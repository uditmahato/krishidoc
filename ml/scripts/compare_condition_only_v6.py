"""Compare frozen research outputs; never tune thresholds on the challenge."""

import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd
from prepare_manifest import compute_sha256

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "ml/src"))
from krishidoc_ml.calibration import apply_calibration

CHALLENGE = ROOT / "ml/artifacts/potato_field_v5_20260907"
OUT = ROOT / "ml/artifacts/potato_field_v6_condition_only_20260907"
MODELS = {
    "parent": "potato_field_v3_dg_rotation_1_oe003",
    "candidate": "potato_field_v5_plantseg_20260907",
    "condition_only_v6": "potato_field_v6_condition_only_20260907",
}
METRICS = ("correct", "raw_correct", "accepted", "wrong_accepted", "false_healthy")


def unsupported_breakdown(frame):
    """Keep unknown diseases separate from invalid or wrong-crop photos."""
    unknown = frame.loc[~frame.known]
    output = []
    for validity, group in unknown.groupby("validity_label", dropna=False):
        count = len(group)
        accepted = int(group.accepted.sum())
        output.append(
            {
                "validity_label": validity,
                "count": count,
                "false_accepted": accepted,
                "observed_false_accept_rate": accepted / count,
                "role": "unsupported_condition_on_usable_leaf"
                if validity == "usable_target_leaf"
                else "image_validity_rejection",
            }
        )
    return output


def main():
    output = OUT / "comparison.json"
    if output.exists():
        raise ValueError("Preserve existing comparison")
    manifest_hash = compute_sha256(CHALLENGE / "evaluation_manifest.json")
    frames, calibrations, identities = {}, {}, {}
    for name, folder in MODELS.items():
        path = CHALLENGE / f"{name}_evaluation.json"
        result = json.loads(path.read_text())
        run = ROOT / "ml/runs" / folder / "efficientnet_b0"
        for key, artifact in (
            ("checkpoint_sha256", run / "best.pt"),
            ("calibration_sha256", run / "calibration.json"),
        ):
            if result[key] != compute_sha256(artifact):
                raise ValueError(f"Changed {name} {key}")
        if result["evaluation_manifest_sha256"] != manifest_hash:
            raise ValueError("Unpaired evaluation manifest")
        frame = pd.DataFrame(result["rows"])
        if len(frame) != 749 or frame.image_path.duplicated().any():
            raise ValueError("Incomplete or duplicate evaluation")
        calibration = json.loads((run / "calibration.json").read_text())
        decision = apply_calibration(
            calibration,
            np.array(frame.validity_logits.tolist()),
            np.array(frame.condition_logits.tolist()),
        )
        quality = np.array(
            [bool(row.get("quality_block", False)) for row in result["rows"]]
        )
        if not np.array_equal(decision["accepted"] & ~quality, frame.accepted):
            raise ValueError("Stored acceptance cannot be replayed")
        frames[name], calibrations[name] = frame, calibration
        identities[name] = {
            "evaluation_sha256": compute_sha256(path),
            **{k: result[k] for k in ("checkpoint_sha256", "calibration_sha256")},
        }
    parent, current = frames["parent"], frames["condition_only_v6"]
    pair_columns = [
        "image_path",
        "sha256",
        "cohort",
        "condition_label",
        "validity_label",
        "known",
    ]
    if any(not parent[pair_columns].equals(f[pair_columns]) for f in frames.values()):
        raise ValueError("Mismatched paired labels or inputs")
    max_validity_difference = float(
        np.max(
            np.abs(
                np.array(parent.validity_logits.tolist())
                - np.array(current.validity_logits.tolist())
            )
        )
    )
    if max_validity_difference > 1e-6:
        raise ValueError("Frozen validity outputs changed beyond numerical tolerance")
    old_cal, new_cal = calibrations["parent"], calibrations["condition_only_v6"]
    if old_cal["validity_temperature"] != new_cal["validity_temperature"]:
        raise ValueError("Validity temperature drift")
    if (
        new_cal["thresholds"]["validity_probability_min"]
        < old_cal["thresholds"]["validity_probability_min"]
    ):
        raise ValueError("Validity threshold relaxed")
    new_ood = ~parent.known & ~parent.accepted & current.accepted
    if new_ood.any():
        raise ValueError(
            "Unexpected new unsupported acceptances; investigate before reporting"
        )
    cohorts = []
    for (cohort, label), indices in parent.groupby(
        ["cohort", "condition_label"], dropna=False
    ).groups.items():
        cohorts.append(
            {
                "cohort": cohort,
                "label": label,
                "count": len(indices),
                **{
                    name: {
                        metric: int(frame.loc[indices, metric].sum())
                        for metric in METRICS
                    }
                    for name, frame in frames.items()
                },
            }
        )
    ood = ~parent.known
    controls = parent.cohort.eq("google_uncertain_healthy_controls")
    totals = {
        name: {
            "known_excluding_uncertain_controls": int((frame.known & ~controls).sum()),
            "unsupported_count": int(ood.sum()),
            "unsupported_accepted": int(frame.loc[ood, "accepted"].sum()),
            **{metric: int(frame.loc[~controls, metric].sum()) for metric in METRICS},
        }
        for name, frame in frames.items()
    }
    result = {
        "status": "RESEARCH_ONLY_NO_APP_PROMOTION",
        "evaluation_role": "All photos are consumed development diagnostics, not independent validation",
        "threshold_tuning_on_challenge": False,
        "evaluation_manifest_sha256": manifest_hash,
        "identities": identities,
        "maximum_validity_logit_difference": max_validity_difference,
        "new_unsupported_acceptances": int(new_ood.sum()),
        "totals_exclude_uncertain_healthy_controls": totals,
        "unsupported_by_type": {
            name: unsupported_breakdown(frame) for name, frame in frames.items()
        },
        "cohorts": cohorts,
    }
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    changed = parent.raw_condition.ne(current.raw_condition) | parent.accepted.ne(
        current.accepted
    )
    details = current.loc[
        changed,
        pair_columns + ["raw_condition", "accepted", "correct", "wrong_accepted"],
    ].copy()
    for field in ("raw_condition", "accepted", "correct", "wrong_accepted"):
        details[f"parent_{field}"] = parent.loc[changed, field]
    details.to_csv(OUT / "paired_changes.csv", index=False)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
