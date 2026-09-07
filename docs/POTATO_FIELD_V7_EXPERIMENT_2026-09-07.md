# V7: new field data, restrained feature adaptation, subgroup calibration

Status: **COMPLETED — REJECTED FOR APP REPLACEMENT**. Three CUDA epochs,
calibration and the paired 895-image comparison finished successfully on
2026-09-07 at 10:51:43 UTC. The app model was not changed.

## Result: better new-source recognition, excessive refusals elsewhere

The new candidate learned the added source, but did not deliver a broad
recognition improvement on the older challenge. Stricter calibration reduced
wrong accepted answers substantially while also rejecting many correct ones.
This is a safety/coverage trade-off, not an unqualified accuracy improvement.

| Previously consumed challenge | Current V3 | V7 |
|---|---:|---:|
| Raw correct classification, supported conditions / 526 | 474 | 475 |
| Correct accepted answers | 457 | 322 |
| Wrong accepted answers, including unsupported inputs | 43 | 11 |
| Unsupported inputs accepted / 220 | 13 | 2 |
| False-healthy accepted answers | 15 | 1 |

The older challenge has 749 photos: 526 supported-condition cases, 220
unsupported inputs and 3 uncertain healthy controls. The controls are excluded
from the table and were all refused by both models. This challenge had already
been consumed in earlier experiments; it is regression evidence, not untouched
release validation.

| New same-source, group-held-out photos / 146 | Current V3 | V7 |
|---|---:|---:|
| Raw correct classification | 139 | 144 |
| Raw macro F1 | 0.9299 | 0.9758 |
| Correct accepted answers | 134 | 125 |
| Wrong accepted answers | 7 | 1 |
| Refusals | 5 | 20 |
| Accepted macro F1, refusals count against recall | 0.8910 | 0.9015 |
| Worst accepted class recall | 0.6842 | 0.7368 |

V7 passes the configured F1/recall gates on this small new-source holdout, but
fails the predeclared cross-source regression criteria. All 895 evaluated
photos are now consumed evidence for future experiments. Do not call them a
fresh benchmark again, move them into training, or tune thresholds on them.

### Class/source details

| Correct accepted answers | Current V3 | V7 |
|---|---:|---:|
| New TARI early blight / 19 | 13 | 14 |
| New TARI healthy / 69 | 68 | 61 |
| New TARI late blight / 58 | 53 | 50 |
| PlantSeg early blight / 22 | 6 | 4 |
| PlantSeg late blight / 22 | 16 | 8 |
| Holeta healthy / 331 | 325 | 222 |
| Holeta late blight / 66 | 58 | 44 |
| Google disease examples / 8 | 3 | 4 |

Unsupported-input false acceptances changed from 8/59 to 2/59 for usable potato
leaves with unsupported conditions, 4/139 to 0/139 for other plants, and 1/22 to
0/22 for wrong-crop leaves. No non-plant subgroup is represented in this
challenge, so this is not evidence of its rejection quality.

The previously troublesome Google `eb02` still has **healthy** as its raw
prediction, but is now refused instead of returned as healthy. Google `lb02`
and `lb04` still return the wrong accepted early-blight diagnosis. They are not
fixed by this retraining.

### Why the answer rate fell

Frozen-gate replay exactly reproduces the saved decisions; no threshold was
changed during this analysis. On the older challenge, V7 corrected 8 raw errors
but introduced 7 new ones: only a one-image net recognition gain. It lost 136
previously correct accepted answers and gained one new correct accepted answer;
132 of those losses still had a correct raw classification.

Of V7's 153 raw-correct-but-refused older cases, 136 fail the validity-probability
gate and 29 fail the condition-energy gate; these counts overlap. On the new
holdout, 19 correct raw classifications are refused (17 validity-gate failures,
2 energy-gate failures). This is descriptive attribution, not a causal ablation
or permission to loosen gates using this test set.

Calibration selected a usable-leaf probability minimum of 0.990026, condition
probability minimum 0.340477 and maximum condition energy -1.014884. It accepted
92.28% of known calibration inputs and 1/1,396 unsupported calibration inputs,
including 0/9 usable unknown-condition leaves. The nine-example subgroup is too
small to justify a safety guarantee. All frozen backbone normalization tensors
were verified identical to the parent checkpoint.

### What this supports next

Retain V7 as a research candidate, not the default app model. Prioritize distinct,
expert-labelled field photos from Nepal and other unseen capture sources:
healthy whole leaves with clutter, early/mild symptoms, and usable leaves with
unsupported conditions. The current calibration set's nine unknown-condition
examples and the repeated views in the new source are the main evidence gaps.
Evaluate any subsequent calibration change on a newly frozen independent set;
do not rescue this run by lowering thresholds on these 895 examples. Native
TFLite parity and connected-phone testing remain required before deployment.

### Execution and identities

