# Potato field model V5 — new-source experiment

Status: **completed and rejected for app replacement**. App assets unchanged.
V6 is a separate follow-up, not a replacement of these results.

## Outcome

Four CUDA epochs completed, followed by calibration and all 749 comparisons.
Correct accepted predictions increased from 457 to 470, but wrong accepted
predictions increased from 43 to 70. The pooled total includes mixed cohorts;
it is not a deployment-accuracy estimate. Three unverified healthy-looking
Google controls are excluded from any healthy-accuracy claim.

| Cohort | Correct accepted: parent → V5 | Wrong accepted: parent → V5 |
| --- | ---: | ---: |
| PlantSeg publisher test, 44 | 22 → 32 | 10 → 11 |
| Holeta healthy, 331 | 325 → 328 | 3 → 3 |
| Holeta late blight, 66 | 58 → 56 | 6 → 9 |
| Bangladesh known conditions, 24 | 3 → 3 | 2 → 7 |
| Farmer.Chat known conditions, 8 | 4 → 4 | 3 → 3 |
| Google disease photos, 8 | 3 → 4 | 3 → 3 |
| PLDD internal examples, 45 | 42 → 43 | 3 → 2 |

Unsupported-image false acceptance rose from **13/220 (5.9%) to 32/220 (14.5%)**:
Bangladesh 3/48 → 9/48; Farmer.Chat 10/172 → 23/172. Google `eb02` is still
incorrectly accepted as healthy; `lb02` and `lb04` are still early/late mistakes.
The extra correct Google prediction is `eb03`, previously refused. This does not
repair the original false reassurance. All three uncertain healthy controls
remain refused. Holeta's strong healthy performance must not hide the decline
on its late-blight photos.

Replaying the frozen logits reproduces the decisions. Every one of the 19 new
unsupported acceptances crosses the validity gate; none crosses the energy
gate. Both models' condition-probability and energy gates pass all 220 of these
unsupported photos. Validity top-class `usable` increases from 13 to 36, so the
problem is not merely a changed energy threshold. This is descriptive gate
attribution, not proof of the underlying data/optimization cause.

The original selection rule chose epoch 4. Validation early/late matches by epoch:
6/10 + 11/13, 9/10 + 10/13, 5/10 + 11/13, 7/10 + 11/13. The optional alternative
was **not created** because the final checkpoint is already the primary.

- Candidate checkpoint SHA-256:
  `d1051609d13383d5c3a660dbeaebf4e1f92bcea481e9f4f5078cea938ed16ccd`.
- Calibration SHA-256:
  `57ea026f6b520c7ad2141a781bfbc026f931db9bca3c271fe871b9cdc0d0e136`.
- Calibrated on 2,944 unchanged calibration images only. Its observed calibration
  false-accept rate is 2.44%, but diagnostic-domain false acceptance is 14.5%:
  calibration-domain performance does not establish cross-source reliability.
- Model optimization loop: 1,287 seconds on the RTX 4060. Entire execution
  completed at 2026-09-07 07:13:37 UTC (12:58:37 Nepal).
- Evidence: `ml/artifacts/potato_field_v5_20260907/`: `parent_evaluation.json`,
  `candidate_evaluation.json`, per-image CSVs, `regression_decision.json`,
  `disagreements.csv`, execution/code/data hashes, and all stage logs.
- All these test outputs, including Holeta, are now consumed development evidence
  for subsequent experiments. They must not be called an independent V6 holdout.
- The app model remains SHA-256
  `90875fad84d33e06884466030e2dfe18fedc2fd89b5e71a9d61835b837891c69`.

## Decision fixed before training

The V4 balancing-only experiment increased unsupported-image false acceptance.
The subsequent Google-photo audit found early/late-blight confusion and a
high-confidence false healthy prediction. More epochs on the same source mix
are not an adequate response. V5 tests additional labelled disease imagery,
without changing the app's architecture or relaxing refusal thresholds by hand.

- Parent: V3 EfficientNet-B0, SHA-256
  `9e1854e4dabf868622abc5f21fea6cc13680c24bcdaa985560832e3843ed520a`.
