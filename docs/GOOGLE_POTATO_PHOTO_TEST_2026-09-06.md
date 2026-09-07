# Google-discovered potato photo test — 6 September 2026

## Outcome

**The current potato model still makes unsafe mistakes on real photographs.** In this small diagnostic, a source-labelled early-blight plant was accepted as healthy, and two late-blight examples were accepted as early blight. No retraining, threshold changes, app model replacement or promotion was performed.

Scope is **potato's three supported classes**, following the potato-improvement request. This is not a new tomato/maize evaluation.

**Completed:** 11/11 desktop CUDA evaluations on the RTX 4060 Laptop GPU, using tensors produced by the actual Dart app image-preparation and potato-preprocessing code. The unchanged parent checkpoint and calibration hashes were checked against bundled app metadata. No inference errors or non-finite logits.

**Native Android status:** only 1/11 completed. Android entered `Dozing`, paused the diagnostic activity, and stopped progressing at photo 2. An unlock request was sent. Do not present the remaining ten GPU results as completed phone results. The isolated `com.krishidoc.app.modelaudit` package and fixtures are retained so the phone run can resume when unlocked; the normal app was not reinstalled or cleared.

## Sample selection and limitations

Google Images queries were `potato early blight extension`, `potato late blight extension`, and `healthy potato plants extension`. The source pages, not Google's snippets, supplied the disease labels. Additional UMN and NC botanical references were found through web search. Every selected photograph was visually inspected before inference.

- Four early-blight photos, four late-blight photos, three **apparently healthy / unverified** controls.
- Eight images have natural/growing context, including whole fields and seedlings; three plain-background disease photos are reported separately as controls. No background was removed, composited or replaced.
- The first proposed `hc03` control had visible holes/damage. It was excluded before inference and replaced with `hc04`; the initial selection is preserved separately and was never scored.
- All 11 final photos are byte-distinct. No exact overlap with the 33,796-row parent manifest; nearest 64-bit pHash distances are 14–18, above the exclusion threshold of 4. This does **not** prove all web-photo derivatives or pretrained ancestry are absent.
- Publisher disease labels are stronger evidence than an internet commenter, but not an independent laboratory diagnosis. Healthy-looking controls are not certified disease-free and are excluded from confirmed disease-accuracy claims.
- A field overview or seedling is not necessarily a usable close-up leaf view. Refusing such an input can be appropriate; an image's source disease label does not establish that the model can resolve its lesions at 224 pixels.
- This convenience sample is small, source-correlated, mostly non-Nepal, and not randomly selected. It cannot establish field accuracy or Nepal readiness. These inspected photos are now consumed diagnostic evidence, not a future untouched promotion holdout.
- Downloads are local, ignored test fixtures. Public access is not permission for model training or redistribution; no photographs were added to app assets or published to GitHub.

## Completed CUDA results

“Accepted” below means the model's **possible-match** route passes its existing validity, condition-probability and energy gates. It does not mean a confirmed diagnosis. Gallery exposure/size blocks were applied; one blur-warning case assumes the user elects to continue.

| Source class | Photos | Raw condition matches | Accepted matching label | Wrong accepted label | Refused |
|---|---:|---:|---:|---:|---:|
| Early blight | 4 | 2 | 1 | 1 | 2 |
| Late blight | 4 | 2 | 2 | 2 | 0 |
| Apparently healthy controls — uncertain labels | 3 | 1 | 0 | 0 | 3 |

Among the eight disease-labelled photos: **3 matching accepted results, 3 wrong accepted results, 2 refusals**. These counts must not be described as a population accuracy estimate. Among five natural/growing-context disease photos, the counts are 2 matching, 2 wrong and 1 refused; among three plain-background disease controls, 1 matching, 1 wrong and 1 refused.

| ID | Source label / photo context | Raw condition | Gated CUDA result | Key observation |
|---|---|---|---|---|
| eb01 | Early blight; close leaf with surrounding foliage | Early blight | Early blight | Only sample also completed natively; phone result agrees |
| eb02 | Early blight; attached leaves, mild spots, clutter | Healthy | **Healthy — wrong** | Healthy condition score 99.35%; usable-leaf score 84.03% |
| eb03 | Early blight; yellow compound leaf on black background | Early blight | Refused | Validity head says `other_plant`; usable score 47.41% |
| eb04 | Early blight; severe disease, wide field view | Healthy | Refused | Gate prevents a healthy result; leaf detail is small |
| lb01 | Late blight; detached leaves on white background | Late blight | Late blight, after blur warning | `tooBlurry` warning requires user confirmation in the gallery |
| lb02 | Late blight; detached compound leaf on white background | Early blight | **Early blight — wrong** | Early-blight condition score 89.11% |
| lb03 | Late blight; attached leaf and stem, natural background | Late blight | Late blight | Correct source-label match |
| lb04 | Late blight; leaf among foliage, visible lesion | Early blight | **Early blight — wrong** | Early-blight condition score 84.33%; original source image is 400 × 266 |
| hc01 | Apparently healthy hilled crop rows | Late blight | Refused | Wide-field control; not certified healthy |
| hc02 | Apparently healthy mulched potato row | Healthy | Refused | Wide-row control; not certified healthy |
| hc04 | Apparently healthy emerging potato seedlings | Late blight | Refused | Validity says `wrong_crop_leaf`; seedling is not a mature leaf view |

