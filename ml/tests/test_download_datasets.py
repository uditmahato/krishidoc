from __future__ import annotations

import hashlib
import io
import json
from pathlib import Path
import stat
import tempfile
import unittest
from unittest import mock
import urllib.parse
import zipfile

from ml.scripts import download_datasets as subject


FIXTURES = Path(__file__).with_name("fixtures")


def fixture(name: str):
    return json.loads((FIXTURES / name).read_text(encoding="utf-8"))


class FakeResponse(io.BytesIO):
    def __init__(self, body: bytes, *, status: int = 200, url: str = "https://cdn.example/file"):
        super().__init__(body)
        self.status = status
        self._url = url

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, traceback):
        self.close()
        return False

    def geturl(self):
        return self._url


class ManifestTests(unittest.TestCase):
    def test_checked_in_manifest_is_valid_and_raw_data_is_ignored(self):
        manifest = subject.load_manifest(subject.DEFAULT_MANIFEST)
        ids = [source["id"] for source in manifest["sources"]]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertIn("ccmt-field", ids)
        self.assertIn("plantwild", ids)
        self.assertIn("/data/", (subject.ML_ROOT / ".gitignore").read_text(encoding="utf-8"))

    def test_review_sources_are_not_automatically_selected(self):
        manifest = subject.load_manifest(subject.DEFAULT_MANIFEST)
        selected = subject.select_sources(manifest["sources"], includes=(), excludes=(), all_safe=True)
        statuses = {source["status"] for source in selected}
        self.assertTrue(statuses <= subject.SAFE_AUTOMATIC_STATUSES)
        self.assertNotIn("plantdoc-field", {source["id"] for source in selected})
        self.assertNotIn("plantvillage-mendeley", {source["id"] for source in selected})

    def test_destination_name_can_be_used_as_cli_source_alias(self):
        manifest = subject.load_manifest(subject.DEFAULT_MANIFEST)
        selected = subject.select_sources(
            manifest["sources"],
            includes=("figshare_maize",),
            excludes=(),
            all_safe=False,
        )
        self.assertEqual([source["id"] for source in selected], ["maize-figshare-29298275"])

    def test_receipt_url_drops_signed_query_credentials(self):
        self.assertEqual(
            subject.receipt_url(
                "https://user:secret@cdn.example/archive.zip?X-Amz-Credential=abc&X-Amz-Signature=def#fragment"
            ),
            "https://cdn.example/archive.zip",
        )

    def test_tom2024_is_an_integrity_pinned_direct_http_archive(self):
        manifest = subject.load_manifest(subject.DEFAULT_MANIFEST)
        source = next(item for item in manifest["sources"] if item["id"] == "tom2024-original")
        acquisition = source["acquisition"]
        self.assertEqual(acquisition["provider"], "http")
        self.assertEqual(acquisition["expected_size"], 134833774)
        self.assertEqual(
            acquisition["expected_sha256"],
            "6c110be15bc8bcdd4bc58aed277b3b81d66d8e2497505edb19639a60a8b76747",
        )
        self.assertTrue(acquisition["extract"])

    def test_digigreen_is_cc_by_pinned_and_never_default_selected(self):
        manifest = subject.load_manifest(subject.DEFAULT_MANIFEST)
        source = next(
            item for item in manifest["sources"] if item["id"] == "digigreen-crop-disease-images"
        )
        self.assertEqual(source["status"], "holdout_locked")
        self.assertFalse(source["default_selected"])
        self.assertEqual(source["license"]["spdx"], "CC-BY-4.0")
        self.assertEqual(source["acquisition"]["provider"], "huggingface")
        self.assertEqual(
            source["acquisition"]["ref"],
            "2b18be861bddeb525c83cf2d7e07eb7f649dfed9",
        )

    def test_new_mendeley_field_candidates_are_versioned_and_manual_only(self):
        manifest = subject.load_manifest(subject.DEFAULT_MANIFEST)
        by_id = {source["id"]: source for source in manifest["sources"]}
        expected = {
            "plantcity-pakistan-v2": {
                "dataset_id": "w8kh2xkspx",
                "version": 2,
                "doi": "10.17632/w8kh2xkspx.2",
                "landing_url": "https://data.mendeley.com/datasets/w8kh2xkspx/2",
                "count_key": "publisher_reported_original_images",
                "count": 10667,
            },
            "tomato-bangladesh-93h9p62kg4-v1": {
                "dataset_id": "93h9p62kg4",
                "version": 1,
                "doi": "10.17632/93h9p62kg4.1",
                "landing_url": "https://data.mendeley.com/datasets/93h9p62kg4/1",
                "count_key": "publisher_reported_total_from_class_counts",
                "count": 2659,
            },
            "maize-seasonal-corn-v1": {
                "dataset_id": "vy629dngm8",
                "version": 1,
                "doi": "10.17632/vy629dngm8.1",
                "landing_url": "https://data.mendeley.com/datasets/vy629dngm8/1",
                "count_key": "publisher_reported_original_images",
                "count": 2943,
            },
            "tomato-bangladesh-jttrv2w27r-v1": {
                "dataset_id": "jttrv2w27r",
                "version": 1,
                "doi": "10.17632/jttrv2w27r.1",
                "landing_url": "https://data.mendeley.com/datasets/jttrv2w27r/1",
                "count_key": "publisher_reported_total_images",
                "count": 2995,
            },
            "maize-bangladesh-mld-v1": {
                "dataset_id": "3myfctrgk3",
                "version": 1,
                "doi": "10.17632/3myfctrgk3.1",
                "landing_url": "https://data.mendeley.com/datasets/3myfctrgk3/1",
                "count_key": "publisher_reported_total_images",
                "count": 1996,
            },
        }

        for source_id, facts in expected.items():
            with self.subTest(source=source_id):
                source = by_id[source_id]
                self.assertEqual(source["status"], "review_required")
                self.assertFalse(source["default_selected"])
                self.assertEqual(source["license"]["spdx"], "CC-BY-4.0")
                self.assertEqual(source["landing_url"], facts["landing_url"])
                self.assertEqual(source["doi"], facts["doi"])
                self.assertEqual(source["acquisition"]["provider"], "mendeley")
                self.assertEqual(source["acquisition"]["dataset_id"], facts["dataset_id"])
                self.assertEqual(source["acquisition"]["version"], facts["version"])
                self.assertEqual(
                    source["known_counts"][facts["count_key"]],
                    facts["count"],
                )
                self.assertNotIn("include", source["acquisition"])
                self.assertNotIn("exclude", source["acquisition"])

        tomato_93 = by_id["tomato-bangladesh-93h9p62kg4-v1"]
        self.assertEqual(tomato_93["known_counts"]["provider_visible_image_files"], 2627)
        seasonal = by_id["maize-seasonal-corn-v1"]
        self.assertEqual(seasonal["known_counts"]["publisher_reported_augmented_images"], 7500)
        plantcity = by_id["plantcity-pakistan-v2"]
        self.assertEqual(plantcity["known_counts"]["publisher_reported_post_augmentation_images"], 52219)


