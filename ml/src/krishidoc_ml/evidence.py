"""Versioned, fail-closed evidence roles for dataset sources."""

from __future__ import annotations

import hashlib
import json
from collections.abc import Mapping, Sequence
from pathlib import Path
from typing import Any


DEFAULT_SOURCE_EVIDENCE_POLICY = (
    Path(__file__).resolve().parents[2]
    / "datasets"
    / "source_evidence_policy_v1.json"
)


class SourceEvidencePolicyError(ValueError):
    """Raised when the source-evidence registry is malformed."""


def load_source_evidence_policy(
    path: str | Path | None = None,
) -> tuple[dict[str, Any], Path, str]:
    """Load and validate the source registry, returning policy, path, and hash."""

    policy_path = Path(path or DEFAULT_SOURCE_EVIDENCE_POLICY).resolve()
    raw = policy_path.read_bytes()
    try:
        policy = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise SourceEvidencePolicyError(
            f"Source-evidence policy is not valid UTF-8 JSON: {policy_path}"
        ) from error
    if not isinstance(policy, dict):
        raise SourceEvidencePolicyError("Source-evidence policy must be a JSON object")
    if policy.get("schema_version") != 1:
        raise SourceEvidencePolicyError(
            "Source-evidence policy schema_version must equal 1"
        )
    if not _non_empty_text(policy.get("policy_id")):
        raise SourceEvidencePolicyError("Source-evidence policy_id is required")
    sources = policy.get("sources")
    if not isinstance(sources, Mapping) or not sources:
        raise SourceEvidencePolicyError(
            "Source-evidence policy sources must be a non-empty object"
        )
    aliases = policy.get("aliases", {})
    if not isinstance(aliases, Mapping):
        raise SourceEvidencePolicyError("Source-evidence policy aliases must be an object")

    for source_id, value in sources.items():
        if not _non_empty_text(source_id) or not isinstance(value, Mapping):
            raise SourceEvidencePolicyError(
                "Every source-evidence entry must have a non-empty id and object value"
            )
        for field in ("evidence_role", "reason"):
            if not _non_empty_text(value.get(field)):
                raise SourceEvidencePolicyError(
                    f"Source {source_id!r} must define non-empty {field!r}"
                )
        for field in ("selection_independent", "promotion_eligible"):
            if not isinstance(value.get(field), bool):
                raise SourceEvidencePolicyError(
                    f"Source {source_id!r} must define boolean {field!r}"
                )

    for alias, canonical in aliases.items():
        if not _non_empty_text(alias) or not _non_empty_text(canonical):
            raise SourceEvidencePolicyError(
                "Source-evidence aliases must map non-empty strings"
            )
        if canonical not in sources:
            raise SourceEvidencePolicyError(
                f"Source-evidence alias {alias!r} targets unknown source {canonical!r}"
            )

    return policy, policy_path, hashlib.sha256(raw).hexdigest()


def resolve_source_evidence(
    source_ids: Sequence[str],
    *,
    policy_path: str | Path | None = None,
) -> dict[str, Any]:
    """Resolve aggregate and per-source evidence metadata.

    Unknown sources deliberately resolve to non-independent and non-promotional.
    This makes evaluation useful for diagnostics while ensuring that adding a new
    source identifier cannot silently create promotion evidence.
    """

    policy, resolved_path, digest = load_source_evidence_policy(policy_path)
    sources: Mapping[str, Mapping[str, Any]] = policy["sources"]
    aliases: Mapping[str, str] = policy.get("aliases", {})
    unique_ids = sorted({str(value).strip() for value in source_ids if str(value).strip()})

    resolved: dict[str, dict[str, Any]] = {}
    for source_id in unique_ids:
        canonical_id = str(aliases.get(source_id, source_id))
        entry = sources.get(canonical_id)
        if entry is None:
            resolved[source_id] = {
                "canonical_source_id": canonical_id,
                "policy_status": "unknown_source",
                "evidence_role": "unknown",
                "selection_independent": False,
                "promotion_eligible": False,
                "reason": "Source id is absent from the versioned evidence policy.",
            }
            continue
        resolved[source_id] = {
            "canonical_source_id": canonical_id,
            "policy_status": "resolved",
            "evidence_role": str(entry["evidence_role"]),
            "selection_independent": bool(entry["selection_independent"]),
            "promotion_eligible": bool(entry["promotion_eligible"]),
            "reason": str(entry["reason"]),
        }

    roles = {item["evidence_role"] for item in resolved.values()}
    role = next(iter(roles)) if len(roles) == 1 else ("mixed" if roles else "unknown")
    all_resolved = bool(resolved) and all(
        item["policy_status"] == "resolved" for item in resolved.values()
    )
    return {
        "evidence_role": role,
        "selection_independent": bool(
            all_resolved
            and all(item["selection_independent"] for item in resolved.values())
        ),
        "promotion_eligible": bool(
            all_resolved and all(item["promotion_eligible"] for item in resolved.values())
        ),
        "source_evidence": resolved,
        "evidence_policy": {
            "policy_id": str(policy["policy_id"]),
            "schema_version": int(policy["schema_version"]),
            "sha256": digest,
            "path": str(resolved_path),
        },
    }


def _non_empty_text(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())
