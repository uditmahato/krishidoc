import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/capture/camera_session.dart';
import 'package:krishidoc_app/src/capture/capture_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:krishidoc_app/src/diagnosis/result_screen.dart';
import 'package:krishidoc_app/src/home_screen.dart';
import 'package:krishidoc_app/src/providers.dart';

import 'helpers/fakes.dart';
import 'helpers/pump_app.dart';

const _timeout = Timeout(Duration(minutes: 1));

LumaFrame _frame(Uint8List plane) =>
    LumaFrame(luminance: plane, width: 64, height: 64);

Uint8List _flat(int value) => Uint8List(64 * 64)..fillRange(0, 64 * 64, value);

Uint8List _checkerboard({required int dark, required int light}) {
  final plane = Uint8List(64 * 64);
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < 64; x++) {
      plane[y * 64 + x] = (x + y).isEven ? dark : light;
    }
  }
  return plane;
}

/// Sharp and well exposed: the frame the gate should accept.
LumaFrame get _goodFrame => _frame(_checkerboard(dark: 90, light: 200));

Future<AppServices> _pumpCapture(
  WidgetTester tester,
  FakeCameraSession camera, {
  Locale locale = const Locale('en'),
  Future<void> Function(AppServices services)? seed,
  int preparedSize = 4242,
}) {
  addTearDown(camera.close);
  return pumpScreen(
    tester,
    const CaptureScreen(),
    locale: locale,
    seed: seed,
    overrides: [
      cameraSessionProvider.overrideWithValue(camera),
      frameAssessmentIntervalProvider.overrideWithValue(Duration.zero),
      imagePreparationProvider.overrideWithValue(
        (original) async => Uint8List(preparedSize),
      ),
    ],
  );
}

FilledButton _shutter(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byKey(shutterKey));

/// Emits a frame and lets the screen catch up.
///
/// Two pumps, deliberately: the first builds the pending frame and only then
/// yields, which is when the stream delivery microtask runs `setState`; the
/// second renders that new state. One pump asserts against the previous
/// frame and reads as a product bug when it is really test timing.
Future<void> _emit(
  WidgetTester tester,
  FakeCameraSession camera,
  LumaFrame frame,
) async {
  camera.emit(frame);
  await tester.pump();
  await tester.pump();
}

