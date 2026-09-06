"""Canonical CSV manifest validation, datasets, and source balancing."""

from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Sequence

import numpy as np
import pandas as pd
import torch
from PIL import Image
from torch.utils.data import Dataset, WeightedRandomSampler

from .constants import (
    MANIFEST_REQUIRED_COLUMNS,
    MANIFEST_SPLITS,
    USABLE_VALIDITY_LABEL,
    VALIDITY_LABELS,
    VALIDITY_TO_INDEX,
)
from .reproducibility import make_generator


class ManifestValidationError(ValueError):
    """Raised when a manifest could invalidate training or reported metrics."""


def read_manifest(
    path: str | Path,
    *,
    crop: str | None = None,
    split: str | None = None,
    condition_labels: Sequence[str] | None = None,
    check_files: bool = False,
    image_root: str | Path | None = None,
    unconfigured_conditions: str = "reject",
    unknown_condition_label: str | None = None,
) -> pd.DataFrame:
    manifest_path = Path(path).resolve()
    frame = pd.read_csv(manifest_path, dtype=str, keep_default_na=False)
    validate_manifest(
        frame,
        condition_labels=None,
        manifest_path=manifest_path,
        check_files=check_files,
        image_root=image_root,
    )
    if crop is not None:
        frame = select_for_crop(frame, crop)
    if condition_labels is not None:
        effective_unknown_label = unknown_condition_label or (
            f"{crop}_other_unknown" if crop is not None else None
        )
        frame = apply_unconfigured_condition_policy(
            frame,
            condition_labels,
            policy=unconfigured_conditions,
            unknown_condition_label=effective_unknown_label,
        )
        _validate_condition_taxonomy(
            frame,
            condition_labels,
            unknown_condition_label=effective_unknown_label,
        )
    if split is not None:
        if split not in MANIFEST_SPLITS:
            raise ManifestValidationError(
                f"Unknown split {split!r}; expected one of {MANIFEST_SPLITS}"
            )
        frame = frame.loc[frame["split"] == split]
    frame = frame.reset_index(drop=True)
    if frame.empty:
        scope = f"crop={crop!r}, split={split!r}"
        raise ManifestValidationError(f"Manifest has no rows for {scope}")
    return frame


def select_for_crop(frame: pd.DataFrame, target_crop: str) -> pd.DataFrame:
    """Adapt one observed-crop manifest to a crop-specific model pack.

    The canonical ``crop`` column describes what is actually pictured.  Each
    pack reuses the global negative pool: leaves of another known crop become
    ``wrong_crop_leaf`` while non-plant and other-plant rows retain their more
    informative labels. This avoids triplicating negative rows in the manifest.
    """

    selected = frame.copy()
    observed_other_crop = selected["crop"].ne(target_crop) & ~selected[
        "validity_label"
    ].isin(("non_plant", "other_plant"))
    selected.loc[observed_other_crop, "validity_label"] = "wrong_crop_leaf"
    selected.loc[observed_other_crop, "condition_label"] = ""
    return selected


def apply_unconfigured_condition_policy(
    frame: pd.DataFrame,
    condition_labels: Sequence[str],
    *,
    policy: str,
    unknown_condition_label: str | None,
) -> pd.DataFrame:
    """Fail closed or turn unsupported target conditions into open-set rows."""

    if policy not in ("reject", "as_unknown"):
        raise ManifestValidationError(
            "unconfigured_conditions must be either 'reject' or 'as_unknown'"
        )
    selected = frame.copy()
    known = set(condition_labels)
    usable_labelled = selected["validity_label"].eq(USABLE_VALIDITY_LABEL) & selected[
        "condition_label"
    ].ne("")
    explicitly_unknown = selected["condition_label"].str.endswith("_other_unknown")
    unsupported = (
        usable_labelled & ~selected["condition_label"].isin(known) & ~explicitly_unknown
    )
    if not np.any(unsupported):
        return selected
    unexpected = sorted(set(selected.loc[unsupported, "condition_label"]))
    if policy == "reject":
        raise ManifestValidationError(
            "Usable target-leaf rows have condition labels outside the crop "
            f"taxonomy: {unexpected}"
        )
    if not unknown_condition_label:
        raise ManifestValidationError(
            "as_unknown requires an explicit unknown condition label"
        )
    if unknown_condition_label in known:
        raise ManifestValidationError(
            "The unknown condition label must not also be a known head class"
        )
    selected.loc[unsupported, "condition_label"] = unknown_condition_label
    return selected