- New source: [PlantSeg v5](https://zenodo.org/records/14935094), all 243
  potato-prefixed images and corresponding disease masks. Publisher declares
  CC BY 4.0; the underlying internet-photo rights still require review before
  redistribution/commercial release. Disease masks are **not** whole-leaf masks.
- Preserve publisher train/validation/test assignments. Quarantine entire
  near-duplicate components spanning labels/splits and components overlapping
  prior data or consumed Google/Bangladesh challenges (pHash distance <=8).
  Retain every original base-manifest row unchanged. No farm/photographer IDs
  are available: passing hash checks cannot prove complete independence.
- Inspect train/validation images for wrong subjects, collages and unresolvable
  labels; record exclusions before prediction. No automatic disease relabelling.
- The 307 Tanzania samples remain quarantined pending expert label review.
  Visual uncertainty does not establish that their publisher is wrong.
- Whole-source Holeta data remain reserved for a frozen-model comparison;
  no use for optimization, calibration or checkpoint selection.
- Four CUDA/AMP epochs, seed 20260907, 16,000 sampled training examples/epoch,
  task/source-balanced sampler, learning rate 0.0001, backbone multiplier 0.25.
  All existing negative/outlier training data and the 0.03 outlier loss remain.
- Select by the existing validation safety composite. Fit calibration using
  only the unchanged, separate calibration split. No test-driven thresholds.

## Comparison and stop conditions

Compare against the parent, not the rejected V4. Record raw class recognition,
accepted correct predictions, wrong accepted predictions, false healthy calls,
refusals and unsupported-condition false acceptance, per source and class.
Evaluate the unchanged 297-photo challenge as **consumed diagnostic data**, not
independent validation. Include the 11 Google photos as consumed diagnostics,
using exact Dart-prepared tensors where possible; healthy-looking controls do
not establish true healthy accuracy.

A candidate is not an improvement merely because internal validation rises.
Reject app replacement if disease wrong acceptances/false reassurance or
unsupported-image acceptance increase on the frozen diagnostic comparisons.
An apparent improvement on tiny cohorts remains uncertain. Confident clinical
claims still require independent, expert-labelled Nepal field data and native
mobile parity/performance verification. No candidate is automatically deployed.

## Engineering change

Weights-only fine-tuning now permits an explicitly pinned, append-only manifest
extension after the full combined-data audit. All parent rows/labels/splits must
remain identical; additions cannot recycle parent source/group/SHA identities.
Checkpoint label order, architecture and parent-manifest hash still must match.
This is not a resumed training run and does not reuse optimizer/RNG state.

## Frozen data inventory

Visual screening of 195 train/validation images found disease-name banners,
collages, a tuber-centred image, stock-photo rights concerns, and three pairs of
the same visible photograph under contradictory early/late labels. Both sides
of each contradictory pair were quarantined, not relabelled. This review is
visual quality screening, not independent agronomic adjudication.

After exclusions: 138 new train images (69 early, 69 late), 23 validation images
(10 early, 13 late), and 44 publisher-test images (22 each). Thirty-eight of the
243 acquired images were excluded. The resulting manifest has 34,001 rows.
Publisher test images were not visually cherry-picked; their labels and image
appropriateness still carry source uncertainty.

The Holeta archive actually contains 363 healthy and **67** late-blight JPGs,
not the 63 late-blight images in its description. After exact/near-duplicate
exclusion, 331 healthy and 66 late images remain. This discrepancy is recorded,
not silently corrected. These are image counts, not independent farm counts.

Evaluation is frozen at **749 images**: 297 consumed challenge images, 11 Google
diagnostic/control images, 44 PlantSeg test images, and 397 Holeta images.

- Training manifest SHA-256:
  `7793085b141fe4ca01f340066e73822618fb7686d83be6c3016e81bd4e1829f9`.
- Evaluation manifest SHA-256:
  `a0f74db6eeccf0e97ea7ccafff465d6fddd1ce881fbce29abae0eba7d37c3df6`.
- Config file SHA-256:
  `240c9011913c377e0e91c1808228f9fb89b9d2090e87ca8da5c7c0c97d93ff3e`.
- Focused regression tests: **96 passed** (fine-tuning ancestry, strict snapshots,
  training safety, safety-composite selection and bounded HTTP range validation).
- Phone check on September 7: ADB reports **no connected device**. No new native
  phone-test or installation claim is made.

## Execution checkpoint

All 34,001 images passed fresh decode, SHA-256 and pHash verification; structural
checks passed with 28,415 groups and zero mixed-condition groups. Serial decoding
was replaced with eight independent verification workers; equivalence and
tamper-rejection tests passed. No image checks were skipped or inherited.

The final ML suite passes **252 tests**, with one ONNX deprecation warning.
The runner launched training at 2026-09-07 06:47:33 UTC (12:32:33 Nepal), requiring
CUDA. Logs and frozen code/config/data identities are in
`ml/artifacts/potato_field_v5_20260907/execution.json` and `train.log`.
Per-source validation diagnostics now accompany aggregate validation metrics;
they do not alter the predefined checkpoint-selection criterion.

### Optional exploratory validation-selection comparison

Declared while training is running, after inspecting validation epochs 1–3 but
before reading any reserved evaluation outputs: keep the original aggregate-best
candidate as the primary result. Also retain the final checkpoint **only if**
its mean early/late recall on PlantSeg validation exceeds the primary checkpoint,
both recalls are at least 0.70, and its aggregate safety composite is within
0.001 of the primary score. Fit its own calibration on the unchanged calibration
split. This is an explicitly exploratory, validation-selected alternative—not
a redefinition of the primary experiment and not a test-selected checkpoint.
The motivation is observed: epoch 3 raises the aggregate score while new-source
early-blight recognition falls from 9/10 to 5/10. Do not hide this selection bias
behind the larger aggregate score. If the final checkpoint does not qualify,
do not create this alternative.
