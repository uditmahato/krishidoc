"""Prepare a paper-linked source extension; keep new test images off review sheets."""

import argparse
import csv
import hashlib
import json
import re
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps
from prepare_manifest import _BKTree, compute_phash, compute_sha256
from prepare_plantseg_extension import write_json

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "ml/artifacts/potato_field_v7_20260907"
BASE = ROOT / "ml/data/prepared/manifest_field_v5_plantseg.csv"
MANIFEST = ROOT / "ml/data/prepared/manifest_field_v7_tari.csv"
CONFIG = ROOT / "ml/configs/potato_field_v7_tari_20260907.json"
REVIEW = ROOT / "ml/datasets/potato_v7_visual_review.json"
SOURCES = ROOT / "ml/datasets/potato_field_v7_sources.json"


def fingerprint(row):
    path = ROOT / row["file"]
    if compute_sha256(path) != row["sha256"]:
        raise ValueError("Input bytes changed")
    with Image.open(path) as im:
        im.verify()
    return {**row, "phash": compute_phash(path)}


def inventory():
    specs = json.loads(SOURCES.read_text())["sources"]
    rows, identities = [], {}
    for spec in specs:
        receipt = ROOT / "ml/data/raw" / spec["id"] / "sampled/selection_receipt.json"
        data = json.loads(receipt.read_text())
        if len(data["rows"]) != 300 or data["source_url"] != spec["landing_url"]:
            raise ValueError("Incomplete or mismatched acquisition")
        identities[receipt.relative_to(ROOT).as_posix()] = compute_sha256(receipt)
        rows.extend({**r, "label": spec["condition_label"]} for r in data["rows"])
    with ThreadPoolExecutor(max_workers=8) as pool:
        rows = list(pool.map(fingerprint, rows))
    with BASE.open(newline="", encoding="utf-8-sig") as stream:
        base = list(csv.DictReader(stream))
    reference = [(r["sha256"], int(r["phash"], 16)) for r in base]
    challenge = ROOT / "ml/artifacts/potato_field_v5_20260907/evaluation_manifest.json"
    old = json.loads(challenge.read_text())["rows"]
    with ThreadPoolExecutor(max_workers=8) as pool:
        checked = list(
            pool.map(
                fingerprint,
                [{"file": r["image_path"], "sha256": r["sha256"]} for r in old],
            )
        )
    reference.extend((r["sha256"], int(r["phash"], 16)) for r in checked)
    tree = _BKTree()
    for i, (_, ph) in enumerate(reference):
        tree.add(ph, i)
    reference_bytes = {sha for sha, _ in reference}
    parent = list(range(len(rows)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(a, b):
        parent[find(a)] = find(b)

    blocks = {}
    for i, row in enumerate(rows):
        number = int(re.search(r"(\d+)\.[^.]+$", row["member"])[1])
        block = (row["label"], number // 100)
        if block in blocks:
            union(i, blocks[block])
        blocks[block] = i
        for j in range(i):
            if (
                row["sha256"] == rows[j]["sha256"]
                or (int(row["phash"], 16) ^ int(rows[j]["phash"], 16)).bit_count() <= 8
            ):
                union(i, j)
    groups = defaultdict(list)
    for i, row in enumerate(rows):
        groups[find(i)].append(row)
    included, excluded = [], []
    for group in groups.values():
        reason = None
        if len({r["label"] for r in group}) > 1:
            reason = "duplicate_component_has_conflicting_labels"
        if any(
            r["sha256"] in reference_bytes or tree.query(int(r["phash"], 16), 8)
            for r in group
        ):
            reason = "component_overlaps_prior_training_or_consumed_challenge"
        if reason:
            excluded.extend({**r, "exclusion": reason} for r in group)
            continue
        group_id = "tari_" + min(r["sha256"] for r in group)[:24]
        bucket = (
            int(
                hashlib.sha256(("v7-split-20260907:" + group_id).encode()).hexdigest(),
                16,
            )
            % 10
        )
        split = (
            "train"
            if bucket < 6
            else "validation"
            if bucket == 6
            else "calibration"
            if bucket == 7
            else "test"
        )
        seen = set()
        for row in sorted(group, key=lambda r: r["sha256"]):
            if row["sha256"] in seen:
                excluded.append({**row, "exclusion": "exact_duplicate"})
                continue
            seen.add(row["sha256"])
            included.append({**row, "split": split, "group_id": group_id})
    included.sort(key=lambda r: (r["split"], r["label"], r["file"]))
    for index, row in enumerate(included):
        row["review_id"] = index
    write_json(
        OUT / "inventory.json",
        {
            "rows": included,
            "excluded": excluded,
            "acquisition_sha256": identities,
            "base_sha256": compute_sha256(BASE),
            "consumed_challenge_sha256": compute_sha256(challenge),
            "split_rule": "numeric filename blocks of 100 plus distance-8 components; seeded hash buckets 60/10/10/20; no model results used",
            "limitations": "Filename blocks are only a conservative capture-sequence proxy. True farm/plant identifiers are unavailable; this is not a source-independent or Nepal holdout.",
        },
    )
    review_rows = [r for r in included if r["split"] != "test"]
    for start in range(0, len(review_rows), 48):
        sheet = Image.new("RGB", (1600, 1200), "white")
        draw = ImageDraw.Draw(sheet)
        for i, row in enumerate(review_rows[start : start + 48]):
            x, y = i % 8 * 200, i // 8 * 200
            with Image.open(ROOT / row["file"]) as im:
                sheet.paste(ImageOps.contain(im.convert("RGB"), (195, 165)), (x, y))
            draw.text(
                (x, y + 165),
                f"{row['review_id']} {row['split']} {row['label'][7:]}",
                fill="black",
            )
        sheet.save(OUT / f"review_{start // 48:02d}.jpg", quality=93)
    print(Counter((r["split"], r["label"]) for r in included))
    print("Excluded", len(excluded), "review sheets", (len(review_rows) + 47) // 48)


def build():
    inventory_path = OUT / "inventory.json"
    inventory_data = json.loads(inventory_path.read_text())
    review = json.loads(REVIEW.read_text())
    if review["inventory_sha256"] != compute_sha256(inventory_path):
        raise ValueError("Review does not match inventory")
    if compute_sha256(BASE) != inventory_data["base_sha256"]:
        raise ValueError("Base manifest changed")
    rows = inventory_data["rows"]
    reviewed = {r["review_id"] for r in rows if r["split"] != "test"}
    if set(review["reviewed_ids"]) != reviewed:
        raise ValueError(
            "Every development image must be reviewed; test stays untouched"
        )
    excluded_ids = {int(k) for k in review["excluded"]}
    if not excluded_ids <= reviewed:
        raise ValueError("Cannot manually select or exclude held-out test images")
    geometric_path = OUT / "geometric_duplicate_audit.json"
    geometric = json.loads(geometric_path.read_text())
    if geometric["inventory_sha256"] != compute_sha256(inventory_path):
        raise ValueError("Geometric duplicate audit does not match inventory")
    if geometric["script_sha256"] != compute_sha256(
        ROOT / "ml/scripts/audit_potato_v7_duplicates.py"
    ):
        raise ValueError("Geometric audit implementation changed")
    original = {r["review_id"]: r for r in rows}
    for row in geometric["rows"]:
        before = original[row["review_id"]]
        if any(row[k] != before[k] for k in before if k != "group_id"):
            raise ValueError("Geometric audit changed original image or split")
    from audit_potato_v7_duplicates import screen

    positions = {r["review_id"]: i for i, r in enumerate(rows)}
    manual_edges = []
    for a, b in review.get("same_leaf_development_pairs", []):
        if a not in reviewed or b not in reviewed:
            raise ValueError("Manual same-leaf decisions must use development only")
        manual_edges.append({"a": positions[a], "b": positions[b]})
    rows, duplicate_exclusions = screen(
        inventory_data, geometric["edges"] + manual_edges
    )
    excluded_groups = {r["group_id"] for r in rows if r["review_id"] in excluded_ids}
    rows = [r for r in rows if r["group_id"] not in excluded_groups]
    counts = Counter((r["split"], r["label"]) for r in rows)
    labels = ["potato_early_blight", "potato_late_blight", "potato_healthy"]
    for split, minimum in (
        ("train", 50),
        ("validation", 10),
        ("calibration", 10),
        ("test", 15),
    ):
        if any(counts[(split, label)] < minimum for label in labels):
            raise ValueError(f"Insufficient {split} coverage: {counts}")
    with BASE.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        base, fields = list(reader), reader.fieldnames
    additions = [
        {
            "image_path": r["file"],
            "crop": "potato",
            "condition_label": r["label"],
            "validity_label": "usable_target_leaf",
            "split": r["split"],
            "source_id": "potato_tari_8286529_v7",
            "group_id": r["group_id"],
            "sha256": r["sha256"],
            "phash": r["phash"],
            "is_derivative": "0",
            "is_field": "1",
            "source_locked_split": "",
        }
        for r in rows
    ]
    if MANIFEST.exists() or CONFIG.exists():
        raise ValueError("Preserve frozen experiment files")
    with MANIFEST.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(base + additions)
    write_json(
        OUT / "extension_receipt.json",
        {
            "base_sha256": compute_sha256(BASE),
            "manifest_sha256": compute_sha256(MANIFEST),
            "inventory_sha256": compute_sha256(inventory_path),
            "review_sha256": compute_sha256(REVIEW),
            "geometric_audit_sha256": compute_sha256(geometric_path),
            "added_counts": {f"{s}:{c}": n for (s, c), n in counts.items()},
            "excluded_visual_groups": sorted(excluded_groups),
            "duplicate_excluded_review_ids": sorted(
                r["review_id"] for r in duplicate_exclusions
            ),
        },
    )
    config = json.loads(
        (ROOT / "ml/configs/potato_field_v5_plantseg_20260907.json").read_text()
    )
    policy = json.loads((ROOT / config["source_evidence_policy"]).read_text())
    policy.update(
        policy_id="krishidoc-source-evidence-v7",
        description="V7 source extension; all existing evidence restrictions retained",
    )
    for source in ("plantseg_potato_v5", "potato_tari_8286529_v7"):
        policy["sources"][source] = {
            "title": source,
            "evidence_role": "training_or_internal_development",
            "selection_independent": False,
            "promotion_eligible": False,
            "reason": "This source contributes training; even untouched group-held-out images do not establish source-independent Nepal performance.",
        }
    policy_path = ROOT / "ml/datasets/source_evidence_policy_v7.json"
    write_json(policy_path, policy)
    config.update(
        run_name="potato_field_v7_tari_20260907",
        seed=20260909,
        manifest=MANIFEST.relative_to(ROOT).as_posix(),
        epochs=3,
        batch_size=16,
        samples_per_epoch=12000,
        learning_rate=0.00005,
        backbone_learning_rate_multiplier=0.1,
        freeze_backbone_epochs=0,
        freeze_backbone_batch_norm=True,
        monitor="source_balanced_safety_v1",
        monitor_source_ids=["pldd-up", "plantseg_potato_v5", "potato_tari_8286529_v7"],
        calibration_maximum_subgroup_false_accept_rate=0.05,
        source_evidence_policy=policy_path.relative_to(ROOT).as_posix(),
        status="research_only_bn_frozen_full_adaptation",
        limitations=[
            "No app promotion: new test is only group-held-out within a training source, not source-independent or Nepal validation.",
            "SIFT-geometric duplicate screening is not verified physical-leaf identity; residual duplicate risk remains. Healthy source images are predominantly close-ups.",
            "New data labels are publisher-reported pathologist-validated; KrishiDoc visual screening is not clinical adjudication.",
            "No quarantined Zenodo 17553016 samples admitted. No old test or calibration rows moved into training.",
            "Only nine usable unknown-condition calibration examples remain: separate cap and explicit small-sample flag, not a safety guarantee.",
            "All previous 749 challenge images remain excluded from additions and are consumed diagnostics only.",
        ],
    )
    snapshot = config["data_snapshot"]
    snapshot.update(
        manifest_sha256=compute_sha256(MANIFEST),
        audit_receipt="ml/data/prepared/audit_receipt_field_v7_tari.json",
    )
    artifacts = {
        "v7_extension": OUT / "extension_receipt.json",
        "v7_inventory": inventory_path,
        "v7_visual_review": REVIEW,
        "v7_geometric_audit": geometric_path,
        "v7_source_registry": SOURCES,
        "source_evidence_policy": policy_path,
    }
    artifacts.update(
        {
            f"v7_acquisition_{i}": ROOT / p
            for i, p in enumerate(inventory_data["acquisition_sha256"])
        }
    )
    for name, path in artifacts.items():
        snapshot["required_artifacts"][name] = {
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": compute_sha256(path),
        }
    write_json(CONFIG, config)
    print(json.dumps({f"{s}:{c}": n for (s, c), n in counts.items()}, indent=2))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["inventory", "build"])
    {"inventory": inventory, "build": build}[parser.parse_args().action]()
