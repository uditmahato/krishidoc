from pathlib import Path

import numpy as np
import pandas as pd
import pytest
import torch
from krishidoc_ml.checkpoint import initialize_finetune
from krishidoc_ml.manifest import (
    task_source_balanced_sampler,
    task_source_balanced_weights,
)
from krishidoc_ml.pipeline import train_experiment
from krishidoc_ml.receipt import file_sha256


def test_tasks_equal_mass_sources_sqrt_and_no_eval_sampling():
    frame = pd.DataFrame(
        [
            {
                "split": "train",
                "validity_label": "usable_target_leaf",
                "condition_label": c,
                "source_id": s,
            }
            for c, s, n in [
                ("early", "large", 100),
                ("early", "small", 4),
                ("late", "large", 10),
            ]
            for _ in range(n)
        ]
    )
    weights = task_source_balanced_weights(frame)
    assert np.isclose(weights[:104].sum(), weights[104:].sum())
    assert np.isclose(weights[:100].sum() / weights[100:104].sum(), 5)
    assert list(task_source_balanced_sampler(frame, 3, 60)) == list(
        task_source_balanced_sampler(frame, 3, 60)
    )
    frame.loc[0, "split"] = "test"
    with pytest.raises(ValueError, match="training rows"):
        task_source_balanced_weights(frame)


def test_finetune_rejects_wrong_identity_and_preserves_weights(tmp_path: Path):
    model = torch.nn.Linear(2, 2)
    expected = {
        "crop": "potato",
        "architecture": "efficientnet_b0",
        "condition_labels": ["early", "late"],
        "validity_labels": ["usable"],
        "image_size": 224,
        "manifest_sha256": "m",
    }
    path = tmp_path / "parent.pt"
    torch.save(dict(**expected, config_hash="c", model_state=model.state_dict()), path)
    target = torch.nn.Linear(2, 2)
    digest = file_sha256(path)
    initialize_finetune(path, model=target, expected_sha256=digest, **expected)
    assert torch.equal(model.weight, target.weight)
    with pytest.raises(ValueError, match="SHA-256"):
        initialize_finetune(path, model=target, expected_sha256="bad", **expected)
    for key, wrong in [
        ("condition_labels", ["late", "early"]),
        ("manifest_sha256", "other"),
    ]:
        with pytest.raises(ValueError, match=key):
            initialize_finetune(
                path, model=target, expected_sha256=digest, **(expected | {key: wrong})
            )


def test_required_gpu_fails_before_reading_data(tmp_path: Path):
    config = {"_config_path": str(Path(__file__).resolve()), "require_cuda": True}
    with pytest.raises(ValueError, match="CUDA"):
        train_experiment(
            config=config,
            crop="potato",
            architecture="efficientnet_b0",
            condition_labels=["early", "late"],
            output_dir=tmp_path / "run",
            device_name="cpu",
        )
    assert not (tmp_path / "run").exists()
