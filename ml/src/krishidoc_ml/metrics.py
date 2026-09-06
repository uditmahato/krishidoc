"""Safety-oriented classification, calibration, selection, and OOD metrics."""

from __future__ import annotations

from typing import Any, Sequence

import numpy as np
from sklearn.metrics import average_precision_score, roc_auc_score, roc_curve

from .constants import USABLE_VALIDITY_LABEL, VALIDITY_LABELS, VALIDITY_TO_INDEX


Z_95 = 1.959963984540054


def softmax(logits: np.ndarray, temperature: float = 1.0) -> np.ndarray:
    values = np.asarray(logits, dtype=np.float64) / max(float(temperature), 1e-6)
    values = values - np.max(values, axis=1, keepdims=True)
    exponent = np.exp(values)
    return exponent / exponent.sum(axis=1, keepdims=True)


def classification_metrics(
    targets: np.ndarray,
    predictions: np.ndarray,
    labels: Sequence[str],
) -> dict[str, Any]:
    targets = np.asarray(targets, dtype=np.int64)
    predictions = np.asarray(predictions, dtype=np.int64)
    per_class: dict[str, dict[str, float | int]] = {}
    recalls: list[float] = []
    f1_values: list[float] = []
    for index, label in enumerate(labels):
        target_positive = targets == index
        predicted_positive = predictions == index
        true_positive = int(np.sum(target_positive & predicted_positive))
        false_positive = int(np.sum(~target_positive & predicted_positive))
        false_negative = int(np.sum(target_positive & ~predicted_positive))
        true_negative = int(np.sum(~target_positive & ~predicted_positive))
        support = int(np.sum(target_positive))
        predicted_positive_count = int(np.sum(predicted_positive))
        precision = _safe_divide(true_positive, true_positive + false_positive)
        recall = _safe_divide(true_positive, true_positive + false_negative)
        f1 = _safe_divide(2 * precision * recall, precision + recall)
        per_class[label] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": support,
            "true_positive": true_positive,
            "false_positive": false_positive,
            "false_negative": false_negative,
            "true_negative": true_negative,
            "predicted_positive": predicted_positive_count,
            "precision_wilson_95": _interval_dict(
                _wilson_interval(true_positive, predicted_positive_count)
            ),
            "recall_wilson_95": _interval_dict(
                _wilson_interval(true_positive, support)
            ),
        }
        if support:
            recalls.append(recall)
            f1_values.append(f1)
    accuracy = float(np.mean(targets == predictions)) if len(targets) else 0.0
    return {
        "accuracy": accuracy,
        "macro_f1": float(np.mean(f1_values)) if f1_values else None,
        "balanced_accuracy": float(np.mean(recalls)) if recalls else None,
        "per_class": per_class,
        "sample_count": int(len(targets)),
    }


def calibration_metrics(
    probabilities: np.ndarray, targets: np.ndarray, bins: int = 15
) -> dict[str, float | int | None]:
    probabilities = np.asarray(probabilities, dtype=np.float64)
    targets = np.asarray(targets, dtype=np.int64)
    if len(targets) == 0:
        return {"ece": None, "brier": None, "nll": None, "sample_count": 0}
    confidence = probabilities.max(axis=1)
    predictions = probabilities.argmax(axis=1)
    correct = predictions == targets
    edges = np.linspace(0.0, 1.0, bins + 1)
    ece = 0.0
    for lower, upper in zip(edges[:-1], edges[1:]):
        if upper == 1.0:
            mask = (confidence >= lower) & (confidence <= upper)
        else:
            mask = (confidence >= lower) & (confidence < upper)
        if np.any(mask):
            ece += float(np.mean(mask)) * abs(
                float(np.mean(correct[mask])) - float(np.mean(confidence[mask]))
            )
    one_hot = np.eye(probabilities.shape[1], dtype=np.float64)[targets]
    brier = float(np.mean(np.sum((probabilities - one_hot) ** 2, axis=1)))
    true_probability = probabilities[np.arange(len(targets)), targets]
    nll = float(-np.mean(np.log(np.clip(true_probability, 1e-12, 1.0))))
    return {"ece": ece, "brier": brier, "nll": nll, "sample_count": len(targets)}