def validate_manifest(
    frame: pd.DataFrame,
    *,
    condition_labels: Sequence[str] | None = None,
    manifest_path: str | Path | None = None,
    check_files: bool = False,
    image_root: str | Path | None = None,
) -> None:
    missing = sorted(set(MANIFEST_REQUIRED_COLUMNS) - set(frame.columns))
    if missing:
        raise ManifestValidationError(
            "Manifest is missing required columns: " + ", ".join(missing)
        )
    if frame.empty:
        raise ManifestValidationError("Manifest contains no samples")

    for column in (
        "image_path",
        "crop",
        "condition_label",
        "split",
        "source_id",
        "group_id",
    ):
        empty_count = int(frame[column].astype(str).str.strip().eq("").sum())
        if empty_count:
            raise ManifestValidationError(
                f"Manifest column {column!r} has {empty_count} empty values"
            )

    invalid_splits = sorted(set(frame["split"]) - set(MANIFEST_SPLITS))
    if invalid_splits:
        raise ManifestValidationError(f"Invalid split values: {invalid_splits}")
    invalid_validity = sorted(set(frame["validity_label"]) - set(VALIDITY_LABELS))
    if invalid_validity:
        raise ManifestValidationError(
            f"Invalid validity labels {invalid_validity}; expected {VALIDITY_LABELS}"
        )

    if condition_labels is not None:
        _validate_condition_taxonomy(frame, condition_labels)

    _assert_group_locked(frame, "source_id", "group_id")
    _assert_condition_consistent_groups(frame)
    for optional_group in ("duplicate_group", "sha256", "phash"):
        if optional_group in frame.columns:
            nonempty = frame.loc[frame[optional_group].ne("")]
            if not nonempty.empty:
                _assert_single_column_locked(nonempty, optional_group)

    if "is_derivative" in frame.columns:
        derivative = frame["is_derivative"].map(parse_bool)
        leaked_derivatives = frame.loc[derivative & frame["split"].ne("train")]
        if not leaked_derivatives.empty:
            raise ManifestValidationError(
                "Derivative images are allowed only in train; found "
                f"{len(leaked_derivatives)} evaluation rows"
            )
    if "source_locked_split" in frame.columns:
        locked = frame["source_locked_split"].astype(str).str.strip()
        violated = locked.ne("") & frame["split"].ne(locked)
        if np.any(violated):
            raise ManifestValidationError(
                f"source_locked_split is violated by {int(np.sum(violated))} rows"
            )

    if check_files:
        base = (
            Path(image_root).resolve()
            if image_root
            else _default_image_root(manifest_path)
        )
        missing_files: list[str] = []
        changed_files: list[str] = []
        digest_cache: dict[Path, str] = {}
        has_hashes = "sha256" in frame.columns
        for _, row in frame.iterrows():
            resolved = resolve_image_path(row["image_path"], base)
            if not resolved.is_file():
                missing_files.append(str(resolved))
                if len(missing_files) >= 10:
                    break
                continue
            expected_hash = str(row.get("sha256", "")).strip().lower()
            if has_hashes and expected_hash:
                actual_hash = digest_cache.get(resolved)
                if actual_hash is None:
                    digest = hashlib.sha256()
                    with resolved.open("rb") as handle:
                        for block in iter(lambda: handle.read(1024 * 1024), b""):
                            digest.update(block)
                    actual_hash = digest.hexdigest()
                    digest_cache[resolved] = actual_hash
                if actual_hash != expected_hash:
                    changed_files.append(str(resolved))
                    if len(changed_files) >= 10:
                        break
        if missing_files:
            suffix = " (first 10)" if len(missing_files) == 10 else ""
            raise ManifestValidationError(
                f"Image files are missing{suffix}: " + "; ".join(missing_files)
            )
        if changed_files:
            suffix = " (first 10)" if len(changed_files) == 10 else ""
            raise ManifestValidationError(
                f"Image SHA-256 does not match the manifest{suffix}: "
                + "; ".join(changed_files)
            )


