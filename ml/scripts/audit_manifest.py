"""Strictly audit a KrishiDoc image manifest before training or evaluation."""

from __future__ import annotations

import argparse
import csv
import json
from collections import defaultdict
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

try:  # Supports both ``python ml/scripts/...`` and package imports in tests.
    from prepare_manifest import (
        ALLOWED_SPLITS,
        CANONICAL_COLUMNS,
        MANIFEST_COLUMNS,
        REQUIRED_SPLITS,
        VALIDITY_LABELS,
        _BKTree,
        _find_repo_root,
        compute_phash,
        compute_sha256,
        load_aliases,
    )
except ImportError:  # pragma: no cover - selected by import style
    from ml.scripts.prepare_manifest import (
        ALLOWED_SPLITS,
        CANONICAL_COLUMNS,
        MANIFEST_COLUMNS,
        REQUIRED_SPLITS,
        VALIDITY_LABELS,
        _BKTree,
        _find_repo_root,
        compute_phash,
        compute_sha256,
        load_aliases,
    )

from PIL import Image, UnidentifiedImageError


class ManifestAuditError(RuntimeError):
    """Raised when a manifest violates a safety or leakage invariant."""


def _load_json(path: Path, description: str) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise ManifestAuditError(
            f"cannot read {description} {path}: {error}"
        ) from error


def _read_manifest(path: Path) -> list[dict[str, str]]:
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as input_file:
            reader = csv.DictReader(input_file)
            if reader.fieldnames is None:
                raise ManifestAuditError(f"manifest is empty: {path}")
            missing = set(MANIFEST_COLUMNS).difference(reader.fieldnames)
            if missing:
                raise ManifestAuditError(
                    f"manifest is missing required columns: {sorted(missing)}"
                )
            rows = [
                {key: str(value or "").strip() for key, value in row.items()}
                for row in reader
            ]
    except OSError as error:
        raise ManifestAuditError(f"cannot read manifest {path}: {error}") from error
    if not rows:
        raise ManifestAuditError(f"manifest has no image rows: {path}")
    return rows


def _allowed_taxonomy(
    taxonomy: Mapping[str, Any],
) -> tuple[dict[str, set[str]], set[str]]:
    crops: dict[str, set[str]] = {}
    all_conditions = {"not_applicable"}
    for crop, values in taxonomy.get("crops", {}).items():
        known = {str(label) for label in values.get("known", [])}
        unknown = str(values.get("unknown", "")).strip()
        if unknown:
            known.add(unknown)
        crops[str(crop)] = known
        all_conditions.update(known)
    if not crops:
        raise ManifestAuditError("taxonomy contains no crops")
    return crops, all_conditions


def _expected_source_locks(
    aliases: Mapping[str, Any] | None,
    config: Mapping[str, Any] | None,
) -> dict[str, str]:
    locks: dict[str, str] = {}
    if aliases:
        for source_id, source in aliases.get("sources", {}).items():
            source_id = str(source.get("canonical_source_id", source_id))
            locked_split = str(source.get("locked_split", "")).strip()
            if locked_split:
                locks[str(source_id)] = locked_split
    if config:
        policy = config.get("split_policy", {})
        for source_id in policy.get("locked_external_test_sources", []):
            locks[str(source_id)] = "external_test"
        future_nepal = str(policy.get("future_nepal_test_source", "")).strip()
        if future_nepal:
            locks[future_nepal] = "external_test"
    return locks


def _expected_source_fields(aliases: Mapping[str, Any] | None) -> dict[str, bool]:
    fields: dict[str, bool] = {}
    if aliases:
        for source_id, source in aliases.get("sources", {}).items():
            canonical_id = str(source.get("canonical_source_id", source_id))
            if isinstance(source.get("is_field"), bool):
                fields[canonical_id] = bool(source["is_field"])
    return fields


