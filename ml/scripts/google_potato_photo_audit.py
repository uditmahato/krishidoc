"""Freeze sourced web photos and summarize an isolated native Android audit.

Diagnostic only: no training, threshold tuning, model export or promotion.
Public availability is not a training/redistribution license. Photos stay ignored.
"""

import argparse
import hashlib
import io
import json
import subprocess
import sys
import zipfile
from pathlib import Path
from urllib.parse import urljoin

import numpy as np
import pandas as pd
import requests
from bs4 import BeautifulSoup
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from ml.scripts.prepare_manifest import compute_phash

OUT = ROOT / "ml/artifacts/google_potato_audit_20260906/reviewed"
DATA = ROOT / "ml/data/raw/google_potato_audit_20260906/reviewed"
BASE = ROOT / "ml/data/prepared/manifest_field_v3_dg_rotation_1.csv"
EARLY = "https://www.ndsu.edu/agriculture/extension/publications/early-blight-potato"
LATE = "https://content.ces.ncsu.edu/potato-late-blight"
UMD = "https://extension.umd.edu/resource/late-blight-tomato-and-potato"
SDSU = "https://extension.sdstate.edu/potatoes-how-grow-it"
NC = "https://plants.ces.ncsu.edu/plants/solanum-tuberosum/common-name/potatoes/"
UMN = "https://blog-fruit-vegetable-ipm.extension.umn.edu/2026/08/weekly-vegetable-update-august-20-2026.html"

# Selection fixed before running inference; labels follow the individual figure,
# not the page title. NDSU figures 2a, 2b and 3b are different diseases: excluded.
CATALOG = [
    (
        "eb01",
        EARLY,
        "alt",
        "Figure 1a",
        "potato_early_blight",
        "Mitch Bauske",
        "target-ring lesions",
    ),
    (
        "eb02",
        EARLY,
        "alt",
        "Figure 1b",
        "potato_early_blight",
        "Sunil Shrestha, NDSU",
        "initial lower-leaf lesions",
    ),
    (
        "eb03",
        EARLY,
        "alt",
        "Figure 3a",
        "potato_early_blight",
        "Sunil Shrestha, NDSU",
        "coalesced lesions and yellowing",
    ),
    (
        "eb04",
        EARLY,
        "alt",
        "Figure 5",
        "potato_early_blight",
        "Sunil Shrestha, NDSU",
        "severe upper-canopy symptoms",
    ),
    (
        "lb01",
        LATE,
        "src",
        "/media/images/IMG_0014.jpg",
        "potato_late_blight",
        "Lina Quesada, NC State Vegetable Pathology Lab",
        "late blight on leaves",
    ),
    (
        "lb02",
        LATE,
        "src",
        "/media/images/IMG_0022.jpg",
        "potato_late_blight",
        "Lina Quesada, NC State Vegetable Pathology Lab",
        "late blight on leaves",
    ),
    (
        "lb03",
        UMD,
        "alt",
        "late blight infected stem and leaves on a potato plant",
        "potato_late_blight",
        "University of Maryland Extension / Bugwood; see source page",
        "infected attached leaves and stem",
    ),
    (
        "lb04",
        UMN,
        "alt",
        "Close-up photo of a leaf with late blight symptoms: there is a nickel-sized brown splotch in the center of the leaf that looks sort of wet.",
        "potato_late_blight",
        "Marissa Schuh, UMN Extension",
        "late blight on a potato leaf, field report August 20, 2026",
    ),
    (
        "hc01",
        SDSU,
        "alt",
        "Several rows of hilled potatoes growing in a garden.",
        "potato_healthy",
        "SDSU Extension",
        "apparently healthy hilled rows; not disease-certified",
    ),
    (
        "hc02",
        SDSU,
        "alt",
        "Row of potatoes surrounded by light-colored grass mulch.",
        "potato_healthy",
        "SDSU Extension",
        "apparently healthy mulched row; not disease-certified",
    ),
    (
        "hc04",
        NC,
        "data-caption",
        "Potato seedlings",
        "potato_healthy",
        "Allison P., CC BY-NC-ND 2.0",
        "apparently healthy seedlings; not disease-certified",
    ),
]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def write(path, value):
    path.write_text(
        json.dumps(value, indent=2, allow_nan=False) + "\n", encoding="utf-8"
    )


