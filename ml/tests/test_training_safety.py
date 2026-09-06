from __future__ import annotations

import hashlib
import math
from pathlib import Path

import pandas as pd
import pytest
import torch
from PIL import Image

from krishidoc_ml.checkpoint import load_training_checkpoint, save_checkpoint
from krishidoc_ml.config import config_hash
from krishidoc_ml.manifest import (
    ManifestDataset,
    ManifestValidationError,
    apply_unconfigured_condition_policy,
    validate_manifest,
)
from krishidoc_ml.pipeline import (
    _assert_effective_config_identity,
    _assert_evaluation_manifest_identity,
    _condition_outlier_exposure_weight,
    _condition_stratified_mixup_permutation,
    _train_one_epoch,
    _uniform_condition_kl,
    _validate_calibration_artifact_identity,
    calibrate_checkpoint,
    train_experiment,
)


def _row(
    image_path: Path,
    *,
    split: str,
    condition: str,
    group: str,
) -> dict[str, str]:
    return {
        "image_path": str(image_path),
        "crop": "maize",
        "condition_label": condition,
        "validity_label": "usable_target_leaf",
        "split": split,
        "source_id": "fixture",
        "group_id": group,
    }


def test_unconfigured_conditions_are_rejected_or_explicitly_mapped_unknown(
    tmp_path: Path,
) -> None:
    image_path = tmp_path / "leaf.png"
    Image.new("RGB", (8, 8), color=(20, 100, 30)).save(image_path)
    frame = pd.DataFrame(
        [
            _row(
                image_path,
                split="train",
                condition="maize_northern_leaf_blight",
                group="g1",
            )
        ]
    )

    with pytest.raises(ManifestValidationError, match="outside the crop taxonomy"):
        apply_unconfigured_condition_policy(
            frame,
            ["maize_common_rust", "maize_healthy"],
            policy="reject",
            unknown_condition_label="maize_other_unknown",
        )

    mapped = apply_unconfigured_condition_policy(
        frame,
        ["maize_common_rust", "maize_healthy"],
        policy="as_unknown",
        unknown_condition_label="maize_other_unknown",
    )
    assert mapped.loc[0, "condition_label"] == "maize_other_unknown"
    dataset = ManifestDataset(
        mapped,
        ["maize_common_rust", "maize_healthy"],
        transform=lambda _: torch.zeros(3, 8, 8),
        image_root=tmp_path,
        unknown_condition_label="maize_other_unknown",
    )
    assert dataset[0]["condition_target"] == -1
    assert dataset[0]["condition_outlier_exposure_target"] is True

    legacy_dataset = ManifestDataset(
        mapped,
        ["maize_common_rust", "maize_healthy"],
        transform=lambda _: torch.zeros(3, 8, 8),
        image_root=tmp_path,
    )
    assert legacy_dataset[0]["condition_outlier_exposure_target"] is False


def test_training_fails_closed_when_validation_does_not_cover_every_class(
    tmp_path: Path,
) -> None:
    paths = []
    for index in range(3):
        path = tmp_path / f"leaf_{index}.png"
        Image.new("RGB", (8, 8), color=(index * 20, 100, 30)).save(path)
        paths.append(path)
    manifest_path = tmp_path / "manifest.csv"
    pd.DataFrame(
        [
            _row(paths[0], split="train", condition="rust", group="g0"),
            _row(paths[1], split="train", condition="healthy", group="g1"),
            _row(paths[2], split="validation", condition="rust", group="g2"),
        ]
    ).to_csv(manifest_path, index=False)
    repo_root = Path(__file__).resolve().parents[2]
    config = {
        "schema_version": 1,
        "_config_path": str(repo_root / "ml" / "configs" / "smoke.json"),
        "manifest": str(manifest_path),
        "image_root": str(tmp_path),
        "monitor": "condition_macro_f1",
        "max_train_samples": 0,
        "max_eval_samples": 0,
    }
    with pytest.raises(ValueError, match="validation split.*healthy"):
        train_experiment(
            config=config,
            crop="maize",
            architecture="mobilenet_v3_large",
            condition_labels=["rust", "healthy"],
            output_dir=tmp_path / "run",
            device_name="cpu",
        )


