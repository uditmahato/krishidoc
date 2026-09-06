"""Summarize the device audit without tuning thresholds or changing weights."""
from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
POTATO = ["potato_early_blight", "potato_late_blight", "potato_healthy"]
GLOBAL_LABELS = [r["key"] for r in json.loads((ROOT / "app/assets/models/plant_disease_experimental.metadata.json").read_text())["output"]["labels"]]
CAL = json.loads((ROOT / "ml/runs/potato_field_v3_dg_rotation_1_oe003/efficientnet_b0/calibration.json").read_text())


def reference_result(row: dict) -> str | None:
    def probability(values, temperature):
        values = np.asarray(values, dtype=np.float64) / temperature
        values -= values.max()
        exponentials = np.exp(values)
        return exponentials / exponentials.sum()
    validity = probability(row["reference_validity"], CAL["validity_temperature"])
    condition = probability(row["reference_condition"], CAL["condition_temperature"])
    scaled = np.asarray(row["reference_condition"]) / CAL["condition_temperature"]
    energy = -CAL["condition_temperature"] * (scaled.max() + np.log(np.exp(scaled - scaled.max()).sum()))
    threshold = CAL["thresholds"]
    accepted = validity[0] >= threshold["validity_probability_min"] and condition.max() >= threshold["condition_probability_min"] and energy <= threshold["condition_energy_max"]
    return POTATO[int(condition.argmax())] if accepted else None


def fraction(numerator: int, denominator: int) -> dict:
    return {"count": numerator, "total": denominator, "rate": numerator / denominator if denominator else None}


def summarize(rows: list[dict]) -> dict:
    known = [r for r in rows if r["validity"] == "usable_target_leaf" and r["label"] in GLOBAL_LABELS]
    suggestions = [r for r in known if r.get("crop_suggestion") is not None]
    potato_known = [r for r in known if r["crop"] == "potato"]
    potato_ood = [r for r in rows if r not in potato_known]
    return {
        "samples": len(rows),
        "known": len(known),
        "gallery_rejects_known": fraction(sum(not r["gallery_quality_pass"] for r in known), len(known)),
        "global_condition_correct": fraction(sum(r["global_top"] == r["label"] for r in known), len(known)),
        "global_crop_correct": fraction(sum(r["global_top"].split('_')[0] == r["crop"] for r in known), len(known)),
        "auto_suggestion_coverage": fraction(len(suggestions), len(known)),
        "auto_suggestion_correct": fraction(sum(r["crop_suggestion"] == r["crop"] for r in suggestions), len(suggestions)),
        "potato_app_correct_accepted": fraction(sum(r["potato_top"] == r["label"] for r in potato_known), len(potato_known)),
        "potato_reference_correct_accepted": fraction(sum(reference_result(r) == r["label"] for r in potato_known), len(potato_known)),
        "potato_app_ood_accepts": fraction(sum(r["potato_top"] is not None for r in potato_ood), len(potato_ood)),
        "potato_reference_ood_accepts": fraction(sum(reference_result(r) is not None for r in potato_ood), len(potato_ood)),
        "potato_reference_app_decision_disagreements": sum(reference_result(r) != r["potato_top"] for r in rows),
        "onnx_native_max_error": max((r["onnx_native_max_error"] for r in rows), default=0),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("report", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    data = json.loads(args.report.read_text(encoding="utf-8"))
    rows = [r for r in data["rows"] if "error" not in r]
    groups = collections.defaultdict(list)
    for row in rows:
        groups[f"{row['split']}/{row['crop']}"] .append(row)
    summary = {"overall": summarize(rows), "by_split_crop": {k: summarize(v) for k, v in groups.items()},
               "errors": [r for r in data["rows"] if "error" in r],
               "confusions": dict(collections.Counter(f"{r['split']}: {r['label']} -> {r['global_top']}" for r in rows if r["label"] in GLOBAL_LABELS)),
               "quality_rejected_known_ids": [r["id"] for r in rows if r["label"] in GLOBAL_LABELS and not r["gallery_quality_pass"]],
               "wrong_suggestion_ids": [r["id"] for r in rows if r.get("crop_suggestion") and r["crop"] in ('potato','tomato','maize') and r["crop_suggestion"] != r["crop"]]}
    encoded = json.dumps(summary, indent=2)
    if args.output:
        args.output.write_text(encoded, encoding="utf-8")
    print(encoded)


if __name__ == "__main__":
    main()
