import 'model_pack.dart';

/// Auditable contract for the experimental PlantVillage model.
///
/// This is a genuine neural-network artifact, but it is not a production
/// agronomy model. Its lab-photo benchmark has not been validated on Nepal
/// field images, its probabilities are not calibrated for this app, and it
/// has no non-plant class. Therefore every class threshold is 1.0: the model
/// can offer possible matches, but can never produce a confident result.
abstract final class ExperimentalPlantPack {
  static const String modelVersion =
      'experimental-janasunrise-mobilenetv2-pv38-r8bff045b';
  static const String thresholdSetVersion =
      'experimental-possible-match-only-v1';
  static const String artifactSha256 =
      'd7cf3507569f136e8e9bdc787d4a6222661fa6035e65a6176ebe86b63164014b';
  static const String sourceRevision =
      '8bff045b0845394cb4028e8b62cb8f0bf41e3ba7';

  static const int inputWidth = 224;
  static const int inputHeight = 224;
  static const int inputChannels = 3;
  static const int outputCount = 38;

  /// Crops deliberately enabled in the current app catalog.
  ///
  /// The underlying model contains other PlantVillage classes. They remain in
  /// the global tensor contract so a winner from another crop can be rejected,
  /// but they are not advertised as app coverage.
  static const Set<String> enabledCrops = {'tomato', 'potato', 'maize'};

  static const List<String> labelKeys = [
    'apple_apple_scab',
    'apple_black_rot',
    'apple_cedar_apple_rust',
    'apple_healthy',
    'blueberry_healthy',
    'cherry_powdery_mildew',
    'cherry_healthy',
    'maize_cercospora_leaf_spot_gray_leaf_spot',
    'maize_common_rust',
    'maize_northern_leaf_blight',
    'maize_healthy',
    'grape_black_rot',
    'grape_esca_black_measles',
    'grape_leaf_blight_isariopsis_leaf_spot',
    'grape_healthy',
    'orange_haunglongbing_citrus_greening',
    'peach_bacterial_spot',
    'peach_healthy',
    'pepper_bell_bacterial_spot',
    'pepper_bell_healthy',
    'potato_early_blight',
    'potato_late_blight',
    'potato_healthy',
    'raspberry_healthy',
    'soybean_healthy',
    'squash_powdery_mildew',
    'strawberry_leaf_scorch',
    'strawberry_healthy',
    'tomato_bacterial_spot',
    'tomato_early_blight',
    'tomato_late_blight',
    'tomato_leaf_mold',
    'tomato_septoria_leaf_spot',
    'tomato_spider_mites_two_spotted_spider_mite',
    'tomato_target_spot',
    'tomato_yellow_leaf_curl_virus',
    'tomato_mosaic_virus',
    'tomato_healthy',
  ];

  static const Set<int> _healthyIndices = {
    3,
    4,
    6,
    10,
    14,
    17,
    19,
    22,
    23,
    24,
    27,
    37,
  };

  static final Map<String, Set<String>> labelsByCrop = {
    'maize': labelKeys.sublist(7, 11).toSet(),
    'potato': labelKeys.sublist(20, 23).toSet(),
    'tomato': labelKeys.sublist(28, 38).toSet(),
  };

  static final ModelPack global = ModelPack(
    // One global output tensor covers many crops. Crop scope is enforced by
    // ClassificationService.allowedLabelKeys before a result is resolved.
    cropKey: 'plantvillage-global',
    modelVersion: modelVersion,
    thresholdSetVersion: thresholdSetVersion,
    temperature: 1,
    rejectionFloor: 0.20,
    minMargin: 0.10,
    decisionMode: ModelDecisionMode.possibleMatchOnly,
    labels: [
      for (var index = 0; index < labelKeys.length; index++)
        LabelSpec(
          key: labelKeys[index],
          kind: _healthyIndices.contains(index)
              ? LabelKind.healthy
              : LabelKind.disease,
          // Until Nepal field calibration exists, a confident state would be
          // a false product claim. Softmax output is not expected to equal 1.
          threshold: 1,
        ),
    ],
  );

  static ModelPack? forCrop(String cropKey) =>
      enabledCrops.contains(cropKey) ? global : null;

  static Set<String>? allowedLabelsForCrop(String cropKey) =>
      labelsByCrop[cropKey];
}

bool isExperimentalModelVersion(String modelVersion) =>
    modelVersion.startsWith('experimental-');
