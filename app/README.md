# krishidoc_app

The KrishiDoc V2 farmer app (Android-first). See the repo root README for the branch model and `docs/` for decisions.

- Run: `flutter run` (from this directory). `flutter pub get` at the repo root resolves the whole workspace.
- Localization: ARB sources in `lib/l10n/`; generated code lands in `lib/l10n/gen/` (gitignored) via `flutter gen-l10n`. Launch languages en/ne/hi (D-06); farmer-facing strings ship only after the native agronomist review gate (D-35).
- Release builds use a calibrated dual-head EfficientNet-B0 field candidate
  for experimental potato possible matches. Its validity head can refuse an
  unsuitable view, wrong crop, other plant or non-plant input before condition
  ranking. Tomato and maize retain the genuine 38-class PlantVillage TFLite
  model. Neither model is Nepal-field validated, so neither can return a
  confirmed diagnosis or chemical instruction. Debug builds retain
  deterministic sample inference unless started with
  `--dart-define=KRISHIDOC_EXPERIMENTAL_MODEL=true`.
- Camera screens offer **Choose from gallery** through Flutter's system image
  picker, including when camera access is denied. Imports are resized, stripped
  of EXIF metadata, and checked for exposure and blur before disease analysis.
  Reopening capture recovers a pending Android picker selection after process
  reclamation and asks for review before storing a diagnosis.
- Disease scans start in **Auto-detect crop** mode. The existing global model
  suggests tomato, potato or maize; the photo review asks the farmer to confirm
  or correct that crop before routing to the crop's disease model. Ambiguous or
  unsupported suggestions leave the crop unselected. Manual mode remains
  available. Recognition thresholds are provisional and all disease results
  remain experimental possible matches (D-59).
- Weather uses live Open-Meteo forecasts with manual Nepal city selection. The
  Weather screen also compares the next seven days' daily-average temperature
  with sourced FAO EcoCrop ranges for tomato, potato and maize. This is a
  transparent weather-fit estimate, not AI, a field measurement, or a crop,
  planting or yield recommendation (D-57). The crop assistant is a bounded
  en/ne/hi offline reference based on public NARC material, not live generative
  AI.
- Market reads the latest daily wholesale table published by the official
  Kalimati board, preserves each published unit and min/max/average value, and
  keeps the last validated list on the phone for an unavailable refresh. It is
  a wholesale reference, not a real-time exchange, retail quote or farmgate
  price.
- Android: `minSdk 26`, required by the official TensorFlow Lite runtime. The
  CAMERA and INTERNET permissions live in the main manifest.
