"""Execute one frozen V7 GPU experiment; preserve failures and all prior runs."""

import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone

from prepare_manifest import compute_sha256
from prepare_potato_v7 import CONFIG, MANIFEST, OUT, ROOT

RUN = ROOT / "ml/runs/potato_field_v7_tari_20260907/efficientnet_b0"


def main():
    if RUN.exists() or (OUT / "execution.json").exists():
        raise ValueError("Existing run; never overwrite or relaunch blindly")
    config = json.loads(CONFIG.read_text())
    audit = ROOT / config["data_snapshot"]["audit_receipt"]
    sources = list((ROOT / "ml/src/krishidoc_ml").glob("*.py")) + [
        ROOT / "ml/scripts" / name
        for name in (
            "run_potato_v7.py",
            "evaluate_potato_v7.py",
            "evaluate_potato_v5.py",
            "prepare_potato_v7.py",
            "audit_potato_v7_duplicates.py",
            "prepare_plantseg_extension.py",
            "prepare_manifest.py",
            "train.py",
            "calibrate.py",
        )
    ]
    frozen = sources + [CONFIG, MANIFEST, audit, OUT / "evaluation_manifest.json"]
    frozen += [
        ROOT / item["path"]
        for item in config["data_snapshot"]["required_artifacts"].values()
    ]
    identities = {p.relative_to(ROOT).as_posix(): compute_sha256(p) for p in frozen}
    for source in sources:
        target = OUT / "source_snapshot" / source.relative_to(ROOT)
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
    record = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "status": "running",
        "identities": identities,
        "steps": [],
        "promotion_allowed": False,
    }

    def save():
        temporary = OUT / "execution.json.tmp"
        temporary.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        temporary.replace(OUT / "execution.json")

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
            "evaluate_parent",
            [
                "ml/scripts/evaluate_potato_v7.py",
                "evaluate",
                "--checkpoint",
                str(ROOT / config["finetune_from"]["path"]),
                "--name",
                "parent",
            ],
        ),
        (
            "evaluate_candidate",
            [
                "ml/scripts/evaluate_potato_v7.py",
                "evaluate",
                "--checkpoint",
                str(RUN / "best.pt"),
                "--name",
                "candidate",
            ],
        ),
    ]
    save()
    try:
        for name, command in steps:
            if any(compute_sha256(ROOT / p) != sha for p, sha in identities.items()):
                raise ValueError("Frozen source/config/data changed")
            entry = {
                "name": name,
                "started_at": datetime.now(timezone.utc).isoformat(),
                "command": command,
            }
            record["steps"].append(entry)
            save()
            print("Starting V7", name, flush=True)
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
                raise RuntimeError(f"{name} failed; inspect preserved log")
        record["status"] = "completed_research_comparison_not_deployed"
    except Exception as error:
        record.update(status="failed", error=str(error))
        raise
    finally:
        record["updated_at"] = datetime.now(timezone.utc).isoformat()
        save()
    print(record["status"], flush=True)


if __name__ == "__main__":
    main()
