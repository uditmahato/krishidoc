#!/usr/bin/env python
"""Export one calibrated PyTorch checkpoint as a verified ONNX candidate."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "ml" / "src"))

from krishidoc_ml.deployment import export_onnx_candidate  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--checkpoint", required=True)
    parser.add_argument(
        "--calibration",
        required=True,
        help="Locked calibration artifact produced for this exact checkpoint",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Candidate directory under ml/artifacts; app asset paths are refused",
    )
    parser.add_argument("--artifact-name", help="Optional plain .onnx filename")
    parser.add_argument(
        "--overwrite",
        action="store_true",
        help="Replace an existing candidate in the output directory",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result = export_onnx_candidate(
        checkpoint_path=args.checkpoint,
        calibration_path=args.calibration,
        output_dir=args.output_dir,
        artifact_name=args.artifact_name,
        overwrite=args.overwrite,
    )
    print(
        json.dumps(
            {
                "artifact_path": result["artifact_path"],
                "metadata_path": result["metadata_path"],
                "app_runtime_compatible": result["metadata"]["app_compatibility"][
                    "compatible_with_current_flutter_runtime"
                ],
            },
            indent=2,
            sort_keys=True,
        )
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
