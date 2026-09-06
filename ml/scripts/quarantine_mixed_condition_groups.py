"""Quarantine manifest groups with contradictory canonical conditions.

A group is quarantined whenever its rows contain more than one canonical
``condition_label``.  Canonical labels comprise every crop's taxonomy
``known`` and explicit ``unknown`` labels plus ``not_applicable``.  The rule
has no crop, source, split, unknown-label, or ``not_applicable`` waiver.  Once
a group triggers, every row in that group is removed so a leakage unit is
never split.

The input manifest is never modified.  The sanitized CSV and its JSON
quarantine evidence are staged as sibling temporary files and atomically
replaced.  The sidecar intentionally has no timestamp, making repeated runs
over the same paths and bytes deterministic.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import tempfile
from collections import defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence

try:  # Supports both ``python ml/scripts/...`` and package imports in tests.
    from prepare_manifest import MANIFEST_COLUMNS
except ImportError:  # pragma: no cover - selected by import style
    from ml.scripts.prepare_manifest import MANIFEST_COLUMNS


REASON_CODE = "multiple_canonical_condition_labels"
REQUIRED_NONBLANK_COLUMNS = frozenset(MANIFEST_COLUMNS).difference(
    {"source_locked_split"}
)


class ManifestSanitizationError(RuntimeError):
    """Raised when a manifest cannot be sanitized without ambiguity."""


def _sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def _sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as input_file:
        for chunk in iter(lambda: input_file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _read_bytes(path: Path, description: str) -> bytes:
    try:
        return path.read_bytes()
    except OSError as error:
        raise ManifestSanitizationError(
            f"cannot read {description} {path}: {error}"
        ) from error


def _canonical_conditions(
    taxonomy_bytes: bytes, taxonomy_path: Path
) -> tuple[frozenset[str], dict[str, str]]:
    try:
        taxonomy = json.loads(taxonomy_bytes.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise ManifestSanitizationError(
            f"cannot parse taxonomy {taxonomy_path}: {error}"
        ) from error
    if not isinstance(taxonomy, Mapping):
        raise ManifestSanitizationError("taxonomy root must be an object")
    crops = taxonomy.get("crops")
    if not isinstance(crops, Mapping) or not crops:
        raise ManifestSanitizationError(
            "taxonomy must contain a non-empty crops object"
        )

    canonical_conditions = {"not_applicable"}
    owner_by_condition: dict[str, str] = {}
    for raw_crop, raw_config in crops.items():
        crop = str(raw_crop).strip()
        if not crop:
            raise ManifestSanitizationError("taxonomy contains a blank crop name")
        if not isinstance(raw_config, Mapping):
            raise ManifestSanitizationError(f"taxonomy crop {crop!r} must be an object")
        raw_known = raw_config.get("known")
        if not isinstance(raw_known, list) or not raw_known:
            raise ManifestSanitizationError(
                f"taxonomy crop {crop!r} must have a non-empty known list"
            )
        known_values = [str(value).strip() for value in raw_known]
        if any(not value for value in known_values):
            raise ManifestSanitizationError(
                f"taxonomy crop {crop!r} has a blank known condition"
            )
        if len(known_values) != len(set(known_values)):
            raise ManifestSanitizationError(
                f"taxonomy crop {crop!r} repeats a known condition"
            )
        unknown = str(raw_config.get("unknown", "")).strip()
        if not unknown:
            raise ManifestSanitizationError(
                f"taxonomy crop {crop!r} must have an explicit unknown condition"
            )
        crop_conditions = [*known_values, unknown]
        if len(crop_conditions) != len(set(crop_conditions)):
            raise ManifestSanitizationError(
                f"taxonomy crop {crop!r} reuses a known condition as its unknown"
            )
        for condition in crop_conditions:
            prior_owner = owner_by_condition.setdefault(condition, crop)
            if prior_owner != crop:
                raise ManifestSanitizationError(
                    f"canonical condition {condition!r} belongs to both "
                    f"{prior_owner!r} and {crop!r}"
                )
            canonical_conditions.add(condition)

    return frozenset(canonical_conditions), owner_by_condition


def _read_manifest(
    manifest_bytes: bytes, manifest_path: Path
) -> tuple[list[str], list[tuple[int, dict[str, str]]]]:
    try:
        text = manifest_bytes.decode("utf-8-sig")
    except UnicodeDecodeError as error:
        raise ManifestSanitizationError(
            f"manifest is not valid UTF-8: {manifest_path}: {error}"
        ) from error

    with io.StringIO(text, newline="") as input_file:
        reader = csv.DictReader(input_file)
        if reader.fieldnames is None:
            raise ManifestSanitizationError(f"manifest is empty: {manifest_path}")
        fieldnames = list(reader.fieldnames)
        if any(not fieldname for fieldname in fieldnames):
            raise ManifestSanitizationError("manifest contains a blank column name")
        if len(fieldnames) != len(set(fieldnames)):
            raise ManifestSanitizationError("manifest contains duplicate column names")
        missing = set(MANIFEST_COLUMNS).difference(fieldnames)
        if missing:
            raise ManifestSanitizationError(
                f"manifest is missing required columns: {sorted(missing)}"
            )

        rows: list[tuple[int, dict[str, str]]] = []
        for row_number, raw_row in enumerate(reader, start=2):
            if None in raw_row:
                raise ManifestSanitizationError(
                    f"row {row_number} has more values than the manifest header"
                )
            missing_values = [
                column for column in fieldnames if raw_row.get(column) is None
            ]
            if missing_values:
                raise ManifestSanitizationError(
                    f"row {row_number} is missing values for columns {missing_values}"
                )
            row = {column: str(raw_row[column]) for column in fieldnames}
            blank_required = sorted(
                column
                for column in REQUIRED_NONBLANK_COLUMNS
                if not row[column].strip()
            )
            if blank_required:
                raise ManifestSanitizationError(
                    f"row {row_number} has blank required fields {blank_required}"
                )
            sha256 = row["sha256"].strip().casefold()
            if len(sha256) != 64 or any(
                character not in "0123456789abcdef" for character in sha256
            ):
                raise ManifestSanitizationError(
                    f"row {row_number} has invalid SHA256 {row['sha256']!r}"
                )
            rows.append((row_number, row))

    if not rows:
        raise ManifestSanitizationError(f"manifest has no image rows: {manifest_path}")
    return fieldnames, rows


def _validate_output_paths(
    manifest_path: Path,
    taxonomy_path: Path,
    output_path: Path,
    quarantine_path: Path,
) -> None:
    named_paths = {
        "input manifest": manifest_path.resolve(),
        "taxonomy": taxonomy_path.resolve(),
        "sanitized output": output_path.resolve(),
        "quarantine sidecar": quarantine_path.resolve(),
    }
    protected = {named_paths["input manifest"], named_paths["taxonomy"]}
    if named_paths["sanitized output"] in protected:
        raise ManifestSanitizationError(
            "sanitized output must not overwrite the input manifest or taxonomy"
        )
    if named_paths["quarantine sidecar"] in protected:
        raise ManifestSanitizationError(
            "quarantine sidecar must not overwrite the input manifest or taxonomy"
        )
    if named_paths["sanitized output"] == named_paths["quarantine sidecar"]:
        raise ManifestSanitizationError(
            "sanitized output and quarantine sidecar must be different paths"
        )


def _temporary_sibling(path: Path) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(
        dir=path.parent,
        prefix=f".{path.name}.",
        suffix=".tmp",
    )
    os.close(descriptor)
    return Path(temporary)


def _write_csv(
    path: Path, fieldnames: Sequence[str], rows: Sequence[Mapping[str, str]]
) -> None:
    with path.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.DictWriter(
            output_file,
            fieldnames=fieldnames,
            lineterminator="\n",
            extrasaction="raise",
        )
        writer.writeheader()
        writer.writerows(rows)


def _write_json(path: Path, payload: Mapping[str, Any]) -> None:
    path.write_text(
        json.dumps(payload, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def sanitize_manifest(
    manifest_path: Path,
    output_path: Path,
    taxonomy_path: Path,
    quarantine_path: Path,
) -> dict[str, Any]:
    """Write a sanitized manifest and return its deterministic sidecar payload."""

    _validate_output_paths(
        manifest_path,
        taxonomy_path,
        output_path,
        quarantine_path,
    )
    manifest_bytes = _read_bytes(manifest_path, "manifest")
    taxonomy_bytes = _read_bytes(taxonomy_path, "taxonomy")
    fieldnames, numbered_rows = _read_manifest(manifest_bytes, manifest_path)
    canonical_conditions, owner_by_condition = _canonical_conditions(
        taxonomy_bytes, taxonomy_path
    )

    rows_by_group: dict[str, list[tuple[int, dict[str, str]]]] = defaultdict(list)
    conditions_by_group: dict[str, set[str]] = defaultdict(set)
    for row_number, row in numbered_rows:
        crop = row["crop"].strip()
        condition = row["condition_label"].strip()
        if condition not in canonical_conditions:
            raise ManifestSanitizationError(
                f"row {row_number}: non-canonical condition_label {condition!r}"
            )
        owner = owner_by_condition.get(condition)
        if owner is not None and crop != owner:
            raise ManifestSanitizationError(
                f"row {row_number}: canonical condition {condition!r} belongs to crop "
                f"{owner!r}, not {crop!r}"
            )
        group_id = row["group_id"].strip()
        rows_by_group[group_id].append((row_number, row))
        conditions_by_group[group_id].add(condition)

    conflicts_by_group = {
        group_id: sorted(conditions)
        for group_id, conditions in conditions_by_group.items()
        if len(conditions) > 1
    }

    quarantined_group_ids = frozenset(conflicts_by_group)
    retained = [
        row
        for _, row in numbered_rows
        if row["group_id"].strip() not in quarantined_group_ids
    ]
    if not retained:
        raise ManifestSanitizationError(
            "sanitization would quarantine every manifest row; no output was written"
        )

    quarantine_groups = []
    for group_id in sorted(quarantined_group_ids):
        group_rows = rows_by_group[group_id]
        quarantine_groups.append(
            {
                "group_id": group_id,
                "reason_code": REASON_CODE,
                "condition_labels": conflicts_by_group[group_id],
                "row_count": len(group_rows),
                "rows": [
                    {
                        "input_row_number": row_number,
                        "image_path": row["image_path"],
                        "sha256": row["sha256"].casefold(),
                        "phash": row["phash"].casefold(),
                        "manifest_row": {column: row[column] for column in fieldnames},
                    }
                    for row_number, row in group_rows
                ],
            }
        )

    temporary_output: Path | None = None
    temporary_quarantine: Path | None = None
    try:
        temporary_output = _temporary_sibling(output_path)
        _write_csv(temporary_output, fieldnames, retained)
        output_sha256 = _sha256_file(temporary_output)
        sidecar: dict[str, Any] = {
            "schema_version": 1,
            "policy": {
                "reason_code": REASON_CODE,
                "trigger": (
                    "one group contains multiple taxonomy-canonical "
                    "condition_label values"
                ),
                "quarantine_whole_group": True,
                "canonical_labels": (
                    "taxonomy known and explicit unknown labels plus not_applicable"
                ),
                "waivers_allowed": False,
            },
            "input_manifest": {
                "path": str(manifest_path.resolve()),
                "sha256": _sha256_bytes(manifest_bytes),
            },
            "taxonomy": {
                "path": str(taxonomy_path.resolve()),
                "sha256": _sha256_bytes(taxonomy_bytes),
            },
            "sanitized_manifest": {
                "path": str(output_path.resolve()),
                "sha256": output_sha256,
            },
            "summary": {
                "input_rows": len(numbered_rows),
                "input_groups": len(rows_by_group),
                "quarantined_rows": len(numbered_rows) - len(retained),
                "quarantined_groups": len(quarantined_group_ids),
                "retained_rows": len(retained),
                "retained_groups": len(rows_by_group) - len(quarantined_group_ids),
            },
            "quarantined_groups": quarantine_groups,
        }
        temporary_quarantine = _temporary_sibling(quarantine_path)
        _write_json(temporary_quarantine, sidecar)

        os.replace(temporary_output, output_path)
        temporary_output = None
        os.replace(temporary_quarantine, quarantine_path)
        temporary_quarantine = None
        return sidecar
    except OSError as error:
        raise ManifestSanitizationError(
            f"cannot write sanitized manifest outputs: {error}"
        ) from error
    finally:
        for temporary in (temporary_output, temporary_quarantine):
            if temporary is not None:
                try:
                    temporary.unlink(missing_ok=True)
                except OSError:
                    pass


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument(
        "--taxonomy",
        type=Path,
        default=Path("ml/datasets/taxonomy_v1.json"),
    )
    parser.add_argument("--quarantine", type=Path, required=True)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    sidecar = sanitize_manifest(
        arguments.manifest,
        arguments.output,
        arguments.taxonomy,
        arguments.quarantine,
    )
    print(json.dumps(sidecar["summary"], indent=2, sort_keys=True))
    print(f"sanitized manifest: {arguments.output}")
    print(f"quarantine sidecar: {arguments.quarantine}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
