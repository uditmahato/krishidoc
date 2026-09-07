from __future__ import annotations

import csv
import hashlib
import json
from pathlib import Path

import pytest

from ml.scripts.prepare_manifest import MANIFEST_COLUMNS
from ml.scripts.quarantine_mixed_condition_groups import (
    REASON_CODE,
    ManifestSanitizationError,
    sanitize_manifest,
)


TAXONOMY = Path(__file__).parents[1] / "datasets" / "taxonomy_v1.json"


def _row(
    number: int,
    *,
    group_id: str,
    crop: str,
    condition: str,
    split: str = "train",
    validity: str = "usable_target_leaf",
) -> dict[str, str]:
    return {
        "image_path": f"ml/data/raw/fixture/image_{number:02d}.jpg",
        "crop": crop,
        "condition_label": condition,
        "validity_label": validity,
        "split": split,
        "source_id": "fixture-source",
        "group_id": group_id,
        "sha256": f"{number:064x}",
        "phash": f"{number:016x}",
        "is_derivative": "0",
        "is_field": "1",
        "source_locked_split": "",
    }


def _write_manifest(
    path: Path,
    rows: list[dict[str, str]],
    *,
    fieldnames: list[str] | tuple[str, ...] = MANIFEST_COLUMNS,
) -> None:
    with path.open("w", encoding="utf-8", newline="") as output_file:
        writer = csv.DictWriter(
            output_file,
            fieldnames=fieldnames,
            lineterminator="\n",
            extrasaction="ignore",
        )
        writer.writeheader()
        writer.writerows(rows)


