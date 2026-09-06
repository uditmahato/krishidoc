"""Fail-closed identity checks for audited training-data snapshots."""

from __future__ import annotations

import json
import re
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any

from .receipt import file_sha256


_SHA256_PATTERN = re.compile(r"^[0-9a-fA-F]{64}$")


class DataSnapshotValidationError(ValueError):
    """Raised when an opted-in training snapshot cannot be authenticated."""


def verify_training_data_snapshot(
    *,
    config: Mapping[str, Any],
    manifest_path: str | Path,
    repo_root: str | Path,
    manifest_sha256: str | None = None,
) -> dict[str, Any] | None:
    """Authenticate an audited data snapshot before training creates artifacts.

    The check is deliberately opt-in so historical and smoke-test configs keep
    their existing behaviour. Once ``audit_required_before_training`` is true,
    every declared identity is mandatory and a malformed or stale declaration
    fails closed.
    """

    snapshot = config.get("data_snapshot")
    if not isinstance(snapshot, Mapping):
        return None

    audit_required = snapshot.get("audit_required_before_training", False)
    if audit_required is False:
        return None
    if audit_required is not True:
        raise DataSnapshotValidationError(
            "data_snapshot.audit_required_before_training must be a JSON boolean"
        )

    root = Path(repo_root).resolve()
    manifest = Path(manifest_path).resolve()
    actual_manifest_sha256 = (manifest_sha256 or file_sha256(manifest)).lower()
    expected_manifest_sha256 = _required_sha256(
        snapshot, "manifest_sha256", context="data_snapshot"
    )
    if actual_manifest_sha256 != expected_manifest_sha256:
        raise DataSnapshotValidationError(
            "Training manifest SHA-256 does not match "
            "data_snapshot.manifest_sha256"
        )

    receipt_path = _required_path(
        snapshot, "audit_receipt", root=root, context="data_snapshot"
    )
    receipt = _load_json_object(receipt_path, "audit receipt")
    if type(receipt.get("schema_version")) is not int or receipt["schema_version"] != 1:
        raise DataSnapshotValidationError(
            f"Audit receipt schema_version must be the integer 1: {receipt_path}"
        )
    if receipt.get("status") != "passed":
        raise DataSnapshotValidationError(
            f"Audit receipt status must be 'passed': {receipt_path}"
        )
    must_verify_images = snapshot.get(
        "audit_receipt_must_verify_images", False
    )
    if not isinstance(must_verify_images, bool):
        raise DataSnapshotValidationError(
            "data_snapshot.audit_receipt_must_verify_images must be a JSON boolean"
        )
    if must_verify_images and receipt.get("image_verification") is not True:
        raise DataSnapshotValidationError(
            "Audit receipt must explicitly record image_verification=true"
        )
    must_match_dependencies = snapshot.get(
        "audit_receipt_must_match_dependencies", False
    )
    if not isinstance(must_match_dependencies, bool):
        raise DataSnapshotValidationError(
            "data_snapshot.audit_receipt_must_match_dependencies must be a JSON boolean"
        )
    receipt_manifest = receipt.get("manifest")
    if not isinstance(receipt_manifest, Mapping):
        raise DataSnapshotValidationError(
            f"Audit receipt manifest identity is missing: {receipt_path}"
        )
    receipt_manifest_sha256 = _required_sha256(
        receipt_manifest, "sha256", context="audit receipt manifest"
    )
    if receipt_manifest_sha256 != actual_manifest_sha256:
        raise DataSnapshotValidationError(
            "Audit receipt belongs to a different training manifest"
        )

    must_match_config = snapshot.get("audit_receipt_must_match_config", False)
    if not isinstance(must_match_config, bool):
        raise DataSnapshotValidationError(
            "data_snapshot.audit_receipt_must_match_config must be a JSON boolean"
        )
    config_path: Path | None = None
    config_sha256: str | None = None
    if must_match_config:
        config_path = _required_config_path(config)
        config_sha256 = file_sha256(config_path).lower()
        receipt_config = receipt.get("config")
        if not isinstance(receipt_config, Mapping):
            raise DataSnapshotValidationError(
                f"Audit receipt config identity is missing: {receipt_path}"
            )
        receipt_config_sha256 = _required_sha256(
            receipt_config, "sha256", context="audit receipt config"
        )
        if receipt_config_sha256 != config_sha256:
            raise DataSnapshotValidationError(
                "Audit receipt belongs to a different training config"
            )

    verified_artifacts: dict[str, dict[str, str]] = {}
    _verify_optional_quarantine(snapshot, root, verified_artifacts)
    for name, declaration in _artifact_declarations(snapshot):
        if name in verified_artifacts:
            raise DataSnapshotValidationError(
                f"Duplicate data snapshot artifact name: {name!r}"
            )
        artifact_path = _required_path(
            declaration,
            "path",
            root=root,
            context=f"data_snapshot.required_artifacts[{name!r}]",
        )
        expected_sha256 = _required_sha256(
            declaration,
            "sha256",
            context=f"data_snapshot.required_artifacts[{name!r}]",
        )
        _verify_artifact(name, artifact_path, expected_sha256, verified_artifacts)

    if must_match_dependencies:
        _verify_audit_dependencies(
            receipt=receipt,
            config=config,
            verified_artifacts=verified_artifacts,
        )

    result: dict[str, Any] = {
        "manifest": {
            "path": str(manifest),
            "sha256": actual_manifest_sha256,
        },
        "audit_receipt": {
            "path": str(receipt_path),
            "sha256": file_sha256(receipt_path),
            "status": "passed",
            "image_verification": receipt.get("image_verification"),
        },
        "required_artifacts": verified_artifacts,
    }
    if config_path is not None and config_sha256 is not None:
        result["config"] = {
            "path": str(config_path),
            "sha256": config_sha256,
        }
    return result


