from __future__ import annotations

import numpy as np
import pytest

from krishidoc_ml.calibration import apply_calibration, fit_calibration
from krishidoc_ml.metrics import compute_metrics


def _synthetic_logits():
    validity_targets = np.array([0, 0, 0, 1, 2, 3, 4])
    condition_targets = np.array([0, 1, 2, -1, -1, -1, -1])
    validity_logits = np.full((7, 5), -3.0)
    validity_logits[np.arange(7), validity_targets] = 3.0
    condition_logits = np.array(
        [
            [5.0, 0.0, 0.0],
            [0.0, 5.0, 0.0],
            [0.0, 0.0, 5.0],
            [0.1, 0.1, 0.1],
            [0.1, 0.1, 0.1],
            [0.1, 0.1, 0.1],
            [0.1, 0.1, 0.1],
        ]
    )
    return validity_logits, condition_logits, validity_targets, condition_targets


def test_metrics_cover_classification_calibration_selection_and_ood() -> None:
    validity, condition, validity_targets, condition_targets = _synthetic_logits()
    metrics = compute_metrics(
        validity_logits=validity,
        condition_logits=condition,
        validity_targets=validity_targets,
        condition_targets=condition_targets,
        condition_labels=["a", "b", "c"],
    )
    assert metrics["condition"]["macro_f1"] == 1.0
    assert metrics["condition"]["balanced_accuracy"] == 1.0
    assert metrics["condition"]["calibration"]["ece"] is not None
    assert metrics["condition"]["selective"]["aurc"] == 0.0
    assert metrics["ood"]["joint"]["auroc"] == 1.0
    assert metrics["ood"]["joint"]["aupr_ood"] == 1.0
    assert metrics["ood"]["joint"]["fpr95"] == 0.0


def test_calibration_gate_honours_false_accept_constraint() -> None:
    validity, condition, validity_targets, condition_targets = _synthetic_logits()
    calibration = fit_calibration(
        validity_logits=validity,
        condition_logits=condition,
        validity_targets=validity_targets,
        condition_targets=condition_targets,
        target_false_accept_rate=0.0,
    )
    applied = apply_calibration(calibration, validity, condition)
    assert not np.any(applied["accepted"][3:])
    assert calibration["thresholds"]["observed_false_accept_rate"] == 0.0


def test_metrics_emit_user_visible_accepted_condition_confusion() -> None:
    validity, condition, validity_targets, condition_targets = _synthetic_logits()
    accepted = np.array([True, True, False, True, False, False, False])

    metrics = compute_metrics(
        validity_logits=validity,
        condition_logits=condition,
        validity_targets=validity_targets,
        condition_targets=condition_targets,
        condition_labels=["a", "b", "c"],
        accepted=accepted,
    )

    exposed = metrics["accepted_condition"]
    assert exposed["sample_count"] == 7
    assert exposed["known_count"] == 3
    assert exposed["accepted_count"] == 3
    assert exposed["accepted_known_count"] == 2
    assert exposed["accepted_ood_count"] == 1
    assert exposed["correct_accepted_known_count"] == 2
    assert exposed["overall_accept_rate"] == pytest.approx(3 / 7)
    assert exposed["known_coverage"] == pytest.approx(2 / 3)
    assert exposed["accepted_output_precision"] == pytest.approx(2 / 3)

    # The accepted OOD row predicts `a`, so it must count against the
    # precision of the diagnosis that would be shown to a user.
    class_a = exposed["per_class"]["a"]
    assert class_a["support"] == 1
    assert class_a["accepted_support"] == 1
    assert class_a["predicted_positive"] == 2
    assert class_a["true_positive"] == 1
    assert class_a["false_positive"] == 1
    assert class_a["false_negative"] == 0
    assert class_a["precision"] == 0.5
    assert class_a["recall"] == 1.0
    assert class_a["precision_wilson_95_lower"] == pytest.approx(
        0.0945312, abs=1e-6
    )

    class_c = exposed["per_class"]["c"]
    assert class_c["support"] == 1
    assert class_c["accepted_support"] == 0
    assert class_c["predicted_positive"] == 0
    assert class_c["false_negative"] == 1
    assert class_c["refused_positive"] == 1
    assert class_c["precision_wilson_95"] is None


def test_accepted_condition_all_refuse_is_explicit_and_fail_safe() -> None:
    validity, condition, validity_targets, condition_targets = _synthetic_logits()
    metrics = compute_metrics(
        validity_logits=validity,
        condition_logits=condition,
        validity_targets=validity_targets,
        condition_targets=condition_targets,
        condition_labels=["a", "b", "c"],
        accepted=np.zeros(len(validity_targets), dtype=bool),
    )

    exposed = metrics["accepted_condition"]
    assert exposed["accepted_count"] == 0
    assert exposed["accepted_known_count"] == 0
    assert exposed["known_coverage"] == 0.0
    assert exposed["accuracy"] is None
    assert exposed["accepted_output_precision"] is None
    for values in exposed["per_class"].values():
        assert values["predicted_positive"] == 0
        assert values["precision_wilson_95"] is None


def test_accepted_mask_requires_one_boolean_per_sample() -> None:
    validity, condition, validity_targets, condition_targets = _synthetic_logits()
    with pytest.raises(ValueError, match="one value per sample"):
        compute_metrics(
            validity_logits=validity,
            condition_logits=condition,
            validity_targets=validity_targets,
            condition_targets=condition_targets,
            condition_labels=["a", "b", "c"],
            accepted=np.zeros((len(validity_targets), 1), dtype=bool),
        )