def freeze():
    if (DATA / "manifest.json").exists():
        raise ValueError("Preserve frozen evidence: manifest already exists")
    DATA.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    base = pd.read_csv(BASE, dtype=str, keep_default_na=False)
    base_hashes = set(base.sha256)
    hashes = [(int(r.phash, 16), r.image_path) for r in base.itertuples() if r.phash]
    pages, rows, seen = {}, [], set()
    for ident, page, attr, value, label, credit, description in CATALOG:
        if page not in pages:
            response = requests.get(page, timeout=40)
            response.raise_for_status()
            pages[page] = BeautifulSoup(response.text, "html.parser")
        matches = [
            i
            for i in pages[page].find_all("img")
            if i.get(attr) == value and not i.get("src", "").startswith("data:")
        ]
        urls = {urljoin(page, i["src"]) for i in matches}
        if len(urls) != 1:
            raise ValueError(f"Ambiguous/missing image for {ident}: {len(urls)}")
        url = urls.pop()
        response = requests.get(url, timeout=40)
        response.raise_for_status()
        raw = response.content
        sha = hashlib.sha256(raw).hexdigest()
        with Image.open(io.BytesIO(raw)) as photo:
            photo.load()
            width, height = photo.size
            extension = {"JPEG": "jpg", "PNG": "png", "WEBP": "webp"}[photo.format]
        path = DATA / f"{ident}.{extension}"
        if path.exists() and digest(path) != sha:
            raise ValueError(f"Existing image differs: {path}")
        path.write_bytes(raw)
        phash = compute_phash(path)
        nearest = min(((int(phash, 16) ^ h).bit_count(), p) for h, p in hashes)
        if sha in seen or sha in base_hashes or nearest[0] <= 4:
            raise ValueError(
                f"Duplicate/near overlap must be reviewed: {ident}, {nearest}"
            )
        seen.add(sha)
        rows.append(
            {
                "id": ident,
                "file": path.name,
                "crop": "potato",
                "condition_label": label,
                "source_id": page.split("/")[2],
                "split": "external_web_diagnostic_not_training",
                "source_page": page,
                "image_url": url,
                "credit": credit,
                "description": description,
                "label_status": "uncertain_apparently_healthy_control"
                if ident.startswith("hc")
                else "extension_figure_label_not_independent_lab_confirmation",
                "sha256": sha,
                "phash": phash,
                "width": width,
                "height": height,
                "nearest_base_phash_distance": nearest[0],
                "nearest_base_image": nearest[1],
                "rights": "Local diagnostic only; no training or redistribution permission inferred.",
            }
        )
        print(
            ident,
            width,
            height,
            "nearest training-manifest pHash:",
            nearest[0],
            flush=True,
        )
    manifest = {
        "audit_id": "google-potato-native-20260906-v2",
        "samples": rows,
        "scope": "potato only: four early blight, four late blight, three uncertain healthy-looking controls",
        "pre_inference_visual_review": "Initial hc03 rejected as a healthy control because visible holes/damage make its label ambiguous. Initial selection preserved in parent folder and never inferred. Added another natural-background late-blight image. White/black-background disease photos retained as separate photographic controls, not field claims.",
        "google_queries": [
            "potato early blight extension",
            "potato late blight extension",
            "healthy potato plants extension",
        ],
        "discovery": "Google Images in browser; original source pages verified separately; NC botanical control added through web search",
        "base_manifest_sha256": digest(BASE),
        "promotion_eligible": False,
    }
    write(DATA / "manifest.json", manifest)
    write(OUT / "manifest.json", manifest)
    write(
        OUT / "freeze_receipt.json",
        {"manifest_sha256": digest(DATA / "manifest.json"), "image_count": len(rows)},
    )


