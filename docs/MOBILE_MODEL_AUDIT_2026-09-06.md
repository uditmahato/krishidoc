# Camera and model audit — 6 September 2026

## Bottom line

The complaint was justified. An image-resizing mismatch changed the potato model's decisions, the gallery action was poorly placed, and a provisional blur score blocked useful leaf photos. These integration/UI defects are corrected. **The model itself is still not reliable enough for definitive field diagnosis.** No new weights, thresholds, confidence claims or treatment permissions were introduced.

## Changes

- Gallery and Capture are two labelled, high-contrast buttons in a fixed bottom bar, beside each other and outside the camera overlays. Both remain visible with large text; gallery still works if camera permission is denied.
- Import errors now remain visible when the camera is unavailable.
- Potato preprocessing uses antialiased triangle/bilinear resizing with training-compatible pixel-centre coordinates, intermediate rounding and ties-to-even letterbox dimensions. The former four-point linear sampler did not reproduce the training resize when reducing photos. The numerical reference is the RGB bilinear implementation in [Pillow's resampler](https://github.com/python-pillow/Pillow/blob/main/src/libImaging/Resample.c). Six generated RGB fixtures check every output byte, including up/downsampling and single-axis cases.
- A blur-only gallery result now opens an explicit warning/review, without guessing a crop first. The user chooses the crop and taps “Check anyway”. Exposure and invalid-size/decode failures remain blocked. Live-camera coaching is unchanged. This is a provisional user override, not a calibrated photo-quality classifier.

## What was actually tested

237 deterministic diagnostic inputs: 233 public dataset photos and 4 solid-colour controls. At most one image per recorded group was selected. Original image hashes were verified.

| Source / recorded split | Count |
| --- | ---: |
| `pldd-up`, internal test | 60 |
| `tom2024-original`, internal test | 108 |
| `farmer_chat_india_development_v1`, external development | 65 |
| Synthetic controls, reported separately | 4 |

The **actual Dart app preprocessing** decoded/oriented each original, applied the normal 1024px/JPEG preparation, assessed gallery quality, and exported its normalized tensor. The frozen potato ONNX export ran on those tensors on the desktop CPU. It was compared with the same weights receiving the Python training reference transform. This is **not a completed Android TensorFlow Lite accuracy benchmark** and is not GPU training.

The external split has already been used during development. It is not an independent held-out promotion set. Labels are source-provided, not newly confirmed by an agronomist; legacy model training overlap cannot be excluded. These observations do not establish Nepal field accuracy or tomato/maize model accuracy.

## Results before and after the resize correction

“Correct” means a correct top condition that also passed the frozen validity/energy gate. Rejections count as unsuccessful known-condition cases; their denominator is not silently removed. These scores are before the UI quality gate, which is reported separately.

| Potato diagnostic measure | Before | Corrected | Training reference |
| --- | ---: | ---: | ---: |
| Internal known conditions | 54/60 | 58/60 | 58/60 |
| External known conditions | 2/8 | 4/8 | 4/8 |
| All known conditions | 56/68 | 62/68 | 62/68 |
| Known conditions rejected | 6/68 | 1/68 | 1/68 |
| External out-of-scope inputs incorrectly accepted | 3/57 | 8/57 | 8/57 |
| Internal out-of-scope inputs incorrectly accepted | 0/108 | 0/108 | 0/108 |
| Solid-colour controls accepted | 0/4 | 0/4 | 0/4 |
| Decisions different from training reference, all inputs | 17/237 | 0/237 | — |

The corrected pipeline reproduces the reference decisions, **including its mistakes**. In particular, external false acceptance rises to 8/57 (14.0%); removing accidental aliasing is not a general safety improvement. Do not promote this candidate or relax its confidence policy. JPEG/decode/initial downscale differences still change raw logits (maximum validity-logit difference 1.51 in this sample), so zero decision disagreement does not mean identical tensors on every photograph.

External known-potato details: both early-blight-labelled images are predicted healthy; 4/5 healthy-labelled images are correct and one is called early blight; the one late-blight-labelled image is refused. One early-blight example contains many leaves and another is a whole-plot photograph, despite both being labelled usable. This is a real workflow failure and a data-quality issue, not evidence that the symptom labels were independently verified.

The eight external false accepts include five unknown potato conditions, one unknown tomato condition and two other/unknown-plant examples. Crop confirmation remains necessary. An apparently “healthy” visual match must not reassure a farmer whose plant has visible symptoms.

## Gallery quality findings

The original quality gate rejected 39/237 inputs. Among source-labelled usable target leaves, blur alone blocked 13 potato, 10 tomato and 7 maize examples; one tomato example was below the minimum size. One inspected rejected potato photo had visible leaf detail plus large black borders. A whole-image edge statistic is not a reliable leaf sharpness decision. The new warning/override addresses that false-veto path without arbitrarily fitting a lower threshold to this audit.

## Phone execution and data incident

The connected device is a Realme RMX3741, Android 15, ARM64. Two Flutter integration-test attempts terminated before completion; the first reached 10 examples but did not yield a retained complete report. Do not use those attempts as an accuracy score.

The initial audit package override did not take effect: inspection showed the normal `com.krishidoc.app` ID. The normal app was removed during that testing period and restored from its release APK. Android logs confirmed removal but do not establish the initiating cause. **Previous local app history may have been lost.**

Audit builds now derive the separate `com.krishidoc.app.modelaudit` ID from the explicit audit entry point; the built APK's package was checked before installation. Its standalone execution was obstructed by the phone's security-check/foreground state and did not produce the full report. User attention is required to finish native accuracy and real-photo ONNX/TFLite parity verification. No security controls were disabled. Audit photos are excluded from the production APK.

## Reproduction and remaining work

Verification: 230 app regression tests pass; the opt-in dataset exporter is deliberately skipped in the ordinary suite and was run separately to completion on all 237 inputs. Targeted Flutter static analysis reports no issues. Python audit scripts compile. The six numerical resize cases and rounding checks pass. The temporary audit app and diagnostic phone screenshot were removed; their source/evidence remain locally reproducible. The phone's original stay-awake setting was restored to 0.

Release `0.3.2+5` built and installed successfully with `adb install -r` on the connected Realme. Package/version inspection confirms `com.krishidoc.app`, versionCode 5; launch returned process 19888. ARM64 APK: 54,852,920 bytes, SHA-256 `0b194780dd0c5d296df1e08625d7de54c35865897ef095015193f255f4e5ad05`. ZIP inspection found zero audit assets. This installation/startup check is not a completed native gallery or accuracy test. The build emitted the existing optional Cupertino-font warning; the changed controls use Material icons.

Local evidence (git-ignored): `ml/artifacts/mobile_audit_20260906/manifest.json`, `host_report_before.json`, `host_report_after.json`, and the exported `host_inputs/`. The checkpoint and calibration identity are recorded in the bundled potato metadata; weights stayed unchanged.

1. `python ml/scripts/prepare_mobile_audit.py` recreates the sample and Python reference outputs from the local licensed datasets.
2. In `app/`, run `flutter test test/inference/export_mobile_audit_inputs_test.dart --dart-define=KD_EXPORT_AUDIT=true`.
3. Run `python ml/scripts/evaluate_mobile_preprocessing.py` from the repository root.
4. For native testing only, temporarily bundle `test_assets/mobile_audit/`, build `integration_test/labelled_model_audit_app.dart`, verify the audit package ID, and run it in the foreground. Remove the asset entry before any normal release. The production packaging test deliberately rejects that entry.
5. Finish the native global-model/crop-suggestion evaluation, collect the user's actual failing images with consent, review whole-plot/leaf usability labels, and build an independent agronomist-labelled Nepal field set. Only then choose/retrain a model and recalibrate on a separate calibration set. This diagnostic sample must not become a claimed independent accuracy benchmark.

The revised UI is not a claim that model reliability is solved.
