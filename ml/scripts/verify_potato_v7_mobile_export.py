"""Bind TFLite tensor names/order and check V7 logits/gates before app staging."""

import json
import os
import sys
from pathlib import Path

os.environ["TF_USE_LEGACY_KERAS"] = "1"
os.environ["CUDA_VISIBLE_DEVICES"] = "-1"
import flatbuffers
import numpy as np
import onnxruntime as ort
import tensorflow as tf
from prepare_manifest import compute_sha256
from prepare_plantseg_extension import write_json
from tensorflow.lite.python import schema_py_generated as schema

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ml/artifacts/potato_v7_mobile_20260907"
sys.path.insert(0, str(ROOT / "ml/src"))
from krishidoc_ml.calibration import apply_calibration


def main():
    source = OUT / "converted_v3/potato-v7_float32.tflite"
    model = schema.ModelT.InitFromObj(
        schema.Model.GetRootAsModel(source.read_bytes(), 0)
    )
    graph = model.subgraphs[0]
    names = {5: b"validity_logits", 3: b"condition_logits"}
    outputs = {int(graph.tensors[int(i)].shape[-1]): int(i) for i in graph.outputs}
    if set(outputs) != {3, 5} or len(graph.outputs) != 2:
        raise ValueError("Unexpected output heads")
    graph.outputs = np.array([outputs[5], outputs[3]], dtype=np.int32)
    for width, i in outputs.items():
        graph.tensors[i].name = names[width]
    builder = flatbuffers.Builder(0)
    builder.Finish(model.Pack(builder), file_identifier=b"TFL3")
    target = OUT / "potato_field_v7_efficientnet_b0_float32.tflite"
    content = bytes(builder.Output())
    if target.exists() and target.read_bytes() != content:
        raise ValueError("Existing canonical artifact differs")
    target.write_bytes(content)
    interpreter = tf.lite.Interpreter(model_path=str(target), num_threads=2)
    interpreter.allocate_tensors()
    inp = interpreter.get_input_details()
    heads = interpreter.get_output_details()
    assert len(inp) == 1 and list(inp[0]["shape"]) == [1, 224, 224, 3]
    assert inp[0]["dtype"] == np.float32
    assert [h["name"] for h in heads] == ["validity_logits", "condition_logits"]
    assert [list(h["shape"]) for h in heads] == [[1, 5], [1, 3]]
    session = ort.InferenceSession(
        str(OUT / "export/potato-v7.onnx"), providers=["CPUExecutionProvider"]
    )
    calpath = (
        ROOT / "ml/runs/potato_field_v7_tari_20260907/efficientnet_b0/calibration.json"
    )
    calibration = json.loads(calpath.read_text())
    frozen = json.loads(
        (
            ROOT / "ml/artifacts/potato_field_v7_20260907/evaluation_manifest.json"
        ).read_text()
    )
    probes = [
        (
            f"synthetic_{i}",
            np.random.default_rng(i).normal(size=(1, 224, 224, 3)).astype(np.float32),
        )
        for i in range(5)
    ]
    for row in frozen["rows"]:
        if not row.get("tensor_path"):
            continue
        path = ROOT / row["tensor_path"]
        if compute_sha256(path) != row["tensor_sha256"]:
            raise ValueError("Dart input bytes changed")
        probes.append(
            (row["id"], np.fromfile(path, dtype="<f4").reshape(1, 224, 224, 3))
        )
    errors = []
    for name, x in probes:
        expected = session.run(
            ["validity_logits", "condition_logits"],
            {"image": x.transpose(0, 3, 1, 2).copy()},
        )
        interpreter.set_tensor(inp[0]["index"], x)
        interpreter.invoke()
        actual = [interpreter.get_tensor(h["index"]) for h in heads]
        error = max(float(np.max(np.abs(a - b))) for a, b in zip(actual, expected))
        if error > 0.001 or any(not np.isfinite(a).all() for a in actual):
            raise ValueError(f"Logit parity failed: {name}: {error}")
        if any(int(a.argmax()) != int(b.argmax()) for a, b in zip(actual, expected)):
            raise ValueError(f"Argmax parity failed: {name}")
        if not np.array_equal(
            apply_calibration(calibration, *actual)["accepted"],
            apply_calibration(calibration, *expected)["accepted"],
        ):
            raise ValueError(f"Gate parity failed: {name}")
        errors.append({"id": name, "maximum_absolute_error": error})
    receipt = {
        "status": "passed_host_conversion_parity_not_native",
        "artifact_sha256": compute_sha256(target),
        "artifact_bytes": target.stat().st_size,
        "checkpoint_sha256": "ad3b3c0b6ab9cb78f5999ba4631605aa48d8f344491772fbff69889c4669c9f8",
        "calibration_sha256": compute_sha256(calpath),
        "onnx_sha256": compute_sha256(OUT / "export/potato-v7.onnx"),
        "probes": errors,
        "tolerance": 0.001,
        "maximum_absolute_error": max(r["maximum_absolute_error"] for r in errors),
        "argmax_disagreements": 0,
        "gate_disagreements": 0,
        "promotion_eligible": False,
    }
    write_json(OUT / "conversion_verification.json", receipt)
    print(json.dumps(receipt, indent=2))


if __name__ == "__main__":
    main()
