"""Run the fixed CUDA candidate, calibration and comparison with durable logs."""

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

from prepare_manifest import compute_sha256
from prepare_plantseg_extension import CONFIG, OUT, ROOT

RUN = ROOT / "ml/runs/potato_field_v5_plantseg_20260907/efficientnet_b0"
PARENT = ROOT / "ml/runs/potato_field_v3_dg_rotation_1_oe003/efficientnet_b0/best.pt"


def main():
    if RUN.exists() or (OUT / "execution.json").exists():
        raise ValueError(
            "Experiment already started; inspect its receipts, do not overwrite"
        )
    sources = sorted((ROOT / "ml/src/krishidoc_ml").glob("*.py"))
    sources += [Path(__file__).resolve(), ROOT / "ml/scripts/evaluate_potato_v5.py"]
    hashes = {p.relative_to(ROOT).as_posix(): compute_sha256(p) for p in sources}
    frozen_files = {
        CONFIG.relative_to(ROOT).as_posix(): compute_sha256(CONFIG),
        "ml/data/prepared/manifest_field_v5_plantseg.csv": compute_sha256(
            ROOT / "ml/data/prepared/manifest_field_v5_plantseg.csv"
        ),
        (OUT / "evaluation_manifest.json").relative_to(ROOT).as_posix(): compute_sha256(
            OUT / "evaluation_manifest.json"
        ),
    }
    record = {
        "started_at": datetime.now(timezone.utc).isoformat(),
        "code_sha256": hashes,
        "frozen_files_sha256": frozen_files,
        "config_sha256": compute_sha256(CONFIG),
        "steps": [],
        "status": "running",
        "promotion_allowed": False,
    }

    def save():
        (OUT / "execution.json").write_text(
            json.dumps(record, indent=2) + "\n", encoding="utf-8"
        )

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
            "parent_evaluate",
            [
                "ml/scripts/evaluate_potato_v5.py",
                "evaluate",
                "--checkpoint",
                str(PARENT),
                "--name",
                "parent",
            ],
        ),
        (
            "candidate_evaluate",
            [
                "ml/scripts/evaluate_potato_v5.py",
                "evaluate",
                "--checkpoint",
                str(RUN / "best.pt"),
                "--name",
                "candidate",
            ],
        ),
    ]
    try:
        for name, command in steps:
            if any(
                compute_sha256(ROOT / path) != value
                for path, value in frozen_files.items()
            ):
                raise ValueError("Frozen config or manifests changed mid-run")
            if any(
                compute_sha256(ROOT / path) != value for path, value in hashes.items()
            ):
                raise ValueError("Experiment code changed mid-run")
            entry = {
                "name": name,
                "started_at": datetime.now(timezone.utc).isoformat(),
                "command": command,
            }
            record["steps"].append(entry)
            save()
            print(f"Starting {name}", flush=True)
            with (OUT / f"{name}.log").open("w", encoding="utf-8") as log:
                process = subprocess.run(
                    [sys.executable, "-u", *command],
                    cwd=ROOT,
                    stdout=log,
                    stderr=subprocess.STDOUT,
                    check=False,
                )
            entry.update(
                exit_code=process.returncode,
                finished_at=datetime.now(timezone.utc).isoformat(),
            )
            save()
            if process.returncode:
                raise RuntimeError(f"{name} failed; inspect {name}.log")
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
