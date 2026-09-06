from __future__ import annotations

import csv
import io
import json
from pathlib import Path

import pytest

from ml.scripts import download_datasets
from ml.scripts import stage_openimages_negatives as subject


def policy() -> dict:
    return {
        "schema_version": 1,
        "source_id": "fixture",
        "dataset_version": "V7",
        "split": "validation",
        "selection_seed": 7,
        "default_limit": 3,
        "max_per_primary_class": 1,
        "minimum_primary_box_area": 0.2,
        "metadata_urls": {
            "class_descriptions": "https://example.test/classes.csv",
            "human_image_labels": "https://example.test/labels.csv",
            "bounding_boxes": "https://example.test/boxes.csv",
            "image_information": "https://example.test/images.csv",
        },
        "official_image_url_template": "https://images.test/validation/{image_id}.jpg",
        "annotation_license": {"spdx": "CC-BY-4.0"},
        "accepted_pixel_license_urls": ["https://creativecommons.org/licenses/by/2.0/"],
        "target_box_labels": ["Clock", "Laptop"],
        "blocked_label_terms": ["plant", "person", "food"],
        "review_status": "manual_review_required",
        "admission_status": "staged_not_admitted",
        "safety_note": "manual review",
    }


def info(image_id: str, *, license_url: str = "https://creativecommons.org/licenses/by/2.0/"):
    return {
        "ImageID": image_id,
        "Subset": "validation",
        "OriginalURL": f"https://origin.test/{image_id}.jpg",
        "OriginalLandingURL": f"https://landing.test/{image_id}",
        "License": license_url,
        "AuthorProfileURL": "https://landing.test/author",
        "Author": "Photographer",
        "Title": "Object",
        "OriginalSize": "123",
        "OriginalMD5": "abc=",
        "Rotation": "0",
    }


def test_positive_plant_or_person_labels_are_excluded_and_negative_labels_do_not_block():
    classes = {"/clock": "Clock", "/plant": "Houseplant", "/person": "Person"}
    boxes = [
        subject.BoxCandidate("safe", "/clock", "Clock", 0.5),
        subject.BoxCandidate("plant", "/clock", "Clock", 0.6),
        subject.BoxCandidate("person", "/clock", "Clock", 0.7),
    ]
    positives = {
        "safe": {"Clock"},
        "plant": {"Clock", "Houseplant"},
        "person": {"Clock", "Person"},
    }
    rows = subject.select_candidates(
        policy=policy(),
        classes=classes,
        positives=positives,
        boxes=boxes,
        image_information={key: info(key) for key in positives},
        limit=3,
    )
    assert [row["image_id"] for row in rows] == ["safe"]
    assert rows[0]["review_status"] == "manual_review_required"
    assert rows[0]["admission_status"] == "staged_not_admitted"
    assert rows[0]["intended_review_outcome"] == "non_plant_candidate_only"
    assert "proposed_validity_label" not in rows[0]


def test_selector_is_balanced_deterministic_and_requires_per_image_cc_by():
    boxes = [
        subject.BoxCandidate("clock-b", "/clock", "Clock", 0.6),
        subject.BoxCandidate("laptop", "/laptop", "Laptop", 0.4),
        subject.BoxCandidate("clock-a", "/clock", "Clock", 0.8),
        subject.BoxCandidate("wrong-license", "/laptop", "Laptop", 0.9),
    ]
    metadata = {
        "clock-a": info("clock-a"),
        "clock-b": info("clock-b"),
        "laptop": info("laptop"),
        "wrong-license": info("wrong-license", license_url="https://example.test/all-rights-reserved"),
    }
    kwargs = dict(
        policy=policy(),
        classes={"/clock": "Clock", "/laptop": "Laptop"},
        positives={key: set() for key in metadata},
        image_information=metadata,
        limit=3,
    )
    first = subject.select_candidates(boxes=boxes, **kwargs)
    second = subject.select_candidates(boxes=list(reversed(boxes)), **kwargs)
    assert [row["image_id"] for row in first] == [row["image_id"] for row in second]
    assert {row["image_id"] for row in first} == {"clock-a", "laptop"}


