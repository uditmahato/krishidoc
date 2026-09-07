from __future__ import annotations

import pandas as pd
import pytest

from krishidoc_ml.manifest import (
    ManifestValidationError,
    select_for_crop,
    source_balanced_weights,
    validate_manifest,
)


def _frame() -> pd.DataFrame:
    return pd.DataFrame(
        [
            {
                "image_path": "maize.jpg",
                "crop": "maize",
                "condition_label": "maize_common_rust",
                "validity_label": "usable_target_leaf",
                "split": "train",
                "source_id": "large",
                "group_id": "m1",
            },
            {
                "image_path": "tomato.jpg",
                "crop": "tomato",
                "condition_label": "tomato_healthy",
                "validity_label": "usable_target_leaf",
                "split": "train",
                "source_id": "large",
                "group_id": "t1",
            },
            {
                "image_path": "background.jpg",
                "crop": "unknown",
                "condition_label": "not_applicable",
                "validity_label": "non_plant",
                "split": "validation",
                "source_id": "small",
                "group_id": "n1",
            },
        ]
    )


def test_crop_pack_relabels_other_crop_but_preserves_non_plant() -> None:
    selected = select_for_crop(_frame(), "maize")
    assert selected.loc[1, "validity_label"] == "wrong_crop_leaf"
    assert selected.loc[1, "condition_label"] == ""
    assert selected.loc[2, "validity_label"] == "non_plant"


def test_source_weights_give_sources_equal_total_mass() -> None:
    weights = source_balanced_weights(_frame())
    frame = _frame().assign(weight=weights)
    totals = frame.groupby("source_id")["weight"].sum()
    assert totals["large"] == pytest.approx(totals["small"])


def test_group_leakage_is_rejected() -> None:
    frame = _frame()
    frame.loc[2, "source_id"] = "large"
    frame.loc[2, "group_id"] = "m1"
    with pytest.raises(ManifestValidationError, match="leakage"):
        validate_manifest(frame)
