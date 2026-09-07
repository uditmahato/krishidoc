#!/usr/bin/env python3
"""Stage rights-aware Open Images V7 candidates for manual non-plant review.

The selector is intentionally fail-closed: it filters human-positive labels and
object boxes, but never emits a ``non_plant`` training label. Open Images labels
are not exhaustive, so every candidate remains ``manual_review_required`` and
outside the active model manifest until a human reviews the complete frame.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import csv
import dataclasses
import datetime as dt
import hashlib
import json
import os
from pathlib import Path
import re
from typing import Any, Callable, Iterable, Mapping, Sequence
import urllib.request


SCRIPT_PATH = Path(__file__).resolve()
ML_ROOT = SCRIPT_PATH.parents[1]
DEFAULT_POLICY = ML_ROOT / "datasets" / "openimages_negative_policy_v1.json"
DEFAULT_OUTPUT = ML_ROOT / "data" / "raw" / "openimages-v7-nonplant-candidates"
USER_AGENT = "KrishiDoc-OpenImages-negative-staging/1.0"
SELECTION_COLUMNS = (
    "image_id",
    "split",
    "primary_object_label",
    "primary_object_mid",
    "primary_box_area",
    "positive_labels",
    "official_download_url",
    "original_url",
    "original_landing_url",
    "license_url",
    "author_profile_url",
    "author",
    "title",
    "original_size",
    "original_md5_base64",
    "rotation",
    "review_status",
    "admission_status",
    "intended_review_outcome",
    "local_path",
    "bytes",
    "sha256",
    "download_status",
)


class StagingError(RuntimeError):
    """Raised when source metadata or a staged candidate is unsafe/invalid."""


@dataclasses.dataclass(frozen=True)
class BoxCandidate:
    image_id: str
    label_mid: str
    label_name: str
    area: float


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_policy(path: Path) -> dict[str, Any]:
    try:
        policy = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise StagingError(f"Cannot read policy {path}: {error}") from error
    if policy.get("schema_version") != 1:
        raise StagingError("Open Images policy must use schema_version 1")
    if policy.get("review_status") != "manual_review_required":
        raise StagingError("Policy must fail closed as manual_review_required")
    if policy.get("admission_status") != "staged_not_admitted":
        raise StagingError("Policy must keep candidates outside active manifests")
    urls = policy.get("metadata_urls")
    if not isinstance(urls, dict) or set(urls) != {
        "class_descriptions",
        "human_image_labels",
        "bounding_boxes",
        "image_information",
    }:
        raise StagingError("Policy must define the four official metadata URLs")
    if not all(str(url).startswith("https://") for url in urls.values()):
        raise StagingError("All metadata URLs must use HTTPS")
    if not policy.get("target_box_labels") or not policy.get("blocked_label_terms"):
        raise StagingError("Policy requires target labels and blocked label terms")
    return policy


def normalized_words(value: str) -> str:
    return " ".join(re.findall(r"[a-z0-9]+", value.casefold()))


def is_blocked_label(label: str, blocked_terms: Iterable[str]) -> bool:
    normalized = normalized_words(label)
    padded = f" {normalized} "
    label_tokens = normalized.split()
    for term in blocked_terms:
        blocked = normalized_words(term)
        if not blocked:
            continue
        if " " in blocked and f" {blocked} " in padded:
            return True
        if " " not in blocked and any(blocked in token for token in label_tokens):
            # Compound class names such as ``Houseplant`` and ``Cornfield``
            # must not evade the conservative screen. False exclusions are
            # preferable to admitting an unsafe negative candidate.
            return True
    return False


def _urlopen(request: urllib.request.Request, timeout: float):
    return urllib.request.urlopen(request, timeout=timeout)


def download_url(
    url: str,
    destination: Path,
    *,
    timeout: float = 120.0,
    opener: Callable[..., Any] = _urlopen,
) -> dict[str, Any]:
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = destination.with_suffix(destination.suffix + ".part")
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    digest = hashlib.sha256()
    size = 0
    try:
        with opener(request, timeout) as response, temporary.open("wb") as output:
            for chunk in iter(lambda: response.read(1024 * 1024), b""):
                output.write(chunk)
                digest.update(chunk)
                size += len(chunk)
        os.replace(temporary, destination)
    except Exception:
        temporary.unlink(missing_ok=True)
        raise
    return {
        "url": url,
        "path": destination.as_posix(),
        "bytes": size,
        "sha256": digest.hexdigest(),
    }


def fetch_metadata(
    policy: Mapping[str, Any],
    metadata_dir: Path,
    *,
    force: bool = False,
    opener: Callable[..., Any] = _urlopen,
) -> list[dict[str, Any]]:
    metadata_dir.mkdir(parents=True, exist_ok=True)
    results: list[dict[str, Any]] = []
    for key, url in sorted(policy["metadata_urls"].items()):
        destination = metadata_dir / f"{key}.csv"
        if destination.exists() and not force:
            results.append(
                {
                    "url": url,
                    "path": destination.as_posix(),
                    "bytes": destination.stat().st_size,
                    "sha256": sha256_file(destination),
                    "reused": True,
                }
            )
            continue
        result = download_url(url, destination, opener=opener)
        result["reused"] = False
        results.append(result)
    return results


def read_class_descriptions(path: Path) -> dict[str, str]:
    classes: dict[str, str] = {}
    with path.open("r", encoding="utf-8", newline="") as stream:
        for row in csv.reader(stream):
            if len(row) < 2:
                continue
            classes[row[0].strip()] = row[1].strip()
    if not classes:
        raise StagingError(f"No class descriptions found in {path}")
    return classes


def read_positive_labels(
    path: Path,
    classes: Mapping[str, str],
) -> dict[str, set[str]]:
    positives: dict[str, set[str]] = {}
    with path.open("r", encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        required = {"ImageID", "LabelName", "Confidence"}
        if not required <= set(reader.fieldnames or ()):
            raise StagingError(f"Image label CSV is missing {sorted(required)}")
        for row in reader:
            if row["Confidence"].strip() != "1":
                continue
            mid = row["LabelName"].strip()
            positives.setdefault(row["ImageID"].strip(), set()).add(
                classes.get(mid, mid)
            )
    return positives


def read_box_candidates(
    path: Path,
    classes: Mapping[str, str],
    target_labels: Iterable[str],
    minimum_area: float,
) -> list[BoxCandidate]:
    targets = {normalized_words(label) for label in target_labels}
    best: dict[tuple[str, str], BoxCandidate] = {}
    with path.open("r", encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        required = {
            "ImageID",
            "LabelName",
            "XMin",
            "XMax",
            "YMin",
            "YMax",
            "IsGroupOf",
            "IsDepiction",
            "IsInside",
        }
        if not required <= set(reader.fieldnames or ()):
            raise StagingError(f"Bounding-box CSV is missing {sorted(required)}")
        for row in reader:
            mid = row["LabelName"].strip()
            name = classes.get(mid, mid)
            if normalized_words(name) not in targets:
                continue
            if any(row.get(flag, "0").strip() == "1" for flag in ("IsGroupOf", "IsDepiction", "IsInside")):
                continue
            try:
                area = (float(row["XMax"]) - float(row["XMin"])) * (
                    float(row["YMax"]) - float(row["YMin"])
                )
            except ValueError:
                continue
            if not minimum_area <= area <= 1.0:
                continue
            candidate = BoxCandidate(row["ImageID"].strip(), mid, name, area)
            key = (candidate.image_id, normalized_words(candidate.label_name))
            if key not in best or candidate.area > best[key].area:
                best[key] = candidate
    return list(best.values())


def read_image_information(path: Path) -> dict[str, dict[str, str]]:
    result: dict[str, dict[str, str]] = {}
    with path.open("r", encoding="utf-8", newline="") as stream:
        reader = csv.DictReader(stream)
        required = {
            "ImageID",
            "Subset",
            "OriginalURL",
            "OriginalLandingURL",
            "License",
            "Author",
        }
        if not required <= set(reader.fieldnames or ()):
            raise StagingError(f"Image-information CSV is missing {sorted(required)}")
        for row in reader:
            result[row["ImageID"].strip()] = {key: (value or "").strip() for key, value in row.items()}
    return result


def stable_key(seed: int, image_id: str) -> str:
    return hashlib.sha256(f"{seed}:{image_id}".encode("utf-8")).hexdigest()


def select_candidates(
    *,
    policy: Mapping[str, Any],
    classes: Mapping[str, str],
    positives: Mapping[str, set[str]],
    boxes: Sequence[BoxCandidate],
    image_information: Mapping[str, Mapping[str, str]],
    limit: int,
) -> list[dict[str, str]]:
    if limit <= 0:
        raise StagingError("limit must be positive")
    blocked_terms = tuple(str(value) for value in policy["blocked_label_terms"])
    accepted_licenses = set(policy["accepted_pixel_license_urls"])
    seed = int(policy["selection_seed"])
    split = str(policy["split"])
    url_template = str(policy["official_image_url_template"])
    review_status = str(policy["review_status"])
    admission_status = str(policy["admission_status"])

    best_by_image: dict[str, BoxCandidate] = {}
    for candidate in boxes:
        labels = positives.get(candidate.image_id, set()) | {candidate.label_name}
        if any(is_blocked_label(label, blocked_terms) for label in labels):
            continue
        info = image_information.get(candidate.image_id)
        if not info or info.get("Subset") != split:
            continue
        if info.get("License") not in accepted_licenses:
            continue
        if not info.get("OriginalLandingURL") or not info.get("Author"):
            continue
        previous = best_by_image.get(candidate.image_id)
        if previous is None or (candidate.area, candidate.label_name) > (
            previous.area,
            previous.label_name,
        ):
            best_by_image[candidate.image_id] = candidate

    buckets: dict[str, list[BoxCandidate]] = {}
    for candidate in best_by_image.values():
        buckets.setdefault(candidate.label_name, []).append(candidate)
    for label in buckets:
        buckets[label].sort(key=lambda item: (-item.area, stable_key(seed, item.image_id)))

    max_per_class = int(policy["max_per_primary_class"])
    selected: list[BoxCandidate] = []
    labels = sorted(buckets)
    position = 0
    while len(selected) < limit:
        progress = False
        for label in labels:
            bucket = buckets[label]
            if position < min(len(bucket), max_per_class):
                selected.append(bucket[position])
                progress = True
                if len(selected) == limit:
                    break
        if not progress:
            break
        position += 1

    rows: list[dict[str, str]] = []
    for candidate in selected:
        info = image_information[candidate.image_id]
        labels_for_image = sorted(positives.get(candidate.image_id, set()) | {candidate.label_name})
        rows.append(
            {
                "image_id": candidate.image_id,
                "split": split,
                "primary_object_label": candidate.label_name,
                "primary_object_mid": candidate.label_mid,
                "primary_box_area": f"{candidate.area:.8f}",
                "positive_labels": " | ".join(labels_for_image),
                "official_download_url": url_template.format(image_id=candidate.image_id),
                "original_url": info.get("OriginalURL", ""),
                "original_landing_url": info.get("OriginalLandingURL", ""),
                "license_url": info.get("License", ""),
                "author_profile_url": info.get("AuthorProfileURL", ""),
                "author": info.get("Author", ""),
                "title": info.get("Title", ""),
                "original_size": info.get("OriginalSize", ""),
                "original_md5_base64": info.get("OriginalMD5", ""),
                "rotation": info.get("Rotation", ""),
                "review_status": review_status,
                "admission_status": admission_status,
                "intended_review_outcome": "non_plant_candidate_only",
                "local_path": f"images/{candidate.image_id}.jpg",
                "bytes": "",
                "sha256": "",
                "download_status": "selected_not_downloaded",
            }
        )
    return rows


def write_selection(path: Path, rows: Sequence[Mapping[str, str]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".part")
    with temporary.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(stream, fieldnames=SELECTION_COLUMNS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    os.replace(temporary, path)


def download_candidates(
    rows: Sequence[Mapping[str, str]],
    output_root: Path,
    *,
    workers: int,
    opener: Callable[..., Any] = _urlopen,
) -> list[dict[str, str]]:
    if workers <= 0:
        raise StagingError("workers must be positive")
    images_dir = output_root / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    def fetch(row: Mapping[str, str]) -> dict[str, str]:
        updated = dict(row)
        destination = output_root / row["local_path"]
        if destination.exists():
            size = destination.stat().st_size
            digest = sha256_file(destination)
            status = "reused_verified"
        else:
            receipt = download_url(row["official_download_url"], destination, opener=opener)
            size = int(receipt["bytes"])
            digest = str(receipt["sha256"])
            status = "downloaded_verified"
        updated["bytes"] = str(size)
        updated["sha256"] = digest
        updated["download_status"] = status
        return updated

    completed: list[dict[str, str]] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(fetch, row) for row in rows]
        for future in concurrent.futures.as_completed(futures):
            completed.append(future.result())
    completed.sort(key=lambda row: row["image_id"])
    return completed


def write_receipt(
    path: Path,
    *,
    policy_path: Path,
    policy: Mapping[str, Any],
    metadata: Sequence[Mapping[str, Any]],
    rows: Sequence[Mapping[str, str]],
) -> dict[str, Any]:
    class_counts: dict[str, int] = {}
    status_counts: dict[str, int] = {}
    total_bytes = 0
    for row in rows:
        class_counts[row["primary_object_label"]] = class_counts.get(row["primary_object_label"], 0) + 1
        status_counts[row["download_status"]] = status_counts.get(row["download_status"], 0) + 1
        total_bytes += int(row.get("bytes") or 0)
        if row.get("review_status") != "manual_review_required":
            raise StagingError("Every candidate must remain manual_review_required")
        if row.get("admission_status") != "staged_not_admitted":
            raise StagingError("Every candidate must remain staged_not_admitted")
    receipt = {
        "schema_version": 1,
        "created_at": utc_now(),
        "source_id": policy["source_id"],
        "dataset_version": policy["dataset_version"],
        "source_documentation": "https://storage.googleapis.com/openimages/web/download_v7.html",
        "policy": {
            "path": policy_path.as_posix(),
            "sha256": sha256_file(policy_path),
        },
        "metadata": list(metadata),
        "candidate_count": len(rows),
        "candidate_bytes": total_bytes,
        "class_counts": dict(sorted(class_counts.items())),
        "download_status_counts": dict(sorted(status_counts.items())),
        "annotation_license": policy["annotation_license"],
        "pixel_licenses": sorted({row["license_url"] for row in rows}),
        "manual_review_required": True,
        "ready_for_manifest": False,
        "assigned_training_label": None,
        "safety_note": policy["safety_note"],
        "rights_note": (
            "Open Images states that images are listed as CC BY 2.0 but provides no "
            "warranty. Verify each original landing page and attribution before release."
        ),
    }
    path.write_text(json.dumps(receipt, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return receipt


def stage(args: argparse.Namespace) -> int:
    policy_path = args.policy.resolve()
    policy = load_policy(policy_path)
    output_root = args.output.resolve()
    metadata_dir = output_root / "metadata"
    metadata = fetch_metadata(policy, metadata_dir, force=args.force_metadata)
    classes = read_class_descriptions(metadata_dir / "class_descriptions.csv")
    positives = read_positive_labels(metadata_dir / "human_image_labels.csv", classes)
    boxes = read_box_candidates(
        metadata_dir / "bounding_boxes.csv",
        classes,
        policy["target_box_labels"],
        float(policy["minimum_primary_box_area"]),
    )
    information = read_image_information(metadata_dir / "image_information.csv")
    rows = select_candidates(
        policy=policy,
        classes=classes,
        positives=positives,
        boxes=boxes,
        image_information=information,
        limit=args.limit or int(policy["default_limit"]),
    )
    if not rows:
        raise StagingError("Conservative selection produced no candidates")
    selection_path = output_root / "candidates.csv"
    write_selection(selection_path, rows)
    if not args.select_only:
        rows = download_candidates(rows, output_root, workers=args.workers)
        write_selection(selection_path, rows)
    receipt = write_receipt(
        output_root / "receipt.json",
        policy_path=policy_path,
        policy=policy,
        metadata=metadata,
        rows=rows,
    )
    print(
        json.dumps(
            {
                "output": output_root.as_posix(),
                "candidates": receipt["candidate_count"],
                "download_status_counts": receipt["download_status_counts"],
                "manual_review_required": True,
                "ready_for_manifest": False,
            },
            indent=2,
        )
    )
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--policy", type=Path, default=DEFAULT_POLICY)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--limit", type=int)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--select-only", action="store_true")
    parser.add_argument("--force-metadata", action="store_true")
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    return stage(build_parser().parse_args(argv))


if __name__ == "__main__":
    raise SystemExit(main())
