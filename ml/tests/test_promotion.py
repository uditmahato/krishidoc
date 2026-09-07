from __future__ import annotations

import json

import pytest

from krishidoc_ml.promotion import (
    compare_candidates,
    render_model_card_summary,
    wilson_interval,
    write_comparison_outputs,
)


def _config(*, promotion_allowed: bool = True) -> dict:
    return {
        "schema_version": 1,
        "promotion_allowed": promotion_allowed,
        "split_policy": {"future_nepal_test_source": "nepal_field_locked_v1"},
        "acceptance_gates": {
            "minimum_field_macro_f1": 0.8,
            "minimum_worst_known_class_recall": 0.7,
            "minimum_per_class_support": 50,
            "minimum_accepted_set_per_class_precision_lower_95": 0.9,
            "minimum_healthy_precision_lower_95": 0.95,
            "minimum_usable_target_leaf_recall": 0.95,
            "maximum_expected_calibration_error": 0.05,
            "maximum_ood_false_accept_rate_at_operating_point": 0.05,
            "maximum_int8_model_bytes_per_crop": 6_000_000,
            "maximum_p95_device_inference_ms": 750,
            "maximum_cold_device_inference_ms": 2_000,
            "nepal_field_gate_required_for_confident_results": True,
        },
    }


def _passing_report(candidate_id: str = "maize-mobile-v1", field_f1: float = 0.88) -> dict:
    return {
        "schema_version": 1,
        "candidate_id": candidate_id,
        "crop": "maize",
        "architecture": "mobilenet_v3_large",
        "checkpoint_sha256": "a" * 64,
        "split": "test",
        "metrics": {
            "condition": {
                "field_macro_f1": field_f1,
                "calibration": {"ece": 0.03},
                "per_class": {
                    "maize_healthy": {
                        "support": 200,
                        "true_positive": 196,
                        "predicted_positive": 200,
                        "precision": 0.98,
                        "recall": 0.98,
                        "f1": 0.98,
                    },
                    "maize_common_rust": {
                        "support": 100,
                        "true_positive": 90,
                        "predicted_positive": 94,
                        "precision": 90 / 94,
                        "recall": 0.9,
                        "f1": 0.928,
                    },
                },
            },
            "accepted_condition": {
                "per_class": {
                    "maize_healthy": {
                        "support": 200,
                        "true_positive": 199,
                        "predicted_positive": 200,
                        "precision": 0.995,
                        "recall": 0.995,
                        "f1": 0.995,
                    },
                    "maize_common_rust": {
                        "support": 100,
                        "true_positive": 95,
                        "predicted_positive": 96,
                        "precision": 95 / 96,
                        "recall": 0.95,
                        "f1": 0.969,
                    },
                }
            },
            "validity": {
                "per_class": {"usable_target_leaf": {"recall": 0.97}}
            },
            "ood": {
                "false_accept_rate": 0.0,
                "false_accept_count": 0,
                "ood_count": 100,
            },
        },
        "deployment": {
            "int8_model_bytes": 5_500_000,
            "p95_device_inference_ms": 420,
            "cold_device_inference_ms": 1_200,
        },
        "nepal_field_evaluation": {
            "passed": True,
            "locked": True,
            "independently_labeled": True,
            "dataset_id": "nepal_field_locked_v1",
            "sample_count": 500,
        },
    }


def _gate(candidate: dict, name: str) -> dict:
    return next(gate for gate in candidate["gates"] if gate["name"] == name)


def test_wilson_interval_matches_reference_values() -> None:
    lower, upper = wilson_interval(0, 100)
    assert lower == 0.0
    assert upper == pytest.approx(0.0369935, abs=1e-6)

    lower, upper = wilson_interval(95, 100)
    assert lower == pytest.approx(0.88825, abs=1e-5)
    assert upper == pytest.approx(0.97846, abs=1e-5)
    assert wilson_interval(0, 0) is None


def test_all_evidence_can_make_candidate_eligible_without_deploying() -> None:
    result = compare_candidates(
        [_passing_report()], _config(), generated_at="2026-09-02T00:00:00+00:00"
    )

    assert result["selection"]["promotion_allowed"] is True
    assert result["selection"]["deployment_performed"] is False
    candidate = result["candidates"][0]
    assert candidate["quality_gates_passed"] is True
    assert candidate["promotion_allowed"] is True
    assert candidate["evidence"]["ood_false_accept"]["wilson_95"]["upper"] < 0.05
    assert all(gate["status"] == "pass" for gate in candidate["gates"])


def test_explicit_provisional_policy_blocks_even_passing_metrics() -> None:
    result = compare_candidates([_passing_report()], _config(promotion_allowed=False))
    candidate = result["candidates"][0]

    assert candidate["quality_gates_passed"] is True
    assert candidate["promotion_allowed"] is False
    assert result["selection"]["provisional_only"] is True
    policy = _gate(candidate, "promotion_policy_permission")
    assert policy["status"] == "fail"
    assert "promotion_allowed=false" in policy["reason"]


