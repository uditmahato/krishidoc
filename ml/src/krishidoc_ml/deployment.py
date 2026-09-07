"""Auditable candidate export, host benchmarking, and deployment evidence.

The current Flutter application executes TFLite, while the training stack is
PyTorch and emits two raw-logit heads.  This module therefore exports a
verified ONNX *interchange candidate* without pretending it is app-ready.
Physical-device measurements can only enter a promotion report through the
strict evidence composer at the bottom of this file.
"""

from __future__ import annotations

import importlib.metadata
import json
import math
import os
import platform
import statistics
import tempfile
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Sequence

import numpy as np
import torch
from torch import nn

from .config import SUPPORTED_ARCHITECTURES, find_repo_root
from .constants import VALIDITY_LABELS
from .model import create_model
from .receipt import file_sha256, write_json_atomic
from .transforms import DEFAULT_FILL, IMAGENET_MEAN, IMAGENET_STD


EXPORT_SCHEMA_VERSION = 1
BENCHMARK_SCHEMA_VERSION = 1
DEPLOYMENT_EVIDENCE_SCHEMA_VERSION = 1
ONNX_OPSET = 17
ONNX_PARITY_RTOL = 1e-3
ONNX_PARITY_ATOL = 1e-4
MINIMUM_STEADY_DEVICE_SAMPLES = 100
MINIMUM_COLD_DEVICE_SAMPLES = 5


class DeploymentContractError(ValueError):
    """Raised when provenance or runtime evidence is incomplete or mismatched."""


