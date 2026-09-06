#!/usr/bin/env python3
"""Acquire versioned KrishiDoc datasets with provenance and integrity receipts.

The downloader intentionally has no third-party Python dependencies. It supports
checksum-pinned HTTP files, Figshare article files, Mendeley Data's anonymous
public file/folder API or download-all ZIP endpoint, and public Git repositories
including GitHub and Hugging Face Git/LFS. Raw data is written below ``ml/data/``,
which is ignored by Git.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime as dt
import fnmatch
import hashlib
import http.client
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import time
from typing import Any, Callable, Iterable, Mapping, Sequence
import urllib.error
import urllib.parse
import urllib.request
import uuid
import zipfile


SCRIPT_PATH = Path(__file__).resolve()
ML_ROOT = SCRIPT_PATH.parents[1]
REPO_ROOT = ML_ROOT.parent
DEFAULT_MANIFEST = ML_ROOT / "datasets" / "sources.json"
USER_AGENT = "KrishiDoc-dataset-acquisition/1.0"
SAFE_SOURCE_ID = re.compile(r"^[a-z0-9][a-z0-9._-]*$")
SAFE_AUTOMATIC_STATUSES = {"preferred", "lab_derivative"}
REVIEW_STATUSES = {"review_required", "license_review", "holdout_locked"}
NON_DOWNLOADABLE_STATUSES = {"external_locked", "excluded"}


class AcquisitionError(RuntimeError):
    """Raised when acquisition cannot proceed safely or reproducibly."""


@dataclasses.dataclass(frozen=True)
class RemoteFile:
    """A remotely hosted file and the integrity metadata known before download."""

    relative_path: str
    url: str
    expected_size: int | None = None
    expected_sha256: str | None = None
    expected_md5: str | None = None
    provider_id: str | int | None = None
    provider_metadata: Mapping[str, Any] = dataclasses.field(default_factory=dict)


@dataclasses.dataclass(frozen=True)
class DownloadResult:
    """Verified local result returned by :func:`download_http`."""

    path: Path
    size: int
    sha256: str
    md5: str
    reused: bool
    resumed_from: int
    final_url: str


def _make_inheriting_temp_directory(parent: Path, prefix: str) -> Path:
    """Create a collision-resistant staging directory with normal parent ACLs.

    ``tempfile.mkdtemp`` deliberately applies a private ACL on recent Windows
    Python releases. That ACL survives ``os.replace`` and can make an
    extracted dataset unreadable to the non-elevated training process. A
    randomly named directory created with the platform's normal mkdir mode
    inherits the repository data directory ACL while remaining unguessable.
    """

    parent.mkdir(parents=True, exist_ok=True)
    for _ in range(100):
        candidate = parent / f"{prefix}{uuid.uuid4().hex}"
        try:
            candidate.mkdir()
        except FileExistsError:
            continue
        return candidate
    raise AcquisitionError(f"Could not allocate a staging directory below {parent}")


JsonFetcher = Callable[[str], Any]


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat().replace("+00:00", "Z")


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        manifest = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise AcquisitionError(f"Cannot read manifest {path}: {exc}") from exc
    validate_manifest(manifest)
    return manifest


def validate_manifest(manifest: Mapping[str, Any]) -> None:
    if manifest.get("schema_version") != 1:
        raise AcquisitionError("sources.json must use schema_version 1")
    sources = manifest.get("sources")
    if not isinstance(sources, list) or not sources:
        raise AcquisitionError("sources.json must contain a non-empty sources list")

    seen: set[str] = set()
    for source in sources:
        if not isinstance(source, dict):
            raise AcquisitionError("Every source entry must be an object")
        source_id = source.get("id")
        if not isinstance(source_id, str) or not SAFE_SOURCE_ID.fullmatch(source_id):
            raise AcquisitionError(f"Invalid source id: {source_id!r}")
        if source_id in seen:
            raise AcquisitionError(f"Duplicate source id: {source_id}")
        seen.add(source_id)

        status = source.get("status")
        if status in NON_DOWNLOADABLE_STATUSES:
            if source.get("default_selected"):
                raise AcquisitionError(f"Blocked source {source_id} cannot be selected by default")
        elif status not in SAFE_AUTOMATIC_STATUSES | REVIEW_STATUSES:
            raise AcquisitionError(f"Unknown status {status!r} for {source_id}")

        acquisition = source.get("acquisition")
        if not isinstance(acquisition, dict) or not acquisition.get("provider"):
            raise AcquisitionError(f"Missing acquisition provider for {source_id}")
        provider = acquisition["provider"]
        if provider == "mendeley":
            if not acquisition.get("dataset_id") or not isinstance(acquisition.get("version"), int):
                raise AcquisitionError(f"Mendeley source {source_id} needs dataset_id and integer version")
        elif provider == "figshare":
            if not isinstance(acquisition.get("article_id"), int):
                raise AcquisitionError(f"Figshare source {source_id} needs integer article_id")
        elif provider in {"github", "git", "huggingface"}:
            if not acquisition.get("repository") or not acquisition.get("ref"):
                raise AcquisitionError(f"Git source {source_id} needs repository and ref")
        elif provider == "http":
            url = acquisition.get("url")
            filename = acquisition.get("filename")
            if not isinstance(url, str) or not url.startswith("https://") or not filename:
                raise AcquisitionError(f"HTTP source {source_id} needs an HTTPS url and filename")
            safe_relative_path(str(filename))
            expected_size = acquisition.get("expected_size")
            if expected_size is not None and (not isinstance(expected_size, int) or expected_size < 0):
                raise AcquisitionError(f"HTTP source {source_id} has invalid expected_size")
            expected_sha256 = acquisition.get("expected_sha256")
            if expected_sha256 is not None and not re.fullmatch(r"[0-9a-fA-F]{64}", str(expected_sha256)):
                raise AcquisitionError(f"HTTP source {source_id} has invalid expected_sha256")
        elif provider != "manual":
            raise AcquisitionError(f"Unsupported provider {provider!r} for {source_id}")


def manifest_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fetch_json(url: str, *, timeout: float = 60.0, opener: Callable[..., Any] | None = None) -> Any:
    request = urllib.request.Request(
        url,
        headers={
            "Accept": "application/json, application/vnd.mendeley-public-dataset.1+json",
            "User-Agent": USER_AGENT,
        },
    )
    open_url = opener or urllib.request.urlopen
    try:
        with open_url(request, timeout=timeout) as response:
            raw = response.read()
    except (OSError, urllib.error.URLError) as exc:
        raise AcquisitionError(f"Metadata request failed for {url}: {exc}") from exc
    try:
        return json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise AcquisitionError(f"Metadata endpoint did not return valid JSON: {url}") from exc


def _json_list(payload: Any, *, endpoint: str) -> list[dict[str, Any]]:
    if isinstance(payload, dict) and isinstance(payload.get("results"), list):
        payload = payload["results"]
    if not isinstance(payload, list):
        raise AcquisitionError(f"Expected a JSON list from {endpoint}, got {type(payload).__name__}")
    if not all(isinstance(item, dict) for item in payload):
        raise AcquisitionError(f"Expected object entries from {endpoint}")
    return payload


def safe_relative_path(value: str) -> str:
    """Return a normalized relative POSIX path, rejecting traversal and drives."""

    if not isinstance(value, str) or not value or "\x00" in value:
        raise AcquisitionError(f"Unsafe empty or NUL-containing path: {value!r}")
    normalized = value.replace("\\", "/")
    path = PurePosixPath(normalized)
    parts = [part for part in path.parts if part not in {"", "."}]
    if path.is_absolute() or not parts or any(part == ".." for part in parts):
        raise AcquisitionError(f"Unsafe relative path: {value!r}")
    if re.fullmatch(r"[A-Za-z]:", parts[0]):
        raise AcquisitionError(f"Drive-qualified path is not allowed: {value!r}")
    return PurePosixPath(*parts).as_posix()


def receipt_url(value: str) -> str:
    """Strip query credentials and fragments from a URL before persisting it."""

    parsed = urllib.parse.urlsplit(value)
    hostname = parsed.hostname or ""
    port = f":{parsed.port}" if parsed.port else ""
    netloc = f"{hostname}{port}"
    return urllib.parse.urlunsplit((parsed.scheme, netloc, parsed.path, "", ""))


def build_mendeley_folder_paths(folders: Sequence[Mapping[str, Any]]) -> dict[str, str]:
    """Reconstruct stable relative paths from Mendeley's flat folder graph."""

    by_id: dict[str, Mapping[str, Any]] = {}
    for folder in folders:
        folder_id = folder.get("id")
        if not isinstance(folder_id, str) or not folder_id:
            raise AcquisitionError("Mendeley folder is missing an id")
        if folder_id in by_id:
            raise AcquisitionError(f"Duplicate Mendeley folder id: {folder_id}")
        by_id[folder_id] = folder

    resolved: dict[str, str] = {}

    def resolve(folder_id: str, active: set[str]) -> str:
        if folder_id in resolved:
            return resolved[folder_id]
        if folder_id in active:
            raise AcquisitionError(f"Cycle in Mendeley folder graph at {folder_id}")
        folder = by_id[folder_id]
        name = safe_relative_path(str(folder.get("name", "")))
        if "/" in name:
            raise AcquisitionError(f"Mendeley folder name contains a path separator: {name!r}")
        parent_id = folder.get("parent_id")
        if parent_id in {None, "", "root"}:
            result = name
        else:
            if not isinstance(parent_id, str) or parent_id not in by_id:
                raise AcquisitionError(f"Folder {folder_id} references unknown parent {parent_id!r}")
            result = f"{resolve(parent_id, active | {folder_id})}/{name}"
        resolved[folder_id] = safe_relative_path(result)
        return resolved[folder_id]

    for item_id in by_id:
        resolve(item_id, set())

    folded: dict[str, str] = {}
    for item_id, path in resolved.items():
        key = path.casefold()
        if key in folded:
            raise AcquisitionError(f"Case-insensitive Mendeley folder collision: {path!r} and {folded[key]!r}")
        folded[key] = path
    return resolved


