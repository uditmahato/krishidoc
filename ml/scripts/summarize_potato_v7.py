"""Report V7 paired research outcomes without tuning or promoting a model."""

import json

import numpy as np
import pandas as pd
from compare_condition_only_v6 import unsupported_breakdown
from prepare_manifest import compute_sha256
from prepare_plantseg_extension import write_json
from prepare_potato_v7 import CONFIG, OUT, ROOT
from sklearn.metrics import f1_score

LABELS = ["potato_early_blight", "potato_late_blight", "potato_healthy"]
METRICS = ("correct", "raw_correct", "accepted", "wrong_accepted", "false_healthy")


def group_diagnostics(frame):
    """Expose repeated-view weighting without claiming true plant independence."""
    result = {}
    for label, part in frame[frame.known].groupby("condition_label"):
        groups = part.groupby("group_id").correct.agg(["mean", "count"])
        result[label] = {
            "images": len(part),
            "proxy_groups": len(groups),
            "largest_group_images": int(groups["count"].max()),
            "image_weighted_accepted_recall": float(part.correct.mean()),
            "equal_group_accepted_recall": float(groups["mean"].mean()),
            "note": "Heuristic duplicate/capture groups, not verified physical plants. Descriptive only; no independent-sample confidence claim.",
        }
    return result


def known_summary(frame):
    known = frame[frame.known]
    if known.empty:
        return {
            "count": 0,
            "raw_macro_f1": None,
            "accepted_macro_f1": None,
            "worst_accepted_recall": None,
        }
    truth = known.condition_label.to_numpy()
    prediction = known.raw_condition.to_numpy()
    gated = np.where(known.accepted, prediction, "refused")
    represented = [label for label in LABELS if (truth == label).any()]
    return {
        "count": len(known),
        "raw_macro_f1": float(
            f1_score(
                truth, prediction, labels=represented, average="macro", zero_division=0
            )
        ),
        "accepted_macro_f1": float(
            f1_score(truth, gated, labels=represented, average="macro", zero_division=0)
        ),
        "worst_accepted_recall": float(
            min(
                known.loc[known.condition_label.eq(label), "correct"].mean()
                for label in represented
            )
        ),
        "known_acceptance_rate": float(known.accepted.mean()),
        "correct_accepted": int(known.correct.sum()),
        "wrong_accepted": int(known.wrong_accepted.sum()),
        "note": "Known-condition-only metrics; unsupported-input errors reported separately. Refusals count against accepted recall/F1.",
    }


def main():
    config = json.loads(CONFIG.read_text())
    runs = {
        "parent": (ROOT / config["finetune_from"]["path"]).parent,
        "candidate": ROOT / "ml/runs/potato_field_v7_tari_20260907/efficientnet_b0",
    }
    frames, identities = {}, {}
    for name, run in runs.items():
        path = OUT / f"{name}_evaluation.json"
        data = json.loads(path.read_text())
        for key, artifact in (
            ("checkpoint_sha256", run / "best.pt"),
            ("calibration_sha256", run / "calibration.json"),
            ("evaluation_manifest_sha256", OUT / "evaluation_manifest.json"),
        ):
            if data[key] != compute_sha256(artifact):
                raise ValueError(f"Changed identity: {name}/{key}")
        frames[name] = pd.DataFrame(data["rows"])
        identities[name] = {
            k: data[k]
            for k in (
                "checkpoint_sha256",
                "calibration_sha256",
                "evaluation_manifest_sha256",
            )
        }
        identities[name]["evaluation_sha256"] = compute_sha256(path)
    a, b = frames["parent"], frames["candidate"]
    pairing = [
        "image_path",
        "sha256",
        "condition_label",
        "validity_label",
        "cohort",
        "known",
    ]
    if a.image_path.duplicated().any() or not a[pairing].equals(b[pairing]):
        raise ValueError("Evaluation rows are not paired")
    old = ~a.cohort.eq("tari_new_group_holdout")
    if int(old.sum()) != 749:
        raise ValueError("Consumed diagnostic population changed")
    fresh = ~old
    controls = a.cohort.eq("google_uncertain_healthy_controls")
    totals = {
        name: {
            "old_diagnostics": {
                metric: int(frame.loc[old & ~controls, metric].sum())
                for metric in METRICS
            },
            "fresh_group_holdout": known_summary(frame.loc[fresh]),
            "fresh_proxy_group_diagnostics": group_diagnostics(frame.loc[fresh]),
            "unsupported_groups_on_consumed_challenge": unsupported_breakdown(
                frame.loc[old]
            ),
        }
        for name, frame in frames.items()
    }
    cohorts = []
    for (cohort, label), indices in a.groupby(
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
    reasons = []
    if b.loc[old, "wrong_accepted"].sum() > a.loc[old, "wrong_accepted"].sum():
        reasons.append("more_wrong_accepted_on_consumed_diagnostics")
    if b.loc[old, "correct"].sum() < a.loc[old, "correct"].sum():
        reasons.append("fewer_correct_accepted_on_consumed_diagnostics")
    if (
        b.loc[old & ~a.known, "accepted"].sum()
        > a.loc[old & ~a.known, "accepted"].sum()
    ):
        reasons.append("more_unsupported_acceptances_on_consumed_diagnostics")
    if b.loc[old, "false_healthy"].sum() > a.loc[old, "false_healthy"].sum():
        reasons.append("more_false_healthy_outputs_on_consumed_diagnostics")
    for item in cohorts:
        if item["label"] in LABELS and item["count"] >= 15:
            if item["candidate"]["correct"] < item["parent"]["correct"]:
                reasons.append(
                    f"class_correct_regression:{item['cohort']}:{item['label']}"
                )
            if item["candidate"]["wrong_accepted"] > item["parent"]["wrong_accepted"]:
                reasons.append(
                    f"class_wrong_accept_regression:{item['cohort']}:{item['label']}"
                )
    new = totals["candidate"]["fresh_group_holdout"]
    if new["accepted_macro_f1"] < config["acceptance_gates"]["minimum_field_macro_f1"]:
        reasons.append("new_group_holdout_fails_accepted_macro_f1")
    if (
        new["worst_accepted_recall"]
        < config["acceptance_gates"]["minimum_worst_known_class_recall"]
    ):
        reasons.append("new_group_holdout_fails_worst_accepted_recall")
    result = {
        "decision": "REJECT_FOR_APP_REPLACEMENT"
        if reasons
        else "PROMISING_RESEARCH_ONLY_NOT_RELEASE_VALIDATED",
        "promotion_allowed": False,
        "reasons": reasons,
        "release_blockers": [
            "no_untouched_Nepal_evidence",
            "insufficient_unknown_condition_calibration_coverage",
            "no_native_V7_verification",
        ],
        "identities": identities,
        "total_inputs": len(a),
        "fresh_group_holdout_count": int(fresh.sum()),
        "totals": totals,
        "cohorts": cohorts,
        "test_driven_threshold_tuning": False,
    }
    write_json(OUT / "comparison.json", result)
    changes = b.loc[
        a.raw_condition.ne(b.raw_condition) | a.accepted.ne(b.accepted),
        pairing + ["raw_condition", "accepted", "correct"],
    ].copy()
    changes["parent_raw_condition"] = a.loc[changes.index, "raw_condition"]
    changes["parent_accepted"] = a.loc[changes.index, "accepted"]
    changes.to_csv(OUT / "paired_changes.csv", index=False)
    print(json.dumps({k: v for k, v in result.items() if k != "cohorts"}, indent=2))


if __name__ == "__main__":
    main()
