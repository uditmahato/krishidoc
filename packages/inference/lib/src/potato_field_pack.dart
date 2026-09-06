import 'model_pack.dart';

/// Auditable app contract for the field-trained potato candidate.
///
/// The model has a calibrated validity head and three potato condition
/// classes, but it has not passed an independently labelled Nepal field set.
/// It is therefore structurally restricted to possible matches. The separate
/// three-signal acceptance gate is implemented by the mobile model adapter.
abstract final class PotatoFieldResearchPack {
  static const String modelVersion =
      'experimental-potato-efficientnet-b0-9e1854e4dabf';
  static const String thresholdSetVersion =
      'calibration-fe4f0715b3fc-three-signal-v1';
  static const String artifactSha256 =
      '90875fad84d33e06884466030e2dfe18fedc2fd89b5e71a9d61835b837891c69';
  static const String checkpointSha256 =
      '9e1854e4dabf868622abc5f21fea6cc13680c24bcdaa985560832e3843ed520a';
  static const String calibrationSha256 =
      'fe4f0715b3fca7a4ac9c62cc40d6265d628e5fd471272beb84ef453d32d5aefa';
  static const String manifestSha256 =
      '8d091b81284885c2acbba46b07e41873bf2a2d0e6af5e650ec0320aaec8d4177';

  static const int inputWidth = 224;
  static const int inputHeight = 224;
  static const int inputChannels = 3;
  static const int validityOutputCount = 5;
  static const int conditionOutputCount = 3;

  static const List<String> validityLabelKeys = [
    'usable_target_leaf',
    'unsuitable_target_crop_view',
    'wrong_crop_leaf',
    'other_plant',
    'non_plant',
  ];

  static const List<String> conditionLabelKeys = [
    'potato_early_blight',
    'potato_late_blight',
    'potato_healthy',
  ];

  static const double validityTemperature = 0.653050816470007;
  static const double conditionTemperature = 0.6482262752865812;
  static const double validityProbabilityMin = 0.5;
  static const double conditionProbabilityMin = 0.3519576858617407;
  static const double conditionEnergyMax = -0.061798970861053196;

  static final ModelPack pack = ModelPack(
    cropKey: 'potato',
    modelVersion: modelVersion,
    thresholdSetVersion: thresholdSetVersion,
    temperature: conditionTemperature,
    rejectionFloor: conditionProbabilityMin,
    minMargin: 0,
    decisionMode: ModelDecisionMode.possibleMatchOnly,
    labels: const [
      LabelSpec(
        key: 'potato_early_blight',
        kind: LabelKind.disease,
        threshold: conditionProbabilityMin,
      ),
      LabelSpec(
        key: 'potato_late_blight',
        kind: LabelKind.disease,
        threshold: conditionProbabilityMin,
      ),
      LabelSpec(
        key: 'potato_healthy',
        kind: LabelKind.healthy,
        threshold: conditionProbabilityMin,
      ),
    ],
  );
}
