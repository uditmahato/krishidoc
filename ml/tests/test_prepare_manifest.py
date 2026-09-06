from __future__ import annotations

import json
import random
from copy import deepcopy
from pathlib import Path

import pytest
from PIL import Image, PngImagePlugin

from ml.scripts.prepare_manifest import (
    CANONICAL_COLUMNS,
    DEFAULT_SPLIT_RATIOS,
    ImageRecord,
    MAXIMUM_NUMERIC_CAPTURE_GAP,
    MAXIMUM_NUMERIC_CAPTURE_PHASH_DISTANCE,
    ManifestPreparationError,
    NUMERIC_CAPTURE_CONFIG_KEY,
    _cluster_records,
    _glob_matches,
    _infer_base_group,
    _infer_numeric_capture,
    _is_derivative,
    _label_for_path,
    build_manifest,
    hamming_distance,
    load_aliases,
)


def _write_noise_image(path: Path, seed: int, *, note: str | None = None) -> None:
    randomiser = random.Random(seed)
    pixels = bytes(randomiser.randrange(256) for _ in range(48 * 48 * 3))
    image = Image.frombytes("RGB", (48, 48), pixels)
    path.parent.mkdir(parents=True, exist_ok=True)
    metadata = None
    if note is not None:
        metadata = PngImagePlugin.PngInfo()
        metadata.add_text("fixture-note", note)
    image.save(path, pnginfo=metadata)


def _write_aliases(path: Path) -> None:
    aliases = {
        "schema_version": 1,
        "validity_labels": [
            "usable_target_leaf",
            "unsuitable_target_crop_view",
            "wrong_crop_leaf",
            "other_plant",
            "non_plant",
        ],
        "profiles": {
            "maize": {
                "class_aliases": {
                    "maize_healthy": {
                        "crop": "maize",
                        "condition_label": "maize_healthy",
                        "validity_label": "usable_target_leaf",
                    }
                },
                "derivative_globs": ["**/augmented/**"],
            }
        },
        "sources": {
            "fixture-source": {"profiles": ["maize"], "is_field": True},
            "external-source": {
                "is_field": True,
                "requires_metadata": True,
                "locked_split": "external_test",
            },
        },
    }
    path.write_text(json.dumps(aliases), encoding="utf-8")


def _make_fixture_corpus(tmp_path: Path) -> tuple[Path, Path, dict]:
    raw_root = tmp_path / "raw"
    source = raw_root / "fixture-source" / "extracted" / "maize_healthy"
    for index in range(30):
        _write_noise_image(source / f"image_{index:02d}.png", index + 100)

    # Same decoded pixels but different PNG bytes: pHash catches what SHA cannot.
    _write_noise_image(source / "visual_variant.png", 101, note="different bytes")
    derivative = source / "augmented" / "image_00_aug.png"
    _write_noise_image(derivative, 100, note="derived copy")

    external = raw_root / "external-source"
    sidecar_rows = [
        "relative_path,crop,condition_label,validity_label,group_id,is_derivative"
    ]
    for index in range(3):
        relative = f"photos/external_{index}.png"
        _write_noise_image(external / relative, index + 1000)
        sidecar_rows.append(
            f"{relative},maize,maize_healthy,usable_target_leaf,external-{index},0"
        )
    (external / ".labels.csv").write_text(
        "\n".join(sidecar_rows) + "\n", encoding="utf-8"
    )

    aliases_path = tmp_path / "aliases.json"
    _write_aliases(aliases_path)
    config = {
        "seed": 17,
        "split_policy": {
            "near_duplicate_hamming_distance": 4,
            "locked_external_test_sources": ["external-source"],
            "future_nepal_test_source": "nepal_field_locked_v1",
        },
    }
    return raw_root, aliases_path, config


