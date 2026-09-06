from __future__ import annotations

import json
import subprocess
import sys
from copy import deepcopy
from pathlib import Path

import pytest

from krishidoc_ml.promotion import compare_candidate_bundles


CHECKPOINT_SHA = "a" * 64
CONFIG_SHA = "b" * 64
MANIFEST_SHA = "c" * 64


def _identity() -> dict[str, str]:
    return {
        "checkpoint_sha256": CHECKPOINT_SHA,
        "config_sha256": CONFIG_SHA,
        "manifest_sha256": MANIFEST_SHA,
    }


def _internal_report() -> dict:
    return {
        "schema_version": 1,
        "crop": "maize",
        "architecture": "mobilenet_v3_large",
        "split": "test",
        **_identity(),
        "evaluation_domain": {
            "source_ids": ["tom2024-original"],
            "source_locked_to_split": False,
            "independent_from_training": False,
            "sample_count": 200,
        },
        "metrics": {
            "sample_count": 200,
            "condition": {
                "field_macro_f1": 0.88,
                "balanced_accuracy": 0.89,
                "sample_count": 200,
                "per_class": {
                    "maize_common_rust": {
                        "support": 100,
                        "precision": 0.9,
                        "recall": 0.9,
                        "f1": 0.9,
                    },
                    "maize_healthy": {
                        "support": 100,
                        "precision": 0.92,
                        "recall": 0.92,
                        "f1": 0.92,
                    },
                },
            },
            "decision": {"known_accept_rate": 0.9},
        },
    }


def _external_report() -> dict:
    return {
        "schema_version": 1,
        "crop": "maize",
        "architecture": "mobilenet_v3_large",
        "split": "external_test",
        **_identity(),
        "evaluation_domain": {
            "source_ids": ["nepal_field_locked_v1"],
            "source_locked_to_split": True,
            "independent_from_training": True,
            "selection_independent": True,
            "promotion_eligible": True,
            "evidence_role": "external_test",
            "sample_count": 300,
        },
        "metrics": {
            "sample_count": 300,
            "condition": {
                "field_macro_f1": 0.84,
                "macro_f1": 0.85,
                "field_balanced_accuracy": 0.86,
                "balanced_accuracy": 0.87,
                "field_sample_count": 300,
                "sample_count": 300,
                "per_class": {
                    "maize_common_rust": {
                        "support": 150,
                        "precision": 0.84,
                        "recall": 0.82,
                        "f1": 0.83,
                    },
                    "maize_healthy": {
                        "support": 150,
                        "precision": 0.88,
                        "recall": 0.88,
                        "f1": 0.88,
                    },
                },
            },
            "decision": {"known_accept_rate": 0.82},
            "ood": {
                "false_accept_rate": 0.02,
                "false_accept_count": 2,
                "ood_count": 100,
            },
        },
    }


def _deployment_report() -> dict:
    return {
        "schema_version": 1,
        "crop": "maize",
        "architecture": "mobilenet_v3_large",
        **_identity(),
        "deployment": {
            "evidence_schema_version": 1,
            "artifact_format": "tflite",
            "artifact_sha256": "e" * 64,
            "int8_model_bytes": 5_000_000,
            "p95_device_inference_ms": 320,
            "cold_device_inference_ms": 900,
            "steady_sample_count": 100,
            "cold_sample_count": 5,
            "runtime": {"name": "tflite_flutter", "version": "0.12.1"},
            "contract_test": {"passed": True},
            "device": {
                "manufacturer": "Example",
                "model": "Phone",
                "android_version": "15",
                "api_level": 35,
                "abi": "arm64-v8a",
            },
        },
    }


def _export_report() -> dict:
    return {
        "schema_version": 1,
        "source_checkpoint": {
            "sha256": CHECKPOINT_SHA,
            "config_sha256": CONFIG_SHA,
            "manifest_sha256": MANIFEST_SHA,
        },
        "model": {
            "crop": "maize",
            "architecture": "mobilenet_v3_large",
        },
        "artifact": {
            "filename": "candidate.tflite",
            "format": "tflite",
            "sha256": "e" * 64,
            "bytes": 5_000_000,
            "quantization": {
                "mode": "full_integer_int8",
                "input_dtype": "int8",
                "output_dtype": "int8",
            },
        },
        "app_compatibility": {"compatible_with_current_flutter_runtime": True},
        "promotion_evidence": {"int8_model_bytes": 5_000_000},
    }


