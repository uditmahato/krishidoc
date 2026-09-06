"""Training, prediction, calibration, and evaluation orchestration."""

from __future__ import annotations

import json
import math
import re
import time
from collections.abc import Mapping
from contextlib import nullcontext
from pathlib import Path
from typing import Any, Iterable

import numpy as np
import pandas as pd
import torch
from torch.nn import functional as F
from torch.utils.data import DataLoader

from .calibration import apply_calibration, fit_calibration
from .checkpoint import initialize_finetune, load_training_checkpoint, save_checkpoint
from .config import config_hash, find_repo_root
from .constants import USABLE_VALIDITY_LABEL, VALIDITY_LABELS, VALIDITY_TO_INDEX
from .data_snapshot import verify_training_data_snapshot
from .evidence import resolve_source_evidence
from .manifest import (
    ManifestDataset,
    deterministic_limit,
    parse_bool,
    read_manifest,
    source_balanced_sampler,
    task_source_balanced_sampler,
)
from .metrics import compute_metrics
from .model import CropSpecificTwoHeadModel, create_model
from .receipt import create_run_receipt, file_sha256, write_json_atomic
from .reproducibility import make_generator, resolve_device, seed_everything, seed_worker
from .transforms import build_transform


_SHA256_PATTERN = re.compile(r"^[0-9a-f]{64}$")

SAFETY_COMPOSITE_MONITOR = "safety_composite_v1"
SAFETY_COMPOSITE_WEIGHTS: dict[str, float] = {
    "field_condition_macro_f1": 0.50,
    "validity_balanced_accuracy": 0.25,
    "joint_ood_auroc": 0.25,
}