Selected epoch: 3. Validation selection scores: 0.931627, 0.934465, 0.935036.
Training-loop time: 860.3 seconds. This score is a selection composite, not
accuracy. No export, installation or app-model replacement occurred.

Final verification: **275 ML tests passed**, with one existing ONNX deprecation
warning. The stored parent/candidate acceptance decisions were reproduced
exactly by the gate-analysis script.

- Checkpoint SHA-256: `ad3b3c0b6ab9cb78f5999ba4631605aa48d8f344491772fbff69889c4669c9f8`
- Calibration SHA-256: `3c1881348e472816f0893d0a85bc86f987733ce73752c6cdd6699762212860a4`
- Evaluation manifest SHA-256: `f8da0a4b67b8d90c8d748e8351b1c95debe470828dfa4184a3ca74ea35badb70`
- Comparison SHA-256: `cb884d3b1e0b05d65a94c4067f34163950fd5eb7ed69d85ab6622d776ffbf834`
- Unchanged app asset SHA-256: `90875fad84d33e06884466030e2dfe18fedc2fd89b5e71a9d61835b837891c69`

Reproduce the report with `ml/scripts/summarize_potato_v7.py` and descriptive
gate replay with `ml/scripts/analyze_potato_v7_outcome.py`. Frozen per-image
predictions, paired changes, comparison and `recognition_vs_refusal.json` are in
`ml/artifacts/potato_field_v7_20260907/`. Preserve this completed run; do not
relaunch its training runner or overwrite its frozen outputs.

Acquisition is complete: 900 real images, 300 per class. Initial hash/filename
screening retained 876 and quarantined 24. All 689 development thumbnails were
reviewed; the 187 initially assigned test images were not displayed. The review
found repeated views of the same leaf missed by pHash distance eight, including
an apparent train/validation overlap (review IDs 398 and 815). Healthy images
are predominantly very tight leaf close-ups, so this acquisition does **not**
resolve the need for wide, cluttered-background healthy photos.

Before any training or model evaluation, preparation now requires an additional
all-pairs SIFT/geometric audit of the 900 downloaded images. It merges original
groups and confirmed geometric matches, quarantines components crossing the
original splits or touching previous quarantine/conflicting labels, and never
moves visually reviewed examples into test. Fixed criteria: maximum 640px,
400 SIFT features, ratio test 0.75, at least 16 unique RANSAC inliers, at least
70% inlier fraction and 5% spatial coverage in each image. These checks reduce
duplicate risk but cannot establish farm/physical-leaf identity. Original
minimum per-class split counts remain mandatory; no result has been used to
change these data-preparation rules.

The completed all-pairs check retained **685** images after an additional 191
quarantines (215 excluded from the original 900 in total). Two visually confirmed
development-only same-leaf pairs were also merged, including one missed by the
strict SIFT criterion. No splits were reassigned. Final source addition:

| Split | Early blight | Healthy | Late blight |
|---|---:|---:|---:|
| Train | 81 | 177 | 150 |
| Validation | 12 | 24 | 23 |
| Calibration | 12 | 24 | 36 |
| Test | 19 | 69 | 58 |

The combined manifest contains **34,686** rows. The frozen paired evaluation has
**895** images: 749 previously consumed diagnostics and 146 new, same-source
group-held-out images. All original minimum counts passed without relaxation.
This is not proof that every physical leaf is independent: filenames are proxies
and visual matching has known false negatives. The full ML suite passed **274
tests**, with one existing ONNX deprecation warning.

Exclusions by class were 176 early-blight, 6 healthy and 33 late-blight images.
Early-blight validation contains only 4 estimated capture/duplicate groups
(12 photos); early-blight test has 13 such groups (19 photos). Treat estimates
from these small populations cautiously. Group-weighted descriptive recall is
reported alongside photo-weighted results; these groups are not verified plants.

Full combined audit passed with **34,686/34,686** images freshly verified
(decoding, byte SHA and perceptual hash), zero mixed-condition groups and 28,841
groups across seven sources. The GPU runner was launched only after this receipt
and the test manifest were frozen. The additional group-weighted report test
passed separately (two report tests total).

The run receipt confirms PyTorch 2.7.0+cu118, CUDA 11.8, deterministic algorithms
and the NVIDIA GeForce RTX 4060 Laptop GPU. Training uses CUDA/AMP; acquisition,
image decoding, duplicate screening and small calibration optimization are not
claims of GPU-only processing. Training began 2026-09-07 10:32:05 UTC after
preflight; its receipt was created at 10:33:36 UTC.

## Evidence driving the experiment

V5 adapted to PlantSeg but worsened unsupported acceptance. V6 preserved validity
exactly but worsened late-blight recognition. Neither was deployed. V7 tests a
different data/optimization combination, not additional epochs of those runs.

