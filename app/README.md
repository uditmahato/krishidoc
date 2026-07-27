# krishidoc_app

The KrishiDoc V2 farmer app (Android-first). See the repo root README for the branch model and `docs/` for decisions.

- Run: `flutter run` (from this directory). `flutter pub get` at the repo root resolves the whole workspace.
- Localization: ARB sources in `lib/l10n/`; generated code lands in `lib/l10n/gen/` (gitignored) via `flutter gen-l10n`. Launch languages en/ne/hi (D-06); farmer-facing strings ship only after the native agronomist review gate (D-35).
- Debug builds expose a "UI preview" entry on Home showcasing the three diagnosis result states (D-17).
- Android: `minSdk 23` (D-14) and the INTERNET permission lives in the MAIN manifest, guarded by CI (a V1 regression).