def train_experiment(
    *,
    config: dict[str, Any],
    crop: str,
    architecture: str,
    condition_labels: list[str],
    output_dir: str | Path,
    resume: str | Path | None = None,
    device_name: str = "auto",
) -> dict[str, Any]:
    repo_root = find_repo_root(config.get("_config_path", Path.cwd()))
    seed = int(config.get("seed", 0))
    seed_everything(seed, deterministic=bool(config.get("deterministic", True)))
    device = resolve_device(device_name)
    if config.get('require_cuda', False) and device.type != 'cuda':
        raise ValueError('This experiment requires CUDA; CPU fallback is forbidden')
    finetune = config.get('finetune_from')
    sampling = config.get('sampling_strategy', 'source_balanced')
    if sampling not in ('source_balanced', 'task_source_balanced_v1'):
        raise ValueError(f'Unsupported sampling strategy: {sampling}')
    amp_enabled = bool(config.get("amp", True)) and device.type == "cuda"
    condition_outlier_exposure_weight = _condition_outlier_exposure_weight(config)
    unknown_condition_label = str(
        config.get("unknown_label", f"{crop}_other_unknown")
    )
    if (
        condition_outlier_exposure_weight > 0.0
        and unknown_condition_label != f"{crop}_other_unknown"
    ):
        raise ValueError(
            "condition_outlier_exposure_weight may only supervise the canonical "
            f"explicit unknown label {crop + '_other_unknown'!r}; received "
            f"{unknown_condition_label!r}"
        )
    if condition_outlier_exposure_weight > 0.0 and len(condition_labels) < 2:
        raise ValueError(
            "Condition outlier exposure requires at least two known condition "
            "classes; a one-class head cannot express uncertainty"
        )
    if (
        condition_outlier_exposure_weight > 0.0
        and unknown_condition_label in condition_labels
    ):
        raise ValueError(
            "The explicit unknown condition label must not be a known "
            "condition-head class when outlier exposure is enabled"
        )

    manifest_path = _resolve_path(config["manifest"], repo_root)
    manifest_digest = file_sha256(manifest_path)
    verify_training_data_snapshot(
        config=config,
        manifest_path=manifest_path,
        repo_root=repo_root,
        manifest_sha256=manifest_digest,
    )
    image_root = _resolve_path(config.get("image_root", repo_root), repo_root)
    output = Path(output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)

    full_frame = read_manifest(
        manifest_path,
        crop=crop,
        condition_labels=condition_labels,
        check_files=True,
        image_root=image_root,
        unconfigured_conditions=str(config.get("unconfigured_conditions", "reject")),
        unknown_condition_label=unknown_condition_label,
    )
    train_frame = deterministic_limit(
        full_frame.loc[full_frame["split"] == "train"].reset_index(drop=True),
        _optional_int(config.get("max_train_samples")),
        seed,
    )
    validation_frame = deterministic_limit(
        full_frame.loc[full_frame["split"] == "validation"].reset_index(drop=True),
        _optional_int(config.get("max_eval_samples")),
        seed + 1,
    )
    if train_frame.empty or validation_frame.empty:
        raise ValueError(
            f"Training requires non-empty train and validation rows for {crop}; "
            f"got {len(train_frame)} and {len(validation_frame)}"
        )
    condition_outlier_exposure_manifest_count = int(
        (
            train_frame["validity_label"].eq(USABLE_VALIDITY_LABEL)
            & train_frame["condition_label"].eq(unknown_condition_label)
        ).sum()
    )
    if (
        condition_outlier_exposure_weight > 0.0
        and condition_outlier_exposure_manifest_count == 0
    ):
        raise ValueError(
            "condition_outlier_exposure_weight is enabled, but the selected "
            f"training rows contain no usable {unknown_condition_label!r} examples"
        )
    monitor_name = str(config.get("monitor", "condition_macro_f1"))
    _assert_training_coverage(
        train_frame,
        validation_frame,
        condition_labels,
        monitor_name=monitor_name,
        safety_composite_validation_contract=config.get(
            "safety_composite_validation_contract"
        ),
    )

    image_size = int(config.get("image_size", 224))
    train_dataset = ManifestDataset(
        train_frame,
        condition_labels,
        build_transform(image_size, training=True),
        image_root,
        unknown_condition_label=unknown_condition_label,
    )
    validation_dataset = ManifestDataset(
        validation_frame,
        condition_labels,
        build_transform(image_size, training=False),
        image_root,
        unknown_condition_label=unknown_condition_label,
    )
    validation_loader = _make_loader(
        validation_dataset,
        batch_size=int(config.get("batch_size", 32)),
        num_workers=int(config.get("num_workers", 0)),
        seed=seed + 10_000,
        device=device,
    )

    model = create_model(
        architecture,
        len(condition_labels),
        pretrained=bool(config.get("pretrained", True)) and resume is None and not finetune,
    ).to(device)
    if finetune and resume is None:
        initialize_finetune(
            _resolve_path(finetune['path'], repo_root), model=model,
            expected_sha256=finetune['sha256'], crop=crop,
            architecture=architecture, condition_labels=condition_labels,
            validity_labels=list(VALIDITY_LABELS), image_size=image_size,
            manifest_sha256=manifest_digest,
        )
    optimizer = _create_optimizer(model, config)
    epochs = int(config.get("epochs", 20))
    scheduler = torch.optim.lr_scheduler.CosineAnnealingLR(
        optimizer, T_max=max(1, epochs), eta_min=float(config.get("minimum_learning_rate", 1e-6))
    )
    scaler = torch.amp.GradScaler(device.type, enabled=amp_enabled)

    starting_epoch = 0
    best_metric = -math.inf
    stale_epochs = 0
    config_digest = config_hash(config)
    if resume is not None:
        checkpoint = load_training_checkpoint(
            resume,
            model=model,
            optimizer=optimizer,
            scheduler=scheduler,
            scaler=scaler,
            expected_config_hash=config_digest,
            expected_manifest_hash=manifest_digest,
        )
        _assert_checkpoint_identity(checkpoint, crop, architecture, condition_labels)
        _optimizer_to(optimizer, device)
        starting_epoch = int(checkpoint["epoch"]) + 1
        best_metric = float(checkpoint["best_metric"])
        stale_epochs = int(checkpoint["epochs_without_improvement"])

    receipt = create_run_receipt(
        repo_root=repo_root,
        config=config,
        manifest_path=manifest_path,
        crop=crop,
        architecture=architecture,
        seed=seed,
        device=device,
        extra_files={
            "taxonomy": repo_root / "ml" / "datasets" / "taxonomy_v1.json",
            "manifest_schema": repo_root
            / "ml"
            / "datasets"
            / "manifest_schema_v1.json",
        },
    )
    receipt_name = "run_receipt.json" if resume is None else f"resume_receipt_epoch_{starting_epoch}.json"
    write_json_atomic(output / receipt_name, receipt)

    history_path = output / "history.json"
    history: list[dict[str, Any]] = _load_history(history_path) if resume else []
    patience = int(config.get("early_stopping_patience", 5))
    freeze_epochs = int(config.get("freeze_backbone_epochs", 0))
    started = time.monotonic()

    for epoch in range(starting_epoch, epochs):
        model.set_backbone_trainable(epoch >= freeze_epochs)
        # Epoch-derived generators make the sample order and worker augmentation
        # streams identical after resume without serialising DataLoader workers.
        train_loader = _make_loader(
            train_dataset,
            batch_size=int(config.get("batch_size", 32)),
            num_workers=int(config.get("num_workers", 0)),
            seed=seed + epoch,
            device=device,
            sampler=(task_source_balanced_sampler(
                train_frame, seed + epoch,
                config.get('samples_per_epoch', len(train_frame)),
            ) if sampling == 'task_source_balanced_v1'
                else source_balanced_sampler(train_frame, seed + epoch)),
        )
        train_summary = _train_one_epoch(
            model=model,
            loader=train_loader,
            optimizer=optimizer,
            scaler=scaler,
            device=device,
            amp_enabled=amp_enabled,
            validity_class_weights=(torch.ones(len(VALIDITY_LABELS), device=device)
                if sampling == 'task_source_balanced_v1' else _class_weights(
                train_frame["validity_label"].map(
                    {label: index for index, label in enumerate(VALIDITY_LABELS)}
                ).to_numpy(),
                len(VALIDITY_LABELS),
                device,
            )),
            condition_class_weights=(torch.ones(len(condition_labels), device=device)
                if sampling == 'task_source_balanced_v1' else _condition_class_weights(
                train_frame, condition_labels, device
            )),
            label_smoothing=float(config.get("label_smoothing", 0.0)),
            condition_loss_weight=float(config.get("condition_loss_weight", 1.0)),
            condition_outlier_exposure_weight=condition_outlier_exposure_weight,
            mixup_alpha=float(config.get("mixup_alpha", 0.0)),
            gradient_clip_norm=float(config.get("gradient_clip_norm", 5.0)),
        )
        validation_predictions = predict_loader(
            model, validation_loader, device=device, amp_enabled=amp_enabled
        )
        validation_metrics = compute_metrics(
            **_metric_arguments(validation_predictions, condition_labels)
        )
        monitored = _monitor_value(validation_metrics, monitor_name)
        improved = monitored is not None and monitored > best_metric + float(
            config.get("early_stopping_min_delta", 1e-4)
        )
        if improved:
            best_metric = float(monitored)
            stale_epochs = 0
        else:
            stale_epochs += 1
        scheduler.step()

        epoch_record = {
            "epoch": epoch,
            "learning_rates": [group["lr"] for group in optimizer.param_groups],
            "train": train_summary,
            "validation": validation_metrics,
            "monitor": {"name": monitor_name, "value": monitored},
            "improved": improved,
            "elapsed_seconds": time.monotonic() - started,
        }
        history.append(epoch_record)
        write_json_atomic(history_path, history)
        metadata = {
            "crop": crop,
            "architecture": architecture,
            "condition_labels": condition_labels,
            "validity_labels": list(VALIDITY_LABELS),
            "config": {key: value for key, value in config.items() if not key.startswith("_")},
            "config_hash": config_digest,
            "manifest_sha256": manifest_digest,
            "image_size": image_size,
        }
        save_checkpoint(
            output / "last.pt",
            model=model,
            optimizer=optimizer,
            scheduler=scheduler,
            scaler=scaler,
            epoch=epoch,
            best_metric=best_metric,
            epochs_without_improvement=stale_epochs,
            metadata=metadata,
        )
        if improved:
            save_checkpoint(
                output / "best.pt",
                model=model,
                optimizer=optimizer,
                scheduler=scheduler,
                scaler=scaler,
                epoch=epoch,
                best_metric=best_metric,
                epochs_without_improvement=stale_epochs,
                metadata=metadata,
            )
        print(
            json.dumps(
                {
                    "epoch": epoch,
                    "train_loss": train_summary["loss"],
                    "monitor": monitor_name,
                    "monitor_value": monitored,
                    "best": best_metric,
                    "stale_epochs": stale_epochs,
                },
                sort_keys=True,
            ),
            flush=True,
        )
        if stale_epochs >= patience:
            break

    summary = {
        "crop": crop,
        "architecture": architecture,
        "output_dir": str(output),
        "best_checkpoint": str(output / "best.pt"),
        "last_checkpoint": str(output / "last.pt"),
        "best_metric": best_metric if math.isfinite(best_metric) else None,
        "monitor": monitor_name,
        "epochs_completed": len(history),
        "device": str(device),
        "amp_enabled": amp_enabled,
        "condition_outlier_exposure": {
            "objective": "kl_uniform_to_prediction_v1",
            "weight": condition_outlier_exposure_weight,
            "manifest_train_count": condition_outlier_exposure_manifest_count,
        },
    }
    write_json_atomic(output / "summary.json", summary)
    return summary


