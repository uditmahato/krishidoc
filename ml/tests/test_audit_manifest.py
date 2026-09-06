from __future__ import annotations

import csv
import json
from collections import Counter
from pathlib import Path

import pytest

from ml.scripts.audit_manifest import ManifestAuditError, audit_manifest
from ml.scripts.prepare_manifest import MANIFEST_COLUMNS, build_manifest
from ml.tests.test_prepare_manifest import _make_fixture_corpus


TAXONOMY = Path(__file__).parents[1] / "datasets" / "taxonomy_v1.json"


def _prepared_manifest(tmp_path: Path) -> tuple[Path, Path, Path]:
    raw_root, aliases_path, config = _make_fixture_corpus(tmp_path)
    config_path = tmp_path / "config.json"
    config_path.write_text(json.dumps(config), encoding="utf-8")
    manifest_path = tmp_path / "manifest.csv"
    build_manifest(
        raw_root,
        manifest_path,
        aliases_path,
        config=config,
        seed=17,
    )
    return manifest_path, aliases_path, config_path


def _read_rows(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as input_file:
        return list(csv.DictReader(input_file))


def _write_rows(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.DictWriter(
            output_file, fieldnames=MANIFEST_COLUMNS, lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)


def _audit(
    manifest_path: Path,
    aliases_path: Path,
    config_path: Path,
    *,
    verify_images: bool = False,
):
    return audit_manifest(
        manifest_path,
        TAXONOMY,
        aliases_path=aliases_path,
        config_path=config_path,
        verify_images=verify_images,
    )


def test_audit_accepts_verified_prepared_manifest(tmp_path: Path) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    summary = _audit(
        manifest_path,
        aliases_path,
        config_path,
        verify_images=True,
    )

    assert summary["rows"] == 35
    assert summary["verified_images"] == 35
    assert summary["field_counts"] == {"field": 35}
    assert set(summary["split_counts"]).issuperset(
        {"train", "validation", "calibration", "test", "external_test"}
    )


def test_audit_resolves_repo_relative_paths_after_worktree_moves(
    tmp_path: Path,
) -> None:
    repo_root = tmp_path / "source-worktree"
    (repo_root / ".git").mkdir(parents=True)
    raw_root, aliases_path, config = _make_fixture_corpus(repo_root)
    config_path = repo_root / "config.json"
    config_path.write_text(json.dumps(config), encoding="utf-8")
    manifest_path = repo_root / "ml" / "data" / "prepared" / "manifest.csv"
    rows = build_manifest(
        raw_root,
        manifest_path,
        aliases_path,
        config=config,
        seed=17,
    )
    assert all(not Path(row["image_path"]).is_absolute() for row in rows)

    moved_root = tmp_path / "moved-worktree"
    repo_root.rename(moved_root)
    summary = audit_manifest(
        moved_root / "ml" / "data" / "prepared" / "manifest.csv",
        TAXONOMY,
        aliases_path=moved_root / "aliases.json",
        config_path=moved_root / "config.json",
        verify_images=True,
    )

    assert summary["verified_images"] == 35


def test_audit_hard_fails_group_and_near_duplicate_leakage(tmp_path: Path) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    original = next(
        row for row in rows if Path(row["image_path"]).name == "image_01.png"
    )
    variant = next(
        row for row in rows if Path(row["image_path"]).name == "visual_variant.png"
    )
    assert original["group_id"] == variant["group_id"]
    variant["group_id"] = "manually_broken_group"
    variant["split"] = "test" if original["split"] != "test" else "validation"
    _write_rows(manifest_path, rows)

    with pytest.raises(ManifestAuditError, match="near-duplicate leakage"):
        _audit(manifest_path, aliases_path, config_path)


def test_audit_hard_fails_exact_hash_leakage(tmp_path: Path) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    left = rows[0]
    right = next(row for row in rows if row["split"] != left["split"])
    right["sha256"] = left["sha256"]
    right["phash"] = left["phash"]
    right["group_id"] = "unclustered-copy"
    _write_rows(manifest_path, rows)

    with pytest.raises(ManifestAuditError, match="exact-hash leakage"):
        _audit(manifest_path, aliases_path, config_path)


def test_audit_hard_fails_mixed_known_conditions_within_group(
    tmp_path: Path,
) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    group_counts = Counter(row["group_id"] for row in rows)
    phash_counts = Counter(row["phash"] for row in rows)
    candidates = [
        row
        for row in rows
        if row["source_id"] == "fixture-source"
        and row["validity_label"] == "usable_target_leaf"
        and row["is_derivative"] == "0"
        and group_counts[row["group_id"]] == 1
        and phash_counts[row["phash"]] == 1
    ]
    left = candidates[0]
    right = next(
        row
        for row in candidates[1:]
        if row["split"] == left["split"] and row["group_id"] != left["group_id"]
    )
    right["condition_label"] = "maize_common_rust"
    right["group_id"] = left["group_id"]
    _write_rows(manifest_path, rows)

    with pytest.raises(
        ManifestAuditError,
        match="conflicting canonical condition labels.*quarantine the entire group",
    ):
        _audit(manifest_path, aliases_path, config_path)


def test_audit_hard_fails_known_and_open_set_unknown_in_one_group(
    tmp_path: Path,
) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    group_counts = Counter(row["group_id"] for row in rows)
    phash_counts = Counter(row["phash"] for row in rows)
    candidates = [
        row
        for row in rows
        if row["source_id"] == "fixture-source"
        and row["validity_label"] == "usable_target_leaf"
        and row["is_derivative"] == "0"
        and group_counts[row["group_id"]] == 1
        and phash_counts[row["phash"]] == 1
    ]
    left = candidates[0]
    right = next(
        row
        for row in candidates[1:]
        if row["split"] == left["split"] and row["group_id"] != left["group_id"]
    )
    right["condition_label"] = "maize_other_unknown"
    right["group_id"] = left["group_id"]
    _write_rows(manifest_path, rows)

    with pytest.raises(
        ManifestAuditError,
        match="conflicting canonical condition labels.*quarantine the entire group",
    ):
        _audit(manifest_path, aliases_path, config_path)


def test_audit_hard_fails_mixed_conditions_across_observed_crops(
    tmp_path: Path,
) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    group_counts = Counter(row["group_id"] for row in rows)
    phash_counts = Counter(row["phash"] for row in rows)
    candidates = [
        row
        for row in rows
        if row["source_id"] == "fixture-source"
        and row["validity_label"] == "usable_target_leaf"
        and row["is_derivative"] == "0"
        and group_counts[row["group_id"]] == 1
        and phash_counts[row["phash"]] == 1
    ]
    left = candidates[0]
    right = next(
        row
        for row in candidates[1:]
        if row["split"] == left["split"] and row["group_id"] != left["group_id"]
    )
    right["crop"] = "potato"
    right["condition_label"] = "potato_healthy"
    right["group_id"] = left["group_id"]
    _write_rows(manifest_path, rows)

    with pytest.raises(
        ManifestAuditError,
        match="conflicting canonical condition labels.*quarantine the entire group",
    ):
        _audit(manifest_path, aliases_path, config_path)


def test_audit_hard_fails_whole_source_lock_violation(tmp_path: Path) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    external = next(row for row in rows if row["source_id"] == "external-source")
    external["split"] = "test"
    _write_rows(manifest_path, rows)

    with pytest.raises(ManifestAuditError, match="source lock requires"):
        _audit(manifest_path, aliases_path, config_path)


def test_audit_hard_fails_unknown_label_and_empty_required_split(
    tmp_path: Path,
) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    rows[0]["condition_label"] = "invented_disease"
    rows = [row for row in rows if row["split"] != "calibration"]
    _write_rows(manifest_path, rows)

    with pytest.raises(ManifestAuditError) as failure:
        _audit(manifest_path, aliases_path, config_path)
    message = str(failure.value)
    assert "unknown condition_label" in message
    assert "required split 'calibration' is empty" in message


def test_audit_hard_fails_missing_corrupt_or_changed_files(tmp_path: Path) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    missing = Path(rows[0]["image_path"])
    missing.unlink()
    changed = Path(rows[1]["image_path"])
    changed.write_bytes(b"not a decodable image")

    with pytest.raises(ManifestAuditError) as failure:
        _audit(
            manifest_path,
            aliases_path,
            config_path,
            verify_images=True,
        )
    message = str(failure.value)
    assert "missing image" in message
    assert "corrupt/unreadable image" in message


def test_audit_hard_fails_derivative_in_evaluation(tmp_path: Path) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    derivative = next(row for row in rows if row["is_derivative"] == "1")
    derivative["split"] = "validation"
    _write_rows(manifest_path, rows)

    with pytest.raises(ManifestAuditError, match="derivative/augmented image"):
        _audit(manifest_path, aliases_path, config_path)


def test_audit_hard_fails_inconsistent_source_field_metadata(tmp_path: Path) -> None:
    manifest_path, aliases_path, config_path = _prepared_manifest(tmp_path)
    rows = _read_rows(manifest_path)
    fixture_row = next(row for row in rows if row["source_id"] == "fixture-source")
    fixture_row["is_field"] = "0"
    _write_rows(manifest_path, rows)

    with pytest.raises(ManifestAuditError, match="must declare is_field"):
        _audit(manifest_path, aliases_path, config_path)
