"""Stable labels and file contracts shared by training and evaluation."""

from __future__ import annotations

VALIDITY_LABELS: tuple[str, ...] = (
    "usable_target_leaf",
    "unsuitable_target_crop_view",
    "wrong_crop_leaf",
    "other_plant",
    "non_plant",
)
"""The fixed five-way subject-validity head, in model-output order."""

USABLE_VALIDITY_LABEL = VALIDITY_LABELS[0]
VALIDITY_TO_INDEX = {label: index for index, label in enumerate(VALIDITY_LABELS)}

MANIFEST_REQUIRED_COLUMNS: tuple[str, ...] = (
    "image_path",
    "crop",
    "condition_label",
    "validity_label",
    "split",
    "source_id",
    "group_id",
)

MANIFEST_SPLITS: tuple[str, ...] = (
    "train",
    "validation",
    "calibration",
    "test",
    "external_test",
)

# Optional columns understood by the core. Unknown columns are preserved so a
# data-preparation pipeline can add provenance without changing this package.
MANIFEST_OPTIONAL_COLUMNS: tuple[str, ...] = (
    "observed_crop",
    "country",
    "farm_id",
    "plant_id",
    "duplicate_group",
    "sha256",
    "license_id",
    "is_field",
    "is_synthetic",
)