def calibrate_checkpoint(
    *,
    checkpoint_path: str | Path,
    config: dict[str, Any] | None,
    manifest_path: str | Path | None,
    split: str,
    output_path: str | Path,
    target_false_accept_rate: float,
    device_name: str = "auto",
) -> dict[str, Any]:
    if split != "calibration":
        raise ValueError(
            "Calibration may only be fitted on the locked `calibration` split; "
            f"received {split!r}."
        )
    bundle = load_model_bundle(checkpoint_path, device_name=device_name)
    effective_config = config or bundle["checkpoint"]["config"]
    predictions = _predict_for_checkpoint(
        bundle=bundle,
        config=effective_config,
        manifest_path=manifest_path,
        split=split,
    )
    calibration = fit_calibration(
        validity_logits=predictions["validity_logits"],
        condition_logits=predictions["condition_logits"],
        validity_targets=predictions["validity_targets"],
        condition_targets=predictions["condition_targets"],
        target_false_accept_rate=target_false_accept_rate,
    )
    calibration.update(
        {
            "crop": bundle["checkpoint"]["crop"],
            "architecture": bundle["checkpoint"]["architecture"],
            "checkpoint_sha256": file_sha256(checkpoint_path),
            "manifest_split": split,
            "manifest_sha256": predictions["manifest_sha256"],
            "config_sha256": predictions["effective_config_sha256"],
        }
    )
    write_json_atomic(output_path, calibration)
    return calibration


def evaluate_checkpoint(
    *,
    checkpoint_path: str | Path,
    config: dict[str, Any] | None,
    manifest_path: str | Path | None,
    split: str,
    output_dir: str | Path,
    calibration_path: str | Path | None = None,
    device_name: str = "auto",
) -> dict[str, Any]:
    bundle = load_model_bundle(checkpoint_path, device_name=device_name)
    effective_config = config or bundle["checkpoint"]["config"]
    predictions = _predict_for_checkpoint(
        bundle=bundle,
        config=effective_config,
        manifest_path=manifest_path,
        split=split,
    )
    calibration: dict[str, Any] | None = None
    calibrated: dict[str, np.ndarray] | None = None
    if calibration_path is not None:
        with Path(calibration_path).open("r", encoding="utf-8") as handle:
            calibration = json.load(handle)
        _validate_calibration_artifact_identity(
            calibration,
            checkpoint=bundle["checkpoint"],
            checkpoint_sha256=file_sha256(checkpoint_path),
            manifest_sha256=predictions["manifest_sha256"],
            effective_config_sha256=predictions["effective_config_sha256"],
        )
        calibrated = apply_calibration(
            calibration,
            predictions["validity_logits"],
            predictions["condition_logits"],
        )

    metrics = compute_metrics(
        **_metric_arguments(
            predictions,
            bundle["checkpoint"]["condition_labels"],
            calibration=calibration,
            calibrated=calibrated,
        )
    )
    output = Path(output_dir).resolve()
    output.mkdir(parents=True, exist_ok=True)
    report = {
        "schema_version": 1,
        "crop": bundle["checkpoint"]["crop"],
        "architecture": bundle["checkpoint"]["architecture"],
        "split": split,
        "checkpoint_sha256": file_sha256(checkpoint_path),
        # An explicit config override is accepted only when its canonical hash
        # equals the config stored in the checkpoint. Recording the effective
        # identity here therefore cannot silently attribute a filtered subset
        # or a different evidence policy to the training configuration.
        "config_sha256": predictions["effective_config_sha256"],
        "effective_config_sha256": predictions["effective_config_sha256"],
        "training_config_sha256": bundle["checkpoint"]["config_hash"],
        "calibration_sha256": (
            file_sha256(calibration_path) if calibration_path else None
        ),
        "manifest_sha256": predictions["manifest_sha256"],
        "evaluation_domain": predictions["evaluation_domain"],
        "metrics": metrics,
    }
    write_json_atomic(output / f"metrics_{split}.json", report)
    _write_predictions(
        output / f"predictions_{split}.csv",
        predictions,
        bundle["checkpoint"]["condition_labels"],
        calibrated,
    )
    return report


def load_model_bundle(
    checkpoint_path: str | Path, device_name: str = "auto"
) -> dict[str, Any]:
    device = resolve_device(device_name)
    checkpoint = torch.load(checkpoint_path, map_location="cpu", weights_only=False)
    model = create_model(
        checkpoint["architecture"],
        len(checkpoint["condition_labels"]),
        pretrained=False,
    )
    model.load_state_dict(checkpoint["model_state"])
    model.to(device).eval()
    return {"model": model, "checkpoint": checkpoint, "device": device}


@torch.inference_mode()
def predict_loader(
    model: CropSpecificTwoHeadModel,
    loader: DataLoader,
    *,
    device: torch.device,
    amp_enabled: bool,
) -> dict[str, Any]:
    model.eval()
    result: dict[str, list[Any]] = {
        "validity_logits": [],
        "condition_logits": [],
        "validity_targets": [],
        "condition_targets": [],
        "is_field": [],
        "image_path": [],
        "source_id": [],
        "group_id": [],
    }
    for batch in loader:
        images = batch["image"].to(device, non_blocking=True)
        context = (
            torch.autocast(device_type=device.type, dtype=torch.float16)
            if amp_enabled
            else nullcontext()
        )
        with context:
            validity_logits, condition_logits = model(images)
        result["validity_logits"].append(validity_logits.float().cpu().numpy())
        result["condition_logits"].append(condition_logits.float().cpu().numpy())
        result["validity_targets"].append(batch["validity_target"].numpy())
        result["condition_targets"].append(batch["condition_target"].numpy())
        field = batch["is_field"]
        result["is_field"].append(
            field.numpy() if torch.is_tensor(field) else np.asarray(field, dtype=bool)
        )
        for key in ("image_path", "source_id", "group_id"):
            result[key].extend(list(batch[key]))
    for key in (
        "validity_logits",
        "condition_logits",
        "validity_targets",
        "condition_targets",
        "is_field",
    ):
        result[key] = np.concatenate(result[key], axis=0)
    return result


