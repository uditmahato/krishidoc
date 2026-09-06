#!/usr/bin/env python3
"""Create deterministic, leakage-safe folds for consumed development evidence.

The canonical image manifest remains immutable.  This script joins source
annotations onto one source's manifest rows and writes a separate CSV sidecar.
Every ``group_id`` is assigned as one unit.  Missing critical metadata
quarantines the complete group; disagreements are retained and flagged instead
of being silently resolved.

These folds are for model development only.  Every output row is explicitly
``promotion_eligible=false`` and ``selection_independent=false``.  The source
policy must independently confirm those restrictions or the script fails.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import math
import os
import re
import tempfile
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path, PurePosixPath
from typing import Any, Iterable, Mapping, Sequence


SCRIPT_PATH = Path(__file__).resolve()
ML_ROOT = SCRIPT_PATH.parents[1]
DEFAULT_MANIFEST = ML_ROOT / "data" / "prepared" / "manifest_field_v2_1_sanitized.csv"
DEFAULT_ANNOTATIONS = ML_ROOT / "data" / "raw" / "farmer_chat_india" / "annotations.csv"
DEFAULT_POLICY = ML_ROOT / "datasets" / "source_evidence_policy_v1.json"
DEFAULT_OUTPUT = (
    ML_ROOT / "data" / "prepared" / "farmer_chat_india_development_folds_v1.csv"
)
DEFAULT_REPORT = (
    ML_ROOT / "data" / "prepared" / "farmer_chat_india_development_folds_v1.report.json"
)
DEFAULT_SOURCE_ID = "farmer_chat_india"
DEFAULT_SEED = 20260903
DEFAULT_FOLDS = 5

REQUIRED_MANIFEST_COLUMNS = frozenset(
    {
        "image_path",
        "crop",
        "condition_label",
        "validity_label",
        "split",
        "source_id",
        "group_id",
        "sha256",
    }
)
REQUIRED_ANNOTATION_COLUMNS = frozenset(
    {"image_file", "crop", "diagnosis", "country", "state"}
)
CRITICAL_METADATA_FIELDS = ("crop", "diagnosis", "country", "state")
FOLD_SCHEMA_VERSION = 1
ALGORITHM_ID = "grouped-marginal-multistart-greedy-v1"
DETERMINISTIC_RESTARTS = 32

# The dimensions are normalized by both their label count and label support.
# Values are part of the versioned algorithm contract and appear in the report.
DIMENSION_WEIGHTS = {
    "row_count": 8,
    "group_count": 2,
    "state_bucket": 4,
    "observed_crop": 4,
    "observed_diagnosis": 5,
    "task_role": 4,
}

SIDECAR_COLUMNS = (
    "fold_schema_version",
    "source_id",
    "image_path",
    "sha256",
    "group_id",
    "manifest_split",
    "development_fold",
    "fold_index",
    "evidence_role",
    "development_only",
    "promotion_eligible",
    "selection_independent",
    "task_role",
    "state_bucket",
    "raw_crops_json",
    "raw_diagnoses_json",
    "diagnosis_terms_json",
    "raw_states_json",
    "raw_countries_json",
    "raw_review_count",
    "metadata_status",
    "metadata_flags",
    "group_metadata_flags",
)


class DevelopmentFoldError(RuntimeError):
    """Raised when folds cannot be built without weakening the contract."""


@dataclass(frozen=True)
class AnnotationSummary:
    review_count: int
    crops: tuple[str, ...]
    diagnoses: tuple[str, ...]
    diagnosis_terms: tuple[str, ...]
    countries: tuple[str, ...]
    states: tuple[str, ...]
    flags: tuple[str, ...]
    quarantine: bool


@dataclass
class PreparedRow:
    manifest: dict[str, str]
    annotation: AnnotationSummary
    task_role: str
    state_bucket: str = ""
    group_flags: tuple[str, ...] = ()


@dataclass
class FoldGroup:
    group_id: str
    rows: list[PreparedRow]
    features: dict[str, Counter[str]]
    quarantine: bool


def _sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _read_bytes(path: Path, description: str) -> bytes:
    try:
        return path.read_bytes()
    except OSError as error:
        raise DevelopmentFoldError(
            f"cannot read {description} {path}: {error}"
        ) from error


def _parse_csv(
    payload: bytes, path: Path, required: frozenset[str]
) -> list[dict[str, str]]:
    try:
        text = payload.decode("utf-8-sig")
    except UnicodeDecodeError as error:
        raise DevelopmentFoldError(f"{path} is not valid UTF-8: {error}") from error
    with io.StringIO(text, newline="") as stream:
        reader = csv.DictReader(stream)
        if reader.fieldnames is None:
            raise DevelopmentFoldError(f"CSV is empty: {path}")
        fieldnames = list(reader.fieldnames)
        if len(fieldnames) != len(set(fieldnames)) or any(
            not value for value in fieldnames
        ):
            raise DevelopmentFoldError(f"CSV has duplicate or blank headers: {path}")
        missing = sorted(required.difference(fieldnames))
        if missing:
            raise DevelopmentFoldError(f"CSV {path} is missing columns: {missing}")
        rows: list[dict[str, str]] = []
        for row_number, raw in enumerate(reader, start=2):
            if None in raw or any(raw.get(column) is None for column in fieldnames):
                raise DevelopmentFoldError(f"malformed CSV row {row_number} in {path}")
            rows.append({column: str(raw[column]) for column in fieldnames})
    if not rows:
        raise DevelopmentFoldError(f"CSV has no data rows: {path}")
    return rows


def _stable_values(values: Iterable[str]) -> tuple[str, ...]:
    unique = {value.strip() for value in values if value.strip()}
    return tuple(sorted(unique, key=lambda value: (value.casefold(), value)))


def _normalized_label(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).casefold().strip()
    return " ".join(normalized.split())


def _diagnosis_terms(values: Iterable[str]) -> tuple[str, ...]:
    terms: set[str] = set()
    for value in values:
        for term in value.split(";"):
            normalized = _normalized_label(term)
            if normalized:
                terms.add(normalized)
    return tuple(sorted(terms))


def _json_array(values: Iterable[str]) -> str:
    return json.dumps(list(values), ensure_ascii=False, separators=(",", ":"))


def _normalize_relative_image_path(value: str, *, row_number: int) -> str:
    normalized = value.strip().replace("\\", "/")
    while normalized.startswith("./"):
        normalized = normalized[2:]
    pure = PurePosixPath(normalized)
    if (
        not normalized
        or pure.is_absolute()
        or re.match(r"^[A-Za-z]:/", normalized)
        or any(part in {"", ".", ".."} for part in pure.parts)
    ):
        raise DevelopmentFoldError(
            f"annotation row {row_number} has unsafe image_file {value!r}"
        )
    return pure.as_posix()


def _manifest_join_key(image_path: str, annotation_keys: set[str]) -> str | None:
    normalized = image_path.strip().replace("\\", "/")
    matches = [
        key
        for key in annotation_keys
        if normalized == key or normalized.endswith("/" + key)
    ]
    if not matches:
        return None
    if len(matches) != 1:
        raise DevelopmentFoldError(
            f"manifest image_path {image_path!r} has multiple annotation path matches"
        )
    return matches[0]


def _summarize_reviews(reviews: Sequence[Mapping[str, str]]) -> AnnotationSummary:
    if not reviews:
        return AnnotationSummary(0, (), (), (), (), (), ("missing_annotation",), True)

    flags: set[str] = set()
    value_sets: dict[str, tuple[str, ...]] = {}
    quarantine = False
    for field in CRITICAL_METADATA_FIELDS:
        raw_values = [str(review[field]) for review in reviews]
        values = _stable_values(raw_values)
        value_sets[field] = values
        if any(not value.strip() for value in raw_values):
            flags.add(f"missing_{field}")
            quarantine = True
        if not values:
            flags.add(f"missing_{field}")
            quarantine = True
        if len(values) > 1:
            flags.add(f"conflicting_{field}_reviews")
    if len(reviews) > 1:
        flags.add("multiple_reviews")

    diagnoses = value_sets["diagnosis"]
    return AnnotationSummary(
        review_count=len(reviews),
        crops=value_sets["crop"],
        diagnoses=diagnoses,
        diagnosis_terms=_diagnosis_terms(diagnoses),
        countries=value_sets["country"],
        states=value_sets["state"],
        flags=tuple(sorted(flags)),
        quarantine=quarantine,
    )


def _task_role(row: Mapping[str, str]) -> str:
    validity = row["validity_label"].strip()
    condition = row["condition_label"].strip()
    if validity == "usable_target_leaf":
        return (
            "target_open_set"
            if condition.endswith("_other_unknown")
            else "target_known_condition"
        )
    return validity or "missing_validity"


def _load_policy(payload: bytes, source_id: str) -> dict[str, Any]:
    try:
        policy = json.loads(payload.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise DevelopmentFoldError(f"cannot parse source policy: {error}") from error
    if not isinstance(policy, Mapping) or policy.get("schema_version") != 1:
        raise DevelopmentFoldError(
            "source policy must be an object with schema_version 1"
        )
    aliases = policy.get("aliases", {})
    canonical = (
        aliases.get(source_id, source_id) if isinstance(aliases, Mapping) else source_id
    )
    sources = policy.get("sources")
    entry = sources.get(canonical) if isinstance(sources, Mapping) else None
    if not isinstance(entry, Mapping):
        raise DevelopmentFoldError(f"source {source_id!r} is absent from source policy")
    if entry.get("promotion_eligible") is not False:
        raise DevelopmentFoldError("source policy must set promotion_eligible to false")
    if entry.get("selection_independent") is not False:
        raise DevelopmentFoldError(
            "source policy must set selection_independent to false"
        )
    if entry.get("evidence_role") != "external_development":
        raise DevelopmentFoldError(
            "source policy must set evidence_role to 'external_development'"
        )
    return {"canonical_source_id": canonical, "entry": dict(entry)}


def _validate_manifest_rows(
    rows: Sequence[Mapping[str, str]],
    source_id: str,
    *,
    all_manifest_rows: Sequence[Mapping[str, str]],
) -> None:
    seen_paths: set[str] = set()
    group_by_sha: dict[str, set[str]] = defaultdict(set)
    for row_number, row in enumerate(rows, start=2):
        for field in REQUIRED_MANIFEST_COLUMNS:
            if not str(row[field]).strip():
                raise DevelopmentFoldError(
                    f"manifest row {row_number} has blank required field {field!r}"
                )
        if row["source_id"].strip() != source_id:
            raise DevelopmentFoldError(
                "internal error: wrong source survived filtering"
            )
        if row["split"].strip() != "external_test":
            raise DevelopmentFoldError(
                f"consumed source row {row_number} is not locked to external_test"
            )
        locked = row.get("source_locked_split", "").strip()
        if locked and locked != "external_test":
            raise DevelopmentFoldError(
                f"manifest row {row_number} has incompatible source_locked_split {locked!r}"
            )
        path = row["image_path"].strip().replace("\\", "/")
        if path in seen_paths:
            raise DevelopmentFoldError(
                f"duplicate source image_path in manifest: {path}"
            )
        seen_paths.add(path)
        digest = row["sha256"].strip().casefold()
        if len(digest) != 64 or any(ch not in "0123456789abcdef" for ch in digest):
            raise DevelopmentFoldError(
                f"manifest row {row_number} has invalid sha256 {row['sha256']!r}"
            )
        group_by_sha[digest].add(row["group_id"].strip())
    leaked = {
        digest: groups for digest, groups in group_by_sha.items() if len(groups) > 1
    }
    if leaked:
        digest, groups = sorted(leaked.items())[0]
        raise DevelopmentFoldError(
            f"exact SHA family {digest} spans group_ids {sorted(groups)}; repair manifest first"
        )

    selected_digests = set(group_by_sha)
    cross_source: dict[str, set[str]] = defaultdict(set)
    for row in all_manifest_rows:
        digest = str(row.get("sha256", "")).strip().casefold()
        if (
            digest in selected_digests
            and str(row.get("source_id", "")).strip() != source_id
        ):
            cross_source[digest].add(str(row.get("source_id", "")).strip())
    if cross_source:
        digest, sources = sorted(cross_source.items())[0]
        raise DevelopmentFoldError(
            f"selected-source SHA family {digest} also occurs in sources {sorted(sources)}; "
            "repair the canonical manifest before development folding"
        )


def _state_buckets(
    rows: Sequence[PreparedRow],
    folds: int,
    quarantined_group_ids: set[str],
) -> dict[str, str]:
    groups_by_state: dict[str, set[str]] = defaultdict(set)
    for row in rows:
        if (
            row.annotation.quarantine
            or row.manifest["group_id"].strip() in quarantined_group_ids
        ):
            continue
        values = {_normalized_label(value) for value in row.annotation.states}
        if len(values) == 1:
            groups_by_state[next(iter(values))].add(row.manifest["group_id"].strip())
    return {
        state: state if len(groups) >= folds else "__rare_state__"
        for state, groups in groups_by_state.items()
    }


def _prepare_groups(
    manifest_rows: Sequence[dict[str, str]],
    annotation_rows: Sequence[dict[str, str]],
    *,
    folds: int,
) -> tuple[list[FoldGroup], list[dict[str, Any]], Counter[str]]:
    reviews_by_key: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row_number, row in enumerate(annotation_rows, start=2):
        key = _normalize_relative_image_path(row["image_file"], row_number=row_number)
        reviews_by_key[key].append(row)

    annotation_keys = set(reviews_by_key)
    joined_keys: set[str] = set()
    prepared: list[PreparedRow] = []
    for manifest in manifest_rows:
        key = _manifest_join_key(manifest["image_path"], annotation_keys)
        if key is not None:
            joined_keys.add(key)
        summary = _summarize_reviews(reviews_by_key[key] if key is not None else [])
        prepared.append(
            PreparedRow(
                manifest=manifest,
                annotation=summary,
                task_role=_task_role(manifest),
            )
        )

    quarantined_group_ids = {
        row.manifest["group_id"].strip()
        for row in prepared
        if row.annotation.quarantine
    }
    bucket_by_state = _state_buckets(prepared, folds, quarantined_group_ids)
    for row in prepared:
        normalized_states = {
            _normalized_label(value) for value in row.annotation.states if value.strip()
        }
        if row.manifest["group_id"].strip() in quarantined_group_ids:
            row.state_bucket = "__quarantine__"
        elif len(normalized_states) != 1:
            row.state_bucket = "__mixed_state__"
        else:
            row.state_bucket = bucket_by_state[next(iter(normalized_states))]

    rows_by_group: dict[str, list[PreparedRow]] = defaultdict(list)
    for row in prepared:
        rows_by_group[row.manifest["group_id"].strip()].append(row)

    groups: list[FoldGroup] = []
    flag_counts: Counter[str] = Counter()
    for group_id, group_rows in sorted(rows_by_group.items()):
        group_flags: set[str] = set()
        for field, accessor in (
            ("crop", lambda row: row.annotation.crops),
            # Compare complete expert observations here. A single legitimate
            # multi-label value such as ``Mites; Thrips`` is not disagreement.
            ("diagnosis", lambda row: row.annotation.diagnoses),
            ("state", lambda row: row.annotation.states),
            ("country", lambda row: row.annotation.countries),
            ("task_role", lambda row: (row.task_role,)),
        ):
            values = {
                _normalized_label(value)
                for row in group_rows
                for value in accessor(row)
                if value.strip()
            }
            if len(values) > 1:
                group_flags.add(f"conflicting_{field}_within_group")
        for row in group_rows:
            row.group_flags = tuple(sorted(group_flags))
            flag_counts.update(row.annotation.flags)
            flag_counts.update(row.group_flags)

        quarantine = any(row.annotation.quarantine for row in group_rows)
        features: dict[str, Counter[str]] = {
            "state_bucket": Counter(),
            "observed_crop": Counter(),
            "observed_diagnosis": Counter(),
            "task_role": Counter(),
        }
        if not quarantine:
            for row in group_rows:
                features["state_bucket"][row.state_bucket] += 1
                for crop in {
                    _normalized_label(value) for value in row.annotation.crops
                }:
                    features["observed_crop"][crop] += 1
                for diagnosis in row.annotation.diagnosis_terms:
                    features["observed_diagnosis"][diagnosis] += 1
                features["task_role"][row.task_role] += 1
        groups.append(FoldGroup(group_id, group_rows, features, quarantine))

    orphaned: list[dict[str, Any]] = []
    for key in sorted(annotation_keys.difference(joined_keys)):
        summary = _summarize_reviews(reviews_by_key[key])
        orphaned.append(
            {
                "image_file": key,
                "raw_review_count": summary.review_count,
                "raw_crops": list(summary.crops),
                "raw_diagnoses": list(summary.diagnoses),
                "raw_states": list(summary.states),
                "raw_countries": list(summary.countries),
                "metadata_flags": list(summary.flags),
                "reason": "annotation_image_absent_from_canonical_manifest",
            }
        )
    return groups, orphaned, flag_counts


def _feature_totals(groups: Sequence[FoldGroup]) -> dict[str, Counter[str]]:
    totals = {
        "state_bucket": Counter(),
        "observed_crop": Counter(),
        "observed_diagnosis": Counter(),
        "task_role": Counter(),
    }
    for group in groups:
        if group.quarantine:
            continue
        for dimension, counts in group.features.items():
            totals[dimension].update(counts)
    return totals


def _stable_hash(seed: int, *values: object) -> str:
    payload = "|".join([str(seed), *(str(value) for value in values)])
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def _group_order_key(
    group: FoldGroup, totals: Mapping[str, Counter[str]], seed: int
) -> tuple[Any, ...]:
    rarity: list[Fraction] = []
    for dimension, counts in group.features.items():
        for label, count in counts.items():
            rarity.append(Fraction(count, totals[dimension][label]))
    return (
        -max(rarity, default=Fraction(0)),
        -sum(rarity, Fraction(0)),
        -len(group.rows),
        _stable_hash(seed, group.group_id),
        group.group_id,
    )


def _normalized_delta(current: int, addition: int, total: int, folds: int) -> Fraction:
    denominator = max(total, folds) ** 2
    before = (folds * current - total) ** 2
    after = (folds * (current + addition) - total) ** 2
    return Fraction(after - before, denominator)


def assign_groups(
    groups: Sequence[FoldGroup], *, folds: int, seed: int
) -> tuple[dict[str, int], dict[str, Any]]:
    """Greedily balance marginal distributions while keeping groups whole."""

    if folds < 2:
        raise DevelopmentFoldError("fold count must be at least 2")
    assignable = [group for group in groups if not group.quarantine]
    if len(assignable) < folds:
        raise DevelopmentFoldError(
            f"only {len(assignable)} assignable groups are available for {folds} folds"
        )
    totals = _feature_totals(assignable)
    total_rows = sum(len(group.rows) for group in assignable)
    total_groups = len(assignable)
    fold_rows = [0] * folds
    fold_groups = [0] * folds
    fold_features = [
        {dimension: Counter() for dimension in totals} for _ in range(folds)
    ]
    assignment: dict[str, int] = {}

    for group in sorted(
        assignable, key=lambda value: _group_order_key(value, totals, seed)
    ):
        scored: list[tuple[Fraction, int, int, str, int]] = []
        for fold in range(folds):
            score = Fraction(DIMENSION_WEIGHTS["row_count"]) * _normalized_delta(
                fold_rows[fold], len(group.rows), total_rows, folds
            )
            score += Fraction(DIMENSION_WEIGHTS["group_count"]) * _normalized_delta(
                fold_groups[fold], 1, total_groups, folds
            )
            for dimension, group_counts in group.features.items():
                label_count = max(len(totals[dimension]), 1)
                dimension_weight = Fraction(DIMENSION_WEIGHTS[dimension], label_count)
                for label, addition in group_counts.items():
                    score += dimension_weight * _normalized_delta(
                        fold_features[fold][dimension][label],
                        addition,
                        totals[dimension][label],
                        folds,
                    )
            scored.append(
                (
                    score,
                    fold_rows[fold] + len(group.rows),
                    fold_groups[fold] + 1,
                    _stable_hash(seed, group.group_id, fold + 1),
                    fold,
                )
            )
        chosen = min(scored)[-1]
        assignment[group.group_id] = chosen
        fold_rows[chosen] += len(group.rows)
        fold_groups[chosen] += 1
        for dimension, counts in group.features.items():
            fold_features[chosen][dimension].update(counts)

    diagnostics = {
        "fold_rows": fold_rows,
        "fold_groups": fold_groups,
        "feature_totals": totals,
        "fold_features": fold_features,
    }
    return assignment, diagnostics


def _assignment_objective(diagnostics: Mapping[str, Any], folds: int) -> Fraction:
    """Return the exact normalized objective used to compare restarts."""

    fold_rows = diagnostics["fold_rows"]
    fold_groups = diagnostics["fold_groups"]
    total_rows = sum(fold_rows)
    total_groups = sum(fold_groups)

    def squared_cost(counts: Sequence[int], total: int) -> Fraction:
        denominator = max(total, folds) ** 2
        return sum(
            (Fraction((folds * count - total) ** 2, denominator) for count in counts),
            Fraction(0),
        )

    score = Fraction(DIMENSION_WEIGHTS["row_count"]) * squared_cost(
        fold_rows, total_rows
    )
    score += Fraction(DIMENSION_WEIGHTS["group_count"]) * squared_cost(
        fold_groups, total_groups
    )
    totals = diagnostics["feature_totals"]
    by_fold = diagnostics["fold_features"]
    for dimension, labels in totals.items():
        dimension_weight = Fraction(DIMENSION_WEIGHTS[dimension], max(len(labels), 1))
        for label, total in labels.items():
            counts = [int(fold[dimension][label]) for fold in by_fold]
            score += dimension_weight * squared_cost(counts, int(total))
    return score


def assign_groups_multistart(
    groups: Sequence[FoldGroup],
    *,
    folds: int,
    seed: int,
    restarts: int = DETERMINISTIC_RESTARTS,
) -> tuple[dict[str, int], dict[str, Any], dict[str, Any]]:
    """Select the best exact objective from deterministic greedy restarts."""

    if restarts < 1:
        raise DevelopmentFoldError("deterministic restart count must be positive")
    candidates: list[tuple[Any, ...]] = []
    for restart_index in range(restarts):
        restart_seed = (
            seed
            if restart_index == 0
            else int(_stable_hash(seed, "restart", restart_index)[:16], 16)
        )
        assignment, diagnostics = assign_groups(groups, folds=folds, seed=restart_seed)
        row_range = max(diagnostics["fold_rows"]) - min(diagnostics["fold_rows"])
        group_range = max(diagnostics["fold_groups"]) - min(diagnostics["fold_groups"])
        candidates.append(
            (
                _assignment_objective(diagnostics, folds),
                row_range,
                group_range,
                restart_index,
                restart_seed,
                assignment,
                diagnostics,
            )
        )
    selected = min(candidates, key=lambda value: value[:4])
    objective, _, _, restart_index, restart_seed, assignment, diagnostics = selected
    selection = {
        "deterministic_restarts": restarts,
        "selected_restart_index": restart_index,
        "selected_restart_seed": restart_seed,
        "objective_fraction": f"{objective.numerator}/{objective.denominator}",
        "objective_decimal": round(float(objective), 12),
    }
    return assignment, diagnostics, selection


def _rational_amount(numerator: int, denominator: int) -> dict[str, Any]:
    divisor = math.gcd(numerator, denominator)
    reduced_numerator = numerator // divisor
    reduced_denominator = denominator // divisor
    return {
        "fraction": (
            str(reduced_numerator)
            if reduced_denominator == 1
            else f"{reduced_numerator}/{reduced_denominator}"
        ),
        "decimal": round(numerator / denominator, 6),
    }


def _distribution_report(
    totals: Mapping[str, Counter[str]],
    by_fold: Sequence[Mapping[str, Counter[str]]],
    folds: int,
) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for dimension in sorted(totals):
        labels: dict[str, Any] = {}
        ranges: list[int] = []
        for label, total in sorted(totals[dimension].items()):
            counts = [int(fold[dimension][label]) for fold in by_fold]
            deviation_numerator = max(abs(folds * count - total) for count in counts)
            label_range = max(counts) - min(counts)
            ranges.append(label_range)
            labels[label] = {
                "total_memberships": int(total),
                "ideal_per_fold": _rational_amount(int(total), folds),
                "fold_counts": {
                    f"dev_fold_{index + 1}": count for index, count in enumerate(counts)
                },
                "min": min(counts),
                "max": max(counts),
                "range": label_range,
                "max_absolute_deviation": _rational_amount(deviation_numerator, folds),
                "support_smaller_than_fold_count": total < folds,
            }
        result[dimension] = {
            "unit": "row-label membership",
            "label_count": len(labels),
            "total_memberships": int(sum(totals[dimension].values())),
            "imbalance": {
                "max_label_range": max(ranges, default=0),
                "sum_label_ranges": sum(ranges),
                "labels_with_range_gt_one": sum(value > 1 for value in ranges),
            },
            "labels": labels,
        }
    return result


def _serialize_sidecar(
    groups: Sequence[FoldGroup], assignment: Mapping[str, int]
) -> bytes:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(
        output,
        fieldnames=SIDECAR_COLUMNS,
        lineterminator="\n",
        extrasaction="raise",
    )
    writer.writeheader()
    ordered_rows = sorted(
        (row for group in groups for row in group.rows),
        key=lambda row: (
            row.manifest["group_id"],
            row.manifest["image_path"].replace("\\", "/"),
            row.manifest["sha256"],
        ),
    )
    quarantined_groups = {group.group_id for group in groups if group.quarantine}
    for row in ordered_rows:
        group_id = row.manifest["group_id"].strip()
        is_quarantined = group_id in quarantined_groups
        fold = None if is_quarantined else assignment[group_id]
        flags = tuple(sorted(set(row.annotation.flags).union(row.group_flags)))
        status = "quarantined" if is_quarantined else ("flagged" if flags else "ok")
        writer.writerow(
            {
                "fold_schema_version": str(FOLD_SCHEMA_VERSION),
                "source_id": row.manifest["source_id"].strip(),
                "image_path": row.manifest["image_path"].strip().replace("\\", "/"),
                "sha256": row.manifest["sha256"].strip().casefold(),
                "group_id": group_id,
                "manifest_split": row.manifest["split"].strip(),
                "development_fold": (
                    "quarantine" if fold is None else f"dev_fold_{fold + 1}"
                ),
                "fold_index": "" if fold is None else str(fold + 1),
                "evidence_role": "external_development",
                "development_only": "true",
                "promotion_eligible": "false",
                "selection_independent": "false",
                "task_role": row.task_role,
                "state_bucket": row.state_bucket,
                "raw_crops_json": _json_array(row.annotation.crops),
                "raw_diagnoses_json": _json_array(row.annotation.diagnoses),
                "diagnosis_terms_json": _json_array(row.annotation.diagnosis_terms),
                "raw_states_json": _json_array(row.annotation.states),
                "raw_countries_json": _json_array(row.annotation.countries),
                "raw_review_count": str(row.annotation.review_count),
                "metadata_status": status,
                "metadata_flags": ";".join(flags),
                "group_metadata_flags": ";".join(row.group_flags),
            }
        )
    return output.getvalue().encode("utf-8")


def _atomic_write_pair(
    output_path: Path,
    output_bytes: bytes,
    report_path: Path,
    report_bytes: bytes,
) -> None:
    output_path.parent.mkdir(parents=True, exist_ok=True)
    report_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_paths: list[Path] = []
    try:
        for destination, payload in (
            (output_path, output_bytes),
            (report_path, report_bytes),
        ):
            descriptor, temporary_name = tempfile.mkstemp(
                dir=destination.parent,
                prefix=f".{destination.name}.",
                suffix=".tmp",
            )
            temporary = Path(temporary_name)
            temporary_paths.append(temporary)
            with os.fdopen(descriptor, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
        os.replace(temporary_paths[0], output_path)
        temporary_paths.pop(0)
        os.replace(temporary_paths[0], report_path)
        temporary_paths.pop(0)
    finally:
        for temporary in temporary_paths:
            temporary.unlink(missing_ok=True)


def build_development_folds(
    manifest_path: Path,
    annotations_path: Path,
    source_policy_path: Path,
    output_path: Path,
    report_path: Path,
    *,
    source_id: str = DEFAULT_SOURCE_ID,
    folds: int = DEFAULT_FOLDS,
    seed: int = DEFAULT_SEED,
) -> dict[str, Any]:
    """Build sidecar and deterministic report, returning the report payload."""

    resolved_inputs = {
        manifest_path.resolve(),
        annotations_path.resolve(),
        source_policy_path.resolve(),
    }
    if (
        output_path.resolve() in resolved_inputs
        or report_path.resolve() in resolved_inputs
    ):
        raise DevelopmentFoldError("outputs must not overwrite an input")
    if output_path.resolve() == report_path.resolve():
        raise DevelopmentFoldError("sidecar and report paths must differ")

    manifest_bytes = _read_bytes(manifest_path, "canonical manifest")
    annotations_bytes = _read_bytes(annotations_path, "source annotations")
    policy_bytes = _read_bytes(source_policy_path, "source policy")
    policy = _load_policy(policy_bytes, source_id)
    all_manifest_rows = _parse_csv(
        manifest_bytes, manifest_path, REQUIRED_MANIFEST_COLUMNS
    )
    manifest_rows = [
        row for row in all_manifest_rows if row["source_id"].strip() == source_id
    ]
    if not manifest_rows:
        raise DevelopmentFoldError(f"manifest has no rows for source {source_id!r}")
    _validate_manifest_rows(
        manifest_rows,
        source_id,
        all_manifest_rows=all_manifest_rows,
    )
    annotation_rows = _parse_csv(
        annotations_bytes, annotations_path, REQUIRED_ANNOTATION_COLUMNS
    )

    groups, orphaned_annotations, flag_counts = _prepare_groups(
        manifest_rows, annotation_rows, folds=folds
    )
    assignment, diagnostics, restart_selection = assign_groups_multistart(
        groups, folds=folds, seed=seed
    )
    sidecar_bytes = _serialize_sidecar(groups, assignment)

    quarantined_groups = [group for group in groups if group.quarantine]
    assigned_groups = [group for group in groups if not group.quarantine]
    flagged_rows = [
        row
        for group in assigned_groups
        for row in group.rows
        if row.annotation.flags or row.group_flags
    ]
    ok_rows = [
        row
        for group in assigned_groups
        for row in group.rows
        if not row.annotation.flags and not row.group_flags
    ]
    flagged_groups = [
        group
        for group in assigned_groups
        if any(row.annotation.flags or row.group_flags for row in group.rows)
    ]
    flag_group_counts: Counter[str] = Counter()
    for group in groups:
        flag_group_counts.update(
            {
                flag
                for row in group.rows
                for flag in (*row.annotation.flags, *row.group_flags)
            }
        )
    fold_rows = diagnostics["fold_rows"]
    fold_groups = diagnostics["fold_groups"]
    row_total = sum(fold_rows)
    group_total = sum(fold_groups)
    report: dict[str, Any] = {
        "schema_version": FOLD_SCHEMA_VERSION,
        "status": "development_only",
        "promotion_eligible": False,
        "selection_independent": False,
        "evidence_role": "external_development",
        "source_id": source_id,
        "canonical_source_id": policy["canonical_source_id"],
        "fold_count": folds,
        "fold_names": [f"dev_fold_{index + 1}" for index in range(folds)],
        "seed": seed,
        "algorithm": {
            "id": ALGORITHM_ID,
            "group_unit": "group_id",
            "rare_state_rule": "states with support in fewer than fold_count groups map to __rare_state__",
            "stratification_dimensions": [
                "state_bucket",
                "observed_crop",
                "observed_diagnosis",
                "task_role",
            ],
            "dimension_weights": DIMENSION_WEIGHTS,
            "restart_selection": restart_selection,
            "diagnosis_tokenization": "trimmed semicolon-separated marginal labels; Unicode NFKC + casefold",
            "conflict_policy": (
                "retain and flag disagreements; quarantine the whole group only when "
                "a critical annotation field is missing or no annotation is joined"
            ),
        },
        "inputs": {
            "canonical_manifest_sha256": _sha256_bytes(manifest_bytes),
            "annotations_sha256": _sha256_bytes(annotations_bytes),
            "source_policy_sha256": _sha256_bytes(policy_bytes),
            "source_policy_id": json.loads(policy_bytes.decode("utf-8-sig")).get(
                "policy_id", ""
            ),
        },
        "output": {
            "sidecar_sha256": _sha256_bytes(sidecar_bytes),
            "sidecar_rows": len(manifest_rows),
            "sidecar_columns": list(SIDECAR_COLUMNS),
        },
        "summary": {
            "manifest_rows": len(manifest_rows),
            "manifest_groups": len(groups),
            "assigned_rows": row_total,
            "assigned_groups": group_total,
            "quarantined_rows": sum(len(group.rows) for group in quarantined_groups),
            "quarantined_groups": len(quarantined_groups),
            "metadata_status_rows": {
                "ok": len(ok_rows),
                "flagged": len(flagged_rows),
                "quarantined": sum(len(group.rows) for group in quarantined_groups),
            },
            "metadata_status_groups": {
                "ok": len(assigned_groups) - len(flagged_groups),
                "flagged": len(flagged_groups),
                "quarantined": len(quarantined_groups),
            },
            "annotation_rows": len(annotation_rows),
            "joined_annotation_rows": sum(
                row.annotation.review_count for group in groups for row in group.rows
            ),
            "annotation_images": len(
                {
                    _normalize_relative_image_path(row["image_file"], row_number=index)
                    for index, row in enumerate(annotation_rows, start=2)
                }
            ),
            "orphaned_annotation_images": len(orphaned_annotations),
            "orphaned_annotation_rows": sum(
                int(item["raw_review_count"]) for item in orphaned_annotations
            ),
            "metadata_flag_row_occurrences": dict(sorted(flag_counts.items())),
            "metadata_flag_group_occurrences": dict(sorted(flag_group_counts.items())),
        },
        "folds": {
            f"dev_fold_{index + 1}": {
                "fold_index": index + 1,
                "rows": fold_rows[index],
                "groups": fold_groups[index],
                "development_only": True,
                "promotion_eligible": False,
            }
            for index in range(folds)
        },
        "row_imbalance": {
            "ideal_per_fold": _rational_amount(row_total, folds),
            "min": min(fold_rows),
            "max": max(fold_rows),
            "range": max(fold_rows) - min(fold_rows),
            "max_absolute_deviation": _rational_amount(
                max(abs(folds * count - row_total) for count in fold_rows), folds
            ),
        },
        "group_imbalance": {
            "ideal_per_fold": _rational_amount(group_total, folds),
            "min": min(fold_groups),
            "max": max(fold_groups),
            "range": max(fold_groups) - min(fold_groups),
            "max_absolute_deviation": _rational_amount(
                max(abs(folds * count - group_total) for count in fold_groups), folds
            ),
        },
        "marginal_distributions": _distribution_report(
            diagnostics["feature_totals"], diagnostics["fold_features"], folds
        ),
        "quarantine": [
            {
                "group_id": group.group_id,
                "image_paths": sorted(row.manifest["image_path"] for row in group.rows),
                "flags": sorted(
                    {
                        flag
                        for row in group.rows
                        for flag in (*row.annotation.flags, *row.group_flags)
                    }
                ),
            }
            for group in quarantined_groups
        ],
        "orphaned_annotations": orphaned_annotations,
        "leakage_checks": {
            "group_id_assigned_to_one_fold": len(assignment) == len(assigned_groups),
            "exact_sha_family_confined_to_one_group": True,
            "canonical_manifest_mutated": False,
        },
        "limitations": [
            "The source was already inspected and used in model decisions, so no fold is promotion evidence.",
            "State is registered farmer location, not verified image geolocation.",
            "Rare labels and indivisible multi-row groups make perfect stratification mathematically impossible.",
            "Conflicting expert reviews are preserved as observed labels; this tool performs no visual adjudication.",
        ],
    }
    report_bytes = (json.dumps(report, indent=2, sort_keys=True) + "\n").encode("utf-8")
    _atomic_write_pair(output_path, sidecar_bytes, report_path, report_bytes)
    return report


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--annotations", type=Path, default=DEFAULT_ANNOTATIONS)
    parser.add_argument("--source-policy", type=Path, default=DEFAULT_POLICY)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument("--source-id", default=DEFAULT_SOURCE_ID)
    parser.add_argument("--folds", type=int, default=DEFAULT_FOLDS)
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    report = build_development_folds(
        args.manifest,
        args.annotations,
        args.source_policy,
        args.output,
        args.report,
        source_id=args.source_id,
        folds=args.folds,
        seed=args.seed,
    )
    summary = report["summary"]
    print(
        json.dumps(
            {
                "status": report["status"],
                "sidecar_sha256": report["output"]["sidecar_sha256"],
                "assigned_rows": summary["assigned_rows"],
                "assigned_groups": summary["assigned_groups"],
                "quarantined_rows": summary["quarantined_rows"],
                "fold_rows": {
                    name: values["rows"] for name, values in report["folds"].items()
                },
                "row_range": report["row_imbalance"]["range"],
                "promotion_eligible": report["promotion_eligible"],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":  # pragma: no cover
    raise SystemExit(main())