def _bundle(*, optional_members: bool = True) -> dict:
    members = {
        "internal_test": _internal_report(),
        "external_test": _external_report(),
    }
    if optional_members:
        members.update(
            {
                "deployment_benchmark": _deployment_report(),
                "export": _export_report(),
            }
        )
    return {
        "schema_version": 1,
        "candidate_id": "maize-mobile-bundle",
        "identity": _identity(),
        "members": members,
    }


def _config(*, deployment_gates: bool = True) -> dict:
    gates = {
        "minimum_external_known_accept_rate": 0.75,
        "minimum_external_field_macro_f1": 0.8,
        "minimum_external_condition_macro_f1": 0.8,
        "minimum_external_field_balanced_accuracy": 0.8,
        "minimum_external_condition_balanced_accuracy": 0.8,
        "minimum_external_known_support": 250,
        "minimum_external_field_support": 250,
        "minimum_external_per_class_support": 100,
    }
    if deployment_gates:
        gates.update(
            {
                "maximum_int8_model_bytes_per_crop": 8_000_000,
                "maximum_p95_device_inference_ms": 500,
            }
        )
    return {
        "schema_version": 1,
        "promotion_allowed": True,
        "external_required_labels": ["maize_common_rust", "maize_healthy"],
        "acceptance_gates": gates,
    }


def _gate(candidate: dict, name: str) -> dict:
    return next(item for item in candidate["gates"] if item["name"] == name)


def test_bundle_combines_internal_external_export_and_device_evidence() -> None:
    result = compare_candidate_bundles(
        [_bundle()], _config(), generated_at="2026-09-02T00:00:00+00:00"
    )

    assert result["decision_type"] == (
        "candidate_evidence_bundle_comparison_and_promotion_gate"
    )
    assert result["selection"]["promotion_allowed"] is True
    candidate = result["candidates"][0]
    assert candidate["promotion_allowed"] is True
    assert candidate["identity"]["checkpoint_sha256"] == CHECKPOINT_SHA
    assert candidate["evidence"]["external_test"]["known_accept_rate"] == 0.82
    assert candidate["evidence"]["external_test"]["known_support"] == 300
    assert candidate["evidence"]["int8_model_bytes"] == 5_000_000
    assert candidate["evidence"]["p95_device_inference_ms"] == 320
    assert all(item["status"] == "pass" for item in candidate["gates"])


def test_bundle_ranking_prioritizes_independent_domain_quality() -> None:
    high_internal = _bundle(optional_members=False)
    high_internal["candidate_id"] = "high-internal"
    high_internal["members"]["internal_test"]["metrics"]["condition"][
        "field_macro_f1"
    ] = 0.99
    high_internal["members"]["external_test"]["metrics"]["condition"][
        "field_macro_f1"
    ] = 0.81

    high_external = _bundle(optional_members=False)
    high_external["candidate_id"] = "high-external"
    high_external["members"]["internal_test"]["metrics"]["condition"][
        "field_macro_f1"
    ] = 0.85
    high_external["members"]["external_test"]["metrics"]["condition"][
        "field_macro_f1"
    ] = 0.9

    result = compare_candidate_bundles(
        [high_internal, high_external], _config(deployment_gates=False)
    )

    assert result["selection"]["provisional_best_candidate_id"] == "high-external"


@pytest.mark.parametrize(
    "field", ["checkpoint_sha256", "config_sha256", "manifest_sha256"]
)
def test_any_bundle_identity_mismatch_blocks_promotion(field: str) -> None:
    bundle = _bundle()
    bundle["members"]["external_test"][field] = "d" * 64

    candidate = compare_candidate_bundles([bundle], _config())["candidates"][0]

    identity_gate = _gate(candidate, "bundle_identity_consistency")
    assert identity_gate["status"] == "fail"
    assert field in identity_gate["reason"]
    assert candidate["promotion_allowed"] is False