def _pattern_prefix(pattern: str) -> str:
    normalized = pattern.replace("\\", "/")
    wildcard_at = min((normalized.find(char) for char in "*?[" if char in normalized), default=len(normalized))
    return normalized[:wildcard_at].rstrip("/")


def _folder_may_match(folder_path: str, include_groups: Sequence[Sequence[str]]) -> bool:
    """Whether a directory can contain a file satisfying every include group."""

    normalized = folder_path.strip("/")
    for group in include_groups:
        if not group:
            continue
        possible = False
        for pattern in group:
            prefix = _pattern_prefix(pattern)
            if not prefix:
                possible = True
            elif normalized == prefix or normalized.startswith(prefix + "/") or prefix.startswith(normalized + "/"):
                possible = True
            elif fnmatch.fnmatchcase(normalized + "/probe", pattern):
                possible = True
            if possible:
                break
        if not possible:
            return False
    return True


def path_selected(
    relative_path: str,
    *,
    include_groups: Sequence[Sequence[str]] = (),
    exclude_patterns: Sequence[str] = (),
) -> bool:
    normalized = relative_path.replace("\\", "/")
    for group in include_groups:
        if group and not any(fnmatch.fnmatchcase(normalized, pattern) for pattern in group):
            return False
    return not any(fnmatch.fnmatchcase(normalized, pattern) for pattern in exclude_patterns)


