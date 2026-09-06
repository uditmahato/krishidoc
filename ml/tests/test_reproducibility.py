from __future__ import annotations

import random

import numpy as np
import torch

from krishidoc_ml.reproducibility import (
    capture_rng_state,
    restore_rng_state,
    seed_everything,
)


def test_rng_state_restores_python_numpy_and_torch() -> None:
    seed_everything(41)
    state = capture_rng_state()
    expected = (random.random(), np.random.random(), torch.rand(1).item())
    restore_rng_state(state)
    actual = (random.random(), np.random.random(), torch.rand(1).item())
    assert actual == expected
