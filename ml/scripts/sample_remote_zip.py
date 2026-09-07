"""Acquire a deterministic research subset without downloading entire archives.

HTTP Content-Range and each extracted ZIP member CRC are verified. Whole-archive
MD5 is deliberately NOT claimed verified when only selected members are fetched.
"""

import argparse
import hashlib
import io
import json
import time
import zipfile
from pathlib import Path, PurePosixPath

import requests
from PIL import Image

try:
    from download_bounded_ranges import validate_range
except ImportError:
    from ml.scripts.download_bounded_ranges import validate_range

ROOT = Path(__file__).resolve().parents[2]


class RemoteZip(io.RawIOBase):
    def __init__(self, url, size):
        self.url, self.size, self.position = url, size, 0
        self.session = requests.Session()
        self.cache_start, self.cache = -1, b""
        self.last_request_at = 0.0

    def seekable(self):
        return True

    def readable(self):
        return True

    def seek(self, offset, whence=0):
        self.position = (
            0 if whence == 0 else self.position if whence == 1 else self.size
        ) + offset
        if self.position < 0:
            raise ValueError("Negative seek")
        return self.position

    def tell(self):
        return self.position

    def read(self, count=-1):
        count = (
            self.size - self.position
            if count < 0
            else min(count, self.size - self.position)
        )
        if count <= 0:
            return b""
        start = self.position
        if not (
            self.cache_start <= start
            and start + count <= self.cache_start + len(self.cache)
        ):
            end = min(start + max(count, 262144), self.size) - 1
            response = None
            for attempt in range(4):
                try:
                    time.sleep(
                        max(0.0, 1.0 - (time.monotonic() - self.last_request_at))
                    )
                    self.last_request_at = time.monotonic()
                    response = self.session.get(
                        self.url,
                        headers={"Range": f"bytes={start}-{end}"},
                        timeout=(15, 45),
                    )
                    if response.status_code == 429:
                        delay = max(
                            60 * (attempt + 1),
                            int(response.headers.get("Retry-After", "60")),
                        )
                        print(
                            f"Provider rate limit; backing off {delay} seconds",
                            flush=True,
                        )
                        # Keep sleeps interruptible and never shorten the
                        # provider's Retry-After when it exceeds one minute.
                        while delay > 0:
                            interval = min(30, delay)
                            time.sleep(interval)
                            delay -= interval
                        continue
                    validate_range(
                        response.status_code,
                        response.headers.get("Content-Range"),
                        start,
                        end,
                        self.size,
                        len(response.content),
                    )
                    break
                except (requests.RequestException, ValueError):
                    if attempt == 3:
                        raise
                    time.sleep(2**attempt)
            else:
                raise ValueError("Range request remained rate limited")
            self.cache_start, self.cache = start, response.content
        offset = start - self.cache_start
        result = self.cache[offset : offset + count]
        self.position += len(result)
        return result

    def close(self):
        self.session.close()
        super().close()


def image_member(info):
    """Ignore macOS resource forks: they inherit .jpg but are not images."""
    path = PurePosixPath(info.filename)
    return (
        not info.is_dir()
        and path.suffix.lower() in {".jpg", ".jpeg", ".png"}
        and "__MACOSX" not in path.parts
        and not any(part.startswith("._") for part in path.parts)
    )


def acquire(source, count, inventory_only=False):
    spec = source["acquisition"]
    out = ROOT / "ml/data/raw" / source["id"] / "sampled"
    with (
        RemoteZip(spec["url"], spec["expected_size"]) as stream,
        zipfile.ZipFile(stream) as archive,
    ):
        members = sorted(
            (x for x in archive.infolist() if image_member(x)),
            key=lambda x: x.filename,
        )
        print(
            source["id"],
            "total images",
            len(members),
            "first",
            [(x.filename, x.file_size) for x in members[:5]],
            flush=True,
        )
        if inventory_only:
            return
        if not members or count <= 0:
            raise ValueError("Need images and a positive selection count")
        indices = sorted(
            {
                int(i * (len(members) - 1) / max(1, min(count, len(members)) - 1))
                for i in range(min(count, len(members)))
            }
        )
        out.mkdir(parents=True, exist_ok=True)
        rows = []
        for number, index in enumerate(indices):
            info = members[index]
            name = PurePosixPath(info.filename)
            if (
                name.is_absolute()
                or ".." in name.parts
                or "\\" in info.filename
                or ":" in info.filename
                or info.file_size > 25_000_000
            ):
                raise ValueError("Unsafe or unexpectedly large archive member")
            path = out / f"{index:06d}_{name.name}"
            if path.exists():
                raw = path.read_bytes()
                import zlib

                if len(raw) != info.file_size or zlib.crc32(raw) != info.CRC:
                    raise ValueError("Existing sampled image changed")
            else:
                raw = archive.read(info)  # ZipFile verifies CRC on full member read.
                with Image.open(io.BytesIO(raw)) as decoded:
                    decoded.verify()
                path.write_bytes(raw)
            with Image.open(io.BytesIO(raw)) as decoded:
                decoded.verify()
            rows.append(
                {
                    "file": path.relative_to(ROOT).as_posix(),
                    "member": info.filename,
                    "archive_index": index,
                    "crc32": info.CRC,
                    "sha256": hashlib.sha256(raw).hexdigest(),
                    "bytes": len(raw),
                }
            )
            if number % 10 == 0:
                print(source["id"], f"{number + 1}/{len(indices)}", flush=True)
        receipt = {
            "source": source["id"],
            "source_url": source["landing_url"],
            "archive_url": spec["url"],
            "archive_size": spec["expected_size"],
            "publisher_archive_md5": spec["expected_md5"],
            "whole_archive_checksum_verified": False,
            "member_crc32_verified": True,
            "selection": "equally spaced indices in lexically sorted image-member list; fixed before visual inspection or model predictions",
            "available_image_count": len(members),
            "rows": rows,
        }
        destination = out / "selection_receipt.json"
        encoded = json.dumps(receipt, indent=2) + "\n"
        if destination.exists() and destination.read_text() != encoded:
            raise ValueError("Preserve previous frozen subset receipt")
        destination.write_text(encoded, encoding="utf-8")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--source", required=True)
    parser.add_argument("--count", type=int, default=150)
    parser.add_argument("--inventory-only", action="store_true")
    args = parser.parse_args()
    source = next(
        s
        for s in json.loads(args.manifest.read_text())["sources"]
        if s["id"] == args.source
    )
    acquire(source, args.count, args.inventory_only)