The [original Tanzania dataset](https://zenodo.org/records/8286529) is explicitly
cited by the [Laizer and Mduma paper](https://doi.org/10.1016/j.dib.2025.111549).
The paper describes natural field photography and plant-pathologist validation.
This is publisher-reported validation, not independent clinical confirmation by
KrishiDoc. The dataset record's licence is CC BY 4.0.

The previously quarantined samples came from **17553016**, a different record
with different listed authors. That record is not the one cited by the paper.
Those samples remain excluded; the paper's validation claim is not transferred
to them. The new acquisition uses the paper-linked original **8286529**.

## Fixed preparation and experiment rules

- Acquire an equally spaced deterministic sample of 300 real images per class
  from the original early/healthy/late archives. Exclude macOS resource forks;
  verify ZIP member CRC, current SHA and image decoding. Full-archive MD5 is not
  claimed when only selected byte ranges are downloaded.
- Preserve all 34,001 V5 manifest rows, labels and splits. New additions must not
  overlap those rows or the 749 consumed challenge photos by exact SHA or pHash
  distance eight. Quarantine mixed-label duplicate components.
- Group adjacent numeric filename blocks of 100 and near-duplicate components
  before a deterministic 60/10/10/20 train/validation/calibration/test assignment.
  Numeric blocks are only an approximate capture-sequence safeguard; farm and
  physical-plant identities are unavailable. The new holdout is fresh and
  group-disjoint, **not source-independent or Nepal validation**.
- Visually screen every development image for input suitability; never use model
  predictions to select images or relabel diseases. Keep test images off review
  sheets and out of checkpoint/threshold decisions. Excluding a development image
  excludes its entire related component.
- Require at least 50 training, 10 validation, 10 calibration and 15 new test
  examples per supported class after exclusions. Run the complete combined
  manifest/image audit before training.
- Initialize from V3, not rejected V5/V6. Train three CUDA/AMP epochs, batch size
  16 (other running applications currently occupy roughly 3.9 GiB of GPU memory), 12,000
  weighted draws per epoch, seed 20260909, head learning rate 0.00005 and backbone
  multiplier 0.1. Keep the parent's backbone batch-normalization affine parameters
  and running statistics frozen while permitting other features to adapt.
  Existing mixup, label smoothing and explicit-unknown exposure stay unchanged.
- Select by a geometric safety composite: equal-source mean disease recall over
  PLDD, PlantSeg and TARI (weight 0.5), validity balanced accuracy (0.25), joint
  OOD AUROC (0.25). Do not label that score app accuracy. Minimum source/class
  validation coverage is enforced; a strong large source cannot dominate the
  disease component solely through sample count.
- Fit temperatures and thresholds on calibration rows only. Enforce both the
  existing pooled 5% OOD false-accept cap and a separate 5% observed cap within
  each represented OOD validity subgroup, including usable unknown-condition
  potato leaves. Report subgroup counts, errors and small-sample warnings.
- Only nine usable unknown-condition calibration examples currently exist. That
  remains inadequate evidence of safe field rejection, even if all nine are
  refused. No new unsupported-disease source is being fabricated or silently
  relabelled to satisfy the requested coverage.
- Freeze the new test list before optimization, snapshot code/config identities,
  then run training, calibration and paired parent/candidate evaluation. All
  previous 749 photos remain consumed diagnostics. Never overwrite an old run.

## Decision rules

No automatic export, installation or app-model replacement. Report raw disease
recognition, correct accepted results, wrong accepted results, false-healthy
outputs, refusals and unsupported acceptance separately by class and source.
A better pooled number must not hide worse late-blight or unknown-condition
performance. Apply existing configured field F1/recall gates, inspect regressions
against the parent, and retain honest failures rather than retuning on this test.
Flag any class/source cell with at least 15 photos that loses correct accepted
answers or gains wrong accepted answers versus the parent. Also flag increased
false-healthy outputs. The new group holdout must reach accepted macro F1 0.8
and worst accepted class recall 0.7; refusals count against those metrics.

Even a promising research result still needs adequately represented unknown
conditions, untouched Nepal evidence, TFLite parity and a connected-phone test.
Source review is not an expert diagnosis of each downloaded leaf.

## Reproduction files

- Source registry: `ml/datasets/potato_field_v7_sources.json`
- Preparation: `ml/scripts/prepare_potato_v7.py`
- Training runner: `ml/scripts/run_potato_v7.py`
- Evaluation: `ml/scripts/evaluate_potato_v7.py`
- Artifacts: `ml/artifacts/potato_field_v7_20260907/`

Acquisition caught macOS resource forks with image-like extensions; the corrected
selector and decoding guard are covered by tests. The full ML suite currently
passed 274 tests (one existing ONNX deprecation warning), including three new
geometric-audit tests covering transformed duplicates, unrelated inputs and
cross-split/conflicting-label quarantine propagation.