def test_build_manifest_is_deterministic_and_split_locked(tmp_path: Path) -> None:
    raw_root, aliases_path, config = _make_fixture_corpus(tmp_path)
    rows = build_manifest(
        raw_root,
        tmp_path / "manifest.csv",
        aliases_path,
        config=config,
        seed=17,
    )
    repeated = build_manifest(
        raw_root,
        tmp_path / "manifest-repeated.csv",
        aliases_path,
        config=config,
        seed=17,
    )

    assert set(CANONICAL_COLUMNS).issubset(rows[0])
    assert {row["is_field"] for row in rows} == {"1"}
    assert {
        (Path(row["image_path"]).name, row["group_id"], row["split"]) for row in rows
    } == {
        (Path(row["image_path"]).name, row["group_id"], row["split"])
        for row in repeated
    }
    assert {row["split"] for row in rows}.issuperset(
        {"train", "validation", "calibration", "test", "external_test"}
    )

    external = [row for row in rows if row["source_id"] == "external-source"]
    assert external
    assert {row["split"] for row in external} == {"external_test"}
    assert {row["source_locked_split"] for row in external} == {"external_test"}

    by_name = {Path(row["image_path"]).name: row for row in rows}
    original = by_name["image_00.png"]
    derivative = by_name["image_00_aug.png"]
    assert derivative["is_derivative"] == "1"
    assert original["sha256"] != derivative["sha256"]
    assert original["phash"] == derivative["phash"]
    assert original["group_id"] == derivative["group_id"]
    assert original["split"] == derivative["split"] == "train"

    visual_original = by_name["image_01.png"]
    visual_variant = by_name["visual_variant.png"]
    assert visual_original["sha256"] != visual_variant["sha256"]
    assert hamming_distance(visual_original["phash"], visual_variant["phash"]) <= 4
    assert visual_original["group_id"] == visual_variant["group_id"]
    assert visual_original["split"] == visual_variant["split"]


def test_auto_emits_repo_relative_paths_inside_worktree(tmp_path: Path) -> None:
    repo_root = tmp_path / "portable-repo"
    (repo_root / ".git").mkdir(parents=True)
    raw_root, aliases_path, config = _make_fixture_corpus(repo_root)
    output = repo_root / "ml" / "data" / "prepared" / "manifest.csv"

    rows = build_manifest(raw_root, output, aliases_path, config=config, seed=17)

    assert all(not Path(row["image_path"]).is_absolute() for row in rows)
    assert all(row["image_path"].startswith("raw/") for row in rows)
    assert all("\\" not in row["image_path"] for row in rows)


def test_explicit_path_modes_are_fail_closed(tmp_path: Path) -> None:
    raw_root, aliases_path, config = _make_fixture_corpus(tmp_path)
    absolute_rows = build_manifest(
        raw_root,
        tmp_path / "absolute.csv",
        aliases_path,
        config=config,
        path_mode="absolute",
    )
    assert all(Path(row["image_path"]).is_absolute() for row in absolute_rows)

    unrelated_root = tmp_path / "unrelated-repository"
    unrelated_root.mkdir()
    with pytest.raises(ManifestPreparationError, match="outside repository root"):
        build_manifest(
            raw_root,
            tmp_path / "relative.csv",
            aliases_path,
            config=config,
            path_mode="repo-relative",
            repo_root=unrelated_root,
        )


def test_filename_time_bucket_groups_central_java_capture_bursts() -> None:
    source_config = {
        "filename_time_bucket": {
            "bucket_seconds": 300,
            "timezone_offset_minutes": 420,
            "scope": "source",
        }
    }
    camera_start = _infer_base_group(
        "Healthy/19700101_070000.jpg", "potato-central-java", source_config, None
    )
    camera_end = _infer_base_group(
        "Fungi/19700101_070459392.jpg",
        "potato-central-java",
        source_config,
        None,
    )
    epoch_same_bucket = _infer_base_group(
        "Virus/0000000299999.jpg", "potato-central-java", source_config, None
    )
    next_bucket = _infer_base_group(
        "Healthy/19700101_070500.jpg", "potato-central-java", source_config, None
    )
    unrecognised = _infer_base_group(
        "Healthy/IMG_0318.JPG", "potato-central-java", source_config, None
    )

    assert camera_start == camera_end == epoch_same_bucket
    assert next_bucket != camera_start
    assert unrecognised.endswith(":healthy:img_0318")


