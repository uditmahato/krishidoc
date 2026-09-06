#!/usr/bin/env python
"""Fit temperatures and refusal thresholds on the locked calibration split."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "ml" / "src"))

from krishidoc_ml.config import load_config  # noqa: E402
from krishidoc_ml.pipeline import calibrate_checkpoint  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", required=True, help="Trained best.pt")
    parser.add_argument("--config", help="Config override; checkpoint config is default")
    parser.add_argument("--manifest", help="Manifest override")
    parser.add_argument("--split", default="calibration")
    parser.add_argument("--output", help="Defaults beside checkpoint as calibration.json")
    parser.add_argument("--target-far", type=float, help="Maximum validation OOD false accept")
    parser.add_argument("--device", default="auto")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = load_config(args.config) if args.config else None
    target_far = args.target_far
    if target_far is None:
        target_far = float(
            (config or {}).get("acceptance_gates", {}).get(
                "maximum_ood_false_accept_rate_at_operating_point", 0.05
            )
        )
    output = Path(args.output) if args.output else Path(args.checkpoint).resolve().parent / "calibration.json"
    result = calibrate_checkpoint(
        checkpoint_path=args.checkpoint,
        config=config,
        manifest_path=args.manifest,
        split=args.split,
        output_path=output,
        target_false_accept_rate=target_far,
        device_name=args.device,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
