# Living Project Memory

**Protocol:** updated at every major milestone close (minimum); consulted before any new decision; a recorded decision is changed only by an explicit superseding ADR. This repo copy is authoritative as of Module 1.

## Architecture decisions

Registry: [adr/ADR-INDEX.md](adr/ADR-INDEX.md) (D-00..D-51). Full rationale: the design review meeting and external audit documents (delivered 2026-07-27). Per-module ADR files are written before their module's code.

## Open questions

- Numerals and area units for doses (Devanagari vs Latin digits; ropani/kattha/bigha rendering): field test before dose-bearing content ships. Owner: Agri + UX (D-35 action).
- Starter pack regional variants (Nepal hills vs Indian plains crop mix): decide variant strategy during M1 (audit R2-3).
- Final applicationId + trademark check before store submission (audit L-3): `com.krishidoc.app` is set provisionally in app/android/app/build.gradle.kts.
- ne/hi ARB strings (Module 3) are drafted in the register Agri's review required (बाली, रोग पहिचान, सम्भावना semantics) but remain PENDING the D-06 native agronomist review gate before any release.
- go_router pinned to 15.x while 17.x exists: intentional (resolve on the first quarterly dependency train, D-41), not an oversight.
- RESOLVED (Module 2): `uv` installed via `python -m pip install uv`; backend env managed by `uv sync`, `uv.lock` committed, CI uses `uv sync --frozen`.

## Technical debt

- QualityGate thresholds (minEdgeEnergy 8, luminance 40..220) and the D-16 30ms-per-frame budget are **provisional and unvalidated on hardware**. They need reference-device-lab calibration against real field photos before launch; too strict refuses genuine diseased leaves, too loose defeats the gate. Owner: Perf + Agri.
- History tiles render the raw model label; KB display names replace this when advisory content lands (D-35).

## Lessons encoded in code (do not regress)

- **Blur metric is mean absolute Laplacian, not variance.** The textbook variance recipe assumes full-pixel sampling. Once frames are subsampled for the frame budget, a regular texture (woven mat, mesh screen) can alias so every sampled Laplacian shares a sign, collapsing variance to zero and refusing a perfectly sharp frame. A regression test in packages/capture pins this.
- **Widget tests never drive a live drift database** (Module 5): fake the core_domain ports instead.
- **Stream-driven UI needs two pumps in tests** (Module 7): `pump()` builds the pending frame and only then yields, which is when the stream-delivery microtask runs `setState`. One pump asserts against the previous frame and reads as a product bug when it is test timing. See `_emit` in app/test/capture_test.dart.
- **`find.byType` compares exact runtime types** (Module 7): `FilledButton.icon` builds a private subclass, so `find.byType(FilledButton)` finds nothing. Give such widgets a named Key (e.g. `shutterKey`) and find by key.
- **A corrupted `.dart_tool/pub/workspace_ref.json` (null bytes) crashes the flutter tool** with a JSON FormatException during `pub get` (Module 7, caused by killed background runs). Delete the file and re-run `flutter pub get`.

## Risks (register: implementation plan §14)

R1 KB editorial throughput (top risk) · R2 low-end device budgets · R3 launch model quality · R4 Flutter Web portal bet · R5 OTP SMS cost/abuse · R6 single-region outage · R7 LLM provider change · R8 Play policy friction · R9 bus factor · R10 adoption/retention.

## TODOs (module ladder within milestones M0..M6)