def _mendeley_remote_file(entry: Mapping[str, Any], folder_path: str) -> RemoteFile:
    filename = safe_relative_path(str(entry.get("filename", "")))
    if "/" in filename:
        raise AcquisitionError(f"Mendeley filename contains a path separator: {filename!r}")
    details = entry.get("content_details") or {}
    if not isinstance(details, dict):
        raise AcquisitionError(f"Mendeley file {filename!r} has invalid content_details")
    url = details.get("download_url")
    if not isinstance(url, str) or not url.startswith("https://"):
        raise AcquisitionError(f"Mendeley file {filename!r} has no HTTPS download URL")
    size = details.get("size", entry.get("size"))
    expected_size = int(size) if size is not None else None
    sha256 = details.get("sha256_hash")
    if sha256 is not None and not re.fullmatch(r"[0-9a-fA-F]{64}", str(sha256)):
        raise AcquisitionError(f"Mendeley file {filename!r} has invalid SHA-256 metadata")
    relative = f"{folder_path}/{filename}" if folder_path else filename
    return RemoteFile(
        relative_path=safe_relative_path(relative),
        url=url,
        expected_size=expected_size,
        expected_sha256=str(sha256).lower() if sha256 else None,
        provider_id=entry.get("id"),
        provider_metadata={
            "content_type": details.get("content_type"),
            "last_modified_date": entry.get("last_modified_date"),
        },
    )


def discover_mendeley_files(
    acquisition: Mapping[str, Any],
    *,
    fetcher: JsonFetcher = fetch_json,
    cli_include: Sequence[str] = (),
    cli_exclude: Sequence[str] = (),
) -> list[RemoteFile]:
    dataset_id = str(acquisition["dataset_id"])
    version = int(acquisition["version"])
    base = f"https://data.mendeley.com/public-api/datasets/{urllib.parse.quote(dataset_id, safe='')}"
    folder_endpoint = f"{base}/folders/{version}"
    folder_payload = fetcher(folder_endpoint)
    folders = _json_list(folder_payload, endpoint=folder_endpoint)
    folder_paths = build_mendeley_folder_paths(folders)

    source_include = tuple(str(item) for item in acquisition.get("include", []))
    source_exclude = tuple(str(item) for item in acquisition.get("exclude", []))
    include_groups: list[Sequence[str]] = []
    if source_include:
        include_groups.append(source_include)
    if cli_include:
        include_groups.append(tuple(cli_include))
    excludes = source_exclude + tuple(cli_exclude)

    folders_to_query: list[tuple[str, str]] = [("root", "")]
    folders_to_query.extend(
        (folder_id, path)
        for folder_id, path in sorted(folder_paths.items(), key=lambda item: item[1].casefold())
        if _folder_may_match(path, include_groups)
    )

    found: list[RemoteFile] = []
    seen_paths: set[str] = set()
    for folder_id, folder_path in folders_to_query:
        query = urllib.parse.urlencode({"folder_id": folder_id, "version": version})
        endpoint = f"{base}/files?{query}"
        entries = _json_list(fetcher(endpoint), endpoint=endpoint)
        for entry in entries:
            remote = _mendeley_remote_file(entry, folder_path)
            if not path_selected(remote.relative_path, include_groups=include_groups, exclude_patterns=excludes):
                continue
            folded = remote.relative_path.casefold()
            if folded in seen_paths:
                raise AcquisitionError(f"Duplicate Mendeley destination path: {remote.relative_path}")
            seen_paths.add(folded)
            found.append(remote)
    return sorted(found, key=lambda item: item.relative_path.casefold())


def discover_mendeley_zip(
    acquisition: Mapping[str, Any],
    *,
    fetcher: JsonFetcher = fetch_json,
) -> RemoteFile:
    """Resolve Mendeley's published download-all archive with provider integrity data."""

    dataset_id = str(acquisition["dataset_id"])
    version = int(acquisition["version"])
    endpoint = (
        "https://data.mendeley.com/api/datasets-v2/datasets/"
        f"{urllib.parse.quote(dataset_id, safe='')}/zip?"
        f"{urllib.parse.urlencode({'version': version})}"
    )
    payload = fetcher(endpoint)
    if not isinstance(payload, dict):
        raise AcquisitionError(f"Expected a JSON object from {endpoint}")
    status = str(payload.get("status", "")).upper()
    if status not in {"FINISH", "FINISHED", "COMPLETED"}:
        raise AcquisitionError(f"Mendeley download-all archive is not ready for {dataset_id}.{version}: {status or 'unknown'}")
    # The API response can contain an already-expired object-store signature.
    # Always download through Mendeley's stable versioned redirect so each
    # attempt receives a fresh signature, while retaining the API's size/hash
    # as the integrity authority.
    url = f"https://data.mendeley.com/public-api/zip/{dataset_id}/download/{version}"
    size = payload.get("size")
    sha256 = payload.get("sha256_hash")
    if sha256 is not None and not re.fullmatch(r"[0-9a-fA-F]{64}", str(sha256)):
        raise AcquisitionError(f"Mendeley ZIP metadata has invalid SHA-256 for {dataset_id}.{version}")
    return RemoteFile(
        relative_path=f"{dataset_id}-v{version}-download-all.zip",
        url=url,
        expected_size=int(size) if size is not None else None,
        expected_sha256=str(sha256).lower() if sha256 else None,
        provider_id=f"{dataset_id}.{version}",
        provider_metadata={
            "archive_status": status,
            "created_on": payload.get("created_on"),
            "modified_on": payload.get("modified_on"),
            "metadata_endpoint": endpoint,
        },
    )


