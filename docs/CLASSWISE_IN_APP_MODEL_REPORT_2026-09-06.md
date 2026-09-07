# In-app classwise disease-model audit — 6 September 2026

## Executive result

**320/320 photos completed on the connected Realme RMX3741 using an Android release diagnostic app and the production classification providers; zero processing errors.** The balanced test contains exactly 15 images for each of the 17 classes. The additional 65 field images are reported separately. No model weights, thresholds or normal-app features were changed during this evaluation.

| Plant | Classes × images | Correct top match | Rejected | Macro F1 | Median diagnosis time |
| --- | ---: | ---: | ---: | ---: | ---: |
| Tomato | 10 × 15 | 113/150 (75.3%) | 1 | 0.743 | 493 ms |
| Maize | 4 × 15 | 51/60 (85.0%) | 0 | 0.844 | 488 ms |
| Potato | 3 × 15 | 2/45 (4.4%) | 43 | 0.083 | 734 ms |

**These are diagnostic results, not Nepal field-accuracy claims.** PlantVillage likely overlaps the legacy model’s training data. The field cohort was previously used in development and contains only a few known-condition examples. Labels are supplied by the datasets, not newly certified by an agronomist. Fifteen examples per class are enough to expose some failures, not certify reliability.

## What “in the app” means

- Actual phone TensorFlow Lite execution in release mode, through `imagePreparationProvider`, `galleryQualityProvider`, and `classificationServiceProvider(crop)` from the app. Potato therefore uses EfficientNet; tomato/maize use the existing 38-class model with crop scoping. No fake classifier or desktop substitution.
- The test supplies each photo’s correct crop, equivalent to the farmer confirming/correcting it. Crop-suggestion performance is measured separately so wrong suggestions do not silently contaminate disease-class scores.
- This is an instrumented batch test, not 320 manual taps through the native gallery picker or tests of live camera focus/exposure. Public input files enter the shared app preparation path directly. Native picker resizing before that path is not tested.
- Raw model checking also runs for images the gallery would block, to distinguish model failure from image-quality refusal. “Gallery correct” below counts a block as unsuccessful and assumes the user explicitly proceeds after a blur-only warning.
- Every app output remains a possible match (`uncertain`) or a refusal. A correct possible match counts as top-1 recognition; uncertainty is not falsely counted as an incorrect class. Model probabilities are uncalibrated scores, not correctness guarantees.
- The isolated `com.krishidoc.app.modelaudit` package never replaced normal `com.krishidoc.app`. Screen locking does not intentionally stop batch computation. Results were saved after every photo.

## All 17 classes — 15 images each

| Class | Correct | Raw condition correct | Wrong class | Rejected | Gallery correct | Blur warnings | Top-3 includes label | Precision | Recall | F1 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| maize cercospora leaf spot gray leaf spot | 11/15 | 11/15 | 4 | 0 | 11/15 | 0 | 15/15 | 0.846 | 0.733 | 0.786 |
| maize common rust | 15/15 | 15/15 | 0 | 0 | 15/15 | 0 | 15/15 | 0.789 | 1.000 | 0.882 |
| maize northern leaf blight | 10/15 | 10/15 | 5 | 0 | 10/15 | 0 | 15/15 | 0.833 | 0.667 | 0.741 |
| maize healthy | 15/15 | 15/15 | 0 | 0 | 15/15 | 2 | 15/15 | 0.938 | 1.000 | 0.968 |
| potato early blight | 1/15 | 12/15 | 0 | 14 | 1/15 | 0 | 1/15 | 1.000 | 0.067 | 0.125 |
| potato late blight | 1/15 | 5/15 | 0 | 14 | 1/15 | 0 | 1/15 | 1.000 | 0.067 | 0.125 |
| potato healthy | 0/15 | 13/15 | 0 | 15 | 0/15 | 0 | 0/15 | 0.000 | 0.000 | 0.000 |
| tomato bacterial spot | 12/15 | 12/15 | 3 | 0 | 12/15 | 0 | 15/15 | 0.800 | 0.800 | 0.800 |
| tomato early blight | 9/15 | 9/15 | 6 | 0 | 9/15 | 0 | 12/15 | 1.000 | 0.600 | 0.750 |
| tomato late blight | 12/15 | 12/15 | 3 | 0 | 10/15 | 0 | 15/15 | 0.923 | 0.800 | 0.857 |
| tomato leaf mold | 15/15 | 15/15 | 0 | 0 | 15/15 | 0 | 15/15 | 0.714 | 1.000 | 0.833 |
| tomato septoria leaf spot | 12/15 | 12/15 | 3 | 0 | 12/15 | 0 | 15/15 | 0.480 | 0.800 | 0.600 |
| tomato spider mites two spotted spider mite | 10/15 | 10/15 | 5 | 0 | 10/15 | 0 | 13/15 | 0.909 | 0.667 | 0.769 |
| tomato target spot | 12/15 | 12/15 | 3 | 0 | 12/15 | 0 | 15/15 | 0.667 | 0.800 | 0.727 |
| tomato yellow leaf curl virus | 15/15 | 15/15 | 0 | 0 | 15/15 | 5 | 15/15 | 0.714 | 1.000 | 0.833 |
| tomato mosaic virus | 3/15 | 3/15 | 12 | 0 | 3/15 | 0 | 8/15 | 1.000 | 0.200 | 0.333 |
| tomato healthy | 13/15 | 13/15 | 1 | 1 | 13/15 | 0 | 14/15 | 1.000 | 0.867 | 0.929 |

