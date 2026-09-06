from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any

import pytest

from krishidoc_ml.data_snapshot import (
    DataSnapshotValidationError,
    verify_training_data_snapshot,
)
from krishidoc_ml.pipeline import train_experiment
from krishidoc_ml.receipt import file_sha256


def _write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )


def _complete_snapshot(tmp_path: Path) -> tuple[dict[str, Any], Path, dict[str, Path]]:
    manifest = tmp_path / "manifest.csv"
    manifest.write_text("image_path,crop\nleaf.jpg,potato\n", encoding="utf-8")
    quarantine = tmp_path / "quarantine.json"
    _write_json(quarantine, {"quarantined": []})

    artifacts: dict[str, Path] = {}
    for name in ("aliases", "source_evidence_policy", "fold_report", "rotation_receipt"):
        path = tmp_path / f"{name}.json"
        _write_json(path, {"artifact": name})
        artifacts[name] = path

    receipt_path = tmp_path / "audit_receipt.json"
    config_path = tmp_path / "training.json"
    stored_config: dict[str, Any] = {
        "schema_version": 1,
        "manifest": manifest.name,
        "data_snapshot": {
            "audit_required_before_training": True,
            "audit_receipt_must_match_config": True,
            "manifest_sha256": file_sha256(manifest),
            "audit_receipt": receipt_path.name,
            "quarantine_sidecar": quarantine.name,
            "quarantine_sha256": file_sha256(quarantine),
            "required_artifacts": {
                name: {"path": path.name, "sha256": file_sha256(path)}
                for name, path in artifacts.items()
            },
        },
    }
    _write_json(config_path, stored_config)
    _write_json(
        receipt_path,
        {
            "schema_version": 1,
            "status": "passed",
            "manifest": {"sha256": file_sha256(manifest)},
            "config": {"sha256": file_sha256(config_path)},
        },
    )
    config = json.loads(config_path.read_text(encoding="utf-8"))
    config["_config_path"] = str(config_path)
    artifacts["quarantine"] = quarantine
    artifacts["audit_receipt"] = receipt_path
    artifacts["config"] = config_path
    return config, manifest, artifacts


def _enable_dependency_binding(
    config: dict[str, Any], artifacts: dict[str, Path]
) -> None:
    taxonomy = artifacts["config"].parent / "taxonomy.json"
    _write_json(taxonomy, {"schema_version": 1, "crops": {}})
    artifacts["taxonomy"] = taxonomy
    snapshot = config["data_snapshot"]
    snapshot["audit_receipt_must_match_dependencies"] = True
    snapshot["required_artifacts"]["taxonomy"] = {
        "path": taxonomy.name,
        "sha256": file_sha256(taxonomy),
    }
    config["split_policy"] = {"near_duplicate_hamming_distance": 4}
    receipt_path = artifacts["audit_receipt"]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt["taxonomy"] = {"sha256": file_sha256(taxonomy)}
    receipt["aliases"] = {"sha256": file_sha256(artifacts["aliases"])}
    receipt["near_duplicate_hamming_distance"] = 4
    _write_json(receipt_path, receipt)


def test_complete_snapshot_authenticates_manifest_receipt_config_and_artifacts(
    tmp_path: Path,
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)

    verified = verify_training_data_snapshot(
        config=config,
        manifest_path=manifest,
        repo_root=tmp_path,
    )

    assert verified is not None
    assert verified["manifest"]["sha256"] == file_sha256(manifest)
    assert verified["config"]["sha256"] == file_sha256(artifacts["config"])
    assert set(verified["required_artifacts"]) == {
        "aliases",
        "source_evidence_policy",
        "fold_report",
        "rotation_receipt",
        "quarantine",
    }


def test_snapshot_guard_is_backward_compatible_and_opt_in(tmp_path: Path) -> None:
    manifest = tmp_path / "manifest.csv"
    manifest.write_bytes(b"manifest")
    config = {
        "data_snapshot": {
            "manifest_sha256": "not-a-digest",
            "audit_receipt": "missing.json",
        }
    }

    assert (
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )
        is None
    )