def selective_metrics(
    correct: np.ndarray, confidence: np.ndarray
) -> dict[str, Any]:
    correct = np.asarray(correct, dtype=bool)
    confidence = np.asarray(confidence, dtype=np.float64)
    if not len(correct):
        return {"aurc": None, "risk_at_coverage": {}, "sample_count": 0}
    order = np.argsort(-confidence, kind="stable")
    errors = (~correct[order]).astype(np.float64)
    cumulative_risk = np.cumsum(errors) / np.arange(1, len(errors) + 1)
    result = {}
    for coverage in (0.5, 0.8, 0.9, 1.0):
        count = max(1, int(np.ceil(len(errors) * coverage)))
        result[f"{coverage:.1f}"] = float(cumulative_risk[count - 1])
    return {
        "aurc": float(np.mean(cumulative_risk)),
        "risk_at_coverage": result,
        "sample_count": int(len(correct)),
    }


def ood_metrics(ood_targets: np.ndarray, ood_scores: np.ndarray) -> dict[str, Any]:
    targets = np.asarray(ood_targets, dtype=np.int64)
    scores = np.asarray(ood_scores, dtype=np.float64)
    if len(np.unique(targets)) < 2:
        return {
            "auroc": None,
            "aupr_ood": None,
            "fpr95": None,
            "sample_count": int(len(targets)),
            "reason": "both ID and OOD examples are required",
        }
    false_positive_rate, true_positive_rate, _ = roc_curve(targets, scores)
    indices = np.flatnonzero(true_positive_rate >= 0.95)
    fpr95 = float(false_positive_rate[indices[0]]) if len(indices) else 1.0
    return {
        "auroc": float(roc_auc_score(targets, scores)),
        "aupr_ood": float(average_precision_score(targets, scores)),
        "fpr95": fpr95,
        "sample_count": int(len(targets)),
    }


def energy_score(logits: np.ndarray, temperature: float = 1.0) -> np.ndarray:
    """Return energy where larger values are more out-of-distribution-like."""

    scaled = np.asarray(logits, dtype=np.float64) / max(float(temperature), 1e-6)
    maximum = np.max(scaled, axis=1, keepdims=True)
    logsumexp = maximum[:, 0] + np.log(np.exp(scaled - maximum).sum(axis=1))
    return -float(temperature) * logsumexp