def test_missing_identity_fails_closed_in_optional_bundle_member() -> None:
    bundle = _bundle()
    del bundle["members"]["export"]["source_checkpoint"]["config_sha256"]

    candidate = compare_candidate_bundles([bundle], _config())["candidates"][0]

    gate = _gate(candidate, "bundle_identity_consistency")
    assert gate["status"] == "fail"
    assert "export.config_sha256" in gate["reason"]


def test_external_domain_gates_fail_on_low_performance_and_support() -> None:
    bundle = _bundle()
    external = bundle["members"]["external_test"]
    external["metrics"]["decision"]["known_accept_rate"] = 0.4
    external["metrics"]["condition"]["field_macro_f1"] = 0.5
    external["metrics"]["condition"]["per_class"]["maize_healthy"]["support"] = 20

    candidate = compare_candidate_bundles([bundle], _config())["candidates"][0]

    assert _gate(candidate, "minimum_external_known_accept_rate")["status"] == "fail"
    assert _gate(candidate, "minimum_external_field_macro_f1")["status"] == "fail"
    assert _gate(candidate, "minimum_external_per_class_support")["status"] == "fail"
    assert candidate["promotion_allowed"] is False


def test_malformed_external_required_labels_cannot_fall_back_to_all_classes() -> None:
    config = _config(deployment_gates=False)
    config["external_required_labels"] = "maize_healthy"

    candidate = compare_candidate_bundles([_bundle(optional_members=False)], config)[
        "candidates"
    ][0]

    gate = _gate(candidate, "minimum_external_per_class_support")
    assert gate["status"] == "unavailable"
    assert candidate["promotion_allowed"] is False


def test_missing_required_external_member_is_a_visible_fail_closed_result() -> None:
    bundle = _bundle(optional_members=False)
    del bundle["members"]["external_test"]

    candidate = compare_candidate_bundles([bundle], _config(deployment_gates=False))[
        "candidates"
    ][0]

    assert _gate(candidate, "evidence_bundle_contract")["status"] == "fail"
    assert _gate(candidate, "external_evaluation_report_contract")["status"] == "fail"
    assert _gate(candidate, "minimum_external_known_accept_rate")["status"] == (
        "unavailable"
    )
    assert candidate["promotion_allowed"] is False


def test_external_source_overlap_blocks_independence_claim() -> None:
    bundle = _bundle(optional_members=False)
    bundle["members"]["external_test"]["evaluation_domain"]["source_ids"] = [
        "tom2024-original"
    ]

    candidate = compare_candidate_bundles([bundle], _config(deployment_gates=False))[
        "candidates"
    ][0]

    gate = _gate(candidate, "external_evaluation_report_contract")
    assert gate["status"] == "fail"
    assert "overlap" in gate["reason"]


def test_consumed_development_source_cannot_be_forged_into_external_evidence() -> None:
    bundle = _bundle(optional_members=False)
    domain = bundle["members"]["external_test"]["evaluation_domain"]
    domain["source_ids"] = ["farmer_chat_india"]
    # Even an old or hand-written report claiming eligibility must be checked
    # against the active source policy.
    domain["selection_independent"] = True
    domain["promotion_eligible"] = True
    domain["evidence_role"] = "external_test"

    candidate = compare_candidate_bundles(
        [bundle], _config(deployment_gates=False)
    )["candidates"][0]

    gate = _gate(candidate, "external_evaluation_report_contract")
    assert gate["status"] == "fail"
    assert "selection_independent=false" in gate["reason"]
    assert "promotion_eligible=false" in gate["reason"]
    assert candidate["promotion_allowed"] is False


def test_external_evidence_metadata_must_be_explicit() -> None:
    bundle = _bundle(optional_members=False)
    domain = bundle["members"]["external_test"]["evaluation_domain"]
    del domain["selection_independent"]
    del domain["promotion_eligible"]
    del domain["evidence_role"]

    candidate = compare_candidate_bundles(
        [bundle], _config(deployment_gates=False)
    )["candidates"][0]

    gate = _gate(candidate, "external_evaluation_report_contract")
    assert gate["status"] == "fail"
    assert "must be explicitly true" in gate["reason"]
    assert "evidence_role" in gate["reason"]


