"""Frozen research comparison: source-held-out, internal and consumed cohorts."""

import argparse
import csv
import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import torch
from PIL import Image
from prepare_manifest import compute_phash, compute_sha256
from prepare_plantseg_extension import BASE, MANIFEST, OUT, ROOT, write_json

sys.path.insert(0, str(ROOT / "ml/src"))
from krishidoc_ml.calibration import apply_calibration
from krishidoc_ml.pipeline import (
    _validate_calibration_artifact_identity,
    load_model_bundle,
)
from krishidoc_ml.transforms import build_transform

GOOGLE = ROOT / "ml/artifacts/google_potato_audit_20260906/reviewed"
EVAL = OUT / "evaluation_manifest.json"


def freeze():
    with MANIFEST.open(encoding="utf-8-sig", newline="") as stream:
        combined = list(csv.DictReader(stream))
    reference = [(r["sha256"], int(r["phash"], 16)) for r in combined]
    with (ROOT / "ml/artifacts/potato_field_v4_20260906/challenge.csv").open(
        encoding="utf-8-sig", newline=""
    ) as stream:
        rows = list(csv.DictReader(stream))
    rows.extend(
        {**r, "cohort": "plantseg_publisher_test"}
        for r in combined
        if r["source_id"] == "plantseg_potato_v5" and r["split"] == "test"
    )
    excluded = []
    holeta_hashes = []
    for path in sorted(
        (ROOT / "ml/data/raw/potato-holeta-locked/originals").rglob("*.jpg")
    ):
        sha, phash = compute_sha256(path), compute_phash(path)
        with Image.open(path) as image:
            image.verify()
        if any(
            sha == prior or (int(phash, 16) ^ ph).bit_count() <= 8
            for prior, ph in reference + holeta_hashes
        ):
            excluded.append(
                {
                    "path": path.relative_to(ROOT).as_posix(),
                    "reason": "exact_or_near_duplicate",
                }
            )
            continue
        holeta_hashes.append((sha, int(phash, 16)))
        rows.append(
            {
                "image_path": path.relative_to(ROOT).as_posix(),
                "sha256": sha,
                "phash": phash,
                "cohort": "holeta_source_held_out",
                "condition_label": "potato_healthy"
                if path.parent.name == "Healthy"
                else "potato_late_blight",
                "validity_label": "usable_target_leaf",
            }
        )
    google = json.loads((GOOGLE / "manifest.json").read_text())
    quality = {
        r["id"]: r
        for r in json.loads((GOOGLE / "host_inputs/quality.json").read_text())
    }
    for item in google["samples"]:
        tensor = GOOGLE / f"host_inputs/{item['id']}.f32"
        rows.append(
            {
                "image_path": f"ml/data/raw/google_potato_audit_20260906/reviewed/{item['file']}",
                "sha256": item["sha256"],
                "cohort": "google_uncertain_healthy_controls"
                if item["condition_label"] == "potato_healthy"
                else "google_consumed_disease",
                "condition_label": item["condition_label"],
                "validity_label": "usable_target_leaf",
                "id": item["id"],
                "tensor_path": tensor.relative_to(ROOT).as_posix(),
                "tensor_sha256": compute_sha256(tensor),
                "quality_block": bool(
                    set(quality[item["id"]]["gallery_issues"])
                    & {"tooDark", "tooBright", "invalid_size"}
                ),
            }
        )
    for row in rows:
        if compute_sha256(ROOT / row["image_path"]) != row["sha256"]:
            raise ValueError("Evaluation photo changed")
    write_json(
        EVAL,
        {
            "training_manifest_sha256": compute_sha256(MANIFEST),
            "base_manifest_sha256": compute_sha256(BASE),
            "rows": rows,
            "excluded_holeta": excluded,
            "holeta_publisher_count_discrepancy": "Extracted 363 healthy + 67 late jpg files, not the described 63 late; no label repair inferred.",
        },
    )
    print(pd.DataFrame(rows).groupby(["cohort", "condition_label"]).size().to_string())
    print("Holeta exclusions", len(excluded))


