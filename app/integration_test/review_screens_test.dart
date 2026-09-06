import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:krishidoc_app/main.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/home_screen.dart';
import 'package:krishidoc_app/src/providers.dart';

/// Dev utility for the screen review cycle, not a verification.
///
/// Puts real screens on a real device and holds each one long enough to be
/// photographed, because a suite that only asserts cannot tell you that
/// Devanagari matras are colliding or that a card looks like a form field.
/// Language, sample records and text scale are all fixed here rather than
/// tapped in, since driving the device UI directly is outside the automation
/// boundary.
///
/// Run:
///   flutter test integration_test/review_screens_test.dart -d DEVICE
///       --dart-define=KD_REVIEW_LOCALE=ne
///       --dart-define=KD_REVIEW_SCALE_PCT=130
///
/// Then capture the screen while it holds. Records are hand written: there is
/// no trained model yet, so nothing else can produce them.
const _locale = String.fromEnvironment('KD_REVIEW_LOCALE', defaultValue: 'ne');

/// Text scale as a percentage, because `fromEnvironment` has no double form.
const _scale =
    int.fromEnvironment('KD_REVIEW_SCALE_PCT', defaultValue: 100) / 100;
const _holdSeconds = int.fromEnvironment('KD_REVIEW_HOLD', defaultValue: 14);

Future<void> _seed(AppServices services) async {
  await services.settingsStore.write(SettingsKeys.selectedCrop, 'tomato');
  final now = DateTime.now().toUtc();
  final samples = [
    DiagnosisRecord(
      id: '01900000-0000-7000-8000-0000000000a1',
      state: ResultState.confident,
      cropKey: 'tomato',
      predictions: [
        TopPrediction(label: 'tomato_late_blight', confidence: 0.94),
      ],
      modelVersion: 'sample-v0',
      createdAt: now.subtract(const Duration(hours: 2)),
    ),
    DiagnosisRecord(
      id: '01900000-0000-7000-8000-0000000000a2',
      state: ResultState.uncertain,
      cropKey: 'potato',
      predictions: [
        TopPrediction(label: 'potato_early_blight', confidence: 0.41),
        TopPrediction(label: 'potato_late_blight', confidence: 0.36),
      ],
      modelVersion: 'sample-v0',
      createdAt: now.subtract(const Duration(days: 1)),
    ),
    DiagnosisRecord(
      id: '01900000-0000-7000-8000-0000000000a3',
      state: ResultState.outOfScope,
      predictions: const [],
      modelVersion: 'sample-v0',
      createdAt: now.subtract(const Duration(days: 3)),
    ),
  ];
  for (final record in samples) {
    await services.diagnosisStore.upsert(record);
  }
}

Future<void> _hold(WidgetTester tester, int seconds) async {
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hold home, then Records and disease scans, for review', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = _scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final services = await AppServices.open();
    addTearDown(services.dispose);
    await _seed(services);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: KrishiDocApp(initialLocale: Locale(_locale)),
      ),
    );
    await _hold(tester, _holdSeconds);

    // Navigation is driven through the app's own visible Records UI, which is
    // what keeps this inside the automation boundary.
  await tester.tap(find.byKey(homeProfileTabKey));
    await _hold(tester, _holdSeconds);
    final scansTile = find.ancestor(
      of: find.byIcon(Icons.document_scanner_outlined),
      matching: find.byType(ListTile),
    );
    expect(scansTile, findsOneWidget);
    await tester.tap(scansTile);
    await _hold(tester, _holdSeconds);
  });
}