def test_training_rejects_mixed_condition_group_before_writing_receipt(
    tmp_path: Path,
) -> None:
    paths = []
    for index in range(3):
        path = tmp_path / f"conflict_{index}.png"
        Image.new("RGB", (8, 8), color=(index * 20, 100, 30)).save(path)
        paths.append(path)
    manifest_path = tmp_path / "manifest.csv"
    pd.DataFrame(
        [
            _row(paths[0], split="train", condition="rust", group="conflict"),
            _row(paths[1], split="train", condition="healthy", group="conflict"),
            _row(paths[2], split="validation", condition="rust", group="validation"),
        ]
    ).to_csv(manifest_path, index=False)
    repo_root = Path(__file__).resolve().parents[2]
    output = tmp_path / "run"
    config = {
        "schema_version": 1,
        "_config_path": str(repo_root / "ml" / "configs" / "smoke.json"),
        "manifest": str(manifest_path),
        "image_root": str(tmp_path),
        "monitor": "condition_macro_f1",
    }

    with pytest.raises(
        ManifestValidationError,
        match="conflicting canonical condition labels.*quarantine each whole group",
    ):
        train_experiment(
            config=config,
            crop="maize",
            architecture="mobilenet_v3_large",
            condition_labels=["rust", "healthy"],
            output_dir=output,
            device_name="cpu",
        )

    assert not (output / "run_receipt.json").exists()


def test_file_hash_is_verified_when_manifest_supplies_sha256(tmp_path: Path) -> None:
    image_path = tmp_path / "leaf.png"
    Image.new("RGB", (8, 8), color=(20, 100, 30)).save(image_path)
    frame = pd.DataFrame(
        [
            {
                **_row(image_path, split="train", condition="rust", group="g0"),
                "sha256": hashlib.sha256(b"different bytes").hexdigest(),
            }
        ]
    )
    with pytest.raises(ManifestValidationError, match="SHA-256"):
        validate_manifest(frame, check_files=True, image_root=tmp_path)


def test_resume_rejects_a_changed_manifest_hash(tmp_path: Path) -> None:
    model = torch.nn.Linear(2, 2)
    optimizer = torch.optim.AdamW(model.parameters(), lr=1e-3)
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(optimizer, T_max=1)
    scaler = torch.amp.GradScaler("cpu", enabled=False)
    checkpoint_path = tmp_path / "last.pt"
    save_checkpoint(
        checkpoint_path,
        model=model,
        optimizer=optimizer,
        scheduler=scheduler,
        scaler=scaler,
        epoch=0,
        best_metric=0.5,
        epochs_without_improvement=0,
        metadata={"config_hash": "same", "manifest_sha256": "original"},
    )
    with pytest.raises(ValueError, match="manifest hash"):
        load_training_checkpoint(
            checkpoint_path,
            model=model,
            optimizer=optimizer,
            scheduler=scheduler,
            scaler=scaler,
            expected_config_hash="same",
            expected_manifest_hash="changed",
        )


def test_evaluation_rejects_a_changed_manifest_hash() -> None:
    with pytest.raises(ValueError, match="Evaluation manifest hash"):
        _assert_evaluation_manifest_identity(
            {"manifest_sha256": "a" * 64},
            "b" * 64,
        )


def test_evaluation_requires_a_canonical_manifest_identity() -> None:
    for missing_or_invalid in (None, "", "A" * 64, "not-a-digest"):
        with pytest.raises(ValueError, match="training-manifest SHA-256"):
            _assert_evaluation_manifest_identity(
                {"manifest_sha256": missing_or_invalid},
                "b" * 64,
            )


def test_evaluation_config_must_be_identical_to_checkpoint_config() -> None:
    stored = {"schema_version": 1, "seed": 7, "max_eval_samples": None}
    digest = config_hash(stored)
    checkpoint = {"config": stored, "config_hash": digest}

    assert _assert_effective_config_identity(
        checkpoint,
        {**stored, "_config_path": "ignored-by-canonical-hash.json"},
    ) == digest

    with pytest.raises(ValueError, match="Effective evaluation config"):
        _assert_effective_config_identity(
            checkpoint,
            {**stored, "max_eval_samples": 1},
        )

    with pytest.raises(ValueError, match="does not match its recorded hash"):
        _assert_effective_config_identity(
            {"config": {**stored, "seed": 8}, "config_hash": digest},
            stored,
        )