def test_unknown_external_source_fails_even_when_report_claims_eligibility() -> None:
    bundle = _bundle(optional_members=False)
    domain = bundle["members"]["external_test"]["evaluation_domain"]
    domain["source_ids"] = ["unknown-locked-source"]

    candidate = compare_candidate_bundles(
        [bundle], _config(deployment_gates=False)
    )["candidates"][0]

    gate = _gate(candidate, "external_evaluation_report_contract")
    assert gate["status"] == "fail"
    assert "absent from the source-evidence policy" in gate["reason"]
    assert candidate["promotion_allowed"] is False


def test_optional_artifact_evidence_is_only_required_by_configured_gates() -> None:
    without_artifacts = _bundle(optional_members=False)

    candidate = compare_candidate_bundles(
        [without_artifacts], _config(deployment_gates=False)
    )["candidates"][0]
    assert candidate["promotion_allowed"] is True

    candidate = compare_candidate_bundles(
        [without_artifacts], _config(deployment_gates=True)
    )["candidates"][0]
    assert candidate["promotion_allowed"] is False
    assert _gate(candidate, "maximum_int8_model_bytes_per_crop")["status"] == (
        "unavailable"
    )


def test_host_benchmark_cannot_satisfy_physical_device_gates() -> None:
    bundle = _bundle(optional_members=False)
    bundle["members"]["deployment_benchmark"] = {
        "schema_version": 1,
        "scope": "development_host_cpu",
        "promotion_gate_eligible": False,
        "source_checkpoint": {
            "sha256": CHECKPOINT_SHA,
            "config_sha256": CONFIG_SHA,
            "manifest_sha256": MANIFEST_SHA,
        },
        "model": {
            "crop": "maize",
            "architecture": "mobilenet_v3_large",
        },
        "host_benchmark": {"p95_ms": 1.0},
        "deployment": {
            "int8_model_bytes": 1,
            "p95_device_inference_ms": 1,
            "cold_device_inference_ms": 1,
        },
    }

    candidate = compare_candidate_bundles([bundle], _config())["candidates"][0]

    assert _gate(candidate, "deployment_benchmark_report_contract")["status"] == (
        "pass"
    )
    assert _gate(candidate, "maximum_p95_device_inference_ms")["status"] == (
        "unavailable"
    )
    assert candidate["promotion_allowed"] is False


def test_malformed_optional_export_is_a_visible_blocker() -> None:
    bundle = _bundle(optional_members=False)
    bundle["members"]["export"] = _export_report()
    bundle["members"]["export"]["artifact"]["sha256"] = "not-a-digest"

    candidate = compare_candidate_bundles([bundle], _config(deployment_gates=False))[
        "candidates"
    ][0]

    assert _gate(candidate, "export_report_contract")["status"] == "fail"
    assert candidate["promotion_allowed"] is False


def test_cli_loads_relative_paths_from_bundle_descriptor(tmp_path: Path) -> None:
    evidence = tmp_path / "evidence"
    evidence.mkdir()
    (evidence / "internal.json").write_text(
        json.dumps(_internal_report()), encoding="utf-8"
    )
    (evidence / "external.json").write_text(
        json.dumps(_external_report()), encoding="utf-8"
    )
    descriptor = tmp_path / "candidate.bundle.json"
    descriptor.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "candidate_id": "cli-bundle",
                "identity": _identity(),
                "members": {
                    "internal_test": "evidence/internal.json",
                    "external_test": {"path": "evidence/external.json"},
                },
            }
        ),
        encoding="utf-8",
    )
    policy = tmp_path / "policy.json"
    policy.write_text(json.dumps(_config(deployment_gates=False)), encoding="utf-8")
    output_json = tmp_path / "decision.json"
    output_markdown = tmp_path / "decision.md"
    repo_root = Path(__file__).resolve().parents[2]

    completed = subprocess.run(
        [
            sys.executable,
            str(repo_root / "ml" / "scripts" / "compare_candidates.py"),
            "--config",
            str(policy),
            "--bundle",
            str(descriptor),
            "--output-json",
            str(output_json),
            "--output-markdown",
            str(output_markdown),
            "--require-promotion",
        ],
        cwd=repo_root,
        capture_output=True,
        text=True,
        check=False,
    )

    assert completed.returncode == 0, completed.stderr
    decision = json.loads(output_json.read_text(encoding="utf-8"))
    assert decision["selection"]["promotion_candidate_id"] == "cli-bundle"
    assert "External known accept" in output_markdown.read_text(encoding="utf-8")
    assert decision["candidates"][0]["evidence_sources"]["external_test"].endswith(
        "external.json"
    )