def discover_figshare_files(
    acquisition: Mapping[str, Any],
    *,
    fetcher: JsonFetcher = fetch_json,
    cli_include: Sequence[str] = (),
    cli_exclude: Sequence[str] = (),
) -> list[RemoteFile]:
    article_id = int(acquisition["article_id"])
    endpoint = f"https://api.figshare.com/v2/articles/{article_id}/files"
    entries = _json_list(fetcher(endpoint), endpoint=endpoint)
    source_include = tuple(str(item) for item in acquisition.get("include", []))
    include_groups = tuple(group for group in (source_include, tuple(cli_include)) if group)
    excludes = tuple(str(item) for item in acquisition.get("exclude", [])) + tuple(cli_exclude)

    found: list[RemoteFile] = []
    seen: set[str] = set()
    for entry in entries:
        relative = safe_relative_path(str(entry.get("name", "")))
        if not path_selected(relative, include_groups=include_groups, exclude_patterns=excludes):
            continue
        folded = relative.casefold()
        if folded in seen:
            raise AcquisitionError(f"Duplicate Figshare destination path: {relative}")
        seen.add(folded)
        url = entry.get("download_url") or f"https://api.figshare.com/v2/file/download/{entry.get('id')}"
        if not isinstance(url, str) or not url.startswith("https://"):
            raise AcquisitionError(f"Figshare file {relative!r} has no HTTPS download URL")
        size = entry.get("size")
        md5 = entry.get("computed_md5")
        if md5 is not None and not re.fullmatch(r"[0-9a-fA-F]{32}", str(md5)):
            raise AcquisitionError(f"Figshare file {relative!r} has invalid MD5 metadata")
        found.append(
            RemoteFile(
                relative_path=relative,
                url=url,
                expected_size=int(size) if size is not None else None,
                expected_md5=str(md5).lower() if md5 else None,
                provider_id=entry.get("id"),
                provider_metadata={"supplied_md5": md5},
            )
        )
    return sorted(found, key=lambda item: item.relative_path.casefold())


def discover_http_files(
    acquisition: Mapping[str, Any],
    *,
    cli_include: Sequence[str] = (),
    cli_exclude: Sequence[str] = (),
) -> list[RemoteFile]:
    """Normalize one checksum-pinned direct HTTP file from the source registry."""

    relative = safe_relative_path(str(acquisition["filename"]))
    source_include = tuple(str(item) for item in acquisition.get("include", []))
    include_groups = tuple(group for group in (source_include, tuple(cli_include)) if group)
    excludes = tuple(str(item) for item in acquisition.get("exclude", [])) + tuple(cli_exclude)
    if not path_selected(relative, include_groups=include_groups, exclude_patterns=excludes):
        return []
    url = str(acquisition["url"])
    expected_sha256 = acquisition.get("expected_sha256")
    expected_md5 = acquisition.get("expected_md5")
    if expected_md5 is not None and not re.fullmatch(r"[0-9a-fA-F]{32}", str(expected_md5)):
        raise AcquisitionError(f"HTTP file {relative!r} has invalid expected_md5")
    return [
        RemoteFile(
            relative_path=relative,
            url=url,
            expected_size=int(acquisition["expected_size"]) if acquisition.get("expected_size") is not None else None,
            expected_sha256=str(expected_sha256).lower() if expected_sha256 else None,
            expected_md5=str(expected_md5).lower() if expected_md5 else None,
            provider_id=acquisition.get("provider_id") or receipt_url(url),
            provider_metadata={"kind": "direct_http"},
        )
    ]


def _hashes(path: Path) -> tuple[int, str, str]:
    sha256 = hashlib.sha256()
    md5 = hashlib.md5(usedforsecurity=False)
    size = 0
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            size += len(chunk)
            sha256.update(chunk)
            md5.update(chunk)
    return size, sha256.hexdigest(), md5.hexdigest()


def _verify_file(path: Path, remote: RemoteFile) -> tuple[int, str, str]:
    size, sha256, md5 = _hashes(path)
    if remote.expected_size is not None and size != remote.expected_size:
        raise AcquisitionError(
            f"Size mismatch for {remote.relative_path}: expected {remote.expected_size}, received {size}"
        )
    if remote.expected_sha256 and sha256.lower() != remote.expected_sha256.lower():
        raise AcquisitionError(
            f"SHA-256 mismatch for {remote.relative_path}: expected {remote.expected_sha256}, received {sha256}"
        )
    if remote.expected_md5 and md5.lower() != remote.expected_md5.lower():
        raise AcquisitionError(
            f"Provider MD5 mismatch for {remote.relative_path}: expected {remote.expected_md5}, received {md5}"
        )
    return size, sha256, md5


def _response_status(response: Any) -> int:
    status = getattr(response, "status", None)
    if status is None and hasattr(response, "getcode"):
        status = response.getcode()
    return int(status or 200)