class _ExportModel(nn.Module):
    """Give the two model outputs stable names while preserving raw logits."""

    def __init__(self, model: nn.Module) -> None:
        super().__init__()
        self.model = model

    def forward(self, image: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        return self.model(image)


def export_onnx_candidate(
    *,
    checkpoint_path: str | Path,
    calibration_path: str | Path,
    output_dir: str | Path,
    artifact_name: str | None = None,
    overwrite: bool = False,
) -> dict[str, Any]:
    """Export one calibrated checkpoint to a validated, fixed-shape ONNX file.

    ONNX is an interchange artifact, not a deployment claim.  The metadata
    explicitly records that the existing Flutter runtime cannot consume this
    dual-head artifact and omits all INT8/device gate fields.
    """

    checkpoint_file = Path(checkpoint_path).resolve()
    calibration_file = Path(calibration_path).resolve()
    checkpoint = _load_checkpoint(checkpoint_file)
    calibration = _load_calibration(
        calibration_file,
        checkpoint=checkpoint,
        checkpoint_sha256=file_sha256(checkpoint_file),
    )

    output = Path(output_dir).resolve()
    _reject_app_asset_destination(output)
    output.mkdir(parents=True, exist_ok=True)
    default_name = (
        f"{checkpoint['crop']}-{checkpoint['architecture']}-"
        f"{file_sha256(checkpoint_file)[:12]}.onnx"
    )
    name = artifact_name or default_name
    if Path(name).name != name or not name.lower().endswith(".onnx"):
        raise DeploymentContractError(
            "artifact_name must be a plain filename ending in .onnx"
        )
    artifact_path = output / name
    metadata_path = output / f"{Path(name).stem}.metadata.json"
    for destination in (artifact_path, metadata_path):
        if destination.exists() and not overwrite:
            raise FileExistsError(
                f"Refusing to overwrite existing candidate artifact: {destination}"
            )

    onnx, ort = _require_onnx_dependencies()
    model = create_model(
        str(checkpoint["architecture"]),
        len(checkpoint["condition_labels"]),
        pretrained=False,
    )
    model.load_state_dict(checkpoint["model_state"], strict=True)
    # Mark the wrapper itself as evaluation-only. The legacy exporter restores
    # the wrapper's original mode after tracing; if only the child were set to
    # eval, that restoration would reactivate dropout before the parity check.
    wrapper = _ExportModel(model).eval()
    image_size = int(checkpoint["image_size"])
    generator = torch.Generator(device="cpu").manual_seed(20260902)
    sample = torch.randn((1, 3, image_size, image_size), generator=generator)

    file_descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{Path(name).stem}-", suffix=".onnx.tmp", dir=output
    )
    os.close(file_descriptor)
    temporary = Path(temporary_name)
    try:
        torch.onnx.export(
            wrapper,
            (sample,),
            str(temporary),
            export_params=True,
            opset_version=ONNX_OPSET,
            do_constant_folding=True,
            input_names=["image"],
            output_names=["validity_logits", "condition_logits"],
            dynamic_axes=None,
        )
        graph = onnx.load(str(temporary))
        onnx.checker.check_model(graph, full_check=True)
        _assert_onnx_contract(
            graph,
            image_size=image_size,
            condition_count=len(checkpoint["condition_labels"]),
        )
        parity = _verify_onnx_runtime_parity(
            ort,
            temporary,
            wrapper,
            sample,
        )
        if artifact_path.exists():
            artifact_path.unlink()
        temporary.replace(artifact_path)
    finally:
        if temporary.exists():
            temporary.unlink()

    checkpoint_sha = file_sha256(checkpoint_file)
    calibration_sha = file_sha256(calibration_file)
    artifact_sha = file_sha256(artifact_path)
    config = checkpoint.get("config")
    promotion_allowed = (
        bool(config.get("promotion_allowed", False))
        if isinstance(config, Mapping)
        else False
    )
    metadata: dict[str, Any] = {
        "schema_version": EXPORT_SCHEMA_VERSION,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "status": "candidate_not_deployed",
        "artifact": {
            "filename": artifact_path.name,
            "format": "onnx",
            "opset": ONNX_OPSET,
            "bytes": artifact_path.stat().st_size,
            "sha256": artifact_sha,
            "numeric_precision": "float32",
            "quantization": {"mode": "none"},
        },
        "source_checkpoint": {
            "filename": checkpoint_file.name,
            "bytes": checkpoint_file.stat().st_size,
            "sha256": checkpoint_sha,
            "schema_version": checkpoint["schema_version"],
            "epoch": int(checkpoint["epoch"]),
            "best_metric": float(checkpoint["best_metric"]),
            "config_sha256": checkpoint["config_hash"],
            "manifest_sha256": checkpoint["manifest_sha256"],
        },
        "model": {
            "crop": checkpoint["crop"],
            "architecture": checkpoint["architecture"],
            "condition_head_count": len(checkpoint["condition_labels"]),
            "validity_head_count": len(VALIDITY_LABELS),
        },
        "input": {
            "name": "image",
            "shape": [1, 3, image_size, image_size],
            "layout": "NCHW",
            "dtype": "float32",
            "color_order": "RGB",
            "preprocessing_location": "caller",
            "resize": {
                "method": "aspect_preserving_letterbox",
                "width": image_size,
                "height": image_size,
                "preserve_aspect_ratio": True,
                "interpolation": "bilinear",
                "antialias": True,
                "fill_rgb": list(DEFAULT_FILL),
            },
            "normalization": {
                "formula": "(pixel / 255.0 - mean) / std",
                "mean_rgb": list(IMAGENET_MEAN),
                "std_rgb": list(IMAGENET_STD),
            },
        },
        "outputs": [
            {
                "name": "validity_logits",
                "shape": [1, len(VALIDITY_LABELS)],
                "dtype": "float32",
                "activation": "none_raw_logits",
                "labels": list(VALIDITY_LABELS),
            },
            {
                "name": "condition_logits",
                "shape": [1, len(checkpoint["condition_labels"])],
                "dtype": "float32",
                "activation": "none_raw_logits",
                "labels": list(checkpoint["condition_labels"]),
            },
        ],
        "decision_policy": {
            "calibration_filename": calibration_file.name,
            "calibration_sha256": calibration_sha,
            "calibration_manifest_split": calibration["manifest_split"],
            "validity_temperature": float(calibration["validity_temperature"]),
            "condition_temperature": float(calibration["condition_temperature"]),
            "thresholds": dict(calibration["thresholds"]),
            "acceptance_rule": (
                "validity_probability >= validity_probability_min AND "
                "condition_probability >= condition_probability_min AND "
                "condition_energy <= condition_energy_max"
            ),
            "configured_promotion_allowed": promotion_allowed,
            "decision_mode": (
                "promotion_gate_required"
                if promotion_allowed
                else "possible_matches_only"
            ),
        },
        "runtime_validation": {
            "onnx_checker_passed": True,
            "onnxruntime_parity_passed": True,
            **parity,
            "torch_version": torch.__version__,
            "onnx_version": importlib.metadata.version("onnx"),
            "onnxruntime_version": importlib.metadata.version("onnxruntime"),
        },
        "app_compatibility": {
            "compatible_with_current_flutter_runtime": False,
            "current_flutter_runtime": "tflite_flutter_single_output_adapter",
            "required_runtime_contract": "dual_raw_logit_heads_plus_three_signal_gate",
            "blockers": [
                "ONNX is not consumed by the current Flutter TFLite runtime",
                "the app has no adapter for the validity head",
                "this float32 artifact has not passed INT8 equivalence checks",
                "physical Android latency has not been measured",
            ],
        },
        "promotion_evidence": {
            "int8_model_bytes": None,
            "p95_device_inference_ms": None,
            "cold_device_inference_ms": None,
            "eligible_for_deployment_gates": False,
        },
        "limitations": [
            "Interchange export only; this file must not replace an app asset.",
            "Host numerical parity is not physical-device validation.",
            "Calibration is valid only for the checkpoint and manifest hashes recorded above.",
        ],
    }
    write_json_atomic(metadata_path, metadata)
    return {
        "artifact_path": str(artifact_path),
        "metadata_path": str(metadata_path),
        "metadata": metadata,
    }


