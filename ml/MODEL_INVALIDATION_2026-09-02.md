# Candidate-model invalidation notice

**Status: INVALIDATED — research history only. Do not promote, deploy, export as a release, or replace an app model with any candidate covered by this notice.**

This notice applies fail-closed to every checkpoint, calibration, evaluation, comparison, export, or benchmark whose recorded `manifest_sha256` is either:

- `8bb7dc0355d1e2fa09a178695e9db6311dc6f215708ae27495a56c0d80ff7cae` (`manifest_8bb7dc0355d1.csv`)
- `6005e4828b1c3f9f0edc314c123755e9707f6d08faf7cbf5cc6ff2f3c75059b9` (`manifest_field_v2_pldd_up.csv`)

## Evidence

- The frozen manifest contains 21 duplicate groups (42 rows) with conflicting canonical condition labels. All 21 conflicts are exact-byte (`sha256`) duplicates: 9 maize groups and 12 tomato groups. By split, 17 affected groups are in training, 3 in validation, and 1 in calibration.
- Sanitizing field manifest v2 quarantined 87 mixed-canonical-condition groups containing 293 rows. That manifest must not be used for training or evaluation.

Conflicting labels inside duplicate groups violate the dataset identity and split assumptions. Consequently, metrics, calibration thresholds, rankings, and deployment evidence derived from either manifest are invalid as model-selection or release evidence, even where an earlier gate happened to pass. Historical files are retained only for diagnosis and reproducibility.

## Required recovery

Start new runs from a separately identified manifest that passes the strengthened mixed-condition-group audit. Refit the model, recalibrate thresholds, and repeat internal, external, export, and physical-device gates from scratch. Do not reuse the affected checkpoints or their reported rankings.

No covered model was promoted or installed into the app. The existing app model asset is outside this notice and was not changed by this action.

Machine-readable counterpart: `MODEL_INVALIDATION_2026-09-02.json`.
