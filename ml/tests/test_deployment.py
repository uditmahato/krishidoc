from __future__ import annotations

import hashlib
import json
from pathlib import Path

import pytest
import torch

from krishidoc_ml.constants import VALIDITY_LABELS
from krishidoc_ml.deployment import (
    DeploymentContractError,
    benchmark_onnx_host,
    compose_physical_device_evidence,
    export_onnx_candidate,
)
from krishidoc_ml.model import create_model
from krishidoc_ml.receipt import file_sha256


def _checkpoint_and_calibration(tmp_path: Path) -> tuple[Path, Path]:
    checkpoint_path = tmp_path / "best.pt"
    model = create_model("mobilenet_v3_large", 2, pretrained=False)
    torch.save(
        {
            "schema_version": 1,
            "epoch": 2,
            "best_metric": 0.75,
            "model_state": model.state_dict(),
            "crop": "maize",
            "architecture": "mobilenet_v3_large",
            "condition_labels": ["maize_common_rust", "maize_healthy"],
            "validity_labels": list(VALIDITY_LABELS),
            "config_hash": "a" * 64,
            "manifest_sha256": "b" * 64,
            "image_size": 64,
            "config": {"promotion_allowed": False},
        },
        checkpoint_path,
    )
    calibration_path = tmp_path / "calibration.json"
    calibration_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "crop": "maize",
                "architecture": "mobilenet_v3_large",
                "checkpoint_sha256": file_sha256(checkpoint_path),
                "manifest_sha256": "b" * 64,
                "config_sha256": "a" * 64,
                "manifest_split": "calibration",
                "method": "scalar_temperature_plus_three_signal_grid_gate",
                "validity_temperature": 1.2,
                "condition_temperature": 0.8,
                "thresholds": {
                    "validity_probability_min": 0.7,
                    "condition_probability_min": 0.8,
                    "condition_energy_max": -1.1,
                },
            }
        ),
        encoding="utf-8",
    )
    return checkpoint_path, calibration_path


def test_export_rejects_mismatched_calibration_before_writing(tmp_path: Path) -> None:
    checkpoint, calibration = _checkpoint_and_calibration(tmp_path)
    value = json.loads(calibration.read_text(encoding="utf-8"))
    value["checkpoint_sha256"] = "0" * 64
    calibration.write_text(json.dumps(value), encoding="utf-8")
    output = tmp_path / "candidate"

    with pytest.raises(DeploymentContractError, match="checkpoint_sha256"):
        export_onnx_candidate(
            checkpoint_path=checkpoint,
            calibration_path=calibration,
            output_dir=output,
        )

    assert not output.exists()


@pytest.mark.parametrize("replacement", [None, "0" * 64])
def test_export_requires_exact_calibration_config_identity(
    tmp_path: Path, replacement: str | None
) -> None:
    checkpoint, calibration = _checkpoint_and_calibration(tmp_path)
    value = json.loads(calibration.read_text(encoding="utf-8"))
    if replacement is None:
        del value["config_sha256"]
    else:
        value["config_sha256"] = replacement
    calibration.write_text(json.dumps(value), encoding="utf-8")
    output = tmp_path / "candidate"

    with pytest.raises(DeploymentContractError, match="config_sha256"):
        export_onnx_candidate(
            checkpoint_path=checkpoint,
            calibration_path=calibration,
            output_dir=output,
        )

    assert not output.exists()


def test_export_refuses_active_app_asset_directory(tmp_path: Path) -> None:
    checkpoint, calibration = _checkpoint_and_calibration(tmp_path)
    repo_root = Path(__file__).resolve().parents[2]

    with pytest.raises(DeploymentContractError, match="app/assets/models"):
        export_onnx_candidate(
            checkpoint_path=checkpoint,
            calibration_path=calibration,
            output_dir=repo_root / "app" / "assets" / "models" / "candidate",
        )


@pytest.fixture(scope="module")
def onnx_candidate(tmp_path_factory: pytest.TempPathFactory) -> dict[str, object]:
    pytest.importorskip("onnx")
    pytest.importorskip("onnxruntime")
    root = tmp_path_factory.mktemp("onnx_candidate")
    checkpoint, calibration = _checkpoint_and_calibration(root)
    result = export_onnx_candidate(
        checkpoint_path=checkpoint,
        calibration_path=calibration,
        output_dir=root / "export",
        artifact_name="candidate.onnx",
    )
    return result