Precision/recall/F1 use the balanced cohort only; rejected cases are false negatives. Top-3 for potato is weak evidence because there are only three potato classes. Latency includes the app’s diagnosis preprocessing/inference, not photographer effort, and the first call includes warm-up.

## Exact class confusions

### Tomato

Rows are source labels; columns are the app’s top possible match.

| Expected \ predicted | bacterial spot | early blight | late blight | leaf mold | septoria leaf spot | spider mites two spotted spider mite | target spot | yellow leaf curl virus | mosaic virus | healthy | Rejected |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| bacterial spot | 12 | 0 | 0 | 0 | 2 | 0 | 0 | 1 | 0 | 0 | 0 |
| early blight | 1 | 9 | 0 | 0 | 2 | 0 | 1 | 2 | 0 | 0 | 0 |
| late blight | 0 | 0 | 12 | 3 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| leaf mold | 0 | 0 | 0 | 15 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| septoria leaf spot | 1 | 0 | 0 | 1 | 12 | 1 | 0 | 0 | 0 | 0 | 0 |
| spider mites two spotted spider mite | 0 | 0 | 1 | 0 | 0 | 10 | 4 | 0 | 0 | 0 | 0 |
| target spot | 1 | 0 | 0 | 0 | 1 | 0 | 12 | 1 | 0 | 0 | 0 |
| yellow leaf curl virus | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 15 | 0 | 0 | 0 |
| mosaic virus | 0 | 0 | 0 | 1 | 8 | 0 | 1 | 2 | 3 | 0 | 0 |
| healthy | 0 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 13 | 1 |

### Maize

Rows are source labels; columns are the app’s top possible match.

| Expected \ predicted | cercospora leaf spot gray leaf spot | common rust | northern leaf blight | healthy | Rejected |
| --- | ---: | ---: | ---: | ---: | ---: |
| cercospora leaf spot gray leaf spot | 11 | 1 | 2 | 1 | 0 |
| common rust | 0 | 15 | 0 | 0 | 0 |
| northern leaf blight | 2 | 3 | 10 | 0 | 0 |
| healthy | 0 | 0 | 0 | 15 | 0 |

### Potato

Rows are source labels; columns are the app’s top possible match.

| Expected \ predicted | early blight | late blight | healthy | Rejected |
| --- | ---: | ---: | ---: | ---: |
| early blight | 1 | 0 | 0 | 14 |
| late blight | 0 | 1 | 0 | 14 |
| healthy | 0 | 0 | 0 | 15 |

## Why the potato app refuses so many photos

On the 45 balanced potato images, the disease head alone identifies **30/45** correctly; **28** of those correct raw predictions are removed by the gate. This separates recognition errors from refusal errors.

Gate failures (an image can fail more than one): usable_leaf: 43.
Validity-head top classes: other_plant: 43, usable_target_leaf: 2.

