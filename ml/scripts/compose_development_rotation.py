#!/usr/bin/env python3
"""Compose a provenance-bound Digital Green diagnostic development rotation."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
import tempfile
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence

SOURCE_ID = "farmer_chat_india"
ROTATED_SOURCE_ID = "farmer_chat_india_development_v1"
FOLD_COUNT = 5
HEX = frozenset("0123456789abcdef")
MANIFEST_REQUIRED = frozenset({"image_path", "crop", "condition_label", "validity_label", "split", "source_id", "group_id", "sha256", "phash", "source_locked_split"})
SIDECAR_REQUIRED = frozenset({"fold_schema_version", "source_id", "image_path", "sha256", "group_id", "manifest_split", "development_fold", "fold_index", "evidence_role", "development_only", "promotion_eligible", "selection_independent", "metadata_status", "metadata_flags", "group_metadata_flags"})


class DevelopmentRotationError(RuntimeError):
    """The rotation inputs or result violate the development-only contract."""


def _sha(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def _read_bytes(path: Path, label: str) -> bytes:
    try:
        return path.read_bytes()
    except OSError as error:
        raise DevelopmentRotationError(f"cannot read {label} {path}: {error}") from error


def _read_json(path: Path, label: str) -> tuple[bytes, dict[str, Any]]:
    payload = _read_bytes(path, label)
    try:
        value = json.loads(payload.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise DevelopmentRotationError(f"invalid {label} JSON {path}: {error}") from error
    if not isinstance(value, dict):
        raise DevelopmentRotationError(f"{label} must be a JSON object")
    return payload, value


def _read_csv(path: Path, required: frozenset[str]) -> tuple[bytes, list[str], list[dict[str, str]]]:
    payload = _read_bytes(path, "CSV")
    try:
        text = payload.decode("utf-8-sig")
    except UnicodeDecodeError as error:
        raise DevelopmentRotationError(f"CSV is not UTF-8: {path}") from error
    reader = csv.DictReader(io.StringIO(text, newline=""))
    if reader.fieldnames is None:
        raise DevelopmentRotationError(f"CSV is empty: {path}")
    fields = list(reader.fieldnames)
    if len(fields) != len(set(fields)) or any(not field for field in fields):
        raise DevelopmentRotationError(f"CSV has duplicate or blank headers: {path}")
    missing = sorted(required.difference(fields))
    if missing:
        raise DevelopmentRotationError(f"CSV {path} is missing columns: {missing}")
    rows: list[dict[str, str]] = []
    for number, raw in enumerate(reader, start=2):
        if None in raw or any(raw.get(field) is None for field in fields):
            raise DevelopmentRotationError(f"malformed CSV row {number} in {path}")
        row = {field: str(raw[field]) for field in fields}
        rows.append(row)
    if not rows:
        raise DevelopmentRotationError(f"CSV has no rows: {path}")
    return payload, fields, rows


def _exact_bool(value: object, expected: bool, context: str) -> None:
    if value is not expected:
        raise DevelopmentRotationError(f"{context} must be canonical JSON boolean {expected}")


def _exact_csv_bool(value: str, expected: bool, context: str) -> None:
    canonical = "true" if expected else "false"
    if value.strip() != canonical:
        raise DevelopmentRotationError(f"{context} must equal canonical lowercase {canonical}")


def _valid_hex(value: str, length: int) -> bool:
    return len(value) == length and all(character in HEX for character in value)


def _key(row: Mapping[str, str]) -> tuple[str, str, str]:
    return (row["image_path"].strip().replace("\\", "/"), row["sha256"].strip().casefold(), row["group_id"].strip())


def _resolve_distinct_paths(paths: Sequence[Path]) -> None:
    resolved = [path.resolve() for path in paths]
    if len(set(resolved)) != len(resolved):
        raise DevelopmentRotationError("input/output paths must all be distinct")


def _validate_report(report: Mapping[str, Any], manifest_sha: str, sidecar_sha: str, policy_sha: str) -> None:
    if report.get("schema_version") != 1 or report.get("fold_count") != FOLD_COUNT:
        raise DevelopmentRotationError("fold report must be schema version 1 with five folds")
    if report.get("status") != "development_only" or report.get("evidence_role") != "external_development":
        raise DevelopmentRotationError("fold report is not external-development-only evidence")
    _exact_bool(report.get("promotion_eligible"), False, "fold report promotion_eligible")
    _exact_bool(report.get("selection_independent"), False, "fold report selection_independent")
    inputs, output = report.get("inputs"), report.get("output")
    if not isinstance(inputs, Mapping) or not isinstance(output, Mapping):
        raise DevelopmentRotationError("fold report lacks input/output identities")
    if inputs.get("canonical_manifest_sha256") != manifest_sha:
        raise DevelopmentRotationError("fold report canonical manifest hash does not match")
    if inputs.get("source_policy_sha256") != policy_sha:
        raise DevelopmentRotationError("fold report evidence policy hash does not match")
    if output.get("sidecar_sha256") != sidecar_sha:
        raise DevelopmentRotationError("fold report sidecar hash does not match")


def _validate_policy(policy: Mapping[str, Any]) -> None:
    sources = policy.get("sources")
    if policy.get("schema_version") != 1 or not isinstance(sources, Mapping) or not isinstance(sources.get(SOURCE_ID), Mapping):
        raise DevelopmentRotationError("source policy is missing its canonical Digital Green entry")
    entry = sources[SOURCE_ID]
    if entry.get("evidence_role") != "external_development":
        raise DevelopmentRotationError("source policy role must be external_development")
    _exact_bool(entry.get("promotion_eligible"), False, "source policy promotion_eligible")
    _exact_bool(entry.get("selection_independent"), False, "source policy selection_independent")


class _BKTree:
    def __init__(self) -> None:
        self.root: tuple[int, dict[int, Any]] | None = None

    def add(self, value: int) -> None:
        if self.root is None:
            self.root = (value, {})
            return
        node = self.root
        while True:
            distance = (value ^ node[0]).bit_count()
            child = node[1].get(distance)
            if child is None:
                node[1][distance] = (value, {})
                return
            node = child

    def nearby(self, value: int, maximum: int) -> list[int]:
        found: list[int] = []
        pending = [self.root] if self.root else []
        while pending:
            node = pending.pop()
            distance = (value ^ node[0]).bit_count()
            if distance <= maximum:
                found.append(node[0])
            pending.extend(child for edge, child in node[1].items() if distance - maximum <= edge <= distance + maximum)
        return found


def _assert_no_leakage(rows: Sequence[Mapping[str, str]], phash_distance: int) -> None:
    if not 0 <= phash_distance <= 64:
        raise DevelopmentRotationError("pHash distance must be between 0 and 64")
    groups: dict[str, set[str]] = defaultdict(set)
    shas: dict[str, set[str]] = defaultdict(set)
    phashes: dict[int, set[str]] = defaultdict(set)
    for number, row in enumerate(rows, start=2):
        group, digest, perceptual, split = row["group_id"].strip(), row["sha256"].strip().casefold(), row["phash"].strip().casefold(), row["split"].strip()
        if not group or not split or not _valid_hex(digest, 64) or not _valid_hex(perceptual, 16):
            raise DevelopmentRotationError(f"output row {number} has malformed identity metadata")
        groups[group].add(split)
        shas[digest].add(split)
        phashes[int(perceptual, 16)].add(split)
    for label, values in (("group_id", groups), ("SHA-256", shas)):
        for identity, splits in values.items():
            if len(splits) > 1:
                raise DevelopmentRotationError(f"{label} {identity!r} crosses splits {sorted(splits)}")
    for splits in phashes.values():
        if len(splits) > 1:
            raise DevelopmentRotationError(
                f"pHash pair crosses splits within distance {phash_distance}"
            )
    tree = _BKTree()
    for perceptual in sorted(phashes):
        for nearby in tree.nearby(perceptual, phash_distance):
            if phashes[perceptual] != phashes[nearby]:
                raise DevelopmentRotationError(f"pHash pair crosses splits within distance {phash_distance}")
        tree.add(perceptual)


def _serialize(fields: Sequence[str], rows: Sequence[Mapping[str, str]]) -> bytes:
    output = io.StringIO(newline="")
    writer = csv.DictWriter(output, fieldnames=fields, lineterminator="\n", extrasaction="raise")
    writer.writeheader()
    writer.writerows(rows)
    return output.getvalue().encode("utf-8")


def _commit(output: Path, manifest: bytes, receipt: Path, receipt_bytes: bytes, overwrite: bool) -> None:
    if not overwrite and (output.exists() or receipt.exists()):
        raise DevelopmentRotationError("output or receipt already exists; refusing overwrite")
    output.parent.mkdir(parents=True, exist_ok=True)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    temporary: list[Path] = []
    try:
        for destination, payload in ((output, manifest), (receipt, receipt_bytes)):
            handle, name = tempfile.mkstemp(prefix=f".{destination.name}.", suffix=".tmp", dir=destination.parent)
            path = Path(name)
            temporary.append(path)
            with os.fdopen(handle, "wb") as stream:
                stream.write(payload)
                stream.flush()
                os.fsync(stream.fileno())
        if overwrite and receipt.exists():
            receipt.unlink()
        manifest_temporary, receipt_temporary = temporary
        os.replace(manifest_temporary, output)
        temporary.remove(manifest_temporary)
        os.replace(receipt_temporary, receipt)
        temporary.remove(receipt_temporary)
    finally:
        for path in temporary:
            path.unlink(missing_ok=True)


def compose_development_rotation(manifest_path: Path, sidecar_path: Path, fold_report_path: Path, source_policy_path: Path, output_path: Path, receipt_path: Path, *, rotation: int, include_flagged: bool = False, phash_distance: int = 4, overwrite: bool = False) -> dict[str, Any]:
    if rotation not in range(1, 6):
        raise DevelopmentRotationError("rotation must be between 1 and 5")
    _resolve_distinct_paths((manifest_path, sidecar_path, fold_report_path, source_policy_path, output_path, receipt_path))
    if not overwrite and (output_path.exists() or receipt_path.exists()):
        raise DevelopmentRotationError("output or receipt already exists; refusing overwrite")
    manifest_bytes, fields, manifest = _read_csv(manifest_path, MANIFEST_REQUIRED)
    sidecar_bytes, _, sidecar = _read_csv(sidecar_path, SIDECAR_REQUIRED)
    report_bytes, report = _read_json(fold_report_path, "fold report")
    policy_bytes, policy = _read_json(source_policy_path, "source policy")
    _validate_policy(policy)
    _validate_report(report, _sha(manifest_bytes), _sha(sidecar_bytes), _sha(policy_bytes))

    for number, row in enumerate(manifest, start=2):
        if any(not row[field].strip() for field in MANIFEST_REQUIRED.difference({"source_locked_split"})):
            raise DevelopmentRotationError(f"blank required manifest value at row {number}")

    source_rows = [row for row in manifest if row["source_id"].strip() == SOURCE_ID]
    source_keys = {_key(row) for row in source_rows}
    if not source_rows or len(source_keys) != len(source_rows):
        raise DevelopmentRotationError("Digital Green base identities are absent or non-unique")
    sidecar_by_key: dict[tuple[str, str, str], dict[str, str]] = {}
    for number, row in enumerate(sidecar, start=2):
        essential = SIDECAR_REQUIRED.difference({"fold_index", "metadata_flags", "group_metadata_flags"})
        if any(not row[field].strip() for field in essential):
            raise DevelopmentRotationError(f"blank required sidecar value at row {number}")
        if row["fold_schema_version"].strip() != "1":
            raise DevelopmentRotationError(f"sidecar row {number} has unsupported schema")
        if row["source_id"].strip() != SOURCE_ID or row["evidence_role"].strip() != "external_development":
            raise DevelopmentRotationError(f"sidecar row {number} has invalid source/evidence role")
        _exact_csv_bool(row["development_only"], True, f"sidecar row {number} development_only")
        _exact_csv_bool(row["promotion_eligible"], False, f"sidecar row {number} promotion_eligible")
        _exact_csv_bool(row["selection_independent"], False, f"sidecar row {number} selection_independent")
        if row["metadata_status"].strip() not in {"ok", "flagged", "quarantined"}:
            raise DevelopmentRotationError(f"sidecar row {number} has invalid metadata_status")
        key = _key(row)
        if not _valid_hex(key[1], 64) or key in sidecar_by_key:
            raise DevelopmentRotationError(f"sidecar row {number} has malformed/duplicate identity")
        sidecar_by_key[key] = row
    if set(sidecar_by_key) != source_keys:
        raise DevelopmentRotationError("sidecar/base identity mismatch")
    for row in source_rows:
        if row["split"].strip() != "external_test" or sidecar_by_key[_key(row)]["manifest_split"].strip() != "external_test":
            raise DevelopmentRotationError("Digital Green base/sidecar split must be external_test")

    by_group: dict[str, list[dict[str, str]]] = defaultdict(list)
    for row in sidecar:
        by_group[row["group_id"].strip()].append(row)
    admitted: dict[str, int] = {}
    excluded: dict[str, set[str]] = {}
    all_folds: set[int] = set()
    excluded_by_fold: Counter[str] = Counter()
    for group, rows in sorted(by_group.items()):
        folds: set[int] = set()
        reasons: set[str] = set()
        quarantined = False
        for row in rows:
            status, fold_text, fold_name = row["metadata_status"].strip(), row["fold_index"].strip(), row["development_fold"].strip()
            if status == "quarantined" or fold_name == "quarantine":
                quarantined = True
                reasons.add("quarantine")
            if status != "ok":
                reasons.add(f"metadata_status:{status}")
            if row["metadata_flags"].strip() or row["group_metadata_flags"].strip():
                reasons.add("review_or_disagreement_flags")
            if fold_text:
                try:
                    fold = int(fold_text)
                except ValueError as error:
                    raise DevelopmentRotationError(f"group {group!r} has non-integer fold") from error
                if fold not in range(1, 6) or fold_name != f"dev_fold_{fold}":
                    raise DevelopmentRotationError(f"group {group!r} has inconsistent fold fields")
                folds.add(fold)
        if quarantined:
            excluded[group] = reasons
            excluded_by_fold["quarantine"] += 1
            continue
        if len(folds) != 1:
            raise DevelopmentRotationError(f"group {group!r} must have exactly one fold")
        fold = next(iter(folds))
        all_folds.add(fold)
        if reasons and not include_flagged:
            excluded[group] = reasons
            excluded_by_fold[f"dev_fold_{fold}"] += 1
        else:
            admitted[group] = fold
    if all_folds != set(range(1, 6)):
        raise DevelopmentRotationError("sidecar must contain all five non-quarantine folds")
    if set(admitted.values()) != set(range(1, 6)):
        raise DevelopmentRotationError("all five admitted folds must remain nonempty after exclusions")

    calibration_fold = rotation % 5 + 1
    split_by_fold = {fold: ("external_test" if fold == rotation else "calibration" if fold == calibration_fold else "train") for fold in range(1, 6)}
    output_rows: list[dict[str, str]] = []
    rows_by_split: Counter[str] = Counter()
    groups_by_split: dict[str, set[str]] = defaultdict(set)
    excluded_classes: Counter[str] = Counter()
    for row in manifest:
        if row["source_id"].strip() != SOURCE_ID:
            output_rows.append(dict(row))
            continue
        group = row["group_id"].strip()
        if group in excluded:
            fold = next((int(item["fold_index"]) for item in by_group[group] if item["fold_index"].strip()), 0)
            excluded_classes[f"fold={fold or 'quarantine'}|crop={row['crop']}|condition={row['condition_label']}|validity={row['validity_label']}"] += 1
            continue
        split = split_by_fold[admitted[group]]
        rotated = dict(row)
        rotated["source_id"], rotated["split"], rotated["source_locked_split"] = ROTATED_SOURCE_ID, split, ""
        output_rows.append(rotated)
        rows_by_split[split] += 1
        groups_by_split[split].add(group)
    _assert_no_leakage(output_rows, phash_distance)
    output_bytes = _serialize(fields, output_rows)
    excluded_payload = json.dumps({group: sorted(reasons) for group, reasons in sorted(excluded.items())}, sort_keys=True, separators=(",", ":")).encode("utf-8")
    receipt: dict[str, Any] = {
        "schema_version": 1, "status": "complete", "evidence_role": "external_development",
        "human_evidence_label": "diagnostic external-development fold; not independent external evidence",
        "promotion_eligible": False, "selection_independent": False,
        "algorithm": "digitalgreen-five-fold-rotation-compositor-v2",
        "rotation": {"index": rotation, "technical_external_test_fold": f"dev_fold_{rotation}", "calibration_fold": f"dev_fold_{calibration_fold}", "train_folds": [f"dev_fold_{fold}" for fold in range(1, 6) if fold not in {rotation, calibration_fold}]},
        "inputs": {
            "manifest": {"path": str(manifest_path.resolve()), "sha256": _sha(manifest_bytes), "rows": len(manifest)},
            "fold_sidecar": {"path": str(sidecar_path.resolve()), "sha256": _sha(sidecar_bytes), "rows": len(sidecar)},
            "fold_report": {"path": str(fold_report_path.resolve()), "sha256": _sha(report_bytes)},
            "source_policy": {"path": str(source_policy_path.resolve()), "sha256": _sha(policy_bytes)},
        },
        "output": {"manifest": {"path": str(output_path.resolve()), "sha256": _sha(output_bytes), "rows": len(output_rows)}, "source_id": ROTATED_SOURCE_ID},
        "counts": {
            "preserved_non_digitalgreen_rows": sum(row["source_id"].strip() != SOURCE_ID for row in manifest),
            "rotated_rows_by_split": dict(sorted(rows_by_split.items())),
            "rotated_groups_by_split": {split: len(groups) for split, groups in sorted(groups_by_split.items())},
            "excluded_groups": len(excluded), "excluded_rows_by_fold_and_class": dict(sorted(excluded_classes.items())),
            "excluded_groups_by_fold": dict(sorted(excluded_by_fold.items())),
        },
        "excluded_group_set_sha256": _sha(excluded_payload),
        "leakage_checks": {"group": True, "sha256": True, "phash": True, "phash_maximum_hamming_distance": phash_distance},
        "write_protocol": "manifest first; receipt written last as commit marker",
    }
    receipt_bytes = (json.dumps(receipt, indent=2, sort_keys=True) + "\n").encode("utf-8")
    _commit(output_path, output_bytes, receipt_path, receipt_bytes, overwrite)
    return receipt


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--fold-sidecar", type=Path, required=True)
    parser.add_argument("--fold-report", type=Path, required=True)
    parser.add_argument("--source-policy", type=Path, required=True)
    parser.add_argument("--rotation", type=int, choices=range(1, 6), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--receipt", type=Path, required=True)
    parser.add_argument("--phash-distance", type=int, default=4)
    parser.add_argument("--include-flagged", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    receipt = compose_development_rotation(args.manifest, args.fold_sidecar, args.fold_report, args.source_policy, args.output, args.receipt, rotation=args.rotation, include_flagged=args.include_flagged, phash_distance=args.phash_distance, overwrite=args.overwrite)
    print(json.dumps({"status": receipt["status"], "output": receipt["output"], "counts": receipt["counts"]}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