def test_box_reader_requires_large_real_non_group_boxes(tmp_path: Path):
    path = tmp_path / "boxes.csv"
    with path.open("w", encoding="utf-8", newline="") as stream:
        writer = csv.DictWriter(
            stream,
            fieldnames=[
                "ImageID", "LabelName", "XMin", "XMax", "YMin", "YMax",
                "IsGroupOf", "IsDepiction", "IsInside",
            ],
        )
        writer.writeheader()
        writer.writerows(
            [
                {"ImageID": "large", "LabelName": "/clock", "XMin": "0", "XMax": "0.8", "YMin": "0", "YMax": "0.8", "IsGroupOf": "0", "IsDepiction": "0", "IsInside": "0"},
                {"ImageID": "tiny", "LabelName": "/clock", "XMin": "0", "XMax": "0.1", "YMin": "0", "YMax": "0.1", "IsGroupOf": "0", "IsDepiction": "0", "IsInside": "0"},
                {"ImageID": "depiction", "LabelName": "/clock", "XMin": "0", "XMax": "1", "YMin": "0", "YMax": "1", "IsGroupOf": "0", "IsDepiction": "1", "IsInside": "0"},
            ]
        )
    rows = subject.read_box_candidates(path, {"/clock": "Clock"}, ["Clock"], 0.2)
    assert [(row.image_id, row.area) for row in rows] == [("large", pytest.approx(0.64))]


def test_download_records_pixel_hash_and_never_marks_ready(tmp_path: Path):
    row = {
        column: "" for column in subject.SELECTION_COLUMNS
    }
    row.update(
        {
            "image_id": "abc",
            "primary_object_label": "Clock",
            "official_download_url": "https://images.test/validation/abc.jpg",
            "local_path": "images/abc.jpg",
            "license_url": "https://creativecommons.org/licenses/by/2.0/",
            "review_status": "manual_review_required",
            "admission_status": "staged_not_admitted",
            "download_status": "selected_not_downloaded",
        }
    )

    class Response(io.BytesIO):
        def __enter__(self):
            return self

        def __exit__(self, *args):
            self.close()

    def opener(request, timeout):
        assert request.full_url == row["official_download_url"]
        assert timeout == 120.0
        return Response(b"fake-jpeg")

    completed = subject.download_candidates([row], tmp_path, workers=1, opener=opener)
    assert completed[0]["sha256"] == subject.hashlib.sha256(b"fake-jpeg").hexdigest()
    assert completed[0]["download_status"] == "downloaded_verified"

    policy_path = tmp_path / "policy.json"
    policy_path.write_text(json.dumps(policy()), encoding="utf-8")
    receipt = subject.write_receipt(
        tmp_path / "receipt.json",
        policy_path=policy_path,
        policy=policy(),
        metadata=[],
        rows=completed,
    )
    assert receipt["manual_review_required"] is True
    assert receipt["ready_for_manifest"] is False
    assert receipt["assigned_training_label"] is None


def test_checked_in_policy_is_fail_closed():
    loaded = subject.load_policy(subject.DEFAULT_POLICY)
    assert loaded["review_status"] == "manual_review_required"
    assert loaded["admission_status"] == "staged_not_admitted"
    assert loaded["default_limit"] == 750


def test_source_registry_keeps_openimages_candidates_manual_and_unselected():
    registry = download_datasets.load_manifest(download_datasets.DEFAULT_MANIFEST)
    source = next(
        item for item in registry["sources"]
        if item["id"] == "openimages-v7-nonplant-candidates"
    )
    assert source["status"] == "review_required"
    assert source["default_selected"] is False
    assert source["license"]["spdx"] == "LicenseRef-OPENIMAGES-PER-IMAGE"
    assert source["acquisition"]["provider"] == "manual"