For comparison only, the legacy global model’s raw top label is correct on **39/45** of these same potato photos. That is not an unbiased reason to switch back: PlantVillage likely overlaps its training data, and unknown-condition safety/field performance must also be compared.

A likely explanation is source/domain dependence in the potato validity head, which needs source-grouped validation and inspection of negative labels. That mechanism is a hypothesis; the measured facts are the raw scores and failed gates in the CSV. Raising acceptance without checking false positives would hide the symptom rather than establish reliability.

**Native-versus-desktop check:** all 64 potato inputs (45 balanced + 19 field) were also processed through the frozen ONNX export using matching Dart-prepared tensors. Maximum absolute logit difference: 0.00033665. Validity argmax disagreements: 0; condition argmax disagreements: 0; gate-decision disagreements: 0. Thus the rejection pattern is reproducible in the model, not a phone-only conversion/routing fault on these tested examples. This does not prove all possible images are numerically equivalent.

## Crop recognition before confirmation

| Plant | Suggestion offered (raw) | Correct when offered | No suggestion |
| --- | ---: | ---: | ---: |
| Tomato | 144/150 | 144/144 (100.0%) | 6 |
| Maize | 60/60 | 60/60 (100.0%) | 0 |
| Potato | 36/45 | 35/36 (97.2%) | 9 |

These are raw crop-suggestion opportunities. The UI suppresses suggestions for blur warnings/blocked photos; per-image CSV includes both raw and actually eligible suggestions. Correct-crop confirmation must remain mandatory.

## Separate field stress test

| Plant | Known-condition examples | Correct top match | Rejected |
| --- | ---: | ---: | ---: |
| Tomato | 3 | 0/3 (0.0%) | 2 |
| Maize | 3 | 0/3 (0.0%) | 1 |
| Potato | 8 | 4/8 (50.0%) | 1 |

Unknown-condition images of supported crops incorrectly given a covered-condition match: **12/27 (44.4%)**.
Other/unknown-crop field photos receiving a supported-crop suggestion: **6/24 (25.0%)**. These photos have no valid manual crop route; they are not credited as successful disease rejections simply because the test has no correct crop to select.

This cohort includes wide shots and multi-leaf photographs. Some are labelled usable by the source despite weak visual evidence at leaf scale; usability labels need review before retraining. Do not merge this cohort into the balanced laboratory score.

## Failures to inspect first

3 wrong balanced-cohort predictions had a top score ≥0.90. This measures overconfident scores, not the UI’s confidence state.
Source-labelled disease images predicted healthy across both cohorts: 4. IDs: 9, 269, 270, 290.

