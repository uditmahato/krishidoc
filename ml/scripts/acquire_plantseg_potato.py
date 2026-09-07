"""Pin and acquire potato images/masks only from PlantSeg v5 for research.

Publisher split and labels are preserved. CRC/SHA verify individual members,
not the unacquired full archive. Images retain their upstream-rights caveat.
"""

import hashlib
import json
import zipfile
import zlib
from pathlib import PurePosixPath

from sample_remote_zip import ROOT, RemoteZip

URL = "https://zenodo.org/records/14935094/files/plantsegv3.zip?download=1"
SIZE = 1691902086
OUT = ROOT / "ml/data/raw/plantseg-potato-v5"


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with RemoteZip(URL, SIZE) as stream, zipfile.ZipFile(stream) as archive:
        members = sorted(
            [
                x
                for x in archive.infolist()
                if not x.is_dir()
                and PurePosixPath(x.filename).name.startswith("potato_")
                and ("/images/" in x.filename or "/annotations/" in x.filename)
            ],
            key=lambda x: x.header_offset,
        )
        rows = []
        for index, info in enumerate(members):
            name = PurePosixPath(info.filename)
            if (
                name.is_absolute()
                or ".." in name.parts
                or "\\" in info.filename
                or ":" in info.filename
                or len(name.parts) != 4
                or name.parts[0] != "plantsegv3"
                or name.parts[1] not in {"images", "annotations"}
                or name.parts[2] not in {"train", "val", "test"}
                or name.suffix.lower() not in {".jpg", ".png"}
                or info.file_size > 25000000
            ):
                raise ValueError("Unsafe member")
            path = OUT.joinpath(*name.parts[1:])
            path.parent.mkdir(parents=True, exist_ok=True)
            raw = path.read_bytes() if path.exists() else archive.read(info)
            if len(raw) != info.file_size or zlib.crc32(raw) != info.CRC:
                raise ValueError(f"Corrupt member: {name}")
            if not path.exists():
                path.write_bytes(raw)
            rows.append(
                {
                    "member": info.filename,
                    "file": path.relative_to(ROOT).as_posix(),
                    "sha256": hashlib.sha256(raw).hexdigest(),
                    "crc32": info.CRC,
                    "bytes": len(raw),
                }
            )
            if index % 20 == 0:
                print(f"{index + 1}/{len(members)}", flush=True)
        receipt = {
            "source": "plantseg-potato-v5",
            "landing_url": "https://zenodo.org/records/14935094",
            "license": "CC-BY-4.0 as declared by Zenodo; internet images may have upstream rights",
            "archive_url": URL,
            "archive_size": SIZE,
            "publisher_archive_md5": "9458f4fb61d026df1580ce437df0b63a",
            "whole_archive_checksum_verified": False,
            "member_crc32_verified": True,
            "selection": "All potato-prefixed images and masks, preserving original splits; before predictions",
            "rows": rows,
        }
        encoded = json.dumps(receipt, indent=2) + "\n"
        target = OUT / "acquisition_receipt.json"
        if target.exists() and target.read_text(encoding="utf-8") != encoded:
            raise ValueError("Receipt changed")
        target.write_text(encoded, encoding="utf-8")
        print(f"Complete: {len(rows)} members", flush=True)


if __name__ == "__main__":
    main()