def _valid_calibration_identity_fixture() -> tuple[dict[str, object], dict[str, str]]:
    checkpoint = {
        "crop": "maize",
        "architecture": "mobilenet_v3_large",
    }
    artifact: dict[str, object] = {
        "schema_version": 1,
        "method": "scalar_temperature_plus_three_signal_grid_gate",
        "checkpoint_sha256": "a" * 64,
        "manifest_sha256": "b" * 64,
        "config_sha256": "c" * 64,
        "manifest_split": "calibration",
        "crop": "maize",
        "architecture": "mobilenet_v3_large",
        "validity_temperature": 1.0,
        "condition_temperature": 1.0,
        "thresholds": {
            "validity_probability_min": 0.5,
            "condition_probability_min": 0.6,
            "condition_energy_max": -1.0,
        },
        "validation_counts": {"total": 10, "known": 7, "ood": 3},
    }
    return artifact, checkpoint


def test_calibration_identity_requires_complete_exact_schema() -> None:
    artifact, checkpoint = _valid_calibration_identity_fixture()
    _validate_calibration_artifact_identity(
        artifact,
        checkpoint=checkpoint,
        checkpoint_sha256="a" * 64,
        manifest_sha256="b" * 64,
        effective_config_sha256="c" * 64,
    )


@pytest.mark.parametrize(
    ("field", "replacement", "message"),
    [
        ("schema_version", "1", "schema_version"),
        ("method", "legacy_gate", "method"),
        ("checkpoint_sha256", "d" * 64, "checkpoint_sha256"),
        ("manifest_sha256", "d" * 64, "manifest_sha256"),
        ("config_sha256", "d" * 64, "config_sha256"),
        ("crop", "potato", "crop"),
        ("architecture", "efficientnet_b0", "architecture"),
        ("manifest_split", "test", "calibration split"),
    ],
)
def test_calibration_identity_rejects_incompatible_artifacts(
    field: str, replacement: object, message: str
) -> None:
    artifact, checkpoint = _valid_calibration_identity_fixture()
    artifact[field] = replacement

    with pytest.raises(ValueError, match=message):
        _validate_calibration_artifact_identity(
            artifact,
            checkpoint=checkpoint,
            checkpoint_sha256="a" * 64,
            manifest_sha256="b" * 64,
            effective_config_sha256="c" * 64,
        )


@pytest.mark.parametrize(
    ("field", "message"),
    [
        ("checkpoint_sha256", "checkpoint_sha256"),
        ("manifest_sha256", "manifest_sha256"),
        ("config_sha256", "config_sha256"),
        ("crop", "crop"),
        ("architecture", "architecture"),
    ],
)
def test_calibration_identity_rejects_missing_identity_fields(
    field: str, message: str
) -> None:
    artifact, checkpoint = _valid_calibration_identity_fixture()
    del artifact[field]

    with pytest.raises(ValueError, match=message):
        _validate_calibration_artifact_identity(
            artifact,
            checkpoint=checkpoint,
            checkpoint_sha256="a" * 64,
            manifest_sha256="b" * 64,
            effective_config_sha256="c" * 64,
        )


def test_calibration_refuses_test_split_before_loading_checkpoint(
    tmp_path: Path,
) -> None:
    with pytest.raises(ValueError, match="locked `calibration` split"):
        calibrate_checkpoint(
            checkpoint_path=tmp_path / "missing.pt",
            config=None,
            manifest_path=None,
            split="test",
            output_path=tmp_path / "calibration.json",
            target_false_accept_rate=0.05,
            device_name="cpu",
        )


def test_mixup_keeps_condition_supervision_in_the_same_stratum() -> None:
    validity_targets = torch.tensor([0, 0, 0, 1, 2, 3, 4, 0])
    condition_targets = torch.tensor([0, 1, 0, -1, -1, -1, -1, -1])
    supervised = (validity_targets == 0) & (condition_targets >= 0)
    torch.manual_seed(12)
    permutation = _condition_stratified_mixup_permutation(
        validity_targets, condition_targets
    )
    assert sorted(permutation.tolist()) == list(range(len(condition_targets)))
    assert torch.equal(supervised, supervised[permutation])


def test_outlier_exposure_mixup_preserves_three_loss_strata() -> None:
    validity_targets = torch.tensor([0, 0, 0, 0, 1, 2, 3, 4])
    condition_targets = torch.tensor([0, 1, -1, -1, -1, -1, -1, -1])
    outlier_exposure = torch.tensor(
        [False, False, True, True, False, False, False, False]
    )
    known = (validity_targets == 0) & (condition_targets >= 0)
    other = ~(known | outlier_exposure)

    torch.manual_seed(23)
    permutation = _condition_stratified_mixup_permutation(
        validity_targets,
        condition_targets,
        condition_outlier_exposure_targets=outlier_exposure,
    )

    assert sorted(permutation.tolist()) == list(range(len(condition_targets)))
    assert torch.equal(known, known[permutation])
    assert torch.equal(outlier_exposure, outlier_exposure[permutation])
    assert torch.equal(other, other[permutation])