def _effective_image_root(
    manifest_path: Path,
    *,
    explicit_image_root: Path | None,
    config: Mapping[str, Any] | None,
    config_path: Path | None,
) -> Path:
    if explicit_image_root is not None:
        return explicit_image_root.resolve()

    repo_root = _find_repo_root(manifest_path)
    if repo_root is None and config_path is not None:
        repo_root = _find_repo_root(config_path)
    configured = str((config or {}).get("image_root", "")).strip()
    if configured:
        configured_root = Path(configured)
        if configured_root.is_absolute():
            return configured_root.resolve()
        anchor = repo_root
        if anchor is None:
            anchor = (
                config_path.resolve().parent
                if config_path
                else manifest_path.resolve().parent
            )
        return (anchor / configured_root).resolve()

    # The training pipeline resolves relative manifest paths from the repository
    # root. Mirror that contract here, while preserving manifest-directory
    # behavior for standalone manifests outside a worktree.
    return repo_root or manifest_path.resolve().parent


def _resolve_image_path(value: str, image_root: Path) -> Path:
    path = Path(value)
    if not path.is_absolute():
        path = image_root / path
    return path.resolve()


def _truth_value(value: str) -> bool | None:
    normalised = value.casefold()
    if normalised in {"1", "true", "yes"}:
        return True
    if normalised in {"0", "false", "no"}:
        return False
    return None


def _verify_image_job(job: tuple[Path, str, str, str]) -> list[str]:
    image_path, sha256, phash, prefix = job
    try:
        with Image.open(image_path) as image:
            image.verify()
        actual_sha256 = compute_sha256(image_path)
        actual_phash = compute_phash(image_path)
    except (OSError, ValueError, UnidentifiedImageError, RuntimeError) as error:
        return [f"{prefix}: corrupt/unreadable image {image_path}: {error}"]
    errors = []
    if actual_sha256 != sha256:
        errors.append(
            f"{prefix}: SHA256 mismatch for {image_path}; file changed after preparation"
        )
    if actual_phash != phash:
        errors.append(
            f"{prefix}: pHash mismatch for {image_path}; file changed after preparation"
        )
    return errors


