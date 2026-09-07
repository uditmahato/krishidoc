"""Freeze the validity-preserving follow-up before its optimization starts."""

import json

from prepare_manifest import compute_sha256
from prepare_plantseg_extension import ROOT, write_json


def main():
    config = json.loads(
        (ROOT / "ml/configs/potato_field_v5_plantseg_20260907.json").read_text()
    )
    parent_calibration = (
        ROOT
        / "ml/runs/potato_field_v3_dg_rotation_1_oe003/efficientnet_b0/calibration.json"
    )
    config.update(
        run_name="potato_field_v6_condition_only_20260907",
        seed=20260908,
        training_mode="condition_head_only",
        epochs=2,
        freeze_backbone_epochs=2,
        learning_rate=0.0003,
        samples_per_epoch=12000,
        monitor="source_balanced_condition_recall_v1",
        monitor_source_ids=["pldd-up", "plantseg_potato_v5"],
        status="research_only_frozen_validity_path",
        frozen_validity_calibration={
            "path": parent_calibration.relative_to(ROOT).as_posix(),
            "sha256": compute_sha256(parent_calibration),
        },
        limitations=[
            "Only the final disease-classification linear layer trains; all validity-path parameters and buffers must remain bit-identical to the V3 parent.",
            "Validity temperature is inherited from the pinned parent and validity probability threshold may not be lowered by calibration.",
            "The entire 749-photo challenge is now consumed development evidence after V5. No new independent Nepal or other release-validation claim is allowed.",
            "Model selection uses equal-source mean condition recall over PLDD and PlantSeg validation, with >=10 examples for each of >=2 classes per source. No test results select checkpoints or thresholds.",
            "New-source healthy training examples and independently adjudicated Nepal labels are still missing. No automatic app promotion.",
        ],
    )
    config["data_snapshot"]["audit_receipt"] = (
        "ml/data/prepared/audit_receipt_field_v6_condition_only.json"
    )
    config["data_snapshot"]["required_artifacts"]["frozen_validity_calibration"] = (
        config["frozen_validity_calibration"]
    )
    write_json(ROOT / "ml/configs/potato_field_v6_condition_only_20260907.json", config)


if __name__ == "__main__":
    main()