def summarize(allow_partial=False):
    manifest = json.loads((OUT / "manifest.json").read_text())
    receipt = json.loads((OUT / "freeze_receipt.json").read_text())
    if digest(OUT / "manifest.json") != receipt["manifest_sha256"]:
        raise ValueError("Frozen manifest changed")
    report = json.loads((OUT / "device_report.json").read_text())
    if (not report["complete"] and not allow_partial) or report["audit_id"] != manifest[
        "audit_id"
    ]:
        raise ValueError("Wrong or incomplete native audit")
    samples = {r["id"]: r for r in manifest["samples"]}
    ids = [r["id"] for r in report["rows"]]
    if len(ids) != len(set(ids)) or not set(ids) <= set(samples):
        raise ValueError("Native row identities differ")
    if not allow_partial and set(ids) != set(samples):
        raise ValueError("Native rows missing")
    meta = json.loads(
        (
            ROOT / "app/assets/models/potato_field_v3_efficientnet_b0.metadata.json"
        ).read_text()
    )
    if report["potato_model"] != meta["modelVersion"]:
        raise ValueError("Unexpected model")
    apk = (
        ROOT / "ml/artifacts/classwise_app_audit_20260906/krishidoc-classwise-audit.apk"
    )
    with zipfile.ZipFile(apk) as archive:
        model_hash = hashlib.sha256(
            archive.read("assets/flutter_assets/" + meta["artifact"]["path"])
        ).hexdigest()
    if model_hash != meta["artifact"]["sha256"]:
        raise ValueError("Diagnostic APK differs from current bundled potato model")
    adb = str(Path.home() / "AppData/Local/Android/Sdk/platform-tools/adb.exe")
    phone_hashes = subprocess.run(
        [
            adb,
            "-s",
            "S44PS4OZMVPZBQXO",
            "shell",
            "sha256sum",
            "/sdcard/Android/data/com.krishidoc.app.modelaudit/files/audit-input/*",
        ],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    remote = {
        line.split()[1].rsplit("/", 1)[-1]: line.split()[0]
        for line in phone_hashes.splitlines()
    }
    for sample in samples.values():
        if remote.get(sample["file"]) != sample["sha256"]:
            raise ValueError("Actual device photo bytes differ")
    if remote.get("manifest.json") != receipt["manifest_sha256"]:
        raise ValueError("Actual device manifest differs")
    write(
        OUT / "device_integrity.json",
        {
            "serial": "S44PS4OZMVPZBQXO",
            "apk_sha256": digest(apk),
            "bundled_potato_sha256": model_hash,
            "remote_input_sha256": remote,
        },
    )
    labels = meta["outputs"][1]["labels"]
    validity = meta["outputs"][0]["labels"]
    rows = []
    for result in report["rows"]:
        sample = samples[result["id"]]
        # Caption verification corrected these attribution fields. Preserve the
        # original immutable manifest; corrected credits live in results/report.
        if sample["id"] in {"lb03", "lb04"}:
            sample = {
                **sample,
                "credit": "Gerald Holmes, Strawberry Center, Cal Poly San Luis Obispo, Bugwood.org",
            }
        if result.get("error"):
            raise ValueError(f"Native processing failure: {result['id']}")
        if (
            digest(DATA / sample["file"]) != sample["sha256"]
            or result["photo_sha256"] != sample["sha256"]
        ):
            raise ValueError("Photo identity changed")
        v = np.asarray(result["potato_validity_logits"])
        c = np.asarray(result["potato_condition_logits"])
        if v.shape != (5,) or c.shape != (3,) or not np.isfinite(np.r_[v, c]).all():
            raise ValueError("Invalid native logits")
        rows.append(
            {
                **sample,
                "background": "plain_control"
                if sample["id"] in {"eb03", "lb01", "lb02"}
                else "natural_or_growing_context",
                "raw_condition": labels[c.argmax()],
                "validity_top": validity[v.argmax()],
                "app_top": result["app_top"] or "refused",
                "gallery_app_top": result["gallery_app_top"] or "refused",
                "state": result["state"],
                "gallery_disposition": result["gallery_disposition"],
                "crop_suggestion_shown": result["crop_suggestion_shown"],
                "global_top": result["global_top"],
                "source_label_match": result["gallery_app_top"]
                == sample["condition_label"],
                "raw_source_label_match": labels[c.argmax()]
                == sample["condition_label"],
                "diagnosis_ms": result["diagnosis_ms"],
            }
        )
    frame = pd.DataFrame(rows)
    frame.to_csv(OUT / "per_image.csv", index=False)
    summary = []
    for label, group in frame.groupby("condition_label"):
        summary.append(
            {
                "label": label,
                "count": len(group),
                "raw_source_label_matches": int(group.raw_source_label_match.sum()),
                "gallery_source_label_matches": int(group.source_label_match.sum()),
                "refused": int(group.gallery_app_top.eq("refused").sum()),
                "wrong_accepted": int(
                    (
                        ~group.source_label_match & group.gallery_app_top.ne("refused")
                    ).sum()
                ),
                "uncertain_controls": label == "potato_healthy",
            }
        )
    write(
        OUT / "summary.json",
        {
            "runtime": report["runtime"],
            "complete": report["complete"],
            "expected_count": len(samples),
            "completed_count": len(rows),
            "model": report["potato_model"],
            "promotion_eligible": False,
            "model_changed": False,
            "training_performed": False,
            "device_report_sha256": digest(OUT / "device_report.json"),
            "rows": summary,
        },
    )
    print(json.dumps(summary, indent=2))
    print(
        frame[
            [
                "id",
                "raw_condition",
                "validity_top",
                "gallery_app_top",
                "crop_suggestion_shown",
            ]
        ].to_string(index=False)
    )


def reference():
    """Run unchanged parent checkpoint on exact Dart tensors, requiring CUDA."""
    import torch

    sys.path.insert(0, str(ROOT / "ml/src"))
    from krishidoc_ml.calibration import apply_calibration
    from krishidoc_ml.pipeline import (
        _validate_calibration_artifact_identity,
        load_model_bundle,
    )

    checkpoint = (
        ROOT / "ml/runs/potato_field_v3_dg_rotation_1_oe003/efficientnet_b0/best.pt"
    )
    calibration_path = checkpoint.parent / "calibration.json"
    calibration = json.loads(calibration_path.read_text())
    meta = json.loads(
        (
            ROOT / "app/assets/models/potato_field_v3_efficientnet_b0.metadata.json"
        ).read_text()
    )
    if (
        digest(checkpoint) != meta["source"]["checkpointSha256"]
        or digest(calibration_path) != meta["source"]["calibrationSha256"]
    ):
        raise ValueError("Checkpoint/calibration is not the current app ancestor")
    manifest = json.loads((OUT / "manifest.json").read_text())
    receipt = json.loads((OUT / "freeze_receipt.json").read_text())
    if digest(OUT / "manifest.json") != receipt["manifest_sha256"]:
        raise ValueError("Frozen manifest changed")
    bundle = load_model_bundle(checkpoint, device_name="cuda")
    _validate_calibration_artifact_identity(
        calibration,
        checkpoint=bundle["checkpoint"],
        checkpoint_sha256=digest(checkpoint),
        manifest_sha256=manifest["base_manifest_sha256"],
        effective_config_sha256=bundle["checkpoint"]["config_hash"],
    )
    labels = bundle["checkpoint"]["condition_labels"]
    validity = bundle["checkpoint"]["validity_labels"]
    if (
        labels != meta["outputs"][1]["labels"]
        or validity != meta["outputs"][0]["labels"]
    ):
        raise ValueError("Checkpoint label order differs from app metadata")
    quality = {
        r["id"]: r for r in json.loads((OUT / "host_inputs/quality.json").read_text())
    }
    rows = []
    for sample in manifest["samples"]:
        if digest(DATA / sample["file"]) != sample["sha256"]:
            raise ValueError("Photo changed")
        path = OUT / f"host_inputs/{sample['id']}.f32"
        array = (
            np.fromfile(path, dtype="<f4")
            .reshape(224, 224, 3)
            .transpose(2, 0, 1)
            .copy()[None]
        )
        if not np.isfinite(array).all():
            raise ValueError("Invalid tensor")
        with torch.inference_mode():
            v, c = bundle["model"](torch.from_numpy(array).to(bundle["device"]))
        v, c = v.cpu().numpy(), c.cpu().numpy()
        if not np.isfinite(np.r_[v.ravel(), c.ravel()]).all():
            raise ValueError("Invalid logits")
        decision = apply_calibration(calibration, v, c)
        raw_label = labels[int(c.argmax())]
        blocked = bool(
            set(quality[sample["id"]]["gallery_issues"])
            & {"tooDark", "tooBright", "invalid_size"}
        )
        accepted = bool(decision["accepted"][0]) and not blocked
        corrected_credit = (
            "Gerald Holmes, Strawberry Center, Cal Poly San Luis Obispo, Bugwood.org"
            if sample["id"] in {"lb03", "lb04"}
            else sample["credit"]
        )
        rows.append(
            {
                **sample,
                "credit": corrected_credit,
                "background": "plain_control"
                if sample["id"] in {"eb03", "lb01", "lb02"}
                else "natural_or_growing_context",
                "raw_condition": raw_label,
                "validity_top": validity[int(v.argmax())],
                "app_equivalent_top": raw_label if accepted else "refused",
                "source_label_match": accepted
                and raw_label == sample["condition_label"],
                "raw_source_label_match": raw_label == sample["condition_label"],
                "validity_probability": float(decision["validity_probability"][0]),
                "condition_probability": float(decision["condition_probability"][0]),
                "gallery": quality[sample["id"]],
                "tensor_sha256": digest(path),
                "validity_logits": v[0].tolist(),
                "condition_logits": c[0].tolist(),
            }
        )
    write(
        OUT / "cuda_reference.json",
        {
            "runtime": "desktop CUDA float32 parent checkpoint on actual Dart app-prepared tensors; not native Android",
            "gpu": torch.cuda.get_device_name(),
            "checkpoint_sha256": digest(checkpoint),
            "calibration_sha256": digest(calibration_path),
            "manifest_sha256": receipt["manifest_sha256"],
            "rows": rows,
        },
    )
    frame = pd.DataFrame(rows)
    frame.drop(columns=["gallery", "validity_logits", "condition_logits"]).to_csv(
        OUT / "cuda_per_image.csv", index=False
    )
    print(
        frame[
            [
                "id",
                "raw_condition",
                "validity_top",
                "app_equivalent_top",
                "validity_probability",
            ]
        ].to_string(index=False)
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "action", choices=["freeze", "summarize", "reference", "partial"]
    )
    args = parser.parse_args()
    {
        "freeze": freeze,
        "summarize": summarize,
        "reference": reference,
        "partial": lambda: summarize(allow_partial=True),
    }[args.action]()
