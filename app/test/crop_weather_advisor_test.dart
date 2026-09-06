import 'package:core_domain/core_domain.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/weather/weather.dart';

void main() {
  const advisor = CropWeatherAdvisor();
  const crops = [Crop('tomato'), Crop('potato'), Crop('maize')];

  test('cool forecast favors the potato temperature range transparently', () {
    final outlook = advisor.assess(
      snapshot: _snapshot(List.filled(7, 16)),
      crops: crops,
    );

    expect(outlook.hasEnoughForecast, isTrue);
    expect(_for(outlook, 'potato').fit, CropWeatherFit.favorable);
    expect(_for(outlook, 'potato').preferredDays, 7);
    expect(_for(outlook, 'tomato').fit, CropWeatherFit.weak);
    expect(_for(outlook, 'maize').fit, CropWeatherFit.weak);
  });

  test('warm forecast favors maize without calling it a planting decision', () {
    final outlook = advisor.assess(
      snapshot: _snapshot(List.filled(7, 30)),
      crops: crops,
    );

    expect(_for(outlook, 'maize').fit, CropWeatherFit.favorable);
    expect(_for(outlook, 'tomato').fit, CropWeatherFit.weak);
    expect(_for(outlook, 'potato').fit, CropWeatherFit.weak);
  });

  test('overlapping ranges permit several favorable crops', () {
    final outlook = advisor.assess(
      snapshot: _snapshot(List.filled(7, 23)),
      crops: crops,
    );

    expect(
      outlook.assessments.map((assessment) => assessment.fit),
      everyElement(CropWeatherFit.favorable),
    );
  });

  test('three or four preferred days produce a mixed label', () {
    final outlook = advisor.assess(
      snapshot: _snapshot([23, 23, 23, 23, 18, 18, 18]),
      crops: const [Crop('tomato')],
    );

    expect(_for(outlook, 'tomato').preferredDays, 4);
    expect(_for(outlook, 'tomato').fit, CropWeatherFit.mixed);
  });

  test('an absolute-temperature breach prevents a favorable label', () {
    final outlook = advisor.assess(
      snapshot: _snapshot([23, 23, 23, 23, 23, 23, 40]),
      crops: const [Crop('tomato')],
    );

    expect(_for(outlook, 'tomato').preferredDays, 6);
    expect(_for(outlook, 'tomato').outsideAbsoluteDays, 1);
    expect(_for(outlook, 'tomato').fit, CropWeatherFit.weak);
  });

  test('less than three usable days never produces a fit', () {
    final outlook = advisor.assess(snapshot: _snapshot([20, 21]), crops: crops);

    expect(outlook.hasEnoughForecast, isFalse);
    expect(
      outlook.assessments.map((assessment) => assessment.fit),
      everyElement(CropWeatherFit.insufficientData),
    );
  });

  test('rain, wind and storms stay factual context rather than crop rank', () {
    final outlook = advisor.assess(
      snapshot: _snapshot(
        [23, 23, 23],
        rain: [2, 4, 8],
        wind: [10, 30, 20],
        thunderstormIndexes: {1},
      ),
      crops: crops,
    );

    expect(outlook.totalRainMm, 14);
    expect(outlook.maximumWindSpeedKmh, 30);
    expect(outlook.thunderstormDays, 1);
    expect(
      outlook.assessments.map((assessment) => assessment.fit),
      everyElement(CropWeatherFit.favorable),
    );
  });

  test('unknown catalog crops are omitted and reported safely', () {
    final outlook = advisor.assess(
      snapshot: _snapshot(List.filled(7, 23)),
      crops: const [Crop('tomato'), Crop('rice')],
    );

    expect(outlook.assessments.map((value) => value.crop.key), ['tomato']);
    expect(outlook.unsupportedCropKeys, ['rice']);
    expect(CropWeatherAdvisor.methodVersion, isNotEmpty);
    expect(
      CropWeatherAdvisor.profiles['tomato']?.sourceUrl.isScheme('https'),
      isTrue,
    );
  });
}

CropWeatherAssessment _for(CropWeatherOutlook outlook, String cropKey) =>
    outlook.assessments.singleWhere(
      (assessment) => assessment.crop.key == cropKey,
    );

WeatherSnapshot _snapshot(
  List<double> dailyMeans, {
  List<double>? rain,
  List<double>? wind,
  Set<int> thunderstormIndexes = const {},
}) => WeatherSnapshot(
  location: NepalWeatherPresets.kathmandu,
  current: CurrentWeather(
    observedAt: DateTime.utc(2026, 8, 24),
    temperatureC: dailyMeans.first,
    relativeHumidityPercent: 70,
    windSpeedKmh: 8,
    condition: WeatherCondition.clear,
  ),
  daily: [
    for (var index = 0; index < dailyMeans.length; index++)
      DailyWeatherForecast(
        date: DateTime.utc(2026, 8, 24 + index),
        condition: thunderstormIndexes.contains(index)
            ? WeatherCondition.thunderstorm
            : WeatherCondition.clear,
        minimumTemperatureC: dailyMeans[index] - 2,
        maximumTemperatureC: dailyMeans[index] + 2,
        precipitationProbabilityPercent: 20,
        precipitationSumMm: rain?[index] ?? 0,
        maximumWindSpeedKmh: wind?[index] ?? 10,
      ),
  ],
  fetchedAt: DateTime.utc(2026, 8, 24),
  providerName: 'Open-Meteo',
  providerUrl: Uri.parse('https://open-meteo.com'),
);
