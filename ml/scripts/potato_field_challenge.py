"""Freeze an originals-only field challenge, then compare frozen GPU candidates.

Bangladesh is whole-source excluded from training; no augmented descendants are
admitted. Source labels are provisional, especially whole-canopy usability.
This is desktop research inference, not physical-device promotion evidence.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image
from torch.utils.data import DataLoader

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "ml/src"))
from krishidoc_ml.calibration import apply_calibration
from krishidoc_ml.constants import VALIDITY_LABELS
from krishidoc_ml.manifest import ManifestDataset, read_manifest
from krishidoc_ml.pipeline import (
    _validate_calibration_artifact_identity,
    load_model_bundle,
    predict_loader,
)
from krishidoc_ml.receipt import file_sha256, write_json_atomic
from krishidoc_ml.transforms import build_transform

LABELS = ["potato_early_blight", "potato_late_blight", "potato_healthy"]
BASE = ROOT / "ml/data/prepared/manifest_field_v3_dg_rotation_1.csv"
OUTPUT = ROOT / "ml/artifacts/potato_field_v4_20260906"


def freeze():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    target = OUTPUT / "challenge.csv"
    if target.exists():
        raise ValueError("Challenge already frozen; never overwrite after inspection")
    base = read_manifest(
        BASE,
        crop="potato",
        condition_labels=LABELS,
        unconfigured_conditions="as_unknown",
    )
    if base.source_id.str.contains("bangladesh", case=False).any():
        raise ValueError(
            "Bangladesh cannot be a challenge if it is in the base manifest"
        )
    rows = []
    rejected = []
    from ml.scripts.prepare_manifest import compute_phash

    reference_hashes = {int(x, 16) for x in base.phash if x}
    byte_hashes = set(base.sha256)
    seen = set()
    files = sorted(
        (ROOT / "ml/data/raw/potato-bangladesh/extracted").rglob("orig_*.jpg")
    )
    if len(files) != 84:
        raise ValueError(
            f"Expected pinned downloaded archive with 84 originals, got {len(files)}"
        )
    for path in files:
        sha = file_sha256(path)
        phash = compute_phash(path)
        close = any((int(phash, 16) ^ h).bit_count() <= 4 for h in reference_hashes)
        if sha in byte_hashes or sha in seen or close:
            rejected.append(
                {"path": str(path.relative_to(ROOT)), "reason": "exact_or_near_overlap"}
            )
            continue
        seen.add(sha)
        condition = {
            "Healthy": "potato_healthy",
            "Fungal Late Blight": "potato_late_blight",
        }.get(path.parent.name, "potato_other_unknown")
        with Image.open(path) as image:
            image.verify()
        rows.append(
            {
                "image_path": path.relative_to(ROOT).as_posix(),
                "crop": "potato",
                "condition_label": condition,
                "validity_label": "usable_target_leaf",
                "split": "external_test",
                "source_id": "potato-bangladesh-originals-v1",
                "group_id": "whole_source_bangladesh",
                "sha256": sha,
                "phash": phash,
                "is_field": "1",
                "is_derivative": "0",
                "cohort": "bangladesh_source_held_out",
                "source_condition": path.parent.name,
            }
        )
    # Representative internal field diagnostic, one row per locked group.
    for label in LABELS:
        pool = base[
            base.source_id.eq("pldd-up")
            & base.split.eq("test")
            & base.condition_label.eq(label)
        ].copy()
        pool["rank"] = pool.sha256.map(
            lambda x: hashlib.sha256(("field-v4:" + x).encode()).hexdigest()
        )
        selection = pool.sort_values("rank").drop_duplicates("group_id").head(15)
        if len(selection) != 15:
            raise ValueError(f"Not enough held-out groups for {label}")
        for record in selection.to_dict("records"):
            record["cohort"] = "pldd_internal_field_test"
            rows.append(record)
    for record in base[
        base.source_id.eq("farmer_chat_india_development_v1")
        & base.split.eq("external_test")
    ].to_dict("records"):
        record["cohort"] = "consumed_farmerchat_development"
        rows.append(record)
    frame = pd.DataFrame(rows).fillna("")
    duplicates = frame.sha256.duplicated()
    for record in frame[duplicates].to_dict("records"):
        rejected.append(
            {"path": record["image_path"], "reason": "duplicate_challenge_sha256"}
        )
    frame = frame[~duplicates].reset_index(drop=True)
    frame.to_csv(target, index=False)
    write_json_atomic(
        OUTPUT / "challenge_receipt.json",
        {
            "promotion_eligible": False,
            "manifest_sha256": file_sha256(target),
            "base_manifest_sha256": file_sha256(BASE),
            "counts": frame.groupby(["cohort", "condition_label"])
            .size()
            .reset_index(name="count")
            .to_dict("records"),
            "excluded": rejected,
            "source_url": "https://data.mendeley.com/datasets/d5b3fzpw3g/1",
            "license": "CC-BY-4.0",
            "attribution": "Ayesha Banu and Kaushik Deb, version 1",
            "limitations": [
                "84 orig-named files in downloaded archive, not the claimed 804 originals.",
                "No expert re-adjudication; orig naming is publisher evidence, not guaranteed lineage.",
                "No farm/plant IDs; whole Bangladesh source is excluded from optimization.",
                "pHash distance 4 excludes detectable overlap, not all possible derivatives.",
                "PLDD is internal source-shared evidence; FarmerChat is consumed development.",
                "Bangladesh has no early-blight originals; no external early-blight accuracy claim.",
            ],
        },
    )
    print(frame.groupby(["cohort", "condition_label"]).size().to_string(), flush=True)


def evaluate(checkpoint: Path, calibration_path: Path, name: str):
    if not name.replace("_", "").replace("-", "").isalnum():
        raise ValueError("Name must be a simple artifact identifier")
    target = OUTPUT / f"{name}.json"
    if target.exists():
        raise ValueError("Evaluation already exists; preserve frozen evidence")
    receipt = json.loads((OUTPUT / "challenge_receipt.json").read_text())
    challenge = OUTPUT / "challenge.csv"
    if file_sha256(challenge) != receipt["manifest_sha256"]:
        raise ValueError("Challenge changed after freezing")
    calibration = json.loads(calibration_path.read_text())
    if calibration.get("checkpoint_sha256") != file_sha256(checkpoint):
        raise ValueError("Calibration checkpoint identity mismatch")
    bundle = load_model_bundle(checkpoint, device_name="cuda")
    if bundle["checkpoint"]["manifest_sha256"] != receipt["base_manifest_sha256"]:
        raise ValueError(
            "Candidate training manifest differs from the frozen challenge ancestry"
        )
    _validate_calibration_artifact_identity(
        calibration,
        checkpoint=bundle["checkpoint"],
        checkpoint_sha256=file_sha256(checkpoint),
        manifest_sha256=receipt["base_manifest_sha256"],
        effective_config_sha256=bundle["checkpoint"]["config_hash"],
    )
    if bundle["checkpoint"]["condition_labels"] != LABELS or bundle["checkpoint"][
        "validity_labels"
    ] != list(VALIDITY_LABELS):
        raise ValueError("Label order mismatch")
    frame = pd.read_csv(challenge, dtype=str, keep_default_na=False)
    for row in frame.itertuples(index=False):
        if file_sha256(ROOT / row.image_path) != row.sha256:
            raise ValueError(f"Challenge image changed: {row.image_path}")
    dataset = ManifestDataset(frame, LABELS, build_transform(224, False), ROOT)
    loader = DataLoader(dataset, batch_size=32, num_workers=2, pin_memory=True)
    predictions = predict_loader(
        bundle["model"], loader, device=bundle["device"], amp_enabled=False
    )
    for head in ("validity_logits", "condition_logits"):
        if not np.isfinite(predictions[head]).all():
            raise ValueError(
                f"Non-finite {head}; do not count inference failures as safe refusals"
            )
    decisions = apply_calibration(
        calibration, predictions["validity_logits"], predictions["condition_logits"]
    )
    frame["accepted"] = decisions["accepted"]
    frame["raw_condition"] = [
        LABELS[i] for i in predictions["condition_logits"].argmax(1)
    ]
    frame["validity_top"] = [
        VALIDITY_LABELS[i] for i in predictions["validity_logits"].argmax(1)
    ]
    frame["app_top"] = np.where(frame.accepted, frame.raw_condition, "rejected")
    frame["usable_probability"] = decisions["validity_probability"]
    frame["condition_probability"] = decisions["condition_probability"]
    frame["correct"] = frame.app_top.eq(frame.condition_label)
    frame["known"] = frame.validity_label.eq(
        "usable_target_leaf"
    ) & frame.condition_label.isin(LABELS)
    frame["false_healthy"] = frame.app_top.eq(
        "potato_healthy"
    ) & ~frame.condition_label.eq("potato_healthy")
    summary = []
    for (cohort, label), part in frame.groupby(["cohort", "condition_label"]):
        summary.append(
            {
                "cohort": cohort,
                "label": label,
                "count": len(part),
                "correct": int(part.correct.sum()),
                "accepted": int(part.accepted.sum()),
                "raw_correct": int(part.raw_condition.eq(part.condition_label).sum()),
                "false_healthy": int(part.false_healthy.sum()),
            }
        )
    frame.to_csv(OUTPUT / f"{name}.csv", index=False)
    write_json_atomic(
        target,
        {
            "checkpoint_sha256": file_sha256(checkpoint),
            "promotion_eligible": False,
            "calibration_sha256": file_sha256(calibration_path),
            "challenge_sha256": receipt["manifest_sha256"],
            "device": str(bundle["device"]),
            "gpu": torch.cuda.get_device_name(),
            "runtime": "desktop PyTorch float32, training evaluation transform; not native app",
            "rows": summary,
        },
    )
    print(json.dumps(summary, indent=2), flush=True)


if __name__ == "__main__":
    sys.path.insert(0, str(ROOT))
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["freeze", "evaluate"])
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--calibration", type=Path)
    parser.add_argument("--name")
    args = parser.parse_args()
    if args.action == "freeze":
        freeze()
    else:
        if not all([args.checkpoint, args.calibration, args.name]):
            parser.error("evaluate requires --checkpoint, --calibration and --name")
        evaluate(args.checkpoint, args.calibration, args.name)
