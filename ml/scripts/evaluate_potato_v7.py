"""Freeze and evaluate the new V7 group holdout alongside consumed diagnostics."""

import argparse
import json
from pathlib import Path

import evaluate_potato_v5 as evaluator
import pandas as pd
from prepare_manifest import compute_sha256
from prepare_plantseg_extension import write_json
from prepare_potato_v7 import BASE, CONFIG, MANIFEST, OUT, ROOT

EVAL = OUT / "evaluation_manifest.json"
PARENT = ROOT / "ml/data/prepared/manifest_field_v3_dg_rotation_1.csv"


def freeze():
    if (ROOT / "ml/runs/potato_field_v7_tari_20260907").exists():
        raise ValueError("Freeze evaluation before training")
    config = json.loads(CONFIG.read_text())
    if compute_sha256(MANIFEST) != config["data_snapshot"]["manifest_sha256"]:
        raise ValueError("Training manifest changed")
    previous = ROOT / "ml/artifacts/potato_field_v5_20260907/evaluation_manifest.json"
    old = json.loads(previous.read_text())
    frame = pd.read_csv(MANIFEST, keep_default_na=False)
    fresh = frame[frame.source_id.eq("potato_tari_8286529_v7") & frame.split.eq("test")]
    if len(old["rows"]) != 749 or fresh.empty:
        raise ValueError("Incomplete comparison")
    rows = old["rows"] + [
        {**r, "cohort": "tari_new_group_holdout"}
        for r in fresh.to_dict(orient="records")
    ]
    if len({r["image_path"] for r in rows}) != len(rows):
        raise ValueError("Duplicate evaluation path")
    write_json(
        EVAL,
        {
            "training_manifest_sha256": compute_sha256(MANIFEST),
            "base_manifest_sha256": compute_sha256(PARENT),
            "v5_manifest_sha256": compute_sha256(BASE),
            "previous_evaluation_manifest_sha256": compute_sha256(previous),
            "roles": {
                "tari_new_group_holdout": "fresh group-held-out, same source as new training; not source-independent or Nepal evidence",
                "all_other_cohorts": "consumed diagnostic data only",
            },
            "promotion_eligible": False,
            "rows": rows,
        },
    )
    print(
        "Frozen", len(rows), "inputs including", len(fresh), "new group-held-out photos"
    )


def evaluate(checkpoint, name):
    # Reuse the exact established preprocessing/gating implementation. These
    # explicit paths change only this process, never V5's frozen artifacts.
    evaluator.OUT = OUT
    evaluator.EVAL = EVAL
    evaluator.MANIFEST = MANIFEST
    evaluator.BASE = PARENT
    evaluator.evaluate(checkpoint, name)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["freeze", "evaluate"])
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--name", choices=["parent", "candidate"])
    args = parser.parse_args()
    if args.action == "freeze":
        freeze()
    elif args.checkpoint and args.name:
        evaluate(args.checkpoint, args.name)
    else:
        parser.error("evaluate requires checkpoint and name")