def compute_metrics(
    *,
    validity_logits: np.ndarray,
    condition_logits: np.ndarray,
    validity_targets: np.ndarray,
    condition_targets: np.ndarray,
    condition_labels: Sequence[str],
    validity_temperature: float = 1.0,
    condition_temperature: float = 1.0,
    accepted: np.ndarray | None = None,
    accept_score_threshold: float = 0.5,
    is_field: np.ndarray | None = None,
) -> dict[str, Any]:
    validity_targets = np.asarray(validity_targets, dtype=np.int64)
    condition_targets = np.asarray(condition_targets, dtype=np.int64)
    validity_probabilities = softmax(validity_logits, validity_temperature)
    condition_probabilities = softmax(condition_logits, condition_temperature)
    validity_predictions = validity_probabilities.argmax(axis=1)
    condition_predictions = condition_probabilities.argmax(axis=1)

    usable_index = VALIDITY_TO_INDEX[USABLE_VALIDITY_LABEL]
    known = (validity_targets == usable_index) & (condition_targets >= 0)
    ood = ~known
    accept_score = (
        validity_probabilities[:, usable_index] * condition_probabilities.max(axis=1)
    )
    if accepted is None:
        accepted = accept_score >= float(accept_score_threshold)
    else:
        accepted = np.asarray(accepted, dtype=bool)
    if accepted.shape != known.shape:
        raise ValueError(
            "accepted must be a one-dimensional mask with one value per sample"
        )

    condition = classification_metrics(
        condition_targets[known], condition_predictions[known], condition_labels
    )
    condition["calibration"] = calibration_metrics(
        condition_probabilities[known], condition_targets[known]
    )
    condition["selective"] = selective_metrics(
        condition_predictions[known] == condition_targets[known],
        accept_score[known],
    )

    if is_field is not None:
        field_mask = known & np.asarray(is_field, dtype=bool)
        if np.any(field_mask):
            field = classification_metrics(
                condition_targets[field_mask],
                condition_predictions[field_mask],
                condition_labels,
            )
            condition["field_macro_f1"] = field["macro_f1"]
            condition["field_balanced_accuracy"] = field["balanced_accuracy"]
            condition["field_sample_count"] = field["sample_count"]

    accepted_condition = _accepted_condition_metrics(
        condition_targets=condition_targets,
        condition_predictions=condition_predictions,
        condition_labels=condition_labels,
        known=known,
        ood=ood,
        accepted=accepted,
    )

    false_accept_rate = float(np.mean(accepted[ood])) if np.any(ood) else None
    false_accept_by_validity: dict[str, dict[str, float | int]] = {}
    for index, label in enumerate(VALIDITY_LABELS):
        mask = validity_targets == index
        if index == usable_index:
            mask &= condition_targets < 0
        if np.any(mask):
            false_accept_by_validity[label] = {
                "rate": float(np.mean(accepted[mask])),
                "count": int(np.sum(mask)),
            }

    joint_ood_score = 1.0 - accept_score
    return {
        "validity": {
            **classification_metrics(
                validity_targets, validity_predictions, VALIDITY_LABELS
            ),
            "calibration": calibration_metrics(
                validity_probabilities, validity_targets
            ),
        },
        "condition": condition,
        "accepted_condition": accepted_condition,
        "ood": {
            "joint": ood_metrics(ood.astype(np.int64), joint_ood_score),
            "condition_energy": ood_metrics(
                ood.astype(np.int64),
                energy_score(condition_logits, condition_temperature),
            ),
            "false_accept_rate": false_accept_rate,
            "false_accept_count": int(np.sum(accepted & ood)),
            "ood_count": int(np.sum(ood)),
            "false_accept_by_validity": false_accept_by_validity,
        },
        "decision": {
            "accepted_count": int(np.sum(accepted)),
            "accepted_rate": float(np.mean(accepted)) if len(accepted) else 0.0,
            "known_accept_rate": float(np.mean(accepted[known])) if np.any(known) else None,
            "default_accept_score_threshold": float(accept_score_threshold),
        },
        "sample_count": int(len(validity_targets)),
    }


def _safe_divide(numerator: float, denominator: float) -> float:
    return float(numerator / denominator) if denominator else 0.0


