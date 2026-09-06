# Potato field-background experiment — 6 September 2026

The preceding app/ML checkpoint is [PR #1](https://github.com/uditmahato/krishidoc/pull/1).
This follow-up is a research experiment on a separate branch, not an app-model replacement.

## What the earlier benchmark did not establish

Fifteen PlantVillage images per class exposed important defects, but its plain
backgrounds and likely training overlap cannot establish field performance.
The current potato model already uses field training images. The question is
whether it generalizes across **different field sources**, distances, leaf
scales, clutter, lighting and cameras, rather than memorizing one source's look.

## Frozen real-background challenge

`ml/scripts/potato_field_challenge.py` fixes a 297-photo challenge before candidate
training. No generated or pre-augmented photos enter the challenge:

- **72 Bangladesh originals:** 20 late blight, 4 healthy, and 48 unsupported
  conditions. The [publisher](https://data.mendeley.com/datasets/d5b3fzpw3g/1)
  describes smartphone field photos from BARI, Bangladesh, licensed CC BY 4.0
  (Ayesha Banu and Kaushik Deb). Inspected originals include overlapping leaves,
  stems, soil and shadows. The downloaded archive has only 84 `orig_` files,
  despite the landing page's larger original-image count. The 16 healthy
  `orig_` filenames contain only four distinct byte sequences: twelve exact
  duplicates were excluded. `aug_` files were not admitted. No exact overlap
  with the base training manifest was found; the retained rows also pass the
  cross-manifest pHash-distance-4 exclusion check.
- **45 PLDD internal examples:** 15 each early blight, late blight and healthy,
  sampled deterministically from distinct groups in the existing test split.
  These share a source with training, so they are internal evidence, not an
  independent field claim. Some are close-ups with little surrounding context.
- **180 Farmer.Chat examples:** the existing development-only external fold,
  after removing two exact duplicate images. It includes eight known-condition
  potato photos, unsupported potato conditions and other subjects. This source
  has influenced earlier development and is not independent selection evidence.

Bangladesh remains whole-source excluded from all training, selection and
calibration in this experiment. Cross-source SHA-256 and pHash-distance-4 checks
exclude detectable overlap with the full existing manifest; they cannot establish
complete independence. Publisher `orig_` naming does not prove raw-camera lineage.
Labels have not been independently re-adjudicated. Wide-canopy pictures may not
contain enough visible detail for a leaf-level diagnosis. There are **no new
external early-blight examples** and only four distinct healthy examples; a
larger expert-labelled, farm-grouped Nepal set remains necessary.

## Baseline

| Cohort | Correct accepted top match | Unsupported/wrong-subject false acceptance |
| --- | ---: | ---: |
| PLDD internal field | 42/45 | Not measured: known-only subset |
| Bangladesh source held out | 3/24 | 3/48 |
| Consumed Farmer.Chat development | 4/8 | 10/172 |

Bangladesh raw condition-head recognition is 9/24 before the refusal gate:
5/20 late blight and 4/4 healthy. The gate rejects all four healthy images.
Thus both disease recognition and usability generalization need work; merely
lowering acceptance thresholds is not an adequate fix.

Of the 20 source-labelled late-blight photos, the raw disease head calls 13
early blight and two healthy. The current gate blocks both of those raw healthy
mistakes. Consequently, increasing usable-leaf acceptance without improving
condition recognition could expose false reassurance that is currently refused.

The training inventory explains why a cross-source test matters: early blight
has 3,209 PLDD training images but only six Farmer.Chat images; late blight has
4,222 PLDD images but only five Farmer.Chat images. Healthy has 3,193 PLDD,
189 Central Java and 17 Farmer.Chat images. A large total count therefore hides
very limited source diversity for the named diseases. Rebalancing cannot invent
missing disease/background combinations; additional independently labelled
close-leaf and multi-leaf field coverage is the next data requirement.

The current model letterboxes the **whole photo to 224 pixels**; it does not
detect or segment individual leaves. A crowded canopy can therefore leave only
a few pixels per leaf. Leaf localization or user-confirmed region selection is
a separate candidate approach, requiring its own annotation and evaluation;
blindly choosing the crop with the highest disease score would introduce another
false-positive mechanism. No such crop-selection shortcut is used in this run.

These are **desktop CUDA/PyTorch measurements** using the frozen model's
evaluation transform and calibrated three-signal decision policy. They are not
a new physical-phone test. The previous 64-photo native parity result applies
only to that earlier model/input comparison, not automatically to a new candidate.
The known potato cases assume the user confirmed potato. The separate global
automatic crop-suggestion model is not being retrained or credited by this test.

## Predeclared candidate

- Parent: frozen EfficientNet-B0 checkpoint SHA-256
  `9e1854e4dabf868622abc5f21fea6cc13680c24bcdaa985560832e3843ed520a`.
- Weights-only fine-tuning with fresh optimizer/scheduler/RNG; not a resumed run.
  Architecture, ordered head labels, image size and split-manifest identity must
  match. The original checkpoint, calibration and app assets are not overwritten.
- Same 33,796-row audited manifest and unchanged train/validation/calibration/test
  assignments. Only training rows are resampled. No challenge images are added.
- Four epochs, 12,000 draws per epoch, seed 20260906, learning rate 0.00008,
  backbone multiplier 0.25, existing train-only augmentation and outlier loss.
  Best checkpoint is selected by the existing validation safety composite, never
  by the Bangladesh challenge. Calibration uses the separate calibration split.
- **Task/source balancing experiment:** equal expected mass per known condition
  and invalid/unknown role; square-root source balancing within each role prevents
  a tiny source receiving the same mass as thousands of photos. With the current
  training data, expected known-condition exposure increases from 22.2% to 50.0%.
  Each of early blight, late blight and healthy receives 16.7% rather than
  approximately 6.3%, 8.1% and 7.8%. Unknown conditions and other subjects remain
  represented. Additional inverse-frequency loss weights are disabled for this
  already-balanced experiment to avoid applying class correction twice.
- CUDA is mandatory; a CPU fallback fails before training. CPU image decoding
  and data auditing remain normal preprocessing tasks, not CPU model training.

This is a bounded ablation, not a claim that rebalancing will solve domain shift.
If accuracy gains come with worse false acceptance or false-healthy behavior,
the candidate must not replace the phone model. A successful desktop comparison
would still require export parity, native field testing and the existing release
gates before app integration.

## Reproduction and evidence

- The new preflight checked all 33,796 current image SHA-256 hashes against the
  exact, pinned previously decoded manifest and reran structural/duplicate checks.
  `ml/scripts/reverify_unchanged_snapshot.py` permits reuse only when the prior
  full-decode receipt, manifest, taxonomy and aliases match their identities.
  The receipt explicitly records zero fresh decodes and all current hashes
  verified. The slower redundant full-decode pass was stopped after this proof
  completed. No image verification or split check was waived.
- Configuration: `ml/configs/potato_field_v4_task_balanced_20260906.json`.
- Frozen challenge, exclusions, SHA-256 identity, baseline per-photo CSV and
  metrics: `ml/artifacts/potato_field_v4_20260906/` (local ignored artifacts).
- Training: `ml/scripts/train.py --config <configuration> --crop potato
  --architecture efficientnet_b0 --device cuda --output-dir <new run directory>`.
- Recalibrate only with `ml/scripts/calibrate.py` on the calibration split.
- Compare frozen candidates with `ml/scripts/potato_field_challenge.py evaluate`.

## Candidate outcome

**Rejected for app integration. Potato is not fixed.** Four CUDA/AMP epochs
completed on the RTX 4060 Laptop GPU. The validation rule retained epoch 1;
epoch 4's tiny numerical increase was below the configured minimum improvement.
Calibration used 2,944 separate calibration rows (1,548 known, 1,396 OOD).
Neither training nor calibration used the Bangladesh challenge.

| Cohort | Correct known: parent → candidate | False acceptance: parent → candidate |
| --- | ---: | ---: |
| PLDD internal field | 42/45 → 43/45 | Known-only subset |
| Bangladesh source held out | 3/24 → 4/24 | 3/48 → 4/48 |
| Consumed Farmer.Chat development | 4/8 → 4/8 | 10/172 → 16/172 |

The candidate trades small recognition gains for more wrong matches. Bangladesh
raw condition recognition actually falls from 9/24 to 8/24, and all four healthy
photos are still refused. Farmer.Chat false-healthy outputs increase from six
to eight, including wrong-subject and unsupported-condition photos. This fails
the predeclared safety comparison even though internal validation looks strong.
Do not lower thresholds or present this as a successful field fix.

Candidate checkpoint SHA-256:
`f008da51f6636758780f2c916ea65f3bb4cd01a1cce1a672d9eebd4dc4744ef4`.
The checkpoint and its calibrated policy remain research artifacts, not a mobile
release. Both original bundled model hashes remain unchanged. All 73 targeted
ML tests passed, including weights-only identity checks, no-CPU-fallback,
training-only sampling, manifest guards and snapshot-reverification safeguards.

Evidence: [decision and cohort comparison](../ml/artifacts/potato_field_v4_20260906/decision.json),
[baseline per-image CSV](../ml/artifacts/potato_field_v4_20260906/baseline.csv),
[candidate per-image CSV](../ml/artifacts/potato_field_v4_20260906/candidate_v4.csv),
[training summary](../ml/runs/potato_field_v4_task_balanced_20260906/efficientnet_b0/summary.json).
These are local ignored artifacts. All 297 challenge images completed for both
models; non-finite outputs or changed image hashes fail the candidate evaluation.

## What must improve next

1. Add independently reviewed, original potato field photos across multiple
   sources for **each** named disease, with close-leaf/cluttered-background and
   wide-canopy usability labels kept distinct. Existing totals conceal almost
   single-source early/late-blight coverage. Retain wrong-crop and unsupported
   condition examples; do not optimize only for accepting more leaves.
2. Evaluate leaf localization or user-confirmed image-region selection on
   original-resolution photos. This requires localization annotations and
   separate false-positive testing; no high-confidence crop-selection shortcut
   has been implemented or validated here.
3. Reserve a new farm/plant-grouped test source before further tuning. This
   challenge has now been inspected and must be labelled consumed development
   evidence in subsequent experiments. Real failed app photos, with independently
   confirmed diagnoses where available, would strengthen that next evaluation.
4. Only after a candidate improves field recognition **without worse refusal
   safety**, perform export parity and the same labelled challenge through the
   actual mobile runtime. The existing Nepal field-validation and confirmed-
   diagnosis release gates remain.