def _read_manifest(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as input_file:
        return list(csv.DictReader(input_file))


def test_quarantines_whole_conflicting_group_with_deterministic_evidence(
    tmp_path: Path,
) -> None:
    manifest = tmp_path / "manifest.csv"
    output = tmp_path / "manifest_sanitized.csv"
    quarantine = tmp_path / "manifest_sanitized.quarantine.json"
    rows = [
        _row(
            1,
            group_id="keep-single",
            crop="potato",
            condition="potato_late_blight",
        ),
        _row(
            2,
            group_id="quarantine-me",
            crop="potato",
            condition="potato_healthy",
        ),
        _row(
            3,
            group_id="quarantine-me",
            crop="potato",
            condition="potato_early_blight",
            split="validation",
        ),
        _row(
            4,
            group_id="quarantine-me",
            crop="potato",
            condition="potato_other_unknown",
        ),
        _row(
            5,
            group_id="quarantine-known-plus-unknown",
            crop="potato",
            condition="potato_early_blight",
        ),
        _row(
            6,
            group_id="quarantine-known-plus-unknown",
            crop="potato",
            condition="potato_other_unknown",
        ),
        _row(
            7,
            group_id="quarantine-different-crops",
            crop="potato",
            condition="potato_healthy",
        ),
        _row(
            8,
            group_id="quarantine-different-crops",
            crop="maize",
            condition="maize_healthy",
        ),
        _row(
            9,
            group_id="quarantine-not-applicable",
            crop="potato",
            condition="potato_healthy",
        ),
        _row(
            10,
            group_id="quarantine-not-applicable",
            crop="potato",
            condition="not_applicable",
            validity="unsuitable_target_crop_view",
        ),
    ]
    _write_manifest(manifest, rows)
    original_bytes = manifest.read_bytes()

    sidecar = sanitize_manifest(manifest, output, TAXONOMY, quarantine)

    assert manifest.read_bytes() == original_bytes
    assert [row["image_path"] for row in _read_manifest(output)] == [
        rows[0]["image_path"]
    ]
    assert sidecar["summary"] == {
        "input_rows": 10,
        "input_groups": 5,
        "quarantined_rows": 9,
        "quarantined_groups": 4,
        "retained_rows": 1,
        "retained_groups": 1,
    }
    assert sidecar["policy"]["waivers_allowed"] is False
    assert (
        sidecar["sanitized_manifest"]["sha256"]
        == hashlib.sha256(output.read_bytes()).hexdigest()
    )
    assert json.loads(quarantine.read_text(encoding="utf-8")) == sidecar

    evidence = sidecar["quarantined_groups"]
    assert [group["group_id"] for group in evidence] == [
        "quarantine-different-crops",
        "quarantine-known-plus-unknown",
        "quarantine-me",
        "quarantine-not-applicable",
    ]
    conflicting = next(
        group for group in evidence if group["group_id"] == "quarantine-me"
    )
    assert conflicting["reason_code"] == REASON_CODE
    assert conflicting["condition_labels"] == [
        "potato_early_blight",
        "potato_healthy",
        "potato_other_unknown",
    ]
    assert conflicting["row_count"] == 3
    assert [row["input_row_number"] for row in conflicting["rows"]] == [3, 4, 5]
    assert [row["image_path"] for row in conflicting["rows"]] == [
        rows[index]["image_path"] for index in (1, 2, 3)
    ]
    assert [row["sha256"] for row in conflicting["rows"]] == [
        rows[index]["sha256"] for index in (1, 2, 3)
    ]
    assert conflicting["rows"][2]["manifest_row"] == rows[3]
    cross_crop = next(
        group for group in evidence if group["group_id"] == "quarantine-different-crops"
    )
    assert cross_crop["condition_labels"] == ["maize_healthy", "potato_healthy"]
    not_applicable = next(
        group for group in evidence if group["group_id"] == "quarantine-not-applicable"
    )
    assert not_applicable["condition_labels"] == [
        "not_applicable",
        "potato_healthy",
    ]

    first_output = output.read_bytes()
    first_quarantine = quarantine.read_bytes()
    assert sanitize_manifest(manifest, output, TAXONOMY, quarantine) == sidecar
    assert output.read_bytes() == first_output
    assert quarantine.read_bytes() == first_quarantine
    assert not list(tmp_path.glob(".*.tmp"))


def test_invalid_manifest_fails_before_replacing_existing_outputs(
    tmp_path: Path,
) -> None:
    manifest = tmp_path / "invalid.csv"
    output = tmp_path / "output.csv"
    quarantine = tmp_path / "quarantine.json"
    rows = [
        _row(
            1,
            group_id="keep",
            crop="potato",
            condition="potato_healthy",
        )
    ]
    missing_phash = [column for column in MANIFEST_COLUMNS if column != "phash"]
    _write_manifest(manifest, rows, fieldnames=missing_phash)
    output.write_bytes(b"previous output")
    quarantine.write_bytes(b"previous quarantine")

    with pytest.raises(ManifestSanitizationError, match="missing required columns"):
        sanitize_manifest(manifest, output, TAXONOMY, quarantine)

    assert output.read_bytes() == b"previous output"
    assert quarantine.read_bytes() == b"previous quarantine"
    assert not list(tmp_path.glob(".*.tmp"))


def test_canonical_condition_assigned_to_wrong_crop_fails_closed(
    tmp_path: Path,
) -> None:
    manifest = tmp_path / "manifest.csv"
    output = tmp_path / "output.csv"
    quarantine = tmp_path / "quarantine.json"
    _write_manifest(
        manifest,
        [
            _row(
                1,
                group_id="bad-label",
                crop="potato",
                condition="maize_healthy",
            )
        ],
    )

    with pytest.raises(ManifestSanitizationError, match="belongs to crop 'maize'"):
        sanitize_manifest(manifest, output, TAXONOMY, quarantine)

    assert not output.exists()
    assert not quarantine.exists()


def test_refuses_to_overwrite_input_or_emit_an_empty_manifest(tmp_path: Path) -> None:
    manifest = tmp_path / "manifest.csv"
    output = tmp_path / "output.csv"
    quarantine = tmp_path / "quarantine.json"
    _write_manifest(
        manifest,
        [
            _row(
                1,
                group_id="only-group",
                crop="potato",
                condition="potato_early_blight",
            ),
            _row(
                2,
                group_id="only-group",
                crop="potato",
                condition="potato_healthy",
            ),
        ],
    )
    original_bytes = manifest.read_bytes()

    with pytest.raises(ManifestSanitizationError, match="must not overwrite"):
        sanitize_manifest(manifest, manifest, TAXONOMY, quarantine)
    with pytest.raises(ManifestSanitizationError, match="quarantine every"):
        sanitize_manifest(manifest, output, TAXONOMY, quarantine)

    assert manifest.read_bytes() == original_bytes
    assert not output.exists()
    assert not quarantine.exists()
