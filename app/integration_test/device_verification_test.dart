import 'dart:math';

import 'package:capture/capture.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:integration_test/integration_test.dart';
import 'package:krishidoc_app/main.dart' as app;
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/providers.dart';

/// On-device verification of what widget tests cannot reach: the real SQLite
/// database, the real Android file system, and this CPU's actual speed.
///
/// It drives only this app's own widget tree, so it cannot touch anything
/// else on the phone.

/// Real-device async has real timers; `pumpAndSettle` can wait forever on a
/// database stream. Poll for the condition instead.
Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 15),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('timed out waiting for: $finder');
}

AppServices servicesOf(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(MaterialApp)),
).read(servicesProvider);

/// Boots the real app and hands back its services.
///
/// The disposal is not ceremony: every test in this file runs in one process,
/// and `main` opens a fresh connection to the same on-device database file.
/// Without closing the previous one, SQLite refuses the next open with
/// "database is locked" and the whole suite fails after the first test.
Future<AppServices> bootApp(WidgetTester tester) async {
  await app.main();
  await pumpUntil(tester, find.text('KrishiDoc'));
  final services = servicesOf(tester);

  addTearDown(() async {
    // Unmount before closing: screens hold live database streams, and
    // closing the connection underneath them raises
    // ConnectionClosedException after the test has already passed.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Startup fires a locale read that nothing outside can await, so give
    // any in-flight query a moment to land before the connection goes.
    // Issuing another query here instead deadlocked against the initial
    // open on the background isolate and killed the app.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    await services.dispose();
  });
  return services;
}

Uint8List noisePlane(int width, int height) {
  final random = Random(7);
  final plane = Uint8List(width * height);
  for (var i = 0; i < plane.length; i++) {
    plane[i] = random.nextInt(256);
  }
  return plane;
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('boot and persistence on the real device', () {
    testWidgets('the app boots with a real on-device database', (tester) async {
      await bootApp(tester);

      expect(find.text('KrishiDoc'), findsOneWidget);
      expect(find.text('Identify disease'), findsOneWidget);
    });

    testWidgets('settings survive a real SQLite round trip', (tester) async {
      final services = await bootApp(tester);

      await services.settingsStore.write(SettingsKeys.selectedLanguage, 'ne');
      expect(
        await services.settingsStore.read(SettingsKeys.selectedLanguage),
        'ne',
      );

      // Leave the device in the default language for the next run.
      await services.settingsStore.write(SettingsKeys.selectedLanguage, 'en');
    });

    testWidgets('a stored diagnosis reaches the History screen', (
      tester,
    ) async {
      final services = await bootApp(tester);

      final marker = 'device_check_${services.ids.newId().substring(0, 8)}';
      await services.diagnosisStore.upsert(
        DiagnosisRecord(
          id: services.ids.newId(),
          state: ResultState.confident,
          predictions: [TopPrediction(label: marker, confidence: 0.93)],
          modelVersion: 'device-verification',
          createdAt: DateTime.now().toUtc(),
        ),
      );

      final historyTile = find.byIcon(Icons.history);
      await tester.ensureVisible(historyTile);
      await tester.pump();
      await tester.tap(historyTile);

      await pumpUntil(tester, find.text(marker));
      expect(find.text(marker), findsOneWidget);
    });
  });

  group('measured budgets on this device', () {
    test('quality gate cost per frame (D-16)', () {
      const gate = QualityGate();
      const width = 1280;
      const height = 720;
      final plane = noisePlane(width, height);

      gate.assess(plane, width: width, height: height); // warm up

      const iterations = 20;
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < iterations; i++) {
        gate.assess(plane, width: width, height: height);
      }
      stopwatch.stop();

      final perFrameMs = stopwatch.elapsedMicroseconds / iterations / 1000;
      debugPrint(
        'MEASURED quality_gate_720p_ms=${perFrameMs.toStringAsFixed(2)}',
      );

      // Debug builds run unoptimised Dart, so this is a pessimistic bound: a
      // release build is materially faster. Failing here is a real signal;
      // passing here is a strong one.
      expect(
        perFrameMs,
        lessThan(30),
        reason: 'D-16 budget is 30 ms per frame on a low-end device',
      );
    });

    test('image preparation cost per photo (D-12)', () {
      final source = Uint8List.fromList(
        img.encodeJpg(_syntheticPhoto(2048, 1536), quality: 90),
      );
      const processor = ImageProcessor();

      final stopwatch = Stopwatch()..start();
      final prepared = processor.prepare(source);
      stopwatch.stop();

      debugPrint(
        'MEASURED image_prepare_ms=${stopwatch.elapsedMilliseconds} '
        'source_kb=${(source.length / 1024).round()} '
        'prepared_kb=${(prepared.length / 1024).round()}',
      );

      expect(prepared.length, lessThan(source.length));
      // No timing assertion: this is exactly why D-12 requires an isolate.
      // The number is the deliverable, not a pass or fail.
    });
  });
}

img.Image _syntheticPhoto(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 7) % 256,
        (y * 11) % 256,
        ((x + y) * 13) % 256,
      );
    }
  }
  return image;
}