| Image ID | Source cohort | Expected | App output | Score |
| ---: | --- | --- | --- | ---: |
| [270](../ml/data/raw/farmer_chat_india/images/00489.jpg) | field_development_stress | potato early blight | potato healthy | 0.941 |
| [290](../ml/data/raw/farmer_chat_india/images/00061.jpg) | field_development_stress | tomato late blight | tomato healthy | 0.649 |
| [9](../ml/data/raw/plantvillage-audit-15-per-class/07e2a661f9d3d83e9d31160806eb3e6a00a435fe.jpg) | balanced_lab_diagnostic | maize cercospora leaf spot gray leaf spot | maize healthy | 0.475 |
| [269](../ml/data/raw/farmer_chat_india/images/00695.jpg) | field_development_stress | potato early blight | potato healthy | 0.468 |
| [39](../ml/data/raw/plantvillage-audit-15-per-class/d277838665f13a6f78b65b0c16bca771ce1563e3.jpg) | balanced_lab_diagnostic | maize northern leaf blight | maize common rust | 0.983 |
| [230](../ml/data/raw/plantvillage-audit-15-per-class/e40614e45e797cb50f8ce9934f264ed016cb0237.jpg) | balanced_lab_diagnostic | tomato mosaic virus | tomato septoria leaf spot | 0.957 |
| [228](../ml/data/raw/plantvillage-audit-15-per-class/7b036fde4a8d3a5b4b32fa55300977e5c3ef6890.jpg) | balanced_lab_diagnostic | tomato mosaic virus | tomato yellow leaf curl virus | 0.953 |
| [235](../ml/data/raw/plantvillage-audit-15-per-class/7ec6d330313b6a6dbe3ebc60f3b0f9604adf056f.jpg) | balanced_lab_diagnostic | tomato mosaic virus | tomato septoria leaf spot | 0.888 |
| [200](../ml/data/raw/plantvillage-audit-15-per-class/86a422e652b8dfd7a0ac25780efd1ad3a4592f99.jpg) | balanced_lab_diagnostic | tomato target spot | tomato bacterial spot | 0.884 |
| [35](../ml/data/raw/plantvillage-audit-15-per-class/218b96952d0bff449f4142b91b008c1890d747ee.jpg) | balanced_lab_diagnostic | maize northern leaf blight | maize common rust | 0.883 |
| [237](../ml/data/raw/plantvillage-audit-15-per-class/fc04a10ea4bfd73e345503f41da59ee555afc4cf.jpg) | balanced_lab_diagnostic | tomato mosaic virus | tomato septoria leaf spot | 0.882 |
| [105](../ml/data/raw/plantvillage-audit-15-per-class/0168d31231a750911c0603d65af653106e07cea9.jpg) | balanced_lab_diagnostic | tomato bacterial spot | tomato yellow leaf curl virus | 0.810 |
| [256](../ml/data/raw/farmer_chat_india/images/00516.jpg) | field_development_stress | maize healthy | maize common rust | 0.798 |
| [139](../ml/data/raw/plantvillage-audit-15-per-class/926d013cdbb0a7c5734ce72efc4e9d64ba22ba8f.jpg) | balanced_lab_diagnostic | tomato late blight | tomato leaf mold | 0.736 |
| [231](../ml/data/raw/plantvillage-audit-15-per-class/8bc8ce1c9ea848a3c375137752136332c6adc110.jpg) | balanced_lab_diagnostic | tomato mosaic virus | tomato septoria leaf spot | 0.734 |
| [226](../ml/data/raw/plantvillage-audit-15-per-class/635c7f4375036e7222fe94f816ebf7ccfe1a25a3.jpg) | balanced_lab_diagnostic | tomato mosaic virus | tomato septoria leaf spot | 0.733 |
| [128](../ml/data/raw/plantvillage-audit-15-per-class/3e0dab6e2aae14167fef1b759124c77c6ff125bf.jpg) | balanced_lab_diagnostic | tomato early blight | tomato septoria leaf spot | 0.730 |
| [186](../ml/data/raw/plantvillage-audit-15-per-class/f19daeee6c19a6a39563eec7f482884c6408848c.jpg) | balanced_lab_diagnostic | tomato spider mites two spotted spider mite | tomato target spot | 0.729 |
| [245](../ml/data/raw/plantvillage-audit-15-per-class/a747889546be9282805c3f71df3e862070010b1a.jpg) | balanced_lab_diagnostic | tomato healthy | tomato leaf mold | 0.722 |
| [227](../ml/data/raw/plantvillage-audit-15-per-class/0a9e70c2a50d6696f698eaba78672ffaaf234ce0.jpg) | balanced_lab_diagnostic | tomato mosaic virus | tomato yellow leaf curl virus | 0.707 |
| [169](../ml/data/raw/plantvillage-audit-15-per-class/cbdece41d54d80270f859bf97f4253db56f7dc60.jpg) | balanced_lab_diagnostic | tomato septoria leaf spot | tomato spider mites two spotted spider mite | 0.698 |
| [271](../ml/data/raw/farmer_chat_india/images/00113.jpg) | field_development_stress | potato healthy | potato early blight | 0.693 |
| [118](../ml/data/raw/plantvillage-audit-15-per-class/46d6ce60bade07f1a766d2e1800a669e9207df9d.jpg) | balanced_lab_diagnostic | tomato bacterial spot | tomato septoria leaf spot | 0.687 |
| [127](../ml/data/raw/plantvillage-audit-15-per-class/69f25be9a32bafed50a4830be20ee17e7ae9a47f.jpg) | balanced_lab_diagnostic | tomato early blight | tomato yellow leaf curl virus | 0.684 |
| [33](../ml/data/raw/plantvillage-audit-15-per-class/f611cd3b67a5fa4f95402f96977e0a47b096fd61.jpg) | balanced_lab_diagnostic | maize northern leaf blight | maize cercospora leaf spot gray leaf spot | 0.679 |