def test_omitted_outlier_exposure_mask_preserves_legacy_mixup_rng_path() -> None:
    validity_targets = torch.tensor([0, 0, 0, 1, 2, 3, 4, 0])
    condition_targets = torch.tensor([0, 1, 0, -1, -1, -1, -1, -1])

    torch.manual_seed(91)
    omitted = _condition_stratified_mixup_permutation(
        validity_targets, condition_targets
    )
    torch.manual_seed(91)
    explicit_none = _condition_stratified_mixup_permutation(
        validity_targets,
        condition_targets,
        condition_outlier_exposure_targets=None,
    )

    assert torch.equal(omitted, explicit_none)


def test_uniform_condition_kl_is_zero_at_uniform_and_penalises_confidence() -> None:
    uniform_logits = torch.zeros(3, 4, requires_grad=True)
    uniform_loss = _uniform_condition_kl(uniform_logits)
    assert uniform_loss.item() == pytest.approx(0.0, abs=1e-7)
    uniform_loss.backward()
    assert torch.isfinite(uniform_logits.grad).all()
    assert torch.max(torch.abs(uniform_logits.grad)).item() == pytest.approx(
        0.0, abs=1e-7
    )

    confident_logits = torch.tensor(
        [[8.0, -4.0, -4.0, -4.0]], requires_grad=True
    )
    confident_loss = _uniform_condition_kl(confident_logits)
    assert confident_loss.item() > 0.0
    confident_loss.backward()
    assert torch.isfinite(confident_logits.grad).all()
    assert confident_logits.grad[0, 0].item() > 0.0
    assert confident_logits.grad[0, 1].item() < 0.0


