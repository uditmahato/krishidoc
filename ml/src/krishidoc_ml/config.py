"""Configuration loading and experiment expansion."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any, Iterable


SUPPORTED_ARCHITECTURES = ("mobilenet_v3_large", "efficientnet_b0")


def canonical_json_bytes(value: Any) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def canonical_hash(value: Any) -> str:
    return hashlib.sha256(canonical_json_bytes(value)).hexdigest()


def load_config(path: str | Path) -> dict[str, Any]:
    config_path = Path(path).resolve()
    with config_path.open("r", encoding="utf-8") as handle:
        config = json.load(handle)
    if not isinstance(config, dict):
        raise ValueError(f"Config must be a JSON object: {config_path}")
    if int(config.get("schema_version", 0)) != 1:
        raise ValueError("Only training config schema_version 1 is supported")
    config["_config_path"] = str(config_path)
    return config


def config_for_hash(config: dict[str, Any]) -> dict[str, Any]:
    return {key: value for key, value in config.items() if not key.startswith("_")}


def config_hash(config: dict[str, Any]) -> str:
    return canonical_hash(config_for_hash(config))


def iter_experiments(
    config: dict[str, Any],
    crop_override: str | None = None,
    architecture_override: str | None = None,
) -> Iterable[tuple[str, str]]:
    config_kind = str(config.get("config_kind", "training")).strip()
    if config_kind not in {"", "training"}:
        raise ValueError(
            f"Config kind {config_kind!r} is not a training configuration"
        )
    crops = [crop_override] if crop_override else _as_list(config, "crop", "crops")
    architectures = (
        [architecture_override]
        if architecture_override
        else _as_list(config, "architecture", "candidate_architectures")
    )
    if not crops:
        raise ValueError("Config must specify `crop` or non-empty `crops`")
    if not architectures:
        raise ValueError(
            "Config must specify `architecture` or non-empty "
            "`candidate_architectures`"
        )
    for crop in crops:
        for architecture in architectures:
            if architecture not in SUPPORTED_ARCHITECTURES:
                raise ValueError(
                    f"Unsupported architecture {architecture!r}; expected one of "
                    f"{SUPPORTED_ARCHITECTURES}"
                )
            yield str(crop), str(architecture)


def _as_list(config: dict[str, Any], singular: str, plural: str) -> list[str]:
    if singular in config:
        return [str(config[singular])]
    values = config.get(plural, [])
    if isinstance(values, (str, bytes)):
        raise ValueError(f"`{plural}` must be a list, not a string")
    return [str(value) for value in values]


def condition_labels_for_crop(
    config: dict[str, Any], crop: str, repo_root: str | Path
) -> list[str]:
    explicit = config.get("known_labels")
    configured_crop = config.get("crop")
    if explicit and (configured_crop is None or str(configured_crop) == crop):
        return [str(label) for label in explicit]

    taxonomy_path = Path(
        config.get("taxonomy", Path(repo_root) / "ml" / "datasets" / "taxonomy_v1.json")
    )
    if not taxonomy_path.is_absolute():
        taxonomy_path = Path(repo_root) / taxonomy_path
    with taxonomy_path.open("r", encoding="utf-8") as handle:
        taxonomy = json.load(handle)
    try:
        labels = taxonomy["crops"][crop]["known"]
    except KeyError as error:
        raise ValueError(f"Crop {crop!r} is absent from {taxonomy_path}") from error
    if not labels:
        raise ValueError(f"Crop {crop!r} has no known labels in {taxonomy_path}")
    return [str(label) for label in labels]


def find_repo_root(start: str | Path | None = None) -> Path:
    cursor = Path(start or Path.cwd()).resolve()
    if cursor.is_file():
        cursor = cursor.parent
    for candidate in (cursor, *cursor.parents):
        if (candidate / ".git").exists() and (candidate / "ml").exists():
            return candidate
    raise FileNotFoundError("Could not find repository root containing .git and ml")
