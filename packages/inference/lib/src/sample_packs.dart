import 'model_pack.dart';

/// Stand-in model packs for the three launch crops (D-49).
///
/// These go through the real [ModelPack.parse], not a shortcut constructor, so
/// the sample path exercises the same manifest validation a shipped pack will:
/// the label-count minimum, the range checks, and the rule that a rejection
/// floor at or below chance level is refused because it could never fire.
///
/// Every `modelVersion` begins `sample-`, which is the marker the app keys its
/// permanent sample-data notice off. The label keys are plausible and are NOT
/// agronomist reviewed; display names come from the knowledge base (D-35), so
/// nothing here is ever shown to a farmer as text.
///
/// Calibration constants are deliberately ordinary rather than flattering.
/// Thresholds ship with the model (D-18), and picking generous ones here would
/// train us to expect a confidence the real model has to earn.
abstract final class SamplePacks {
  static const String _tomato = '''
{
  "cropKey": "tomato",
  "modelVersion": "sample-tomato-v0",
  "thresholdSetVersion": "sample-ts-v0",
  "temperature": 1.4,
  "minMargin": 0.10,
  "labels": [
    {"key": "tomato_late_blight", "kind": "disease", "threshold": 0.72},
    {"key": "tomato_early_blight", "kind": "disease", "threshold": 0.72},
    {"key": "tomato_leaf_mold", "kind": "disease", "threshold": 0.75},
    {"key": "tomato_septoria_leaf_spot", "kind": "disease", "threshold": 0.75},
    {"key": "tomato_bacterial_spot", "kind": "disease", "threshold": 0.75},
    {"key": "tomato_healthy", "kind": "healthy", "threshold": 0.80}
  ]
}
''';

  static const String _potato = '''
{
  "cropKey": "potato",
  "modelVersion": "sample-potato-v0",
  "thresholdSetVersion": "sample-ts-v0",
  "temperature": 1.4,
  "minMargin": 0.10,
  "labels": [
    {"key": "potato_late_blight", "kind": "disease", "threshold": 0.72},
    {"key": "potato_early_blight", "kind": "disease", "threshold": 0.72},
    {"key": "potato_healthy", "kind": "healthy", "threshold": 0.80}
  ]
}
''';

  static const String _maize = '''
{
  "cropKey": "maize",
  "modelVersion": "sample-maize-v0",
  "thresholdSetVersion": "sample-ts-v0",
  "temperature": 1.4,
  "minMargin": 0.10,
  "labels": [
    {"key": "maize_northern_leaf_blight", "kind": "disease", "threshold": 0.72},
    {"key": "maize_common_rust", "kind": "disease", "threshold": 0.72},
    {"key": "maize_gray_leaf_spot", "kind": "disease", "threshold": 0.75},
    {"key": "maize_healthy", "kind": "healthy", "threshold": 0.80}
  ]
}
''';

  static const Map<String, String> _manifests = {
    'tomato': _tomato,
    'potato': _potato,
    'maize': _maize,
  };

  /// The sample pack for [cropKey], or null when that crop has none.
  ///
  /// Returning null rather than falling back to another crop is deliberate: a
  /// tomato pack answering a maize photo is exactly the silent wrong answer
  /// this project exists to avoid. Callers must handle absent coverage.
  static ModelPack? forCrop(String cropKey) {
    final manifest = _manifests[cropKey];
    return manifest == null ? null : ModelPack.parse(manifest);
  }

  static Iterable<String> get coveredCrops => _manifests.keys;
}