def download_http(
    remote: RemoteFile,
    destination: Path,
    *,
    timeout: float = 120.0,
    retries: int = 3,
    opener: Callable[..., Any] | None = None,
    progress: Callable[[str], None] = print,
) -> DownloadResult:
    """Download one file atomically, resuming a ``.part`` file with HTTP Range."""

    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists():
        try:
            size, sha256, md5 = _verify_file(destination, remote)
        except AcquisitionError:
            suffix = dt.datetime.now().strftime("%Y%m%dT%H%M%S")
            invalid = destination.with_name(f"{destination.name}.invalid-{suffix}")
            destination.replace(invalid)
            progress(f"Existing invalid file preserved as {invalid.name}")
        else:
            return DownloadResult(destination, size, sha256, md5, True, 0, remote.url)

    partial = destination.with_name(destination.name + ".part")
    open_url = opener or urllib.request.urlopen
    last_error: BaseException | None = None
    initial_offset = partial.stat().st_size if partial.exists() else 0

    for attempt in range(retries + 1):
        offset = partial.stat().st_size if partial.exists() else 0
        headers = {"Accept": "application/octet-stream", "User-Agent": USER_AGENT}
        if offset:
            headers["Range"] = f"bytes={offset}-"
        request = urllib.request.Request(remote.url, headers=headers)
        try:
            response = open_url(request, timeout=timeout)
            with response:
                status = _response_status(response)
                if offset and status == 206:
                    content_range = getattr(response, "headers", {}).get("Content-Range")
                    if content_range and not content_range.startswith(f"bytes {offset}-"):
                        raise AcquisitionError(
                            f"Server resumed {remote.relative_path} from the wrong byte: {content_range}"
                        )
                    mode = "ab"
                elif offset and status == 200:
                    progress(f"Server ignored Range for {remote.relative_path}; restarting transfer")
                    mode = "wb"
                    offset = 0
                else:
                    mode = "wb"
                    offset = 0
                final_url = response.geturl() if hasattr(response, "geturl") else remote.url
                written = 0
                with partial.open(mode) as handle:
                    while chunk := response.read(1024 * 1024):
                        handle.write(chunk)
                        written += len(chunk)
                content_length = getattr(response, "headers", {}).get("Content-Length")
                if content_length is not None and written != int(content_length):
                    raise AcquisitionError(
                        f"Truncated HTTP body for {remote.relative_path}: expected {content_length}, read {written}"
                    )
            size, sha256, md5 = _verify_file(partial, remote)
            os.replace(partial, destination)
            return DownloadResult(destination, size, sha256, md5, False, initial_offset, str(final_url))
        except urllib.error.HTTPError as exc:
            if exc.code == 416 and partial.exists():
                if remote.expected_size is None and not remote.expected_sha256 and not remote.expected_md5:
                    suffix = dt.datetime.now().strftime("%Y%m%dT%H%M%S")
                    unverifiable = partial.with_name(f"{partial.name}.unverifiable-{suffix}")
                    partial.replace(unverifiable)
                    last_error = AcquisitionError(
                        f"Cannot accept HTTP 416 for {remote.relative_path} without provider integrity metadata"
                    )
                    progress(f"Unverifiable partial file preserved as {unverifiable.name}; restarting")
                    continue
                try:
                    size, sha256, md5 = _verify_file(partial, remote)
                except AcquisitionError as verify_exc:
                    suffix = dt.datetime.now().strftime("%Y%m%dT%H%M%S")
                    corrupt = partial.with_name(f"{partial.name}.invalid-{suffix}")
                    partial.replace(corrupt)
                    last_error = verify_exc
                    progress(f"Unusable partial file preserved as {corrupt.name}; restarting")
                    continue
                os.replace(partial, destination)
                return DownloadResult(destination, size, sha256, md5, False, initial_offset, remote.url)
            last_error = exc
        except (OSError, urllib.error.URLError, http.client.HTTPException, AcquisitionError) as exc:
            last_error = exc

        if attempt < retries:
            delay = min(2**attempt, 8)
            progress(f"Download attempt {attempt + 1} failed for {remote.relative_path}; retrying in {delay}s")
            time.sleep(delay)

    raise AcquisitionError(f"Download failed for {remote.relative_path}: {last_error}") from last_error


def _zip_member_target(root: Path, info: zipfile.ZipInfo) -> tuple[Path, str]:
    raw_name = info.filename.replace("\\", "/")
    relative = safe_relative_path(raw_name.rstrip("/"))
    target = (root / Path(*PurePosixPath(relative).parts)).resolve()
    try:
        common = os.path.commonpath((str(root.resolve()), str(target)))
    except ValueError as exc:
        raise AcquisitionError(f"ZIP member escapes extraction root: {info.filename!r}") from exc
    if common != str(root.resolve()):
        raise AcquisitionError(f"ZIP member escapes extraction root: {info.filename!r}")
    unix_mode = (info.external_attr >> 16) & 0xFFFF
    file_type = stat.S_IFMT(unix_mode)
    if file_type == stat.S_IFLNK:
        raise AcquisitionError(f"ZIP symbolic links are not allowed: {info.filename!r}")
    if file_type not in {0, stat.S_IFREG, stat.S_IFDIR}:
        raise AcquisitionError(f"ZIP special file is not allowed: {info.filename!r}")
    if info.flag_bits & 0x1:
        raise AcquisitionError(f"Encrypted ZIP member is not supported: {info.filename!r}")
    return target, relative