def _train_one_epoch(
    *,
    model: CropSpecificTwoHeadModel,
    loader: DataLoader,
    optimizer: torch.optim.Optimizer,
    scaler: torch.amp.GradScaler,
    device: torch.device,
    amp_enabled: bool,
    validity_class_weights: torch.Tensor,
    condition_class_weights: torch.Tensor,
    label_smoothing: float,
    condition_loss_weight: float,
    mixup_alpha: float,
    gradient_clip_norm: float,
    condition_outlier_exposure_weight: float = 0.0,
) -> dict[str, float | int | str | None]:
    model.train()
    total_loss = 0.0
    total_validity_loss = 0.0
    total_condition_loss = 0.0
    total_condition_outlier_exposure_loss = 0.0
    total_samples = 0
    supervised_condition_samples = 0
    condition_outlier_exposure_samples = 0
    usable_index = VALIDITY_TO_INDEX[USABLE_VALIDITY_LABEL]

    for batch in loader:
        images = batch["image"].to(device, non_blocking=True)
        validity_targets = batch["validity_target"].to(device, non_blocking=True)
        condition_targets = batch["condition_target"].to(device, non_blocking=True)
        if condition_outlier_exposure_weight > 0.0:
            raw_outlier_exposure_targets = batch.get(
                "condition_outlier_exposure_target"
            )
            if raw_outlier_exposure_targets is None:
                raise ValueError(
                    "An outlier-exposure-enabled loader must provide "
                    "condition_outlier_exposure_target"
                )
            condition_outlier_exposure_targets = raw_outlier_exposure_targets.to(
                device, non_blocking=True, dtype=torch.bool
            )
            invalid_outlier_targets = condition_outlier_exposure_targets & (
                (validity_targets != usable_index) | (condition_targets >= 0)
            )
            if torch.any(invalid_outlier_targets):
                raise ValueError(
                    "Condition outlier exposure is restricted to usable "
                    "explicit-unknown rows without a known condition target"
                )
        else:
            # Preserve the legacy hot path: do not copy or inspect the new
            # marker, and therefore do not add a CUDA synchronisation point.
            condition_outlier_exposure_targets = None
        optimizer.zero_grad(set_to_none=True)

        permutation: torch.Tensor | None = None
        mix = 1.0
        if mixup_alpha > 0.0 and len(images) > 1:
            mix = float(np.random.beta(mixup_alpha, mixup_alpha))
            permutation = _condition_stratified_mixup_permutation(
                validity_targets,
                condition_targets,
                condition_outlier_exposure_targets=(
                    condition_outlier_exposure_targets
                ),
            )
            images = mix * images + (1.0 - mix) * images[permutation]

        context = (
            torch.autocast(device_type=device.type, dtype=torch.float16)
            if amp_enabled
            else nullcontext()
        )
        with context:
            validity_logits, condition_logits = model(images)
            validity_loss = _possibly_mixed_cross_entropy(
                validity_logits,
                validity_targets,
                permutation,
                mix,
                weight=validity_class_weights,
                label_smoothing=label_smoothing,
            )
            supervised = (
                (validity_targets == usable_index) & (condition_targets >= 0)
            )
            if permutation is not None:
                supervised &= (
                    (validity_targets[permutation] == usable_index)
                    & (condition_targets[permutation] >= 0)
                )
            if torch.any(supervised):
                permuted_targets = (
                    condition_targets[permutation] if permutation is not None else None
                )
                condition_loss = _possibly_mixed_cross_entropy(
                    condition_logits[supervised],
                    condition_targets[supervised],
                    None,
                    mix,
                    weight=condition_class_weights,
                    label_smoothing=label_smoothing,
                    second_targets=(
                        permuted_targets[supervised]
                        if permuted_targets is not None
                        else None
                    ),
                )
                supervised_condition_samples += int(torch.sum(supervised).item())
            else:
                condition_loss = validity_logits.sum() * 0.0
            condition_outlier_exposure_loss: torch.Tensor | None = None
            batch_outlier_exposure_count = 0
            if condition_outlier_exposure_targets is not None:
                outlier_exposure = condition_outlier_exposure_targets
                if permutation is not None:
                    # The three-way mixup stratification makes these masks
                    # equal. Retaining the intersection is a fail-safe if the
                    # pairing implementation is changed later.
                    outlier_exposure = (
                        outlier_exposure
                        & condition_outlier_exposure_targets[permutation]
                    )
                batch_outlier_exposure_count = int(
                    torch.sum(outlier_exposure).item()
                )
            if batch_outlier_exposure_count:
                condition_outlier_exposure_loss = _uniform_condition_kl(
                    condition_logits[outlier_exposure]
                )
                condition_outlier_exposure_samples += (
                    batch_outlier_exposure_count
                )
            loss = validity_loss + condition_loss_weight * condition_loss
            if condition_outlier_exposure_loss is not None:
                loss = (
                    loss
                    + condition_outlier_exposure_weight
                    * condition_outlier_exposure_loss
                )

        scaler.scale(loss).backward()
        if gradient_clip_norm > 0:
            scaler.unscale_(optimizer)
            torch.nn.utils.clip_grad_norm_(model.parameters(), gradient_clip_norm)
        scaler.step(optimizer)
        scaler.update()

        count = len(validity_targets)
        total_samples += count
        total_loss += float(loss.detach().item()) * count
        total_validity_loss += float(validity_loss.detach().item()) * count
        total_condition_loss += float(condition_loss.detach().item()) * count
        if condition_outlier_exposure_loss is not None:
            total_condition_outlier_exposure_loss += (
                float(condition_outlier_exposure_loss.detach().item())
                * batch_outlier_exposure_count
            )

    denominator = max(1, total_samples)
    mean_condition_outlier_exposure_loss = (
        total_condition_outlier_exposure_loss / condition_outlier_exposure_samples
        if condition_outlier_exposure_samples
        else None
    )
    return {
        "loss": total_loss / denominator,
        "validity_loss": total_validity_loss / denominator,
        "condition_loss": total_condition_loss / denominator,
        "sample_count": total_samples,
        "condition_supervised_count": supervised_condition_samples,
        "condition_outlier_exposure_objective": "kl_uniform_to_prediction_v1",
        "condition_outlier_exposure_weight": condition_outlier_exposure_weight,
        "condition_outlier_exposure_loss": mean_condition_outlier_exposure_loss,
        "condition_outlier_exposure_weighted_loss": (
            condition_outlier_exposure_weight
            * mean_condition_outlier_exposure_loss
            if mean_condition_outlier_exposure_loss is not None
            else None
        ),
        "condition_outlier_exposure_count": condition_outlier_exposure_samples,
    }


