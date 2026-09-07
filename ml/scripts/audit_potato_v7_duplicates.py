"""Geometric duplicate screening before V7 training; never reassign exposed splits."""

import json
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor
from itertools import combinations, islice
from pathlib import Path

import cv2
import numpy as np
from prepare_manifest import compute_sha256
from prepare_plantseg_extension import write_json
from prepare_potato_v7 import OUT, ROOT


def features(path):
    im = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if im is None:
        raise ValueError(f"Cannot decode {path}")
    scale = min(1.0, 640 / max(im.shape))
    im = cv2.resize(im, None, fx=scale, fy=scale)
    keys, desc = cv2.SIFT_create(nfeatures=400).detectAndCompute(im, None)
    return np.float32([k.pt for k in keys]), desc, im.shape


def geometric_match(a, b):
    pa, da, sa = a
    pb, db, sb = b
    if da is None or db is None or min(len(da), len(db)) < 16:
        return None
    matches = cv2.BFMatcher().knnMatch(da, db, k=2)
    good = [m for m, n in matches if m.distance < 0.75 * n.distance]
    # A texture repeated many times in one photo must not count as many matches.
    unique = {m.trainIdx: m for m in sorted(good, key=lambda m: -m.distance)}
    good = list(unique.values())
    if len(good) < 16:
        return None
    x = np.float32([pa[m.queryIdx] for m in good])
    y = np.float32([pb[m.trainIdx] for m in good])
    _, mask = cv2.findHomography(x, y, cv2.RANSAC, 4.0)
    if mask is None:
        return None
    keep = mask.ravel().astype(bool)
    count = int(keep.sum())
    ratio = count / len(good)
    coverage = [
        cv2.contourArea(cv2.convexHull(points[keep])) / (shape[0] * shape[1])
        for points, shape in ((x, sa), (y, sb))
    ]
    if count < 16 or ratio < 0.7 or min(coverage) < 0.05:
        return None
    return {"inliers": count, "inlier_ratio": ratio, "coverage": coverage}


def screen(inventory, edges):
    rows = inventory["rows"] + inventory["excluded"]
    parent = list(range(len(rows)))

    def find(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    def union(a, b):
        parent[find(a)] = find(b)

    groups = {}
    hashes = {}
    for i, row in enumerate(rows):
        if row.get("group_id") in groups:
            union(i, groups[row["group_id"]])
        if "group_id" in row:
            groups[row["group_id"]] = i
        if row["sha256"] in hashes:
            union(i, hashes[row["sha256"]])
        hashes[row["sha256"]] = i
    for edge in edges:
        union(edge["a"], edge["b"])
    components = defaultdict(list)
    for i, row in enumerate(rows):
        components[find(i)].append(row)
    kept, rejected = [], []
    for component in components.values():
        reason = None
        if any(r.get("exclusion") not in (None, "exact_duplicate") for r in component):
            reason = "geometric_component_touches_prior_quarantine"
        elif len({r["label"] for r in component}) > 1:
            reason = "geometric_component_conflicting_labels"
        elif len({r["split"] for r in component if "split" in r}) > 1:
            reason = "geometric_component_crosses_original_splits"
        group_id = "tari_geo_" + min(r["sha256"] for r in component)[:24]
        for row in component:
            if "review_id" not in row:
                continue
            if reason:
                rejected.append({**row, "exclusion": reason})
            else:
                kept.append({**row, "group_id": group_id})
    return kept, rejected


def main():
    target = OUT / "geometric_duplicate_audit.json"
    if target.exists():
        raise ValueError("Preserve completed audit")
    cv2.setNumThreads(1)
    inventory_path = OUT / "inventory.json"
    inventory = json.loads(inventory_path.read_text())
    rows = inventory["rows"] + inventory["excluded"]
    with ThreadPoolExecutor(max_workers=8) as pool:
        feats = list(pool.map(lambda r: features(ROOT / r["file"]), rows))
    print("Extracted SIFT features", len(rows), flush=True)
    # All pairs, including cross-label and previously quarantined photographs.
    pairs = combinations(range(len(rows)), 2)

    def compare(pair):
        a, b = pair
        result = geometric_match(feats[a], feats[b])
        return {"a": a, "b": b, **result} if result else None

    edges, completed = [], 0
    for path in OUT.glob("geometric_progress*.json"):
        progress = json.loads(path.read_text())
        if progress["inventory_sha256"] != compute_sha256(inventory_path):
            raise ValueError("Partial audit inventory changed")
        if progress["pairs_checked"] > completed:
            completed, edges = progress["pairs_checked"], progress["edges"]
    print("Resuming after", completed, "pairs", flush=True)
    with ThreadPoolExecutor(max_workers=8) as pool:
        for i, result in enumerate(pool.map(compare, islice(pairs, completed, None)), start=completed):
            if result:
                edges.append(result)
            if (i + 1) % 10000 == 0:
                print("Pairs", i + 1, "geometric matches", len(edges), flush=True)
                write_json(OUT / f"geometric_progress_{i + 1}.json", {
                    "pairs_checked": i + 1, "edges": edges,
                    "inventory_sha256": compute_sha256(inventory_path),
                })
    kept, rejected = screen(inventory, edges)
    counts = Counter((r["split"], r["label"]) for r in kept)
    write_json(target, {
        "inventory_sha256": compute_sha256(inventory_path),
        "script_sha256": compute_sha256(Path(__file__)),
        "parameters": "all 404550 pairs; SIFT400 at max640px; ratio0.75; unique target features; homography RANSAC4px; >=16 inliers; fraction>=0.7; coverage>=0.05 both images",
        "limitations": "Conservative geometric screening, not verified farm/physical-leaf identity. It can miss similar leaves or heavily changed views. Cross-split components quarantined, never reassigned.",
        "edges": edges,
        "rows": kept,
        "excluded": rejected,
        "counts": {f"{s}:{c}": n for (s, c), n in counts.items()},
    })
    print(json.dumps({"kept": len(kept), "quarantined": len(rejected), "counts": {f"{s}:{c}": n for (s, c), n in counts.items()}}, indent=2), flush=True)


if __name__ == "__main__":
    main()
