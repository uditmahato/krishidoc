"""Build a leakage-resistant image manifest for KrishiDoc training.

Raw datasets are intentionally source-specific.  This module turns their
folder names (or an optional ``.labels.csv`` sidecar) into one small canonical
CSV, verifies every image, fingerprints its bytes and visual content, groups
duplicates *before* assigning splits, and records every split constraint needed
by :mod:`audit_manifest`.
"""

from __future__ import annotations

import argparse
import csv
import fnmatch
import hashlib
import json
import math
import re
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence

from PIL import Image, ImageOps, UnidentifiedImageError


CANONICAL_COLUMNS = (
    "image_path",
    "crop",
    "condition_label",
    "validity_label",
    "split",
    "source_id",
    "group_id",
)
METADATA_COLUMNS = (
    "sha256",
    "phash",
    "is_derivative",
    "is_field",
    "source_locked_split",
)
MANIFEST_COLUMNS = CANONICAL_COLUMNS + METADATA_COLUMNS

VALIDITY_LABELS = frozenset(
    {
        "usable_target_leaf",
        "unsuitable_target_crop_view",
        "wrong_crop_leaf",
        "other_plant",
        "non_plant",
    }
)
REQUIRED_SPLITS = ("train", "validation", "calibration", "test")
ALLOWED_SPLITS = frozenset((*REQUIRED_SPLITS, "external_test"))
DEFAULT_SPLIT_RATIOS = {
    "train": 0.70,
    "validation": 0.10,
    "calibration": 0.10,
    "test": 0.10,
}
IMAGE_EXTENSIONS = frozenset(
    {".jpg", ".jpeg", ".png", ".bmp", ".tif", ".tiff", ".webp"}
)
DEFAULT_DERIVATIVE_PATTERNS = (
    r"(?:^|[/_.-])aug(?:mented|mentation)?(?:$|[/_.-])",
    r"(?:^|[/_.-])synthetic(?:$|[/_.-])",
    r"(?:^|[/_.-])generated(?:$|[/_.-])",
    r"(?:^|[/_.-])patch(?:es)?(?:$|[/_.-])",
    r"(?:^|[/_.-])flip(?:ped)?(?:$|[/_.-])",
    r"(?:^|[/_.-])rot(?:ate|ated|ation|[_-]?\d+)(?:$|[/_.-])",
    r"(?:^|[/_.-])shear(?:ed)?(?:$|[/_.-])",
    r"(?:^|[/_.-])zoom(?:ed)?(?:$|[/_.-])",
)
PATH_MODES = ("auto", "repo-relative", "absolute")
NUMERIC_CAPTURE_CONFIG_KEY = "filename_numeric_capture_group"
NUMERIC_CAPTURE_ALLOWED_KEYS = frozenset(
    {"regex", "maximum_adjacent_gap", "maximum_phash_distance", "scope"}
)
MAXIMUM_NUMERIC_CAPTURE_GAP = 3
MAXIMUM_NUMERIC_CAPTURE_PHASH_DISTANCE = 16


class ManifestPreparationError(RuntimeError):
    """Raised when raw inputs cannot safely produce a training manifest."""


@dataclass
class ImageRecord:
    path: Path
    relative_path: str
    source_id: str
    crop: str
    condition_label: str
    validity_label: str
    base_group: str
    sha256: str
    phash: str
    is_derivative: bool
    is_field: bool
    source_locked_split: str
    numeric_capture: _NumericCapture | None = None
    group_id: str = ""
    split: str = ""

    def to_row(self, *, image_path: str | None = None) -> dict[str, str]:
        return {
            "image_path": image_path or str(self.path.resolve()),
            "crop": self.crop,
            "condition_label": self.condition_label,
            "validity_label": self.validity_label,
            "split": self.split,
            "source_id": self.source_id,
            "group_id": self.group_id,
            "sha256": self.sha256,
            "phash": self.phash,
            "is_derivative": "1" if self.is_derivative else "0",
            "is_field": "1" if self.is_field else "0",
            "source_locked_split": self.source_locked_split,
        }


@dataclass(frozen=True)
class _NumericCapture:
    """Parsed source-local numeric filename evidence for capture grouping."""

    sequence_key: str
    adjacency_key: str
    number: int
    maximum_adjacent_gap: int
    maximum_phash_distance: int

    @property
    def base_group(self) -> str:
        return f"{self.sequence_key}:{self.number}"


class _DisjointSet:
    def __init__(self, size: int) -> None:
        self.parent = list(range(size))
        self.rank = [0] * size

    def find(self, item: int) -> int:
        parent = self.parent[item]
        if parent != item:
            self.parent[item] = self.find(parent)
        return self.parent[item]

    def union(self, left: int, right: int) -> None:
        left_root = self.find(left)
        right_root = self.find(right)
        if left_root == right_root:
            return
        if self.rank[left_root] < self.rank[right_root]:
            left_root, right_root = right_root, left_root
        self.parent[right_root] = left_root
        if self.rank[left_root] == self.rank[right_root]:
            self.rank[left_root] += 1


class _BKTree:
    """Small BK-tree for 64-bit perceptual hashes."""

    def __init__(self) -> None:
        self._root: tuple[int, list[int], dict[int, Any]] | None = None

    def add(self, value: int, index: int) -> None:
        if self._root is None:
            self._root = (value, [index], {})
            return
        node = self._root
        while True:
            node_value, indices, children = node
            distance = (value ^ node_value).bit_count()
            if distance == 0:
                indices.append(index)
                return
            child = children.get(distance)
            if child is None:
                children[distance] = (value, [index], {})
                return
            node = child

    def query(self, value: int, maximum_distance: int) -> list[int]:
        if self._root is None:
            return []
        matches: list[int] = []
        pending = [self._root]
        while pending:
            node_value, indices, children = pending.pop()
            distance = (value ^ node_value).bit_count()
            if distance <= maximum_distance:
                matches.extend(indices)
            lower = distance - maximum_distance
            upper = distance + maximum_distance
            pending.extend(
                child for edge, child in children.items() if lower <= edge <= upper
            )
        return matches