Condition scores are model scores, **not probabilities that the diagnosis is correct**. Lowering the validity threshold would not fix `eb02`, `lb02` or `lb04`: they already pass it. It could instead expose additional wrong results.

## Photo provenance

| IDs | Original source page | Credit / label basis |
|---|---|---|
| eb01–eb04 | [NDSU: Early Blight of Potato](https://www.ndsu.edu/agriculture/extension/publications/early-blight-potato) | Figures 1a, 1b, 3a and 5 respectively; Mitch Bauske for 1a, Sunil Shrestha for the others. Figures illustrating different diseases were not used as early blight. |
| lb01–lb02 | [NC State: Potato Late Blight](https://content.ces.ncsu.edu/potato-late-blight) | Lina Quesada, NC State Vegetable Pathology Lab; leaf photographs IMG_0014 and IMG_0022. |
| lb03 | [University of Maryland: Late Blight of Tomato and Potato](https://extension.umd.edu/resource/late-blight-tomato-and-potato) | Potato-specific lead photo; Gerald Holmes, Strawberry Center, Cal Poly San Luis Obispo, Bugwood.org. Tomato photos on the same page were excluded. |
| lb04 | [UMN: Weekly Vegetable Update, August 20, 2026](https://blog-fruit-vegetable-ipm.extension.umn.edu/2026/08/weekly-vegetable-update-august-20-2026.html) | Potato-specific caption; Gerald Holmes, Strawberry Center, Cal Poly San Luis Obispo, Bugwood.org. The article date is not a claim about the photo's capture date. |
| hc01–hc02 | [SDSU: Potatoes — How to Grow It](https://extension.sdstate.edu/potatoes-how-grow-it) | Hilled-row and mulched-row growing examples; no disease-free certification provided. |
| hc04 | [NC State Plant Toolbox: Solanum tuberosum](https://plants.ces.ncsu.edu/plants/solanum-tuberosum/common-name/potatoes/) | Potato seedlings; Allison P., CC BY-NC-ND 2.0. Species identification, not disease-free certification. |

Attribution erratum: the immutable download manifest initially used an incomplete credit for `lb03` and the article author's name for `lb04`. The verified photo credit above is corrected in result CSV/JSON; photo bytes and labels did not change.

## What this means for improvement

1. **Prioritize false-healthy early-blight cases.** `eb02` demonstrates failure on mild symptoms in attached, overlapping foliage, despite passing both gates with high scores. Add independently expert-labelled, licensed early-stage examples and healthy lookalikes from multiple farms; evaluate false-healthy frequency separately. Do not train on this diagnostic and then call it an independent test.
2. **Test early-versus-late blight contrasts across backgrounds.** Both a white-background late-blight photograph and a foliage-background example were confused with early blight. Background alone is not the entire failure mechanism.
3. **Separate usable leaf framing from wide-field views.** A capture guide and tested leaf-localization approach are candidates, not proven fixes. Compare full image and annotated leaf regions on a new held-out set without changing disease labels. Preserve abstention for unresolved small leaves and unsupported conditions.
4. **Review validity-head false refusals without bypassing it.** `eb03` has a correct raw condition but is blocked. Conversely `eb04` shows why removing that gate can expose a wrong healthy result. Threshold loosening alone is not supported by this evidence.
5. **Complete phone parity after unlocking.** One matching native sample cannot establish parity for all eleven. This GPU test exercises the confirmed-potato route; it is not an eleven-image test of automatic crop suggestion, camera interactions, or the entire normal app UI.

No model improvement is claimed from evaluation alone. The earlier rejected candidate remains rejected.

## Reproduction and evidence

Runner: `ml/scripts/google_potato_photo_audit.py`; `freeze` refuses to overwrite a frozen selection, `reference` requires CUDA, `summarize` refuses incomplete native runs, and `partial` explicitly records native completion counts.

Local, ignored artifacts under `ml/artifacts/google_potato_audit_20260906/reviewed/`:

- `manifest.json`, `freeze_receipt.json`: selection, exact image URLs, SHA-256/pHash, dimensions, source labels and download provenance.
- `host_inputs/*.f32`, `host_inputs/quality.json`: actual Dart preprocessing and gallery-quality checks for all 11 images; exporter test passed.
- `cuda_reference.json`, `cuda_per_image.csv`: completed CUDA evidence and per-image outcomes.
- `device_report.json`, `per_image.csv`, `summary.json`: **partial native** evidence, explicitly 1/11 complete.
- `device_integrity.json`: all 11 photo bytes and the manifest rehashed on the physical phone; diagnostic APK's embedded potato model checked against the normal app asset hash.

Current checkpoint: `9e1854e4dabf868622abc5f21fea6cc13680c24bcdaa985560832e3843ed520a`.
Bundled potato TFLite: `90875fad84d33e06884466030e2dfe18fedc2fd89b5e71a9d61835b837891c69`.
The source model, calibration and app assets were not modified. Ruff formatting/lint passed for the diagnostic runner.
