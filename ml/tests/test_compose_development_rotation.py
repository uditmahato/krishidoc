from __future__ import annotations

import csv
import hashlib
import json
import os
from pathlib import Path

import pytest

from ml.scripts import compose_development_rotation as module
from ml.scripts.compose_development_rotation import DevelopmentRotationError
from ml.scripts.audit_manifest import audit_manifest
from ml.src.krishidoc_ml.evidence import resolve_source_evidence

FIELDS = ("image_path", "crop", "condition_label", "validity_label", "split", "source_id", "group_id", "sha256", "phash", "is_derivative", "is_field", "source_locked_split")
SIDE = ("fold_schema_version", "source_id", "image_path", "sha256", "group_id", "manifest_split", "development_fold", "fold_index", "evidence_role", "development_only", "promotion_eligible", "selection_independent", "metadata_status", "metadata_flags", "group_metadata_flags")


def _row(number: int, *, group: str | None = None, source: str = "farmer_chat_india") -> dict[str, str]:
    return {"image_path": f"raw/{source}/{number}.jpg", "crop": "potato", "condition_label": "potato_healthy", "validity_label": "usable_target_leaf", "split": "external_test" if source == "farmer_chat_india" else "validation", "source_id": source, "group_id": group or f"g{number}", "sha256": f"{number:064x}", "phash": f"{number * 0x1111111111111111:016x}", "is_derivative": "0", "is_field": "1", "source_locked_split": "external_test" if source == "farmer_chat_india" else ""}


def _side(row: dict[str, str], fold: int, status: str = "ok", flags: str = "") -> dict[str, str]:
    return {"fold_schema_version": "1", "source_id": "farmer_chat_india", "image_path": row["image_path"], "sha256": row["sha256"], "group_id": row["group_id"], "manifest_split": "external_test", "development_fold": "quarantine" if status == "quarantined" else f"dev_fold_{fold}", "fold_index": "" if status == "quarantined" else str(fold), "evidence_role": "external_development", "development_only": "true", "promotion_eligible": "false", "selection_independent": "false", "metadata_status": status, "metadata_flags": flags, "group_metadata_flags": ""}


def _csv(path: Path, fields: tuple[str, ...], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields, lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)


def _sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _fixture(tmp: Path, rows: list[dict[str, str]] | None = None, sides: list[dict[str, str]] | None = None):
    manifest, sidecar, report, policy = tmp / "base.csv", tmp / "folds.csv", tmp / "folds.json", tmp / "policy.json"
    rows = rows or [_row(i) for i in range(1, 6)]
    sides = sides or [_side(row, i) for i, row in enumerate([r for r in rows if r["source_id"] == "farmer_chat_india"], 1)]
    _csv(manifest, FIELDS, rows); _csv(sidecar, SIDE, sides)
    policy.write_text(json.dumps({"schema_version": 1, "sources": {"farmer_chat_india": {"evidence_role": "external_development", "promotion_eligible": False, "selection_independent": False}}}), encoding="utf-8")
    report.write_text(json.dumps({"schema_version": 1, "status": "development_only", "evidence_role": "external_development", "promotion_eligible": False, "selection_independent": False, "fold_count": 5, "inputs": {"canonical_manifest_sha256": _sha(manifest), "source_policy_sha256": _sha(policy)}, "output": {"sidecar_sha256": _sha(sidecar)}}), encoding="utf-8")
    return manifest, sidecar, report, policy, tmp / "out.csv", tmp / "receipt.json"


def _compose(paths, rotation=1, **kwargs):
    return module.compose_development_rotation(*paths, rotation=rotation, **kwargs)


@pytest.mark.parametrize("rotation", range(1, 6))
def test_all_rotations_are_diagnostic_and_have_blank_rotated_locks(tmp_path: Path, rotation: int) -> None:
    paths = _fixture(tmp_path)
    result = _compose(paths, rotation)
    with paths[4].open(encoding="utf-8", newline="") as stream:
        rows = list(csv.DictReader(stream))
    assert all(row["source_locked_split"] == "" for row in rows)
    assert {row["split"] for row in rows} == {"train", "calibration", "external_test"}
    assert result["selection_independent"] is False
    assert result["human_evidence_label"].startswith("diagnostic external-development")


def test_excludes_flagged_group_by_fold_and_class_and_quarantine_piggyback(tmp_path: Path) -> None:
    rows = [_row(i) for i in range(1, 8)]
    rows[5]["group_id"] = "g1"
    sides = [_side(row, 1 if row["group_id"] in {"g1", "g7"} else int(row["group_id"][1:])) for row in rows]
    sides[0]["metadata_status"] = "quarantined"; sides[0]["development_fold"] = "quarantine"; sides[0]["fold_index"] = ""
    paths = _fixture(tmp_path, rows, sides)
    result = _compose(paths, include_flagged=True)
    assert result["counts"]["excluded_groups"] == 1
    assert not any("g1" == row["group_id"] for row in csv.DictReader(paths[4].open(encoding="utf-8")))
    assert result["excluded_group_set_sha256"]