def _possibly_mixed_cross_entropy(
    logits: torch.Tensor,
    targets: torch.Tensor,
    permutation: torch.Tensor | None,
    mix: float,
    *,
    weight: torch.Tensor,
    label_smoothing: float,
    second_targets: torch.Tensor | None = None,
) -> torch.Tensor:
    first = F.cross_entropy(
        logits,
        targets,
        weight=weight,
        label_smoothing=label_smoothing,
    )
    if permutation is None and second_targets is None:
        return first
    second = second_targets if second_targets is not None else targets[permutation]
    return mix * first + (1.0 - mix) * F.cross_entropy(
        logits,
        second,
        weight=weight,
        label_smoothing=label_smoothing,
    )


def _uniform_condition_kl(logits: torch.Tensor) -> torch.Tensor:
    """Return mean KL(U || p) for explicit unknown-condition examples.

    ``U`` is uniform over the reviewed known-condition classes and ``p`` is
    the condition head's softmax distribution. Subtracting ``log(K)`` gives a
    zero minimum while preserving the gradient of uniform-target cross entropy.
    The calculation is promoted to float32 under AMP for numerical stability.
    """

    if logits.ndim != 2:
        raise ValueError("Condition logits must have shape [batch, classes]")
    class_count = int(logits.shape[1])
    if class_count < 2:
        raise ValueError(
            "Uniform condition KL requires at least two known condition classes"
        )
    log_probabilities = F.log_softmax(logits.float(), dim=1)
    return -log_probabilities.mean(dim=1).mean() - math.log(class_count)


def _condition_stratified_mixup_permutation(
    validity_targets: torch.Tensor,
    condition_targets: torch.Tensor,
    condition_outlier_exposure_targets: torch.Tensor | None = None,
) -> torch.Tensor:
    """Pair samples only with others sharing their condition-loss contract.

    A fully random mixup permutation makes most known samples unusable for the
    condition loss when open-set examples dominate a batch. Keeping the two
    supervision strata separate preserves every valid condition target while
    validity targets can still mix within the open-set stratum. When the
    opt-in outlier-exposure objective is active, explicit unknowns become a
    third stratum: an unknown-uniform target is never attached to an image
    mixed with wrong-crop, non-leaf, other-plant, or non-plant evidence.
    """

    usable_index = VALIDITY_TO_INDEX[USABLE_VALIDITY_LABEL]
    condition_supervised = (
        (validity_targets == usable_index) & (condition_targets >= 0)
    )
    if condition_outlier_exposure_targets is None:
        strata = (condition_supervised, ~condition_supervised)
    else:
        outlier_exposure = condition_outlier_exposure_targets.to(
            device=condition_targets.device, dtype=torch.bool
        )
        if outlier_exposure.shape != condition_targets.shape:
            raise ValueError(
                "condition_outlier_exposure_targets must match condition_targets"
            )
        invalid = outlier_exposure & condition_supervised
        if torch.any(invalid):
            raise ValueError(
                "Known-condition and outlier-exposure mixup strata must be disjoint"
            )
        strata = (
            condition_supervised,
            outlier_exposure,
            ~(condition_supervised | outlier_exposure),
        )
    permutation = torch.arange(len(condition_targets), device=condition_targets.device)
    for mask in strata:
        indices = torch.nonzero(mask, as_tuple=False).flatten()
        if len(indices) > 1:
            permutation[indices] = indices[
                torch.randperm(len(indices), device=condition_targets.device)
            ]
    return permutation


def _condition_outlier_exposure_weight(config: dict[str, Any]) -> float:
    """Read the schema-v1 opt-in OE weight without changing legacy hashes."""

    try:
        weight = float(config.get("condition_outlier_exposure_weight", 0.0))
    except (TypeError, ValueError) as error:
        raise ValueError(
            "condition_outlier_exposure_weight must be a finite number >= 0"
        ) from error
    if not math.isfinite(weight) or weight < 0.0:
        raise ValueError(
            "condition_outlier_exposure_weight must be a finite number >= 0"
        )
    return weight


def _create_optimizer(
    model: CropSpecificTwoHeadModel, config: dict[str, Any]
) -> torch.optim.Optimizer:
    learning_rate = float(config.get("learning_rate", 3e-4))
    multiplier = float(config.get("backbone_learning_rate_multiplier", 0.2))
    head_parameters: Iterable[torch.nn.Parameter] = (
        list(model.shared.parameters())
        + list(model.validity_head.parameters())
        + list(model.condition_head.parameters())
    )
    return torch.optim.AdamW(
        [
            {"params": model.backbone.parameters(), "lr": learning_rate * multiplier},
            {"params": head_parameters, "lr": learning_rate},
        ],
        weight_decay=float(config.get("weight_decay", 1e-4)),
    )


def _class_weights(
    targets: np.ndarray, class_count: int, device: torch.device
) -> torch.Tensor:
    targets = np.asarray(targets, dtype=np.int64)
    targets = targets[(targets >= 0) & (targets < class_count)]
    counts = np.bincount(targets, minlength=class_count).astype(np.float64)
    weights = np.zeros(class_count, dtype=np.float64)
    present = counts > 0
    if np.any(present):
        weights[present] = np.sqrt(np.sum(counts) / (np.sum(present) * counts[present]))
    return torch.as_tensor(weights, dtype=torch.float32, device=device)


def _condition_class_weights(
    frame: pd.DataFrame, labels: list[str], device: torch.device
) -> torch.Tensor:
    mapping = {label: index for index, label in enumerate(labels)}
    usable = frame["validity_label"].eq(USABLE_VALIDITY_LABEL)
    targets = frame.loc[usable, "condition_label"].map(mapping).dropna().to_numpy(dtype=int)
    return _class_weights(targets, len(labels), device)


