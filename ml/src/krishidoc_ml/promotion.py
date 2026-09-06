"""Fail-closed comparison and promotion decisions for model candidates.

The evaluator intentionally separates *provisional selection* from *promotion*.
A candidate can be the strongest of the reports supplied while still being
ineligible for the app because evidence, policy permission, or the locked
Nepal field gate is missing.
"""

from __future__ import annotations

import hashlib
import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

from .evidence import SourceEvidencePolicyError, resolve_source_evidence


REPORT_SCHEMA_VERSION = 1
BUNDLE_SCHEMA_VERSION = 1
CONFIDENCE_LEVEL = 0.95
Z_95 = 1.959963984540054
REQUIRED_BUNDLE_ROLES = ("internal_test", "external_test")
OPTIONAL_BUNDLE_ROLES = ("deployment_benchmark", "export")
BUNDLE_ROLES = frozenset((*REQUIRED_BUNDLE_ROLES, *OPTIONAL_BUNDLE_ROLES))
IDENTITY_FIELDS = ("checkpoint_sha256", "config_sha256", "manifest_sha256")
MINIMUM_STEADY_DEVICE_SAMPLES = 100
MINIMUM_COLD_DEVICE_SAMPLES = 5

SUPPORTED_ACCEPTANCE_GATES = {
    "minimum_field_macro_f1",
    "minimum_worst_known_class_recall",
    "minimum_worst_known_class_recall_lower_95",
    "minimum_per_class_support",
    "minimum_accepted_set_per_class_precision_lower_95",
    "minimum_per_class_precision_lower_95",
    "minimum_healthy_precision_lower_95",
    "minimum_usable_target_leaf_recall",
    "maximum_expected_calibration_error",
    "maximum_ood_false_accept_rate_at_operating_point",
    "maximum_int8_model_bytes_per_crop",
    "maximum_p95_device_inference_ms",
    "maximum_cold_device_inference_ms",
    "maximum_int8_field_macro_f1_drop",
    "maximum_int8_accepted_risk_drop",
    "minimum_external_known_accept_rate",
    "minimum_external_field_macro_f1",
    "minimum_external_condition_macro_f1",
    "minimum_external_field_balanced_accuracy",
    "minimum_external_condition_balanced_accuracy",
    "minimum_external_known_support",
    "minimum_external_field_support",
    "minimum_external_per_class_support",
    "nepal_field_gate_required_for_confident_results",
}


def wilson_interval(
    successes: int, trials: int, *, z: float = Z_95
) -> tuple[float, float] | None:
    """Return a two-sided Wilson score interval for a binomial proportion."""

    if trials <= 0 or successes < 0 or successes > trials:
        return None
    proportion = successes / trials
    z_squared = z * z
    denominator = 1.0 + z_squared / trials
    centre = proportion + z_squared / (2.0 * trials)
    margin = z * math.sqrt(
        proportion * (1.0 - proportion) / trials + z_squared / (4.0 * trials * trials)
    )
    lower = max(0.0, (centre - margin) / denominator)
    upper = min(1.0, (centre + margin) / denominator)
    # Floating-point cancellation can leave a tiny positive lower bound for
    # 0/n (or a tiny sub-one upper bound for n/n). Preserve the exact binomial
    # boundary in those two cases.
    if successes == 0:
        lower = 0.0
    if successes == trials:
        upper = 1.0
    return lower, upper


def compare_candidates(
    evaluation_reports: Sequence[Mapping[str, Any]],
    config: Mapping[str, Any],
    *,
    report_sources: Sequence[str] | None = None,
    generated_at: str | None = None,
) -> dict[str, Any]:
    """Evaluate candidate reports and return a machine-readable decision.

    Missing measurements are not imputed. Every configured requirement must
    be supported and present for promotion to be eligible.
    """

    if not evaluation_reports:
        raise ValueError("At least one evaluation report is required")
    acceptance_gates = config.get("acceptance_gates")
    if not isinstance(acceptance_gates, Mapping) or not acceptance_gates:
        raise ValueError("Config must contain a non-empty `acceptance_gates` object")

    sources = list(report_sources or [])
    if sources and len(sources) != len(evaluation_reports):
        raise ValueError(
            "report_sources must have the same length as evaluation_reports"
        )

    unsupported = sorted(set(acceptance_gates) - SUPPORTED_ACCEPTANCE_GATES)
    candidates = []
    for index, evaluation in enumerate(evaluation_reports):
        source = sources[index] if sources else None
        candidates.append(
            _evaluate_candidate(
                evaluation,
                config,
                acceptance_gates,
                unsupported_gate_names=unsupported,
                source=source,
                ordinal=index,
            )
        )

    candidate_ids = [candidate["candidate_id"] for candidate in candidates]
    duplicate_ids = sorted(
        candidate_id
        for candidate_id in set(candidate_ids)
        if candidate_ids.count(candidate_id) > 1
    )
    if duplicate_ids:
        raise ValueError(
            "Candidate identifiers must be unique; duplicates: "
            + ", ".join(duplicate_ids)
        )

    ranked = sorted(candidates, key=_ranking_key)
    for rank, candidate in enumerate(ranked, start=1):
        candidate["provisional_rank"] = rank

    best = ranked[0]
    promotable = [candidate for candidate in ranked if candidate["promotion_allowed"]]
    now = generated_at or datetime.now(timezone.utc).isoformat()
    config_payload = {
        key: value for key, value in config.items() if not str(key).startswith("_")
    }
    result = {
        "schema_version": REPORT_SCHEMA_VERSION,
        "generated_at": now,
        "decision_type": "candidate_comparison_and_promotion_gate",
        "confidence_level": CONFIDENCE_LEVEL,
        "config_sha256": _canonical_sha256(config_payload),
        "candidate_count": len(candidates),
        "selection": {
            "provisional_best_candidate_id": best["candidate_id"],
            "provisional_only": not bool(promotable),
            "promotion_allowed": bool(promotable),
            "promotion_candidate_id": (
                promotable[0]["candidate_id"] if promotable else None
            ),
            "deployment_performed": False,
            "explanation": (
                "A candidate satisfies the supplied evidence and policy gates; "
                "human review and a separate integration change are still required."
                if promotable
                else "The strongest observed candidate is provisional only; one or "
                "more required evidence or policy gates failed or were unavailable."
            ),
        },
        "unsupported_acceptance_gates": unsupported,
        "candidates": sorted(candidates, key=lambda item: item["provisional_rank"]),
    }
    return result