def _verify_audit_dependencies(
    *,
    receipt: Mapping[str, Any],
    config: Mapping[str, Any],
    verified_artifacts: Mapping[str, Mapping[str, str]],
) -> None:
    for name in ("taxonomy", "aliases"):
        artifact = verified_artifacts.get(name)
        if artifact is None:
            raise DataSnapshotValidationError(
                "Strict audit dependency binding requires exactly named "
                f"required_artifacts.{name}"
            )
        receipt_dependency = receipt.get(name)
        if not isinstance(receipt_dependency, Mapping):
            raise DataSnapshotValidationError(
                f"Audit receipt {name} identity is missing"
            )
        receipt_sha256 = _required_sha256(
            receipt_dependency, "sha256", context=f"audit receipt {name}"
        )
        if receipt_sha256 != artifact["sha256"]:
            raise DataSnapshotValidationError(
                f"Audit receipt {name} SHA-256 does not match required_artifacts.{name}"
            )

    split_policy = config.get("split_policy")
    if not isinstance(split_policy, Mapping):
        raise DataSnapshotValidationError(
            "Strict audit dependency binding requires config.split_policy"
        )
    configured_distance = split_policy.get("near_duplicate_hamming_distance")
    if type(configured_distance) is not int or configured_distance < 0:
        raise DataSnapshotValidationError(
            "config.split_policy.near_duplicate_hamming_distance must be a "
            "non-negative integer"
        )
    receipt_distance = receipt.get("near_duplicate_hamming_distance")
    if type(receipt_distance) is not int:
        raise DataSnapshotValidationError(
            "Audit receipt near_duplicate_hamming_distance must be an integer"
        )
    if receipt_distance != configured_distance:
        raise DataSnapshotValidationError(
            "Audit receipt near_duplicate_hamming_distance does not match "
            "config.split_policy"
        )