def audit_manifest(
    manifest_path: Path,
    taxonomy_path: Path,
    *,
    aliases_path: Path | None = None,
    config_path: Path | None = None,
    near_duplicate_distance: int = 4,
    verify_images: bool = True,
    image_root: Path | None = None,
    image_workers: int = 1,
) -> dict[str, Any]:
    """Audit a manifest and return counts, or raise with all discovered faults."""
    if not 0 <= near_duplicate_distance <= 64:
        raise ManifestAuditError("near-duplicate distance must be between 0 and 64")
    if type(image_workers) is not int or not 1 <= image_workers <= 16:
        raise ManifestAuditError("image_workers must be an integer between 1 and 16")
    rows = _read_manifest(manifest_path)
    taxonomy = _load_json(taxonomy_path, "taxonomy")
    crops, all_conditions = _allowed_taxonomy(taxonomy)
    aliases = (
        load_aliases(aliases_path) if aliases_path and aliases_path.is_file() else None
    )
    config = (
        _load_json(config_path, "config")
        if config_path and config_path.is_file()
        else None
    )
    expected_locks = _expected_source_locks(aliases, config)
    expected_fields = _expected_source_fields(aliases)
    resolved_image_root = _effective_image_root(
        manifest_path,
        explicit_image_root=image_root,
        config=config,
        config_path=config_path,
    )

    errors: list[str] = []
    image_jobs: list[tuple[Path, str, str, str]] = []
    paths_seen: dict[Path, int] = {}
    group_splits: dict[str, set[str]] = defaultdict(set)
    group_condition_rows: dict[str, dict[str, list[int]]] = defaultdict(
        lambda: defaultdict(list)
    )
    sha_splits: dict[str, set[str]] = defaultdict(set)
    sha_groups: dict[str, set[str]] = defaultdict(set)
    source_splits: dict[str, set[str]] = defaultdict(set)
    source_declared_locks: dict[str, set[str]] = defaultdict(set)
    source_field_values: dict[str, set[bool]] = defaultdict(set)
    split_counts: dict[str, int] = defaultdict(int)
    field_counts: dict[str, int] = defaultdict(int)
    phash_entries: list[tuple[int, str, str, str]] = []

    for row_number, row in enumerate(rows, start=2):
        prefix = f"row {row_number}"
        blank_columns = [column for column in CANONICAL_COLUMNS if not row[column]]
        if blank_columns:
            errors.append(f"{prefix}: blank canonical fields {blank_columns}")
        crop = row["crop"]
        condition = row["condition_label"]
        validity = row["validity_label"]
        split = row["split"]
        source_id = row["source_id"]
        group_id = row["group_id"]
        sha256 = row["sha256"].casefold()
        phash = row["phash"].casefold()
        source_lock = row["source_locked_split"]

        if validity not in VALIDITY_LABELS:
            errors.append(f"{prefix}: unknown validity_label {validity!r}")
        if crop not in crops and crop != "unknown":
            errors.append(f"{prefix}: unknown crop {crop!r}")
        if condition not in all_conditions:
            errors.append(f"{prefix}: unknown condition_label {condition!r}")
        if validity == "usable_target_leaf":
            if crop not in crops:
                errors.append(f"{prefix}: usable target leaf requires a supported crop")
            elif condition not in crops[crop]:
                errors.append(
                    f"{prefix}: condition {condition!r} is not valid for crop {crop!r}"
                )
        if condition in all_conditions and group_id:
            group_condition_rows[group_id][condition].append(row_number)
        if validity == "unsuitable_target_crop_view" and crop not in crops:
            errors.append(
                f"{prefix}: unsuitable target view requires an observed target crop"
            )
        if validity in {"other_plant", "non_plant"}:
            if crop != "unknown" or condition != "not_applicable":
                errors.append(
                    f"{prefix}: {validity} requires crop='unknown' and "
                    "condition_label='not_applicable'"
                )
        if split not in ALLOWED_SPLITS:
            errors.append(f"{prefix}: unknown split {split!r}")
        else:
            split_counts[split] += 1
        if not source_id:
            errors.append(f"{prefix}: blank source_id")
        if not group_id:
            errors.append(f"{prefix}: blank group_id")

        if len(sha256) != 64 or any(
            character not in "0123456789abcdef" for character in sha256
        ):
            errors.append(f"{prefix}: invalid SHA256 {row['sha256']!r}")
        if len(phash) != 16 or any(
            character not in "0123456789abcdef" for character in phash
        ):
            errors.append(f"{prefix}: invalid pHash {row['phash']!r}")
        else:
            phash_entries.append((int(phash, 16), split, group_id, prefix))

        derivative = _truth_value(row["is_derivative"])
        if derivative is None:
            errors.append(
                f"{prefix}: invalid is_derivative value {row['is_derivative']!r}"
            )
        elif derivative and split != "train":
            errors.append(f"{prefix}: derivative/augmented image is present in {split}")

        is_field = _truth_value(row["is_field"])
        if is_field is None:
            errors.append(f"{prefix}: invalid is_field value {row['is_field']!r}")
        else:
            source_field_values[source_id].add(is_field)
            field_counts["field" if is_field else "non_field"] += 1
            expected_field = expected_fields.get(source_id)
            if expected_field is not None and is_field != expected_field:
                errors.append(
                    f"{prefix}: source {source_id!r} must declare is_field="
                    f"{int(expected_field)}, found {int(is_field)}"
                )

        if source_lock and source_lock not in ALLOWED_SPLITS:
            errors.append(f"{prefix}: invalid source_locked_split {source_lock!r}")
        if source_lock and split != source_lock:
            errors.append(
                f"{prefix}: source lock requires {source_lock!r}, found {split!r}"
            )
        expected_lock = expected_locks.get(source_id, "")
        if expected_lock and source_lock != expected_lock:
            errors.append(
                f"{prefix}: source {source_id!r} must declare lock {expected_lock!r}"
            )
        if expected_lock and split != expected_lock:
            errors.append(
                f"{prefix}: source {source_id!r} is locked to {expected_lock!r}, "
                f"found {split!r}"
            )

        group_splits[group_id].add(split)
        sha_splits[sha256].add(split)
        sha_groups[sha256].add(group_id)
        source_splits[source_id].add(split)
        source_declared_locks[source_id].add(source_lock)

        image_path = _resolve_image_path(row["image_path"], resolved_image_root)
        if image_path in paths_seen:
            errors.append(
                f"{prefix}: duplicate image_path also appears at row {paths_seen[image_path]}"
            )
        else:
            paths_seen[image_path] = row_number
        if not image_path.is_file():
            errors.append(f"{prefix}: missing image {image_path}")
            continue
        if verify_images:
            image_jobs.append((image_path, sha256, phash, prefix))

    # Only independent image checks are parallelized. Structural/group/split
    # checks remain unchanged; map preserves deterministic manifest error order.
    if image_jobs:
        with ThreadPoolExecutor(max_workers=image_workers) as pool:
            for completed, image_errors in enumerate(
                pool.map(_verify_image_job, image_jobs), 1
            ):
                errors.extend(image_errors)
                if image_workers > 1 and completed % 1000 == 0:
                    print(
                        f"Verified image bytes/decode/pHash: {completed}/{len(image_jobs)}",
                        flush=True,
                    )

    for split in REQUIRED_SPLITS:
        if split_counts[split] == 0:
            errors.append(f"required split {split!r} is empty")
    for group_id, splits in group_splits.items():
        if group_id and len(splits) > 1:
            errors.append(f"group leakage: {group_id!r} spans splits {sorted(splits)}")
    for group_id, condition_rows in group_condition_rows.items():
        if len(condition_rows) <= 1:
            continue
        rows_by_condition = {
            condition: row_numbers[:8]
            for condition, row_numbers in sorted(condition_rows.items())
        }
        errors.append(
            "conflicting canonical condition labels: "
            f"group {group_id!r} carries multiple canonical conditions "
            f"{sorted(condition_rows)} at manifest rows {rows_by_condition}; "
            "quarantine the entire group"
        )
    for sha256, splits in sha_splits.items():
        if sha256 and len(splits) > 1:
            errors.append(f"exact-hash leakage: {sha256} spans splits {sorted(splits)}")
    for sha256, groups in sha_groups.items():
        if sha256 and len(groups) > 1:
            errors.append(
                f"exact duplicates were not clustered: {sha256} uses groups {sorted(groups)}"
            )
    for source_id, declared_locks in source_declared_locks.items():
        nonblank = {lock for lock in declared_locks if lock}
        if nonblank and (len(nonblank) != 1 or "" in declared_locks):
            errors.append(
                f"source-lock metadata is inconsistent for {source_id!r}: "
                f"{sorted(declared_locks)}"
            )
        if nonblank:
            required = next(iter(nonblank))
            if source_splits[source_id] != {required}:
                errors.append(
                    f"whole-source lock leakage: {source_id!r} spans "
                    f"{sorted(source_splits[source_id])}, expected only {required!r}"
                )
    for source_id, values in source_field_values.items():
        if len(values) > 1:
            errors.append(
                f"source-level is_field metadata is inconsistent for {source_id!r}: "
                f"{sorted(values)}"
            )

    tree = _BKTree()
    inserted: list[tuple[int, str, str, str]] = []
    for phash_value, split, group_id, prefix in phash_entries:
        for prior_index in tree.query(phash_value, near_duplicate_distance):
            _, prior_split, prior_group, prior_prefix = inserted[prior_index]
            distance = (phash_value ^ inserted[prior_index][0]).bit_count()
            if group_id != prior_group:
                errors.append(
                    f"near duplicates were not clustered: {prior_prefix} and {prefix} "
                    f"have pHash distance {distance} but groups {prior_group!r}/{group_id!r}"
                )
            if split != prior_split:
                errors.append(
                    f"near-duplicate leakage: {prior_prefix} ({prior_split}) and "
                    f"{prefix} ({split}) have pHash distance {distance}"
                )
        tree.add(phash_value, len(inserted))
        inserted.append((phash_value, split, group_id, prefix))

    if errors:
        preview = "\n".join(f"- {error}" for error in errors[:60])
        suffix = f"\n- ... and {len(errors) - 60} more" if len(errors) > 60 else ""
        raise ManifestAuditError(
            f"manifest audit failed with {len(errors)} error(s):\n{preview}{suffix}"
        )
    return {
        "rows": len(rows),
        "groups": len(group_splits),
        "sources": len(source_splits),
        "split_counts": dict(sorted(split_counts.items())),
        "field_counts": dict(sorted(field_counts.items())),
        "mixed_canonical_condition_groups": 0,
        "verified_images": len(rows) if verify_images else 0,
    }


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--taxonomy", type=Path, default=Path("ml/datasets/taxonomy_v1.json")
    )
    parser.add_argument(
        "--aliases", type=Path, default=Path("ml/datasets/label_aliases.json")
    )
    parser.add_argument("--config", type=Path, default=Path("ml/configs/field_v1.json"))
    parser.add_argument("--near-duplicate-distance", type=int)
    parser.add_argument("--image-workers", type=int, default=1)
    parser.add_argument(
        "--image-root",
        type=Path,
        help=(
            "base for relative image paths (default: config image_root, then the "
            "manifest's repository root)"
        ),
    )
    parser.add_argument(
        "--receipt",
        type=Path,
        default=Path("ml/data/prepared/audit_receipt.json"),
        help="write a machine-readable receipt only after every audit check passes",
    )
    parser.add_argument(
        "--skip-image-verification",
        action="store_true",
        help="only for fast local diagnostics; release audits must verify images",
    )
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    arguments = _parser().parse_args(argv)
    config = (
        _load_json(arguments.config, "config") if arguments.config.is_file() else {}
    )
    distance = (
        arguments.near_duplicate_distance
        if arguments.near_duplicate_distance is not None
        else int(
            config.get("split_policy", {}).get("near_duplicate_hamming_distance", 4)
        )
    )
    summary = audit_manifest(
        arguments.manifest,
        arguments.taxonomy,
        aliases_path=arguments.aliases,
        config_path=arguments.config,
        near_duplicate_distance=distance,
        verify_images=not arguments.skip_image_verification,
        image_root=arguments.image_root,
        image_workers=arguments.image_workers,
    )
    receipt = {
        "schema_version": 1,
        "status": "passed",
        "audited_at_utc": datetime.now(timezone.utc).isoformat(),
        "image_verification": not arguments.skip_image_verification,
        "image_workers": arguments.image_workers,
        "near_duplicate_hamming_distance": distance,
        "manifest": {
            "path": str(arguments.manifest.resolve()),
            "sha256": compute_sha256(arguments.manifest),
        },
        "taxonomy": {
            "path": str(arguments.taxonomy.resolve()),
            "sha256": compute_sha256(arguments.taxonomy),
        },
        "aliases": {
            "path": str(arguments.aliases.resolve()),
            "sha256": compute_sha256(arguments.aliases),
        },
        "config": {
            "path": str(arguments.config.resolve()),
            "sha256": compute_sha256(arguments.config),
        },
        "summary": summary,
    }
    arguments.receipt.parent.mkdir(parents=True, exist_ok=True)
    temporary_receipt = arguments.receipt.with_suffix(arguments.receipt.suffix + ".tmp")
    temporary_receipt.write_text(
        json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    temporary_receipt.replace(arguments.receipt)
    print("manifest audit passed")
    print(json.dumps(summary, indent=2, sort_keys=True))
    print(f"audit receipt: {arguments.receipt}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