def benchmark_onnx_host(
    *,
    metadata_path: str | Path,
    output_path: str | Path,
    warmup_iterations: int = 10,
    measured_iterations: int = 100,
    intra_op_threads: int = 1,
) -> dict[str, Any]:
    """Measure a verified ONNX candidate on the development host CPU.

    Results are intentionally namespaced under ``host_benchmark`` and cannot
    satisfy the promotion gate's physical-device latency requirement.
    """

    if warmup_iterations < 0 or measured_iterations <= 0:
        raise DeploymentContractError("benchmark iteration counts are invalid")
    if intra_op_threads <= 0:
        raise DeploymentContractError("intra_op_threads must be positive")
    metadata_file = Path(metadata_path).resolve()
    metadata, artifact = _load_and_verify_export_metadata(metadata_file)
    if metadata["artifact"].get("format") != "onnx":
        raise DeploymentContractError("Host benchmark currently supports ONNX only")
    source_checkpoint = _require_mapping(metadata, "source_checkpoint")
    model_identity = _require_mapping(metadata, "model")
    _, ort = _require_onnx_dependencies()

    options = ort.SessionOptions()
    options.intra_op_num_threads = intra_op_threads
    options.inter_op_num_threads = 1
    options.execution_mode = ort.ExecutionMode.ORT_SEQUENTIAL
    input_shape = [int(value) for value in metadata["input"]["shape"]]
    input_data = np.zeros(input_shape, dtype=np.float32)

    cold_started = time.perf_counter_ns()
    session = ort.InferenceSession(
        str(artifact),
        sess_options=options,
        providers=["CPUExecutionProvider"],
    )
    session.run(None, {"image": input_data})
    cold_ms = (time.perf_counter_ns() - cold_started) / 1_000_000.0
    for _ in range(warmup_iterations):
        session.run(None, {"image": input_data})

    timings: list[float] = []
    for _ in range(measured_iterations):
        started = time.perf_counter_ns()
        outputs = session.run(None, {"image": input_data})
        timings.append((time.perf_counter_ns() - started) / 1_000_000.0)
    if len(outputs) != 2 or any(not np.all(np.isfinite(value)) for value in outputs):
        raise DeploymentContractError("ONNX runtime produced invalid output tensors")

    report = {
        "schema_version": BENCHMARK_SCHEMA_VERSION,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "scope": "development_host_cpu",
        "promotion_gate_eligible": False,
        "reason_not_device_evidence": (
            "Desktop ONNX Runtime timing does not measure the Flutter TFLite "
            "runtime on a physical Android device."
        ),
        "artifact": {
            "filename": artifact.name,
            "sha256": file_sha256(artifact),
            "bytes": artifact.stat().st_size,
            "format": "onnx",
        },
        "source_checkpoint": {
            key: source_checkpoint.get(key)
            for key in ("sha256", "config_sha256", "manifest_sha256")
        },
        "model": {key: model_identity.get(key) for key in ("crop", "architecture")},
        "export_metadata_sha256": file_sha256(metadata_file),
        "runtime": {
            "name": "onnxruntime",
            "version": importlib.metadata.version("onnxruntime"),
            "provider": "CPUExecutionProvider",
            "intra_op_threads": intra_op_threads,
            "inter_op_threads": 1,
        },
        "host": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
            "processor": platform.processor() or None,
            "python": platform.python_version(),
        },
        "input": {"shape": input_shape, "dtype": "float32", "batch_size": 1},
        "host_benchmark": {
            "warmup_iterations": warmup_iterations,
            "measured_iterations": measured_iterations,
            "cold_session_create_plus_first_inference_ms": cold_ms,
            **_timing_summary(timings),
        },
        "deployment": {
            "int8_model_bytes": None,
            "p95_device_inference_ms": None,
            "cold_device_inference_ms": None,
        },
    }
    write_json_atomic(output_path, report)
    return report