def safe_extract_zip(
    archive: Path,
    destination: Path,
    *,
    max_members: int = 1_000_000,
    max_uncompressed_bytes: int | None = None,
) -> dict[str, Any]:
    """Transactionally extract a ZIP after validating every member path and type."""

    if destination.exists():
        return {"path": str(destination), "reused": True}
    destination.parent.mkdir(parents=True, exist_ok=True)
    temporary = _make_inheriting_temp_directory(
        destination.parent,
        f".{destination.name}.extract-",
    )
    try:
        with zipfile.ZipFile(archive) as bundle:
            members = bundle.infolist()
            if len(members) > max_members:
                raise AcquisitionError(f"ZIP has {len(members)} members; limit is {max_members}")
            total = sum(item.file_size for item in members if not item.is_dir())
            if max_uncompressed_bytes is not None and total > max_uncompressed_bytes:
                raise AcquisitionError(
                    f"ZIP expands to {total} bytes; configured limit is {max_uncompressed_bytes}"
                )

            planned: list[tuple[zipfile.ZipInfo, Path]] = []
            casefolded: dict[str, str] = {}
            for item in members:
                target, relative = _zip_member_target(temporary, item)
                folded = relative.casefold().rstrip("/")
                previous = casefolded.get(folded)
                if previous is not None and previous != relative:
                    raise AcquisitionError(f"Case-insensitive ZIP path collision: {previous!r} and {relative!r}")
                casefolded[folded] = relative
                planned.append((item, target))

            for item, target in planned:
                if item.is_dir():
                    target.mkdir(parents=True, exist_ok=True)
                    continue
                target.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(item, "r") as source_handle, target.open("xb") as target_handle:
                    shutil.copyfileobj(source_handle, target_handle, length=1024 * 1024)
        os.replace(temporary, destination)
        return {
            "path": str(destination),
            "reused": False,
            "member_count": len(members),
            "uncompressed_bytes": total,
        }
    except BaseException:
        shutil.rmtree(temporary, ignore_errors=True)
        raise


