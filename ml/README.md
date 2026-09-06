# KrishiDoc field-model training

This directory contains the reproducible path from licensed public data to an
auditable **experimental** plant-disease model candidate. It does not turn a
public-dataset score into a Nepal diagnosis claim.

## Product boundary

- Supported crops: tomato, potato, and maize.
- A model output is a possible visual match until it passes a locked,
  independently labelled Nepal field test and calibration set.
- Disease-name training data is supplemented with wrong-crop, non-leaf,
  unseen-disease, pest, nutrient-deficiency, blur, and background examples.
- Source/farm/plant groups and near-duplicates must never cross splits.
- Synthetic or pre-augmented copies stay in the training split and are never
  used to report validation or test performance.
- No generated pesticide, dose, mixture, or waiting-period recommendation is
  permitted from a classifier result.

## Layout

```text
ml/
  configs/       versioned training and evaluation configurations
  datasets/      source registry, licence facts, and label mappings
  scripts/       download, index, train, calibrate, evaluate, and export tools
  tests/         deterministic tests for the data and metric contracts
  data/          ignored downloads and prepared manifests
  runs/          ignored checkpoints and metrics
  artifacts/     ignored mobile candidates and model cards
```

## Reproducible environment

Training requires Python 3.12 and an NVIDIA CUDA build of PyTorch. On this
development machine, create the isolated environment from the known-working
Anaconda Python:

```powershell
C:\ProgramData\anaconda3\python.exe -m venv --system-site-packages .venv
.\.venv\Scripts\python.exe -m pip install -r ml\requirements-train.txt
```

`--system-site-packages` reuses the installed CUDA-enabled PyTorch wheel. The
run receipt records the complete package inventory and CUDA/device versions.
For CI or another workstation, install the pinned CUDA PyTorch build first and
then install this requirements file.

## Stages

```powershell
# 1. See the sources, licences, expected bytes, and warnings before downloading.
.\.venv\Scripts\python.exe ml\scripts\download_datasets.py list

# 2. Download selected public sources. Raw data remains git-ignored.
.\.venv\Scripts\python.exe ml\scripts\download_datasets.py fetch --source figshare_maize

# 3. Build a canonical image manifest after source-specific inspection.
.\.venv\Scripts\python.exe ml\scripts\prepare_manifest.py --config ml\configs\field_v1.json

# 4. Verify split leakage and run a short end-to-end GPU smoke test.
.\.venv\Scripts\python.exe ml\scripts\audit_manifest.py --manifest ml\data\prepared\manifest.csv
.\.venv\Scripts\python.exe ml\scripts\train.py --config ml\configs\smoke.json

# 5. Train candidates, calibrate only on the locked calibration split, and
#    evaluate once on test.
.\.venv\Scripts\python.exe ml\scripts\train.py --config ml\configs\field_v1.json

# 6. Assess each candidate as one identity-locked bundle of internal,
#    independent-external, and optional deployment/export evidence. This
#    writes a decision; it never replaces an app asset.
.\.venv\Scripts\python.exe ml\scripts\compare_candidates.py `
  --config ml\configs\maize_promotion_provisional_v1.json `
  --bundle ml\artifacts\candidate-a\evidence-bundle.json `
  --bundle ml\artifacts\candidate-b\evidence-bundle.json `
  --output-json ml\artifacts\promotion\comparison.json `
  --output-markdown ml\artifacts\promotion\model-card-summary.md

# 7. Export a calibrated checkpoint to a fixed-shape ONNX interchange
#    candidate and measure a desktop CPU baseline. Neither command writes to
#    app/assets/models or creates physical-device promotion evidence.
.\.venv\Scripts\python.exe ml\scripts\export_candidate.py `
  --checkpoint ml\runs\candidate-a\best.pt `
  --calibration ml\runs\candidate-a\calibration.json `
  --output-dir ml\artifacts\candidate-a `
  --artifact-name candidate.onnx
.\.venv\Scripts\python.exe ml\scripts\benchmark_candidate.py `
  --metadata ml\artifacts\candidate-a\candidate.metadata.json `
  --output ml\artifacts\candidate-a\host-benchmark.json