def compare_candidate_bundles(
    candidate_bundles: Sequence[Mapping[str, Any]],
    config: Mapping[str, Any],
    *,
    bundle_sources: Sequence[str] | None = None,
    generated_at: str | None = None,
) -> dict[str, Any]:
    """Assess each candidate from grouped, identity-locked evidence.

    A bundle requires separate ``internal_test`` and ``external_test`` members.
    ``deployment_benchmark`` and ``export`` members are optional, but become
    effectively required whenever their measurements are configured as gates.
    Every supplied member must carry the same checkpoint, training-config, and
    manifest SHA-256 identities; missing identity never passes by inference.
    """

    if not candidate_bundles:
        raise ValueError("At least one candidate evidence bundle is required")
    acceptance_gates = config.get("acceptance_gates")
    if not isinstance(acceptance_gates, Mapping) or not acceptance_gates:
        raise ValueError("Config must contain a non-empty `acceptance_gates` object")
    sources = list(bundle_sources or [])
    if sources and len(sources) != len(candidate_bundles):
        raise ValueError(
            "bundle_sources must have the same length as candidate_bundles"
        )

    unsupported = sorted(set(acceptance_gates) - SUPPORTED_ACCEPTANCE_GATES)
    candidates = [
        _evaluate_bundle(
            bundle,
            config,
            acceptance_gates,
            unsupported_gate_names=unsupported,
            source=sources[index] if sources else None,
            ordinal=index,
        )
        for index, bundle in enumerate(candidate_bundles)
    ]
    candidate_ids = [candidate["candidate_id"] for candidate in candidates]
    duplicate_ids = sorted(
        candidate_id
        for candidate_id in set(candidate_ids)
        if candidate_ids.count(candidate_id) > 1
    )
    if duplicate_ids:
        raise ValueError(
            "Candidate identifiers must be unique; duplicates: "
            + ", ".join(duplicate_ids)
        )

    ranked = sorted(candidates, key=_ranking_key)
    for rank, candidate in enumerate(ranked, start=1):
        candidate["provisional_rank"] = rank
    best = ranked[0]
    promotable = [candidate for candidate in ranked if candidate["promotion_allowed"]]
    config_payload = {
        key: value for key, value in config.items() if not str(key).startswith("_")
    }
    return {
        "schema_version": REPORT_SCHEMA_VERSION,
        "generated_at": generated_at or datetime.now(timezone.utc).isoformat(),
        "decision_type": "candidate_evidence_bundle_comparison_and_promotion_gate",
        "confidence_level": CONFIDENCE_LEVEL,
        "config_sha256": _canonical_sha256(config_payload),
        "candidate_count": len(candidates),
        "required_bundle_roles": list(REQUIRED_BUNDLE_ROLES),
        "selection": {
            "provisional_best_candidate_id": best["candidate_id"],
            "provisional_only": not bool(promotable),
            "promotion_allowed": bool(promotable),
            "promotion_candidate_id": (
                promotable[0]["candidate_id"] if promotable else None
            ),
            "deployment_performed": False,
            "explanation": (
                "One evidence bundle satisfies every identity, domain, quality, "
                "and policy gate; human review and a separate integration change "
                "are still required."
                if promotable
                else "The strongest observed bundle is provisional only; one or "
                "more identity, domain, quality, or policy gates failed or were "
                "unavailable."
            ),
        },
        "unsupported_acceptance_gates": unsupported,
        "candidates": sorted(candidates, key=lambda item: item["provisional_rank"]),
    }


