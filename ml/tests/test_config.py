from __future__ import annotations

import pytest

from krishidoc_ml.config import iter_experiments


def test_manifest_preparation_config_cannot_start_training() -> None:
    config = {
        "config_kind": "manifest_preparation",
        "crop": "potato",
        "candidate_architectures": ["mobilenet_v3_large"],
    }

    with pytest.raises(ValueError, match="not a training configuration"):
        list(iter_experiments(config))


def test_legacy_training_config_kind_remains_compatible() -> None:
    config = {
        "crop": "potato",
        "candidate_architectures": ["mobilenet_v3_large"],
    }

    assert list(iter_experiments(config)) == [
        ("potato", "mobilenet_v3_large")
    ]
