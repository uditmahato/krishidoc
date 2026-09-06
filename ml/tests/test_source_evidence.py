from __future__ import annotations

import json
from pathlib import Path

import pytest

from krishidoc_ml.evidence import (
    SourceEvidencePolicyError,
    load_source_evidence_policy,
    resolve_source_evidence,
)


def test_consumed_digitalgreen_ids_resolve_to_development_only() -> None:
    for source_id in ("farmer_chat_india", "digigreen-crop-disease-images"):
        evidence = resolve_source_evidence([source_id])

        assert evidence["evidence_role"] == "external_development"
        assert evidence["selection_independent"] is False
        assert evidence["promotion_eligible"] is False
        assert evidence["source_evidence"][source_id]["canonical_source_id"] == (
            "farmer_chat_india"
        )


def test_unknown_source_fails_closed() -> None:
    evidence = resolve_source_evidence(["unregistered-future-source"])

    assert evidence["evidence_role"] == "unknown"
    assert evidence["selection_independent"] is False
    assert evidence["promotion_eligible"] is False
    assert evidence["source_evidence"]["unregistered-future-source"][
        "policy_status"
    ] == "unknown_source"


def test_mixed_source_evidence_requires_every_source_to_be_eligible() -> None:
    evidence = resolve_source_evidence(
        ["nepal_field_locked_v1", "farmer_chat_india"]
    )

    assert evidence["evidence_role"] == "mixed"
    assert evidence["selection_independent"] is False
    assert evidence["promotion_eligible"] is False


def test_v2_central_java_is_resolved_as_training_only() -> None:
    policy_path = (
        Path(__file__).parents[1]
        / "datasets"
        / "source_evidence_policy_v2.json"
    )
    for source_id in ("potato-central-java", "potato_central_java"):
        evidence = resolve_source_evidence([source_id], policy_path=policy_path)

        assert evidence["evidence_role"] == "training_or_internal_development"
        assert evidence["selection_independent"] is False
        assert evidence["promotion_eligible"] is False
        assert evidence["source_evidence"][source_id]["canonical_source_id"] == (
            "potato-central-java"
        )


def test_policy_validation_rejects_non_boolean_eligibility(tmp_path: Path) -> None:
    policy = {
        "schema_version": 1,
        "policy_id": "fixture",
        "aliases": {},
        "sources": {
            "fixture": {
                "evidence_role": "external_test",
                "selection_independent": "yes",
                "promotion_eligible": True,
                "reason": "fixture",
            }
        },
    }
    path = tmp_path / "policy.json"
    path.write_text(json.dumps(policy), encoding="utf-8")

    with pytest.raises(SourceEvidencePolicyError, match="boolean"):
        load_source_evidence_policy(path)
