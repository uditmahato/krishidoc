"""Machine- and source-verifiable run receipts."""

from __future__ import annotations

import hashlib
import importlib.metadata
import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import torch

from .config import canonical_hash, config_for_hash


def file_sha256(path: str | Path) -> str:
    digest = hashlib.sha256()
    with Path(path).open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def package_inventory() -> dict[str, str]:
    packages: dict[str, str] = {}
    for distribution in importlib.metadata.distributions():
        name = distribution.metadata.get("Name")
        if name:
            packages[name.lower()] = distribution.version
    return dict(sorted(packages.items()))


def create_run_receipt(
    *,
    repo_root: str | Path,
    config: dict[str, Any],
    manifest_path: str | Path,
    crop: str,
    architecture: str,
    seed: int,
    device: torch.device,
    extra_files: dict[str, str | Path] | None = None,
) -> dict[str, Any]:
    root = Path(repo_root).resolve()
    packages = package_inventory()
    git_head = _git(root, ["rev-parse", "HEAD"])
    git_status = _git(root, ["status", "--porcelain=v1", "--untracked-files=all"])
    cuda: dict[str, Any] = {
        "available": torch.cuda.is_available(),
        "torch_cuda_version": torch.version.cuda,
        "cudnn_version": torch.backends.cudnn.version(),
        "device_count": torch.cuda.device_count(),
    }
    if device.type == "cuda" and torch.cuda.is_available():
        index = device.index if device.index is not None else torch.cuda.current_device()
        properties = torch.cuda.get_device_properties(index)
        cuda["selected_device"] = {
            "index": index,
            "name": properties.name,
            "total_memory_bytes": properties.total_memory,
            "compute_capability": [properties.major, properties.minor],
        }
    file_hashes = {
        name: file_sha256(path) for name, path in (extra_files or {}).items()
    }
    return {
        "schema_version": 1,
        "created_at_utc": datetime.now(timezone.utc).isoformat(),
        "crop": crop,
        "architecture": architecture,
        "seed": int(seed),
        "command": sys.argv,
        "working_directory": str(Path.cwd().resolve()),
        "git": {
            "head": git_head.strip() or None,
            "dirty": bool(git_status.strip()),
            "status_sha256": hashlib.sha256(git_status.encode("utf-8")).hexdigest(),
            "status_entry_count": len(git_status.splitlines()),
        },
        "python": {
            "version": sys.version,
            "implementation": platform.python_implementation(),
            "executable": sys.executable,
        },
        "platform": {
            "system": platform.system(),
            "release": platform.release(),
            "machine": platform.machine(),
        },
        "torch": {
            "version": torch.__version__,
            "deterministic_algorithms": torch.are_deterministic_algorithms_enabled(),
        },
        "cuda": cuda,
        "config_sha256": canonical_hash(config_for_hash(config)),
        "manifest_sha256": file_sha256(manifest_path),
        "package_inventory": packages,
        "package_inventory_sha256": canonical_hash(packages),
        "extra_file_sha256": file_hashes,
        "environment_flags": {
            "PYTHONHASHSEED": os.environ.get("PYTHONHASHSEED"),
            "CUBLAS_WORKSPACE_CONFIG": os.environ.get("CUBLAS_WORKSPACE_CONFIG"),
        },
    }


def write_json_atomic(path: str | Path, value: Any) -> None:
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".tmp")
    with temporary.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, indent=2, sort_keys=True)
        handle.write("\n")
    temporary.replace(destination)


def _git(root: Path, arguments: list[str]) -> str:
    try:
        result = subprocess.run(
            ["git", *arguments],
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
            timeout=15,
        )
        return result.stdout if result.returncode == 0 else ""
    except (OSError, subprocess.SubprocessError):
        return ""