void main() {
  group('camera lifecycle', () {
    testWidgets('a camera that cannot start shows guidance, not a spinner', (
      tester,
    ) async {
      await _pumpCapture(tester, FakeCameraSession(failOnStart: true));

      expect(find.textContaining('Allow camera access'), findsOneWidget);
      expect(find.byKey(shutterKey), findsNothing);
    });

    testWidgets('leaving the screen stops the camera', (tester) async {
      final camera = FakeCameraSession();
      await _pumpCapture(tester, camera);
      expect(camera.didStart, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      expect(camera.didStop, isTrue);
    });
  });

  group('coaching (D-16)', () {
    testWidgets('before any frame arrives, the shutter is disabled', (
      tester,
    ) async {
      await _pumpCapture(tester, FakeCameraSession());

      expect(find.text('Hold the camera steady'), findsOneWidget);
      expect(_shutter(tester).onPressed, isNull);
    });

    testWidgets('a good frame enables the shutter', (tester) async {
      final camera = FakeCameraSession();
      await _pumpCapture(tester, camera);
      expect(camera.hasListener, isTrue, reason: 'frames must be subscribed');

      await _emit(tester, camera, _goodFrame);

      expect(find.text('Ready'), findsOneWidget);
      expect(_shutter(tester).onPressed, isNotNull);
    });

    testWidgets('a dark frame coaches toward light and blocks capture', (
      tester,
    ) async {
      final camera = FakeCameraSession();
      await _pumpCapture(tester, camera);

      await _emit(tester, camera, _frame(_checkerboard(dark: 0, light: 30)));

      expect(find.text('Move somewhere brighter'), findsOneWidget);
      expect(_shutter(tester).onPressed, isNull);
    });

    testWidgets('a blurry frame coaches toward the leaf', (tester) async {
      final camera = FakeCameraSession();
      await _pumpCapture(tester, camera);

      await _emit(tester, camera, _frame(_flat(128)));

      expect(
        find.text('Move closer to the leaf and hold steady'),
        findsOneWidget,
      );
      expect(_shutter(tester).onPressed, isNull);
    });

    testWidgets('exposure is named before blur when a frame fails both', (
      tester,
    ) async {
      final camera = FakeCameraSession();
      await _pumpCapture(tester, camera);

      // Flat and nearly black: fails both checks.
      await _emit(tester, camera, _frame(_flat(2)));

      expect(find.text('Move somewhere brighter'), findsOneWidget);
      expect(
        find.text('Move closer to the leaf and hold steady'),
        findsNothing,
      );
    });

    testWidgets('coaching is localized', (tester) async {
      final camera = FakeCameraSession();
      await _pumpCapture(tester, camera, locale: const Locale('ne'));

      await _emit(tester, camera, _frame(_checkerboard(dark: 0, light: 30)));

      expect(find.text('अलि उज्यालो ठाउँमा जानुहोस्'), findsOneWidget);
    });
  });

  group('crop context (D-16)', () {
    testWidgets('defaults to the first covered crop when nothing is stored', (
      tester,
    ) async {
      await _pumpCapture(tester, FakeCameraSession());

      expect(find.text('Crop: Tomato'), findsOneWidget);
    });

    testWidgets('restores the remembered crop', (tester) async {
      await _pumpCapture(
        tester,
        FakeCameraSession(),
        seed: (services) =>
            services.settingsStore.write(SettingsKeys.selectedCrop, 'maize'),
      );

      expect(find.text('Crop: Maize'), findsOneWidget);
    });

    testWidgets('falls back when the stored crop is no longer covered', (
      tester,
    ) async {
      await _pumpCapture(
        tester,
        FakeCameraSession(),
        seed: (services) =>
            services.settingsStore.write(SettingsKeys.selectedCrop, 'cardamom'),
      );

      expect(find.text('Crop: Tomato'), findsOneWidget);
    });

    testWidgets('changing the crop applies and persists it', (tester) async {
      final services = await _pumpCapture(tester, FakeCameraSession());

      await tester.tap(find.text('Crop: Tomato'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Potato'));
      await tester.pumpAndSettle();

      expect(find.text('Crop: Potato'), findsOneWidget);
      expect(
        await services.settingsStore.read(SettingsKeys.selectedCrop),
        'potato',
      );
    });
  });

  group('the closed loop', () {
    // Driven through the real app rather than the screen in isolation,
    // because the thing under test is precisely what happens AFTER the
    // shutter: classify, store, navigate. For four modules the shutter ended
    // in a byte count, which is the dead end this rebuild exists to remove.
    Future<AppServices> pumpLoop(
      WidgetTester tester,
      FakeCameraSession camera, {
      Locale locale = const Locale('en'),
    }) async {
      addTearDown(camera.close);
      final services = await pumpApp(
        tester,
        locale: locale,
        overrides: [
          cameraSessionProvider.overrideWithValue(camera),
          frameAssessmentIntervalProvider.overrideWithValue(Duration.zero),
          imagePreparationProvider.overrideWithValue(
            (original) async => Uint8List.fromList(
              List<int>.generate(4096, (i) => (i * 7) & 0xFF),
            ),
          ),
        ],
      );
      // The debug-only door. The Diagnose tile that used to lead here was
      // deleted in Module 13, because Home must not offer a farmer a
      // diagnosis this build cannot honestly give. Keyed rather than found by
      // icon: the not-ready row now carries the camera glyph too.
      await tester.tap(find.byKey(homeDebugCaptureKey));
      await tester.pumpAndSettle();
      return services;
    }

    testWidgets('the shutter produces a stored diagnosis', timeout: _timeout, (
      tester,
    ) async {
      final camera = FakeCameraSession();
      final services = await pumpLoop(tester, camera);

      await _emit(tester, camera, _goodFrame);
      await tester.tap(find.byKey(shutterKey));
      await tester.pumpAndSettle();

      expect(camera.captureCount, 1);

      final stored = await services.diagnosisStore.recent();
      expect(stored, hasLength(1));
      final record = stored.single;
      expect(record.cropKey, 'tomato');
      expect(
        record.modelVersion,
        startsWith('sample-'),
        reason: 'a record must stay identifiable as sample data forever (D-52)',
      );
      expect(
        record.imagePath,
        isNotNull,
        reason: 'the farmer must be able to see the leaf they photographed',
      );
    });

    testWidgets('the result is on screen and says it is sample data', (
      tester,
    ) async {
      final camera = FakeCameraSession();
      await pumpLoop(tester, camera);

      await _emit(tester, camera, _goodFrame);
      await tester.tap(find.byKey(shutterKey));
      await tester.pumpAndSettle();

      expect(find.byType(ResultScreen), findsOneWidget);
      expect(find.byType(DiagnosisResultView), findsOneWidget);
      expect(find.text('Result'), findsOneWidget);
      // D-52 makes this notice mandatory on every surface rendering a sample
      // result. Without it the app is V1's decorative confidence again, with a
      // bigger blast radius.
      expect(
        find.textContaining('Sample data'),
        findsOneWidget,
        reason: 'a sample answer must never be presented as a real one',
      );
    });

    testWidgets('every result offers a way to reach a person', (tester) async {
      // Whatever the state, escalation is present. This is the behavioural
      // half of putting escalation on the sealed base class.
      final camera = FakeCameraSession();
      await pumpLoop(tester, camera);

      await _emit(tester, camera, _goodFrame);
      await tester.tap(find.byKey(shutterKey));
      await tester.pumpAndSettle();

      expect(find.text('See crop experts near you'), findsOneWidget);
    });

    testWidgets('the new diagnosis reaches History', timeout: _timeout, (
      tester,
    ) async {
      final camera = FakeCameraSession();
      await pumpLoop(tester, camera);

      await _emit(tester, camera, _goodFrame);
      await tester.tap(find.byKey(shutterKey));
      await tester.pumpAndSettle();

      // Back out of the result, back out of the camera, then into History.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.history_outlined));
      await tester.pumpAndSettle();

      expect(find.byType(ListTile), findsOneWidget);
    });

    testWidgets('a capture failure is stated, not swallowed', (tester) async {
      // Previously a bare try/finally, so a failure was indistinguishable from
      // the app ignoring the tap, and a farmer would blame themselves.
      final camera = FakeCameraSession()..failOnCapture = true;
      await pumpLoop(tester, camera);

      await _emit(tester, camera, _goodFrame);
      await tester.tap(find.byKey(shutterKey));
      await tester.pumpAndSettle();

      expect(find.text('Result'), findsNothing);
      expect(
        find.textContaining('Something went wrong'),
        findsOneWidget,
        reason:
            'the explanation of a failure is the one thing that must not '
            'evaporate',
      );
    });
  });
}