```

Manifest preparation defaults to `--path-mode auto`: images inside this Git
worktree are written as forward-slash, repository-relative paths, so moving or
cloning the worktree does not invalidate the manifest. Use `--path-mode
absolute` only for intentionally machine-local data, or `--path-mode
repo-relative --repo-root <path>` to require portable output and fail if any
selected image is outside that root. The auditor follows the same repository
root contract and also accepts an explicit `--image-root`.

Source-specific grouping runs before split assignment. In the v2 alias policy,
the Central Java potato source groups timestamp-named photos into parent-scoped
ten-minute capture buckets (including camera-local and Unix-millisecond
filenames) and locks the entire source to training. Its broad disease folders,
including the publisher's `Phytopthora` spelling, are explicit
`potato_other_unknown` exposure rather than named diagnoses.

PLDD-UP uses a different, filename-bounded rule. Its 15,519 files are named
`early-blight (N)`, `healthy-leaf (N)`, or `late-blight (N)`. The local archive
contains 475 numeric-stem collisions across the `.JPG`, `.jpeg`, and `.jpg`
suffix cohorts: 294 early blight, 80 healthy, and 101 late blight. Those collisions are always grouped,
even when their pixels differ, because their filename lineage is ambiguous.
This is a conservative split lock, not a claim that the colliding files are
the same photograph: all 475 pairs have different SHA-256 values and sampled
pairs were perceptually unrelated.
The numeric ranges are otherwise long and mostly continuous, so adjacent
numbers alone are not treated as a session—doing that would collapse nearly an
entire class. Instead, only immediate neighbours within the same source,
canonical class, parent directory, filename prefix, and exact filename-suffix
cohort (`.JPG`, `.jpeg`, or `.jpg`) are joined when their 64-bit pHash distance
is at most 12. Exact suffix case is significant because the archive's suffix
cohorts behave like separate imports. A deterministic broad diagnostic sample
found 7/750 adjacent pairs at distance 12 or below, versus 0/750 random
within-class pairs more than 100 numbers apart; targeted inspection also found
clear within-cohort burst examples, including pHash distances 0, 2, and 6. The
general pHash rule at distance 4 still runs independently across all records.

This is a conservative leakage heuristic, not recovered farm/plant metadata.
Numeric IDs are archive ordering rather than timestamps, pHash can miss a
burst after a large viewpoint or lighting change, and transitive visual chains
may form a larger group. Suffix-scoped adjacency can also miss a real burst
that crosses an upstream rename/import boundary. PLDD-UP therefore improves potato field
representation but does not become an independent Nepal validation source.

The first PLDD successor, `manifest_field_v2_pldd_up.csv`, is rejected. A
post-build contradiction audit found 87 groups whose rows carried multiple
canonical condition labels: 65 PLDD-UP groups / 249 rows and 22 TOM2024 groups
/ 44 rows. Five PLDD conflicts are byte-identical early-blight/healthy pairs;
one affects validation and one calibration. A separate retrospective audit of
the older frozen manifest found 21 exact-byte TOM2024 conflicts / 42 rows (9
maize groups and 12 tomato groups). Earlier audit
receipts predate this invariant and must not be treated as promotion evidence.

The auditor now fails closed whenever any group carries more than one
canonical `condition_label`, including explicit unknown labels and
`not_applicable`. There is no waiver flag. Sanitize by removing the entire
component, retain the deterministic evidence sidecar, then run the full audit.
These commands never overwrite v2:

```powershell
$expectedV2 = '6005E4828B1C3F9F0EDC314C123755E9707F6D08FAF7CBF5CC6FF2F3C75059B9'
$actualV2 = (Get-FileHash ml\data\prepared\manifest_field_v2_pldd_up.csv -Algorithm SHA256).Hash
if ($actualV2 -ne $expectedV2) { throw "Unexpected v2 manifest: $actualV2" }