def _make_loader(
    dataset: ManifestDataset,
    *,
    batch_size: int,
    num_workers: int,
    seed: int,
    device: torch.device,
    sampler=None,
) -> DataLoader:
    return DataLoader(
        dataset,
        batch_size=batch_size,
        sampler=sampler,
        shuffle=False,
        num_workers=num_workers,
        pin_memory=device.type == "cuda",
        worker_init_fn=seed_worker,
        generator=make_generator(seed),
        persistent_workers=False,
    )


def _predict_for_checkpoint(
    *,
    bundle: dict[str, Any],
    config: dict[str, Any],
    manifest_path: str | Path | None,
    split: str,
) -> dict[str, Any]:
    checkpoint = bundle["checkpoint"]
    effective_config_sha256 = _assert_effective_config_identity(checkpoint, config)
    repo_root = find_repo_root(Path(__file__))
    manifest = _resolve_path(manifest_path or config["manifest"], repo_root)
    manifest_digest = file_sha256(manifest)
    _assert_evaluation_manifest_identity(checkpoint, manifest_digest)
    image_root = _resolve_path(config.get("image_root", repo_root), repo_root)
    frame = read_manifest(
        manifest,
        crop=checkpoint["crop"],
        split=split,
        condition_labels=checkpoint["condition_labels"],
        check_files=True,
        image_root=image_root,
        unconfigured_conditions=str(
            checkpoint.get("config", {}).get("unconfigured_conditions", "reject")
        ),
        unknown_condition_label=str(
            checkpoint.get("config", {}).get(
                "unknown_label", f"{checkpoint['crop']}_other_unknown"
            )
        ),
    )
    frame = deterministic_limit(
        frame, _optional_int(config.get("max_eval_samples")), int(config.get("seed", 0)) + 2
    )
    dataset = ManifestDataset(
        frame,
        checkpoint["condition_labels"],
        build_transform(int(checkpoint.get("image_size", 224)), training=False),
        image_root,
    )
    loader = _make_loader(
        dataset,
        batch_size=int(config.get("batch_size", 32)),
        num_workers=int(config.get("num_workers", 0)),
        seed=int(config.get("seed", 0)) + 20_000,
        device=bundle["device"],
    )
    predictions = predict_loader(
        bundle["model"],
        loader,
        device=bundle["device"],
        amp_enabled=bool(config.get("amp", True)) and bundle["device"].type == "cuda",
    )
    predictions["manifest_sha256"] = manifest_digest
    predictions["manifest_path"] = str(manifest)
    predictions["split"] = split
    predictions["effective_config_sha256"] = effective_config_sha256
    source_ids = sorted({str(value) for value in predictions["source_id"]})
    source_locked = (
        "source_locked_split" in frame.columns
        and not frame.empty
        and frame["source_locked_split"].astype(str).str.strip().eq(split).all()
    )
    configured_evidence_policy = config.get("source_evidence_policy")
    evidence = resolve_source_evidence(
        source_ids,
        policy_path=(
            _resolve_path(configured_evidence_policy, repo_root)
            if configured_evidence_policy
            else None
        ),
    )
    predictions["evaluation_domain"] = {
        "source_ids": source_ids,
        "source_locked_to_split": bool(source_locked),
        "independent_from_training": bool(split == "external_test" and source_locked),
        "sample_count": int(len(frame)),
        **evidence,
    }
    return predictions


def _metric_arguments(
    predictions: dict[str, Any],
    condition_labels: list[str],
    *,
    calibration: dict[str, Any] | None = None,
    calibrated: dict[str, np.ndarray] | None = None,
) -> dict[str, Any]:
    return {
        "validity_logits": predictions["validity_logits"],
        "condition_logits": predictions["condition_logits"],
        "validity_targets": predictions["validity_targets"],
        "condition_targets": predictions["condition_targets"],
        "condition_labels": condition_labels,
        "validity_temperature": (
            float(calibration["validity_temperature"]) if calibration else 1.0
        ),
        "condition_temperature": (
            float(calibration["condition_temperature"]) if calibration else 1.0
        ),
        "accepted": calibrated["accepted"] if calibrated else None,
        "is_field": predictions["is_field"],
    }


def _monitor_value(metrics: dict[str, Any], monitor: str) -> float | None:
    if monitor == SAFETY_COMPOSITE_MONITOR:
        return _safety_composite_monitor_value(metrics)

    condition = metrics["condition"]
    aliases = {
        "field_macro_f1": condition.get("field_macro_f1"),
        "condition_macro_f1": condition.get("macro_f1"),
        "macro_f1": condition.get("macro_f1"),
        "balanced_accuracy": condition.get("balanced_accuracy"),
    }
    if monitor not in aliases:
        supported = sorted((*aliases, SAFETY_COMPOSITE_MONITOR))
        raise ValueError(
            f"Unsupported monitor {monitor!r}; use one of {supported}"
        )
    value = aliases[monitor]
    if value is None:
        raise ValueError(
            f"Monitor metric {monitor!r} is unavailable for this validation split"
        )
    return float(value)


def _safety_composite_monitor_value(metrics: Mapping[str, Any]) -> float:
    """Return the fixed validation-only safety objective.

    A weighted geometric mean prevents a strong condition classifier from
    fully hiding a weak validity or OOD component. Coverage is checked from
    the validation manifest by :func:`_assert_training_coverage` before the
    first epoch; this function independently fails closed on missing or
    malformed metric values.
    """

    condition = metrics.get("condition")
    validity = metrics.get("validity")
    ood = metrics.get("ood")
    joint = ood.get("joint") if isinstance(ood, Mapping) else None
    raw_components = {
        "field_condition_macro_f1": (
            condition.get("field_macro_f1")
            if isinstance(condition, Mapping)
            else None
        ),
        "validity_balanced_accuracy": (
            validity.get("balanced_accuracy")
            if isinstance(validity, Mapping)
            else None
        ),
        "joint_ood_auroc": (
            joint.get("auroc") if isinstance(joint, Mapping) else None
        ),
    }
    components: dict[str, float] = {}
    for name, raw_value in raw_components.items():
        if isinstance(raw_value, bool):
            raise ValueError(
                f"{SAFETY_COMPOSITE_MONITOR} requires numeric {name} in [0, 1]"
            )
        try:
            value = float(raw_value)
        except (TypeError, ValueError) as error:
            raise ValueError(
                f"{SAFETY_COMPOSITE_MONITOR} requires numeric {name} in [0, 1]"
            ) from error
        if not math.isfinite(value) or not 0.0 <= value <= 1.0:
            raise ValueError(
                f"{SAFETY_COMPOSITE_MONITOR} requires finite {name} in [0, 1]"
            )
        components[name] = value

    composite = 1.0
    for name, weight in SAFETY_COMPOSITE_WEIGHTS.items():
        composite *= components[name] ** weight
    return float(composite)


