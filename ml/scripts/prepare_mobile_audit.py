"""Prepare a deterministic diagnostic sample for real-device model evaluation.

No training or threshold fitting. Test/development folds are reported separately.
Assets are local-only and must be removed from pubspec before shipping the app.
"""
from __future__ import annotations

import collections
import csv
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parents[2]
MANIFEST = ROOT / "ml/data/prepared/manifest_field_v3_dg_rotation_1.csv"
OUTPUT = ROOT / "app/test_assets/mobile_audit"
ARTIFACTS = ROOT / "ml/artifacts/mobile_audit_20260906"
MODEL = ROOT / "ml/artifacts/potato_field_v3_dg_rotation_1_oe003/efficientnet_b0/potato-efficientnet_b0-9e1854e4dabf.onnx"


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    with MANIFEST.open(encoding="utf-8") as stream:
        rows = list(csv.DictReader(stream))
    groups: dict[tuple, list[dict]] = collections.defaultdict(list)
    for row in rows:
        if row["split"] not in ("test", "external_test"):
            continue
        known = row["validity_label"] == "usable_target_leaf" and (
            row["condition_label"] not in ("not_applicable", f"{row['crop']}_other_unknown")
        )
        key = (row["split"], row["source_id"], row["crop"], row["condition_label"], row["validity_label"])
        if row["split"] == "test" and not known:
            key = ("test", row["source_id"], "negative", row["validity_label"])
        groups[key].append(row)
    selected = []
    seen_groups = set()
    for key, candidates in sorted(groups.items()):
        limit = 20 if key[0] == "test" and key[2] != "negative" else 8
        if key[0] == "external_test":
            limit = 24 if key[2] == "unknown" else 100
        ordered = sorted(candidates, key=lambda r: hashlib.sha256(
            ("mobile-audit-20260906:" + r["sha256"]).encode()).hexdigest())
        count = 0
        for row in ordered:
            if row["group_id"] in seen_groups:
                continue
            selected.append(dict(row))
            seen_groups.add(row["group_id"])
            count += 1
            if count == limit:
                break

    OUTPUT.mkdir(parents=True, exist_ok=True)
    ARTIFACTS.mkdir(parents=True, exist_ok=True)
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(MODEL), sess_options=options, providers=["CPUExecutionProvider"])
    mean = np.asarray([0.485, 0.456, 0.406], dtype=np.float32)
    std = np.asarray([0.229, 0.224, 0.225], dtype=np.float32)
    entries = []
    for index, row in enumerate(selected):
        source = ROOT / row["image_path"]
        if digest(source) != row["sha256"]:
            raise ValueError(f"Image hash changed: {source}")
        file_name = f"{index:04d}{source.suffix.lower()}"
        shutil.copyfile(source, OUTPUT / file_name)
        with Image.open(source) as source_image:
            image = ImageOps.exif_transpose(source_image).convert("RGB")
        scale = 224 / max(image.size)
        size = tuple(max(1, min(224, round(d * scale))) for d in image.size)
        resized = image.resize(size, Image.Resampling.BILINEAR)
        reference = Image.new("RGB", (224, 224), (124, 116, 104))
        reference.paste(resized, ((224 - size[0]) // 2, (224 - size[1]) // 2))
        reference_name = f"{index:04d}_reference.png"
        reference.save(OUTPUT / reference_name)
        normalized = (np.asarray(reference, dtype=np.float32) / 255 - mean) / std
        validity, condition = session.run(None, {"image": normalized.transpose(2, 0, 1)[None]})
        entries.append({**row, "id": index, "file": file_name, "reference_file": reference_name,
                        "reference_validity": validity[0].tolist(), "reference_condition": condition[0].tolist()})

    # Simple non-plant controls are separate from real labelled field data.
    for rgb in [(0, 0, 0), (255, 255, 255), (128, 128, 128), (30, 150, 40)]:
        index = len(entries)
        name = f"{index:04d}_control.png"
        image = Image.new("RGB", (224, 224), rgb)
        image.save(OUTPUT / name)
        normalized = (np.asarray(image, dtype=np.float32) / 255 - mean) / std
        validity, condition = session.run(None, {"image": normalized.transpose(2, 0, 1)[None]})
        entries.append({"id": index, "file": name, "reference_file": name,
                        "crop": "unknown", "condition_label": "not_applicable", "validity_label": "non_plant",
                        "split": "synthetic_control", "source_id": "solid_colour_control",
                        "sha256": digest(OUTPUT / name), "group_id": name,
                        "reference_validity": validity[0].tolist(), "reference_condition": condition[0].tolist()})
    manifest = {"schema_version": 1, "manifest_sha256": digest(MANIFEST),
                "sampling": "deterministic sha256 order, at most one image per group, stratified caps",
                "selection_independent": False, "promotion_eligible": False,
                "limitations": ["Diagnostic sample; not Nepal field validation.",
                                "external_test is a previously consumed Digital Green development fold.",
                                "Legacy global model training overlap cannot be excluded."], "samples": entries}
    encoded = json.dumps(manifest, indent=2)
    (OUTPUT / "manifest.json").write_text(encoded, encoding="utf-8")
    (ARTIFACTS / "manifest.json").write_text(encoded, encoding="utf-8")
    print(json.dumps({"samples": len(entries), "counts": dict(collections.Counter(
        f"{r['split']}/{r['crop']}/{r['condition_label']}" for r in entries)),
        "asset_bytes": sum(p.stat().st_size for p in OUTPUT.iterdir())}, indent=2))


if __name__ == "__main__":
    main()