def _assert_group_locked(frame: pd.DataFrame, source: str, group: str) -> None:
    grouped = (
        frame.assign(
            _lock_key=frame[source].astype(str) + "::" + frame[group].astype(str)
        )
        .groupby("_lock_key", sort=False)["split"]
        .nunique()
    )
    leaked = grouped[grouped > 1].index.tolist()
    if leaked:
        raise ManifestValidationError(
            "Source/group leakage across splits detected for: " + ", ".join(leaked[:10])
        )


def _assert_condition_consistent_groups(frame: pd.DataFrame) -> None:
    """Reject contradictory labels before crop selection can hide them.

    A group is the indivisible leakage unit. Every row in it must therefore
    carry the same canonical condition label, including explicit open-set
    unknown labels and ``not_applicable``. There is intentionally no training
    waiver: questionable components must be quarantined whole upstream.
    """

    normalized = frame.assign(
        _condition=frame["condition_label"].astype(str).str.strip(),
        _group=frame["group_id"].astype(str).str.strip(),
    )
    labels_by_group = normalized.groupby("_group", sort=False)["_condition"].agg(
        lambda values: tuple(sorted(set(values)))
    )
    conflicts = labels_by_group[labels_by_group.map(len) > 1]
    if conflicts.empty:
        return
    details = "; ".join(
        f"{group_id}: {list(labels)}"
        for group_id, labels in conflicts.iloc[:10].items()
    )
    raise ManifestValidationError(
        "Manifest groups carry conflicting canonical condition labels; "
        f"quarantine each whole group before training: {details}"
    )


def _validate_condition_taxonomy(
    frame: pd.DataFrame,
    condition_labels: Sequence[str],
    *,
    unknown_condition_label: str | None = None,
) -> None:
    known = set(condition_labels)
    usable = frame["validity_label"].eq(USABLE_VALIDITY_LABEL)
    labelled = frame["condition_label"].ne("")
    encountered = set(frame.loc[usable & labelled, "condition_label"])
    # `<crop>_other_unknown` is deliberately not a condition-head class. It is
    # an in-crop, open-set example used by calibration/OOD evaluation only.
    allowed_unknown = (
        {unknown_condition_label}
        if unknown_condition_label is not None
        else {label for label in encountered if label.endswith("_other_unknown")}
    )
    unexpected = sorted(encountered - known - allowed_unknown)
    if unexpected:
        raise ManifestValidationError(
            "Usable target-leaf rows have condition labels outside the crop "
            f"taxonomy: {unexpected}"
        )


def _assert_single_column_locked(frame: pd.DataFrame, column: str) -> None:
    grouped = frame.groupby(column, sort=False)["split"].nunique()
    leaked = grouped[grouped > 1].index.tolist()
    if leaked:
        raise ManifestValidationError(
            f"{column} leakage across splits detected for: "
            + ", ".join(str(value) for value in leaked[:10])
        )


def _default_image_root(manifest_path: str | Path | None) -> Path:
    if manifest_path is None:
        return Path.cwd()
    return Path(manifest_path).resolve().parent