.\.venv\Scripts\python.exe ml\scripts\quarantine_mixed_condition_groups.py `
  --manifest ml\data\prepared\manifest_field_v2_pldd_up.csv `
  --output ml\data\prepared\manifest_field_v2_1_pldd_up.csv `
  --taxonomy ml\datasets\taxonomy_v1.json `
  --quarantine ml\data\prepared\quarantine_field_v2_1_pldd_up.json

.\.venv\Scripts\python.exe ml\scripts\audit_manifest.py `
  --manifest ml\data\prepared\manifest_field_v2_1_pldd_up.csv `
  --taxonomy ml\datasets\taxonomy_v1.json `
  --aliases ml\datasets\label_aliases.json `
  --config ml\configs\potato_pldd_up_provisional_v2_1.json `
  --receipt ml\data\prepared\audit_receipt_field_v2_1_pldd_up.json

.\.venv\Scripts\python.exe -m pytest `
  ml\tests\test_audit_manifest.py `
  ml\tests\test_quarantine_mixed_condition_groups.py -q
```

Only after both the full image-verifying audit and tests pass may training
restart from epoch zero. Outputs from the stopped v2 attempt remain rejected.
Use the research-only sanitized crop config so its receipt also records the
data hashes, audit receipt, limitations, and resize-before-augmentation recipe:

```powershell
.\.venv\Scripts\python.exe ml\scripts\train.py `
  --config ml\configs\potato_pldd_up_sanitized_v2_1.json `
  --crop potato `
  --architecture mobilenet_v3_large `
  --output-dir ml\runs\potato_pldd_up_sanitized_v2_1\mobilenet_v3_large `
  --device cuda
```

Do not add `--resume`, and do not reuse the rejected v2 run directory.

Digital Green/Farmer.Chat has already influenced model and data decisions, so
its canonical `external_test` split must no longer be interpreted as unseen
evidence. Build a separate, non-mutating five-fold development sidecar for
diagnostic cross-validation:

```powershell
.\.venv\Scripts\python.exe ml\scripts\assign_development_folds.py `
  --manifest ml\data\prepared\manifest_field_v2_1_sanitized.csv `
  --annotations ml\data\raw\farmer_chat_india\annotations.csv `
  --source-policy ml\datasets\source_evidence_policy_v1.json `
  --output ml\data\prepared\farmer_chat_india_development_folds_v1.csv `
  --report ml\data\prepared\farmer_chat_india_development_folds_v1.report.json
```

The tool assigns `group_id`, never individual images, balances state buckets,
observed crops, semicolon-tokenized diagnoses, and task roles over 32
deterministic restarts, and reports every marginal count and residual
imbalance. Missing critical metadata quarantines the whole group; conflicting
expert observations are preserved and flagged. Every row and fold says
`development_only=true`, `selection_independent=false`, and
`promotion_eligible=false`. The source-policy check fails if those facts are
not independently recorded.

Condition labels are fail-closed. A config that intentionally trains a
provisional subset must set `"unconfigured_conditions": "as_unknown"`; omitted
conditions then remain usable-leaf examples for the validity head but receive
no condition-head target and are evaluated as open-set cases. The default is
`"reject"`, which stops on any unsupported target-crop condition.

Training-config schema v1 also supports the opt-in
`"condition_outlier_exposure_weight"` field. It defaults to `0.0`, preserving
the original objective and mixup path when omitted. A positive value adds
`KL(U || p_condition)` only for usable target-crop rows explicitly mapped to
`<crop>_other_unknown`; wrong-crop, unsuitable, other-plant, and non-plant rows
never receive this condition-head target. Known-condition cross entropy is
unchanged. With this objective enabled, mixup pairs known, explicit-unknown,
and other open-set rows in three separate strata. Each epoch records the raw
KL, configured weight, weighted value, and actual exposure count in
`history.json`; zero contributors are reported as `null`, not as a perfect
zero loss.