class ProviderDiscoveryTests(unittest.TestCase):
    def test_direct_http_file_uses_registry_size_and_sha256(self):
        remote = subject.discover_http_files(
            {
                "url": "https://downloads.example/archive.zip",
                "filename": "archive.zip",
                "expected_size": 6,
                "expected_sha256": hashlib.sha256(b"abcdef").hexdigest(),
            }
        )[0]
        self.assertEqual(remote.relative_path, "archive.zip")
        self.assertEqual(remote.expected_size, 6)
        self.assertEqual(remote.expected_sha256, hashlib.sha256(b"abcdef").hexdigest())

    def test_figshare_file_metadata_is_normalized_and_filtered(self):
        calls = []

        def fetcher(url):
            calls.append(url)
            return fixture("figshare_files.json")

        files = subject.discover_figshare_files(
            {"article_id": 29298275},
            fetcher=fetcher,
            cli_include=("*.zip",),
        )
        self.assertEqual(calls, ["https://api.figshare.com/v2/articles/29298275/files"])
        self.assertEqual([item.relative_path for item in files], ["Maize_Dataset.zip"])
        self.assertEqual(files[0].expected_size, 6)
        self.assertEqual(files[0].expected_md5, "e80b5017098950fc58aad83c8c14978e")

    def test_mendeley_folder_paths_and_raw_only_selector(self):
        calls = []
        files_by_folder = {
            "root": fixture("mendeley_files_root.json"),
            "raw-root": fixture("mendeley_files_raw_root.json"),
            "raw-maize": [],
            "raw-maize-rust": fixture("mendeley_files_rust.json"),
        }

        def fetcher(url):
            calls.append(url)
            if "/folders/1" in url:
                return fixture("mendeley_folders.json")
            query = urllib.parse.parse_qs(urllib.parse.urlparse(url).query)
            folder_id = query["folder_id"][0]
            if folder_id.startswith("aug-"):
                self.fail("Augmented folders must not be queried when Raw Data/** is selected")
            return files_by_folder[folder_id]

        files = subject.discover_mendeley_files(
            {
                "dataset_id": "fixture-id",
                "version": 1,
                "include": ["Raw Data/**"],
                "exclude": ["CCMT Dataset-Augmented/**"],
            },
            fetcher=fetcher,
        )
        self.assertEqual(
            [item.relative_path for item in files],
            ["Raw Data/labels.csv", "Raw Data/Maize/Rust/leaf-001.jpg"],
        )
        self.assertEqual(files[1].expected_sha256, hashlib.sha256(b"abcdef").hexdigest())
        self.assertEqual(len(calls), 5)  # one folder-tree request, root, and three raw folders

    def test_mendeley_folder_cycle_is_rejected(self):
        with self.assertRaisesRegex(subject.AcquisitionError, "Cycle"):
            subject.build_mendeley_folder_paths(
                [
                    {"id": "a", "name": "A", "parent_id": "b"},
                    {"id": "b", "name": "B", "parent_id": "a"},
                ]
            )

    def test_mendeley_download_all_uses_published_zip_hash_and_size(self):
        calls = []

        def fetcher(url):
            calls.append(url)
            return fixture("mendeley_zip.json")

        remote = subject.discover_mendeley_zip(
            {"dataset_id": "fixture-id", "version": 1},
            fetcher=fetcher,
        )
        self.assertEqual(
            calls,
            ["https://data.mendeley.com/api/datasets-v2/datasets/fixture-id/zip?version=1"],
        )
        self.assertEqual(remote.expected_size, 6)
        self.assertEqual(remote.expected_sha256, hashlib.sha256(b"abcdef").hexdigest())
        self.assertEqual(
            remote.url,
            "https://data.mendeley.com/public-api/zip/fixture-id/download/1",
        )