def _verify_optional_quarantine(
    snapshot: Mapping[str, Any],
    root: Path,
    verified: dict[str, dict[str, str]],
) -> None:
    has_path = "quarantine_sidecar" in snapshot
    has_sha256 = "quarantine_sha256" in snapshot
    if has_path != has_sha256:
        raise DataSnapshotValidationError(
            "data_snapshot.quarantine_sidecar and quarantine_sha256 must be "
            "declared together"
        )
    if not has_path:
        return
    path = _required_path(
        snapshot,
        "quarantine_sidecar",
        root=root,
        context="data_snapshot",
    )
    expected = _required_sha256(
        snapshot, "quarantine_sha256", context="data_snapshot"
    )
    _verify_artifact("quarantine", path, expected, verified)


def _artifact_declarations(
    snapshot: Mapping[str, Any],
) -> list[tuple[str, Mapping[str, Any]]]:
    value = snapshot.get("required_artifacts", {})
    if value is None:
        return []
    if isinstance(value, Mapping):
        declarations: list[tuple[str, Mapping[str, Any]]] = []
        for raw_name, raw_declaration in value.items():
            name = str(raw_name).strip()
            if not name:
                raise DataSnapshotValidationError(
                    "data_snapshot.required_artifacts names must not be empty"
                )
            if not isinstance(raw_declaration, Mapping):
                raise DataSnapshotValidationError(
                    f"Required artifact {name!r} must be an object"
                )
            declarations.append((name, raw_declaration))
        return declarations
    if isinstance(value, Sequence) and not isinstance(value, (str, bytes)):
        declarations = []
        for index, raw_declaration in enumerate(value):
            if not isinstance(raw_declaration, Mapping):
                raise DataSnapshotValidationError(
                    f"Required artifact at index {index} must be an object"
                )
            raw_name = raw_declaration.get("name", raw_declaration.get("role"))
            name = str(raw_name or "").strip()
            if not name:
                raise DataSnapshotValidationError(
                    f"Required artifact at index {index} needs a non-empty name"
                )
            declarations.append((name, raw_declaration))
        return declarations
    raise DataSnapshotValidationError(
        "data_snapshot.required_artifacts must be an object or list"
    )


def _verify_artifact(
    name: str,
    path: Path,
    expected_sha256: str,
    verified: dict[str, dict[str, str]],
) -> None:
    actual_sha256 = file_sha256(path).lower()
    if actual_sha256 != expected_sha256:
        raise DataSnapshotValidationError(
            f"Required data snapshot artifact {name!r} has a SHA-256 mismatch"
        )
    verified[name] = {"path": str(path), "sha256": actual_sha256}


def _required_config_path(config: Mapping[str, Any]) -> Path:
    raw_path = config.get("_config_path")
    if not isinstance(raw_path, (str, Path)) or not str(raw_path).strip():
        raise DataSnapshotValidationError(
            "audit_receipt_must_match_config requires a loaded config file path"
        )
    path = Path(raw_path).resolve()
    if not path.is_file():
        raise DataSnapshotValidationError(
            f"Training config file does not exist: {path}"
        )
    return path


def _required_path(
    value: Mapping[str, Any],
    key: str,
    *,
    root: Path,
    context: str,
) -> Path:
    raw_path = value.get(key)
    if not isinstance(raw_path, (str, Path)) or not str(raw_path).strip():
        raise DataSnapshotValidationError(f"{context}.{key} must be a file path")
    path = Path(raw_path)
    if not path.is_absolute():
        path = root / path
    path = path.resolve()
    if not path.is_file():
        raise DataSnapshotValidationError(f"Required file does not exist: {path}")
    return path


def _required_sha256(
    value: Mapping[str, Any], key: str, *, context: str
) -> str:
    raw_digest = value.get(key)
    if not isinstance(raw_digest, str) or not _SHA256_PATTERN.fullmatch(raw_digest):
        raise DataSnapshotValidationError(
            f"{context}.{key} must be a 64-character hexadecimal SHA-256 digest"
        )
    return raw_digest.lower()


def _load_json_object(path: Path, description: str) -> Mapping[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise DataSnapshotValidationError(
            f"Could not read {description} JSON: {path}: {error}"
        ) from error
    if not isinstance(value, Mapping):
        raise DataSnapshotValidationError(
            f"{description.capitalize()} must contain a JSON object: {path}"
        )
    return value