def test_onnx_export_records_complete_contract_and_runtime_parity(
    onnx_candidate: dict[str, object],
) -> None:
    metadata = onnx_candidate["metadata"]
    assert isinstance(metadata, dict)
    artifact = Path(str(onnx_candidate["artifact_path"]))
    metadata_path = Path(str(onnx_candidate["metadata_path"]))

    assert metadata["artifact"]["sha256"] == file_sha256(artifact)
    assert metadata["artifact"]["bytes"] == artifact.stat().st_size
    assert metadata["artifact"]["quantization"]["mode"] == "none"
    assert metadata["input"]["shape"] == [1, 3, 64, 64]
    assert metadata["input"]["resize"]["preserve_aspect_ratio"] is True
    assert metadata["outputs"][0]["labels"] == list(VALIDITY_LABELS)
    assert metadata["outputs"][1]["labels"] == [
        "maize_common_rust",
        "maize_healthy",
    ]
    assert metadata["decision_policy"]["validity_temperature"] == 1.2
    assert metadata["runtime_validation"]["onnxruntime_parity_passed"] is True
    assert (
        metadata["app_compatibility"]["compatible_with_current_flutter_runtime"]
        is False
    )
    assert metadata["promotion_evidence"]["int8_model_bytes"] is None
    assert json.loads(metadata_path.read_text(encoding="utf-8")) == metadata


def test_host_benchmark_cannot_masquerade_as_device_evidence(
    tmp_path: Path, onnx_candidate: dict[str, object]
) -> None:
    output = tmp_path / "host-benchmark.json"
    report = benchmark_onnx_host(
        metadata_path=str(onnx_candidate["metadata_path"]),
        output_path=output,
        warmup_iterations=1,
        measured_iterations=3,
        intra_op_threads=1,
    )

    assert report["scope"] == "development_host_cpu"
    assert report["promotion_gate_eligible"] is False
    assert report["source_checkpoint"] == {
        "sha256": onnx_candidate["metadata"]["source_checkpoint"]["sha256"],
        "config_sha256": "a" * 64,
        "manifest_sha256": "b" * 64,
    }
    assert report["model"] == {
        "crop": "maize",
        "architecture": "mobilenet_v3_large",
    }
    assert report["host_benchmark"]["measured_iterations"] == 3
    assert report["host_benchmark"]["p95_ms"] > 0
    assert report["deployment"] == {
        "int8_model_bytes": None,
        "p95_device_inference_ms": None,
        "cold_device_inference_ms": None,
    }


