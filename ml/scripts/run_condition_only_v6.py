"""Run one frozen-path ablation; never overwrite existing model artifacts."""

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone

from prepare_manifest import compute_sha256
from prepare_plantseg_extension import ROOT

OUT = ROOT / "ml/artifacts/potato_field_v6_condition_only_20260907"
RUN = ROOT / "ml/runs/potato_field_v6_condition_only_20260907/efficientnet_b0"
CONFIG = ROOT / "ml/configs/potato_field_v6_condition_only_20260907.json"


def main():
    if RUN.exists() or (OUT / "execution.json").exists():
        raise ValueError("Existing run: inspect, do not overwrite")
    OUT.mkdir(parents=True, exist_ok=True)
    sources = list((ROOT / "ml/src/krishidoc_ml").glob("*.py")) + [
        ROOT / "ml/scripts/run_condition_only_v6.py",
        ROOT / "ml/scripts/evaluate_potato_v5.py",
        ROOT / "ml/scripts/train.py",
        ROOT / "ml/scripts/calibrate.py",
    ]
    identities = {p.relative_to(ROOT).as_posix(): compute_sha256(p) for p in sources}
    for source in sources:
        target = OUT / "source_snapshot" / source.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    frozen = [
        CONFIG,
        ROOT / "ml/data/prepared/manifest_field_v5_plantseg.csv",
        ROOT / "ml/artifacts/potato_field_v5_20260907/evaluation_manifest.json",
    ]
    identities.update(
        {p.relative_to(ROOT).as_posix(): compute_sha256(p) for p in frozen}
    )
    record = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "identities": identities,
        "status": "running",
        "steps": [],
        "promotion_allowed": False,
        "evaluation_role": "consumed diagnostic only; no independent holdout claim",
    }

    def save():
        temp = OUT / "execution.json.tmp"
        temp.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        temp.replace(OUT / "execution.json")

    save()
    steps = [
        (
            "train",
            [
                "ml/scripts/train.py",
                "--config",
                str(CONFIG),
                "--crop",
                "potato",
                "--architecture",
                "efficientnet_b0",
                "--output-dir",
                str(RUN),
                "--device",
                "cuda",
            ],
        ),
        (
            "calibrate",
            [
                "ml/scripts/calibrate.py",
                "--checkpoint",
                str(RUN / "best.pt"),
                "--device",
                "cuda",
            ],
        ),
        (
            "evaluate",
            [
                "ml/scripts/evaluate_potato_v5.py",
                "evaluate",
                "--checkpoint",
                str(RUN / "best.pt"),
                "--name",
                "condition_only_v6",
            ],
        ),
    ]
    try:
        for name, command in steps:
            if any(
                compute_sha256(ROOT / p) != digest for p, digest in identities.items()
            ):
                raise ValueError("Frozen code/config/data identity changed")
            entry = {
                "name": name,
                "started_at": datetime.now(timezone.utc).isoformat(),
                "command": command,
            }
            record["steps"].append(entry)
            save()
            print(f"Starting V6 {name}", flush=True)
            with (OUT / f"{name}.log").open("w", encoding="utf-8") as log:
                result = subprocess.run(
                    [sys.executable, "-u", *command],
                    cwd=ROOT,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    check=False,
                )
            entry.update(
                exit_code=result.returncode,
                finished_at=datetime.now(timezone.utc).isoformat(),
            )
            save()
            if result.returncode:
                raise RuntimeError(f"{name} failed; inspect its log")
        record["status"] = "completed_research_comparison_not_deployed"
    except Exception as error:
        record.update(status="failed", error=str(error))
        save()
        raise
    finally:
        record["updated_at"] = datetime.now(timezone.utc).isoformat()
        save()
    print(record["status"], flush=True)


if __name__ == "__main__":
    main()
