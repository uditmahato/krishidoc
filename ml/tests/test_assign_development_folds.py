from __future__ import annotations

import csv
import json
from pathlib import Path

import pytest

from ml.scripts.assign_development_folds import (
    DevelopmentFoldError,
    build_development_folds,
)


MANIFEST_FIELDS = (
    "image_path",
    "crop",
    "condition_label",
    "validity_label",
    "split",
    "source_id",
    "group_id",
    "sha256",
    "phash",
    "is_derivative",
    "is_field",
    "source_locked_split",
)
ANNOTATION_FIELDS = ("image_file", "crop", "diagnosis", "details", "country", "state")


def _manifest_row(
    number: int,
    *,
    group: str | None = None,
    sha: str | None = None,
    image: str | None = None,
    crop: str = "unknown",
    condition: str = "not_applicable",
    validity: str = "other_plant",
) -> dict[str, str]:
    return {
        "image_path": f"ml/data/raw/farmer_chat_india/{image or f'images/{number:05d}.jpg'}",
        "crop": crop,
        "condition_label": condition,
        "validity_label": validity,
        "split": "external_test",
        "source_id": "farmer_chat_india",
        "group_id": group or f"group-{number}",
        "sha256": sha or f"{number:064x}",
        "phash": f"{number:016x}",
        "is_derivative": "0",
        "is_field": "1",
        "source_locked_split": "external_test",
    }


def _annotation(
    number: int,
    *,
    crop: str = "Chilli",
    diagnosis: str = "Healthy",
    state: str = "Bihar",
    image: str | None = None,
) -> dict[str, str]:
    return {
        "image_file": image or f"images/{number:05d}.jpg",
        "crop": crop,
        "diagnosis": diagnosis,
        "details": "raw expert note",
        "country": "India",
        "state": state,
    }


def _write_csv(path: Path, fields: tuple[str, ...], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def _write_policy(path: Path, *, eligible: bool = False) -> None:
    path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "policy_id": "fixture-policy",
                "aliases": {},
                "sources": {
                    "farmer_chat_india": {
                        "evidence_role": "external_development",
                        "selection_independent": False,
                        "promotion_eligible": eligible,
                    }
                },
            }
        ),
        encoding="utf-8",
    )


def _read_csv(path: Path) -> list[dict[str, str]]:
    with path.open("r", encoding="utf-8", newline="") as stream:
        return list(csv.DictReader(stream))


def test_is_deterministic_group_locked_and_explicitly_development_only(
    tmp_path: Path,
) -> None:
    manifest = tmp_path / "manifest.csv"
    annotations = tmp_path / "annotations.csv"
    policy = tmp_path / "policy.json"
    manifest_rows = [_manifest_row(number) for number in range(1, 11)]
    # The two image rows must travel together even though their strata differ.
    manifest_rows[1]["group_id"] = manifest_rows[0]["group_id"]
    annotation_rows = [
        _annotation(
            number,
            crop="Potato" if number % 2 else "Maize",
            diagnosis="Late Blight" if number % 3 else "Healthy",
            state="Bihar" if number < 7 else "Odisha",
        )
        for number in range(1, 11)
    ]
    _write_csv(manifest, MANIFEST_FIELDS, manifest_rows)
    _write_csv(annotations, ANNOTATION_FIELDS, annotation_rows)
    _write_policy(policy)

    outputs = []
    reports = []
    for suffix in ("a", "b"):
        output = tmp_path / f"folds-{suffix}.csv"
        report = tmp_path / f"folds-{suffix}.json"
        build_development_folds(
            manifest,
            annotations,
            policy,
            output,
            report,
            folds=5,
            seed=41,
        )
        outputs.append(output)
        reports.append(report)

    assert outputs[0].read_bytes() == outputs[1].read_bytes()
    assert reports[0].read_bytes() == reports[1].read_bytes()
    rows = _read_csv(outputs[0])
    grouped = {}
    for row in rows:
        grouped.setdefault(row["group_id"], set()).add(row["development_fold"])
        assert row["development_only"] == "true"
        assert row["promotion_eligible"] == "false"
        assert row["selection_independent"] == "false"
        assert row["evidence_role"] == "external_development"
    assert all(len(folds) == 1 for folds in grouped.values())
    payload = json.loads(reports[0].read_text(encoding="utf-8"))
    assert payload["promotion_eligible"] is False
    assert payload["output"]["sidecar_sha256"]
    assert payload["leakage_checks"]["group_id_assigned_to_one_fold"] is True