Uniform exposure discourages an unsupported image from collapsing onto one
known disease, but it does not prove OOD detection or calibrated refusal. Its
weight must be selected without consulting locked test data and compared
against the zero-weight baseline for known-class recall, accepted precision,
unknown-condition false accepts, calibration, and coverage. Too much weight
can flatten useful condition boundaries. Enabling it changes the config hash,
so an existing checkpoint cannot be resumed as though it used the new loss.

The app model under `app/assets/models/` is deliberately not overwritten by a
training command. Promotion requires a reviewed model card, passing acceptance
gates, a compatible mobile export, and an explicit app-integration change.
`compare_candidates.py` reports the strongest candidate provisionally even
when it is blocked. The preferred `--bundle` mode reads descriptors like this;
member paths are relative to the descriptor file:

```json
{
  "schema_version": 1,
  "candidate_id": "maize-mobile-v1",
  "identity": {
    "checkpoint_sha256": "<64 hexadecimal characters>",
    "config_sha256": "<64 hexadecimal characters>",
    "manifest_sha256": "<64 hexadecimal characters>"
  },
  "members": {
    "internal_test": "evaluation/metrics_test.json",
    "external_test": "evaluation/metrics_external_test.json",
    "deployment_benchmark": "deployment/device-evidence.json",
    "export": "export/candidate.metadata.json"
  }
}
```

`internal_test` and `external_test` are mandatory. The external report must
come from source-locked `external_test` rows and records its source IDs, so an
overlap with the internal report fails closed. Deployment and export members
are optional unless their measurements are named by the selected policy.
Every supplied member must identify the exact same checkpoint, training
config, manifest, crop, and architecture. The legacy repeated `--evaluation`
mode remains available for older single-report comparisons, but it does not
provide the cross-domain bundle contract.

Missing measurements, identity mismatches, unsupported configured gates,
`promotion_allowed: false`, or absent locked Nepal evidence all block promotion
and are recorded in both JSON and Markdown output. The OOD gate uses the upper
95% Wilson confidence bound, not only the observed point rate. The standalone
`maize_promotion_provisional_v1.json` policy adds independent-external known
acceptance, field/condition quality, and support gates while deliberately
remaining non-promotable; it does not alter a training configuration.
`tomato_promotion_provisional_v1.json` applies the same bundle boundary to the
three provisional tomato labels (early blight, late blight, and healthy), with
explicit internal/external support, accepted-set precision, OOD confidence,
calibration, INT8 parity/size, physical-device latency, and locked Nepal gates.
It is also explicitly non-promotable and treats every other tomato presentation
as open-set evidence rather than a fourth catch-all diagnosis.
`potato_pldd_up_promotion_provisional_v1.json` is the standalone release policy
for the `potato_pldd_up_provisional_v1` experiment. It is scoped exactly to
potato early blight, late blight, and healthy, requires robust internal and
independent-external per-class evidence, and adds accepted-set Wilson precision,
calibration, OOD, full-INT8 parity/size, physical Android latency, and locked
independently labelled Nepal gates. PLDD-UP remains internal Indian-domain
evidence, every unsupported potato presentation remains open-set, and the
policy is explicitly non-promotable.

`export_candidate.py` requires the calibration artifact to match the exact
checkpoint, crop, architecture, manifest, and locked calibration split. It
records both head-label orders, ImageNet normalization, letterbox behavior,
temperatures, gate thresholds, artifact hashes, and ONNX Runtime parity. The
result is deliberately marked incompatible with the current
`tflite_flutter` single-output adapter: it has two raw-logit heads and is still
float32. A desktop ONNX benchmark is useful for regression tracking but is not
silently relabelled as Android latency.

Only `compose_deployment_evidence.py` can add the `int8_model_bytes`,
`p95_device_inference_ms`, and `cold_device_inference_ms` fields consumed by
the promotion gate. It requires a hash-matched, full-integer TFLite artifact
that has passed the Flutter dual-head contract plus at least 100 raw steady
inference timings and five cold-start timings from a non-emulated Android
device running `tflite_flutter`. It recomputes the percentile and worst cold
start, and always writes a new evaluation report rather than changing the
locked source report. The device harness output contract is versioned in
`ml/datasets/device_benchmark_schema_v1.json`.
