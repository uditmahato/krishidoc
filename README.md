# KrishiDoc

An Android-first farming companion for Nepal, built with Flutter. KrishiDoc
combines experimental on-device plant disease recognition with local farm
records, multilingual crop guidance, weather forecasts and Kalimati wholesale
market prices.

The app is a working research prototype, not a certified diagnostic service.
Plant predictions are tentative visual matches and may be wrong. Independent
Nepal field validation is still required before production diagnosis claims.

## Features

| Area | Current implementation |
| --- | --- |
| Plant photos | Camera capture and gallery selection, photo review, orientation correction, EXIF removal and image-quality checks. |
| Disease recognition | On-device TensorFlow Lite inference for potato, tomato and maize, with crop-scoped results and refusal of some unsupported inputs. |
| Potato research model | Dual-head EfficientNet-B0 checks image suitability and ranks early blight, late blight or healthy appearance. V3 is the default; V7 is an explicit test-build option. |
| Crop selection | Automatic suggestions require confirmation or correction. Manual selection remains available and is recommended for V7 potato testing. |
| Languages | English, Nepali and Hindi interfaces. Localized agronomy content remains subject to native-language and expert review. |
| Crop assistant | Bounded, offline multilingual reference guidance using public NARC material and crop context. It is not a live generative AI chatbot. |
| Weather | Open-Meteo forecasts for manually selected Nepal cities, plus a seven-day temperature-fit comparison for the three supported crops. |
| Market | Official Kalimati daily wholesale prices, published units and min/max/average values, with source timing and a last-validated local cache. |
| Farm records | On-device diagnosis history, photo observations and farm tasks backed by local SQLite storage. |

Local records, reference guidance and bundled disease inference can work without
a network connection. Refreshing weather and market data requires internet
access. Weather-fit comparisons are not planting or yield recommendations;
Kalimati values are not live retail or farmgate quotes.

## Model status and limitations

Normal release builds use the V3 potato research model. Tomato, maize and
automatic crop suggestions use the existing global PlantVillage-based model.
Debug builds use deterministic sample inference unless explicitly enabled.

V7 was trained on an NVIDIA RTX 4060 GPU and integrated into a separate Android
test app. Its native TensorFlow Lite execution uses two CPU threads, not a
mobile GPU delegate. It has **not** replaced V3 by default: broader evaluation
found excessive refusals, and early/late disease confusions remain.

The latest Realme RMX3741 diagnostic completed 79 photos with zero processing
errors and no class or acceptance-gate disagreements between the phone and the
exported model using matching inputs. Of 53 labelled known-condition potato
photos, the model returned 42 correct possible matches, five wrong matches and
six refusals. Seven of the correct matches separately failed the app's gallery
quality check. These are previously consumed diagnostic photos, not a fresh
accuracy benchmark or Nepal validation set.

Automatic crop identification did not suggest potato for any photo in that
diagnostic. **Select Potato manually when testing V7.** Successful conversion
does not mean the model is accurate enough for field deployment.

- [V7 mobile integration and device report](docs/POTATO_V7_MOBILE_TEST_2026-09-07.md)
- [V7 training and evaluation report](docs/POTATO_FIELD_V7_EXPERIMENT_2026-09-07.md)
- [ML pipeline and dataset documentation](ml/README.md)

No model result is a confirmed diagnosis. Classifier output must not be used to
generate pesticide doses, mixtures or waiting-period instructions.

## Technology

- **Mobile:** Flutter 3.32.7, Dart 3.8, Riverpod, GoRouter and ARB localization.
- **Local data:** Drift and SQLite, with device-local photo storage.
- **Inference:** TensorFlow Lite through `tflite_flutter`, isolated native
  execution, model identity checks and calibrated acceptance/refusal gates.
- **ML tooling:** Python, PyTorch, timm, ONNX and ONNX Runtime; dataset manifests,
  duplicate/group audits, controlled fine-tuning and export-parity verification.
- **Backend foundation:** FastAPI and Pydantic, device identity/token endpoints,
  request IDs, structured logging and idempotency. Current adapters are
  in-memory; production PostgreSQL persistence is not implemented.
- **Verification:** Dart/Flutter tests, Python tests, static analysis and GitHub
  Actions checks for formatting, repository hygiene and secrets.

## Repository layout

```text
app/                     Flutter app, Android project and bundled models
packages/
  core_domain/           Domain types and contracts
  core_data/             Local persistence
  capture/               Photo preparation and capture-quality logic
  inference/             Model packs, calibration and result resolution
  design_system/         Shared theme and UI components
backend/                 FastAPI service foundation and tests
ml/                      Dataset policies, training, evaluation and export tools
docs/                    Architecture decisions, product history and reports
.github/workflows/       Continuous integration
```

