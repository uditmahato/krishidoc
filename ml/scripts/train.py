#!/usr/bin/env python
"""Train one or all crop/architecture candidates from a JSON config."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "ml" / "src"))

from krishidoc_ml.config import (  # noqa: E402
    condition_labels_for_crop,
    iter_experiments,
    load_config,
)
from krishidoc_ml.pipeline import train_experiment  # noqa: E402


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", required=True, help="Versioned JSON training config")
    parser.add_argument("--crop", choices=("maize", "potato", "tomato"))
    parser.add_argument(
        "--architecture", choices=("mobilenet_v3_large", "efficientnet_b0")
    )
    parser.add_argument("--output-dir", help="Run root (defaults to ml/runs/<run_name>)")
    parser.add_argument("--resume", help="Exact last.pt checkpoint to resume")
    parser.add_argument("--device", default="auto", help="auto, cpu, cuda, or cuda:N")
    parser.add_argument(
        "--no-pretrained",
        action="store_true",
        help="Do not download/use ImageNet weights (mainly for offline smoke tests)",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    config = load_config(args.config)
    if args.no_pretrained:
        config["pretrained"] = False
    experiments = list(iter_experiments(config, args.crop, args.architecture))
    if args.resume and len(experiments) != 1:
        raise SystemExit("--resume requires exactly one crop/architecture experiment")
    run_name = str(config.get("run_name", Path(args.config).stem))
    base = Path(args.output_dir) if args.output_dir else REPO_ROOT / "ml" / "runs" / run_name
    summaries = []
    for crop, architecture in experiments:
        output = base if len(experiments) == 1 else base / crop / architecture
        labels = condition_labels_for_crop(config, crop, REPO_ROOT)
        summaries.append(
            train_experiment(
                config=config,
                crop=crop,
                architecture=architecture,
                condition_labels=labels,
                output_dir=output,
                resume=args.resume,
                device_name=args.device,
            )
        )
    print(json.dumps({"runs": summaries}, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
