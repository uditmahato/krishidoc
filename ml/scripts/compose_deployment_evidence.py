#!/usr/bin/env python
"""Attach qualified INT8 physical-Android evidence to an evaluation report."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "ml" / "src"))

from krishidoc_ml.deployment import compose_physical_device_evidence  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--evaluation", required=True)
    parser.add_argument("--export-metadata", required=True)
    parser.add_argument(
        "--device-benchmark",
        required=True,
        help="Raw timings captured by the physical Android integration harness",
    )
    parser.add_argument(
        "--output",
        required=True,
        help="New augmented report; source reports are never edited in place",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = compose_physical_device_evidence(
        evaluation_path=args.evaluation,
        export_metadata_path=args.export_metadata,
        device_benchmark_path=args.device_benchmark,
        output_path=args.output,
    )
    print(json.dumps(report["deployment"], indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