def resolve_image_path(value: str, image_root: str | Path) -> Path:
    path = Path(value)
    return path if path.is_absolute() else Path(image_root) / path


def parse_bool(value: object) -> bool:
    return str(value).strip().lower() in {"1", "true", "yes", "y"}


def deterministic_limit(
    frame: pd.DataFrame, maximum: int | None, seed: int
) -> pd.DataFrame:
    if maximum is None or maximum <= 0 or len(frame) <= maximum:
        return frame.reset_index(drop=True)
    keys = frame.apply(
        lambda row: hashlib.sha256(
            (
                f"{seed}|{row['source_id']}|{row['group_id']}|" f"{row['image_path']}"
            ).encode("utf-8")
        ).hexdigest(),
        axis=1,
    )
    return (
        frame.assign(_stable_key=keys)
        .sort_values("_stable_key")
        .head(maximum)
        .drop(columns="_stable_key")
        .reset_index(drop=True)
    )


def source_balanced_weights(frame: pd.DataFrame) -> np.ndarray:
    """Return weights giving every source equal expected sampler mass."""

    counts = frame["source_id"].value_counts()
    weights = frame["source_id"].map(lambda source: 1.0 / float(counts[source]))
    values = weights.to_numpy(dtype=np.float64)
    return values / values.mean()


def source_balanced_sampler(frame: pd.DataFrame, seed: int) -> WeightedRandomSampler:
    weights = torch.as_tensor(source_balanced_weights(frame), dtype=torch.double)
    return WeightedRandomSampler(
        weights=weights,
        num_samples=len(frame),
        replacement=True,
        generator=make_generator(seed),
    )


class ManifestDataset(Dataset):
    def __init__(
        self,
        frame: pd.DataFrame,
        condition_labels: Sequence[str],
        transform,
        image_root: str | Path,
        *,
        unknown_condition_label: str | None = None,
    ) -> None:
        self.frame = frame.reset_index(drop=True).copy()
        self.condition_labels = tuple(condition_labels)
        self.condition_to_index = {
            label: index for index, label in enumerate(self.condition_labels)
        }
        self.unknown_condition_label = unknown_condition_label
        self.transform = transform
        self.image_root = Path(image_root).resolve()

    def __len__(self) -> int:
        return len(self.frame)

    def __getitem__(self, index: int) -> dict[str, object]:
        row = self.frame.iloc[index]
        path = resolve_image_path(row["image_path"], self.image_root)
        try:
            with Image.open(path) as handle:
                image = handle.convert("RGB")
        except Exception as error:
            raise RuntimeError(f"Could not load manifest image {path}") from error

        condition_label = str(row["condition_label"])
        condition_index = self.condition_to_index.get(condition_label, -1)
        validity_label = str(row["validity_label"])
        # A condition target is supervised only when both facts are true.  A
        # usable leaf with an empty label is a valuable open-set example.
        supervise_condition = (
            validity_label == USABLE_VALIDITY_LABEL and condition_index >= 0
        )
        # This marker is intentionally narrower than ``condition_target == -1``.
        # Wrong-crop, non-leaf, other-plant, and non-plant rows also lack a
        # known condition target, but only an explicitly labelled target-crop
        # unknown is valid outlier-exposure evidence for the condition head.
        condition_outlier_exposure_target = (
            validity_label == USABLE_VALIDITY_LABEL
            and getattr(self, "unknown_condition_label", None) is not None
            and condition_label == getattr(self, "unknown_condition_label", None)
        )
        return {
            "image": self.transform(image),
            "validity_target": VALIDITY_TO_INDEX[validity_label],
            "condition_target": condition_index if supervise_condition else -1,
            "condition_outlier_exposure_target": condition_outlier_exposure_target,
            "index": index,
            "image_path": str(path),
            "source_id": str(row["source_id"]),
            "group_id": str(row["group_id"]),
            "is_field": parse_bool(row.get("is_field", False)),
        }