def test_missing_nepal_or_deployment_measurement_fails_closed() -> None:
    report = _passing_report()
    report.pop("nepal_field_evaluation")
    report["deployment"].pop("int8_model_bytes")

    result = compare_candidates([report], _config())
    candidate = result["candidates"][0]

    assert candidate["promotion_allowed"] is False
    assert _gate(candidate, "maximum_int8_model_bytes_per_crop")["status"] == "unavailable"
    assert _gate(candidate, "locked_nepal_field_evaluation")["status"] == "fail"


def test_generic_model_size_cannot_satisfy_int8_size_gate() -> None:
    report = _passing_report()
    report["deployment"].pop("int8_model_bytes")
    report["deployment"]["model_size_bytes"] = 100

    result = compare_candidates([report], _config())

    candidate = result["candidates"][0]
    assert candidate["evidence"]["int8_model_bytes"] is None
    assert _gate(candidate, "maximum_int8_model_bytes_per_crop")["status"] == "unavailable"


def test_precision_gate_never_substitutes_unfiltered_class_metrics() -> None:
    report = _passing_report()
    report["metrics"].pop("accepted_condition")

    result = compare_candidates([report], _config())
    gate = _gate(
        result["candidates"][0],
        "minimum_accepted_set_per_class_precision_lower_95",
    )

    assert gate["status"] == "unavailable"
    assert "unfiltered condition metrics are not substituted" in gate["reason"]


def test_precision_gate_fails_safe_when_one_class_has_no_accepted_prediction() -> None:
    report = _passing_report()
    rust = report["metrics"]["accepted_condition"]["per_class"][
        "maize_common_rust"
    ]
    rust.update(
        {
            "true_positive": 0,
            "predicted_positive": 0,
            "precision": 0.0,
            "recall": 0.0,
            "f1": 0.0,
        }
    )

    result = compare_candidates([report], _config())
    gate = _gate(
        result["candidates"][0],
        "minimum_accepted_set_per_class_precision_lower_95",
    )

    assert gate["status"] == "unavailable"
    assert gate["details"]["maize_common_rust"] is None
    assert "every class" in gate["reason"]


def test_ood_gate_uses_upper_confidence_bound_not_point_estimate() -> None:
    report = _passing_report()
    report["metrics"]["ood"] = {
        "false_accept_rate": 0.0,
        "false_accept_count": 0,
        "ood_count": 10,
    }

    result = compare_candidates([report], _config())
    gate = _gate(
        result["candidates"][0],
        "maximum_ood_false_accept_rate_at_operating_point",
    )

    assert gate["observed"] > 0.25
    assert gate["status"] == "fail"


def test_comparison_selects_best_provisional_candidate_without_claiming_promotion() -> None:
    weaker = _passing_report("weaker", field_f1=0.81)
    stronger = _passing_report("stronger", field_f1=0.91)
    config = _config(promotion_allowed=False)

    result = compare_candidates([weaker, stronger], config)

    assert result["selection"]["provisional_best_candidate_id"] == "stronger"
    assert result["selection"]["promotion_candidate_id"] is None
    assert result["candidates"][0]["provisional_rank"] == 1


def test_unknown_configured_gate_is_a_visible_blocker() -> None:
    config = _config()
    config["acceptance_gates"]["minimum_magic_score"] = 0.9

    result = compare_candidates([_passing_report()], config)
    candidate = result["candidates"][0]

    assert result["unsupported_acceptance_gates"] == ["minimum_magic_score"]
    assert candidate["promotion_allowed"] is False
    assert _gate(candidate, "supported_acceptance_gate_configuration")["status"] == "fail"


def test_writes_machine_report_and_concise_model_card(tmp_path) -> None:
    result = compare_candidates([_passing_report()], _config())
    json_path = tmp_path / "comparison.json"
    markdown_path = tmp_path / "model-card.md"

    write_comparison_outputs(result, json_path, markdown_path)

    persisted = json.loads(json_path.read_text(encoding="utf-8"))
    markdown = markdown_path.read_text(encoding="utf-8")
    assert persisted["selection"]["deployment_performed"] is False
    assert "Candidate comparison" in markdown
    assert "No deployment or app-asset replacement was performed" in markdown
    assert render_model_card_summary(result) == markdown


def test_empty_reports_or_missing_gates_are_rejected() -> None:
    with pytest.raises(ValueError, match="At least one"):
        compare_candidates([], _config())
    with pytest.raises(ValueError, match="acceptance_gates"):
        compare_candidates([_passing_report()], {"schema_version": 1})
