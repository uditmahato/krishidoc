import json
from pathlib import Path

import pytest

from ml.scripts.reverify_unchanged_snapshot import digest, verify_image, verify_parent


def test_cached_decode_requires_pinned_identity_and_same_manifest(tmp_path: Path):
    paths = {}
    for key in ["manifest", "taxonomy", "aliases"]:
        paths[key] = tmp_path / key
        paths[key].write_text(key)
    receipt = tmp_path / "receipt.json"
    receipt.write_text(
        json.dumps(
            dict(
                status="passed",
                image_verification=True,
                **{k: {"sha256": digest(p)} for k, p in paths.items()},
            )
        )
    )
    sha = digest(receipt)
    verify_parent(receipt, sha, **paths)
    with pytest.raises(ValueError, match="receipt hash"):
        verify_parent(receipt, "bad", **paths)
    paths["manifest"].write_text("changed")
    with pytest.raises(ValueError, match="manifest identity"):
        verify_parent(receipt, sha, **paths)


def test_every_current_image_hash_is_checked(tmp_path: Path):
    path = tmp_path / "image.jpg"
    path.write_bytes(b"fixture")
    row = {"image_path": path.name, "sha256": digest(path)}
    verify_image(row, tmp_path)
    path.write_bytes(b"changed")
    with pytest.raises(ValueError, match="Image changed"):
        verify_image(row, tmp_path)


@pytest.mark.parametrize(
    "change",
    [
        {"image_verification": False},
        {"image_verification_mode": "cached"},
    ],
)
def test_reuse_rejects_unverified_or_chained_receipts(tmp_path: Path, change):
    paths = {}
    for key in ["manifest", "taxonomy", "aliases"]:
        paths[key] = tmp_path / key
        paths[key].write_text(key)
    receipt = tmp_path / "receipt.json"
    receipt.write_text(
        json.dumps(
            {
                "status": "passed",
                "image_verification": True,
                **{key: {"sha256": digest(path)} for key, path in paths.items()},
                **change,
            }
        )
    )
    with pytest.raises(ValueError, match="full image verification|full decode audit"):
        verify_parent(receipt, digest(receipt), **paths)