- [x] Module 1: repo foundation and governance (branch `v2`, docs, hygiene CI)
- [x] Module 2: toolchain scaffolds. Native pub workspace (melos deferred: first-party workspaces suffice; revisit on multi-package scripting pain). `packages/core_domain` seeded with decision-anchored types (ResultState D-17, ConsentScope D-31, AppLanguage D-06, Jurisdiction D-21) + tests. Backend FastAPI skeleton: app factory, /healthz, D-27 error envelope with input-sanitized validation errors, request-id middleware, JSON logging (D-38). CI wall: dart format/analyze/purity/test + uv ruff/mypy/pytest jobs. Packages appear only with real content (no empty scaffolds): core_data/api_client arrive with their modules.
- [x] Module 7: crop context and capture experience. core_domain gains Crop + CropCatalog port (lookup tolerates keys from uninstalled packs, falls back to first available). App: CaptureScreen with live coaching from QualityGate, shutter disabled until the frame is worth classifying, remembered crop as a one-tap chip (SettingsKeys.selectedCrop), honest camera-failure state. CameraSession port + FakeCameraSession; the platform `camera` plugin is deliberately NOT added: it can only be verified on hardware and the device lab is still an unmet M0 item. CaptureScreen is built and tested but UNROUTED for the same reason (a route would either crash or show a misleading "allow camera access"); the route lands with the camera implementation. LaunchCropCatalog (tomato/potato/maize) is provisional pending content-workstream and agronomist sign-off.
- [x] Module 6: capture pipeline (`packages/capture`, pure Dart). QualityGate assesses the camera luminance plane directly (no decode) with stride sampling per audit M-4; blur is scored as **mean absolute Laplacian, not variance** (see debt/lesson below); exposure via mean luminance floors. ImageProcessor implements D-12: bake orientation, downscale long edge to 1024, clear all EXIF, re-encode JPEG q85; decoder exceptions are normalised to a typed ImageDecodeException so malformed or hostile bytes render as a retry rather than a crash. Camera UI wiring is deliberately Module 7.
- [x] Module 5: persistence wired into the app. AppServices composition root (production: drift on a background isolate in app documents dir via path_provider + sqlite3_flutter_libs; AppServices.forTest injects port fakes). Riverpod adopted at its minuted trigger (first async state): servicesProvider overridden at root, recentDiagnosesProvider StreamProvider. Language choice persists via SettingsStore and restores on boot (M2 promise closed early, LocaleScope API unchanged). /history route: reactive newest-first list with per-state icons, localized empty/error states; raw model label as stopgap until KB names (D-35). HARD RULE from this module: widget tests NEVER touch a live drift database; fake the core_domain ports (drift + flutter_test fake-async hangs: stream timers re-arm so pumpAndSettle never settles, and db.close() never resolves in the fake zone; each hang eats the 10-minute testWidgets default). Drift stays covered by core_data's pure-Dart suite; a device integration_test can exercise the real seam later.
- [x] Module 4: local persistence (D-10 start of M1). core_domain: DiagnosisRecord/TopPrediction with D-17 invariants enforced at construction (uncertain needs ≥2 predictions, confidence bounded, UTC-only timestamps) + DiagnosisStore/SettingsStore ports. core_data: Drift/SQLite (schemaVersion 1: diagnoses + settings tables, created-at index, enum-by-name + JSON converters), DriftDiagnosisStore with reactive watchRecent, DriftSettingsStore, UUIDv7 IdGenerator. Generated code gitignored (same policy as l10n); build_runner in CI; tests run pure-Dart via NativeDatabase.memory with winsqlite3.dll fallback on Windows and libsqlite3-dev on CI. Lesson recorded: RFC 9562 v7 monotonicity within one millisecond is optional, tests assert timestamp-prefix ordering only.
- [x] Module 3: Flutter app shell. `app/` (Android-only scaffold, applicationId com.krishidoc.app pending L-3, minSdk 23, INTERNET in MAIN manifest with CI guard) + `packages/design_system` (tokens with WCAG-checked contrast, kdLightTheme, sealed DiagnosisPresentation making certainty-free result UI a compile error per D-17, DiagnosisResultView with exhaustive switch). gen-l10n ARB en/ne/hi (generated code gitignored, regenerated by `flutter gen-l10n`); go_router created per app instance (never a singleton: navigation state must not leak between instances/tests); LocaleScope for in-memory language switching (persistence lands in M2 without API change). Home = scrollable ListView + shrink-wrapped grid (fixed-height home layouts were a V1 accessibility finding). 17 tests across 3 suites.
- [ ] Module 4+: per milestone order (offline core loop → sync/identity/consent → advisory/content → chatbot/evals → analytics/research → hardening)

## APIs created

- None yet. Conventions fixed by D-27; endpoint inventory in implementation plan §3.

## Database changes

- Server (Postgres/Alembic): none yet; first migration lands with the identity/sync module.
- Client (Drift, packages/core_data): schemaVersion 1 = `diagnoses` (id UUIDv7 PK, crop_key?, result_state enum-by-name, predictions_json, model_version, image_path?, created_at_ms + desc-read index) and `settings` (key PK, value). Client migrations follow expand-and-contract like the server (D-28).

## Breaking changes

- None. /v1 is additive-only once first published (D-09/D-27).

## Milestone log

- 2026-07-27: Phase 5 audit closed (D-44..D-50 adopted, no critical/high open). Phase 6 plan delivered. D-51: V2 on orphan branch `v2` of existing repo. Module 1 committed.
- 2026-07-27: Module 2 committed. Toolchain deviations recorded: native pub workspaces instead of melos; content-bearing packages only. Local verification: dart analyze clean, 8 Dart tests green; ruff + strict mypy clean, 8 backend tests green at 100% coverage.
- 2026-07-27: Module 7 committed. Crop context and capture coaching live and tested; platform camera and the capture route intentionally deferred to a device-verified module. 71 tests green across five suites.
- 2026-07-27: Module 6 committed. Capture pipeline live; EXIF stripping asserted on raw output bytes with a canary string, closing the V1 finding that farmers' plot GPS was uploaded. 54 tests green across five suites.
- 2026-07-27: Module 5 committed. Language persistence + History screen live; Riverpod in. Cost of the module was the drift/fake-async lesson (three debugging rounds); the fix was architectural (fake the ports in widget tests), now a hard rule above. 36 tests green across four suites; app suite 4s and order-stable.
- 2026-07-27: Module 4 committed. Client schema v1 live with 23 pure-Dart tests (9 store + 14 domain); all four suites green (32 tests total); analyze clean.
- 2026-07-27: Module 3 committed. App shell + design system. Test debugging yielded two durable rules now encoded in code: routers are per-instance (leaked navigation state), and home layouts scroll (lazy-viewport finders exposed the same fixed-height risk UX flagged for font scaling). Full-suite runs verified twice for order stability; analyze clean at fatal-infos.
