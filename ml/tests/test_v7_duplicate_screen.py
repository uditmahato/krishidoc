import sys
from pathlib import Path

import cv2
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

from audit_potato_v7_duplicates import features, geometric_match, screen


def row(i, split, group, label="healthy"):
    return {
        "review_id": i,
        "split": split,
        "group_id": group,
        "label": label,
        "sha256": str(i),
    }


def test_cross_split_connections_quarantine_without_reassignment():
    inventory = {
        "rows": [
            row(0, "train", "a"),
            row(1, "test", "b"),
            row(2, "train", "a"),
            row(3, "test", "c"),
        ],
        "excluded": [],
    }
    kept, excluded = screen(inventory, [{"a": 0, "b": 1}])
    assert [r["review_id"] for r in kept] == [3]
    assert {r["review_id"] for r in excluded} == {0, 1, 2}
    assert kept[0]["split"] == "test"


def test_quarantine_and_conflicting_labels_propagate():
    inventory = {
        "rows": [row(0, "train", "a"), row(1, "train", "b", "late")],
        "excluded": [{"sha256": "x", "label": "healthy", "exclusion": "prior_overlap"}],
    }
    assert not screen(inventory, [{"a": 0, "b": 1}, {"a": 0, "b": 2}])[0]
    assert not screen({**inventory, "excluded": []}, [{"a": 0, "b": 1}])[0]


def test_sift_detects_transformed_content_not_unrelated_image(tmp_path):
    rng = np.random.default_rng(42)
    a = rng.integers(0, 256, (480, 480), dtype=np.uint8)
    a = cv2.GaussianBlur(a, (3, 3), 0)
    b = cv2.warpAffine(a, cv2.getRotationMatrix2D((240, 240), 8, 0.95), (480, 480))
    c = cv2.GaussianBlur(rng.integers(0, 256, (480, 480), dtype=np.uint8), (3, 3), 0)
    files = [tmp_path / f"{i}.png" for i in range(3)]
    for path, data in zip(files, (a, b, c)):
        assert cv2.imwrite(str(path), data)
    fa, fb, fc = [features(p) for p in files]
    assert geometric_match(fa, fb)
    assert geometric_match(fa, fc) is None
