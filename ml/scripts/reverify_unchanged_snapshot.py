"""Reverify every image byte while reusing a pinned prior pixel-decode audit.

Only an EXACT unchanged manifest can reuse decode/pHash work. Every current
image is still SHA-256 checked; structural, split and taxonomy checks run again.
The receipt explicitly distinguishes reuse from fresh image decoding.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from pathlib import Path

try:
    from audit_manifest import _read_manifest, audit_manifest
except ImportError:
    from ml.scripts.audit_manifest import _read_manifest, audit_manifest


def digest(path: Path) -> str:
    with path.open("rb") as handle:
        return hashlib.file_digest(handle, "sha256").hexdigest()


def verify_parent(
    receipt_path: Path,
    expected_sha256: str,
    manifest: Path,
    taxonomy: Path,
    aliases: Path,
) -> dict:
    if digest(receipt_path) != expected_sha256:
        raise ValueError("Prior audit receipt hash mismatch")
    parent = json.loads(receipt_path.read_text(encoding="utf-8"))
    if parent.get("status") != "passed" or parent.get("image_verification") is not True:
        raise ValueError("Prior audit must have passed full image verification")
    if parent.get("image_verification_mode") is not None:
        raise ValueError(
            "Reuse must refer directly to a full decode audit, not another cache"
        )
    for key, path in [
        ("manifest", manifest),
        ("taxonomy", taxonomy),
        ("aliases", aliases),
    ]:
        if parent.get(key, {}).get("sha256") != digest(path):
            raise ValueError(f"Prior audit {key} identity mismatch")
    return parent


def verify_image(row: dict, root: Path) -> None:
    path = root / row["image_path"]
    if digest(path) != row["sha256"]:
        raise ValueError(f"Image changed since full decode audit: {row['image_path']}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in [
        "manifest",
        "taxonomy",
        "aliases",
        "config",
        "prior-receipt",
        "output",
    ]:
        parser.add_argument("--" + name, type=Path, required=True)
    parser.add_argument("--expected-prior-sha256", required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    verify_parent(
        args.prior_receipt,
        args.expected_prior_sha256,
        args.manifest,
        args.taxonomy,
        args.aliases,
    )
    rows = _read_manifest(args.manifest)
    print(
        f"Checking all {len(rows)} current image hashes against the pinned decoded snapshot",
        flush=True,
    )
    with ThreadPoolExecutor(max_workers=6) as pool:
        for index, _ in enumerate(
            pool.map(lambda row: verify_image(row, root), rows), 1
        ):
            if index % 5000 == 0:
                print(f"Verified {index}/{len(rows)} image hashes", flush=True)
    summary = audit_manifest(
        args.manifest,
        args.taxonomy,
        aliases_path=args.aliases,
        config_path=args.config,
        verify_images=False,
        image_root=root,
    )
    summary["verified_images"] = len(rows)
    receipt = {
        "schema_version": 1,
        "status": "passed",
        "image_verification": True,
        "image_verification_mode": "all_current_sha256_matched_to_pinned_full_decode_audit",
        "freshly_decoded_images": 0,
        "current_image_hashes_verified": len(rows),
        "near_duplicate_hamming_distance": 4,
        "audited_at_utc": datetime.now(timezone.utc).isoformat(),
        "summary": summary,
        "prior_full_decode_receipt": {
            "path": str(args.prior_receipt.resolve()),
            "sha256": args.expected_prior_sha256,
        },
    }
    for key in ["manifest", "taxonomy", "aliases", "config"]:
        path = getattr(args, key)
        receipt[key] = {"path": str(path.resolve()), "sha256": digest(path)}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    if args.output.exists():
        raise ValueError("Refusing to overwrite an existing audit receipt")
    args.output.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print(f"Content and structural audit passed: {args.output}", flush=True)


if __name__ == "__main__":
    main()
