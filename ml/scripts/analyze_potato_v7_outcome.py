"""Describe V7 recognition versus refusal changes; never adjust frozen gates."""

import json
import sys

import numpy as np
import pandas as pd
from prepare_manifest import compute_sha256
from prepare_plantseg_extension import write_json
from prepare_potato_v7 import OUT, ROOT

sys.path.insert(0, str(ROOT / "ml/src"))
from krishidoc_ml.calibration import apply_calibration


def main():
    comparison = json.loads((OUT / "comparison.json").read_text())
    frames = {}
    for name, run in {
        "parent": "potato_field_v3_dg_rotation_1_oe003",
        "candidate": "potato_field_v7_tari_20260907",
    }.items():
        path = OUT / f"{name}_evaluation.json"
        if compute_sha256(path) != comparison["identities"][name]["evaluation_sha256"]:
            raise ValueError("Evaluation identity changed")
        data = json.loads(path.read_text())
        calpath = ROOT / "ml/runs" / run / "efficientnet_b0/calibration.json"
        if compute_sha256(calpath) != data["calibration_sha256"]:
            raise ValueError("Calibration changed")
        calibration = json.loads(calpath.read_text())
        frame = pd.DataFrame(data["rows"])
        decision = apply_calibration(
            calibration,
            np.array(frame.validity_logits.tolist()),
            np.array(frame.condition_logits.tolist()),
        )
        quality = (
            frame.quality_block.astype("boolean").fillna(False).to_numpy(dtype=bool)
        )
        if not np.array_equal(decision["accepted"] & ~quality, frame.accepted):
            raise ValueError("Stored acceptance does not reproduce")
        thresholds = calibration["thresholds"]
        frame["validity_fail"] = (
            decision["validity_probability"] < thresholds["validity_probability_min"]
        )
        frame["condition_fail"] = (
            decision["condition_probability"] < thresholds["condition_probability_min"]
        )
        frame["energy_fail"] = (
            decision["condition_energy"] > thresholds["condition_energy_max"]
        )
        frames[name] = frame
    a, b = frames["parent"], frames["candidate"]
    if not a[["image_path", "sha256"]].equals(b[["image_path", "sha256"]]):
        raise ValueError("Unpaired inputs")
    result = {"threshold_tuning": False, "promotion_allowed": False, "populations": {}}
    for name, mask in {
        "consumed_diagnostics": ~a.cohort.eq("tari_new_group_holdout")
        & ~a.cohort.eq("google_uncertain_healthy_controls"),
        "new_same_source_group_holdout": a.cohort.eq("tari_new_group_holdout"),
    }.items():
        lost = mask & a.correct & ~b.correct
        raw_correct_refused = mask & b.raw_correct & ~b.accepted
        result["populations"][name] = {
            "lost_previously_correct_accepted": int(lost.sum()),
            "lost_but_candidate_raw_still_correct": int((lost & b.raw_correct).sum()),
            "new_correct_accepted": int((mask & ~a.correct & b.correct).sum()),
            "raw_errors_corrected": int(
                (mask & a.known & ~a.raw_correct & b.raw_correct).sum()
            ),
            "new_raw_errors": int((mask & a.raw_correct & ~b.raw_correct).sum()),
            "candidate_raw_correct_but_refused": int(raw_correct_refused.sum()),
            "failed_gates_among_raw_correct_refusals": {
                key: int((raw_correct_refused & b[key]).sum())
                for key in ("validity_fail", "condition_fail", "energy_fail")
            },
            "note": "Gate counts overlap. Descriptive replay, not a causal ablation or proposal to relax thresholds on this test.",
        }
    result["comparison_sha256"] = compute_sha256(OUT / "comparison.json")
    write_json(OUT / "recognition_vs_refusal.json", result)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
