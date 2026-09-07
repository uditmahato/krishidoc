import sys
import zipfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from sample_remote_zip import image_member


@pytest.mark.parametrize(
    "name",
    [
        "__MACOSX/healthy/._healthy0.jpg",
        "healthy/._healthy0.JPG",
        "healthy/",
        "healthy/README.txt",
    ],
)
def test_metadata_is_not_an_image(name):
    assert not image_member(zipfile.ZipInfo(name))


@pytest.mark.parametrize(
    "name", ["healthy/healthy0.jpg", "early/early0.PNG", "late/leaf.jpeg"]
)
def test_actual_image_names_are_included(name):
    assert image_member(zipfile.ZipInfo(name))
