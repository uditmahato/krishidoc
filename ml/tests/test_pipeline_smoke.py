from __future__ import annotations

import json
from pathlib import Path

import pandas as pd
import pytest
import torch
from PIL import Image

import krishidoc_ml.pipeline as pipeline


class _TinyTwoHead(torch.nn.Module):
    def __init__(self, condition_classes: int) -> None:
        super().__init__()
        self.backbone = torch.nn.Sequential(
            torch.nn.Conv2d(3, 4, kernel_size=3, padding=1),
            torch.nn.ReLU(),
            torch.nn.AdaptiveAvgPool2d(1),
        )
        self.pool = torch.nn.Identity()
        self.shared = torch.nn.Sequential(torch.nn.Flatten(), torch.nn.Linear(4, 8))
        self.validity_head = torch.nn.Linear(8, 5)
        self.condition_head = torch.nn.Linear(8, condition_classes)

    def forward(self, images):
        features = self.shared(self.pool(self.backbone(images)))
        return self.validity_head(features), self.condition_head(features)

    def set_backbone_trainable(self, trainable: bool) -> None:
        for parameter in self.backbone.parameters():
            parameter.requires_grad = trainable


def test_one_epoch_writes_receipt_metrics_and_resumable_checkpoint(
    tmp_path: Path, monkeypatch
) -> None:
    rows = []
    specifications = [
        ("train", "rust", "usable_target_leaf"),
        ("train", "healthy", "usable_target_leaf"),
        ("train", "not_applicable", "non_plant"),
        ("train", "rust", "usable_target_leaf"),
        ("validation", "rust", "usable_target_leaf"),
        ("validation", "healthy", "usable_target_leaf"),
        ("validation", "not_applicable", "non_plant"),
        ("calibration", "rust", "usable_target_leaf"),
        ("calibration", "healthy", "usable_target_leaf"),
        ("calibration", "not_applicable", "non_plant"),
        ("test", "rust", "usable_target_leaf"),
        ("test", "healthy", "usable_target_leaf"),
        ("test", "not_applicable", "non_plant"),
    ]
    for index, (split, condition, validity) in enumerate(specifications):
        path = tmp_path / f"image_{index}.png"
        Image.new("RGB", (30 + index, 40), color=(index * 20, 90, 40)).save(path)
        rows.append(
            {
                "image_path": str(path),
                "crop": "maize" if validity != "non_plant" else "unknown",
                "condition_label": condition,
                "validity_label": validity,
                "split": split,
                "source_id": "fixture",
                "group_id": f"group_{index}",
                "is_field": "1",
            }
        )
    manifest = tmp_path / "manifest.csv"
    pd.DataFrame(rows).to_csv(manifest, index=False)
    repo_root = Path(__file__).resolve().parents[2]
    config = {
        "schema_version": 1,
        "_config_path": str(repo_root / "ml" / "configs" / "smoke.json"),
        "manifest": str(manifest),
        "image_root": str(tmp_path),
        "seed": 7,
        "image_size": 32,
        "batch_size": 2,
        "num_workers": 0,
        "epochs": 1,
        "learning_rate": 1e-3,
        "backbone_learning_rate_multiplier": 1.0,
        "weight_decay": 0.0,
        "pretrained": False,
        "amp": False,
        "mixup_alpha": 0.0,
        "label_smoothing": 0.0,
        "early_stopping_patience": 2,
        "monitor": "condition_macro_f1",
    }
    monkeypatch.setattr(
        pipeline,
        "create_model",
        lambda architecture, class_count, pretrained: _TinyTwoHead(class_count),
    )
    output = tmp_path / "run"
    result = pipeline.train_experiment(
        config=config,
        crop="maize",
        architecture="mobilenet_v3_large",
        condition_labels=["rust", "healthy"],
        output_dir=output,
        device_name="cpu",
    )
    assert Path(result["best_checkpoint"]).is_file()
    assert (output / "last.pt").is_file()
    assert (output / "run_receipt.json").is_file()
    assert (output / "history.json").is_file()
    with (output / "history.json").open("r", encoding="utf-8") as handle:
        history = json.load(handle)
    assert history[0]["train"]["condition_outlier_exposure_weight"] == 0.0
    assert history[0]["train"]["condition_outlier_exposure_count"] == 0
    assert history[0]["train"]["condition_outlier_exposure_loss"] is None

    resumed = pipeline.train_experiment(
        config=config,
        crop="maize",
        architecture="mobilenet_v3_large",
        condition_labels=["rust", "healthy"],
        output_dir=output,
        resume=output / "last.pt",
        device_name="cpu",
    )
    assert resumed["epochs_completed"] == 1
    assert (output / "resume_receipt_epoch_1.json").is_file()

    calibration_path = output / "calibration.json"
    calibration = pipeline.calibrate_checkpoint(
        checkpoint_path=output / "best.pt",
        config=config,
        manifest_path=manifest,
        split="calibration",
        output_path=calibration_path,
        target_false_accept_rate=0.5,
        device_name="cpu",
    )
    assert calibration_path.is_file()
    assert calibration["manifest_split"] == "calibration"
    assert calibration["config_sha256"] == pipeline.config_hash(config)

    report = pipeline.evaluate_checkpoint(
        checkpoint_path=output / "best.pt",
        config=config,
        manifest_path=manifest,
        split="test",
        output_dir=output / "evaluation",
        calibration_path=calibration_path,
        device_name="cpu",
    )
    assert report["metrics"]["sample_count"] == 3
    assert report["config_sha256"] == pipeline.config_hash(config)
    assert report["effective_config_sha256"] == pipeline.config_hash(config)
    assert report["training_config_sha256"] == pipeline.config_hash(config)
    domain = report["evaluation_domain"]
    assert domain["source_ids"] == ["fixture"]
    assert domain["source_locked_to_split"] is False
    assert domain["independent_from_training"] is False
    assert domain["sample_count"] == 3
    assert domain["evidence_role"] == "unknown"
    assert domain["selection_independent"] is False
    assert domain["promotion_eligible"] is False
    assert domain["source_evidence"]["fixture"]["policy_status"] == "unknown_source"
    assert domain["evidence_policy"]["policy_id"] == "krishidoc-source-evidence-v1"
    assert (output / "evaluation" / "metrics_test.json").is_file()
    assert (output / "evaluation" / "predictions_test.csv").is_file()

    incompatible_output = output / "incompatible-config-evaluation"
    with pytest.raises(ValueError, match="Effective evaluation config"):
        pipeline.evaluate_checkpoint(
            checkpoint_path=output / "best.pt",
            config={**config, "max_eval_samples": 1},
            manifest_path=manifest,
            split="test",
            output_dir=incompatible_output,
            calibration_path=calibration_path,
            device_name="cpu",
        )
    assert not incompatible_output.exists()

    incomplete_calibration = dict(calibration)
    del incomplete_calibration["config_sha256"]
    incomplete_calibration_path = output / "incomplete-calibration.json"
    incomplete_calibration_path.write_text(
        json.dumps(incomplete_calibration), encoding="utf-8"
    )
    incomplete_output = output / "incomplete-calibration-evaluation"
    with pytest.raises(ValueError, match="config_sha256"):
        pipeline.evaluate_checkpoint(
            checkpoint_path=output / "best.pt",
            config=config,
            manifest_path=manifest,
            split="test",
            output_dir=incomplete_output,
            calibration_path=incomplete_calibration_path,
            device_name="cpu",
        )
    assert not incomplete_output.exists()
