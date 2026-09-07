"""Verify and summarize consumed-photo V7 native diagnostic evidence."""

import hashlib
import json
from collections import Counter, defaultdict
from pathlib import Path

import numpy as np
import onnxruntime as ort
from krishidoc_ml.calibration import apply_calibration

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ml/artifacts/potato_v7_mobile_20260907"
LABELS = ["potato_early_blight", "potato_late_blight", "potato_healthy"]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    fixture_path = OUT / "v7_inputs/manifest.json"
    fixture = json.loads(fixture_path.read_text())
    native_path = OUT / "native_audit.json"
    native = json.loads(native_path.read_text())
    samples = {s["id"]: s for s in fixture["samples"]}
    rows = native["rows"]
    assert len(rows) == len(samples) == 79
    assert {r["id"] for r in rows} == set(samples)
    assert native["fixture_sha256"] == digest(fixture_path)
    assert native["potato_artifact_sha256"] == fixture["expected_potato_sha256"]
    assert not any("error" in r for r in rows)
    calibration = json.loads(
        (
            ROOT
            / "ml/runs/potato_field_v7_tari_20260907/efficientnet_b0/calibration.json"
        ).read_text()
    )
    options = ort.SessionOptions()
    options.intra_op_num_threads = 2
    session = ort.InferenceSession(
        str(OUT / "export/potato-v7.onnx"),
        sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    quality = {
        r["id"]: r for r in json.loads((OUT / "host_inputs/quality.json").read_text())
    }
    counts = defaultdict(Counter)
    comparisons = []
    for row in rows:
        sample = samples[row["id"]]
        assert row["image_sha256"] == sample["sha256"]
        assert digest(OUT / "v7_inputs" / sample["file"]) == sample["sha256"]
        tensor = np.fromfile(OUT / "host_inputs" / f"{row['id']}.f32", dtype="<f4")
        tensor = tensor.reshape(1, 224, 224, 3).transpose(0, 3, 1, 2)
        v, c = session.run(["validity_logits", "condition_logits"], {"image": tensor})
        nv = np.asarray([row["potato_validity"]])
        nc = np.asarray([row["potato_condition"]])
        host_gate = bool(apply_calibration(calibration, v, c)["accepted"][0])
        native_gate = bool(apply_calibration(calibration, nv, nc)["accepted"][0])
        accepted = row["potato_state"] == "uncertain"
        # possibleMatchOnly is represented by uncertain; outOfScope is refusal.
        assert row["potato_state"] in ("uncertain", "outOfScope")
        predicted = LABELS[int(np.argmax(nc[0]))]
        comparison = {
            "id": row["id"],
            "max_logit_error": float(max(np.abs(v - nv).max(), np.abs(c - nc).max())),
            "argmax_agrees": bool(
                np.argmax(c) == np.argmax(nc) and np.argmax(v) == np.argmax(nv)
            ),
            "gate_agrees": host_gate == native_gate == accepted,
            "quality_agrees": quality[row["id"]]["gallery_quality_pass"]
            == row["gallery_quality_pass"],
        }
        comparisons.append(comparison)
        for key in (
            "all",
            f"cohort:{sample['split']}",
            f"label:{sample['condition_label']}",
        ):
            stat = counts[key]
            stat["total"] += 1
            stat["accepted"] += accepted
            stat["refused"] += not accepted
            stat["quality_rejected"] += not row["gallery_quality_pass"]
            stat["crop_suggested_potato"] += row["crop_suggestion"] == "potato"
            stat["crop_suggested_other"] += row["crop_suggestion"] not in (
                None,
                "potato",
            )
            stat["crop_suggestion_absent"] += row["crop_suggestion"] is None
            if sample["condition_label"] in LABELS and not (
                sample["split"].startswith("google_")
                and sample["condition_label"] == "potato_healthy"
            ):
                correct = predicted == sample["condition_label"]
                stat["known"] += 1
                stat["raw_correct"] += correct
                stat["accepted_correct"] += accepted and correct
                stat["accepted_wrong"] += accepted and not correct
                stat["quality_pass_accepted_correct"] += (
                    row["gallery_quality_pass"] and accepted and correct
                )
                stat["quality_pass_accepted_wrong"] += (
                    row["gallery_quality_pass"] and accepted and not correct
                )
                stat["false_healthy_accepted"] += (
                    accepted
                    and predicted == "potato_healthy"
                    and sample["condition_label"] != "potato_healthy"
                )
            else:
                stat["other_or_uncertain"] += 1
        row["diagnostic_raw_label"] = predicted
    warm = [r["potato_model_ms"] for r in rows if not r["potato_cold_start"]]
    passed = all(
        c["max_logit_error"] <= 0.001
        and c["argmax_agrees"]
        and c["gate_agrees"]
        and c["quality_agrees"]
        for c in comparisons
    )
    summary = {
        "status": "passed_native_parity_not_promotion"
        if passed
        else "failed_native_parity",
        "report_sha256": digest(native_path),
        "model_sha256": native["potato_artifact_sha256"],
        "fixture_sha256": digest(fixture_path),
        "count": len(rows),
        "processing_errors": 0,
        "selection_independent": False,
        "promotion_eligible": False,
        "max_reference_logit_error": max(r["onnx_native_max_error"] for r in rows),
        "max_actual_pipeline_logit_error": max(
            c["max_logit_error"] for c in comparisons
        ),
        "argmax_disagreements": sum(not c["argmax_agrees"] for c in comparisons),
        "gate_disagreements": sum(not c["gate_agrees"] for c in comparisons),
        "quality_disagreements": sum(not c["quality_agrees"] for c in comparisons),
        "model_latency_ms": {
            "cold": rows[0]["potato_model_ms"],
            "warm_p50": float(np.median(warm)),
            "warm_p95": float(np.percentile(warm, 95)),
            "warm_max": max(warm),
        },
        "counts": dict(counts),
        "comparisons": comparisons,
        "google_rows": [r for r in rows if str(r["split"]).startswith("google_")],
        "limitations": [
            "Previously consumed diagnostic photos, not fresh validation",
            "No Nepal field accuracy claim",
            "Audit exercises production preprocessing and classifiers, not OS camera/gallery taps",
            "Audit scores even quality-rejected photos; count quality separately",
            "Latency is two-thread CPU TFLite, not mobile GPU",
        ],
    }
    output = OUT / "native_summary.json"
    if output.exists():
        raise ValueError("Preserve existing summary")
    output.write_text(json.dumps(summary, indent=2), encoding="utf-8")
    print(
        json.dumps(
            {
                k: v
                for k, v in summary.items()
                if k not in ("comparisons", "google_rows")
            },
            indent=2,
        )
    )
    if not passed:
        raise SystemExit("Native parity failed")


if __name__ == "__main__":
    main()
