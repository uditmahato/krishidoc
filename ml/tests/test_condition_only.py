import numpy as np
import pytest
import torch
from krishidoc_ml.calibration import fit_calibration
from krishidoc_ml.model import create_model
from krishidoc_ml.pipeline import _source_balanced_recall


def test_condition_only_preserves_validity_weights_buffers_and_outputs():
    torch.manual_seed(3)
    model = create_model("efficientnet_b0", 3, pretrained=False).eval()
    inputs = torch.randn(2, 3, 64, 64)
    with torch.no_grad():
        before_validity = model(inputs)[0].clone()
    before = {k: v.clone() for k, v in model.state_dict().items()}
    model.set_condition_head_only()
    model.train()
    model.set_backbone_trainable(True)  # An epoch transition cannot unfreeze it.
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.01)
    for _ in range(2):
        optimizer.zero_grad()
        validity, condition = model(inputs)
        assert torch.equal(validity, before_validity)
        torch.nn.functional.cross_entropy(condition, torch.tensor([0, 1])).backward()
        optimizer.step()
    assert any(
        not torch.equal(v, before[k])
        for k, v in model.state_dict().items()
        if k.startswith("condition_head.")
    )
    assert all(
        torch.equal(v, before[k])
        for k, v in model.state_dict().items()
        if not k.startswith("condition_head.")
    )
    assert not model.backbone.training and not model.shared.training
    assert all(
        not p.requires_grad
        for n, p in model.named_parameters()
        if not n.startswith("condition_head.")
    )


def test_source_monitor_cannot_hide_small_source_behind_large_source():
    diagnostics = {
        "large": {
            "raw_condition": {
                "early": {"count": 1000, "correct": 1000},
                "late": {"count": 1000, "correct": 1000},
            }
        },
        "small": {
            "raw_condition": {
                "early": {"count": 10, "correct": 0},
                "late": {"count": 10, "correct": 0},
            }
        },
    }
    assert _source_balanced_recall(diagnostics, ["large", "small"]) == 0.5
    for sources in (["large"], ["large", "missing"], ["large", "large"]):
        with pytest.raises(ValueError):
            _source_balanced_recall(diagnostics, sources)


def test_calibration_cannot_relax_frozen_validity_temperature_or_floor():
    result = fit_calibration(
        validity_logits=np.array([[4, 0], [3, 0], [0, 3], [0, 4]]),
        condition_logits=np.array([[3, 0], [0, 3], [1, 0], [0, 1]]),
        validity_targets=np.array([0, 0, 1, 1]),
        condition_targets=np.array([0, 1, -1, -1]),
        fixed_validity_temperature=0.7,
        validity_probability_min_floor=0.8,
    )
    assert result["validity_temperature"] == 0.7
    assert result["thresholds"]["validity_probability_min"] >= 0.8


def test_calibration_rejects_any_validity_path_drift_before_reading_images(
    tmp_path, monkeypatch
):
    from krishidoc_ml import pipeline
    from krishidoc_ml.receipt import file_sha256

    metadata = {
        "crop": "potato",
        "architecture": "efficientnet_b0",
        "image_size": 224,
        "validity_labels": ["usable"],
        "condition_labels": ["early", "late"],
    }
    parent = {**metadata, "model_state": {"validity_head.weight": torch.ones(1)}}
    parent_path = tmp_path / "parent.pt"
    torch.save(parent, parent_path)
    changed = {**metadata, "model_state": {"validity_head.weight": torch.zeros(1)}}
    monkeypatch.setattr(
        pipeline, "load_model_bundle", lambda *a, **k: {"checkpoint": changed}
    )
    monkeypatch.setattr(pipeline, "find_repo_root", lambda *a: tmp_path)
    config = {
        "training_mode": "condition_head_only",
        "finetune_from": {"path": str(parent_path), "sha256": file_sha256(parent_path)},
    }
    with pytest.raises(ValueError, match="weights or buffers changed"):
        pipeline.calibrate_checkpoint(
            checkpoint_path=tmp_path / "candidate.pt",
            config=config,
            manifest_path=None,
            split="calibration",
            output_path=tmp_path / "calibration.json",
            target_false_accept_rate=0.05,
            device_name="cpu",
        )
    assert not (tmp_path / "calibration.json").exists()