Raw datasets, checkpoints, local evaluation artifacts and generated APKs are
git-ignored. The app's explicitly bundled model assets and their metadata are
versioned. Follow the model notices before redistributing them.

## Run the Android app

### Prerequisites

- Flutter **3.32.7** with its bundled Dart SDK; this is the CI-pinned version.
- Android SDK platform 36, compatible Java/Gradle tooling and NDK
  `27.0.12077973` as configured in the Android project.
- An Android device or emulator running Android 8.0/API 26 or later.
- USB debugging enabled for a physical Android device.

From a fresh clone of the development branch:

```sh
git clone --branch main https://github.com/uditmahato/krishidoc.git
cd krishidoc
flutter pub get
cd packages/core_data
dart run build_runner build --delete-conflicting-outputs
cd ../../app
flutter gen-l10n
flutter devices
flutter run --dart-define=KRISHIDOC_EXPERIMENTAL_MODEL=true
```

Without `KRISHIDOC_EXPERIMENTAL_MODEL=true`, a normal debug launch uses sample
inference for deterministic development. Normal release builds enable the
bundled experimental models automatically.

### V7 potato test build

Use a branch containing the V7 integration. From `app/`:

```sh
flutter run --release --target lib/main_potato_v7.dart --dart-define=KRISHIDOC_POTATO_V7=true
```

This target installs **KrishiDoc V7 Test** under `com.krishidoc.app.v7test`,
separate from `com.krishidoc.app`. It shows a **V7 RESEARCH** banner and does not
share the original app's saved records. Both the target and the define are
required. Choose Potato manually, then capture or select a photo.

To build an APK instead:

```sh
flutter build apk --release --target-platform android-arm64 --target lib/main_potato_v7.dart --dart-define=KRISHIDOC_POTATO_V7=true
```

The APK is generated under `app/build/app/outputs/flutter-apk/`. Release builds
currently use the project's development signing configuration; they are not
store-ready releases. iOS build and physical-device verification are not
provided by the current Android-first project.

## Development and testing

After dependency resolution and code generation:

```sh
# From the repository root
flutter analyze --fatal-infos

# From app/
flutter test
flutter test test/inference/potato_field_tflite_classifier_test.dart test/model_audit_packaging_test.dart --dart-define=KRISHIDOC_POTATO_V7=true
```

Run `dart test` in `packages/core_domain`, `packages/core_data`,
`packages/capture` and `packages/inference`, and `flutter test` in
`packages/design_system`. The [CI workflow](.github/workflows/ci.yml) documents
the complete shared-package and backend checks.

For backend development, install Python 3.12 or later and `uv`. Set
`KRISHIDOC_TOKEN_SIGNING_KEY` in your shell to a securely generated secret of at
least 32 characters; startup deliberately fails without it. Do not commit this
value. Then run from `backend/`:

```sh
uv sync --frozen
uv run uvicorn krishidoc.main_api:create_app --factory --reload
uv run pytest -q
```

Training uses a separate Python 3.12/CUDA environment. See the
[ML instructions](ml/README.md) before downloading data or running an
experiment. Completed frozen runs must not be overwritten or reused as fresh
evaluation evidence. Conversion dependencies are isolated from training.

## Branches and contribution

`main` is the active development trunk and GitHub default; feature PRs target
it. The V2 application was promoted to `main` on 2026-09-07 without discarding
either branch's history. `v2` retains the pre-promotion development snapshot.
Legacy V1 is preserved in `dev` and `codex/legacy-main-before-v2-20260907`.
See [the branch promotion decision](docs/adr/ADR-0061-main-development-trunk.md).

See [CONTRIBUTING.md](CONTRIBUTING.md), the
[architecture decision index](docs/adr/ADR-INDEX.md) and
[living project memory](docs/PROJECT_MEMORY.md) before changing product,
privacy, model or safety behaviour. Some older reports describe historical
states; use their dates and explicit superseding notes.

## Privacy, security and attribution

- Photo preparation strips EXIF metadata before analysis and storage in the
  reviewed flow. Model inference runs on the device.
- Do not commit credentials, signing keys, downloaded datasets or personal
  farm photos. Ignored local files are not a substitute for a security review.
- Legacy V1 history contains an exposed Google API key that must be treated as
  compromised and rotated by its owner. Do not reuse credentials from old branches.
- Models and datasets have their own licences and restrictions. Read
  [model attribution notices](app/assets/models/THIRD_PARTY_NOTICES.txt) and the
  [dataset registries](ml/datasets/) before use or redistribution.
- A repository-wide software licence has not been added on this branch; do not
  assume that model or dataset licences also license the application code.