def _accepted_condition_metrics(
    *,
    condition_targets: np.ndarray,
    condition_predictions: np.ndarray,
    condition_labels: Sequence[str],
    known: np.ndarray,
    ood: np.ndarray,
    accepted: np.ndarray,
) -> dict[str, Any]:
    """Summarize the diagnoses that the frozen refusal gate would expose.

    A predicted-positive count includes every accepted output for that label,
    including an accepted OOD image. This makes accepted-set precision measure
    the safety of user-visible diagnoses instead of silently excluding false
    accepts. Recall uses all known examples of the class as its denominator, so
    refusals remain visible; per-class ``coverage`` reports acceptance alone.
    """

    per_class: dict[str, dict[str, Any]] = {}
    recalls: list[float] = []
    f1_values: list[float] = []
    for index, label in enumerate(condition_labels):
        target_positive = known & (condition_targets == index)
        predicted_positive = accepted & (condition_predictions == index)
        accepted_target = accepted & target_positive

        true_positive = int(np.sum(target_positive & predicted_positive))
        false_positive = int(np.sum(~target_positive & predicted_positive))
        false_negative = int(np.sum(target_positive & ~predicted_positive))
        true_negative = int(np.sum(~target_positive & ~predicted_positive))
        support = int(np.sum(target_positive))
        accepted_support = int(np.sum(accepted_target))
        predicted_positive_count = int(np.sum(predicted_positive))

        precision = _safe_divide(true_positive, predicted_positive_count)
        recall = _safe_divide(true_positive, support)
        f1 = _safe_divide(2 * precision * recall, precision + recall)
        coverage = _safe_divide(accepted_support, support)
        precision_interval = _wilson_interval(
            true_positive, predicted_positive_count
        )
        recall_interval = _wilson_interval(true_positive, support)
        coverage_interval = _wilson_interval(accepted_support, support)
        per_class[str(label)] = {
            "precision": precision,
            "recall": recall,
            "f1": f1,
            "support": support,
            "accepted_support": accepted_support,
            "coverage": coverage,
            "true_positive": true_positive,
            "false_positive": false_positive,
            "false_negative": false_negative,
            "true_negative": true_negative,
            "predicted_positive": predicted_positive_count,
            "refused_positive": support - accepted_support,
            "accepted_false_negative": accepted_support - true_positive,
            "precision_wilson_95": _interval_dict(precision_interval),
            "precision_wilson_95_lower": (
                precision_interval[0] if precision_interval is not None else None
            ),
            "recall_wilson_95": _interval_dict(recall_interval),
            "recall_wilson_95_lower": (
                recall_interval[0] if recall_interval is not None else None
            ),
            "coverage_wilson_95": _interval_dict(coverage_interval),
            "coverage_wilson_95_lower": (
                coverage_interval[0] if coverage_interval is not None else None
            ),
        }
        if support:
            recalls.append(recall)
            f1_values.append(f1)

    known_count = int(np.sum(known))
    accepted_count = int(np.sum(accepted))
    accepted_known_count = int(np.sum(accepted & known))
    accepted_ood_count = int(np.sum(accepted & ood))
    correct_accepted_known = int(
        np.sum(accepted & known & (condition_predictions == condition_targets))
    )
    known_coverage_interval = _wilson_interval(accepted_known_count, known_count)
    accepted_output_interval = _wilson_interval(
        correct_accepted_known, accepted_count
    )
    accepted_known_accuracy_interval = _wilson_interval(
        correct_accepted_known, accepted_known_count
    )
    return {
        "accuracy": (
            _safe_divide(correct_accepted_known, accepted_count)
            if accepted_count
            else None
        ),
        "macro_f1": float(np.mean(f1_values)) if f1_values else None,
        "balanced_accuracy": float(np.mean(recalls)) if recalls else None,
        "per_class": per_class,
        "sample_count": int(len(accepted)),
        "known_count": known_count,
        "accepted_count": accepted_count,
        "accepted_known_count": accepted_known_count,
        "accepted_ood_count": accepted_ood_count,
        "correct_accepted_known_count": correct_accepted_known,
        "overall_accept_rate": _safe_divide(accepted_count, len(accepted)),
        "known_coverage": _safe_divide(accepted_known_count, known_count),
        "known_coverage_wilson_95": _interval_dict(known_coverage_interval),
        "accepted_output_precision": (
            _safe_divide(correct_accepted_known, accepted_count)
            if accepted_count
            else None
        ),
        "accepted_output_precision_wilson_95": _interval_dict(
            accepted_output_interval
        ),
        "accepted_known_accuracy": (
            _safe_divide(correct_accepted_known, accepted_known_count)
            if accepted_known_count
            else None
        ),
        "accepted_known_accuracy_wilson_95": _interval_dict(
            accepted_known_accuracy_interval
        ),
    }


def _wilson_interval(
    successes: int, trials: int, *, z: float = Z_95
) -> tuple[float, float] | None:
    if trials <= 0 or successes < 0 or successes > trials:
        return None
    proportion = successes / trials
    z_squared = z * z
    denominator = 1.0 + z_squared / trials
    centre = proportion + z_squared / (2.0 * trials)
    margin = z * np.sqrt(
        proportion * (1.0 - proportion) / trials
        + z_squared / (4.0 * trials * trials)
    )
    lower = max(0.0, float((centre - margin) / denominator))
    upper = min(1.0, float((centre + margin) / denominator))
    if successes == 0:
        lower = 0.0
    if successes == trials:
        upper = 1.0
    return lower, upper


def _interval_dict(
    interval: tuple[float, float] | None,
) -> dict[str, float] | None:
    if interval is None:
        return None
    return {"lower": interval[0], "upper": interval[1]}
