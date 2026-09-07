import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/assistant/crop_assistant.dart';
import 'package:krishidoc_app/src/diagnosis/disease_scan_intro_screen.dart';
import 'package:krishidoc_app/src/diagnosis/result_screen.dart';
import 'package:krishidoc_app/src/history_screen.dart';
import 'package:krishidoc_app/src/home_screen.dart';
import 'package:krishidoc_app/src/router.dart';
import 'package:krishidoc_app/src/weather/weather.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('Work exposes Nepal weather and opens a live forecast', (
    tester,
  ) async {
    final weather = _FakeWeatherService();
    await pumpApp(
      tester,
      locale: const Locale('en'),
      overrides: [weatherServiceProvider.overrideWithValue(weather)],
    );

    expect(find.byKey(homeWeatherKey), findsOneWidget);

    await tester.ensureVisible(find.byKey(homeWeatherKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(homeWeatherKey));
    await tester.pumpAndSettle();

    expect(find.byType(NepalWeatherScreen), findsOneWidget);
    expect(find.byKey(weatherLocationKey), findsOneWidget);
    expect(find.text('Source: Open-Meteo'), findsOneWidget);
    expect(weather.calls, 1);
  });

  testWidgets('Doctor exposes both disease scan and crop assistant actions', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(homeAskTabKey));
    await tester.pumpAndSettle();

    expect(find.text('Crop doctor'), findsOneWidget);
    expect(find.byKey(homeDetectDiseaseKey), findsOneWidget);
    expect(find.byKey(homeAssistantKey), findsOneWidget);
  });

  testWidgets('Doctor disease action opens the scan limitations first', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(homeAskTabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(homeDetectDiseaseKey));
    await tester.pumpAndSettle();

    expect(find.byType(DiseaseScanIntroScreen), findsOneWidget);
    expect(
      find.text('Current model: tomato, potato and maize leaves'),
      findsOneWidget,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(diseaseScanStartKey), findsOneWidget);
  });

  testWidgets('Doctor assistant action opens the Nepal crop guide', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(homeAskTabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(homeAssistantKey));
    await tester.pumpAndSettle();

    expect(find.byType(CropAssistantScreen), findsOneWidget);
    expect(find.byKey(cropAssistantDisclosureKey), findsOneWidget);
    expect(find.text('Crop context: Tomato'), findsOneWidget);
  });

  testWidgets('diagnose route supports remembered maize crop', (tester) async {
    final services = await pumpApp(
      tester,
      locale: const Locale('en'),
      startAt: AppRoutes.diagnose,
      seed: (services) =>
          services.settingsStore.write(SettingsKeys.selectedCrop, 'maize'),
    );

    expect(find.byType(DiseaseScanIntroScreen), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(diseaseScanStartKey), findsOneWidget);
    expect(
      await services.settingsStore.read(SettingsKeys.selectedCrop),
      'maize',
    );
  });

  testWidgets('assistant route is directly reachable', (tester) async {
    await pumpApp(
      tester,
      locale: const Locale('ne'),
      startAt: AppRoutes.assistant,
    );

    expect(find.byType(CropAssistantScreen), findsOneWidget);
    expect(find.byKey(cropAssistantQuestionKey), findsOneWidget);
  });

  testWidgets('weather route is directly reachable without a real network', (
    tester,
  ) async {
    final weather = _FakeWeatherService();
    await pumpApp(
      tester,
      locale: const Locale('hi'),
      startAt: AppRoutes.weather,
      overrides: [weatherServiceProvider.overrideWithValue(weather)],
    );

    expect(find.byType(NepalWeatherScreen), findsOneWidget);
    expect(find.byKey(weatherRefreshKey), findsOneWidget);
    expect(weather.calls, 1);
  });

  testWidgets('stored result route is available outside the dev preview', (
    tester,
  ) async {
    const id = 'release-result';
    await pumpApp(
      tester,
      locale: const Locale('en'),
      startAt: '${AppRoutes.resultBase}/$id',
      seed: (services) => services.diagnosisStore.upsert(
        DiagnosisRecord(
          id: id,
          state: ResultState.confident,
          predictions: [TopPrediction(label: 'late_blight', confidence: 0.82)],
          modelVersion: 'tomato-v1',
          createdAt: DateTime.utc(2026, 8, 4),
          cropKey: 'tomato',
        ),
      ),
    );

    expect(find.byType(ResultScreen), findsOneWidget);
    expect(find.text('Result'), findsOneWidget);
    expect(find.textContaining('Something went wrong'), findsNothing);
  });

  testWidgets('a scan result opens immediate crop and candidate guidance', (
    tester,
  ) async {
    const id = 'contextual-assistant-result';
    await pumpApp(
      tester,
      locale: const Locale('en'),
      startAt: '${AppRoutes.resultBase}/$id',
      seed: (services) => services.diagnosisStore.upsert(
        DiagnosisRecord(
          id: id,
          state: ResultState.uncertain,
          predictions: [
            TopPrediction(label: 'tomato_late_blight', confidence: 0.62),
            TopPrediction(label: 'tomato_early_blight', confidence: 0.23),
          ],
          modelVersion: 'experimental-context-test',
          createdAt: DateTime.utc(2026, 8, 4),
          cropKey: 'tomato',
        ),
      ),
    );

    final action = find.text('See treatment, prevention and control guidance');
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(find.byType(CropAssistantScreen), findsOneWidget);
    expect(find.text('Crop context: Tomato'), findsOneWidget);
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
    }
    expect(
      find.textContaining('Tomato late blight. Experimental possible match'),
      findsOneWidget,
    );
    expect(find.byKey(cropAssistantAnswerKey), findsOneWidget);
  });

  testWidgets('stored history route opens its corresponding result', (
    tester,
  ) async {
    const id = 'release-history-result';
    await pumpApp(
      tester,
      locale: const Locale('en'),
      startAt: AppRoutes.history,
      seed: (services) => services.diagnosisStore.upsert(
        DiagnosisRecord(
          id: id,
          state: ResultState.confident,
          predictions: [TopPrediction(label: 'early_blight', confidence: 0.8)],
          modelVersion: 'tomato-v1',
          createdAt: DateTime.utc(2026, 8, 4),
          cropKey: 'tomato',
        ),
      ),
    );

    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pumpAndSettle();

    expect(find.byType(ResultScreen), findsOneWidget);
  });
}

final class _FakeWeatherService implements WeatherService {
  int calls = 0;

  @override
  Future<WeatherSnapshot> fetch(NepalWeatherLocation location) async {
    calls++;
    return WeatherSnapshot(
      location: location,
      current: CurrentWeather(
        observedAt: DateTime.now().toUtc(),
        temperatureC: 24,
        relativeHumidityPercent: 80,
        windSpeedKmh: 8,
        condition: WeatherCondition.partlyCloudy,
      ),
      daily: [
        DailyWeatherForecast(
          date: DateTime.utc(2026, 8, 4),
          condition: WeatherCondition.partlyCloudy,
          minimumTemperatureC: 20,
          maximumTemperatureC: 28,
          precipitationProbabilityPercent: 70,
          precipitationSumMm: 12,
          maximumWindSpeedKmh: 14,
        ),
      ],
      fetchedAt: DateTime.now().toUtc(),
      providerName: 'Open-Meteo',
      providerUrl: Uri.parse('https://open-meteo.com'),
    );
  }
}
