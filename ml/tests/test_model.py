from __future__ import annotations

import pytest
import torch

from krishidoc_ml.model import create_model


@pytest.mark.parametrize("architecture", ["mobilenet_v3_large", "efficientnet_b0"])
def test_two_head_models_return_raw_logits(architecture: str) -> None:
    model = create_model(architecture, num_condition_classes=4, pretrained=False)
    model.eval()
    with torch.inference_mode():
        validity, condition = model(torch.zeros(2, 3, 64, 64))
    assert validity.shape == (2, 5)
    assert condition.shape == (2, 4)
    # A raw-logit head is intentionally not normalised inside the model.
    assert not torch.allclose(validity.sum(dim=1), torch.ones(2))