def evaluate(checkpoint, name):
    target = OUT / f"{name}_evaluation.json"
    if target.exists():
        raise ValueError("Preserve frozen results")
    frozen = json.loads(EVAL.read_text())
    bundle = load_model_bundle(checkpoint, device_name="cuda")
    ck = bundle["checkpoint"]
    if ck["manifest_sha256"] not in {
        frozen["training_manifest_sha256"],
        frozen["base_manifest_sha256"],
    }:
        raise ValueError("Unrecognized candidate data identity")
    if (
        compute_sha256(MANIFEST) != frozen["training_manifest_sha256"]
        or compute_sha256(BASE) != frozen["base_manifest_sha256"]
    ):
        raise ValueError("Frozen source manifests changed")
    calibration_path = checkpoint.parent / "calibration.json"
    calibration = json.loads(calibration_path.read_text())
    _validate_calibration_artifact_identity(
        calibration,
        checkpoint=ck,
        checkpoint_sha256=compute_sha256(checkpoint),
        manifest_sha256=ck["manifest_sha256"],
        effective_config_sha256=ck["config_hash"],
    )
    labels = ck["condition_labels"]
    if (
        labels != ["potato_early_blight", "potato_late_blight", "potato_healthy"]
        or ck["image_size"] != 224
    ):
        raise ValueError("Wrong input/output contract")
    transform = build_transform(224, False)
    results = []
    for start in range(0, len(frozen["rows"]), 32):
        group = frozen["rows"][start : start + 32]
        tensors = []
        for row in group:
            path = ROOT / row["image_path"]
            if compute_sha256(path) != row["sha256"]:
                raise ValueError("Evaluation input changed")
            if row.get("tensor_path"):
                path = ROOT / row["tensor_path"]
                if compute_sha256(path) != row["tensor_sha256"]:
                    raise ValueError("Dart tensor changed")
                tensors.append(
                    torch.from_numpy(
                        np.fromfile(path, dtype="<f4")
                        .reshape(224, 224, 3)
                        .transpose(2, 0, 1)
                        .copy()
                    )
                )
            else:
                with Image.open(path) as image:
                    tensors.append(transform(image.convert("RGB")))
        with torch.inference_mode():
            v, c = bundle["model"](torch.stack(tensors).to(bundle["device"]))
        v, c = v.cpu().numpy(), c.cpu().numpy()
        if not np.isfinite(v).all() or not np.isfinite(c).all():
            raise ValueError("Inference failure, not a refusal")
        decision = apply_calibration(calibration, v, c)
        for i, row in enumerate(group):
            raw = labels[int(c[i].argmax())]
            accepted = bool(decision["accepted"][i]) and not row.get(
                "quality_block", False
            )
            known = (
                row["validity_label"] == "usable_target_leaf"
                and row["condition_label"] in labels
            )
            results.append(
                {
                    **row,
                    "raw_condition": raw,
                    "accepted": accepted,
                    "known": known,
                    "correct": accepted and known and raw == row["condition_label"],
                    "raw_correct": known and raw == row["condition_label"],
                    "wrong_accepted": accepted
                    and (not known or raw != row["condition_label"]),
                    "false_healthy": accepted
                    and raw == "potato_healthy"
                    and row["condition_label"] != "potato_healthy",
                    "validity_logits": v[i].tolist(),
                    "condition_logits": c[i].tolist(),
                }
            )
        print(
            f"{name}: {min(start + 32, len(frozen['rows']))}/{len(frozen['rows'])}",
            flush=True,
        )
    frame = pd.DataFrame(results)
    summary = []
    for (cohort, label), part in frame.groupby(["cohort", "condition_label"]):
        summary.append(
            {
                "cohort": cohort,
                "label": label,
                "count": len(part),
                **{
                    key: int(part[key].sum())
                    for key in (
                        "known",
                        "correct",
                        "raw_correct",
                        "accepted",
                        "wrong_accepted",
                        "false_healthy",
                    )
                },
            }
        )
    write_json(
        target,
        {
            "checkpoint_sha256": compute_sha256(checkpoint),
            "calibration_sha256": compute_sha256(calibration_path),
            "evaluation_manifest_sha256": compute_sha256(EVAL),
            "gpu": torch.cuda.get_device_name(),
            "runtime": "CUDA float32, no native-device claim; Google uses exact Dart tensors, others Python letterbox",
            "promotion_eligible": False,
            "summary": summary,
            "rows": results,
        },
    )
    frame.drop(columns=["validity_logits", "condition_logits"]).to_csv(
        OUT / f"{name}_per_image.csv", index=False
    )
    print(pd.DataFrame(summary).to_string(index=False))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["freeze", "evaluate"])
    parser.add_argument("--checkpoint", type=Path)
    parser.add_argument("--name")
    args = parser.parse_args()
    if args.action == "freeze":
        freeze()
    elif args.checkpoint and args.name:
        evaluate(args.checkpoint, args.name)
    else:
        parser.error("evaluate requires checkpoint and name")
