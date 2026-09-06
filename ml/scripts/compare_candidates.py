#!/usr/bin/env python
"""Compare legacy reports or grouped evidence bundles for promotion."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "ml" / "src"))

from krishidoc_ml.config import load_config  # noqa: E402
from krishidoc_ml.promotion import (  # noqa: E402
    compare_candidate_bundles,
    compare_candidates,
    write_comparison_outputs,
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--config",
        required=True,
        help="Training config or standalone promotion policy with acceptance_gates",
    )
    inputs = parser.add_mutually_exclusive_group(required=True)
    inputs.add_argument(
        "--evaluation",
        action="append",
        help="Legacy test-evaluation JSON; repeat for each separate candidate",
    )
    inputs.add_argument(
        "--bundle",
        action="append",
        help=(
            "Evidence-bundle descriptor JSON; repeat for each candidate. Paths "
            "inside a descriptor are resolved relative to that descriptor."
        ),
    )
    parser.add_argument("--output-json", required=True)
    parser.add_argument("--output-markdown", required=True)
    parser.add_argument(
        "--require-promotion",
        action="store_true",
        help="Exit 2 when no candidate is promotion-eligible",
    )
    return parser.parse_args()


def load_bundle_descriptor(path: str | Path) -> dict:
    """Resolve one path-based bundle descriptor into in-memory reports."""

    descriptor_path = Path(path).resolve()
    descriptor = _read_json_object(descriptor_path, "Evidence-bundle descriptor")
    raw_members = descriptor.get("members", descriptor.get("evidence"))
    if not isinstance(raw_members, dict):
        raise ValueError(
            f"Evidence-bundle descriptor must contain a members object: "
            f"{descriptor_path}"
        )

    reports: dict[str, dict] = {}
    sources: dict[str, str] = {}
    for raw_role, member_reference in raw_members.items():
        role = str(raw_role)
        raw_member_path = (
            member_reference.get("path")
            if isinstance(member_reference, dict)
            else member_reference
        )
        if not isinstance(raw_member_path, str) or not raw_member_path.strip():
            raise ValueError(
                f"Bundle member {role!r} must be a path string or an object "
                f"containing a path string: {descriptor_path}"
            )
        member_path = Path(raw_member_path)
        if not member_path.is_absolute():
            member_path = descriptor_path.parent / member_path
        member_path = member_path.resolve()
        reports[role] = _read_json_object(
            member_path, f"Evidence-bundle member {role!r}"
        )
        sources[role] = str(member_path)

    resolved = {
        "schema_version": descriptor.get("schema_version"),
        "candidate_id": descriptor.get("candidate_id"),
        "members": reports,
        "member_sources": sources,
    }
    if "identity" in descriptor:
        resolved["identity"] = descriptor["identity"]
    return resolved


def _read_json_object(path: Path, description: str) -> dict:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, json.JSONDecodeError) as error:
        raise ValueError(f"Cannot read {description}: {path}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{description} must be a JSON object: {path}")
    return value


def main() -> int:
    args = parse_args()
    config = load_config(args.config)
    if args.bundle:
        paths = [Path(raw_path).resolve() for raw_path in args.bundle]
        comparison = compare_candidate_bundles(
            [load_bundle_descriptor(path) for path in paths],
            config,
            bundle_sources=[str(path) for path in paths],
        )
    else:
        paths = [Path(raw_path).resolve() for raw_path in args.evaluation]
        comparison = compare_candidates(
            [_read_json_object(path, "Evaluation report") for path in paths],
            config,
            report_sources=[str(path) for path in paths],
        )
    write_comparison_outputs(
        comparison,
        Path(args.output_json),
        Path(args.output_markdown),
    )
    print(json.dumps(comparison["selection"], indent=2, sort_keys=True))
    if args.require_promotion and not comparison["selection"]["promotion_allowed"]:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
