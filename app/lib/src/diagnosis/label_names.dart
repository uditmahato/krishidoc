import '../../l10n/gen/app_localizations.dart';

/// Farmer-facing names for every class enabled by the experimental pack.
/// Unknown/sample keys still degrade to readable English during development;
/// no raw snake-case model key is shown.
String localizedLabelName(
  AppLocalizations l10n,
  String labelKey, {
  String? cropKey,
}) => switch (labelKey) {
  'maize_cercospora_leaf_spot_gray_leaf_spot' => l10n.diseaseMaizeGrayLeafSpot,
  'maize_common_rust' => l10n.diseaseMaizeCommonRust,
  'maize_northern_leaf_blight' => l10n.diseaseMaizeNorthernLeafBlight,
  'maize_healthy' => l10n.diseaseMaizeHealthy,
  'potato_early_blight' => l10n.diseasePotatoEarlyBlight,
  'potato_late_blight' => l10n.diseasePotatoLateBlight,
  'potato_healthy' => l10n.diseasePotatoHealthy,
  'tomato_bacterial_spot' => l10n.diseaseTomatoBacterialSpot,
  'tomato_early_blight' => l10n.diseaseTomatoEarlyBlight,
  'tomato_late_blight' => l10n.diseaseTomatoLateBlight,
  'tomato_leaf_mold' => l10n.diseaseTomatoLeafMold,
  'tomato_septoria_leaf_spot' => l10n.diseaseTomatoSeptoria,
  'tomato_spider_mites_two_spotted_spider_mite' =>
    l10n.diseaseTomatoSpiderMites,
  'tomato_target_spot' => l10n.diseaseTomatoTargetSpot,
  'tomato_yellow_leaf_curl_virus' => l10n.diseaseTomatoYellowLeafCurlVirus,
  'tomato_mosaic_virus' => l10n.diseaseTomatoMosaicVirus,
  'tomato_healthy' => l10n.diseaseTomatoHealthy,
  _ => _readableFallback(labelKey, cropKey: cropKey),
};

String _readableFallback(String labelKey, {String? cropKey}) {
  var key = labelKey;
  // Labels are prefixed with their crop, which the screen already states, so
  // repeating it reads as stuttering: "Tomato: Tomato late blight".
  if (cropKey != null && key.startsWith('${cropKey}_')) {
    key = key.substring(cropKey.length + 1);
  }
  final words = key.split('_').where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return labelKey;
  return [
    words.first.isEmpty
        ? words.first
        : words.first[0].toUpperCase() + words.first.substring(1),
    ...words.skip(1),
  ].join(' ');
}
