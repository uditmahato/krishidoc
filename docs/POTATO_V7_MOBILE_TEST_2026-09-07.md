# V7 potato model: mobile integration and physical-device test

## Outcome

V7 is integrated as an explicit **test build**, not promoted over V3. The full
**KrishiDoc V7 Test** app was installed and cold-launched on the connected Realme
RMX3741. Its package is `com.krishidoc.app.v7test`; the original
`com.krishidoc.app` and its data remain intact. The normal camera/gallery and
result flows use V7 when Potato is selected. An orange **V7 RESEARCH** banner
distinguishes this build. Tomato, maize and automatic crop suggestions are unchanged.

**Select Potato manually before testing.** The existing global crop-suggestion
model suggested potato for none of the 79 diagnostic images. Among the 56
potato-labelled photos (including three uncertain healthy-looking controls), it
suggested another supported crop for 10 and offered no suggestion for 46. Crop
confirmation/correction remains essential; this is not an automatic-crop fix.

The separate `com.krishidoc.app.v7audit` release app completed **79/79** original
photos through the actual Android TFLite runtime, production Dart photo
preparation, gallery quality assessment and classification/refusal code.
There were **zero processing errors**. This is a native model/pipeline test,
not a claim that OS camera shutter/gallery picker taps were automated or that
live camera photos were collected. The full app launch was verified separately.

## Model identity and conversion

- Checkpoint: `ad3b3c0b6ab9cb78f5999ba4631605aa48d8f344491772fbff69889c4669c9f8`.
- Calibration: `3c1881348e472816f0893d0a85bc86f987733ce73752c6cdd6699762212860a4`.
- Float32 TFLite: `f3119558c3c4c43522a45794341546fdaffef65e5c5c57272a557d23800ea099`, 16,042,304 bytes.
- Input: float32 NHWC `[1,224,224,3]`; validity output `[1,5]`, condition output `[1,3]`.
- Default V3 asset remains `90875fad84d33e06884466030e2dfe18fedc2fd89b5e71a9d61835b837891c69`.

Conversion used an isolated `.venv-mobile`; the GPU training environment and
frozen training run were not modified. The converter's unavailable generic
downloaded test fixture was replaced with deterministic synthetic conversion
probes, not training images or calibration data. All failed conversion attempts
were preserved. The exported output ordering and names were canonicalized and
then verified numerically; no accuracy-driven weight or threshold changes.

Host ONNX/TFLite parity passed 16 probes (five synthetic plus 11 existing
app-prepared Google photo tensors), maximum logit error 0.000223. The Android
test additionally checked all 79 fixed reference PNGs: maximum error 0.000218.
Replaying the **actual Dart-prepared original-photo tensors** in ONNX gave
maximum error **0.000210**, below the predeclared 0.001 tolerance, with **zero
validity/condition argmax, acceptance-gate or gallery-quality disagreements**.
This establishes faithful conversion/execution, not good field accuracy.

## Diagnostic outcomes

Selection was deterministic, not prediction-filtered: 15 photos per TARI
condition by SHA, all 11 existing Google diagnostics/controls, 15 usable
unknown-condition potato leaves and eight other plants. All were previously
consumed evaluation evidence. They are neither fresh validation nor a Nepal set.
The 15 early-blight TARI photos are not claimed to be 15 independent plants;
the larger source holdout itself contains only 13 early-blight proxy groups.

“Accepted” below means a tentative possible match, never a confident diagnosis.
Raw correctness is the highest condition score before the refusal gate.

| Group | Photos | Raw correct | Correct possible match | Wrong possible match | Refused |
| --- | ---: | ---: | ---: | ---: | ---: |
| TARI selected early/late/healthy | 45 | 42 | 38 | 3 | 4 |
| Google disease photos | 8 | 4 | 4 | 2 | 2 |
| All labelled known potato conditions | 53 | 46 | 42 | 5 | 6 |
| Unsupported potato conditions | 15 | N/A | N/A | 0 | 15 |
| Other plants | 8 | N/A | N/A | 0 | 8 |
| Unverified healthy-looking Google controls | 3 | Not scored | Not scored | Not scored | 3 |

| Known condition | Photos | Raw correct | Correct possible match | Wrong possible match | Refused |
| --- | ---: | ---: | ---: | ---: | ---: |
| Early blight | 19 | 14 | 12 | 3 | 4 |
| Late blight | 19 | 17 | 17 | 2 | 0 |
| Healthy, excluding uncertain controls | 15 | 15 | 13 | 0 | 2 |

Seven photos failed the gallery quality check. The audit intentionally still
scored them to expose model behaviour; the real UI would request another photo.
After accounting for this quality gate, the 53 labelled known photos produced
35 correct and five wrong possible matches, six model refusals and seven
quality rejections. **Do not present 42/53 as end-to-end UI success.** No accepted
false-healthy result occurred in this small selected set, but five accepted
early/late errors remain. The broader V7 experiment still rejects default
promotion because of excessive refusals on prior sources.

