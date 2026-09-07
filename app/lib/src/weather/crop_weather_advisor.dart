import 'dart:math' as math;

import 'package:core_domain/core_domain.dart';

import 'weather_models.dart';

/// A broad temperature profile published by FAO EcoCrop.
///
/// These values are not a Nepal field calibration. They are intentionally
/// kept beside their source and version so a future agronomy review can replace
/// them without hiding a rule change inside presentation code.
final class CropWeatherProfile {
  const CropWeatherProfile({
    required this.cropKey,
    required this.preferredMinimumC,
    required this.preferredMaximumC,
    required this.absoluteMinimumC,
    required this.absoluteMaximumC,
    required this.sourceUrl,
  });

  final String cropKey;
  final double preferredMinimumC;
  final double preferredMaximumC;
  final double absoluteMinimumC;
  final double absoluteMaximumC;
  final Uri sourceUrl;
}

enum CropWeatherFit { favorable, mixed, weak, insufficientData }

enum CropTemperatureDirection { mostlyPreferred, cooler, warmer, variable }

final class CropWeatherAssessment {
  const CropWeatherAssessment({
    required this.crop,
    required this.profile,
    required this.fit,
    required this.direction,
    required this.preferredDays,
    required this.outsideAbsoluteDays,
    required this.forecastDays,
  });

  final Crop crop;
  final CropWeatherProfile profile;
  final CropWeatherFit fit;
  final CropTemperatureDirection direction;
  final int preferredDays;
  final int outsideAbsoluteDays;
  final int forecastDays;
}

/// A transparent comparison derived from the already-visible city forecast.
///
/// Rain, wind and storms are factual context. They are deliberately excluded
/// from crop fit because the cited crop rainfall ranges are annual, while this
/// input covers seven days and knows nothing about drainage or irrigation.
final class CropWeatherOutlook {
  const CropWeatherOutlook({
    required this.assessments,
    required this.unsupportedCropKeys,
    required this.forecastDays,
    required this.totalRainMm,
    required this.maximumWindSpeedKmh,
    required this.thunderstormDays,
  });

  final List<CropWeatherAssessment> assessments;
  final List<String> unsupportedCropKeys;
  final int forecastDays;
  final double totalRainMm;
  final double maximumWindSpeedKmh;
  final int thunderstormDays;

  bool get hasEnoughForecast => forecastDays >= CropWeatherAdvisor.minimumDays;
}

/// Compares forecast daily-average temperature with FAO EcoCrop profiles.
///
/// This is a small deterministic planning aid, not an AI model and not a crop,
/// planting, yield, irrigation, treatment or market recommendation.
final class CropWeatherAdvisor {
  const CropWeatherAdvisor();

  static const int minimumDays = 3;
  static const String methodVersion = 'fao-ecocrop-temperature-v1';
  static const String sourceName = 'FAO EcoCrop';

  static final Map<String, CropWeatherProfile> profiles = {
    'tomato': CropWeatherProfile(
      cropKey: 'tomato',
      preferredMinimumC: 20,
      preferredMaximumC: 27,
      absoluteMinimumC: 7,
      absoluteMaximumC: 35,
      sourceUrl: Uri.parse(
        'https://ecocrop.apps.fao.org/ecocrop/srv/en/dataSheet?id=1379',
      ),
    ),
    'potato': CropWeatherProfile(
      cropKey: 'potato',
      preferredMinimumC: 15,
      preferredMaximumC: 25,
      absoluteMinimumC: 7,
      absoluteMaximumC: 30,
      sourceUrl: Uri.parse(
        'https://ecocrop.apps.fao.org/ecocrop/srv/en/dataSheet?id=1971',
      ),
    ),
    'maize': CropWeatherProfile(
      cropKey: 'maize',
      preferredMinimumC: 18,
      preferredMaximumC: 33,
      absoluteMinimumC: 10,
      absoluteMaximumC: 47,
      sourceUrl: Uri.parse(
        'https://ecocrop.apps.fao.org/ecocrop/srv/en/dataSheet?id=2175',
      ),
    ),
  };

  CropWeatherOutlook assess({
    required WeatherSnapshot snapshot,
    required Iterable<Crop> crops,
  }) {
    final days = snapshot.daily.where(_isUsableDay).take(7).toList();
    final assessments = <CropWeatherAssessment>[];
    final unsupported = <String>[];

    for (final crop in crops) {
      final profile = profiles[crop.key];
      if (profile == null) {
        unsupported.add(crop.key);
        continue;
      }
      assessments.add(_assessCrop(crop, profile, days));
    }

    return CropWeatherOutlook(
      assessments: List.unmodifiable(assessments),
      unsupportedCropKeys: List.unmodifiable(unsupported),
      forecastDays: days.length,
      totalRainMm: days.fold(0, (total, day) => total + day.precipitationSumMm),
      maximumWindSpeedKmh: days.fold(
        0,
        (maximum, day) => math.max(maximum, day.maximumWindSpeedKmh),
      ),
      thunderstormDays: days
          .where((day) => day.condition == WeatherCondition.thunderstorm)
          .length,
    );
  }

  CropWeatherAssessment _assessCrop(
    Crop crop,
    CropWeatherProfile profile,
    List<DailyWeatherForecast> days,
  ) {
    if (days.length < minimumDays) {
      return CropWeatherAssessment(
        crop: crop,
        profile: profile,
        fit: CropWeatherFit.insufficientData,
        direction: CropTemperatureDirection.variable,
        preferredDays: 0,
        outsideAbsoluteDays: 0,
        forecastDays: days.length,
      );
    }

    var preferred = 0;
    var cooler = 0;
    var warmer = 0;
    var outsideAbsolute = 0;
    for (final day in days) {
      final mean = (day.minimumTemperatureC + day.maximumTemperatureC) / 2;
      if (mean < profile.absoluteMinimumC || mean > profile.absoluteMaximumC) {
        outsideAbsolute++;
      }
      if (mean < profile.preferredMinimumC) {
        cooler++;
      } else if (mean > profile.preferredMaximumC) {
        warmer++;
      } else {
        preferred++;
      }
    }

    final fit = outsideAbsolute > 0 || preferred * 7 < days.length * 3
        ? CropWeatherFit.weak
        : preferred * 7 >= days.length * 5
        ? CropWeatherFit.favorable
        : CropWeatherFit.mixed;
    final direction = preferred * 2 >= days.length
        ? CropTemperatureDirection.mostlyPreferred
        : cooler > warmer
        ? CropTemperatureDirection.cooler
        : warmer > cooler
        ? CropTemperatureDirection.warmer
        : CropTemperatureDirection.variable;

    return CropWeatherAssessment(
      crop: crop,
      profile: profile,
      fit: fit,
      direction: direction,
      preferredDays: preferred,
      outsideAbsoluteDays: outsideAbsolute,
      forecastDays: days.length,
    );
  }

  static bool _isUsableDay(DailyWeatherForecast day) =>
      day.minimumTemperatureC.isFinite &&
      day.maximumTemperatureC.isFinite &&
      day.minimumTemperatureC <= day.maximumTemperatureC &&
      day.precipitationSumMm.isFinite &&
      day.precipitationSumMm >= 0 &&
      day.maximumWindSpeedKmh.isFinite &&
      day.maximumWindSpeedKmh >= 0;
}