def compose_physical_device_evidence(
    *,
    evaluation_path: str | Path,
    export_metadata_path: str | Path,
    device_benchmark_path: str | Path,
    output_path: str | Path,
) -> dict[str, Any]:
    """Attach verified INT8 physical-Android evidence to an evaluation report.

    Raw timing samples are required and summary statistics are recomputed here.
    Float/ONNX artifacts, emulators, mismatched hashes, and self-reported summary
    metrics all fail before a promotion-compatible report can be written.
    """

    evaluation_file = Path(evaluation_path).resolve()
    metadata_file = Path(export_metadata_path).resolve()
    benchmark_file = Path(device_benchmark_path).resolve()
    destination = Path(output_path).resolve()
    if destination in {evaluation_file, metadata_file, benchmark_file}:
        raise DeploymentContractError("Evidence composition must write a new file")
    evaluation = _read_object(evaluation_file, "evaluation report")
    metadata, artifact = _load_and_verify_export_metadata(metadata_file)
    benchmark = _read_object(benchmark_file, "device benchmark")

    artifact_info = _require_mapping(metadata, "artifact")
    quantization = _require_mapping(artifact_info, "quantization")
    app_compatibility = _require_mapping(metadata, "app_compatibility")
    if artifact_info.get("format") != "tflite":
        raise DeploymentContractError(
            "Promotion device evidence requires a TFLite artifact"
        )
    if quantization.get("mode") != "full_integer_int8":
        raise DeploymentContractError(
            "Promotion size evidence requires full-integer INT8"
        )
    if (
        quantization.get("input_dtype") != "int8"
        or quantization.get("output_dtype") != "int8"
    ):
        raise DeploymentContractError(
            "INT8 input and both output tensors must remain integer"
        )
    if app_compatibility.get("compatible_with_current_flutter_runtime") is not True:
        raise DeploymentContractError(
            "Artifact has not passed the Flutter app contract"
        )
    _validate_tflite_metadata_contract(metadata)

    checkpoint = _require_mapping(metadata, "source_checkpoint")
    if evaluation.get("checkpoint_sha256") != checkpoint.get("sha256"):
        raise DeploymentContractError(
            "Evaluation and deployment checkpoint hashes differ"
        )
    model = _require_mapping(metadata, "model")
    if evaluation.get("crop") != model.get("crop") or evaluation.get(
        "architecture"
    ) != model.get("architecture"):
        raise DeploymentContractError("Evaluation and exported model identities differ")
    if evaluation.get("manifest_sha256") != checkpoint.get("manifest_sha256"):
        raise DeploymentContractError(
            "Evaluation and deployment manifest hashes differ"
        )
    policy = _require_mapping(metadata, "decision_policy")
    if evaluation.get("calibration_sha256") != policy.get("calibration_sha256"):
        raise DeploymentContractError(
            "Evaluation and deployment calibration hashes differ"
        )

    if int(benchmark.get("schema_version", 0)) != BENCHMARK_SCHEMA_VERSION:
        raise DeploymentContractError("Unsupported device benchmark schema")
    if benchmark.get("scope") != "physical_android_device":
        raise DeploymentContractError("Latency gate requires a physical Android device")
    if benchmark.get("is_emulator") is not False:
        raise DeploymentContractError(
            "Emulator measurements cannot satisfy the device gate"
        )
    if benchmark.get("artifact_sha256") != artifact_info.get("sha256"):
        raise DeploymentContractError("Device benchmark measured a different artifact")
    runtime = _require_mapping(benchmark, "runtime")
    if runtime.get("name") != "tflite_flutter" or not runtime.get("version"):
        raise DeploymentContractError(
            "Benchmark must use the app's tflite_flutter runtime"
        )
    contract_test = _require_mapping(benchmark, "contract_test")
    if contract_test.get("passed") is not True:
        raise DeploymentContractError(
            "On-device tensor and policy contract test did not pass"
        )
    _validate_observed_device_contract(metadata, contract_test)
    device = _require_mapping(benchmark, "device")
    for key in ("manufacturer", "model", "android_version", "api_level", "abi"):
        if device.get(key) in (None, ""):
            raise DeploymentContractError(f"Device benchmark is missing device.{key}")

    steady = _timing_samples(
        benchmark.get("steady_inference_ms"), "steady_inference_ms"
    )
    cold = _timing_samples(benchmark.get("cold_start_ms"), "cold_start_ms")
    if len(steady) < MINIMUM_STEADY_DEVICE_SAMPLES:
        raise DeploymentContractError(
            f"At least {MINIMUM_STEADY_DEVICE_SAMPLES} steady device samples are required"
        )
    if len(cold) < MINIMUM_COLD_DEVICE_SAMPLES:
        raise DeploymentContractError(
            f"At least {MINIMUM_COLD_DEVICE_SAMPLES} cold device samples are required"
        )

    result = json.loads(json.dumps(evaluation))
    result["deployment"] = {
        "evidence_schema_version": DEPLOYMENT_EVIDENCE_SCHEMA_VERSION,
        "artifact_format": "tflite",
        "artifact_sha256": artifact_info["sha256"],
        "int8_model_bytes": artifact.stat().st_size,
        "p95_device_inference_ms": _nearest_rank_percentile(steady, 0.95),
        "cold_device_inference_ms": max(cold),
        "steady_sample_count": len(steady),
        "cold_sample_count": len(cold),
        "device": dict(device),
        "runtime": dict(runtime),
        "contract_test": dict(contract_test),
        "source_export_metadata_sha256": file_sha256(metadata_file),
        "source_device_benchmark_sha256": file_sha256(benchmark_file),
    }
    write_json_atomic(destination, result)
    return result