def _numeric_capture_record(
    relative_path: str,
    *,
    source_id: str,
    condition_label: str,
    phash: str,
    ordinal: int,
) -> ImageRecord:
    config = {
        "filename_numeric_capture_group": {
            "regex": r"^(?P<prefix>[a-z-]+)\s*\((?P<number>\d+)\)$",
            "maximum_adjacent_gap": 1,
            "maximum_phash_distance": 12,
            "scope": "parent",
        }
    }
    label = {
        "crop": "potato",
        "condition_label": condition_label,
        "validity_label": "usable_target_leaf",
    }
    capture = _infer_numeric_capture(relative_path, source_id, config, label)
    assert capture is not None
    return ImageRecord(
        path=Path(relative_path),
        relative_path=relative_path,
        source_id=source_id,
        crop=label["crop"],
        condition_label=label["condition_label"],
        validity_label=label["validity_label"],
        base_group=capture.base_group,
        sha256=f"{ordinal:064x}",
        phash=phash,
        is_derivative=False,
        is_field=True,
        source_locked_split="",
        numeric_capture=capture,
    )


def test_numeric_filename_grouping_locks_collisions_and_guarded_bursts() -> None:
    records = [
        # Same numeric stem is one ambiguous lineage even when pixels differ.
        _numeric_capture_record(
            "extracted/EB/EB/early-blight (1).JPG",
            source_id="pldd-up",
            condition_label="potato_early_blight",
            phash="0000000000000000",
            ordinal=1,
        ),
        _numeric_capture_record(
            "extracted/EB/EB/early-blight (1).jpeg",
            source_id="pldd-up",
            condition_label="potato_early_blight",
            phash="ffffffffffffffff",
            ordinal=2,
        ),
        # Distance 8 is above the global distance 4, but below the numeric
        # neighbour guard 12, so this is treated as a capture burst.
        _numeric_capture_record(
            "extracted/EB/EB/early-blight (2).JPG",
            source_id="pldd-up",
            condition_label="potato_early_blight",
            phash="00000000000000ff",
            ordinal=3,
        ),
        # An adjacent number without visual corroboration stays independent.
        _numeric_capture_record(
            "extracted/EB/EB/early-blight (3).JPG",
            source_id="pldd-up",
            condition_label="potato_early_blight",
            phash="aaaaaaaaaaaaaaaa",
            ordinal=4,
        ),
        # A visually close item two numbers away is outside the configured gap.
        _numeric_capture_record(
            "extracted/EB/EB/early-blight (4).JPG",
            source_id="pldd-up",
            condition_label="potato_early_blight",
            phash="0000000000000ff0",
            ordinal=5,
        ),
        # Filename evidence never crosses a canonical condition class.
        _numeric_capture_record(
            "extracted/LB/LB/late-blight (2).JPG",
            source_id="pldd-up",
            condition_label="potato_late_blight",
            phash="0000000000000f0f",
            ordinal=6,
        ),
        # Nor does it cross a source boundary.
        _numeric_capture_record(
            "extracted/EB/EB/early-blight (2).JPG",
            source_id="another-source",
            condition_label="potato_early_blight",
            phash="0000000000003333",
            ordinal=7,
        ),
        # Even a close immediate neighbour remains independent across the
        # exact extension cohorts used by PLDD-UP's separate imports.
        _numeric_capture_record(
            "extracted/EB/EB/early-blight (20).JPG",
            source_id="pldd-up",
            condition_label="potato_early_blight",
            phash="123456789abcdef0",
            ordinal=8,
        ),
        _numeric_capture_record(
            "extracted/EB/EB/early-blight (21).jpeg",
            source_id="pldd-up",
            condition_label="potato_early_blight",
            phash="123456789abcde0f",
            ordinal=9,
        ),
    ]

    repeated = list(reversed(deepcopy(records)))
    _cluster_records(records, near_duplicate_distance=4)
    _cluster_records(repeated, near_duplicate_distance=4)

    assert records[0].group_id == records[1].group_id == records[2].group_id
    assert records[3].group_id != records[2].group_id
    assert records[4].group_id != records[2].group_id
    assert records[5].group_id != records[2].group_id
    assert records[6].group_id != records[2].group_id
    assert records[7].group_id != records[8].group_id
    expected = {
        (record.source_id, record.relative_path, record.sha256): record.group_id
        for record in records
    }
    assert {
        (record.source_id, record.relative_path, record.sha256): record.group_id
        for record in repeated
    } == expected