class DownloadTests(unittest.TestCase):
    def test_resumes_part_file_and_verifies_sha256_and_size(self):
        payload = b"abcdef"
        remote = subject.RemoteFile(
            relative_path="sample.bin",
            url="https://data.example/sample.bin",
            expected_size=len(payload),
            expected_sha256=hashlib.sha256(payload).hexdigest(),
        )
        requests = []

        def opener(request, timeout):
            requests.append(request)
            return FakeResponse(b"def", status=206, url="https://cdn.example/sample.bin")

        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / "sample.bin"
            destination.with_name("sample.bin.part").write_bytes(b"abc")
            result = subject.download_http(remote, destination, opener=opener, retries=0)
            self.assertEqual(destination.read_bytes(), payload)
            self.assertEqual(result.resumed_from, 3)
            self.assertEqual(result.sha256, hashlib.sha256(payload).hexdigest())
            self.assertEqual(requests[0].get_header("Range"), "bytes=3-")

    def test_server_ignoring_range_restarts_instead_of_appending(self):
        payload = b"abcdef"
        remote = subject.RemoteFile(
            relative_path="sample.bin",
            url="https://data.example/sample.bin",
            expected_size=len(payload),
            expected_sha256=hashlib.sha256(payload).hexdigest(),
        )
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / "sample.bin"
            destination.with_name("sample.bin.part").write_bytes(b"abc")
            result = subject.download_http(
                remote,
                destination,
                opener=lambda request, timeout: FakeResponse(payload, status=200),
                retries=0,
                progress=lambda message: None,
            )
            self.assertEqual(destination.read_bytes(), payload)
            self.assertEqual(result.size, len(payload))


