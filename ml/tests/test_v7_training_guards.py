import copy

import numpy as np
import pytest
import torch
from krishidoc_ml.calibration import apply_calibration, fit_calibration
from krishidoc_ml.model import create_model
from krishidoc_ml.pipeline import (
    _source_balanced_safety_value,
    _verify_frozen_batch_norm_state,
)


def test_bn_freeze_survives_mode_and_epoch_transitions_but_other_weights_train():
    model = create_model("efficientnet_b0", 3, pretrained=False)
    model.set_backbone_batch_norm_frozen()
    model.train()
    model.set_backbone_trainable(True)
    before = {k: v.clone() for k, v in model.state_dict().items()}
    frozen_keys = set()
    for name, module in model.named_modules():
        if name.startswith("backbone.") and isinstance(
            module, torch.nn.modules.batchnorm._BatchNorm
        ):
            assert not module.training
            assert all(not p.requires_grad for p in module.parameters())
            frozen_keys.update(f"{name}.{key}" for key in module.state_dict())
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.001)
    v, c = model(torch.randn(2, 3, 64, 64))
    (v.square().mean() + c.square().mean()).backward()
    optimizer.step()
    assert frozen_keys
    assert all(torch.equal(before[k], model.state_dict()[k]) for k in frozen_keys)
    assert any(
        not torch.equal(before[k], value)
        for k, value in model.state_dict().items()
        if k.startswith("backbone.") and k not in frozen_keys
    )


def test_subgroup_cap_blocks_errors_hidden_by_pooled_cap():
    # One unsupported potato leaf looks exactly like the known leaves, whereas
    # 99 invalid images are easy. Pooled OOD FAR can be 1% with 100% subgroup FAR.
    validity = np.array([[8.0, 0.0]] * 101 + [[0.0, 8.0]] * 99)
    condition = np.array([[8.0, 0.0]] * 200)
    vt = np.array([0] * 101 + [1] * 99)
    ct = np.array([0] * 100 + [-1] * 100)
    arguments = {
        "validity_logits": validity,
        "condition_logits": condition,
        "validity_targets": vt,
        "condition_targets": ct,
        "target_false_accept_rate": 0.05,
    }
    pooled = fit_calibration(**arguments)
    assert apply_calibration(pooled, validity, condition)["accepted"][100]
    grouped = fit_calibration(**arguments, maximum_subgroup_false_accept_rate=0.05)
    assert not apply_calibration(grouped, validity, condition)["accepted"][100]
    assert grouped["subgroup_constraints"]["groups"]["usable_unknown_condition"][
        "fewer_than_30_examples"
    ]
    for bad in (-0.1, 1.1, float("nan")):
        with pytest.raises(ValueError, match="Subgroup"):
            fit_calibration(**arguments, maximum_subgroup_false_accept_rate=bad)


def test_source_safety_monitor_preserves_metrics_and_cannot_hide_bad_validity():
    metrics = {
        "condition": {"field_macro_f1": 1.0},
        "validity": {"balanced_accuracy": 0.0},
        "ood": {"joint": {"auroc": 1.0}},
    }
    before = copy.deepcopy(metrics)
    diagnostics = {
        source: {
            "raw_condition": {
                label: {"count": 20, "correct": 20} for label in ("early", "late")
            }
        }
        for source in ("a", "b")
    }
    assert _source_balanced_safety_value(metrics, diagnostics, ["a", "b"]) == 0.0
    assert metrics == before


def test_bn_artifact_guard_rejects_buffer_or_affine_drift():
    identity = {
        key: "test"
        for key in (
            "crop",
            "architecture",
            "image_size",
            "condition_labels",
            "validity_labels",
        )
    }
    state = {
        f"backbone.bn.{suffix}": torch.ones(1)
        for suffix in (
            "weight",
            "bias",
            "running_mean",
            "running_var",
            "num_batches_tracked",
        )
    }
    parent = {**identity, "model_state": state}
    _verify_frozen_batch_norm_state(copy.deepcopy(parent), parent)
    for key in state:
        candidate = copy.deepcopy(parent)
        candidate["model_state"][key] += 1
        with pytest.raises(ValueError, match="BN state changed"):
            _verify_frozen_batch_norm_state(candidate, parent)


def test_bn_calibration_guard_runs_before_prediction(tmp_path, monkeypatch):
    from krishidoc_ml import pipeline
    from krishidoc_ml.receipt import file_sha256

    parent = {
        **{
            key: "test"
            for key in (
                "crop",
                "architecture",
                "image_size",
                "condition_labels",
                "validity_labels",
            )
        },
        "model_state": {
            f"backbone.bn.{suffix}": torch.ones(1)
            for suffix in (
                "weight",
                "bias",
                "running_mean",
                "running_var",
                "num_batches_tracked",
            )
        },
    }
    path = tmp_path / "parent.pt"
    torch.save(parent, path)
    current = copy.deepcopy(parent)
    current["model_state"]["backbone.bn.weight"] += 1
    monkeypatch.setattr(
        pipeline, "load_model_bundle", lambda *a, **k: {"checkpoint": current}
    )
    monkeypatch.setattr(pipeline, "find_repo_root", lambda *a: tmp_path)
    with pytest.raises(ValueError, match="BN state changed"):
        pipeline.calibrate_checkpoint(
            checkpoint_path=tmp_path / "candidate.pt",
            config={
                "freeze_backbone_batch_norm": True,
                "finetune_from": {"path": str(path), "sha256": file_sha256(path)},
            },
            manifest_path=None,
            split="calibration",
            output_path=tmp_path / "calibration.json",
            target_false_accept_rate=0.05,
            device_name="cpu",
        )
    assert not (tmp_path / "calibration.json").exists()