def test_preserves_review_values_flags_conflicts_and_quarantines_missing_group(
    tmp_path: Path,
) -> None:
    manifest = tmp_path / "manifest.csv"
    annotations = tmp_path / "annotations.csv"
    policy = tmp_path / "policy.json"
    output = tmp_path / "folds.csv"
    report_path = tmp_path / "folds.json"
    rows = [_manifest_row(number) for number in range(1, 8)]
    # One joined row plus one missing row: the complete leakage group is quarantined.
    rows[6]["group_id"] = rows[5]["group_id"]
    reviews = [_annotation(number) for number in range(1, 7)]
    reviews.extend(
        [
            _annotation(1, crop="Tomato", diagnosis="Early Blight; Mites"),
            _annotation(99, image="images/orphan.jpg", crop="Rice", diagnosis="Blast"),
        ]
    )
    _write_csv(manifest, MANIFEST_FIELDS, rows)
    _write_csv(annotations, ANNOTATION_FIELDS, reviews)
    _write_policy(policy)

    report = build_development_folds(
        manifest,
        annotations,
        policy,
        output,
        report_path,
        folds=2,
        seed=9,
    )
    sidecar = {row["image_path"]: row for row in _read_csv(output)}
    disagreed = sidecar["ml/data/raw/farmer_chat_india/images/00001.jpg"]
    assert json.loads(disagreed["raw_crops_json"]) == ["Chilli", "Tomato"]
    assert json.loads(disagreed["raw_diagnoses_json"]) == [
        "Early Blight; Mites",
        "Healthy",
    ]
    assert disagreed["raw_review_count"] == "2"
    assert disagreed["metadata_status"] == "flagged"
    assert "conflicting_crop_reviews" in disagreed["metadata_flags"]
    assert "conflicting_diagnosis_reviews" in disagreed["metadata_flags"]

    quarantined = [row for row in sidecar.values() if row["group_id"] == "group-6"]
    assert len(quarantined) == 2
    assert {row["development_fold"] for row in quarantined} == {"quarantine"}
    assert {row["metadata_status"] for row in quarantined} == {"quarantined"}
    assert report["summary"]["quarantined_rows"] == 2
    assert report["summary"]["orphaned_annotation_images"] == 1
    assert report["orphaned_annotations"][0]["image_file"] == "images/orphan.jpg"


def test_rejects_cross_group_sha_leakage(tmp_path: Path) -> None:
    manifest = tmp_path / "manifest.csv"
    annotations = tmp_path / "annotations.csv"
    policy = tmp_path / "policy.json"
    output = tmp_path / "folds.csv"
    report = tmp_path / "folds.json"
    shared_sha = "a" * 64
    _write_csv(
        manifest,
        MANIFEST_FIELDS,
        [
            _manifest_row(1, sha=shared_sha, group="one"),
            _manifest_row(2, sha=shared_sha, group="two"),
        ],
    )
    _write_csv(annotations, ANNOTATION_FIELDS, [_annotation(1), _annotation(2)])
    _write_policy(policy)
    with pytest.raises(DevelopmentFoldError, match="spans group_ids"):
        build_development_folds(manifest, annotations, policy, output, report, folds=2)
    assert not output.exists()
    assert not report.exists()


def test_rejects_cross_source_sha_and_promotion_eligible_policy(
    tmp_path: Path,
) -> None:
    manifest = tmp_path / "manifest.csv"
    annotations = tmp_path / "annotations.csv"
    policy = tmp_path / "policy.json"
    output = tmp_path / "folds.csv"
    report = tmp_path / "folds.json"
    shared_sha = "b" * 64
    source_rows = [
        _manifest_row(1, sha=shared_sha),
        _manifest_row(2),
    ]
    other_source = _manifest_row(3, sha=shared_sha)
    other_source["source_id"] = "training_source"
    other_source["split"] = "train"
    other_source["source_locked_split"] = ""
    _write_csv(manifest, MANIFEST_FIELDS, [*source_rows, other_source])
    _write_csv(annotations, ANNOTATION_FIELDS, [_annotation(1), _annotation(2)])
    _write_policy(policy)

    with pytest.raises(DevelopmentFoldError, match="also occurs in sources"):
        build_development_folds(manifest, annotations, policy, output, report, folds=2)

    assert not output.exists()
    assert not report.exists()

    _write_csv(
        manifest,
        MANIFEST_FIELDS,
        [_manifest_row(1), _manifest_row(2)],
    )
    _write_policy(policy, eligible=True)
    with pytest.raises(DevelopmentFoldError, match="promotion_eligible"):
        build_development_folds(manifest, annotations, policy, output, report, folds=2)
    assert not output.exists()
    assert not report.exists()