def test_numeric_capture_grouping_rejects_non_conservative_threshold(
    tmp_path: Path,
) -> None:
    aliases = {
        "schema_version": 1,
        "validity_labels": sorted(
            {
                "usable_target_leaf",
                "unsuitable_target_crop_view",
                "wrong_crop_leaf",
                "other_plant",
                "non_plant",
            }
        ),
        "sources": {
            "unsafe-source": {
                "is_field": True,
                "filename_numeric_capture_group": {
                    "regex": r"^(?P<number>\d+)$",
                    "maximum_adjacent_gap": 1,
                    "maximum_phash_distance": 17,
                    "scope": "parent",
                },
            }
        },
    }
    path = tmp_path / "unsafe-aliases.json"
    path.write_text(json.dumps(aliases), encoding="utf-8")

    with pytest.raises(ManifestPreparationError, match="between 0 and 16"):
        load_aliases(path)


def test_manifest_schema_pins_numeric_capture_safety_bounds() -> None:
    schema_path = Path(__file__).parents[1] / "datasets" / "manifest_schema_v1.json"
    schema = json.loads(schema_path.read_text(encoding="utf-8"))
    contract = schema["source_grouping_contracts"][NUMERIC_CAPTURE_CONFIG_KEY]

    assert contract["safety_bounds"] == {
        "maximum_adjacent_gap": [1, MAXIMUM_NUMERIC_CAPTURE_GAP],
        "maximum_phash_distance": [
            0,
            MAXIMUM_NUMERIC_CAPTURE_PHASH_DISTANCE,
        ],
    }
    assert {"source_id", "crop", "condition_label", "validity_label"}.issubset(
        contract["key_isolation"]
    )


def test_unforced_groups_follow_70_10_10_10_policy(tmp_path: Path) -> None:
    raw_root, aliases_path, config = _make_fixture_corpus(tmp_path)
    rows = build_manifest(
        raw_root, tmp_path / "manifest.csv", aliases_path, config=config
    )
    group_splits: dict[str, str] = {}
    for row in rows:
        if row["source_id"] == "fixture-source" and row["is_derivative"] == "0":
            group_splits[row["group_id"]] = row["split"]
    counts = {
        split: list(group_splits.values()).count(split)
        for split in DEFAULT_SPLIT_RATIOS
    }
    total = sum(counts.values())
    # One duplicate family is force-moved to train by its derivative; the
    # remainder is apportioned exactly by group with at most one-group rounding.
    for split, ratio in DEFAULT_SPLIT_RATIOS.items():
        assert abs(counts[split] - ratio * total) <= 2


def test_corrupt_image_aborts_without_publishing_manifest(tmp_path: Path) -> None:
    raw_root, aliases_path, config = _make_fixture_corpus(tmp_path)
    corrupt = raw_root / "fixture-source" / "extracted" / "maize_healthy" / "broken.jpg"
    corrupt.write_bytes(b"this is not an image")
    output = tmp_path / "manifest.csv"

    with pytest.raises(ManifestPreparationError, match="corrupt image"):
        build_manifest(raw_root, output, aliases_path, config=config)
    assert not output.exists()


def test_unknown_source_fails_closed(tmp_path: Path) -> None:
    raw_root, aliases_path, config = _make_fixture_corpus(tmp_path)
    _write_noise_image(raw_root / "not-registered" / "mystery.png", 9000)

    with pytest.raises(ManifestPreparationError, match="has no entry"):
        build_manifest(raw_root, tmp_path / "manifest.csv", aliases_path, config=config)


def test_disease_rot_is_not_mistaken_for_rotation_augmentation() -> None:
    assert not _is_derivative(
        "extracted/tomato_diseases/Blossom_end_rot_d/photo.jpg", {}, None
    )
    assert _is_derivative("class/augmented/photo.jpg", {}, None)
    assert _is_derivative("class/photo_rot90.jpg", {}, None)


