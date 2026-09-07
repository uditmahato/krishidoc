"""Atomic checkpoints with exact RNG restoration for Windows and Linux."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import torch

from .receipt import file_sha256

from .reproducibility import capture_rng_state, restore_rng_state


def initialize_finetune(
    path: str | Path, *, model: torch.nn.Module, expected_sha256: str,
    crop: str, architecture: str, condition_labels: list[str],
    validity_labels: list[str], image_size: int, manifest_sha256: str,
) -> dict[str, str]:
    """Weights-only initialization; never reuse optimizer/RNG or call it resume.

    The supplied manifest identity must match the parent checkpoint. The
    pipeline separately verifies append-only ancestry and the full combined
    image audit when a new-source manifest extension is explicitly configured.
    """
    actual = file_sha256(path)
    if actual != expected_sha256:
        raise ValueError('Fine-tune checkpoint SHA-256 mismatch')
    checkpoint = torch.load(path, map_location='cpu', weights_only=False)
    expected = dict(crop=crop, architecture=architecture,
                    condition_labels=condition_labels, validity_labels=validity_labels,
                    image_size=image_size, manifest_sha256=manifest_sha256)
    for key, value in expected.items():
        if checkpoint.get(key) != value:
            raise ValueError(f'Fine-tune checkpoint {key} mismatch')
    model.load_state_dict(checkpoint['model_state'], strict=True)
    return {'checkpoint_sha256': actual, 'parent_config_hash': checkpoint['config_hash']}


def save_checkpoint(
    path: str | Path,
    *,
    model: torch.nn.Module,
    optimizer: torch.optim.Optimizer,
    scheduler: torch.optim.lr_scheduler.LRScheduler,
    scaler: torch.amp.GradScaler,
    epoch: int,
    best_metric: float,
    epochs_without_improvement: int,
    metadata: dict[str, Any],
) -> None:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    torch.save(
        {
            "schema_version": 1,
            "epoch": int(epoch),
            "best_metric": float(best_metric),
            "epochs_without_improvement": int(epochs_without_improvement),
            "model_state": model.state_dict(),
            "optimizer_state": optimizer.state_dict(),
            "scheduler_state": scheduler.state_dict(),
            "scaler_state": scaler.state_dict(),
            "rng_state": capture_rng_state(),
            **metadata,
        },
        temporary,
    )
    temporary.replace(destination)


def load_training_checkpoint(
    path: str | Path,
    *,
    model: torch.nn.Module,
    optimizer: torch.optim.Optimizer,
    scheduler: torch.optim.lr_scheduler.LRScheduler,
    scaler: torch.amp.GradScaler,
    expected_config_hash: str,
    expected_manifest_hash: str,
) -> dict[str, Any]:
    checkpoint = torch.load(path, map_location="cpu", weights_only=False)
    if checkpoint.get("config_hash") != expected_config_hash:
        raise ValueError(
            "Checkpoint config hash does not match this run. Resume with the "
            "original config rather than silently changing the experiment."
        )
    if checkpoint.get("manifest_sha256") != expected_manifest_hash:
        raise ValueError(
            "Checkpoint manifest hash does not match the current manifest. "
            "Resume only with the exact audited data manifest used by the "
            "original run."
        )
    model.load_state_dict(checkpoint["model_state"])
    optimizer.load_state_dict(checkpoint["optimizer_state"])
    scheduler.load_state_dict(checkpoint["scheduler_state"])
    scaler.load_state_dict(checkpoint["scaler_state"])
    restore_rng_state(checkpoint["rng_state"])
    return checkpoint