def _load_checkpoint(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(path)
    value = torch.load(path, map_location="cpu", weights_only=False)
    if not isinstance(value, dict) or int(value.get("schema_version", 0)) != 1:
        raise DeploymentContractError("Unsupported checkpoint schema")
    required = (
        "epoch",
        "best_metric",
        "model_state",
        "crop",
        "architecture",
        "condition_labels",
        "validity_labels",
        "config_hash",
        "manifest_sha256",
        "image_size",
    )
    missing = [key for key in required if key not in value]
    if missing:
        raise DeploymentContractError(f"Checkpoint is missing keys: {missing}")
    if value["architecture"] not in SUPPORTED_ARCHITECTURES:
        raise DeploymentContractError("Checkpoint architecture is unsupported")
    if not isinstance(value["crop"], str) or not value["crop"]:
        raise DeploymentContractError("Checkpoint crop is invalid")
    labels = value["condition_labels"]
    if (
        not isinstance(labels, list)
        or len(labels) < 2
        or len(set(labels)) != len(labels)
        or any(not isinstance(label, str) or not label for label in labels)
    ):
        raise DeploymentContractError("Checkpoint condition-label order is invalid")
    if value["validity_labels"] != list(VALIDITY_LABELS):
        raise DeploymentContractError("Checkpoint validity-label order changed")
    if not isinstance(value["model_state"], Mapping):
        raise DeploymentContractError("Checkpoint model_state is invalid")
    if int(value["image_size"]) <= 0:
        raise DeploymentContractError("Checkpoint image_size must be positive")
    if isinstance(value["epoch"], bool) or int(value["epoch"]) < 0:
        raise DeploymentContractError("Checkpoint epoch is invalid")
    _finite_number(value["best_metric"], "checkpoint.best_metric")
    for key in ("config_hash", "manifest_sha256"):
        if not _is_sha256(value[key]):
            raise DeploymentContractError(f"Checkpoint {key} is not a SHA-256 digest")
    return value


def _load_calibration(
    path: Path, *, checkpoint: Mapping[str, Any], checkpoint_sha256: str
) -> dict[str, Any]:
    value = _read_object(path, "calibration artifact")
    if type(value.get("schema_version")) is not int or value["schema_version"] != 1:
        raise DeploymentContractError("Unsupported calibration schema")
    if value.get("method") != "scalar_temperature_plus_three_signal_grid_gate":
        raise DeploymentContractError("Unsupported calibration method")
    exact = {
        "checkpoint_sha256": checkpoint_sha256,
        "manifest_sha256": checkpoint["manifest_sha256"],
        "config_sha256": checkpoint["config_hash"],
        "manifest_split": "calibration",
        "crop": checkpoint["crop"],
        "architecture": checkpoint["architecture"],
    }
    for key, expected in exact.items():
        if value.get(key) != expected:
            raise DeploymentContractError(
                f"Calibration {key} does not match checkpoint; expected {expected!r}"
            )
    for key in ("validity_temperature", "condition_temperature"):
        number = _finite_number(value.get(key), f"calibration.{key}")
        if number <= 0:
            raise DeploymentContractError(f"calibration.{key} must be positive")
    thresholds = _require_mapping(value, "thresholds")
    for key in ("validity_probability_min", "condition_probability_min"):
        number = _finite_number(thresholds.get(key), f"thresholds.{key}")
        if not 0.0 <= number <= 1.0:
            raise DeploymentContractError(f"thresholds.{key} must be within [0, 1]")
    _finite_number(
        thresholds.get("condition_energy_max"), "thresholds.condition_energy_max"
    )
    return value


def _require_onnx_dependencies():
    try:
        import onnx
        import onnxruntime as ort
    except ImportError as error:
        raise RuntimeError(
            "ONNX export requires the pinned `onnx` and `onnxruntime` packages "
            "from ml/requirements-train.txt"
        ) from error
    return onnx, ort


def _assert_onnx_contract(graph: Any, *, image_size: int, condition_count: int) -> None:
    inputs = list(graph.graph.input)
    outputs = list(graph.graph.output)
    if [item.name for item in inputs] != ["image"]:
        raise DeploymentContractError("ONNX graph input name changed")
    if [item.name for item in outputs] != ["validity_logits", "condition_logits"]:
        raise DeploymentContractError("ONNX graph output order changed")
    expected = (
        [1, 3, image_size, image_size],
        [1, len(VALIDITY_LABELS)],
        [1, condition_count],
    )
    observed = tuple(_onnx_shape(item) for item in (inputs[0], outputs[0], outputs[1]))
    if observed != expected:
        raise DeploymentContractError(
            f"Unexpected ONNX tensor shapes: observed {observed}, expected {expected}"
        )


def _onnx_shape(value_info: Any) -> list[int]:
    result: list[int] = []
    for dimension in value_info.type.tensor_type.shape.dim:
        if not dimension.HasField("dim_value"):
            raise DeploymentContractError("ONNX graph must use fixed tensor dimensions")
        result.append(int(dimension.dim_value))
    return result


def _verify_onnx_runtime_parity(
    ort: Any, artifact: Path, model: nn.Module, sample: torch.Tensor
) -> dict[str, Any]:
    with torch.inference_mode():
        expected = [value.detach().cpu().numpy() for value in model(sample)]
    session = ort.InferenceSession(str(artifact), providers=["CPUExecutionProvider"])
    observed = session.run(None, {"image": sample.numpy()})
    if len(observed) != 2:
        raise DeploymentContractError(
            "ONNX Runtime returned the wrong number of outputs"
        )
    maximum_absolute = 0.0
    maximum_relative = 0.0
    for wanted, actual in zip(expected, observed, strict=True):
        if wanted.shape != actual.shape or not np.all(np.isfinite(actual)):
            raise DeploymentContractError("ONNX Runtime returned an invalid tensor")
        absolute = np.abs(wanted - actual)
        relative = absolute / np.maximum(np.abs(wanted), 1e-6)
        maximum_absolute = max(maximum_absolute, float(absolute.max(initial=0.0)))
        maximum_relative = max(maximum_relative, float(relative.max(initial=0.0)))
        if not np.allclose(
            wanted,
            actual,
            rtol=ONNX_PARITY_RTOL,
            atol=ONNX_PARITY_ATOL,
        ):
            raise DeploymentContractError(
                "ONNX Runtime outputs differ from the PyTorch checkpoint: "
                f"maximum_absolute_error={maximum_absolute:.9g}, "
                f"maximum_relative_error={maximum_relative:.9g}"
            )
    return {
        "parity_rtol": ONNX_PARITY_RTOL,
        "parity_atol": ONNX_PARITY_ATOL,
        "maximum_absolute_error": maximum_absolute,
        "maximum_relative_error": maximum_relative,
    }


def _load_and_verify_export_metadata(path: Path) -> tuple[dict[str, Any], Path]:
    metadata = _read_object(path, "export metadata")
    if int(metadata.get("schema_version", 0)) != EXPORT_SCHEMA_VERSION:
        raise DeploymentContractError("Unsupported export metadata schema")
    artifact_info = _require_mapping(metadata, "artifact")
    filename = artifact_info.get("filename")
    if not isinstance(filename, str) or Path(filename).name != filename:
        raise DeploymentContractError("Export artifact filename is unsafe")
    artifact = path.parent / filename
    if not artifact.is_file():
        raise FileNotFoundError(artifact)
    if artifact_info.get("sha256") != file_sha256(artifact):
        raise DeploymentContractError("Export artifact SHA-256 mismatch")
    if artifact_info.get("bytes") != artifact.stat().st_size:
        raise DeploymentContractError("Export artifact byte count mismatch")
    return metadata, artifact


def _validate_tflite_metadata_contract(metadata: Mapping[str, Any]) -> None:
    """Validate the mobile tensor contract independently of compatibility flags."""

    source = _require_mapping(metadata, "source_checkpoint")
    for key in ("sha256", "manifest_sha256"):
        if not _is_sha256(source.get(key)):
            raise DeploymentContractError(f"source_checkpoint.{key} is invalid")
    model = _require_mapping(metadata, "model")
    condition_count = model.get("condition_head_count")
    if isinstance(condition_count, bool) or not isinstance(condition_count, int):
        raise DeploymentContractError("model.condition_head_count is invalid")
    if condition_count < 2:
        raise DeploymentContractError(
            "The condition head requires at least two outputs"
        )

    input_tensor = _require_mapping(metadata, "input")
    input_shape = input_tensor.get("shape")
    if (
        not isinstance(input_shape, list)
        or len(input_shape) != 4
        or input_shape[0] != 1
        or input_shape[1] != input_shape[2]
        or input_shape[1] <= 0
        or input_shape[3] != 3
        or input_tensor.get("layout") != "NHWC"
        or input_tensor.get("dtype") != "int8"
    ):
        raise DeploymentContractError(
            "TFLite input must be fixed batch-1 square RGB NHWC int8"
        )
    _validate_int8_quantization(input_tensor, "input")

    outputs = metadata.get("outputs")
    if not isinstance(outputs, list) or len(outputs) != 2:
        raise DeploymentContractError(
            "TFLite metadata must declare exactly two outputs"
        )
    expected = (
        ("validity_logits", [1, len(VALIDITY_LABELS)], list(VALIDITY_LABELS)),
        ("condition_logits", [1, condition_count], None),
    )
    observed_positions: list[int] = []
    for index, (raw, (name, shape, labels)) in enumerate(
        zip(outputs, expected, strict=True)
    ):
        if not isinstance(raw, Mapping):
            raise DeploymentContractError(f"outputs[{index}] must be an object")
        if (
            raw.get("name") != name
            or raw.get("shape") != shape
            or raw.get("dtype") != "int8"
        ):
            raise DeploymentContractError(
                f"outputs[{index}] tensor contract is invalid"
            )
        if labels is not None and raw.get("labels") != labels:
            raise DeploymentContractError("Validity label order changed")
        if labels is None:
            condition_labels = raw.get("labels")
            if (
                not isinstance(condition_labels, list)
                or len(condition_labels) != condition_count
                or len(set(condition_labels)) != condition_count
                or any(
                    not isinstance(label, str) or not label
                    for label in condition_labels
                )
            ):
                raise DeploymentContractError("Condition label order is invalid")
        position = raw.get("position")
        if isinstance(position, bool) or not isinstance(position, int):
            raise DeploymentContractError(f"outputs[{index}].position is invalid")
        observed_positions.append(position)
        _validate_int8_quantization(raw, f"outputs[{index}]")
    if observed_positions != [0, 1]:
        raise DeploymentContractError(
            "TFLite output positions must be explicitly [0, 1]"
        )

    policy = _require_mapping(metadata, "decision_policy")
    if not _is_sha256(policy.get("calibration_sha256")):
        raise DeploymentContractError("decision_policy.calibration_sha256 is invalid")
    for key in ("validity_temperature", "condition_temperature"):
        if _finite_number(policy.get(key), f"decision_policy.{key}") <= 0:
            raise DeploymentContractError(f"decision_policy.{key} must be positive")
    thresholds = _require_mapping(policy, "thresholds")
    for key in (
        "validity_probability_min",
        "condition_probability_min",
        "condition_energy_max",
    ):
        _finite_number(thresholds.get(key), f"decision_policy.thresholds.{key}")


def _validate_observed_device_contract(
    metadata: Mapping[str, Any], contract_test: Mapping[str, Any]
) -> None:
    """Require raw, on-device tensor observations and decision-policy vectors."""

    expected_input = _tensor_signature(_require_mapping(metadata, "input"))
    observed_input = _tensor_signature(_require_mapping(contract_test, "input"))
    if observed_input != expected_input:
        raise DeploymentContractError("On-device input tensor differs from metadata")
    expected_outputs = metadata.get("outputs")
    observed_outputs = contract_test.get("outputs")
    if not isinstance(expected_outputs, list) or not isinstance(observed_outputs, list):
        raise DeploymentContractError(
            "On-device output tensor observations are missing"
        )
    if [_tensor_signature(item) for item in observed_outputs] != [
        _tensor_signature(item) for item in expected_outputs
    ]:
        raise DeploymentContractError("On-device output tensors differ from metadata")
    policy_vectors = _require_mapping(contract_test, "policy_test_vectors")
    count = policy_vectors.get("count")
    if (
        isinstance(count, bool)
        or not isinstance(count, int)
        or count < 3
        or policy_vectors.get("passed") is not True
    ):
        raise DeploymentContractError(
            "At least three on-device acceptance-policy vectors must pass"
        )


def _validate_int8_quantization(value: Mapping[str, Any], name: str) -> None:
    quantization = _require_mapping(value, "quantization")
    if _finite_number(quantization.get("scale"), f"{name}.quantization.scale") <= 0:
        raise DeploymentContractError(f"{name} quantization scale must be positive")
    zero_point = quantization.get("zero_point")
    if (
        isinstance(zero_point, bool)
        or not isinstance(zero_point, int)
        or not -128 <= zero_point <= 127
    ):
        raise DeploymentContractError(f"{name} quantization zero_point is invalid")


def _tensor_signature(value: Any) -> dict[str, Any]:
    if not isinstance(value, Mapping):
        raise DeploymentContractError("Tensor observation must be an object")
    quantization = _require_mapping(value, "quantization")
    return {
        "name": value.get("name"),
        "position": value.get("position"),
        "shape": value.get("shape"),
        "dtype": value.get("dtype"),
        "quantization": {
            "scale": _finite_number(quantization.get("scale"), "tensor scale"),
            "zero_point": quantization.get("zero_point"),
        },
    }


def _reject_app_asset_destination(destination: Path) -> None:
    root = find_repo_root(Path(__file__))
    app_models = (root / "app" / "assets" / "models").resolve()
    if destination == app_models or app_models in destination.parents:
        raise DeploymentContractError(
            "Candidate export cannot write inside app/assets/models; deployment "
            "requires a separate reviewed integration change"
        )


def _read_object(path: Path, description: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise DeploymentContractError(f"Cannot read {description}: {path}") from error
    if not isinstance(value, dict):
        raise DeploymentContractError(
            f"{description.capitalize()} must be a JSON object"
        )
    return value


def _require_mapping(value: Mapping[str, Any], key: str) -> Mapping[str, Any]:
    result = value.get(key)
    if not isinstance(result, Mapping):
        raise DeploymentContractError(f"Missing or invalid object: {key}")
    return result


def _finite_number(value: Any, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        raise DeploymentContractError(f"{name} must be numeric")
    number = float(value)
    if not math.isfinite(number):
        raise DeploymentContractError(f"{name} must be finite")
    return number


def _timing_samples(value: Any, name: str) -> list[float]:
    if not isinstance(value, list):
        raise DeploymentContractError(f"{name} must contain raw timing samples")
    samples = [
        _finite_number(item, f"{name}[{index}]") for index, item in enumerate(value)
    ]
    if any(item <= 0 for item in samples):
        raise DeploymentContractError(f"{name} samples must be positive")
    return samples


def _timing_summary(samples: Sequence[float]) -> dict[str, float]:
    return {
        "mean_ms": statistics.fmean(samples),
        "minimum_ms": min(samples),
        "maximum_ms": max(samples),
        "p50_ms": _nearest_rank_percentile(samples, 0.50),
        "p90_ms": _nearest_rank_percentile(samples, 0.90),
        "p95_ms": _nearest_rank_percentile(samples, 0.95),
        "p99_ms": _nearest_rank_percentile(samples, 0.99),
    }


def _nearest_rank_percentile(samples: Sequence[float], fraction: float) -> float:
    if not samples or not 0.0 < fraction <= 1.0:
        raise DeploymentContractError("Cannot compute percentile")
    ordered = sorted(float(value) for value in samples)
    rank = max(1, math.ceil(fraction * len(ordered)))
    return ordered[rank - 1]


def _is_sha256(value: Any) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(character in "0123456789abcdef" for character in value)
    )