class GitAcquisitionTests(unittest.TestCase):
    def test_existing_huggingface_checkout_emits_commit_and_tree_receipt(self):
        commit = "2b18be861bddeb525c83cf2d7e07eb7f649dfed9"
        repository = "https://huggingface.co/datasets/DigiGreen/Crop_Disease_Images"
        source = {
            "id": "locked-holdout",
            "acquisition": {
                "provider": "huggingface",
                "repository": repository,
                "ref": commit,
                "lfs": False,
            },
        }

        def fake_run(command, *, cwd=None):
            if command[-3:] == ["remote", "get-url", "origin"]:
                return repository
            if command[-2:] == ["rev-parse", "HEAD"]:
                return commit
            self.fail(f"Unexpected command: {command}")

        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder)
            (destination / "repository" / ".git").mkdir(parents=True)
            with mock.patch.object(subject, "_run", side_effect=fake_run), mock.patch.object(
                subject,
                "_tree_digest",
                return_value={"sha256": "a" * 64, "file_count": 10, "size": 1234},
            ):
                receipt = subject.acquire_git(source, destination)
        self.assertEqual(receipt["provider"], "huggingface")
        self.assertEqual(receipt["resolved_commit"], commit)
        self.assertEqual(receipt["tree"]["sha256"], "a" * 64)
        self.assertEqual(receipt["tree"]["size"], 1234)


class SafeExtractionTests(unittest.TestCase):
    def test_staging_directories_are_unique_children_of_requested_parent(self):
        with tempfile.TemporaryDirectory() as folder:
            parent = Path(folder) / "staging-parent"
            first = subject._make_inheriting_temp_directory(parent, ".extract-")
            second = subject._make_inheriting_temp_directory(parent, ".extract-")

            self.assertEqual(first.parent, parent)
            self.assertEqual(second.parent, parent)
            self.assertNotEqual(first, second)
            self.assertTrue(first.is_dir())
            self.assertTrue(second.is_dir())

    def test_extracts_a_valid_zip_transactionally(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive = root / "good.zip"
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.writestr("class-a/leaf.jpg", b"image")
            destination = root / "out"
            receipt = subject.safe_extract_zip(archive, destination)
            self.assertEqual((destination / "class-a" / "leaf.jpg").read_bytes(), b"image")
            self.assertEqual(receipt["member_count"], 1)

    def test_rejects_zip_slip_without_writing_outside_destination(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive = root / "evil.zip"
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.writestr("../escape.txt", b"no")
            with self.assertRaisesRegex(subject.AcquisitionError, "Unsafe relative path|escapes"):
                subject.safe_extract_zip(archive, root / "out")
            self.assertFalse((root / "escape.txt").exists())

    def test_rejects_zip_symlink(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            archive = root / "symlink.zip"
            link = zipfile.ZipInfo("link")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            with zipfile.ZipFile(archive, "w") as bundle:
                bundle.writestr(link, "../../outside")
            with self.assertRaisesRegex(subject.AcquisitionError, "symbolic links"):
                subject.safe_extract_zip(archive, root / "out")


if __name__ == "__main__":
    unittest.main()