@pytest.mark.parametrize("field,value", [("fold_schema_version", "2"), ("development_only", "True"), ("promotion_eligible", "0"), ("selection_independent", "False")])
def test_rejects_schema_and_noncanonical_booleans(tmp_path: Path, field: str, value: str) -> None:
    rows = [_row(i) for i in range(1, 6)]; sides = [_side(row, i) for i, row in enumerate(rows, 1)]
    sides[0][field] = value
    with pytest.raises(DevelopmentRotationError): _compose(_fixture(tmp_path, rows, sides))


def test_rejects_malformed_row_and_empty_admitted_fold(tmp_path: Path) -> None:
    rows = [_row(i) for i in range(1, 6)]; sides = [_side(row, i) for i, row in enumerate(rows, 1)]
    sides[0]["image_path"] = ""
    with pytest.raises(DevelopmentRotationError, match="blank required"): _compose(_fixture(tmp_path, rows, sides))
    tmp2 = tmp_path / "second"; tmp2.mkdir(); sides = [_side(row, i) for i, row in enumerate(rows, 1)]; sides[0]["metadata_status"] = "flagged"; sides[0]["metadata_flags"] = "multiple_reviews"
    with pytest.raises(DevelopmentRotationError, match="all five admitted"): _compose(_fixture(tmp2, rows, sides))


def test_rejects_phash_cross_split(tmp_path: Path) -> None:
    rows = [_row(i) for i in range(1, 6)]
    rows[1]["phash"] = rows[0]["phash"]
    with pytest.raises(DevelopmentRotationError, match="pHash pair"): _compose(_fixture(tmp_path, rows), rotation=1)


def test_rejects_path_collisions_existing_output_and_bad_report_hash(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    with pytest.raises(DevelopmentRotationError, match="distinct"): module.compose_development_rotation(paths[0], paths[1], paths[2], paths[3], paths[0], paths[5], rotation=1)
    paths[4].write_text("occupied", encoding="utf-8")
    with pytest.raises(DevelopmentRotationError, match="exists"): _compose(paths)
    paths[4].unlink(); report = json.loads(paths[2].read_text()); report["inputs"]["canonical_manifest_sha256"] = "0" * 64; paths[2].write_text(json.dumps(report))
    with pytest.raises(DevelopmentRotationError, match="manifest hash"): _compose(paths)


def test_failed_receipt_replace_leaves_manifest_without_attestation(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    paths = _fixture(tmp_path)
    real_replace, calls = os.replace, 0
    def fail_second(source, destination):
        nonlocal calls
        calls += 1
        if calls == 2: raise OSError("simulated receipt commit failure")
        return real_replace(source, destination)
    monkeypatch.setattr(module.os, "replace", fail_second)
    with pytest.raises(OSError, match="simulated"): _compose(paths)
    assert paths[4].exists()
    assert not paths[5].exists()
    assert not list(tmp_path.glob(".*.tmp"))


def test_fold_report_and_policy_hashes_are_strict(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    paths[3].write_text(paths[3].read_text() + " ", encoding="utf-8")
    with pytest.raises(DevelopmentRotationError, match="policy hash"): _compose(paths)


def test_fold_report_requires_canonical_boolean_and_rotated_policy_is_consumed(tmp_path: Path) -> None:
    paths = _fixture(tmp_path)
    report = json.loads(paths[2].read_text(encoding="utf-8"))
    report["selection_independent"] = "false"
    paths[2].write_text(json.dumps(report), encoding="utf-8")
    with pytest.raises(DevelopmentRotationError, match="canonical JSON boolean"):
        _compose(paths)
    policy = Path(__file__).parents[1] / "datasets" / "source_evidence_policy_v2.json"
    evidence = resolve_source_evidence(
        ["farmer_chat_india_development_v1"], policy_path=policy
    )
    assert evidence["selection_independent"] is False
    assert evidence["promotion_eligible"] is False


def test_output_is_auditor_compatible_and_evidence_is_not_independent(tmp_path: Path) -> None:
    rows = [_row(i) for i in range(1, 6)]
    validation = _row(6, source="pldd-up")
    test = _row(7, source="other-source")
    test["split"] = "test"
    paths = _fixture(tmp_path, [validation, test, *rows])
    result = _compose(paths)
    for row in [validation, test, *rows]:
        image = tmp_path / row["image_path"]
        image.parent.mkdir(parents=True, exist_ok=True)
        image.write_bytes(b"fixture")
    taxonomy = tmp_path / "taxonomy.json"
    taxonomy.write_text(json.dumps({"crops": {"potato": {"known": ["potato_healthy"], "unknown": "potato_other_unknown"}}}), encoding="utf-8")
    summary = audit_manifest(paths[4], taxonomy, verify_images=False, image_root=tmp_path)
    assert summary["rows"] == 7
    assert result["selection_independent"] is False
    assert result["promotion_eligible"] is False