def _write_json_atomic(path: Path, payload: Mapping[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + ".tmp")
    temporary.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    os.replace(temporary, path)


def _tree_digest(root: Path) -> dict[str, Any]:
    digest = hashlib.sha256()
    file_count = 0
    total_bytes = 0
    for path in sorted((item for item in root.rglob("*") if item.is_file()), key=lambda item: item.as_posix()):
        if ".git" in path.relative_to(root).parts:
            continue
        relative = path.relative_to(root).as_posix()
        size, sha256, _ = _hashes(path)
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        digest.update(str(size).encode("ascii"))
        digest.update(b"\0")
        digest.update(bytes.fromhex(sha256))
        file_count += 1
        total_bytes += size
    return {"sha256": digest.hexdigest(), "file_count": file_count, "size": total_bytes}


def _run(command: Sequence[str], *, cwd: Path | None = None) -> str:
    try:
        completed = subprocess.run(
            list(command),
            cwd=cwd,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
        )
    except FileNotFoundError as exc:
        raise AcquisitionError(f"Required executable is not installed: {command[0]}") from exc
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        raise AcquisitionError(f"Command failed ({' '.join(command)}): {detail}") from exc
    return completed.stdout.strip()


def acquire_git(source: Mapping[str, Any], destination: Path) -> dict[str, Any]:
    """Acquire any public Git repository at a requested branch, tag, or commit."""

    acquisition = source["acquisition"]
    provider = str(acquisition["provider"])
    repository = str(acquisition["repository"])
    ref = str(acquisition["ref"])
    target = destination / "repository"
    destination.mkdir(parents=True, exist_ok=True)
    if target.exists():
        if not (target / ".git").is_dir():
            raise AcquisitionError(f"Existing GitHub destination is not a Git repository: {target}")
        actual_remote = _run(["git", "remote", "get-url", "origin"], cwd=target)
        if actual_remote.rstrip("/") != repository.rstrip("/"):
            raise AcquisitionError(f"Git remote mismatch at {target}: {actual_remote!r}")
        reused = True
    else:
        temporary = _make_inheriting_temp_directory(destination, ".repository.clone-")
        try:
            _run(["git", "init", str(temporary)])
            _run(["git", "remote", "add", "origin", repository], cwd=temporary)
            _run(["git", "fetch", "--depth", "1", "origin", ref], cwd=temporary)
            _run(["git", "checkout", "--detach", "FETCH_HEAD"], cwd=temporary)
            os.replace(temporary, target)
        except BaseException:
            shutil.rmtree(temporary, ignore_errors=True)
            raise
        reused = False
    if acquisition.get("lfs"):
        _run(["git", "lfs", "install", "--local"], cwd=target)
        _run(["git", "lfs", "pull"], cwd=target)
    commit = _run(["git", "rev-parse", "HEAD"], cwd=target)
    if re.fullmatch(r"[0-9a-fA-F]{40}", ref) and commit.lower() != ref.lower():
        raise AcquisitionError(f"Pinned Git commit mismatch for {source['id']}: expected {ref}, checked out {commit}")
    tree = _tree_digest(target)
    return {
        "provider": provider,
        "repository": repository,
        "requested_ref": ref,
        "resolved_commit": commit,
        "reused": reused,
        "tree": tree,
    }


def _download_file_set(
    remotes: Sequence[RemoteFile],
    destination: Path,
    *,
    extract: bool,
    timeout: float,
    retries: int,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    receipts: list[dict[str, Any]] = []
    extractions: list[dict[str, Any]] = []
    for index, remote in enumerate(remotes, start=1):
        local_relative = safe_relative_path(remote.relative_path)
        local = destination / Path(*PurePosixPath(local_relative).parts)
        print(f"[{index}/{len(remotes)}] {remote.relative_path}")
        result = download_http(remote, local, timeout=timeout, retries=retries)
        receipts.append(
            {
                "relative_path": local.relative_to(destination).as_posix(),
                "provider_id": remote.provider_id,
                "source_url": receipt_url(remote.url),
                "final_url": receipt_url(result.final_url),
                "size": result.size,
                "sha256": result.sha256,
                "md5": result.md5,
                "provider_expected_size": remote.expected_size,
                "provider_expected_sha256": remote.expected_sha256,
                "provider_expected_md5": remote.expected_md5,
                "reused": result.reused,
                "resumed_from": result.resumed_from,
                "metadata": dict(remote.provider_metadata),
            }
        )
        if extract and zipfile.is_zipfile(local):
            stem = local.name
            while Path(stem).suffix.lower() in {".zip"}:
                stem = Path(stem).stem
            extraction_relative = Path("extracted") / local.relative_to(destination).parent / stem
            extraction = safe_extract_zip(local, destination / extraction_relative)
            extraction["archive"] = local.relative_to(destination).as_posix()
            extraction["path"] = (destination / extraction_relative).relative_to(destination).as_posix()
            extractions.append(extraction)
    return receipts, extractions


def acquire_source(
    source: Mapping[str, Any],
    *,
    data_root: Path,
    manifest_path: Path,
    cli_include: Sequence[str],
    cli_exclude: Sequence[str],
    mendeley_mode: str | None,
    extract_override: bool | None,
    timeout: float,
    retries: int,
) -> dict[str, Any]:
    acquisition = source["acquisition"]
    provider = acquisition["provider"]
    destination_name = str(acquisition.get("destination", source["id"]))
    if not SAFE_SOURCE_ID.fullmatch(destination_name):
        raise AcquisitionError(f"Unsafe destination name for {source['id']}: {destination_name!r}")
    destination = data_root / destination_name
    destination.mkdir(parents=True, exist_ok=True)
    extract = bool(acquisition.get("extract", False)) if extract_override is None else extract_override

    receipt: dict[str, Any] = {
        "schema_version": 1,
        "created_at": utc_now(),
        "source_id": source["id"],
        "title": source["title"],
        "status": source["status"],
        "landing_url": source.get("landing_url"),
        "doi": source.get("doi"),
        "license": source.get("license"),
        "provenance_warnings": source.get("provenance_warnings", []),
        "manifest": {
            "path": manifest_path.resolve().as_posix(),
            "sha256": manifest_sha256(manifest_path),
        },
        "acquisition": dict(acquisition),
    }

    if provider in {"github", "git", "huggingface"}:
        if cli_include or cli_exclude:
            raise AcquisitionError(f"File selectors are not supported for Git source {source['id']}")
        receipt["result"] = acquire_git(source, destination)
    elif provider == "http":
        remotes = discover_http_files(
            acquisition,
            cli_include=cli_include,
            cli_exclude=cli_exclude,
        )
        if not remotes:
            raise AcquisitionError(f"No HTTP files matched selectors for {source['id']}")
        files, extractions = _download_file_set(
            remotes,
            destination,
            extract=extract,
            timeout=timeout,
            retries=retries,
        )
        receipt["files"] = files
        receipt["extractions"] = extractions
    elif provider == "figshare":
        remotes = discover_figshare_files(
            acquisition,
            cli_include=cli_include,
            cli_exclude=cli_exclude,
        )
        if not remotes:
            raise AcquisitionError(f"No Figshare files matched selectors for {source['id']}")
        files, extractions = _download_file_set(
            remotes,
            destination,
            extract=extract,
            timeout=timeout,
            retries=retries,
        )
        receipt["files"] = files
        receipt["extractions"] = extractions
    elif provider == "mendeley":
        mode = mendeley_mode or str(acquisition.get("mode", "files"))
        has_filters = bool(acquisition.get("include") or acquisition.get("exclude") or cli_include or cli_exclude)
        if mode == "zip" and has_filters:
            raise AcquisitionError(
                f"Download-all ZIP cannot enforce selectors for {source['id']}; use --mendeley-mode files"
            )
        if mode == "zip":
            remotes = [discover_mendeley_zip(acquisition)]
        else:
            remotes = discover_mendeley_files(
                acquisition,
                cli_include=cli_include,
                cli_exclude=cli_exclude,
            )
        if not remotes:
            raise AcquisitionError(f"No Mendeley files matched selectors for {source['id']}")
        files, extractions = _download_file_set(
            remotes,
            destination,
            extract=extract,
            timeout=timeout,
            retries=retries,
        )
        receipt["files"] = files
        receipt["extractions"] = extractions
        receipt["mendeley_mode"] = mode
    else:
        raise AcquisitionError(f"Provider {provider!r} is not downloadable by this script")

    receipt_path = destination / ".receipt.json"
    _write_json_atomic(receipt_path, receipt)
    return receipt


def _split_patterns(values: Iterable[str] | None) -> tuple[str, ...]:
    patterns: list[str] = []
    for value in values or ():
        patterns.extend(part.strip() for part in value.split(",") if part.strip())
    return tuple(patterns)


def select_sources(
    sources: Sequence[Mapping[str, Any]],
    *,
    includes: Sequence[str],
    excludes: Sequence[str],
    all_safe: bool,
) -> list[Mapping[str, Any]]:
    selected: list[Mapping[str, Any]] = []
    for source in sources:
        source_id = str(source["id"])
        destination_alias = str(source.get("acquisition", {}).get("destination", ""))
        if includes:
            wanted = any(
                fnmatch.fnmatchcase(source_id, pattern)
                or (destination_alias and fnmatch.fnmatchcase(destination_alias, pattern))
                for pattern in includes
            )
        elif all_safe:
            wanted = source.get("status") in SAFE_AUTOMATIC_STATUSES
        else:
            wanted = bool(source.get("default_selected"))
        if excludes and any(fnmatch.fnmatchcase(source_id, pattern) for pattern in excludes):
            wanted = False
        if wanted:
            selected.append(source)
    return sorted(selected, key=lambda item: (int(item.get("priority", 9999)), str(item["id"])))


def _format_bytes(value: int | None) -> str:
    if value is None:
        return "unknown"
    amount = float(value)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if amount < 1024 or unit == "TiB":
            return f"{amount:.1f} {unit}"
        amount /= 1024
    return str(value)


def print_registry(sources: Sequence[Mapping[str, Any]]) -> None:
    for source in sorted(sources, key=lambda item: (int(item.get("priority", 9999)), str(item["id"]))):
        acquisition = source["acquisition"]
        provider = acquisition["provider"]
        approx = acquisition.get("approximate_selected_bytes", acquisition.get("expected_size"))
        marker = "default" if source.get("default_selected") else "manual"
        print(
            f"{source['id']:<31} {source['status']:<17} {provider:<11} "
            f"{marker:<7} {_format_bytes(approx):>12}  {source['title']}"
        )


def print_dry_run(
    selected: Sequence[Mapping[str, Any]],
    *,
    data_root: Path,
    mendeley_mode: str | None,
) -> None:
    print(f"Data root: {data_root}")
    for source in selected:
        acquisition = source["acquisition"]
        destination = acquisition.get("destination", source["id"])
        provider = acquisition["provider"]
        detail = ""
        if provider == "mendeley":
            mode = mendeley_mode or acquisition.get("mode", "files")
            detail = f"dataset={acquisition['dataset_id']} version={acquisition['version']} mode={mode}"
        elif provider == "figshare":
            detail = f"article={acquisition['article_id']}"
        elif provider in {"github", "git", "huggingface"}:
            detail = f"ref={acquisition['ref']} repo={acquisition['repository']}"
        elif provider == "http":
            detail = f"file={acquisition['filename']} url={receipt_url(acquisition['url'])}"
        print(f"- {source['id']} -> {data_root / str(destination)} ({provider}; {detail})")
        if acquisition.get("include"):
            print(f"    include: {', '.join(acquisition['include'])}")
        if acquisition.get("exclude"):
            print(f"    exclude: {', '.join(acquisition['exclude'])}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        nargs="?",
        choices=("list", "fetch"),
        help="Optional command form; `list` and `fetch --source ID` are aliases for the flags below",
    )
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--data-root", type=Path, help="Raw data root (default from sources.json)")
    parser.add_argument("--list", action="store_true", help="List registry entries and exit; no network access")
    parser.add_argument("--dry-run", action="store_true", help="Print the selected acquisition plan; no network access")
    parser.add_argument("--all", action="store_true", help="Select every automatically allowed source")
    parser.add_argument("--include", action="append", help="Source id glob(s), comma separated or repeated")
    parser.add_argument("--source", action="append", help="Alias for --include when using the fetch command")
    parser.add_argument("--exclude", action="append", help="Source id glob(s), comma separated or repeated")
    parser.add_argument("--file-include", action="append", help="Further narrow provider-relative file paths")
    parser.add_argument("--file-exclude", action="append", help="Exclude provider-relative file paths")
    parser.add_argument(
        "--accept-risk",
        action="append",
        default=[],
        metavar="SOURCE_ID",
        help="Explicitly acknowledge a review_required, license_review, or holdout_locked source",
    )
    parser.add_argument(
        "--mendeley-mode",
        choices=("files", "zip"),
        help="Override Mendeley acquisition mode; ZIP is rejected when selectors exist",
    )
    parser.add_argument(
        "--extract",
        action=argparse.BooleanOptionalAction,
        default=None,
        help="Override each source's safe ZIP extraction setting",
    )
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--retries", type=int, default=3)
    return parser


def main(argv: Sequence[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    manifest_path = args.manifest.resolve()
    manifest = load_manifest(manifest_path)
    sources = manifest["sources"]

    if args.list or args.command == "list":
        print_registry(sources)
        return 0

    includes = _split_patterns(tuple(args.include or ()) + tuple(args.source or ()))
    excludes = _split_patterns(args.exclude)
    file_includes = _split_patterns(args.file_include)
    file_excludes = _split_patterns(args.file_exclude)
    selected = select_sources(sources, includes=includes, excludes=excludes, all_safe=args.all)
    if not selected:
        parser.error("No sources matched. Use --list to inspect source ids.")

    accepted = set(_split_patterns(args.accept_risk))
    for source in selected:
        status = source["status"]
        if status in NON_DOWNLOADABLE_STATUSES:
            parser.error(f"{source['id']} is {status} and cannot be downloaded by this pipeline")
        if status in REVIEW_STATUSES and source["id"] not in accepted:
            parser.error(
                f"{source['id']} is {status}; read its provenance warnings and pass "
                f"--accept-risk {source['id']} only after approval"
            )

    if args.retries < 0:
        parser.error("--retries must be non-negative")
    if args.timeout <= 0:
        parser.error("--timeout must be positive")

    if args.data_root:
        data_root = args.data_root.resolve()
    else:
        configured = Path(manifest["raw_data_policy"]["default_root"])
        data_root = configured if configured.is_absolute() else (REPO_ROOT / configured).resolve()

    if args.dry_run:
        print_dry_run(selected, data_root=data_root, mendeley_mode=args.mendeley_mode)
        return 0

    data_root.mkdir(parents=True, exist_ok=True)
    for source in selected:
        print(f"\n=== {source['id']}: {source['title']} ===")
        for warning in source.get("provenance_warnings", []):
            print(f"WARNING: {warning}")
        acquire_source(
            source,
            data_root=data_root,
            manifest_path=manifest_path,
            cli_include=file_includes,
            cli_exclude=file_excludes,
            mendeley_mode=args.mendeley_mode,
            extract_override=args.extract,
            timeout=args.timeout,
            retries=args.retries,
        )
    print(f"\nCompleted {len(selected)} source(s). Receipts are under {data_root}.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AcquisitionError as exc:
        print(f"error: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