def _assert_training_coverage(
    train_frame: pd.DataFrame,
    validation_frame: pd.DataFrame,
    condition_labels: list[str],
    *,
    monitor_name: str,
    safety_composite_validation_contract: Any = None,
) -> None:
    if len(condition_labels) != len(set(condition_labels)):
        raise ValueError("Condition-label order contains duplicate labels")

    for split_name, frame in (
        ("train", train_frame),
        ("validation", validation_frame),
    ):
        supervised = frame.loc[
            frame["validity_label"].eq(USABLE_VALIDITY_LABEL)
            & frame["condition_label"].isin(condition_labels)
        ]
        present = set(supervised["condition_label"])
        missing = [label for label in condition_labels if label not in present]
        if missing:
            raise ValueError(
                f"{split_name} split has no supervised examples for configured "
                f"condition labels: {missing}"
            )

    if monitor_name in {"field_macro_f1", SAFETY_COMPOSITE_MONITOR}:
        if "is_field" not in validation_frame.columns:
            raise ValueError(
                f"{monitor_name} was requested but the manifest has no is_field column"
            )
        field = validation_frame["is_field"].map(parse_bool)
        supervised_field = validation_frame.loc[
            field
            & validation_frame["validity_label"].eq(USABLE_VALIDITY_LABEL)
            & validation_frame["condition_label"].isin(condition_labels)
        ]
        present = set(supervised_field["condition_label"])
        missing = [label for label in condition_labels if label not in present]
        if missing:
            raise ValueError(
                f"{monitor_name} requires field validation examples for every "
                f"configured condition label; missing: {missing}"
            )

    if monitor_name != SAFETY_COMPOSITE_MONITOR:
        return

    contract = _validate_safety_composite_validation_contract(
        safety_composite_validation_contract
    )
    minimum_field = contract["minimum_field_samples_per_condition"]
    field_counts = supervised_field["condition_label"].value_counts()
    insufficient_field = {
        label: int(field_counts.get(label, 0))
        for label in condition_labels
        if int(field_counts.get(label, 0)) < minimum_field
    }
    if insufficient_field:
        raise ValueError(
            f"{SAFETY_COMPOSITE_MONITOR} requires at least {minimum_field} field "
            "validation examples per known condition; observed "
            f"{insufficient_field}"
        )

    known_mask = validation_frame["validity_label"].eq(
        USABLE_VALIDITY_LABEL
    ) & validation_frame["condition_label"].isin(condition_labels)
    known_count = int(known_mask.sum())
    minimum_known = contract["minimum_known_samples"]
    if known_count < minimum_known:
        raise ValueError(
            f"{SAFETY_COMPOSITE_MONITOR} requires at least {minimum_known} known "
            f"validation examples; observed {known_count}"
        )
    ood_count = int((~known_mask).sum())
    minimum_ood = contract["minimum_ood_samples"]
    if ood_count < minimum_ood:
        raise ValueError(
            f"{SAFETY_COMPOSITE_MONITOR} requires at least {minimum_ood} OOD "
            f"validation examples; observed {ood_count}"
        )

    minimum_validity = contract["minimum_samples_per_required_validity_label"]
    validity_counts = validation_frame["validity_label"].value_counts()
    insufficient_validity = {
        label: int(validity_counts.get(label, 0))
        for label in contract["required_validity_labels"]
        if int(validity_counts.get(label, 0)) < minimum_validity
    }
    if insufficient_validity:
        raise ValueError(
            f"{SAFETY_COMPOSITE_MONITOR} requires at least {minimum_validity} "
            "validation examples for every predeclared validity label; observed "
            f"{insufficient_validity}"
        )


def _validate_safety_composite_validation_contract(value: Any) -> dict[str, Any]:
    if not isinstance(value, Mapping):
        raise ValueError(
            f"{SAFETY_COMPOSITE_MONITOR} requires a predeclared "
            "safety_composite_validation_contract object"
        )
    if type(value.get("schema_version")) is not int or value["schema_version"] != 1:
        raise ValueError(
            "safety_composite_validation_contract.schema_version must be the integer 1"
        )

    contract: dict[str, Any] = {"schema_version": 1}
    for name in (
        "minimum_field_samples_per_condition",
        "minimum_known_samples",
        "minimum_ood_samples",
        "minimum_samples_per_required_validity_label",
    ):
        raw = value.get(name)
        if type(raw) is not int or raw <= 0:
            raise ValueError(
                f"safety_composite_validation_contract.{name} must be a positive integer"
            )
        contract[name] = raw

    raw_labels = value.get("required_validity_labels")
    if not isinstance(raw_labels, list) or not raw_labels:
        raise ValueError(
            "safety_composite_validation_contract.required_validity_labels must "
            "be a non-empty list"
        )
    labels = [str(label).strip() for label in raw_labels]
    if any(not label for label in labels) or len(labels) != len(set(labels)):
        raise ValueError(
            "safety_composite_validation_contract.required_validity_labels must "
            "contain unique non-empty labels"
        )
    invalid = sorted(set(labels) - set(VALIDITY_LABELS))
    if invalid:
        raise ValueError(
            "safety_composite_validation_contract.required_validity_labels contains "
            f"unsupported labels: {invalid}"
        )
    contract["required_validity_labels"] = labels
    return contract


def _assert_checkpoint_identity(
    checkpoint: dict[str, Any], crop: str, architecture: str, labels: list[str]
) -> None:
    if checkpoint.get("crop") != crop:
        raise ValueError("Checkpoint crop does not match requested crop")
    if checkpoint.get("architecture") != architecture:
        raise ValueError("Checkpoint architecture does not match requested architecture")
    if checkpoint.get("condition_labels") != labels:
        raise ValueError("Checkpoint condition-label order does not match taxonomy")


def _assert_evaluation_manifest_identity(
    checkpoint: dict[str, Any], manifest_digest: str
) -> None:
    expected = checkpoint.get("manifest_sha256")
    if not isinstance(expected, str) or not _SHA256_PATTERN.fullmatch(expected):
        raise ValueError(
            "Checkpoint is missing a canonical training-manifest SHA-256 identity"
        )
    if expected != manifest_digest:
        raise ValueError(
            "Evaluation manifest hash does not match the manifest used to train "
            "this checkpoint"
        )