def test_standalone_maize_policy_remains_explicitly_provisional() -> None:
    path = (
        Path(__file__).resolve().parents[1]
        / "configs"
        / "maize_promotion_provisional_v1.json"
    )
    policy = json.loads(path.read_text(encoding="utf-8"))

    assert policy["policy_type"] == "candidate_evidence_bundle_promotion"
    assert policy["promotion_allowed"] is False
    assert "minimum_external_known_accept_rate" in policy["acceptance_gates"]
    assert "minimum_external_condition_balanced_accuracy" in policy["acceptance_gates"]

    result = compare_candidate_bundles([deepcopy(_bundle())], policy)
    assert result["selection"]["promotion_allowed"] is False
    assert _gate(result["candidates"][0], "promotion_policy_permission")["status"] == (
        "fail"
    )


def test_standalone_tomato_policy_is_scoped_complete_and_fail_closed() -> None:
    path = (
        Path(__file__).resolve().parents[1]
        / "configs"
        / "tomato_promotion_provisional_v1.json"
    )
    policy = json.loads(path.read_text(encoding="utf-8"))
    expected_labels = [
        "tomato_early_blight",
        "tomato_late_blight",
        "tomato_healthy",
    ]

    assert policy["policy_type"] == "candidate_evidence_bundle_promotion"
    assert policy["crop"] == "tomato"
    assert policy["promotion_allowed"] is False
    assert policy["known_labels"] == expected_labels
    assert policy["external_required_labels"] == expected_labels
    assert policy["required_evidence_roles"] == [
        "internal_test",
        "external_test",
        "deployment_benchmark",
        "export",
    ]
    assert set(policy["evidence_requirements"]) == {
        "internal",
        "external",
        "acceptance",
        "ood",
        "calibration",
        "device_and_int8",
        "nepal",
    }
    gates = policy["acceptance_gates"]
    for name in (
        "minimum_field_macro_f1",
        "minimum_per_class_support",
        "minimum_accepted_set_per_class_precision_lower_95",
        "minimum_external_known_support",
        "minimum_external_per_class_support",
        "maximum_expected_calibration_error",
        "maximum_ood_false_accept_rate_at_operating_point",
        "maximum_int8_field_macro_f1_drop",
        "maximum_int8_model_bytes_per_crop",
        "maximum_p95_device_inference_ms",
        "maximum_cold_device_inference_ms",
        "nepal_field_gate_required_for_confident_results",
    ):
        assert name in gates

    bundle = deepcopy(_bundle())
    bundle["candidate_id"] = "tomato-mobile-bundle"
    for role in ("internal_test", "external_test", "deployment_benchmark"):
        bundle["members"][role]["crop"] = "tomato"
    bundle["members"]["export"]["model"]["crop"] = "tomato"
    for role in ("internal_test", "external_test"):
        per_class = bundle["members"][role]["metrics"]["condition"]["per_class"]
        rust = per_class.pop("maize_common_rust")
        healthy = per_class.pop("maize_healthy")
        per_class["tomato_early_blight"] = deepcopy(rust)
        per_class["tomato_late_blight"] = deepcopy(rust)
        per_class["tomato_healthy"] = healthy

    result = compare_candidate_bundles([bundle], policy)
    candidate = result["candidates"][0]
    assert result["unsupported_acceptance_gates"] == []
    assert _gate(candidate, "promotion_policy_scope")["status"] == "pass"
    assert _gate(candidate, "promotion_policy_permission")["status"] == "fail"
    assert _gate(candidate, "locked_nepal_field_evaluation")["status"] == "fail"
    assert candidate["promotion_allowed"] is False
    assert result["selection"]["promotion_allowed"] is False


