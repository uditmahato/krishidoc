"""Audit research-source additions without changing existing manifest rows.

Run inventory, inspect train/validation sheets, record exclusions, then build.
No model predictions are used. Original test split is never drawn on sheets.
"""

import argparse
import csv
import json
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageOps
from prepare_manifest import compute_phash, compute_sha256

ROOT = Path(__file__).resolve().parents[2]
RAW = ROOT / "ml/data/raw/plantseg-potato-v5"
OUT = ROOT / "ml/artifacts/potato_field_v5_20260907"
BASE = ROOT / "ml/data/prepared/manifest_field_v3_dg_rotation_1.csv"
MANIFEST = ROOT / "ml/data/prepared/manifest_field_v5_plantseg.csv"
CONFIG = ROOT / "ml/configs/potato_field_v5_plantseg_20260907.json"


def write_json(path, value):
    encoded = json.dumps(value, indent=2, sort_keys=True) + "\n"
    if path.exists() and path.read_text(encoding="utf-8") != encoded:
        raise ValueError(
            f"Frozen artifact already exists with different contents: {path}"
        )
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(encoded, encoding="utf-8")


def inventory():
    receipt = json.loads((RAW / "acquisition_receipt.json").read_text())
    rows = []
    for item in receipt["rows"]:
        if "/images/" not in item["file"]:
            continue
        path = ROOT / item["file"]
        if compute_sha256(path) != item["sha256"]:
            raise ValueError("Acquired bytes changed")
        with Image.open(path) as image:
            image.verify()
        label = next(
            x
            for x in ("potato_early_blight", "potato_late_blight")
            if path.name.startswith(x)
        )
        rows.append(
            {
                **item,
                "name": path.name,
                "split": {"val": "validation"}.get(path.parent.name, path.parent.name),
                "label": label,
                "phash": compute_phash(path),
            }
        )
    rows.sort(key=lambda x: (x["split"], x["name"]))
    write_json(
        OUT / "inventory.json",
        {
            "acquisition_sha256": compute_sha256(RAW / "acquisition_receipt.json"),
            "rows": rows,
        },
    )
    review = [r for r in rows if r["split"] != "test"]
    for start in range(0, len(review), 30):
        sheet = Image.new("RGB", (1200, 1080), "white")
        draw = ImageDraw.Draw(sheet)
        for index, row in enumerate(review[start : start + 30]):
            x, y = (index % 6) * 200, (index // 6) * 216
            with Image.open(ROOT / row["file"]) as im:
                thumb = ImageOps.contain(im.convert("RGB"), (194, 177))
                sheet.paste(thumb, (x, y))
            draw.text(
                (x, y + 179),
                f"{start + index}: {row['split']} {row['label'][7:12]}",
                fill="black",
            )
            draw.text(
                (x, y + 193),
                row["name"].replace("potato_", "").replace("blight_", "")[:31],
                fill="black",
            )
        sheet.save(OUT / f"review_{start // 30:02d}.jpg", quality=92)
    print(Counter((r["split"], r["label"]) for r in rows))


def build():
    rows = json.loads((OUT / "inventory.json").read_text())["rows"]
    review = json.loads(
        (ROOT / "ml/datasets/plantseg_potato_review_20260907.json").read_text()
    )
    if review["inventory_sha256"] != compute_sha256(OUT / "inventory.json"):
        raise ValueError("Visual-review inventory changed")
    with BASE.open(newline="", encoding="utf-8-sig") as stream:
        reader = csv.DictReader(stream)
        base = list(reader)
        fields = reader.fieldnames
    # Reference all prior rows and consumed photo tests; exclusion is stricter
    # than the repository's distance-4 audit. pHash cannot prove independence.
    reference = [(r["sha256"], int(r["phash"], 16)) for r in base]
    for path in (ROOT / "ml/data/raw/google_potato_audit_20260906/reviewed").glob("*"):
        if path.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp"}:
            reference.append((compute_sha256(path), int(compute_phash(path), 16)))
    # Already-consumed Bangladesh challenge also remains excluded.
    with (ROOT / "ml/artifacts/potato_field_v4_20260906/challenge.csv").open(
        newline="", encoding="utf-8-sig"
    ) as stream:
        reference.extend(
            (r["sha256"], int(r["phash"], 16)) for r in csv.DictReader(stream)
        )
    parent = list(range(len(rows)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    for i, row in enumerate(rows):
        for j in range(i):
            if (
                row["sha256"] == rows[j]["sha256"]
                or (int(row["phash"], 16) ^ int(rows[j]["phash"], 16)).bit_count() <= 8
            ):
                parent[find(i)] = find(j)
    reasons = {}
    for i, row in enumerate(rows):
        if row["name"] in review["excluded"]:
            reasons[find(i)] = "visual_review: " + review["excluded"][row["name"]]
        if any(
            row["sha256"] == sha or (int(row["phash"], 16) ^ ph).bit_count() <= 8
            for sha, ph in reference
        ):
            reasons[find(i)] = "overlap_with_prior_data_or_consumed_challenge"
    groups = {}
    for i in range(len(rows)):
        groups.setdefault(find(i), []).append(rows[i])
    additions, excluded = [], []
    for root, group in groups.items():
        if len({(r["split"], r["label"]) for r in group}) > 1:
            reasons[root] = "near_duplicate_component_crosses_publisher_split_or_label"
        if root in reasons:
            excluded.extend({**r, "reason": reasons[root]} for r in group)
            continue
        group_id = "plantseg_" + min(r["sha256"] for r in group)[:20]
        seen = set()
        for row in group:
            if row["sha256"] in seen:
                excluded.append({**row, "reason": "exact_duplicate_in_same_component"})
                continue
            seen.add(row["sha256"])
            additions.append(
                {
                    "image_path": row["file"],
                    "crop": "potato",
                    "condition_label": row["label"],
                    "validity_label": "usable_target_leaf",
                    "split": row["split"],
                    "source_id": "plantseg_potato_v5",
                    "group_id": group_id,
                    "sha256": row["sha256"],
                    "phash": row["phash"],
                    "is_derivative": "0",
                    "is_field": "1",
                    "source_locked_split": "",
                }
            )
    if MANIFEST.exists() or CONFIG.exists():
        raise ValueError("Never overwrite a frozen experiment")
    with MANIFEST.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=fields)
        writer.writeheader()
        writer.writerows(base + additions)
    receipt = {
        "base_sha256": compute_sha256(BASE),
        "manifest_sha256": compute_sha256(MANIFEST),
        "inventory_sha256": compute_sha256(OUT / "inventory.json"),
        "review_sha256": compute_sha256(
            ROOT / "ml/datasets/plantseg_potato_review_20260907.json"
        ),
        "added_counts": dict(
            Counter(r["split"] + ":" + r["condition_label"] for r in additions)
        ),
        "excluded": excluded,
        "near_duplicate_distance": 8,
        "limitations": "No farm/photographer IDs; original splits plus hash exclusions do not establish full independence. Tanzania is quarantined pending expert label review. Holeta untouched.",
    }
    write_json(OUT / "extension_receipt.json", receipt)
    config = json.loads(
        (ROOT / "ml/configs/potato_field_v4_task_balanced_20260906.json").read_text()
    )
    config.update(
        run_name="potato_field_v5_plantseg_20260907",
        seed=20260907,
        manifest=MANIFEST.relative_to(ROOT).as_posix(),
        epochs=4,
        samples_per_epoch=16000,
        learning_rate=0.0001,
        status="research_only_new_source_extension",
        limitations=[
            "No app promotion. Public-source research only; Nepal validation and upstream image rights unresolved.",
            "Parent rows unchanged; PlantSeg original splits retained, near-duplicate components excluded at distance eight.",
            "Tanzania disease labels quarantined, no optimization or calibration. Google/Bangladesh consumed diagnostics are not holdouts.",
            "No new-source healthy class. Holeta whole-source withheld until candidate and calibration frozen.",
        ],
    )
    config["finetune_from"]["parent_manifest"] = {
        "path": BASE.relative_to(ROOT).as_posix(),
        "sha256": compute_sha256(BASE),
    }
    snap = config["data_snapshot"]
    snap.update(
        manifest_sha256=compute_sha256(MANIFEST),
        audit_receipt="ml/data/prepared/audit_receipt_field_v5_plantseg.json",
    )
    for name, path in {
        "extension_receipt": OUT / "extension_receipt.json",
        "new_source_acquisition": RAW / "acquisition_receipt.json",
        "visual_review": ROOT / "ml/datasets/plantseg_potato_review_20260907.json",
    }.items():
        snap["required_artifacts"][name] = {
            "path": path.relative_to(ROOT).as_posix(),
            "sha256": compute_sha256(path),
        }
    write_json(CONFIG, config)
    print(json.dumps(receipt["added_counts"], indent=2))
    print("Excluded", len(excluded))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["inventory", "build"])
    args = parser.parse_args()
    {"inventory": inventory, "build": build}[args.action]()