def _normalise_alias(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.casefold()).strip("_")


def _is_truthy(value: Any) -> bool:
    return str(value).strip().casefold() in {"1", "true", "yes", "y"}


def compute_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as image_file:
        for chunk in iter(lambda: image_file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _dct_matrix(size: int):
    try:
        import numpy as np
    except ImportError as error:  # pragma: no cover - dependency guard
        raise ManifestPreparationError(
            "numpy is required to calculate perceptual hashes; install "
            "ml/requirements-train.txt"
        ) from error
    coordinates = np.arange(size, dtype=np.float32)
    frequencies = coordinates[:, None]
    matrix = np.cos((math.pi / size) * (coordinates + 0.5) * frequencies)
    matrix[0, :] *= math.sqrt(1.0 / size)
    matrix[1:, :] *= math.sqrt(2.0 / size)
    return matrix


_PHASH_DCT = None


def compute_phash(path: Path) -> str:
    """Return the conventional 64-bit DCT perceptual hash as 16 hex digits."""
    try:
        import numpy as np
    except ImportError as error:  # pragma: no cover - dependency guard
        raise ManifestPreparationError(
            "numpy is required to calculate perceptual hashes; install "
            "ml/requirements-train.txt"
        ) from error

    global _PHASH_DCT
    if _PHASH_DCT is None:
        _PHASH_DCT = _dct_matrix(32)
    try:
        with Image.open(path) as image:
            image = (
                ImageOps.exif_transpose(image)
                .convert("L")
                .resize((32, 32), Image.Resampling.LANCZOS)
            )
            pixels = np.asarray(image, dtype=np.float32)
    except (OSError, ValueError, UnidentifiedImageError) as error:
        raise ManifestPreparationError(f"corrupt image: {path}: {error}") from error

    coefficients = _PHASH_DCT @ pixels @ _PHASH_DCT.T
    low_frequency = coefficients[:8, :8].reshape(-1)
    threshold = float(np.median(low_frequency[1:]))
    bits = low_frequency > threshold
    value = 0
    for bit in bits:
        value = (value << 1) | int(bit)
    return f"{value:016x}"


def verify_and_fingerprint(path: Path) -> tuple[str, str]:
    try:
        with Image.open(path) as image:
            image.verify()
    except (OSError, ValueError, UnidentifiedImageError) as error:
        raise ManifestPreparationError(f"corrupt image: {path}: {error}") from error
    return compute_sha256(path), compute_phash(path)


def hamming_distance(left: str, right: str) -> int:
    return (int(left, 16) ^ int(right, 16)).bit_count()


def load_aliases(path: Path) -> dict[str, Any]:
    try:
        aliases = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ManifestPreparationError(
            f"cannot read aliases {path}: {error}"
        ) from error
    if aliases.get("schema_version") != 1:
        raise ManifestPreparationError("label aliases must use schema_version 1")
    if not isinstance(aliases.get("sources"), dict):
        raise ManifestPreparationError("label aliases require a sources object")
    configured_validity = set(aliases.get("validity_labels", VALIDITY_LABELS))
    if configured_validity != VALIDITY_LABELS:
        raise ManifestPreparationError(
            "label aliases must declare exactly the canonical validity labels"
        )
    profiles = aliases.get("profiles", {})
    resolved_sources: dict[str, dict[str, Any]] = {}
    for source_id, source in aliases["sources"].items():
        if not isinstance(source, dict):
            raise ManifestPreparationError(f"source {source_id!r} must be an object")
        resolved: dict[str, Any] = {}
        selected_profiles = source.get("profiles", [])
        if isinstance(selected_profiles, str):
            selected_profiles = [selected_profiles]
        for profile_name in selected_profiles:
            profile = profiles.get(profile_name)
            if not isinstance(profile, dict):
                raise ManifestPreparationError(
                    f"source {source_id!r} references unknown profile {profile_name!r}"
                )
            _merge_configuration(resolved, profile)
        _merge_configuration(
            resolved, {key: value for key, value in source.items() if key != "profiles"}
        )
        _validate_numeric_capture_config(str(source_id), resolved)
        resolved_sources[source_id] = resolved
    aliases["sources"] = resolved_sources
    return aliases


def _merge_configuration(target: dict[str, Any], incoming: Mapping[str, Any]) -> None:
    for key, value in incoming.items():
        if isinstance(value, dict) and isinstance(target.get(key), dict):
            _merge_configuration(target[key], value)
        elif isinstance(value, list) and isinstance(target.get(key), list):
            target[key] = [*target[key], *value]
        elif isinstance(value, dict):
            target[key] = dict(value)
        elif isinstance(value, list):
            target[key] = list(value)
        else:
            target[key] = value


def _validate_numeric_capture_config(
    source_id: str, source_config: Mapping[str, Any]
) -> None:
    value = source_config.get(NUMERIC_CAPTURE_CONFIG_KEY)
    if value is None:
        return
    if not isinstance(value, Mapping):
        raise ManifestPreparationError(
            f"{NUMERIC_CAPTURE_CONFIG_KEY} for {source_id!r} must be an object"
        )
    unknown = sorted(set(map(str, value)) - NUMERIC_CAPTURE_ALLOWED_KEYS)
    if unknown:
        raise ManifestPreparationError(
            f"{NUMERIC_CAPTURE_CONFIG_KEY} for {source_id!r} has unsupported "
            f"keys: {unknown}"
        )
    conflicts = [
        key
        for key in ("group_regex", "filename_time_bucket")
        if source_config.get(key) is not None
    ]
    if conflicts:
        raise ManifestPreparationError(
            f"{NUMERIC_CAPTURE_CONFIG_KEY} for {source_id!r} cannot be combined "
            f"with {conflicts}"
        )
    pattern = value.get("regex")
    if not isinstance(pattern, str) or not pattern:
        raise ManifestPreparationError(
            f"{NUMERIC_CAPTURE_CONFIG_KEY} for {source_id!r} requires regex"
        )
    try:
        compiled = re.compile(pattern, flags=re.IGNORECASE)
    except re.error as error:
        raise ManifestPreparationError(
            f"invalid numeric capture regex for {source_id!r}: {error}"
        ) from error
    if "number" not in compiled.groupindex:
        raise ManifestPreparationError(
            f"numeric capture regex for {source_id!r} requires a named 'number' group"
        )
    maximum_gap = _bounded_integer_setting(
        value,
        "maximum_adjacent_gap",
        source_id,
        minimum=1,
        maximum=MAXIMUM_NUMERIC_CAPTURE_GAP,
    )
    maximum_distance = _bounded_integer_setting(
        value,
        "maximum_phash_distance",
        source_id,
        minimum=0,
        maximum=MAXIMUM_NUMERIC_CAPTURE_PHASH_DISTANCE,
    )
    if maximum_gap is None or maximum_distance is None:
        raise AssertionError("bounded numeric capture settings returned None")
    scope = str(value.get("scope", "parent")).strip().casefold()
    if scope not in {"source", "parent"}:
        raise ManifestPreparationError(
            f"{NUMERIC_CAPTURE_CONFIG_KEY} for {source_id!r} has unsupported "
            f"scope {scope!r}; expected 'source' or 'parent'"
        )


def _bounded_integer_setting(
    config: Mapping[str, Any],
    key: str,
    source_id: str,
    *,
    minimum: int,
    maximum: int,
) -> int:
    value = config.get(key)
    if isinstance(value, bool) or not isinstance(value, int):
        raise ManifestPreparationError(
            f"{NUMERIC_CAPTURE_CONFIG_KEY}.{key} for {source_id!r} must be an integer"
        )
    if not minimum <= value <= maximum:
        raise ManifestPreparationError(
            f"{NUMERIC_CAPTURE_CONFIG_KEY}.{key} for {source_id!r} must be "
            f"between {minimum} and {maximum}"
        )
    return value


def _glob_matches(relative_path: str, patterns: Sequence[str]) -> bool:
    lowered = relative_path.casefold()
    return any(fnmatch.fnmatchcase(lowered, pattern.casefold()) for pattern in patterns)


def _load_sidecar(
    source_root: Path, source_config: Mapping[str, Any]
) -> dict[str, dict[str, str]]:
    names = source_config.get("metadata_files", [".labels.csv", "labels.csv"])
    metadata_path = next(
        (source_root / name for name in names if (source_root / name).is_file()), None
    )
    if metadata_path is None:
        return {}
    if source_config.get("metadata_adapter") == "crop_diagnosis_v1":
        return _load_crop_diagnosis_sidecar(metadata_path, source_config)
    rows: dict[str, dict[str, str]] = {}
    with metadata_path.open("r", encoding="utf-8-sig", newline="") as input_file:
        reader = csv.DictReader(input_file)
        if reader.fieldnames is None:
            raise ManifestPreparationError(f"empty label sidecar: {metadata_path}")
        path_column = (
            "relative_path" if "relative_path" in reader.fieldnames else "image_path"
        )
        needed = {path_column, "crop", "condition_label", "validity_label"}
        missing = needed.difference(reader.fieldnames)
        if missing:
            raise ManifestPreparationError(
                f"label sidecar {metadata_path} is missing: {sorted(missing)}"
            )
        for row_number, row in enumerate(reader, start=2):
            relative = str(row.get(path_column, "")).replace("\\", "/").lstrip("./")
            if not relative:
                raise ManifestPreparationError(
                    f"blank path in {metadata_path} row {row_number}"
                )
            key = relative.casefold()
            if key in rows:
                raise ManifestPreparationError(
                    f"duplicate path {relative!r} in {metadata_path}"
                )
            rows[key] = {key: str(value or "").strip() for key, value in row.items()}
    return rows


def _load_crop_diagnosis_sidecar(
    metadata_path: Path,
    source_config: Mapping[str, Any],
) -> dict[str, dict[str, str]]:
    """Adapt Digital Green-style crop/diagnosis rows without trusting free text."""
    columns = source_config.get("metadata_columns", {})
    path_column = str(columns.get("path", "image_file"))
    crop_column = str(columns.get("crop", "crop"))
    diagnosis_column = str(columns.get("diagnosis", "diagnosis"))
    crop_aliases = {
        _normalise_alias(str(raw)): str(canonical)
        for raw, canonical in source_config.get("metadata_crop_aliases", {}).items()
    }
    diagnosis_aliases = {
        crop: {
            _normalise_alias(str(raw)): str(canonical)
            for raw, canonical in mappings.items()
        }
        for crop, mappings in source_config.get(
            "metadata_diagnosis_aliases", {}
        ).items()
    }
    unknown_conditions = {
        str(crop): str(condition)
        for crop, condition in source_config.get(
            "metadata_unknown_conditions", {}
        ).items()
    }
    grouped: dict[str, list[tuple[str, str]]] = defaultdict(list)
    with metadata_path.open("r", encoding="utf-8-sig", newline="") as input_file:
        reader = csv.DictReader(input_file)
        if reader.fieldnames is None:
            raise ManifestPreparationError(f"empty annotation file: {metadata_path}")
        missing = {path_column, crop_column, diagnosis_column}.difference(
            reader.fieldnames
        )
        if missing:
            raise ManifestPreparationError(
                f"annotation file {metadata_path} is missing: {sorted(missing)}"
            )
        for row_number, row in enumerate(reader, start=2):
            relative = str(row.get(path_column, "")).replace("\\", "/").lstrip("./")
            raw_crop = str(row.get(crop_column, "")).strip()
            diagnosis = str(row.get(diagnosis_column, "")).strip()
            if not relative or not raw_crop:
                raise ManifestPreparationError(
                    f"blank path/crop in {metadata_path} row {row_number}"
                )
            crop = crop_aliases.get(_normalise_alias(raw_crop), "unknown")
            grouped[relative.casefold()].append((crop, diagnosis))

    adapted: dict[str, dict[str, str]] = {}
    for relative, observations in grouped.items():
        observed_crops = {crop for crop, _ in observations}
        if len(observed_crops) != 1:
            if source_config.get("conflicting_crop_policy") == "skip":
                continue
            raise ManifestPreparationError(
                f"conflicting crops for {relative} in {metadata_path}: {sorted(observed_crops)}"
            )
        crop = next(iter(observed_crops))
        if crop == "unknown":
            condition_label = "not_applicable"
            validity_label = "other_plant"
        else:
            mapped_values = [
                diagnosis_aliases.get(crop, {}).get(_normalise_alias(diagnosis))
                for _, diagnosis in observations
            ]
            mapped_conditions = {value for value in mapped_values if value is not None}
            if len(mapped_conditions) == 1 and all(
                value is not None for value in mapped_values
            ):
                condition_label = next(iter(mapped_conditions))
            else:
                condition_label = unknown_conditions.get(crop, "")
            if not condition_label:
                raise ManifestPreparationError(
                    f"no unknown-condition label configured for crop {crop!r}"
                )
            validity_label = "usable_target_leaf"
        adapted[relative] = {
            "crop": crop,
            "condition_label": condition_label,
            "validity_label": validity_label,
            "group_id": f"annotation:{Path(relative).stem}",
            "is_derivative": "0",
        }
    return adapted


def _coerce_label(value: Mapping[str, Any], context: str) -> dict[str, str]:
    label = {
        "crop": str(value.get("crop", "")).strip(),
        "condition_label": str(value.get("condition_label", "")).strip(),
        "validity_label": str(value.get("validity_label", "")).strip(),
    }
    missing = [name for name, field_value in label.items() if not field_value]
    if missing:
        raise ManifestPreparationError(f"{context} is missing label fields: {missing}")
    if label["validity_label"] not in VALIDITY_LABELS:
        raise ManifestPreparationError(
            f"{context} uses invalid validity_label {label['validity_label']!r}"
        )
    return label


def _label_for_path(
    relative_path: str,
    source_config: Mapping[str, Any],
    sidecar_row: Mapping[str, str] | None,
) -> dict[str, str] | None:
    if sidecar_row is not None:
        return _coerce_label(sidecar_row, f"sidecar row for {relative_path}")

    for rule_index, rule in enumerate(source_config.get("path_rules", [])):
        glob = str(rule.get("glob", ""))
        regex = str(rule.get("regex", ""))
        matched = bool(glob and _glob_matches(relative_path, [glob]))
        if regex:
            matched = (
                matched
                or re.search(regex, relative_path, flags=re.IGNORECASE) is not None
            )
        if matched:
            return _coerce_label(rule, f"path rule {rule_index} for {relative_path}")

    raw_aliases = source_config.get("class_aliases", {})
    aliases = {_normalise_alias(str(key)): value for key, value in raw_aliases.items()}
    path = Path(relative_path)
    candidates = [path.stem, *(part for part in reversed(path.parts[:-1]))]
    for candidate in candidates:
        value = aliases.get(_normalise_alias(candidate))
        if value is not None:
            return _coerce_label(value, f"class alias {candidate!r}")

    fallback = source_config.get("fallback_label")
    if fallback is not None:
        return _coerce_label(fallback, f"fallback label for {relative_path}")
    return None


def _infer_numeric_capture(
    relative_path: str,
    source_id: str,
    source_config: Mapping[str, Any],
    label: Mapping[str, str],
) -> _NumericCapture | None:
    """Parse source-specific numeric filenames without crossing label domains.

    The number alone is not accepted as a capture identity. The lineage key
    always includes source, crop, condition, validity, optional parent
    directory, and the filename prefix. Adjacent numbers are only joined later
    inside the exact filename-suffix cohort and when their already-computed
    perceptual hashes also satisfy the configured bound.
    """

    config = source_config.get(NUMERIC_CAPTURE_CONFIG_KEY)
    if config is None:
        return None
    if not isinstance(config, Mapping):  # load_aliases normally catches this
        raise ManifestPreparationError(
            f"{NUMERIC_CAPTURE_CONFIG_KEY} for {source_id!r} must be an object"
        )
    pattern = str(config.get("regex", ""))
    match = re.fullmatch(pattern, Path(relative_path).stem, flags=re.IGNORECASE)
    if match is None:
        return None
    try:
        number = int(match.group("number"))
    except (IndexError, TypeError, ValueError) as error:
        raise ManifestPreparationError(
            f"numeric capture filename has an invalid number: "
            f"{source_id}/{relative_path}"
        ) from error
    if number < 0:
        raise ManifestPreparationError(
            f"numeric capture filename has a negative number: "
            f"{source_id}/{relative_path}"
        )
    prefix = match.groupdict().get("prefix") or "sequence"
    prefix_key = _normalise_alias(prefix) or "sequence"
    label_key = ":".join(
        _normalise_alias(str(label[key])) or "empty"
        for key in ("crop", "condition_label", "validity_label")
    )
    scope = str(config.get("scope", "parent")).strip().casefold()
    scope_key = "source"
    if scope == "parent":
        scope_key = Path(relative_path).parent.as_posix().casefold()
    sequence_key = (
        f"{source_id}:numeric-capture:{label_key}:{scope_key}:{prefix_key}"
    )
    # Preserve suffix case deliberately. PLDD-UP has distinct .JPG, .jpeg,
    # and .jpg numbering cohorts; case-folding them would invent adjacency
    # across independently ordered imports. Duplicate numeric stems remain
    # locked through base_group, whose sequence_key intentionally omits suffix.
    suffix_key = Path(relative_path).suffix or "<no-suffix>"
    return _NumericCapture(
        sequence_key=sequence_key,
        adjacency_key=f"{sequence_key}:suffix:{suffix_key}",
        number=number,
        maximum_adjacent_gap=int(config["maximum_adjacent_gap"]),
        maximum_phash_distance=int(config["maximum_phash_distance"]),
    )


def _infer_base_group(
    relative_path: str,
    source_id: str,
    source_config: Mapping[str, Any],
    sidecar_row: Mapping[str, str] | None,
) -> str:
    if sidecar_row and sidecar_row.get("group_id", "").strip():
        return f"{source_id}:{sidecar_row['group_id'].strip()}"
    group_regex = str(source_config.get("group_regex", ""))
    if group_regex:
        match = re.search(group_regex, relative_path, flags=re.IGNORECASE)
        if not match:
            raise ManifestPreparationError(
                f"group_regex did not match {source_id}/{relative_path}"
            )
        if "group_id" in match.groupdict():
            captured = match.group("group_id")
        elif match.groups():
            captured = match.group(1)
        else:
            captured = match.group(0)
        return f"{source_id}:{captured}"

    time_bucket = source_config.get("filename_time_bucket")
    if time_bucket is not None:
        if not isinstance(time_bucket, Mapping):
            raise ManifestPreparationError(
                f"filename_time_bucket for {source_id!r} must be an object"
            )
        try:
            bucket_seconds = int(time_bucket.get("bucket_seconds", 0))
            timezone_offset_minutes = int(time_bucket.get("timezone_offset_minutes", 0))
        except (TypeError, ValueError) as error:
            raise ManifestPreparationError(
                f"filename_time_bucket for {source_id!r} has non-integer settings"
            ) from error
        if bucket_seconds <= 0:
            raise ManifestPreparationError(
                f"filename_time_bucket for {source_id!r} requires positive "
                "bucket_seconds"
            )
        if not -1439 <= timezone_offset_minutes <= 1439:
            raise ManifestPreparationError(
                f"filename_time_bucket for {source_id!r} has invalid "
                "timezone_offset_minutes; expected -1439 through 1439"
            )
        scope = str(time_bucket.get("scope", "parent")).strip().casefold()
        if scope not in {"source", "parent"}:
            raise ManifestPreparationError(
                f"filename_time_bucket for {source_id!r} has unsupported scope "
                f"{scope!r}; expected 'source' or 'parent'"
            )
        timestamp = _filename_timestamp_seconds(
            Path(relative_path).stem,
            timezone_offset_minutes=timezone_offset_minutes,
        )
        if timestamp is not None:
            bucket = timestamp // bucket_seconds
            if scope == "parent":
                parent = Path(relative_path).parent.as_posix().casefold()
                return f"{source_id}:time:{parent}:{bucket}"
            return f"{source_id}:time:{bucket}"

    path = Path(relative_path)
    stem = path.stem.casefold()
    stem = re.sub(
        r"(?:[_ .-](?:aug(?:mented)?|flip(?:ped)?|rot(?:ate|ated|ation|[_-]?\d+)|patch|copy|"
        r"brightness|contrast|noise|shear|zoom)(?:[_ .-]?\d+)*)+$",
        "",
        stem,
    )
    return f"{source_id}:{path.parent.as_posix().casefold()}:{stem}"


def _filename_timestamp_seconds(
    stem: str,
    *,
    timezone_offset_minutes: int,
) -> int | None:
    """Extract common camera or epoch timestamps from a filename stem.

    Central Java contains rapid capture sequences named both as local camera
    timestamps (``YYYYMMDD_HHMMSS[mmm]``) and Unix milliseconds. Converting
    both forms to one integer timeline lets a source opt into conservative
    capture-burst grouping before the split is assigned. Unrecognised names
    deliberately fall back to the normal stem-based group.
    """

    camera_match = re.search(
        r"(?<!\d)(?P<date>\d{8})[_-](?P<time>\d{6})(?:\d{3})?(?!\d)",
        stem,
    )
    if camera_match:
        try:
            local_time = datetime.strptime(
                camera_match.group("date") + camera_match.group("time"),
                "%Y%m%d%H%M%S",
            ).replace(tzinfo=timezone(timedelta(minutes=timezone_offset_minutes)))
        except ValueError:
            return None
        return int(local_time.timestamp())

    epoch_milliseconds = re.search(r"(?<!\d)(?P<epoch>\d{13})(?!\d)", stem)
    if epoch_milliseconds:
        return int(epoch_milliseconds.group("epoch")) // 1000

    epoch_seconds = re.search(r"(?<!\d)(?P<epoch>\d{10})(?!\d)", stem)
    if epoch_seconds:
        return int(epoch_seconds.group("epoch"))
    return None


def _is_derivative(
    relative_path: str,
    source_config: Mapping[str, Any],
    sidecar_row: Mapping[str, str] | None,
) -> bool:
    if sidecar_row and "is_derivative" in sidecar_row:
        return _is_truthy(sidecar_row["is_derivative"])
    if _glob_matches(relative_path, source_config.get("derivative_globs", [])):
        return True
    patterns = [
        *DEFAULT_DERIVATIVE_PATTERNS,
        *source_config.get("derivative_regexes", []),
    ]
    return any(
        re.search(pattern, relative_path, flags=re.IGNORECASE) for pattern in patterns
    )


def _discover_source_images(
    source_root: Path,
    source_id: str,
    source_config: Mapping[str, Any],
    locked_sources: Mapping[str, str],
    skip_unknown: bool,
) -> tuple[list[ImageRecord], list[str]]:
    image_paths = sorted(
        (
            path
            for path in source_root.rglob("*")
            if path.is_file() and path.suffix.casefold() in IMAGE_EXTENSIONS
        ),
        key=lambda item: item.as_posix().casefold(),
    )
    if not image_paths:
        return [], []
    sidecar = _load_sidecar(source_root, source_config)
    if source_config.get("requires_metadata") and not sidecar:
        raise ManifestPreparationError(
            f"source {source_id} requires .labels.csv or labels.csv"
        )
    includes = source_config.get("include_globs", ["**/*"])
    excludes = source_config.get("exclude_globs", [])
    errors: list[str] = []
    records: list[ImageRecord] = []
    if not isinstance(source_config.get("is_field"), bool):
        return [], [f"source {source_id!r} must declare boolean is_field metadata"]
    is_field = bool(source_config["is_field"])
    for path in image_paths:
        relative_path = path.relative_to(source_root).as_posix()
        if includes and not _glob_matches(relative_path, includes):
            continue
        if excludes and _glob_matches(relative_path, excludes):
            continue
        sidecar_row = sidecar.get(relative_path.casefold())
        label = _label_for_path(relative_path, source_config, sidecar_row)
        if label is None:
            if skip_unknown or source_config.get("skip_unmapped", False):
                continue
            errors.append(f"unmapped class: {source_id}/{relative_path}")
            continue
        derivative = _is_derivative(relative_path, source_config, sidecar_row)
        source_lock = str(
            locked_sources.get(source_id, source_config.get("locked_split", ""))
        ).strip()
        if source_lock and source_lock not in ALLOWED_SPLITS:
            errors.append(
                f"invalid locked split {source_lock!r} for source {source_id}"
            )
            continue
        if derivative and source_lock and source_lock != "train":
            errors.append(
                f"derivative image in locked evaluation source: {source_id}/{relative_path}"
            )
            continue
        try:
            sha256, phash = verify_and_fingerprint(path)
        except ManifestPreparationError as error:
            errors.append(str(error))
            continue
        numeric_capture = (
            None
            if sidecar_row and sidecar_row.get("group_id", "").strip()
            else _infer_numeric_capture(
                relative_path,
                source_id,
                source_config,
                label,
            )
        )
        records.append(
            ImageRecord(
                path=path,
                relative_path=relative_path,
                source_id=source_id,
                crop=label["crop"],
                condition_label=label["condition_label"],
                validity_label=label["validity_label"],
                base_group=(
                    numeric_capture.base_group
                    if numeric_capture is not None
                    else _infer_base_group(
                        relative_path, source_id, source_config, sidecar_row
                    )
                ),
                sha256=sha256,
                phash=phash,
                is_derivative=derivative,
                is_field=is_field,
                source_locked_split=source_lock,
                numeric_capture=numeric_capture,
            )
        )
    return records, errors


def _cluster_records(
    records: list[ImageRecord], near_duplicate_distance: int
) -> list[list[int]]:
    disjoint = _DisjointSet(len(records))
    by_base_group: dict[str, int] = {}
    by_sha256: dict[str, int] = {}
    phash_tree = _BKTree()
    for index, record in enumerate(records):
        prior_group = by_base_group.setdefault(record.base_group, index)
        disjoint.union(index, prior_group)
        prior_hash = by_sha256.setdefault(record.sha256, index)
        disjoint.union(index, prior_hash)
        phash_value = int(record.phash, 16)
        for near_index in phash_tree.query(phash_value, near_duplicate_distance):
            disjoint.union(index, near_index)
        phash_tree.add(phash_value, index)

    _union_numeric_capture_groups(disjoint, records)

    components: dict[int, list[int]] = defaultdict(list)
    for index in range(len(records)):
        components[disjoint.find(index)].append(index)
    ordered = sorted(
        components.values(),
        key=lambda indices: min(
            f"{records[index].source_id}/{records[index].relative_path}"
            for index in indices
        ).casefold(),
    )
    for indices in ordered:
        identities = sorted(
            f"{records[index].source_id}/{records[index].relative_path}"
            for index in indices
        )
        digest = hashlib.sha256("\n".join(identities).encode("utf-8")).hexdigest()[:20]
        for index in indices:
            records[index].group_id = f"grp_{digest}"
    return ordered


def _union_numeric_capture_groups(
    disjoint: _DisjointSet, records: Sequence[ImageRecord]
) -> None:
    """Union duplicate numeric stems and visually corroborated neighbours.

    Same-number collisions are locked together even when their pixels differ,
    because the upstream filename no longer provides independent lineage.
    Consecutive numbers are weaker evidence and therefore require the stricter,
    source-configured pHash bound and the exact filename-suffix cohort as well.
    Sequence keys already include the source and canonical class labels, so
    this pass cannot create a cross-class or cross-source component on filename
    evidence alone.
    """

    sequences: dict[str, dict[int, list[int]]] = defaultdict(lambda: defaultdict(list))
    policies: dict[str, tuple[int, int]] = {}
    for index, record in enumerate(records):
        capture = record.numeric_capture
        if capture is None:
            continue
        policy = (
            capture.maximum_adjacent_gap,
            capture.maximum_phash_distance,
        )
        existing = policies.setdefault(capture.adjacency_key, policy)
        if existing != policy:
            raise ManifestPreparationError(
                f"numeric capture sequence {capture.adjacency_key!r} mixes "
                f"grouping policies {existing} and {policy}"
            )
        sequences[capture.adjacency_key][capture.number].append(index)

    for sequence_key in sorted(sequences):
        by_number = sequences[sequence_key]
        numbers = sorted(by_number)
        maximum_gap, maximum_distance = policies[sequence_key]
        for indices in by_number.values():
            for index in indices[1:]:
                disjoint.union(indices[0], index)
        for position, left_number in enumerate(numbers):
            for right_position in range(position + 1, len(numbers)):
                right_number = numbers[right_position]
                gap = right_number - left_number
                if gap > maximum_gap:
                    break
                left_indices = by_number[left_number]
                right_indices = by_number[right_number]
                if any(
                    hamming_distance(records[left].phash, records[right].phash)
                    <= maximum_distance
                    for left in left_indices
                    for right in right_indices
                ):
                    disjoint.union(left_indices[0], right_indices[0])


def _stable_order_key(seed: int, records: list[ImageRecord], indices: list[int]) -> str:
    group_id = records[indices[0]].group_id
    return hashlib.sha256(f"{seed}:{group_id}".encode("utf-8")).hexdigest()


def _apportion(component_count: int) -> dict[str, int]:
    exact = {
        split: DEFAULT_SPLIT_RATIOS[split] * component_count
        for split in REQUIRED_SPLITS
    }
    counts = {split: math.floor(value) for split, value in exact.items()}
    remaining = component_count - sum(counts.values())
    priority = {split: index for index, split in enumerate(REQUIRED_SPLITS)}
    order = sorted(
        REQUIRED_SPLITS,
        key=lambda split: (-(exact[split] - counts[split]), priority[split]),
    )
    for split in order[:remaining]:
        counts[split] += 1
    return counts


def _assign_splits(
    records: list[ImageRecord],
    components: list[list[int]],
    seed: int,
) -> None:
    unlocked: list[list[int]] = []
    for indices in components:
        locks = {
            records[index].source_locked_split
            for index in indices
            if records[index].source_locked_split
        }
        has_derivative = any(records[index].is_derivative for index in indices)
        if len(locks) > 1:
            descriptions = sorted(locks)
            raise ManifestPreparationError(
                f"duplicate/group component has conflicting source locks: {descriptions}"
            )
        if locks and has_derivative and next(iter(locks)) != "train":
            raise ManifestPreparationError(
                f"group {records[indices[0]].group_id} mixes derivative data with a locked "
                "evaluation source"
            )
        if locks:
            split = next(iter(locks))
        elif has_derivative:
            split = "train"
        else:
            unlocked.append(indices)
            continue
        for index in indices:
            records[index].split = split

    strata: dict[tuple[str, str, str, str], list[list[int]]] = defaultdict(list)
    for indices in unlocked:
        source_ids = "+".join(sorted({records[index].source_id for index in indices}))
        crops = "+".join(sorted({records[index].crop for index in indices}))
        conditions = "+".join(
            sorted({records[index].condition_label for index in indices})
        )
        validities = "+".join(
            sorted({records[index].validity_label for index in indices})
        )
        strata[(source_ids, crops, conditions, validities)].append(indices)

    for stratum in sorted(strata):
        stratum_components = sorted(
            strata[stratum],
            key=lambda indices: _stable_order_key(seed, records, indices),
        )
        counts = _apportion(len(stratum_components))
        offset = 0
        for split in REQUIRED_SPLITS:
            end = offset + counts[split]
            for indices in stratum_components[offset:end]:
                for index in indices:
                    records[index].split = split
            offset = end

    # Small strata can round entirely into train.  If the corpus has enough
    # independent, unlocked groups, deterministically seed each required split.
    counts_by_split = {
        split: sum(1 for record in records if record.split == split)
        for split in REQUIRED_SPLITS
    }
    missing = [split for split in REQUIRED_SPLITS if counts_by_split[split] == 0]
    if missing:
        movable = sorted(
            (
                indices
                for indices in unlocked
                if records[indices[0]].split == "train"
                and not any(records[index].is_derivative for index in indices)
            ),
            key=lambda indices: _stable_order_key(seed + 1, records, indices),
        )
        if len(movable) >= len(missing):
            for split, indices in zip(missing, movable, strict=True):
                for index in indices:
                    records[index].split = split


def _locked_sources_from_config(config: Mapping[str, Any]) -> dict[str, str]:
    split_policy = config.get("split_policy", {})
    locked = {
        str(source): "external_test"
        for source in split_policy.get("locked_external_test_sources", [])
    }
    future_nepal = str(split_policy.get("future_nepal_test_source", "")).strip()
    if future_nepal:
        locked[future_nepal] = "external_test"
    return locked


def _canonical_source_id(
    source_root: Path,
    folder_id: str,
    source_config: Mapping[str, Any],
) -> str:
    configured = str(source_config.get("canonical_source_id", folder_id)).strip()
    receipt_path = source_root / ".receipt.json"
    if not receipt_path.is_file():
        return configured
    try:
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ManifestPreparationError(
            f"invalid acquisition receipt {receipt_path}: {error}"
        ) from error
    received = str(receipt.get("source_id", "")).strip()
    if not received:
        raise ManifestPreparationError(
            f"acquisition receipt has no source_id: {receipt_path}"
        )
    if "canonical_source_id" in source_config and received != configured:
        raise ManifestPreparationError(
            f"source identity mismatch for {folder_id!r}: aliases say {configured!r}, "
            f"receipt says {received!r}"
        )
    return received


def _find_repo_root(start: Path) -> Path | None:
    """Return the nearest Git worktree root, if ``start`` is inside one."""

    cursor = start.resolve()
    if cursor.is_file():
        cursor = cursor.parent
    for candidate in (cursor, *cursor.parents):
        if (candidate / ".git").exists():
            return candidate
    return None


def _manifest_image_path(
    path: Path,
    *,
    path_mode: str,
    repo_root: Path | None,
) -> str:
    resolved = path.resolve()
    if path_mode == "absolute":
        return str(resolved)
    if repo_root is not None:
        try:
            return resolved.relative_to(repo_root).as_posix()
        except ValueError:
            if path_mode == "repo-relative":
                raise ManifestPreparationError(
                    f"cannot emit repo-relative path for {resolved}; it is outside "
                    f"repository root {repo_root}"
                )
    if path_mode == "repo-relative":
        raise ManifestPreparationError(
            "repo-relative path mode requires raw data inside a Git worktree or "
            "an explicit repo_root"
        )
    return str(resolved)


def build_manifest(
    raw_root: Path,
    output_path: Path,
    aliases_path: Path,
    *,
    config: Mapping[str, Any] | None = None,
    seed: int = 20260804,
    near_duplicate_distance: int = 4,
    skip_unknown: bool = False,
    selected_sources: set[str] | None = None,
    path_mode: str = "auto",
    repo_root: Path | None = None,
) -> list[dict[str, str]]:
    if near_duplicate_distance < 0 or near_duplicate_distance > 64:
        raise ManifestPreparationError(
            "near-duplicate distance must be between 0 and 64"
        )
    if path_mode not in PATH_MODES:
        raise ManifestPreparationError(
            f"path_mode must be one of {PATH_MODES}, found {path_mode!r}"
        )
    aliases = load_aliases(aliases_path)
    config = config or {}
    locked_sources = _locked_sources_from_config(config)
    source_configs: Mapping[str, Any] = aliases["sources"]
    if not raw_root.is_dir():
        raise ManifestPreparationError(f"raw dataset root does not exist: {raw_root}")
    resolved_repo_root = (
        repo_root.resolve() if repo_root is not None else _find_repo_root(raw_root)
    )
    if path_mode == "repo-relative":
        if resolved_repo_root is None:
            raise ManifestPreparationError(
                "repo-relative path mode requires raw data inside a Git worktree or "
                "an explicit repo_root"
            )
        try:
            raw_root.resolve().relative_to(resolved_repo_root)
        except ValueError as error:
            raise ManifestPreparationError(
                f"raw dataset root {raw_root.resolve()} is outside repository root "
                f"{resolved_repo_root}"
            ) from error

    records: list[ImageRecord] = []
    errors: list[str] = []
    source_directories = sorted(
        (path for path in raw_root.iterdir() if path.is_dir()),
        key=lambda path: path.name.casefold(),
    )
    for source_root in source_directories:
        folder_id = source_root.name
        if selected_sources is not None and folder_id not in selected_sources:
            # Canonical ids are checked after loading the folder alias below.
            candidate_config = source_configs.get(folder_id)
            if candidate_config is None:
                continue
            canonical_id = _canonical_source_id(
                source_root, folder_id, candidate_config
            )
            if canonical_id not in selected_sources:
                continue
        source_config = source_configs.get(folder_id)
        if source_config is None:
            if skip_unknown:
                continue
            errors.append(f"source {folder_id!r} has no entry in {aliases_path}")
            continue
        source_id = _canonical_source_id(source_root, folder_id, source_config)
        source_records, source_errors = _discover_source_images(
            source_root,
            source_id,
            source_config,
            locked_sources,
            skip_unknown,
        )
        records.extend(source_records)
        errors.extend(source_errors)

    if errors:
        preview = "\n".join(f"- {error}" for error in errors[:30])
        suffix = f"\n- ... and {len(errors) - 30} more" if len(errors) > 30 else ""
        raise ManifestPreparationError(
            f"raw-data validation failed:\n{preview}{suffix}"
        )
    if not records:
        raise ManifestPreparationError("no labelled images were discovered")

    components = _cluster_records(records, near_duplicate_distance)
    _assign_splits(records, components, seed)
    rows = [
        record.to_row(
            image_path=_manifest_image_path(
                record.path,
                path_mode=path_mode,
                repo_root=resolved_repo_root,
            )
        )
        for record in sorted(
            records,
            key=lambda record: (record.source_id, record.relative_path.casefold()),
        )
    ]
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = output_path.with_suffix(output_path.suffix + ".tmp")
    with temporary_path.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.DictWriter(
            output_file, fieldnames=MANIFEST_COLUMNS, lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)
    temporary_path.replace(output_path)
    return rows


def _load_json(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ManifestPreparationError(f"cannot read config {path}: {error}") from error


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path("ml/configs/field_v1.json"))
    parser.add_argument("--raw-root", type=Path, default=Path("ml/data/raw"))
    parser.add_argument(
        "--aliases", type=Path, default=Path("ml/datasets/label_aliases.json")
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--seed", type=int)
    parser.add_argument("--near-duplicate-distance", type=int)
    parser.add_argument(
        "--path-mode",
        choices=PATH_MODES,
        help=(
            "image path representation (default: config manifest_path_mode or auto; "
            "auto emits repo-relative paths for data inside the repository)"
        ),
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        help="explicit repository root used by repo-relative path mode",
    )
    parser.add_argument(
        "--source",
        action="append",
        dest="sources",
        help="prepare only this raw-folder or canonical source id (repeatable)",
    )
    parser.add_argument(
        "--skip-unknown",
        action="store_true",
        help="skip unknown source directories and unmapped classes",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    config = _load_json(arguments.config) if arguments.config.is_file() else {}
    split_policy = config.get("split_policy", {})
    output_path = arguments.output or Path(
        config.get("manifest", "ml/data/prepared/manifest.csv")
    )
    seed = (
        arguments.seed
        if arguments.seed is not None
        else int(config.get("seed", 20260804))
    )
    distance = (
        arguments.near_duplicate_distance
        if arguments.near_duplicate_distance is not None
        else int(split_policy.get("near_duplicate_hamming_distance", 4))
    )
    path_mode = arguments.path_mode or str(config.get("manifest_path_mode", "auto"))
    rows = build_manifest(
        arguments.raw_root,
        output_path,
        arguments.aliases,
        config=config,
        seed=seed,
        near_duplicate_distance=distance,
        skip_unknown=arguments.skip_unknown,
        selected_sources=set(arguments.sources) if arguments.sources else None,
        path_mode=path_mode,
        repo_root=arguments.repo_root,
    )
    split_counts: dict[str, int] = defaultdict(int)
    for row in rows:
        split_counts[row["split"]] += 1
    print(f"wrote {len(rows)} verified images to {output_path}")
    print(
        "split counts: "
        + ", ".join(f"{key}={split_counts[key]}" for key in sorted(split_counts))
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
