"""Convert V7 for opt-in phone testing; do not promote or modify V3 assets."""

import argparse
import importlib
import os
from pathlib import Path

os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"

import numpy as np
from onnx2tf import convert

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ml/artifacts/potato_v7_mobile_20260907"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--attempt", default="converted")
    args = parser.parse_args()
    if Path(args.attempt).name != args.attempt:
        raise ValueError("Attempt must be a plain directory name")
    target = OUT / args.attempt
    if target.exists():
        raise ValueError("Preserve conversion attempts; inspect existing outputs")
    # The upstream converter downloads a generic image fixture even for a
    # float32 export. Use deterministic finite probes instead of network data.
    # These are conversion probes, never training/accuracy/calibration evidence.
    converter_module = importlib.import_module("onnx2tf.onnx2tf")
    converter_module.download_test_image_data = lambda: np.random.default_rng(
        20260907
    ).random((20, 128, 128, 3), dtype=np.float32)
    convert(
        input_onnx_file_path=str(OUT / "export/potato-v7.onnx"),
        output_folder_path=str(target),
        not_use_onnxsim=True,
        not_use_opname_auto_generate=True,
        batch_size=1,
        verbosity="error",
    )
