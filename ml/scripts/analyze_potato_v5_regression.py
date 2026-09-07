"""Replay frozen gates and isolate regressions without retuning on test data."""

import json
import sys

import numpy as np
import pandas as pd
from prepare_manifest import compute_sha256
from prepare_plantseg_extension import OUT, ROOT, write_json

sys.path.insert(0, str(ROOT / "ml/src"))
from krishidoc_ml.calibration import apply_calibration


def main():
    models = {
        "parent": ROOT / "ml/runs/potato_field_v3_dg_rotation_1_oe003/efficientnet_b0",
        "candidate": ROOT / "ml/runs/potato_field_v5_plantseg_20260907/efficientnet_b0",
    }
    frames, gates = {}, {}
    for name, run in models.items():
        result = json.loads((OUT / f"{name}_evaluation.json").read_text())
        calibration = json.loads((run / "calibration.json").read_text())
        if result["calibration_sha256"] != compute_sha256(run / "calibration.json"):
            raise ValueError("Calibration identity changed")
        if result["evaluation_manifest_sha256"] != compute_sha256(
            OUT / "evaluation_manifest.json"
        ):
            raise ValueError("Evaluation manifest changed")
        frame = pd.DataFrame(result["rows"])
        if len(frame) != 749 or frame.image_path.duplicated().any():
            raise ValueError("Incomplete or duplicate evaluation rows")
        decision = apply_calibration(
            calibration,
            np.array(frame.validity_logits.tolist()),
            np.array(frame.condition_logits.tolist()),
        )
        quality_block = frame.quality_block.fillna(False).astype(bool).to_numpy()
        if not np.array_equal(
            decision["accepted"] & ~quality_block, frame.accepted.to_numpy()
        ):
            raise ValueError("Stored decisions do not reproduce")
        threshold = calibration["thresholds"]
        frame["validity_pass"] = (
            decision["validity_probability"] >= threshold["validity_probability_min"]
        )
        frame["condition_pass"] = (
            decision["condition_probability"] >= threshold["condition_probability_min"]
        )
        frame["energy_pass"] = (
            decision["condition_energy"] <= threshold["condition_energy_max"]
        )
        frame["validity_top_usable"] = (
            np.array(frame.validity_logits.tolist()).argmax(1) == 0
        )
        frame["validity_probability"] = decision["validity_probability"]
        frames[name] = frame
        ood = frame.loc[~frame.known]
        gates[name] = {
            "ood_count": len(ood),
            **{
                key: int(ood[key].sum())
                for key in (
                    "accepted",
                    "validity_pass",
                    "validity_top_usable",
                    "condition_pass",
                    "energy_pass",
                )
            },
        }
    a, b = frames["parent"], frames["candidate"]
    if not a[["image_path", "sha256"]].equals(b[["image_path", "sha256"]]):
        raise ValueError("Unpaired inputs")
    new_bad = ~a.accepted & b.wrong_accepted
    new_ood = ~a.known & ~a.accepted & b.accepted
    attribution = {
        "new_wrong_acceptances_after_parent_refusal": int(new_bad.sum()),
        "new_ood_acceptances": int(new_ood.sum()),
        "new_ood_cases_crossing_validity_gate": int(
            (new_ood & ~a.validity_pass & b.validity_pass).sum()
        ),
        "new_ood_cases_crossing_energy_gate": int(
            (new_ood & ~a.energy_pass & b.energy_pass).sum()
        ),
        "old_ood_acceptances_now_refused": int(
            (~a.known & a.accepted & ~b.accepted).sum()
        ),
        "note": "Gate crossings can overlap. This is descriptive attribution, not a causal proof or recalibrated hybrid model.",
    }
    summary = []
    for cohort in sorted(a.cohort.unique()):
        first, second = a[a.cohort == cohort], b[b.cohort == cohort]
        summary.append(
            {
                "cohort": cohort,
                "count": len(first),
                **{
                    f"{model}_{metric}": int(frame[metric].sum())
                    for model, frame in (("parent", first), ("candidate", second))
                    for metric in (
                        "correct",
                        "wrong_accepted",
                        "accepted",
                        "false_healthy",
                    )
                },
            }
        )
    result = {
        "decision": "REJECT_FOR_APP_REPLACEMENT",
        "promotion_allowed": False,
        "reason": "More correct predictions do not compensate for increased unsupported-image acceptance and wrong accepted diagnoses.",
        "new_training_or_threshold_tuning_in_this_analysis": False,
        "ood_gates": gates,
        "gate_crossings": attribution,
        "cohorts": summary,
        "parent_evaluation_sha256": compute_sha256(OUT / "parent_evaluation.json"),
        "candidate_evaluation_sha256": compute_sha256(
            OUT / "candidate_evaluation.json"
        ),
    }
    write_json(OUT / "regression_decision.json", result)
    disagreements = b.loc[
        a.accepted.ne(b.accepted) | a.raw_condition.ne(b.raw_condition),
        [
            "image_path",
            "cohort",
            "condition_label",
            "raw_condition",
            "accepted",
            "validity_probability",
        ],
    ].copy()
    disagreements["parent_raw_condition"] = a.loc[disagreements.index, "raw_condition"]
    disagreements["parent_accepted"] = a.loc[disagreements.index, "accepted"]
    disagreements["parent_validity_probability"] = a.loc[
        disagreements.index, "validity_probability"
    ]
    disagreements.to_csv(OUT / "disagreements.csv", index=False)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