def render_model_card_summary(comparison: Mapping[str, Any]) -> str:
    """Render a concise Markdown decision summary from a comparison report."""

    selection = comparison["selection"]
    approved = bool(selection["promotion_allowed"])
    decision = (
        "ELIGIBLE FOR HUMAN-REVIEWED PROMOTION"
        if approved
        else "NOT APPROVED FOR PROMOTION"
    )
    lines = [
        "# KrishiDoc candidate model-card summary",
        "",
        f"**Decision: {decision}.** No deployment or app-asset replacement was performed.",
        "",
        f"Provisional best: `{selection['provisional_best_candidate_id']}`. "
        + str(selection["explanation"]),
        "",
        "## Candidate comparison",
        "",
        "| Rank | Candidate | Crop | Architecture | Internal field macro-F1 | External known accept | External field macro-F1 | External known n | OOD FAR (95% upper) | INT8 bytes | Promotion |",
        "| ---: | --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for candidate in comparison["candidates"]:
        evidence = candidate["evidence"]
        lines.append(
            "| {rank} | `{candidate}` | {crop} | {architecture} | {field_f1} | "
            "{external_accept} | {external_f1} | {external_support} | {far} | "
            "{size} | {promotion} |".format(
                rank=candidate["provisional_rank"],
                candidate=candidate["candidate_id"],
                crop=candidate.get("crop") or "unknown",
                architecture=candidate.get("architecture") or "unknown",
                field_f1=_format_metric(evidence.get("field_macro_f1")),
                external_accept=_format_metric(
                    _nested(evidence, "external_test", "known_accept_rate")
                ),
                external_f1=_format_metric(
                    _nested(evidence, "external_test", "field_macro_f1")
                ),
                external_support=_format_integer(
                    _nested(evidence, "external_test", "known_support")
                ),
                far=_format_metric(
                    _nested(evidence, "ood_false_accept", "wilson_95", "upper")
                ),
                size=_format_integer(evidence.get("int8_model_bytes")),
                promotion="yes" if candidate["promotion_allowed"] else "no",
            )
        )

    lines.extend(["", "## Gate results", ""])
    for candidate in comparison["candidates"]:
        lines.extend([f"### `{candidate['candidate_id']}`", ""])
        failures = [gate for gate in candidate["gates"] if gate["status"] != "pass"]
        if not failures:
            lines.append("All configured evidence and policy gates passed.")
        else:
            for gate in failures:
                lines.append(
                    f"- **{gate['status'].upper()} — {gate['name']}:** {gate['reason']}"
                )
        lines.append("")

    lines.extend(
        [
            "## Interpretation boundary",
            "",
            "Candidate ranking only compares the reports supplied to this command. "
            "A high public-dataset score is not evidence of Nepal field validity. "
            "Missing measurements fail closed, and promotion eligibility never performs deployment.",
            "",
        ]
    )
    return "\n".join(lines)


def write_comparison_outputs(
    comparison: Mapping[str, Any],
    json_path: str | Path,
    markdown_path: str | Path,
) -> None:
    """Atomically write the JSON report and Markdown model-card summary."""

    _atomic_write(
        Path(json_path),
        json.dumps(comparison, indent=2, sort_keys=True, ensure_ascii=False) + "\n",
    )
    _atomic_write(Path(markdown_path), render_model_card_summary(comparison))


def _evaluate_bundle(
    bundle: Mapping[str, Any],
    config: Mapping[str, Any],
    gates: Mapping[str, Any],
    *,
    unsupported_gate_names: Sequence[str],
    source: str | None,
    ordinal: int,
) -> dict[str, Any]:
    structural_errors: list[str] = []
    if not isinstance(bundle, Mapping):
        bundle = {}
        structural_errors.append("bundle must be a JSON object")
    if _as_integer(bundle.get("schema_version")) != BUNDLE_SCHEMA_VERSION:
        structural_errors.append(f"schema_version must equal {BUNDLE_SCHEMA_VERSION}")
    raw_members = bundle.get("members", bundle.get("evidence"))
    if not isinstance(raw_members, Mapping):
        raw_members = {}
        structural_errors.append("members must be an object keyed by evidence role")
    unknown_roles = sorted(set(map(str, raw_members)) - BUNDLE_ROLES)
    if unknown_roles:
        structural_errors.append(f"unsupported evidence roles: {unknown_roles}")
    missing_roles = [role for role in REQUIRED_BUNDLE_ROLES if role not in raw_members]
    if missing_roles:
        structural_errors.append(f"missing required evidence roles: {missing_roles}")

    members: dict[str, Mapping[str, Any]] = {}
    for role in BUNDLE_ROLES:
        value = raw_members.get(role)
        if value is None:
            continue
        if not isinstance(value, Mapping):
            structural_errors.append(f"member {role!r} must be a JSON object")
            continue
        members[role] = value

    internal = members.get("internal_test", {})
    external = members.get("external_test", {})
    candidate_id = _as_text(bundle.get("candidate_id"))
    merged_internal = dict(internal)
    for key in (
        "deployment",
        "device",
        "artifact",
        "quantization",
        "int8_model_bytes",
        "model_size_bytes",
        "p95_device_inference_ms",
        "cold_device_inference_ms",
    ):
        merged_internal.pop(key, None)
    if candidate_id:
        merged_internal["candidate_id"] = candidate_id

    deployment = members.get("deployment_benchmark")
    deployment_projection, deployment_errors = _deployment_evidence_projection(
        deployment
    )
    if deployment_projection:
        merged_internal["deployment"] = deployment_projection

    export = members.get("export")
    export_projection, export_errors = _export_evidence_projection(export)
    if export_projection.get("artifact"):
        merged_internal["artifact"] = export_projection["artifact"]
    if export_projection.get("quantization"):
        merged_internal["quantization"] = export_projection["quantization"]

    nepal = external.get("nepal_field_evaluation")
    if isinstance(nepal, Mapping):
        merged_internal["nepal_field_evaluation"] = dict(nepal)

    evaluated = _evaluate_candidate(
        merged_internal,
        config,
        gates,
        unsupported_gate_names=unsupported_gate_names,
        source=source,
        ordinal=ordinal,
    )
    if candidate_id:
        evaluated["candidate_id"] = candidate_id

    bundle_contract = _gate(
        "evidence_bundle_contract",
        "pass" if not structural_errors else "fail",
        observed={
            "schema_version": bundle.get("schema_version"),
            "roles": sorted(members),
        },
        threshold={
            "schema_version": BUNDLE_SCHEMA_VERSION,
            "required_roles": list(REQUIRED_BUNDLE_ROLES),
            "allowed_roles": sorted(BUNDLE_ROLES),
        },
        comparison="valid grouped evidence descriptor",
        reason=(
            "Required grouped evidence roles are present."
            if not structural_errors
            else "Invalid evidence bundle: " + "; ".join(structural_errors) + "."
        ),
    )
    external_errors = _external_evaluation_contract_errors(external, internal)
    external_contract = _gate(
        "external_evaluation_report_contract",
        "pass" if not external_errors else "fail",
        observed={
            "schema_version": external.get("schema_version"),
            "split": external.get("split"),
            "crop": external.get("crop"),
            "architecture": external.get("architecture"),
            "evaluation_domain": external.get("evaluation_domain"),
        },
        threshold="schema v1 independently held external_test report",
        comparison="valid",
        reason=(
            "Independent external-test report contract is valid."
            if not external_errors
            else "Invalid external evaluation report: "
            + "; ".join(external_errors)
            + "."
        ),
    )
    identity, identity_errors = _bundle_identity_summary(
        members, bundle.get("identity")
    )
    identity_gate = _gate(
        "bundle_identity_consistency",
        "pass" if not identity_errors else "fail",
        observed=identity,
        threshold={
            "required_sha256": list(IDENTITY_FIELDS),
            "consistent_across_all_members": True,
        },
        comparison="exact digest equality",
        reason=(
            "Checkpoint, training-config, and manifest identities match across all evidence."
            if not identity_errors
            else "Evidence identity mismatch or omission: "
            + "; ".join(identity_errors)
            + "."
        ),
    )

    external_evidence = _summarize_external_evidence(external)
    additional_gates = [
        bundle_contract,
        external_contract,
        identity_gate,
        _promotion_policy_scope_gate(config, internal.get("crop")),
    ]
    if deployment is not None:
        additional_gates.append(
            _gate(
                "deployment_benchmark_report_contract",
                "pass" if not deployment_errors else "fail",
                observed={
                    "scope": deployment.get("scope"),
                    "promotion_gate_eligible": deployment.get(
                        "promotion_gate_eligible"
                    ),
                    "deployment": deployment.get("deployment"),
                },
                threshold=(
                    "valid non-promotional host benchmark or composed physical "
                    "Android device evidence"
                ),
                comparison="valid",
                reason=(
                    "Deployment benchmark report contract is valid."
                    if not deployment_errors
                    else "Invalid deployment benchmark report: "
                    + "; ".join(deployment_errors)
                    + "."
                ),
            )
        )
    if export is not None:
        additional_gates.append(
            _gate(
                "export_report_contract",
                "pass" if not export_errors else "fail",
                observed={
                    "schema_version": export.get("schema_version"),
                    "artifact": export.get("artifact"),
                },
                threshold="schema v1 hash-identified ONNX or TFLite export metadata",
                comparison="valid",
                reason=(
                    "Export report contract is valid."
                    if not export_errors
                    else "Invalid export report: " + "; ".join(export_errors) + "."
                ),
            )
        )
    _append_external_metric_gates(additional_gates, gates, external_evidence, config)
    evaluated["gates"].extend(additional_gates)

    internal_evidence = dict(evaluated["evidence"])
    evaluated["evidence"] = {
        **internal_evidence,
        "internal_test": internal_evidence,
        "external_test": external_evidence,
        "deployment_benchmark": _evidence_availability(deployment),
        "export": _evidence_availability(export),
    }
    member_sources = bundle.get("member_sources")
    evaluated["bundle_source"] = source
    evaluated["evidence_sources"] = (
        dict(member_sources) if isinstance(member_sources, Mapping) else {}
    )
    evaluated["evidence_roles"] = sorted(members)
    evaluated["identity"] = identity
    evaluated["checkpoint_sha256"] = identity.get("checkpoint_sha256")
    evaluated["promotion_allowed"] = all(
        item["status"] == "pass" for item in evaluated["gates"]
    )
    evaluated["quality_gates_passed"] = all(
        gate["status"] == "pass"
        for gate in evaluated["gates"]
        if gate["name"]
        not in {"promotion_policy_permission", "locked_nepal_field_evaluation"}
    )
    evaluated["promotion_blockers"] = [
        gate["name"] for gate in evaluated["gates"] if gate["status"] != "pass"
    ]
    return evaluated


def _external_evaluation_contract_errors(
    report: Mapping[str, Any], internal_report: Mapping[str, Any]
) -> list[str]:
    errors: list[str] = []
    if not isinstance(report, Mapping) or not report:
        return ["external_test member is missing or invalid"]
    if _as_integer(report.get("schema_version")) != 1:
        errors.append("schema_version must equal 1")
    if _as_text(report.get("split")) != "external_test":
        errors.append("split must equal 'external_test'")
    if not _as_text(report.get("crop")):
        errors.append("crop is required")
    if not _as_text(report.get("architecture")):
        errors.append("architecture is required")
    if not _is_sha256(report.get("checkpoint_sha256")):
        errors.append("checkpoint_sha256 must be a 64-character hexadecimal digest")
    if not isinstance(report.get("metrics"), Mapping):
        errors.append("metrics object is required")
    domain = report.get("evaluation_domain")
    if not isinstance(domain, Mapping):
        errors.append("evaluation_domain object is required")
        domain = {}
    source_ids = domain.get("source_ids")
    if (
        not isinstance(source_ids, Sequence)
        or isinstance(source_ids, (str, bytes))
        or not source_ids
        or any(not _as_text(value) for value in source_ids)
    ):
        errors.append("evaluation_domain.source_ids must be a non-empty list")
        external_sources: set[str] = set()
    else:
        external_sources = {str(value) for value in source_ids}
    if domain.get("source_locked_to_split") is not True:
        errors.append("evaluation_domain.source_locked_to_split must be true")
    if domain.get("independent_from_training") is not True:
        errors.append("evaluation_domain.independent_from_training must be true")
    if domain.get("selection_independent") is not True:
        errors.append("evaluation_domain.selection_independent must be explicitly true")
    if domain.get("promotion_eligible") is not True:
        errors.append("evaluation_domain.promotion_eligible must be explicitly true")
    if _as_text(domain.get("evidence_role")) != "external_test":
        errors.append("evaluation_domain.evidence_role must equal 'external_test'")

    if external_sources:
        try:
            policy_evidence = resolve_source_evidence(sorted(external_sources))
        except (OSError, SourceEvidencePolicyError) as error:
            errors.append(f"source-evidence policy could not be resolved: {error}")
        else:
            unresolved = sorted(
                source_id
                for source_id, item in policy_evidence["source_evidence"].items()
                if item["policy_status"] != "resolved"
            )
            if unresolved:
                errors.append(
                    "external source_ids are absent from the source-evidence policy: "
                    f"{unresolved}"
                )
            if policy_evidence["selection_independent"] is not True:
                errors.append(
                    "source-evidence policy marks one or more external sources as "
                    "selection_independent=false"
                )
            if policy_evidence["promotion_eligible"] is not True:
                errors.append(
                    "source-evidence policy marks one or more external sources as "
                    "promotion_eligible=false"
                )
            if policy_evidence["evidence_role"] != "external_test":
                errors.append(
                    "source-evidence policy does not assign every external source "
                    "the external_test role"
                )
            for field in (
                "selection_independent",
                "promotion_eligible",
                "evidence_role",
            ):
                if domain.get(field) != policy_evidence[field]:
                    errors.append(
                        f"evaluation_domain.{field} disagrees with the "
                        "source-evidence policy"
                    )
            reported_policy = domain.get("evidence_policy")
            if reported_policy is not None:
                if not isinstance(reported_policy, Mapping):
                    errors.append("evaluation_domain.evidence_policy must be an object")
                else:
                    expected_policy = policy_evidence["evidence_policy"]
                    for field in ("policy_id", "schema_version", "sha256"):
                        if reported_policy.get(field) != expected_policy[field]:
                            errors.append(
                                "evaluation_domain.evidence_policy."
                                f"{field} disagrees with the active policy"
                            )
    domain_count = _as_integer(domain.get("sample_count"))
    metric_count = _as_integer(_nested(report, "metrics", "sample_count"))
    if domain_count is None or domain_count <= 0:
        errors.append("evaluation_domain.sample_count must be a positive integer")
    if metric_count is None or metric_count <= 0:
        errors.append("metrics.sample_count must be a positive integer")
    elif domain_count != metric_count:
        errors.append(
            "evaluation_domain.sample_count disagrees with metrics.sample_count"
        )

    internal_sources = _nested(internal_report, "evaluation_domain", "source_ids")
    if (
        not isinstance(internal_sources, Sequence)
        or isinstance(internal_sources, (str, bytes))
        or not internal_sources
    ):
        errors.append("internal_test evaluation_domain.source_ids is required")
    else:
        overlap = sorted(external_sources & {str(value) for value in internal_sources})
        if overlap:
            errors.append(
                f"external and internal evaluation source_ids overlap: {overlap}"
            )
    for name, value in (
        (
            "known_accept_rate",
            _nested(report, "metrics", "decision", "known_accept_rate"),
        ),
        ("field_macro_f1", _nested(report, "metrics", "condition", "field_macro_f1")),
        ("macro_f1", _nested(report, "metrics", "condition", "macro_f1")),
        (
            "balanced_accuracy",
            _nested(report, "metrics", "condition", "balanced_accuracy"),
        ),
        (
            "field_balanced_accuracy",
            _nested(report, "metrics", "condition", "field_balanced_accuracy"),
        ),
    ):
        number = _as_number(value)
        if value is not None and (number is None or not 0.0 <= number <= 1.0):
            errors.append(f"{name} must be finite and within [0, 1]")
    for name, value in (
        (
            "condition.sample_count",
            _nested(report, "metrics", "condition", "sample_count"),
        ),
        (
            "condition.field_sample_count",
            _nested(report, "metrics", "condition", "field_sample_count"),
        ),
    ):
        count = _as_integer(value)
        if value is not None and (count is None or count < 0):
            errors.append(f"{name} must be a non-negative integer")
    per_class = _nested(report, "metrics", "condition", "per_class")
    if isinstance(per_class, Mapping):
        for label, values in per_class.items():
            if not isinstance(values, Mapping):
                errors.append(f"condition.per_class.{label} must be an object")
                continue
            support = _as_integer(values.get("support"))
            if support is None or support < 0:
                errors.append(f"condition.per_class.{label}.support is invalid")
    return errors


def _promotion_policy_scope_gate(
    config: Mapping[str, Any], observed_crop: Any
) -> dict[str, Any]:
    errors: list[str] = []
    expected_crops: list[str] = []
    if "crop" in config:
        crop = _as_text(config.get("crop"))
        if crop:
            expected_crops = [crop]
        else:
            errors.append("policy crop is empty")
    elif "crops" in config:
        crops = config.get("crops")
        if (
            not isinstance(crops, Sequence)
            or isinstance(crops, (str, bytes))
            or not crops
            or any(not _as_text(crop) for crop in crops)
        ):
            errors.append("policy crops must be a non-empty list")
        else:
            expected_crops = [str(crop) for crop in crops]
    observed = _as_text(observed_crop)
    if expected_crops and observed not in expected_crops:
        errors.append(f"candidate crop {observed!r} is outside policy scope")
    return _gate(
        "promotion_policy_scope",
        "pass" if not errors else "fail",
        observed=observed,
        threshold=expected_crops or "any crop",
        comparison="is within policy crop scope",
        reason=(
            "Candidate crop is within the selected promotion policy scope."
            if not errors
            else "Invalid promotion policy scope: " + "; ".join(errors) + "."
        ),
    )


def _deployment_evidence_projection(
    report: Mapping[str, Any] | None,
) -> tuple[dict[str, Any], list[str]]:
    """Validate a benchmark and expose only promotion-eligible measurements."""

    if report is None:
        return {}, []
    errors: list[str] = []
    if _as_integer(report.get("schema_version")) != 1:
        errors.append("schema_version must equal 1")

    if report.get("scope") == "development_host_cpu":
        if report.get("promotion_gate_eligible") is not False:
            errors.append("host benchmark must explicitly be promotion-ineligible")
        if not isinstance(report.get("host_benchmark"), Mapping):
            errors.append(
                "host_benchmark object is required for development-host scope"
            )
        # Host timing is useful context, but must never satisfy physical-device
        # latency gates.
        return {}, errors

    deployment = report.get("deployment")
    if not isinstance(deployment, Mapping):
        return {}, [*errors, "composed deployment object is required"]
    if _as_integer(deployment.get("evidence_schema_version")) != 1:
        errors.append("deployment.evidence_schema_version must equal 1")
    if deployment.get("artifact_format") != "tflite":
        errors.append("deployment.artifact_format must equal 'tflite'")
    if not _is_sha256(deployment.get("artifact_sha256")):
        errors.append("deployment.artifact_sha256 must be SHA-256")

    size = _as_integer(deployment.get("int8_model_bytes"))
    p95 = _as_number(deployment.get("p95_device_inference_ms"))
    cold = _as_number(deployment.get("cold_device_inference_ms"))
    if size is None or size <= 0:
        errors.append("deployment.int8_model_bytes must be a positive integer")
    if p95 is None or p95 < 0:
        errors.append("deployment.p95_device_inference_ms must be non-negative")
    if cold is None or cold < 0:
        errors.append("deployment.cold_device_inference_ms must be non-negative")
    steady_count = _as_integer(deployment.get("steady_sample_count"))
    cold_count = _as_integer(deployment.get("cold_sample_count"))
    if steady_count is None or steady_count < MINIMUM_STEADY_DEVICE_SAMPLES:
        errors.append(
            "deployment.steady_sample_count must be at least "
            f"{MINIMUM_STEADY_DEVICE_SAMPLES}"
        )
    if cold_count is None or cold_count < MINIMUM_COLD_DEVICE_SAMPLES:
        errors.append(
            "deployment.cold_sample_count must be at least "
            f"{MINIMUM_COLD_DEVICE_SAMPLES}"
        )
    runtime = deployment.get("runtime")
    if not isinstance(runtime, Mapping) or runtime.get("name") != "tflite_flutter":
        errors.append("deployment.runtime.name must equal 'tflite_flutter'")
    contract_test = deployment.get("contract_test")
    if (
        not isinstance(contract_test, Mapping)
        or contract_test.get("passed") is not True
    ):
        errors.append("deployment.contract_test.passed must be true")
    device = deployment.get("device")
    if not isinstance(device, Mapping) or any(
        not _as_text(device.get(key))
        for key in ("manufacturer", "model", "android_version", "api_level", "abi")
    ):
        errors.append("deployment.device identity is incomplete")
    if errors:
        return {}, errors
    return (
        {
            "int8_model_bytes": size,
            "p95_device_inference_ms": p95,
            "cold_device_inference_ms": cold,
        },
        [],
    )


def _export_evidence_projection(
    report: Mapping[str, Any] | None,
) -> tuple[dict[str, Any], list[str]]:
    """Validate export metadata and expose only verified INT8 evidence."""

    if report is None:
        return {}, []
    errors: list[str] = []
    if _as_integer(report.get("schema_version")) != 1:
        errors.append("schema_version must equal 1")
    artifact = report.get("artifact")
    if not isinstance(artifact, Mapping):
        return {}, [*errors, "artifact object is required"]
    artifact_format = _as_text(artifact.get("format"))
    if artifact_format not in {"onnx", "tflite"}:
        errors.append("artifact.format must be 'onnx' or 'tflite'")
    if not _is_sha256(artifact.get("sha256")):
        errors.append("artifact.sha256 must be SHA-256")
    artifact_bytes = _as_integer(artifact.get("bytes"))
    if artifact_bytes is None or artifact_bytes <= 0:
        errors.append("artifact.bytes must be a positive integer")

    projection: dict[str, Any] = {}
    quantization = artifact.get("quantization")
    quantization = quantization if isinstance(quantization, Mapping) else {}
    app_compatibility = report.get("app_compatibility")
    app_compatibility = (
        app_compatibility if isinstance(app_compatibility, Mapping) else {}
    )
    int8_eligible = (
        artifact_format == "tflite"
        and quantization.get("mode") == "full_integer_int8"
        and quantization.get("input_dtype") == "int8"
        and quantization.get("output_dtype") == "int8"
        and app_compatibility.get("compatible_with_current_flutter_runtime") is True
    )
    claimed_size = _as_integer(
        _nested(report, "promotion_evidence", "int8_model_bytes")
    )
    if claimed_size is not None and (
        not int8_eligible or claimed_size != artifact_bytes
    ):
        errors.append(
            "promotion_evidence.int8_model_bytes requires a compatible full-INT8 "
            "TFLite artifact and must equal artifact.bytes"
        )
    if int8_eligible and artifact_bytes is not None:
        projection["artifact"] = {"int8_model_bytes": artifact_bytes}
        comparison = report.get("quantization")
        if isinstance(comparison, Mapping):
            projection["quantization"] = dict(comparison)
    return ({} if errors else projection), errors


def _bundle_identity_summary(
    members: Mapping[str, Mapping[str, Any]], expected: Any
) -> tuple[dict[str, Any], list[str]]:
    errors: list[str] = []
    member_identities: dict[str, dict[str, Any]] = {}
    expected_identity = expected if isinstance(expected, Mapping) else {}
    if expected is not None and not isinstance(expected, Mapping):
        errors.append("descriptor identity must be an object")

    for role in sorted(members):
        identity = {
            field: _identity_value(members[role], field) for field in IDENTITY_FIELDS
        }
        member_identities[role] = identity
        for field, value in identity.items():
            if not _is_sha256(value):
                errors.append(f"{role}.{field} is missing or is not SHA-256")

    resolved: dict[str, Any] = {}
    for field in IDENTITY_FIELDS:
        values = {
            str(identity[field]).casefold()
            for identity in member_identities.values()
            if _is_sha256(identity[field])
        }
        expected_value = expected_identity.get(field)
        if expected_identity and not _is_sha256(expected_value):
            errors.append(f"descriptor identity.{field} is missing or is not SHA-256")
        if _is_sha256(expected_value):
            values.add(str(expected_value).casefold())
        if len(values) > 1:
            errors.append(f"{field} differs across bundle members")
        resolved[field] = next(iter(values)) if len(values) == 1 else None

    crop_values = {
        value
        for value in (_member_text(member, "crop") for member in members.values())
        if value
    }
    architecture_values = {
        value
        for value in (
            _member_text(member, "architecture") for member in members.values()
        )
        if value
    }
    if len(crop_values) > 1:
        errors.append("crop differs across bundle members")
    if len(architecture_values) > 1:
        errors.append("architecture differs across bundle members")
    return (
        {
            **resolved,
            "crop": next(iter(crop_values)) if len(crop_values) == 1 else None,
            "architecture": (
                next(iter(architecture_values))
                if len(architecture_values) == 1
                else None
            ),
            "members": member_identities,
        },
        errors,
    )


def _identity_value(report: Mapping[str, Any], field: str) -> Any:
    direct = report.get(field)
    if direct is not None:
        return direct
    for container_name in ("identity", "provenance"):
        container = report.get(container_name)
        if isinstance(container, Mapping) and container.get(field) is not None:
            return container.get(field)
    source_checkpoint = report.get("source_checkpoint")
    if isinstance(source_checkpoint, Mapping):
        nested_key = "sha256" if field == "checkpoint_sha256" else field
        return source_checkpoint.get(nested_key)
    return None


def _member_text(report: Mapping[str, Any], field: str) -> str | None:
    direct = _as_text(report.get(field))
    if direct:
        return direct
    model = report.get("model")
    return _as_text(model.get(field)) if isinstance(model, Mapping) else None


def _summarize_external_evidence(report: Mapping[str, Any]) -> dict[str, Any]:
    metrics = report.get("metrics")
    metrics = metrics if isinstance(metrics, Mapping) else {}
    condition = metrics.get("condition")
    condition = condition if isinstance(condition, Mapping) else {}
    per_class = condition.get("per_class")
    per_class = per_class if isinstance(per_class, Mapping) else {}
    summarized = {
        str(label): _summarize_class(str(label), values)
        for label, values in per_class.items()
        if isinstance(values, Mapping)
    }
    support = _as_integer(condition.get("sample_count"))
    if support is None and summarized:
        class_supports = [item.get("support") for item in summarized.values()]
        if all(isinstance(value, int) and value >= 0 for value in class_supports):
            support = sum(class_supports)
    ood = metrics.get("ood")
    ood = ood if isinstance(ood, Mapping) else {}
    false_accept_count = _as_integer(ood.get("false_accept_count"))
    ood_count = _as_integer(ood.get("ood_count"))
    return {
        "known_accept_rate": _as_number(
            _nested(metrics, "decision", "known_accept_rate")
        ),
        "field_macro_f1": _as_number(condition.get("field_macro_f1")),
        "condition_macro_f1": _as_number(condition.get("macro_f1")),
        "field_balanced_accuracy": _as_number(condition.get("field_balanced_accuracy")),
        "condition_balanced_accuracy": _as_number(condition.get("balanced_accuracy")),
        "known_support": support,
        "field_support": _as_integer(condition.get("field_sample_count")),
        "per_class": summarized,
        "ood_false_accept": {
            "rate": _as_number(ood.get("false_accept_rate")),
            "false_accept_count": false_accept_count,
            "ood_count": ood_count,
            "wilson_95": _interval_dict(
                wilson_interval(false_accept_count, ood_count)
                if false_accept_count is not None and ood_count is not None
                else None
            ),
        },
    }


def _append_external_metric_gates(
    results: list[dict[str, Any]],
    gates: Mapping[str, Any],
    evidence: Mapping[str, Any],
    config: Mapping[str, Any],
) -> None:
    scalar_gates = (
        ("minimum_external_known_accept_rate", "known_accept_rate"),
        ("minimum_external_field_macro_f1", "field_macro_f1"),
        ("minimum_external_condition_macro_f1", "condition_macro_f1"),
        (
            "minimum_external_field_balanced_accuracy",
            "field_balanced_accuracy",
        ),
        (
            "minimum_external_condition_balanced_accuracy",
            "condition_balanced_accuracy",
        ),
        ("minimum_external_known_support", "known_support"),
        ("minimum_external_field_support", "field_support"),
    )
    for gate_name, evidence_name in scalar_gates:
        if gate_name in gates:
            results.append(
                _numeric_gate(
                    gate_name,
                    evidence.get(evidence_name),
                    gates[gate_name],
                    ">=",
                    unavailable_reason=(
                        f"Independent external-test measurement {evidence_name!r} "
                        "is absent or not finite."
                    ),
                )
            )

    if "minimum_external_per_class_support" in gates:
        all_supports = {
            label: item.get("support")
            for label, item in evidence.get("per_class", {}).items()
        }
        required_labels = config.get("external_required_labels")
        labels_configured = "external_required_labels" in config
        labels_valid = (
            isinstance(required_labels, Sequence)
            and not isinstance(required_labels, (str, bytes))
            and bool(required_labels)
            and all(_as_text(label) for label in required_labels)
        )
        if labels_configured and labels_valid:
            supports = {
                str(label): all_supports.get(str(label)) for label in required_labels
            }
        elif labels_configured:
            supports = {}
        else:
            supports = all_supports
        integer_supports = {
            label: _as_integer(value) for label, value in supports.items()
        }
        observed = (
            min(value for value in integer_supports.values() if value is not None)
            if integer_supports
            and all(value is not None for value in integer_supports.values())
            else None
        )
        results.append(
            _numeric_gate(
                "minimum_external_per_class_support",
                observed,
                gates["minimum_external_per_class_support"],
                ">=",
                details=integer_supports,
                unavailable_reason=(
                    "external_required_labels is invalid, or independent "
                    "external-test support is missing for one or more required "
                    "condition labels."
                ),
            )
        )


def _evidence_availability(report: Mapping[str, Any] | None) -> dict[str, Any]:
    return {
        "provided": isinstance(report, Mapping),
        "schema_version": report.get("schema_version") if report else None,
    }


def _evaluate_candidate(
    report: Mapping[str, Any],
    config: Mapping[str, Any],
    gates: Mapping[str, Any],
    *,
    unsupported_gate_names: Sequence[str],
    source: str | None,
    ordinal: int,
) -> dict[str, Any]:
    if not isinstance(report, Mapping):
        raise ValueError(f"Evaluation report {ordinal + 1} must be a JSON object")
    metrics = report.get("metrics")
    if not isinstance(metrics, Mapping):
        metrics = {}

    condition = metrics.get("condition")
    condition = condition if isinstance(condition, Mapping) else {}
    per_class = condition.get("per_class")
    per_class = per_class if isinstance(per_class, Mapping) else {}
    accepted_per_class = _first_mapping(
        metrics.get("accepted_condition"),
        condition.get("accepted"),
        condition.get("accepted_set"),
    )
    accepted_per_class = (
        accepted_per_class.get("per_class", {})
        if isinstance(accepted_per_class, Mapping)
        else {}
    )

    summarized_classes = {
        str(label): _summarize_class(str(label), values)
        for label, values in per_class.items()
        if isinstance(values, Mapping)
    }
    summarized_accepted = {
        str(label): _summarize_class(str(label), values)
        for label, values in accepted_per_class.items()
        if isinstance(values, Mapping)
    }

    field_macro_f1 = _as_number(condition.get("field_macro_f1"))
    recalls = [
        item["recall"]
        for item in summarized_classes.values()
        if item["support"] and item["recall"] is not None
    ]
    recall_lowers = [
        item["recall_wilson_95"]["lower"]
        for item in summarized_classes.values()
        if item.get("recall_wilson_95") is not None
    ]
    ece = _as_number(_nested(condition, "calibration", "ece"))
    ood = metrics.get("ood")
    ood = ood if isinstance(ood, Mapping) else {}
    false_accept_rate = _as_number(ood.get("false_accept_rate"))
    false_accept_count = _as_integer(ood.get("false_accept_count"))
    ood_count = _as_integer(ood.get("ood_count"))
    far_interval = (
        wilson_interval(false_accept_count, ood_count)
        if false_accept_count is not None and ood_count is not None
        else None
    )

    model_size = _first_number(
        report,
        ("deployment", "int8_model_bytes"),
        ("artifact", "int8_model_bytes"),
        ("int8_model_bytes",),
    )
    p95_latency = _first_number(
        report,
        ("deployment", "p95_device_inference_ms"),
        ("device", "p95_device_inference_ms"),
        ("p95_device_inference_ms",),
    )
    cold_latency = _first_number(
        report,
        ("deployment", "cold_device_inference_ms"),
        ("device", "cold_device_inference_ms"),
        ("cold_device_inference_ms",),
    )
    usable_recall = _as_number(
        _nested(metrics, "validity", "per_class", "usable_target_leaf", "recall")
    )
    float_to_int8_f1_drop = _first_number(
        report,
        ("quantization", "field_macro_f1_drop"),
        ("deployment", "int8_field_macro_f1_drop"),
    )
    float_to_int8_risk_drop = _first_number(
        report,
        ("quantization", "accepted_risk_drop"),
        ("deployment", "int8_accepted_risk_drop"),
    )

    evidence = {
        "field_macro_f1": field_macro_f1,
        "worst_known_class_recall": min(recalls) if recalls else None,
        "worst_known_class_recall_wilson_95_lower": (
            min(recall_lowers) if recall_lowers else None
        ),
        "expected_calibration_error": ece,
        "per_class": summarized_classes,
        "accepted_set_per_class": summarized_accepted,
        "ood_false_accept": {
            "rate": false_accept_rate,
            "false_accept_count": false_accept_count,
            "ood_count": ood_count,
            "wilson_95": _interval_dict(far_interval),
        },
        "usable_target_leaf_recall": usable_recall,
        "int8_model_bytes": _integer_if_whole(model_size),
        "p95_device_inference_ms": p95_latency,
        "cold_device_inference_ms": cold_latency,
        "int8_field_macro_f1_drop": float_to_int8_f1_drop,
        "int8_accepted_risk_drop": float_to_int8_risk_drop,
        "nepal_field_evaluation": _summarize_nepal_evidence(report, config),
    }

    gate_results: list[dict[str, Any]] = []
    contract_errors = _evaluation_contract_errors(report)
    gate_results.append(
        _gate(
            "evaluation_report_contract",
            "pass" if not contract_errors else "fail",
            observed={
                "schema_version": report.get("schema_version"),
                "split": report.get("split"),
                "crop": report.get("crop"),
                "architecture": report.get("architecture"),
                "checkpoint_sha256": report.get("checkpoint_sha256"),
            },
            threshold="schema v1 frozen test report with checkpoint provenance",
            comparison="valid",
            reason=(
                "Evaluation report provenance and split contract are valid."
                if not contract_errors
                else "Invalid evaluation report: " + "; ".join(contract_errors) + "."
            ),
        )
    )
    if unsupported_gate_names:
        gate_results.append(
            _gate(
                "supported_acceptance_gate_configuration",
                "fail",
                observed=list(unsupported_gate_names),
                threshold="all configured gate names must be supported",
                comparison="supported",
                reason="Unsupported configured gates would otherwise be silently ignored.",
            )
        )

    _append_configured_metric_gates(gate_results, gates, evidence)
    gate_results.append(_promotion_policy_gate(config))
    if bool(gates.get("nepal_field_gate_required_for_confident_results", False)):
        nepal = evidence["nepal_field_evaluation"]
        gate_results.append(
            _gate(
                "locked_nepal_field_evaluation",
                "pass" if nepal["passed"] else "fail",
                observed=nepal,
                threshold={
                    "passed": True,
                    "locked": True,
                    "independently_labeled": True,
                    "dataset_id": nepal["expected_dataset_id"],
                },
                comparison="verified evidence required",
                reason=(
                    "Locked Nepal field evidence is present and passes."
                    if nepal["passed"]
                    else nepal["reason"]
                ),
            )
        )

    promotion_allowed = all(item["status"] == "pass" for item in gate_results)
    candidate_id = _candidate_id(report, source=source, ordinal=ordinal)
    return {
        "candidate_id": candidate_id,
        "crop": _as_text(report.get("crop")),
        "architecture": _as_text(report.get("architecture")),
        "checkpoint_sha256": _as_text(report.get("checkpoint_sha256")),
        "evaluation_source": source,
        "split": _as_text(report.get("split")),
        "evidence": evidence,
        "gates": gate_results,
        "quality_gates_passed": all(
            gate["status"] == "pass"
            for gate in gate_results
            if gate["name"]
            not in {"promotion_policy_permission", "locked_nepal_field_evaluation"}
        ),
        "promotion_allowed": promotion_allowed,
        "promotion_blockers": [
            gate["name"] for gate in gate_results if gate["status"] != "pass"
        ],
    }


def _evaluation_contract_errors(report: Mapping[str, Any]) -> list[str]:
    errors = []
    if _as_integer(report.get("schema_version")) != 1:
        errors.append("schema_version must equal 1")
    if _as_text(report.get("split")) != "test":
        errors.append("split must equal 'test'")
    if not _as_text(report.get("crop")):
        errors.append("crop is required")
    if not _as_text(report.get("architecture")):
        errors.append("architecture is required")
    checkpoint_sha256 = _as_text(report.get("checkpoint_sha256")) or ""
    if len(checkpoint_sha256) != 64 or any(
        character not in "0123456789abcdefABCDEF" for character in checkpoint_sha256
    ):
        errors.append("checkpoint_sha256 must be a 64-character hexadecimal digest")

    rate = _as_number(_nested(report, "metrics", "ood", "false_accept_rate"))
    false_accept_count = _as_integer(
        _nested(report, "metrics", "ood", "false_accept_count")
    )
    ood_count = _as_integer(_nested(report, "metrics", "ood", "ood_count"))
    if (
        rate is not None
        and false_accept_count is not None
        and ood_count is not None
        and ood_count > 0
        and abs(rate - false_accept_count / ood_count) > 1e-9
    ):
        errors.append("OOD false_accept_rate disagrees with its counts")
    return errors


def _append_configured_metric_gates(
    results: list[dict[str, Any]],
    gates: Mapping[str, Any],
    evidence: Mapping[str, Any],
) -> None:
    scalar_gates = (
        ("minimum_field_macro_f1", "field_macro_f1", ">="),
        (
            "minimum_worst_known_class_recall",
            "worst_known_class_recall",
            ">=",
        ),
        (
            "minimum_worst_known_class_recall_lower_95",
            "worst_known_class_recall_wilson_95_lower",
            ">=",
        ),
        (
            "minimum_usable_target_leaf_recall",
            "usable_target_leaf_recall",
            ">=",
        ),
        (
            "maximum_expected_calibration_error",
            "expected_calibration_error",
            "<=",
        ),
        (
            "maximum_int8_model_bytes_per_crop",
            "int8_model_bytes",
            "<=",
        ),
        (
            "maximum_p95_device_inference_ms",
            "p95_device_inference_ms",
            "<=",
        ),
        (
            "maximum_cold_device_inference_ms",
            "cold_device_inference_ms",
            "<=",
        ),
        (
            "maximum_int8_field_macro_f1_drop",
            "int8_field_macro_f1_drop",
            "<=",
        ),
        (
            "maximum_int8_accepted_risk_drop",
            "int8_accepted_risk_drop",
            "<=",
        ),
    )
    for config_name, evidence_name, comparison in scalar_gates:
        if config_name in gates:
            results.append(
                _numeric_gate(
                    config_name,
                    evidence.get(evidence_name),
                    gates[config_name],
                    comparison,
                )
            )

    if "minimum_per_class_support" in gates:
        threshold = gates["minimum_per_class_support"]
        supports = {
            label: item.get("support") for label, item in evidence["per_class"].items()
        }
        observed = min(supports.values()) if supports else None
        results.append(
            _numeric_gate(
                "minimum_per_class_support",
                observed,
                threshold,
                ">=",
                details=supports,
            )
        )

    precision_gate_name = None
    for possible in (
        "minimum_accepted_set_per_class_precision_lower_95",
        "minimum_per_class_precision_lower_95",
    ):
        if possible in gates:
            precision_gate_name = possible
            break
    if precision_gate_name:
        lowers = {
            label: _nested(item, "precision_wilson_95", "lower")
            for label, item in evidence["accepted_set_per_class"].items()
        }
        complete = bool(lowers) and all(value is not None for value in lowers.values())
        observed = min(lowers.values()) if complete else None
        results.append(
            _numeric_gate(
                precision_gate_name,
                observed,
                gates[precision_gate_name],
                ">=",
                details=lowers,
                unavailable_reason=(
                    "Accepted-set per-class confusion counts with at least one "
                    "accepted prediction for every class are required; unfiltered "
                    "condition metrics are not substituted."
                ),
            )
        )

    if "minimum_healthy_precision_lower_95" in gates:
        healthy = {
            label: _nested(item, "precision_wilson_95", "lower")
            for label, item in evidence["accepted_set_per_class"].items()
            if label.lower() == "healthy" or label.lower().endswith("_healthy")
        }
        complete = bool(healthy) and all(value is not None for value in healthy.values())
        observed = min(healthy.values()) if complete else None
        results.append(
            _numeric_gate(
                "minimum_healthy_precision_lower_95",
                observed,
                gates["minimum_healthy_precision_lower_95"],
                ">=",
                details=healthy,
                unavailable_reason=(
                    "Accepted-set healthy precision counts are absent or no healthy class is identified."
                ),
            )
        )

    if "maximum_ood_false_accept_rate_at_operating_point" in gates:
        far = evidence["ood_false_accept"]
        upper = _nested(far, "wilson_95", "upper")
        results.append(
            _numeric_gate(
                "maximum_ood_false_accept_rate_at_operating_point",
                upper,
                gates["maximum_ood_false_accept_rate_at_operating_point"],
                "<=",
                details=far,
                unavailable_reason=(
                    "OOD false-accept numerator and denominator are required for the conservative Wilson upper bound."
                ),
            )
        )


def _summarize_class(label: str, values: Mapping[str, Any]) -> dict[str, Any]:
    support = _as_integer(values.get("support"))
    precision = _as_number(values.get("precision"))
    recall = _as_number(values.get("recall"))
    true_positive = _as_integer(values.get("true_positive"))
    predicted_positive = _as_integer(values.get("predicted_positive"))

    if true_positive is None and support is not None and recall is not None:
        true_positive = _recover_count(recall, support)
    if (
        predicted_positive is None
        and true_positive is not None
        and precision is not None
    ):
        if precision > 0:
            predicted_positive = _recover_denominator(true_positive, precision)
        elif true_positive == 0:
            predicted_positive = _as_integer(values.get("false_positive"))

    recall_interval = (
        wilson_interval(true_positive, support)
        if true_positive is not None and support is not None
        else None
    )
    precision_interval = (
        wilson_interval(true_positive, predicted_positive)
        if true_positive is not None and predicted_positive is not None
        else None
    )
    return {
        "label": label,
        "support": support,
        "precision": precision,
        "recall": recall,
        "f1": _as_number(values.get("f1")),
        "true_positive": true_positive,
        "predicted_positive": predicted_positive,
        "precision_wilson_95": _interval_dict(precision_interval),
        "recall_wilson_95": _interval_dict(recall_interval),
    }


def _summarize_nepal_evidence(
    report: Mapping[str, Any], config: Mapping[str, Any]
) -> dict[str, Any]:
    expected = (
        _as_text(_nested(config, "split_policy", "future_nepal_test_source"))
        or "nepal_field_locked_v1"
    )
    raw = report.get("nepal_field_evaluation")
    raw = raw if isinstance(raw, Mapping) else {}
    dataset_id = _as_text(raw.get("dataset_id"))
    locked = raw.get("locked") is True
    independently_labeled = raw.get("independently_labeled") is True
    reported_pass = raw.get("passed") is True
    matches_expected = dataset_id == expected
    passed = reported_pass and locked and independently_labeled and matches_expected
    missing = []
    if not reported_pass:
        missing.append("passed=true")
    if not locked:
        missing.append("locked=true")
    if not independently_labeled:
        missing.append("independently_labeled=true")
    if not matches_expected:
        missing.append(f"dataset_id={expected!r}")
    return {
        "passed": passed,
        "reported_pass": reported_pass,
        "locked": locked,
        "independently_labeled": independently_labeled,
        "dataset_id": dataset_id,
        "expected_dataset_id": expected,
        "sample_count": _as_integer(raw.get("sample_count")),
        "reason": (
            "All locked Nepal evidence requirements are satisfied."
            if passed
            else "Missing or invalid Nepal evidence: " + ", ".join(missing) + "."
        ),
    }


def _promotion_policy_gate(config: Mapping[str, Any]) -> dict[str, Any]:
    explicit = config.get("promotion_allowed")
    passed = explicit is True
    reason = (
        "The config explicitly permits promotion evaluation."
        if passed
        else (
            "The config explicitly sets promotion_allowed=false."
            if explicit is False
            else "The config does not explicitly set promotion_allowed=true; fail-closed policy blocks promotion."
        )
    )
    return _gate(
        "promotion_policy_permission",
        "pass" if passed else "fail",
        observed=explicit,
        threshold=True,
        comparison="is exactly true",
        reason=reason,
    )


def _numeric_gate(
    name: str,
    observed: Any,
    threshold: Any,
    comparison: str,
    *,
    details: Any = None,
    unavailable_reason: str | None = None,
) -> dict[str, Any]:
    observed_number = _as_number(observed)
    threshold_number = _as_number(threshold)
    if threshold_number is None:
        return _gate(
            name,
            "fail",
            observed=observed,
            threshold=threshold,
            comparison=comparison,
            details=details,
            reason="Configured threshold is not a finite number.",
        )
    if observed_number is None:
        return _gate(
            name,
            "unavailable",
            observed=None,
            threshold=threshold_number,
            comparison=comparison,
            details=details,
            reason=unavailable_reason
            or "Required measurement is absent or not finite.",
        )
    passed = (
        observed_number >= threshold_number
        if comparison == ">="
        else observed_number <= threshold_number
    )
    return _gate(
        name,
        "pass" if passed else "fail",
        observed=observed_number,
        threshold=threshold_number,
        comparison=comparison,
        details=details,
        reason=(
            f"Observed {observed_number:.6g} {comparison} {threshold_number:.6g}."
            if passed
            else f"Observed {observed_number:.6g} does not satisfy {comparison} {threshold_number:.6g}."
        ),
    )


def _gate(
    name: str,
    status: str,
    *,
    observed: Any,
    threshold: Any,
    comparison: str,
    reason: str,
    details: Any = None,
) -> dict[str, Any]:
    result = {
        "name": name,
        "status": status,
        "observed": observed,
        "threshold": threshold,
        "comparison": comparison,
        "reason": reason,
    }
    if details is not None:
        result["details"] = details
    return result


def _ranking_key(candidate: Mapping[str, Any]) -> tuple[Any, ...]:
    evidence = candidate["evidence"]
    external = evidence.get("external_test")
    external = external if isinstance(external, Mapping) else {}
    # Missing evidence always ranks after measured evidence. Promotion eligibility
    # ranks first only among otherwise comparable candidates. In bundle mode,
    # independent-domain quality ranks before the internal test score.
    return (
        0 if candidate["quality_gates_passed"] else 1,
        _descending(external.get("field_macro_f1")),
        _descending(external.get("condition_macro_f1")),
        _descending(external.get("field_balanced_accuracy")),
        _descending(external.get("condition_balanced_accuracy")),
        _descending(external.get("known_accept_rate")),
        _descending(evidence.get("field_macro_f1")),
        _descending(evidence.get("worst_known_class_recall")),
        _ascending(evidence.get("expected_calibration_error")),
        _ascending(_nested(evidence, "ood_false_accept", "wilson_95", "upper")),
        _ascending(evidence.get("int8_model_bytes")),
        _ascending(evidence.get("p95_device_inference_ms")),
        str(candidate["candidate_id"]),
    )


def _candidate_id(
    report: Mapping[str, Any], *, source: str | None, ordinal: int
) -> str:
    explicit = _as_text(report.get("candidate_id"))
    if explicit:
        return explicit
    crop = _as_text(report.get("crop")) or "unknown-crop"
    architecture = _as_text(report.get("architecture")) or "unknown-architecture"
    digest = _as_text(report.get("checkpoint_sha256"))
    if not digest:
        digest = _canonical_sha256(report)
    return f"{crop}:{architecture}:{digest[:12]}"


def _recover_count(rate: float, denominator: int) -> int | None:
    if denominator < 0 or not 0.0 <= rate <= 1.0:
        return None
    count = int(round(rate * denominator))
    tolerance = max(1e-9, 0.5 / max(1, denominator) + 1e-9)
    return count if abs(count / max(1, denominator) - rate) <= tolerance else None


def _recover_denominator(successes: int, rate: float) -> int | None:
    if successes < 0 or not 0.0 < rate <= 1.0:
        return None
    denominator = int(round(successes / rate))
    if denominator < successes or denominator <= 0:
        return None
    tolerance = max(1e-9, 0.5 / denominator + 1e-9)
    return denominator if abs(successes / denominator - rate) <= tolerance else None


def _interval_dict(interval: tuple[float, float] | None) -> dict[str, float] | None:
    if interval is None:
        return None
    return {"lower": interval[0], "upper": interval[1]}


def _canonical_sha256(value: Any) -> str:
    payload = json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def _atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def _nested(value: Any, *keys: str) -> Any:
    cursor = value
    for key in keys:
        if not isinstance(cursor, Mapping):
            return None
        cursor = cursor.get(key)
    return cursor


def _first_mapping(*values: Any) -> Mapping[str, Any] | None:
    for value in values:
        if isinstance(value, Mapping):
            return value
    return None


def _first_number(report: Mapping[str, Any], *paths: tuple[str, ...]) -> float | None:
    for path in paths:
        value = _as_number(_nested(report, *path))
        if value is not None:
            return value
    return None


def _as_number(value: Any) -> float | None:
    if isinstance(value, bool):
        return None
    try:
        number = float(value)
    except (TypeError, ValueError):
        return None
    return number if math.isfinite(number) else None


def _as_integer(value: Any) -> int | None:
    number = _as_number(value)
    if number is None or not number.is_integer():
        return None
    return int(number)


def _integer_if_whole(value: float | None) -> int | float | None:
    if value is None:
        return None
    return int(value) if value.is_integer() else value


def _as_text(value: Any) -> str | None:
    return str(value) if value is not None else None


def _is_sha256(value: Any) -> bool:
    text = _as_text(value) or ""
    return len(text) == 64 and all(
        character in "0123456789abcdefABCDEF" for character in text
    )


def _descending(value: Any) -> tuple[int, float]:
    number = _as_number(value)
    return (1, 0.0) if number is None else (0, -number)


def _ascending(value: Any) -> tuple[int, float]:
    number = _as_number(value)
    return (1, 0.0) if number is None else (0, number)


def _format_metric(value: Any) -> str:
    number = _as_number(value)
    return "—" if number is None else f"{number:.3f}"


def _format_integer(value: Any) -> str:
    number = _as_integer(value)
    return "—" if number is None else f"{number:,}"