## Improvement priorities supported by this run

1. **Audit the weakest classes and their confusion pairs first.** The lowest recall classes are potato healthy (0/15), potato early blight (1/15), potato late blight (1/15), tomato mosaic virus (3/15), tomato early blight (9/15). Inspect the exact failed photos in the CSV before attributing every mismatch to disease appearance. Verify tensor label order, source labels, crop routing, and pixel normalization against the pinned training/export artifacts.
   - Potato: the usability head is the immediate bottleneck, but raw late-blight recognition is also weak (see the raw-condition column). Expand positive potato coverage across backgrounds, leaf scales, camera styles and sources; audit false “other plant” negatives. Keep a separate negative test set before recalibrating.
   - Tomato mosaic virus: inspect the eight mosaic-labelled photos called Septoria. Verify source labels, then add difficult mosaic/Septoria/target-spot contrasts and evaluate per-class recall on unseen farms. Do not report a high average score that hides this class.
2. **Prioritize false-healthy and unknown-condition acceptance.** These can falsely reassure farmers. Review the listed IDs, add independently labelled unknown disease/pest/nutrient/stress and non-leaf examples, and evaluate a separate crop/leaf-validity detector. Do not simply raise or lower a score threshold on these test images.
3. **Address the field/laboratory gap with source-grouped data.** Collect close leaf photos plus difficult wide shots from Nepal, with independent expert labels, farm/plant grouping, device/lighting metadata and a locked test split. Existing public/lab results cannot establish field readiness. Re-review source-labelled “usable” whole-plot images.
4. **Keep crop confirmation and cautious output.** Crop suggestions and disease classification are separate failure points. The existing model has no reliable explicit non-plant class; wrong-crop/non-plant refusal needs its own evaluated data and gate.
5. **Only then train/compare candidates.** Use the failed-class review to design a training plan, calibrate on a separate set, and evaluate macro F1, per-class recall, false-healthy rate, unknown-condition false acceptance, and the exact release TensorFlow Lite app path. This audit is now development evidence, not a future untouched test set.

No retraining or threshold changes were performed for this report. A larger independent field test is required before selecting a “best” model.

## Evidence and reproducibility

- [Per-image results CSV](../ml/artifacts/classwise_app_audit_20260906/per_image_results.csv): every expected/predicted label, crop suggestion, gallery disposition, score, timing, source file, leaf group and SHA-256.
- [Per-class metrics CSV](../ml/artifacts/classwise_app_audit_20260906/per_class_results.csv), [summary JSON](../ml/artifacts/classwise_app_audit_20260906/summary.json), [raw phone report](../ml/artifacts/classwise_app_audit_20260906/device_report.json), [input manifest](../ml/artifacts/classwise_app_audit_20260906/manifest.json). These are local ignored evaluation artifacts, not bundled app assets.
- Original lab source: [PlantVillage](https://github.com/spMohanty/PlantVillage-Dataset), pinned at `7f7ecc7e1eaca78107e3affe7cb5abd9427e139a`. Original RGB files only; deterministic SHA ordering and source leaf grouping when available. Git blob hashes and local SHA-256 verified. No exact image duplicates. 138/255 balanced examples have mapped source leaf groups; 117 use filename-based fallback groups, so full independence is not asserted.
- Phone model versions: `experimental-janasunrise-mobilenetv2-pv38-r8bff045b` and `experimental-potato-efficientnet-b0-9e1854e4dabf`. The audit APK and model payload hashes are retained in the execution receipt.
- Run timestamps (UTC): 2026-09-06T09:47:08.593608Z to 2026-09-06T09:58:08.849248Z. Runtime: Android release, production Riverpod classification providers.
- Recreate inputs with `ml/scripts/prepare_classwise_app_audit.py`; build the explicit `app/tool/labelled_model_audit_classwise.dart` target in release mode with real models enabled; verify the separate package ID; transfer `audit-input` to that package’s external files directory; launch; pull the completed report; run `ml/scripts/report_classwise_app_audit.py`.

The normal app installation and its records were not modified by this audit.
