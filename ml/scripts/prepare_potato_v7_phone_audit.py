"""Deterministic consumed-photo V7 phone diagnostic, never promotion evidence."""

import json
import shutil
from collections import Counter
from pathlib import Path

import numpy as np
import onnxruntime as ort
from PIL import Image, ImageOps
from prepare_manifest import compute_sha256
from prepare_plantseg_extension import write_json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ml/artifacts/potato_v7_mobile_20260907"


def main():
    fixture = OUT / "v7_inputs"
    if fixture.exists():
        raise ValueError("Preserve frozen phone inputs")
    rows = json.loads(
        (
            ROOT / "ml/artifacts/potato_field_v7_20260907/evaluation_manifest.json"
        ).read_text()
    )["rows"]
    selected = []
    for label in ("potato_early_blight", "potato_late_blight", "potato_healthy"):
        selected += sorted(
            [
                r
                for r in rows
                if r["cohort"] == "tari_new_group_holdout"
                and r["condition_label"] == label
            ],
            key=lambda r: r["sha256"],
        )[:15]
    selected += [r for r in rows if r["cohort"].startswith("google_")]
    selected += sorted(
        [r for r in rows if r["condition_label"] == "potato_other_unknown"],
        key=lambda r: r["sha256"],
    )[:15]
    selected += sorted(
        [r for r in rows if r["validity_label"] == "other_plant"],
        key=lambda r: r["sha256"],
    )[:8]
    assert len(selected) == 79 and len({r["sha256"] for r in selected}) == 79
    fixture.mkdir()
    opts = ort.SessionOptions()
    opts.intra_op_num_threads = 2
    session = ort.InferenceSession(
        str(OUT / "export/potato-v7.onnx"),
        sess_options=opts,
        providers=["CPUExecutionProvider"],
    )
    samples = []
    for i, row in enumerate(selected):
        source = ROOT / row["image_path"]
        if compute_sha256(source) != row["sha256"]:
            raise ValueError("Changed input")
        name = f"{i:04d}{source.suffix}"
        shutil.copyfile(source, fixture / name)
        with Image.open(source) as image:
            image = ImageOps.exif_transpose(image).convert("RGB")
            scale = 224 / max(image.size)
            size = tuple(max(1, min(224, round(d * scale))) for d in image.size)
            resized = image.resize(size, Image.Resampling.BILINEAR)
            reference = Image.new("RGB", (224, 224), (124, 116, 104))
            reference.paste(resized, ((224 - size[0]) // 2, (224 - size[1]) // 2))
        refname = f"{i:04d}_reference.png"
        reference.save(fixture / refname)
        x = (
            np.asarray(reference, dtype=np.float32) / 255
            - np.array([0.485, 0.456, 0.406], dtype=np.float32)
        ) / np.array([0.229, 0.224, 0.225], dtype=np.float32)
        v, c = session.run(
            ["validity_logits", "condition_logits"],
            {"image": x.transpose(2, 0, 1)[None]},
        )
        samples.append(
            {
                **row,
                "id": i,
                "crop": "potato",
                "split": row["cohort"],
                "source_id": row.get("source_id", row["cohort"]),
                "file": name,
                "reference_file": refname,
                "reference_sha256": compute_sha256(fixture / refname),
                "reference_validity": v[0].tolist(),
                "reference_condition": c[0].tolist(),
            }
        )
    write_json(
        fixture / "manifest.json",
        {
            "samples": samples,
            "selection_independent": False,
            "promotion_eligible": False,
            "expected_potato_sha256": "f3119558c3c4c43522a45794341546fdaffef65e5c5c57272a557d23800ea099",
            "sampling": "15 per TARI class by SHA; all 11 Google diagnostics; 15 usable unknown and 8 other plants by SHA; all previously consumed; no inference-based selection",
        },
    )
    print(len(samples), Counter((r["split"], r["condition_label"]) for r in samples))


if __name__ == "__main__":
    main()