@pytest.mark.parametrize(
    ("mutation", "error"),
    [
        ("expected_manifest", "Training manifest SHA-256"),
        ("receipt_status", "status must be 'passed'"),
        ("receipt_manifest", "different training manifest"),
        ("receipt_config", "different training config"),
    ],
)
def test_snapshot_guard_rejects_stale_core_identities(
    tmp_path: Path, mutation: str, error: str
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    if mutation == "expected_manifest":
        config["data_snapshot"]["manifest_sha256"] = "0" * 64
    else:
        receipt_path = artifacts["audit_receipt"]
        receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
        if mutation == "receipt_status":
            receipt["status"] = "failed"
        elif mutation == "receipt_manifest":
            receipt["manifest"]["sha256"] = "0" * 64
        else:
            receipt["config"]["sha256"] = "0" * 64
        _write_json(receipt_path, receipt)

    with pytest.raises(DataSnapshotValidationError, match=error):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


def test_snapshot_guard_rejects_wrong_receipt_schema(tmp_path: Path) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    receipt_path = artifacts["audit_receipt"]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt["schema_version"] = 2
    _write_json(receipt_path, receipt)

    with pytest.raises(DataSnapshotValidationError, match="schema_version"):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


def test_strict_dependency_binding_authenticates_audit_inputs(
    tmp_path: Path,
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    _enable_dependency_binding(config, artifacts)

    verified = verify_training_data_snapshot(
        config=config,
        manifest_path=manifest,
        repo_root=tmp_path,
    )

    assert verified is not None
    assert verified["required_artifacts"]["taxonomy"]["sha256"] == file_sha256(
        artifacts["taxonomy"]
    )


@pytest.mark.parametrize("name", ["taxonomy", "aliases"])
def test_strict_dependency_binding_requires_exact_artifact_names(
    tmp_path: Path, name: str
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    _enable_dependency_binding(config, artifacts)
    declaration = config["data_snapshot"]["required_artifacts"].pop(name)
    config["data_snapshot"]["required_artifacts"][f"renamed_{name}"] = declaration

    with pytest.raises(
        DataSnapshotValidationError,
        match=rf"exactly named required_artifacts\.{name}",
    ):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


@pytest.mark.parametrize("name", ["taxonomy", "aliases"])
def test_strict_dependency_binding_rejects_receipt_hash_mismatch(
    tmp_path: Path, name: str
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    _enable_dependency_binding(config, artifacts)
    receipt_path = artifacts["audit_receipt"]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt[name]["sha256"] = "0" * 64
    _write_json(receipt_path, receipt)

    with pytest.raises(DataSnapshotValidationError, match=rf"receipt {name} SHA-256"):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


@pytest.mark.parametrize("receipt_distance", [None, 3])
def test_strict_dependency_binding_rejects_missing_or_wrong_distance(
    tmp_path: Path, receipt_distance: int | None
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    _enable_dependency_binding(config, artifacts)
    receipt_path = artifacts["audit_receipt"]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if receipt_distance is None:
        del receipt["near_duplicate_hamming_distance"]
    else:
        receipt["near_duplicate_hamming_distance"] = receipt_distance
    _write_json(receipt_path, receipt)

    with pytest.raises(
        DataSnapshotValidationError, match="near_duplicate_hamming_distance"
    ):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


def test_strict_dependency_binding_rejects_ambiguous_duplicate_names(
    tmp_path: Path,
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    _enable_dependency_binding(config, artifacts)
    aliases = config["data_snapshot"]["required_artifacts"]["aliases"]
    taxonomy = config["data_snapshot"]["required_artifacts"]["taxonomy"]
    config["data_snapshot"]["required_artifacts"] = [
        {"name": "aliases", **aliases},
        {"name": "aliases", **aliases},
        {"name": "taxonomy", **taxonomy},
    ]

    with pytest.raises(DataSnapshotValidationError, match="Duplicate.*aliases"):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


@pytest.mark.parametrize("artifact_name", ["quarantine", "aliases", "fold_report"])
def test_snapshot_guard_rejects_changed_required_artifacts(
    tmp_path: Path, artifact_name: str
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    artifacts[artifact_name].write_bytes(b"changed after snapshot")

    with pytest.raises(DataSnapshotValidationError, match="SHA-256 mismatch"):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


def test_snapshot_guard_accepts_named_list_artifacts(tmp_path: Path) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    policy = artifacts["source_evidence_policy"]
    config["data_snapshot"]["required_artifacts"] = [
        {"name": "source_evidence_policy", "path": policy.name, "sha256": file_sha256(policy)}
    ]

    verified = verify_training_data_snapshot(
        config=config,
        manifest_path=manifest,
        repo_root=tmp_path,
    )

    assert verified is not None
    assert set(verified["required_artifacts"]) == {
        "quarantine",
        "source_evidence_policy",
    }


def test_snapshot_guard_requires_quarantine_path_and_hash_as_a_pair(
    tmp_path: Path,
) -> None:
    config, manifest, _ = _complete_snapshot(tmp_path)
    del config["data_snapshot"]["quarantine_sha256"]

    with pytest.raises(DataSnapshotValidationError, match="declared together"):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


@pytest.mark.parametrize("recorded", [None, False])
def test_strict_snapshot_requires_explicit_full_image_verification(
    tmp_path: Path, recorded: bool | None
) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    config["data_snapshot"]["audit_receipt_must_verify_images"] = True
    receipt_path = artifacts["audit_receipt"]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    if recorded is not None:
        receipt["image_verification"] = recorded
    _write_json(receipt_path, receipt)

    with pytest.raises(DataSnapshotValidationError, match="image_verification=true"):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )


def test_strict_snapshot_accepts_full_image_verification(tmp_path: Path) -> None:
    config, manifest, artifacts = _complete_snapshot(tmp_path)
    config["data_snapshot"]["audit_receipt_must_verify_images"] = True
    receipt_path = artifacts["audit_receipt"]
    receipt = json.loads(receipt_path.read_text(encoding="utf-8"))
    receipt["image_verification"] = True
    _write_json(receipt_path, receipt)

    verified = verify_training_data_snapshot(
        config=config,
        manifest_path=manifest,
        repo_root=tmp_path,
    )

    assert verified is not None
    assert verified["audit_receipt"]["image_verification"] is True


def test_training_snapshot_failure_precedes_output_directory_creation(
    tmp_path: Path,
) -> None:
    manifest = tmp_path / "manifest.csv"
    manifest.write_text("invalid manifest is never parsed\n", encoding="utf-8")
    output = tmp_path / "run"
    repo_root = Path(__file__).resolve().parents[2]
    config = {
        "schema_version": 1,
        "_config_path": str(repo_root / "ml" / "configs" / "smoke.json"),
        "manifest": str(manifest),
        "data_snapshot": {
            "audit_required_before_training": True,
            "manifest_sha256": hashlib.sha256(b"different").hexdigest(),
            "audit_receipt": str(tmp_path / "missing_receipt.json"),
        },
    }

    with pytest.raises(DataSnapshotValidationError, match="Training manifest SHA-256"):
        train_experiment(
            config=config,
            crop="maize",
            architecture="mobilenet_v3_large",
            condition_labels=["rust", "healthy"],
            output_dir=output,
            device_name="cpu",
        )

    assert not output.exists()


@pytest.mark.parametrize(
    "field",
    [
        "audit_required_before_training",
        "audit_receipt_must_match_config",
        "audit_receipt_must_verify_images",
        "audit_receipt_must_match_dependencies",
    ],
)
def test_snapshot_boolean_controls_are_strict_json_booleans(
    tmp_path: Path, field: str
) -> None:
    config, manifest, _ = _complete_snapshot(tmp_path)
    config["data_snapshot"][field] = "true"

    with pytest.raises(DataSnapshotValidationError, match=f"data_snapshot.{field}"):
        verify_training_data_snapshot(
            config=config,
            manifest_path=manifest,
            repo_root=tmp_path,
        )
