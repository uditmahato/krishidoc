import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/l10n/gen/app_localizations.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/providers.dart';
import 'package:krishidoc_app/src/weather/weather.dart';
import 'package:krishidoc_app/src/weather/weather_l10n.dart';

import 'helpers/fakes.dart';

void main() {
  testWidgets('crop weather fit remains usable at 320 px and 2x text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final locale in const [Locale('en'), Locale('ne'), Locale('hi')]) {
      await _pumpLocalizedWeather(tester, locale);

      expect(find.byKey(cropWeatherFitKey), findsOneWidget);
      expect(find.byKey(cropWeatherRowKey('tomato')), findsOneWidget);
      expect(find.byKey(cropWeatherRowKey('potato')), findsOneWidget);
      expect(find.byKey(cropWeatherRowKey('maize')), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: 'locale ${locale.languageCode}',
      );
    }
  });
}

Future<void> _pumpLocalizedWeather(WidgetTester tester, Locale locale) async {
  final services = AppServices.forTest(
    diagnosisStore: FakeDiagnosisStore(),
    farmTaskStore: FakeFarmTaskStore(),
    observationStore: FakeObservationStore(),
    settingsStore: FakeSettingsStore(),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        servicesProvider.overrideWithValue(services),
        weatherServiceProvider.overrideWithValue(_LayoutWeatherService()),
      ],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => NepalWeatherScreen(
            strings: localizedWeatherStrings(AppLocalizations.of(context)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final class _LayoutWeatherService implements WeatherService {
  @override
  Future<WeatherSnapshot> fetch(NepalWeatherLocation location) async {
    final now = DateTime.now().toUtc();
    return WeatherSnapshot(
      location: location,
      current: CurrentWeather(
        observedAt: now,
        temperatureC: 24,
        relativeHumidityPercent: 72,
        windSpeedKmh: 8,
        condition: WeatherCondition.partlyCloudy,
      ),
      daily: [
        for (var index = 0; index < 7; index++)
          DailyWeatherForecast(
            date: DateTime.utc(2026, 8, 24 + index),
            condition: index == 2
                ? WeatherCondition.thunderstorm
                : WeatherCondition.partlyCloudy,
            minimumTemperatureC: 20,
            maximumTemperatureC: 28,
            precipitationProbabilityPercent: 60,
            precipitationSumMm: 8,
            maximumWindSpeedKmh: 18,
          ),
      ],
      fetchedAt: now,
      providerName: 'Open-Meteo',
      providerUrl: Uri.parse('https://open-meteo.com'),
    );
  }
}
