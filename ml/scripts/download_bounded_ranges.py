"""Checksum-pinned bounded HTTP downloads for hosts that stall long streams.

Uses the existing dataset registry and downloader for final verification,
receipts and safe extraction. Interrupted transfers resume from local bytes.
"""

import argparse
import hashlib
import json
import os
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import requests

ROOT = Path(__file__).resolve().parents[2]


def validate_range(status, header, start, end, size, length):
    expected = f"bytes {start}-{end}/{size}"
    if status != 206 or header != expected or length != end - start + 1:
        raise ValueError(
            f"Invalid range response: {status}, {header}, {length}; expected {expected}"
        )


def fetch(source):
    spec = source["acquisition"]
    size = spec["expected_size"]
    destination = ROOT / "ml/data/raw" / source["id"] / spec["filename"]
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".ranges.part")
    if destination.exists():
        if destination.stat().st_size == size:
            with destination.open("rb") as handle:
                if (
                    hashlib.file_digest(handle, "md5").hexdigest()
                    == spec["expected_md5"]
                ):
                    return str(destination)
        raise ValueError("Existing archive differs; preserve it for inspection")
    start = partial.stat().st_size if partial.exists() else 0
    if start > size:
        raise ValueError("Partial file exceeds expected size")
    with requests.Session() as session, partial.open("ab") as output:
        while start < size:
            end = min(start + 4 * 1024 * 1024, size) - 1
            response = session.get(
                spec["url"], headers={"Range": f"bytes={start}-{end}"}, timeout=(15, 45)
            )
            validate_range(
                response.status_code,
                response.headers.get("Content-Range"),
                start,
                end,
                size,
                len(response.content),
            )
            output.write(response.content)
            output.flush()
            start = end + 1
            print(
                f"{source['id']}: {start}/{size} bytes ({100 * start / size:.1f}%)",
                flush=True,
            )
    with partial.open("rb") as handle:
        if hashlib.file_digest(handle, "md5").hexdigest() != spec["expected_md5"]:
            raise ValueError("Publisher checksum mismatch; partial preserved")
    os.replace(partial, destination)
    return str(destination)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--source", action="append", required=True)
    args = parser.parse_args()
    sources = json.loads(args.manifest.read_text())["sources"]
    selected = [s for s in sources if s["id"] in args.source]
    if len(selected) != len(set(args.source)):
        raise ValueError("Unrecognized or repeated source")
    with ThreadPoolExecutor(max_workers=2) as pool:
        for path in pool.map(fetch, selected):
            print(f"Verified {path}", flush=True)