class _ConstantTwoHead(torch.nn.Module):
    def __init__(self) -> None:
        super().__init__()
        self.validity_logits = torch.nn.Parameter(torch.zeros(5))
        self.condition_logits = torch.nn.Parameter(torch.tensor([4.0, -4.0]))

    def forward(self, images: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        count = len(images)
        return (
            self.validity_logits.unsqueeze(0).expand(count, -1),
            self.condition_logits.unsqueeze(0).expand(count, -1),
        )


def _one_epoch_batch(*, include_marker: bool = True) -> dict[str, torch.Tensor]:
    batch = {
        "image": torch.zeros(4, 3, 8, 8),
        "validity_target": torch.tensor([0, 0, 0, 1]),
        "condition_target": torch.tensor([0, 1, -1, -1]),
    }
    if include_marker:
        batch["condition_outlier_exposure_target"] = torch.tensor(
            [False, False, True, False]
        )
    return batch


def _run_one_epoch(
    *, weight: float, include_marker: bool = True
) -> dict[str, float | int | str | None]:
    model = _ConstantTwoHead()
    optimizer = torch.optim.SGD(model.parameters(), lr=0.01)
    return _train_one_epoch(
        model=model,
        loader=[_one_epoch_batch(include_marker=include_marker)],
        optimizer=optimizer,
        scaler=torch.amp.GradScaler("cpu", enabled=False),
        device=torch.device("cpu"),
        amp_enabled=False,
        validity_class_weights=torch.ones(5),
        condition_class_weights=torch.ones(2),
        label_smoothing=0.0,
        condition_loss_weight=1.0,
        mixup_alpha=0.0,
        gradient_clip_norm=0.0,
        condition_outlier_exposure_weight=weight,
    )


def test_one_epoch_reports_explicit_unknown_exposure_loss_and_count() -> None:
    summary = _run_one_epoch(weight=0.5)

    expected_kl = _uniform_condition_kl(torch.tensor([[4.0, -4.0]])).item()
    assert summary["condition_supervised_count"] == 2
    assert summary["condition_outlier_exposure_count"] == 1
    assert summary["condition_outlier_exposure_objective"] == (
        "kl_uniform_to_prediction_v1"
    )
    assert summary["condition_outlier_exposure_loss"] == pytest.approx(expected_kl)
    assert summary["condition_outlier_exposure_weighted_loss"] == pytest.approx(
        0.5 * expected_kl
    )


def test_zero_weight_is_backward_compatible_with_loader_without_marker() -> None:
    summary = _run_one_epoch(weight=0.0, include_marker=False)

    assert summary["condition_supervised_count"] == 2
    assert summary["condition_outlier_exposure_count"] == 0
    assert summary["condition_outlier_exposure_loss"] is None
    assert summary["condition_outlier_exposure_weighted_loss"] is None


def test_disabled_exposure_leaves_condition_head_untouched_on_negative_batch() -> None:
    model = _ConstantTwoHead()
    original = model.condition_logits.detach().clone()
    optimizer = torch.optim.AdamW(model.parameters(), lr=0.01, weight_decay=0.1)
    summary = _train_one_epoch(
        model=model,
        loader=[
            {
                "image": torch.zeros(3, 3, 8, 8),
                "validity_target": torch.tensor([1, 2, 4]),
                "condition_target": torch.tensor([-1, -1, -1]),
            }
        ],
        optimizer=optimizer,
        scaler=torch.amp.GradScaler("cpu", enabled=False),
        device=torch.device("cpu"),
        amp_enabled=False,
        validity_class_weights=torch.ones(5),
        condition_class_weights=torch.ones(2),
        label_smoothing=0.0,
        condition_loss_weight=1.0,
        mixup_alpha=0.0,
        gradient_clip_norm=0.0,
    )

    assert summary["condition_outlier_exposure_count"] == 0
    assert model.condition_logits.grad is None
    assert model.condition_logits not in optimizer.state
    assert torch.equal(model.condition_logits.detach(), original)


def test_outlier_exposure_weight_defaults_to_zero_and_rejects_invalid_values() -> None:
    assert _condition_outlier_exposure_weight({}) == 0.0
    assert _condition_outlier_exposure_weight(
        {"condition_outlier_exposure_weight": 0.25}
    ) == pytest.approx(0.25)
    for invalid in (-0.1, math.inf, -math.inf, math.nan, None, "bad"):
        with pytest.raises(ValueError, match="finite number >= 0"):
            _condition_outlier_exposure_weight(
                {"condition_outlier_exposure_weight": invalid}
            )


def test_enabled_outlier_exposure_requires_explicit_unknown_training_rows(
    tmp_path: Path,
) -> None:
    paths = []
    for index in range(4):
        path = tmp_path / f"known_{index}.png"
        Image.new("RGB", (8, 8), color=(index * 20, 100, 30)).save(path)
        paths.append(path)
    manifest_path = tmp_path / "manifest.csv"
    pd.DataFrame(
        [
            _row(paths[0], split="train", condition="rust", group="g0"),
            _row(paths[1], split="train", condition="healthy", group="g1"),
            _row(paths[2], split="validation", condition="rust", group="g2"),
            _row(paths[3], split="validation", condition="healthy", group="g3"),
        ]
    ).to_csv(manifest_path, index=False)
    repo_root = Path(__file__).resolve().parents[2]
    output = tmp_path / "run"
    config = {
        "schema_version": 1,
        "_config_path": str(repo_root / "ml" / "configs" / "smoke.json"),
        "manifest": str(manifest_path),
        "image_root": str(tmp_path),
        "monitor": "condition_macro_f1",
        "condition_outlier_exposure_weight": 0.1,
    }

    with pytest.raises(ValueError, match="contain no usable.*other_unknown"):
        train_experiment(
            config=config,
            crop="maize",
            architecture="mobilenet_v3_large",
            condition_labels=["rust", "healthy"],
            output_dir=output,
            device_name="cpu",
        )

    assert not (output / "run_receipt.json").exists()


def test_enabled_outlier_exposure_rejects_unknown_as_a_known_head_class(
    tmp_path: Path,
) -> None:
    repo_root = Path(__file__).resolve().parents[2]
    with pytest.raises(ValueError, match="must not be a known condition-head class"):
        train_experiment(
            config={
                "schema_version": 1,
                "_config_path": str(repo_root / "ml" / "configs" / "smoke.json"),
                "condition_outlier_exposure_weight": 0.1,
            },
            crop="maize",
            architecture="mobilenet_v3_large",
            condition_labels=["maize_other_unknown", "maize_healthy"],
            output_dir=tmp_path / "run",
            device_name="cpu",
        )

    assert not (tmp_path / "run" / "run_receipt.json").exists()