def _write_tflite_evidence(tmp_path: Path) -> tuple[Path, Path, Path]:
    artifact = tmp_path / "candidate-int8.tflite"
    artifact.write_bytes(b"synthetic tflite fixture")
    checkpoint_sha = "c" * 64
    manifest_sha = "d" * 64
    calibration_sha = "e" * 64
    input_tensor = {
        "name": "image",
        "position": 0,
        "shape": [1, 224, 224, 3],
        "layout": "NHWC",
        "dtype": "int8",
        "quantization": {"scale": 0.02, "zero_point": -3},
    }
    output_tensors = [
        {
            "name": "validity_logits",
            "position": 0,
            "shape": [1, 5],
            "dtype": "int8",
            "quantization": {"scale": 0.04, "zero_point": 0},
            "labels": list(VALIDITY_LABELS),
        },
        {
            "name": "condition_logits",
            "position": 1,
            "shape": [1, 2],
            "dtype": "int8",
            "quantization": {"scale": 0.03, "zero_point": 1},
            "labels": ["maize_common_rust", "maize_healthy"],
        },
    ]
    metadata = {
        "schema_version": 1,
        "artifact": {
            "filename": artifact.name,
            "format": "tflite",
            "bytes": artifact.stat().st_size,
            "sha256": file_sha256(artifact),
            "quantization": {
                "mode": "full_integer_int8",
                "input_dtype": "int8",
                "output_dtype": "int8",
            },
        },
        "source_checkpoint": {
            "sha256": checkpoint_sha,
            "manifest_sha256": manifest_sha,
        },
        "model": {
            "crop": "maize",
            "architecture": "efficientnet_b0",
            "condition_head_count": 2,
        },
        "input": input_tensor,
        "outputs": output_tensors,
        "decision_policy": {
            "calibration_sha256": calibration_sha,
            "validity_temperature": 1.1,
            "condition_temperature": 0.9,
            "thresholds": {
                "validity_probability_min": 0.7,
                "condition_probability_min": 0.8,
                "condition_energy_max": -1.0,
            },
        },
        "app_compatibility": {"compatible_with_current_flutter_runtime": True},
    }
    metadata_path = tmp_path / "candidate.metadata.json"
    metadata_path.write_text(json.dumps(metadata), encoding="utf-8")
    evaluation_path = tmp_path / "evaluation.json"
    evaluation_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "crop": "maize",
                "architecture": "efficientnet_b0",
                "checkpoint_sha256": checkpoint_sha,
                "manifest_sha256": manifest_sha,
                "calibration_sha256": calibration_sha,
                "metrics": {},
            }
        ),
        encoding="utf-8",
    )
    benchmark = {
        "schema_version": 1,
        "scope": "physical_android_device",
        "is_emulator": False,
        "artifact_sha256": file_sha256(artifact),
        "runtime": {"name": "tflite_flutter", "version": "0.12.1", "threads": 4},
        "contract_test": {
            "passed": True,
            "test_run_id": "fixture",
            "input": input_tensor,
            "outputs": output_tensors,
            "policy_test_vectors": {"count": 3, "passed": True},
        },
        "device": {
            "manufacturer": "Example",
            "model": "Physical Phone",
            "android_version": "15",
            "api_level": 35,
            "abi": "arm64-v8a",
        },
        "steady_inference_ms": [float(index) for index in range(1, 101)],
        "cold_start_ms": [450.0, 500.0, 475.0, 510.0, 490.0],
    }
    benchmark_path = tmp_path / "device-benchmark.json"
    benchmark_path.write_text(json.dumps(benchmark), encoding="utf-8")
    return evaluation_path, metadata_path, benchmark_path


def test_compose_recomputes_qualified_physical_device_evidence(tmp_path: Path) -> None:
    evaluation, metadata, benchmark = _write_tflite_evidence(tmp_path)
    output = tmp_path / "promotion-input.json"

    report = compose_physical_device_evidence(
        evaluation_path=evaluation,
        export_metadata_path=metadata,
        device_benchmark_path=benchmark,
        output_path=output,
    )

    assert (
        report["deployment"]["int8_model_bytes"]
        == (tmp_path / "candidate-int8.tflite").stat().st_size
    )
    assert report["deployment"]["p95_device_inference_ms"] == 95.0
    assert report["deployment"]["cold_device_inference_ms"] == 510.0
    assert report["deployment"]["steady_sample_count"] == 100
    assert json.loads(output.read_text(encoding="utf-8")) == report


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        (lambda value: value.update({"is_emulator": True}), "Emulator"),
        (
            lambda value: value.update(
                {"artifact_sha256": hashlib.sha256(b"other").hexdigest()}
            ),
            "different artifact",
        ),
        (
            lambda value: value.update({"steady_inference_ms": [1.0] * 99}),
            "At least 100",
        ),
    ],
)
def test_compose_rejects_unqualified_device_evidence(
    tmp_path: Path, mutation, message: str
) -> None:
    evaluation, metadata, benchmark = _write_tflite_evidence(tmp_path)
    value = json.loads(benchmark.read_text(encoding="utf-8"))
    mutation(value)
    benchmark.write_text(json.dumps(value), encoding="utf-8")

    with pytest.raises(DeploymentContractError, match=message):
        compose_physical_device_evidence(
            evaluation_path=evaluation,
            export_metadata_path=metadata,
            device_benchmark_path=benchmark,
            output_path=tmp_path / "output.json",
        )


def test_onnx_candidate_cannot_be_composed_as_android_evidence(
    tmp_path: Path, onnx_candidate: dict[str, object]
) -> None:
    evaluation = tmp_path / "evaluation.json"
    evaluation.write_text("{}", encoding="utf-8")
    benchmark = tmp_path / "benchmark.json"
    benchmark.write_text("{}", encoding="utf-8")

    with pytest.raises(DeploymentContractError, match="TFLite"):
        compose_physical_device_evidence(
            evaluation_path=evaluation,
            export_metadata_path=str(onnx_candidate["metadata_path"]),
            device_benchmark_path=benchmark,
            output_path=tmp_path / "output.json",
        )
