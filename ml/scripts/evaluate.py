#!/usr/bin/env python
"""Evaluate a frozen checkpoint on a named manifest split."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "ml" / "src"))

from krishidoc_ml.config import load_config  # noqa: E402
from krishidoc_ml.pipeline import evaluate_checkpoint  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument("--config", help="Config override; checkpoint config is default")
    parser.add_argument("--manifest", help="Manifest override")
    parser.add_argument("--split", default="test")
    parser.add_argument("--calibration", help="Calibration artifact from calibrate.py")
    parser.add_argument("--output-dir", help="Defaults to <checkpoint-dir>/evaluation")
    parser.add_argument("--device", default="auto")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = load_config(args.config) if args.config else None
    output = (
        Path(args.output_dir)
        if args.output_dir
        else Path(args.checkpoint).resolve().parent / "evaluation"
    )
    report = evaluate_checkpoint(
        checkpoint_path=args.checkpoint,
        config=config,
        manifest_path=args.manifest,
        split=args.split,
        output_dir=output,
        calibration_path=args.calibration,
        device_name=args.device,
    )
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