def test_historical_v1_potato_sources_remain_readable() -> None:
    aliases = load_aliases(
        Path(__file__).parents[1] / "datasets" / "label_aliases.json"
    )

    pldd_up = aliases["sources"]["pldd-up"]
    assert _label_for_path("EB/example.jpg", pldd_up, None) == {
        "crop": "potato",
        "condition_label": "potato_early_blight",
        "validity_label": "usable_target_leaf",
    }
    assert _label_for_path("LB/example.jpg", pldd_up, None) == {
        "crop": "potato",
        "condition_label": "potato_late_blight",
        "validity_label": "usable_target_leaf",
    }
    assert pldd_up["filename_numeric_capture_group"] == {
        "regex": r"^(?P<prefix>[a-z-]+)\s*\((?P<number>\d+)\)$",
        "maximum_adjacent_gap": 1,
        "maximum_phash_distance": 12,
        "scope": "parent",
    }

    bangladesh = aliases["sources"]["potato-bangladesh"]
    assert _glob_matches(
        "extracted/Potato Leaf Disease Dataset/Healthy/aug_0_42.jpg",
        bangladesh["exclude_globs"],
    )
    assert not _glob_matches(
        "extracted/Potato Leaf Disease Dataset/Healthy/orig_42.jpg",
        bangladesh["exclude_globs"],
    )


def test_v2_central_java_is_train_only_open_set_exposure() -> None:
    aliases = load_aliases(
        Path(__file__).parents[1] / "datasets" / "label_aliases_v2.json"
    )
    central_java = aliases["sources"]["potato-central-java"]

    assert central_java["locked_split"] == "train"
    assert central_java["filename_time_bucket"] == {
        "bucket_seconds": 600,
        "timezone_offset_minutes": 420,
        "scope": "parent",
    }
    root = (
        "extracted/ptz377bwb8-v1-direct/"
        "Potato Leaf Disease Dataset in Uncontrolled Environment"
    )
    assert _label_for_path(f"{root}/Healthy/example.jpg", central_java, None) == {
        "crop": "potato",
        "condition_label": "potato_healthy",
        "validity_label": "usable_target_leaf",
    }
    for broad_category in (
        "Bacteria",
        "Fungi",
        "Nematode",
        "Pest",
        "Phytopthora",
        "Virus",
    ):
        assert _label_for_path(
            f"{root}/{broad_category}/example.jpg", central_java, None
        ) == {
            "crop": "potato",
            "condition_label": "potato_other_unknown",
            "validity_label": "usable_target_leaf",
        }

    assert _label_for_path(f"{root}/Unreviewed/example.jpg", central_java, None) is None
    assert "phytophthora" not in aliases["profiles"]["potato_single_crop"][
        "class_aliases"
    ]
    assert "phytopthora" not in aliases["profiles"]["potato_single_crop"][
        "class_aliases"
    ]


def test_v2_central_java_real_layout_is_discovered_and_train_locked(
    tmp_path: Path,
) -> None:
    raw_root = tmp_path / "raw"
    source_root = (
        raw_root
        / "potato-central-java"
        / "extracted"
        / "ptz377bwb8-v1-direct"
        / "Potato Leaf Disease Dataset in Uncontrolled Environment"
    )
    _write_noise_image(source_root / "Healthy" / "20230712_120001.jpg", 9101)
    _write_noise_image(source_root / "Fungi" / "20230712_120002.jpg", 9102)

    rows = build_manifest(
        raw_root,
        tmp_path / "manifest.csv",
        Path(__file__).parents[1] / "datasets" / "label_aliases_v2.json",
        config={"seed": 31},
        seed=31,
        selected_sources={"potato-central-java"},
        path_mode="absolute",
    )

    assert len(rows) == 2
    assert {row["source_id"] for row in rows} == {"potato-central-java"}
    assert {row["split"] for row in rows} == {"train"}
    assert {row["source_locked_split"] for row in rows} == {"train"}
    assert {row["condition_label"] for row in rows} == {
        "potato_healthy",
        "potato_other_unknown",
    }
    assert len({row["group_id"] for row in rows}) == 2