def _assert_effective_config_identity(
    checkpoint: Mapping[str, Any], effective_config: Mapping[str, Any]
) -> str:
    """Return the effective config hash only when it is checkpoint-identical."""

    if not isinstance(effective_config, Mapping):
        raise ValueError("Effective evaluation config must be an object")
    expected = checkpoint.get("config_hash")
    if not isinstance(expected, str) or not _SHA256_PATTERN.fullmatch(expected):
        raise ValueError(
            "Checkpoint is missing a canonical training-config SHA-256 identity"
        )
    stored_config = checkpoint.get("config")
    if not isinstance(stored_config, Mapping):
        raise ValueError("Checkpoint is missing its training configuration")
    stored_digest = config_hash(dict(stored_config))
    if stored_digest != expected:
        raise ValueError(
            "Checkpoint training configuration does not match its recorded hash"
        )
    effective_digest = config_hash(dict(effective_config))
    if effective_digest != expected:
        raise ValueError(
            "Effective evaluation config does not match the configuration used "
            "to train this checkpoint"
        )
    return effective_digest


def _validate_calibration_artifact_identity(
    calibration: object,
    *,
    checkpoint: Mapping[str, Any],
    checkpoint_sha256: str,
    manifest_sha256: str,
    effective_config_sha256: str,
) -> None:
    """Require complete calibration provenance before applying its thresholds."""

    if not isinstance(calibration, Mapping):
        raise ValueError("Calibration artifact must be a JSON object")
    if type(calibration.get("schema_version")) is not int or calibration.get(
        "schema_version"
    ) != 1:
        raise ValueError("Calibration artifact schema_version must equal integer 1")
    if calibration.get("method") != "scalar_temperature_plus_three_signal_grid_gate":
        raise ValueError("Calibration artifact method is missing or unsupported")
    if calibration.get("manifest_split") != "calibration":
        raise ValueError(
            "Calibration artifact was not fitted on the locked calibration split"
        )

    for field, value in (
        ("checkpoint_sha256", checkpoint_sha256),
        ("manifest_sha256", manifest_sha256),
        ("config_sha256", effective_config_sha256),
    ):
        if not isinstance(value, str) or not _SHA256_PATTERN.fullmatch(value):
            raise ValueError(f"Expected {field!r} is not a canonical SHA-256 identity")
    for field in ("crop", "architecture"):
        value = checkpoint.get(field)
        if not isinstance(value, str) or not value:
            raise ValueError(f"Checkpoint is missing required identity {field!r}")

    expected_identities = {
        "checkpoint_sha256": checkpoint_sha256,
        "manifest_sha256": manifest_sha256,
        "config_sha256": effective_config_sha256,
        "crop": checkpoint.get("crop"),
        "architecture": checkpoint.get("architecture"),
    }
    for field, expected in expected_identities.items():
        actual = calibration.get(field)
        if actual != expected:
            if actual is None:
                raise ValueError(
                    f"Calibration artifact is missing required identity {field!r}"
                )
            raise ValueError(
                f"Calibration artifact {field!r} does not match the evaluated "
                "checkpoint and manifest"
            )

    for field in ("validity_temperature", "condition_temperature"):
        value = _calibration_number(calibration.get(field), field)
        if value <= 0.0:
            raise ValueError(f"Calibration artifact {field!r} must be positive")

    thresholds = calibration.get("thresholds")
    if not isinstance(thresholds, Mapping):
        raise ValueError("Calibration artifact thresholds must be an object")
    for field in ("validity_probability_min", "condition_probability_min"):
        value = _calibration_number(thresholds.get(field), f"thresholds.{field}")
        if not 0.0 <= value <= 1.0:
            raise ValueError(
                f"Calibration artifact threshold {field!r} must be within [0, 1]"
            )
    _calibration_number(
        thresholds.get("condition_energy_max"), "thresholds.condition_energy_max"
    )

    validation_counts = calibration.get("validation_counts")
    if not isinstance(validation_counts, Mapping):
        raise ValueError("Calibration artifact validation_counts must be an object")
    counts: dict[str, int] = {}
    for field in ("total", "known", "ood"):
        value = validation_counts.get(field)
        if type(value) is not int or value < 0:
            raise ValueError(
                f"Calibration artifact validation_counts.{field} must be a "
                "non-negative integer"
            )
        counts[field] = value
    if counts["known"] == 0 or counts["total"] != counts["known"] + counts["ood"]:
        raise ValueError("Calibration artifact validation_counts are inconsistent")


def _calibration_number(value: object, field: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise ValueError(f"Calibration artifact {field!r} must be a finite number")
    number = float(value)
    if not math.isfinite(number):
        raise ValueError(f"Calibration artifact {field!r} must be a finite number")
    return number


def _optimizer_to(optimizer: torch.optim.Optimizer, device: torch.device) -> None:
    for state in optimizer.state.values():
        for key, value in state.items():
            if torch.is_tensor(value):
                state[key] = value.to(device)


def _resolve_path(value: str | Path, repo_root: Path) -> Path:
    path = Path(value)
    return path.resolve() if path.is_absolute() else (repo_root / path).resolve()


def _optional_int(value: Any) -> int | None:
    return int(value) if value is not None else None


def _load_history(path: Path) -> list[dict[str, Any]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as handle:
        result = json.load(handle)
    return result if isinstance(result, list) else []


def _write_predictions(
    path: Path,
    predictions: dict[str, Any],
    condition_labels: list[str],
    calibrated: dict[str, np.ndarray] | None,
) -> None:
    validity_prediction = np.argmax(predictions["validity_logits"], axis=1)
    condition_prediction = np.argmax(predictions["condition_logits"], axis=1)
    frame = pd.DataFrame(
        {
            "image_path": predictions["image_path"],
            "source_id": predictions["source_id"],
            "group_id": predictions["group_id"],
            "validity_target_index": predictions["validity_targets"],
            "validity_prediction": [VALIDITY_LABELS[index] for index in validity_prediction],
            "condition_target_index": predictions["condition_targets"],
            "condition_prediction": [condition_labels[index] for index in condition_prediction],
            "accepted": calibrated["accepted"] if calibrated else "",
        }
    )
    path.parent.mkdir(parents=True, exist_ok=True)
    frame.to_csv(path, index=False, lineterminator="\n")