The five wrong possible matches are fixture IDs **1, 3, 7** (TARI early blight
reported as late blight) and **50, 52** (Google `lb02.jpg` and `lb04.jpg`, late
blight reported as early blight). All five passed the gallery quality check.
The actual mobile pipeline includes orientation handling, maximum-edge-1024
resizing and JPEG re-encoding before model resizing. Its scores must not be
silently substituted for the earlier training-pipeline benchmark; the matched
Dart-tensor replay above isolates native conversion from those input changes.

## Performance and scope

On this Realme, the potato interpreter used **two CPU threads**, not a GPU
delegate. Previous training used the RTX 4060 GPU; those are separate stages.
First load plus inference measured 377 ms; the following 78 invocations had
median 624 ms, p95 738 ms and maximum 784 ms. These include isolate dispatch but
exclude photo preprocessing, crop suggestion and UI work. The cold sample being
faster than later samples is observed, not normalized away; this sequential
mixed-model workload is not a controlled thermal benchmark. The entire audit
took approximately 202 seconds, including extra reference inferences.

Both model assets are currently bundled; selecting V7 does not load V3 into the
potato interpreter, but packaging both adds approximately 16 MB of uncompressed
model storage. Test fixtures are external to the APK and absent from both APK
asset inventories. Android build uses release mode with the repository's
existing debug signing configuration: this is a sideloaded test, not store release.

## Reproduction and evidence

Artifacts are under `ml/artifacts/potato_v7_mobile_20260907/`:

- `conversion_verification.json`: host conversion evidence.
- `v7_inputs/manifest.json`: frozen 79-photo fixture, SHA `df12ce9e5dc57de2aefb855cc00a6a255fa378cf1f914803a0264c2b732083d6`.
- `host_inputs/`: tensors exported using the actual Dart pipeline.
- `native_audit.json`: untouched phone report, SHA `e3c764cc6986fecdccfa6859f2513691a27949bc1ba972f61370ef5f42d2a36b`.
- `native_summary.json`: per-group results, parity and timings.
- `krishidoc-v7-audit.apk`: executed audit APK, SHA `52ac82f9f2f59826c5c28f282d857b6e44866134771cef94ab068c6b8d635f0f`.
- `krishidoc-v7-test.apk`: first installed full test build; final metadata-bearing build is recorded below.

Build the full test app from `app/`:

```powershell
flutter build apk --release --target-platform android-arm64 --target lib/main_potato_v7.dart --dart-define=KRISHIDOC_POTATO_V7=true
```

Build the isolated diagnostic target with
`--target integration_test/labelled_model_audit_v7_app.dart`, the V7 define and
`--dart-define=KD_AUDIT_EXTERNAL=true`. Place the frozen fixture contents in
`/sdcard/Android/data/com.krishidoc.app.v7audit/files/v7_inputs/`.
The app writes its report in that package's `files/` directory. Refresh Flutter
plugin registration by allowing pub resolution during builds: the initial
`--no-pub` release attempt encountered a stale integration-test registrant.

Full app regression suite: **232 passed**, one opt-in exporter skipped; the
exporter was separately enabled and passed on all 79 photos. V7-specific model
and packaging checks, final static analysis and final installation are recorded
in the completion note below. No training, calibration, default promotion,
Git commit, PR update or iOS test was performed in this integration task.

## Follow-up priorities

1. Replace or separately validate the global crop-identification stage; manual
   Potato selection currently bypasses its poor suggestions. Do not claim that
   fine-tuning the potato condition model fixes crop recognition.
2. Investigate the five accepted early/late confusions and sensitivity to the
   actual app's resize/JPEG pipeline using development data, not by tuning to
   these now-consumed results.
3. Review the seven quality vetoes and obtain independent expert-labelled
   Nepal field photos before making a deployment-quality claim. Do not relax
   the frozen model thresholds merely to make this diagnostic look better.

## Completion note

Final `krishidoc-v7-test-verified.apk` SHA:
`511e8d192f531de06216c45dcd64272552c18755d71d36b67bf04ac3a487afa1`.
Installed successfully with `adb install -r` and launched on the Realme. Its
embedded V7 model SHA was reverified, and its metadata includes the completed
79-photo native validation receipt. The initial full app APK is retained as a
separate artifact; no app data was cleared.

Final V7-specific model/packaging tests: **9 passed**. Static analysis with
`--fatal-infos` passed after correcting a dangling documentation comment. Full
default-mode regression suite: **232 passed**, one opt-in test skipped; that
exporter separately passed when enabled. Four new ML conversion/audit scripts
pass Ruff; `git diff --check` passes. The release build still emits the existing
Cupertino font-family packaging warning; this task did not resolve or visually
verify those icons. No assertion of completely warning-free UI certification.
