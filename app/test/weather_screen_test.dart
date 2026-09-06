import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/providers.dart';
import 'package:krishidoc_app/src/weather/weather.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('shows live values, source, and selected Nepal city', (
    tester,
  ) async {
    final service = _FakeWeatherService((location) => _snapshot(location));

    await _pumpWeather(tester, service);

    expect(find.text('Nepal weather'), findsOneWidget);
    expect(find.text('Kathmandu'), findsOneWidget);
    expect(find.text('24 °C'), findsOneWidget);
    expect(find.text('Partly cloudy'), findsAtLeastNWidgets(1));
    expect(find.text('Source: Open-Meteo'), findsOneWidget);
    expect(find.textContaining('Updated '), findsOneWidget);
    expect(find.textContaining('DHM warnings'), findsOneWidget);
    expect(find.byKey(cropWeatherFitKey), findsOneWidget);
    expect(find.byKey(cropWeatherRowKey('tomato')), findsOneWidget);
    expect(find.byKey(cropWeatherRowKey('potato')), findsOneWidget);
    expect(find.byKey(cropWeatherRowKey('maize')), findsOneWidget);
    expect(find.text('7-day crop weather fit'), findsOneWidget);
    expect(find.textContaining('Soil, drainage, elevation'), findsOneWidget);
    expect(find.textContaining('FAO EcoCrop'), findsOneWidget);
    expect(service.calls, 1);
  });

  testWidgets('labels an old forecast as saved and stale', (tester) async {
    final service = _FakeWeatherService(
      (location) => _snapshot(
        location,
        fetchedAt: DateTime.now().toUtc().subtract(const Duration(hours: 4)),
      ),
    );

    await _pumpWeather(tester, service);

    expect(find.byKey(weatherStaleKey), findsOneWidget);
    expect(find.text('Saved forecast'), findsAtLeastNWidgets(2));
    expect(
      find.text('This forecast is more than 3 hours old.'),
      findsOneWidget,
    );
  });

  testWidgets('shows a safe retry state when the network is unavailable', (
    tester,
  ) async {
    final service = _FakeWeatherService(
      (location) =>
          throw const WeatherServiceException(WeatherFailureKind.network),
    );

    await _pumpWeather(tester, service);

    expect(find.byKey(weatherFailureKey), findsOneWidget);
    expect(
      find.text('No internet connection. Try again when you are online.'),
      findsOneWidget,
    );
    expect(find.byKey(weatherRetryKey), findsOneWidget);
    expect(find.byKey(cropWeatherFitKey), findsNothing);
    expect(find.textContaining('WeatherServiceException'), findsNothing);
  });

  testWidgets('restores the last explicitly selected Nepal city', (
    tester,
  ) async {
    final settings = FakeSettingsStore();
    await settings.write(SettingsKeys.weatherLocation, 'pokhara');
    final service = _FakeWeatherService((location) => _snapshot(location));

    await _pumpWeather(tester, service, settings: settings);

    expect(find.text('Pokhara'), findsOneWidget);
    expect(service.lastLocation?.id, 'pokhara');
  });

  testWidgets('changing the selected place recomputes every crop fit', (
    tester,
  ) async {
    final service = _FakeWeatherService(
      (location) => location.id == 'pokhara'
          ? _snapshot(location, dailyMinimumC: 28, dailyMaximumC: 32)
          : _snapshot(location, dailyMinimumC: 14, dailyMaximumC: 18),
    );

    await _pumpWeather(tester, service);

    expect(
      find.descendant(
        of: find.byKey(cropWeatherRowKey('potato')),
        matching: find.text('Mostly favorable'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(weatherLocationKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pokhara').last);
    await tester.pumpAndSettle();

    expect(service.lastLocation?.id, 'pokhara');
    expect(
      find.descendant(
        of: find.byKey(cropWeatherRowKey('maize')),
        matching: find.text('Mostly favorable'),
      ),
      findsOneWidget,
    );
  });
}

Future<void> _pumpWeather(
  WidgetTester tester,
  WeatherService service, {
  FakeSettingsStore? settings,
}) async {
  final services = AppServices.forTest(
    diagnosisStore: FakeDiagnosisStore(),
    farmTaskStore: FakeFarmTaskStore(),
    observationStore: FakeObservationStore(),
    settingsStore: settings ?? FakeSettingsStore(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        weatherServiceProvider.overrideWithValue(service),
        servicesProvider.overrideWithValue(services),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        home: NepalWeatherScreen(strings: WeatherStrings.english()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _FakeWeatherService implements WeatherService {
  _FakeWeatherService(this.answer);

  final WeatherSnapshot Function(NepalWeatherLocation location) answer;
  int calls = 0;
  NepalWeatherLocation? lastLocation;

  @override
  Future<WeatherSnapshot> fetch(NepalWeatherLocation location) async {
    calls++;
    lastLocation = location;
    return answer(location);
  }
}

WeatherSnapshot _snapshot(
  NepalWeatherLocation location, {
  DateTime? fetchedAt,
  double dailyMinimumC = 20,
  double dailyMaximumC = 28,
}) => WeatherSnapshot(
  location: location,
  current: CurrentWeather(
    observedAt:
        fetchedAt?.subtract(const Duration(minutes: 5)) ??
        DateTime.now().toUtc(),
    temperatureC: 24,
    relativeHumidityPercent: 80,
    windSpeedKmh: 8,
    condition: WeatherCondition.partlyCloudy,
  ),
  daily: [
    for (var index = 0; index < 7; index++)
      DailyWeatherForecast(
        date: DateTime.utc(2026, 8, 4 + index),
        condition: WeatherCondition.partlyCloudy,
        minimumTemperatureC: dailyMinimumC,
        maximumTemperatureC: dailyMaximumC,
        precipitationProbabilityPercent: 70,
        precipitationSumMm: 12,
        maximumWindSpeedKmh: 14,
      ),
  ],
  fetchedAt: fetchedAt ?? DateTime.now().toUtc(),
  providerName: 'Open-Meteo',
  providerUrl: Uri.parse('https://open-meteo.com'),
);