def test_standalone_potato_pldd_up_policy_is_robust_and_fail_closed() -> None:
    path = (
        Path(__file__).resolve().parents[1]
        / "configs"
        / "potato_pldd_up_promotion_provisional_v1.json"
    )
    policy = json.loads(path.read_text(encoding="utf-8"))
    expected_labels = [
        "potato_early_blight",
        "potato_late_blight",
        "potato_healthy",
    ]

    assert policy["policy_type"] == "candidate_evidence_bundle_promotion"
    assert policy["source_experiment"] == "potato_pldd_up_provisional_v1"
    assert policy["crop"] == "potato"
    assert policy["promotion_allowed"] is False
    assert policy["known_labels"] == expected_labels
    assert policy["external_required_labels"] == expected_labels
    assert policy["required_evidence_roles"] == [
        "internal_test",
        "external_test",
        "deployment_benchmark",
        "export",
    ]
    assert set(policy["evidence_requirements"]) == {
        "internal",
        "external",
        "acceptance",
        "ood",
        "calibration",
        "device_and_int8",
        "nepal",
    }
    gates = policy["acceptance_gates"]
    assert gates["minimum_per_class_support"] >= 100
    assert gates["minimum_external_known_support"] >= 300
    assert gates["minimum_external_per_class_support"] >= 75
    assert gates["minimum_accepted_set_per_class_precision_lower_95"] >= 0.9
    assert gates["maximum_expected_calibration_error"] <= 0.05
    assert gates["maximum_ood_false_accept_rate_at_operating_point"] <= 0.05
    assert gates["maximum_int8_model_bytes_per_crop"] <= 6_000_000
    assert gates["maximum_int8_field_macro_f1_drop"] <= 0.01
    assert gates["maximum_int8_accepted_risk_drop"] <= 0.01
    assert gates["maximum_p95_device_inference_ms"] <= 750
    assert gates["maximum_cold_device_inference_ms"] <= 2_000
    assert gates["nepal_field_gate_required_for_confident_results"] is True

    bundle = deepcopy(_bundle())
    bundle["candidate_id"] = "potato-pldd-up-mobile-bundle"
    for role in ("internal_test", "external_test", "deployment_benchmark"):
        bundle["members"][role]["crop"] = "potato"
    bundle["members"]["export"]["model"]["crop"] = "potato"
    for role in ("internal_test", "external_test"):
        per_class = bundle["members"][role]["metrics"]["condition"]["per_class"]
        rust = per_class.pop("maize_common_rust")
        healthy = per_class.pop("maize_healthy")
        per_class["potato_early_blight"] = deepcopy(rust)
        per_class["potato_late_blight"] = deepcopy(rust)
        per_class["potato_healthy"] = healthy

    result = compare_candidate_bundles([bundle], policy)
    candidate = result["candidates"][0]
    assert result["unsupported_acceptance_gates"] == []
    assert _gate(candidate, "promotion_policy_scope")["status"] == "pass"
    assert _gate(candidate, "promotion_policy_permission")["status"] == "fail"
    assert _gate(candidate, "locked_nepal_field_evaluation")["status"] == "fail"
    assert candidate["promotion_allowed"] is False
    assert result["selection"]["promotion_allowed"] is False


def test_crop_specific_policy_cannot_assess_a_different_crop() -> None:
    bundle = _bundle(optional_members=False)
    bundle["members"]["internal_test"]["crop"] = "tomato"
    bundle["members"]["external_test"]["crop"] = "tomato"
    config = _config(deployment_gates=False)
    config["crop"] = "maize"

    candidate = compare_candidate_bundles([bundle], config)["candidates"][0]

    gate = _gate(candidate, "promotion_policy_scope")
    assert gate["status"] == "fail"
    assert candidate["promotion_allowed"] is False
