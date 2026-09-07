import csv

import pytest
from krishidoc_ml.finetune_data import verify_manifest_extension
from krishidoc_ml.receipt import file_sha256


def save(path, rows):
    with path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


@pytest.fixture
def manifests(tmp_path):
    original = {
        "image_path": "old.jpg",
        "sha256": "a",
        "group_id": "g",
        "source_id": "s",
        "split": "test",
    }
    added = {
        "image_path": "new.jpg",
        "sha256": "b",
        "group_id": "h",
        "source_id": "t",
        "split": "train",
    }
    parent, current = tmp_path / "parent.csv", tmp_path / "current.csv"
    save(parent, [original])
    return parent, current, original, added


def test_extension_retains_parent_identity(manifests):
    parent, current, old, new = manifests
    save(current, [new, old])
    assert verify_manifest_extension(
        parent, current, file_sha256(parent)
    ) == file_sha256(parent)
    with pytest.raises(ValueError, match="SHA-256"):
        verify_manifest_extension(parent, current, "bad")


@pytest.mark.parametrize(
    "mutation",
    [
        "split",
        "remove",
        "sha256",
        "group_id",
        "source_id",
        "duplicate",
        "empty_extension",
    ],
)
def test_rejects_leakage_and_changed_history(manifests, mutation):
    parent, current, old, new = manifests
    rows = [old.copy(), new.copy()]
    if mutation == "split":
        rows[0]["split"] = "train"
    elif mutation == "remove":
        rows = [new]
    elif mutation == "duplicate":
        rows.append(old)
    elif mutation == "empty_extension":
        rows = [old]
    else:
        rows[1][mutation] = old[mutation]
    save(current, rows)
    with pytest.raises(ValueError):
        verify_manifest_extension(parent, current, file_sha256(parent))


def test_pipeline_refuses_extension_without_full_audit(manifests, tmp_path):
    from krishidoc_ml.pipeline import train_experiment

    parent, current, old, new = manifests
    save(current, [old, new])
    config = {
        "_config_path": __file__,
        "manifest": str(current),
        "finetune_from": {
            "parent_manifest": {"path": str(parent), "sha256": file_sha256(parent)}
        },
    }
    with pytest.raises(ValueError, match="full strict combined-data audit"):
        train_experiment(
            config=config,
            crop="potato",
            architecture="efficientnet_b0",
            condition_labels=["early", "late"],
            output_dir=tmp_path / "run",
            device_name="cpu",
        )
    assert not (tmp_path / "run").exists()
