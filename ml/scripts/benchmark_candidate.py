#!/usr/bin/env python
"""Benchmark a verified ONNX candidate on the development host CPU."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "ml" / "src"))

from krishidoc_ml.deployment import benchmark_onnx_host  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--metadata", required=True, help="Export metadata JSON")
    parser.add_argument("--output", required=True, help="Host benchmark JSON")
    parser.add_argument("--warmup-iterations", type=int, default=10)
    parser.add_argument("--measured-iterations", type=int, default=100)
    parser.add_argument("--threads", type=int, default=1)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    report = benchmark_onnx_host(
        metadata_path=args.metadata,
        output_path=args.output,
        warmup_iterations=args.warmup_iterations,
        measured_iterations=args.measured_iterations,
        intra_op_threads=args.threads,
    )
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
