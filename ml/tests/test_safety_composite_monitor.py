from __future__ import annotations

import math
from typing import Any

import pandas as pd
import pytest

from krishidoc_ml.pipeline import (
    SAFETY_COMPOSITE_MONITOR,
    _assert_training_coverage,
    _monitor_value,
)


CONDITION_LABELS = ["early", "late", "healthy"]


def _metrics(
    *,
    field_macro_f1: Any = 0.81,
    validity_balanced_accuracy: Any = 0.64,
    joint_ood_auroc: Any = 0.49,
) -> dict[str, Any]:
    return {
        "condition": {"field_macro_f1": field_macro_f1},
        "validity": {"balanced_accuracy": validity_balanced_accuracy},
        "ood": {"joint": {"auroc": joint_ood_auroc}},
    }


def _contract() -> dict[str, Any]:
    return {
        "schema_version": 1,
        "minimum_field_samples_per_condition": 30,
        "minimum_known_samples": 100,
        "minimum_ood_samples": 100,
        "required_validity_labels": [
            "usable_target_leaf",
            "wrong_crop_leaf",
            "other_plant",
        ],
        "minimum_samples_per_required_validity_label": 30,
    }


def _training_frame() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "condition_label": label,
                "validity_label": "usable_target_leaf",
                "is_field": "1",
            }
            for label in CONDITION_LABELS
        ]
    )


def _validation_frame() -> pd.DataFrame:
    rows: list[dict[str, str]] = []
    for label, count in zip(CONDITION_LABELS, (34, 33, 33), strict=True):
        rows.extend(
            {
                "condition_label": label,
                "validity_label": "usable_target_leaf",
                "is_field": "1",
            }
            for _ in range(count)
        )
    for validity_label in ("wrong_crop_leaf", "other_plant"):
        rows.extend(
            {
                "condition_label": "not_applicable",
                "validity_label": validity_label,
                "is_field": "1",
            }
            for _ in range(50)
        )
    return pd.DataFrame(rows)


def _assert_safety_coverage(validation: pd.DataFrame, contract=None) -> None:
    _assert_training_coverage(
        _training_frame(),
        validation,
        CONDITION_LABELS,
        monitor_name=SAFETY_COMPOSITE_MONITOR,
        safety_composite_validation_contract=(
            _contract() if contract is None else contract
        ),
    )


def test_safety_composite_is_fixed_weighted_geometric_mean() -> None:
    observed = _monitor_value(_metrics(), SAFETY_COMPOSITE_MONITOR)
    expected = (0.81**0.50) * (0.64**0.25) * (0.49**0.25)

    assert observed == pytest.approx(expected)


@pytest.mark.parametrize(
    ("field", "value"),
    [
        ("field_macro_f1", None),
        ("field_macro_f1", math.nan),
        ("validity_balanced_accuracy", math.inf),
        ("validity_balanced_accuracy", -0.01),
        ("joint_ood_auroc", 1.01),
        ("joint_ood_auroc", True),
    ],
)
def test_safety_composite_rejects_missing_or_invalid_components(
    field: str, value: Any
) -> None:
    arguments = {field: value}

    with pytest.raises(ValueError, match=SAFETY_COMPOSITE_MONITOR):
        _monitor_value(_metrics(**arguments), SAFETY_COMPOSITE_MONITOR)


def test_safety_composite_accepts_predeclared_validation_coverage() -> None:
    _assert_safety_coverage(_validation_frame())


def test_safety_composite_requires_predeclared_contract() -> None:
    with pytest.raises(ValueError, match="predeclared"):
        _assert_training_coverage(
            _training_frame(),
            _validation_frame(),
            CONDITION_LABELS,
            monitor_name=SAFETY_COMPOSITE_MONITOR,
        )


def test_safety_composite_requires_thirty_field_examples_per_condition() -> None:
    validation = _validation_frame()
    early_indices = validation.index[validation["condition_label"].eq("early")]
    validation.loc[early_indices[:5], "is_field"] = "0"

    with pytest.raises(ValueError, match="at least 30 field.*early.*29"):
        _assert_safety_coverage(validation)


def test_safety_composite_requires_one_hundred_known_examples() -> None:
    validation = _validation_frame().drop(index=0).reset_index(drop=True)

    with pytest.raises(ValueError, match="at least 100 known.*99"):
        _assert_safety_coverage(validation)


def test_safety_composite_requires_one_hundred_ood_examples() -> None:
    validation = _validation_frame().drop(index=100).reset_index(drop=True)

    with pytest.raises(ValueError, match="at least 100 OOD.*99"):
        _assert_safety_coverage(validation)


def test_safety_composite_requires_each_predeclared_validity_label() -> None:
    validation = _validation_frame()
    other_indices = validation.index[
        validation["validity_label"].eq("other_plant")
    ]
    validation.loc[other_indices[:21], "validity_label"] = "wrong_crop_leaf"

    with pytest.raises(ValueError, match="other_plant.*29"):
        _assert_safety_coverage(validation)


@pytest.mark.parametrize(
    "mutation",
    [
        {"schema_version": 2},
        {"minimum_known_samples": True},
        {"required_validity_labels": ["usable_target_leaf", "not_a_label"]},
        {"required_validity_labels": ["usable_target_leaf", "usable_target_leaf"]},
    ],
)
def test_safety_composite_rejects_malformed_contracts(
    mutation: dict[str, Any]
) -> None:
    contract = _contract()
    contract.update(mutation)

    with pytest.raises(ValueError, match="safety_composite_validation_contract"):
        _assert_safety_coverage(_validation_frame(), contract)
