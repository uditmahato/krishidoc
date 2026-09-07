"""Explicit, append-only data ancestry for weights-only fine-tuning."""

import csv
from pathlib import Path

from .receipt import file_sha256


def verify_manifest_extension(
    parent: Path, current: Path, expected_parent_sha256: str
) -> str:
    """Retain every parent row/split; new sources only, no recycled identities.

    This is an ancestry check, NOT a substitute for the full image/near-duplicate
    audit of the combined manifest, which the training pipeline also requires.
    """
    digest = file_sha256(parent)
    if digest != expected_parent_sha256:
        raise ValueError("Parent manifest SHA-256 mismatch")

    def read(path):
        with path.open(encoding="utf-8-sig", newline="") as stream:
            reader = csv.DictReader(stream)
            rows = list(reader)
            fields = reader.fieldnames
        if not rows or not fields or len({r["image_path"] for r in rows}) != len(rows):
            raise ValueError("Empty manifest or duplicate image paths")
        return fields, {r["image_path"]: r for r in rows}

    parent_fields, before = read(parent)
    current_fields, after = read(current)
    if parent_fields != current_fields:
        raise ValueError("Manifest extension schema changed")
    if any(after.get(key) != row for key, row in before.items()):
        raise ValueError("Manifest extension changed or removed a parent row/split")
    additions = [r for key, r in after.items() if key not in before]
    if not additions:
        raise ValueError("Manifest extension contains no new rows")
    for identity in ("sha256", "group_id", "source_id"):
        prior = {r[identity] for r in before.values()}
        if any(r[identity] in prior for r in additions):
            raise ValueError(f"Manifest extension reuses parent {identity}")
    return digest
