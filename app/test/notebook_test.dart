import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/capture/camera_session.dart';
import 'package:krishidoc_app/src/capture/capture_screen.dart';
import 'package:krishidoc_app/src/home_screen.dart';
import 'package:krishidoc_app/src/notebook/notebook_screen.dart';
import 'package:krishidoc_app/src/notebook/observation_screen.dart';
import 'package:krishidoc_app/src/providers.dart';

import 'helpers/fakes.dart';
import 'helpers/pump_app.dart';

const _timeout = Timeout(Duration(minutes: 1));

LumaFrame _frame(Uint8List plane) =>
    LumaFrame(luminance: plane, width: 64, height: 64);

Uint8List _checkerboard() {
  final plane = Uint8List(64 * 64);
  for (var y = 0; y < 64; y++) {
    for (var x = 0; x < 64; x++) {
      plane[y * 64 + x] = (x + y).isEven ? 90 : 200;
    }
  }
  return plane;
}

Future<void> _emit(WidgetTester tester, FakeCameraSession camera) async {
  camera.emit(_frame(_checkerboard()));
  await tester.pump();
  await tester.pump();
}

Future<void> _openNotebook(WidgetTester tester) async {
  await tester.tap(find.byKey(homeProfileTabKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(homeViewAllPhotosKey));
  await tester.pumpAndSettle();
}

/// The first task in this app a farmer can actually finish.
///
/// Everything here is reachable in a RELEASE build, which is the point. The
/// diagnosis loop is real but sits behind `kDebugMode`, because every answer
/// it can give today is a hash of the image bytes. Keeping a dated photograph
/// asserts nothing about a plant, so ADR-0052 does not reach it.
void main() {
  Future<AppServices> pumpLoop(
    WidgetTester tester,
    FakeCameraSession camera, {
    Locale locale = const Locale('en'),
  }) async {
    addTearDown(camera.close);
    return pumpApp(
      tester,
      locale: locale,
      overrides: [
        cameraSessionProvider.overrideWithValue(() => camera),
        frameAssessmentIntervalProvider.overrideWithValue(Duration.zero),
        imagePreparationProvider.overrideWithValue(
          (original) async => Uint8List.fromList(
            List<int>.generate(4096, (i) => (i * 7) & 0xFF),
          ),
        ),
      ],
    );
  }

  testWidgets(
    'home offers the notebook as a live destination',
    timeout: _timeout,
    (tester) async {
      await pumpApp(tester, locale: const Locale('en'));

      await _openNotebook(tester);

      expect(find.byType(NotebookScreen), findsOneWidget);
      expect(find.text('You have no photos yet.'), findsOneWidget);
    },
  );

  testWidgets(
    'the shutter keeps a photograph, and claims nothing',
    timeout: _timeout,
    (tester) async {
      final camera = FakeCameraSession();
      final services = await pumpLoop(tester, camera);

      await _openNotebook(tester);
      await tester.tap(find.byKey(notebookCaptureKey));
      await tester.pumpAndSettle();

      await _emit(tester, camera);
      await tester.tap(find.byKey(shutterKey));
      await tester.pumpAndSettle();

      // One observation, with its photo, its crop and a UTC timestamp.
      final kept = await services.observationStore.recent();
      expect(kept, hasLength(1));
      expect(kept.single.imagePath, isNotNull);
      expect(kept.single.cropKey, 'tomato');
      expect(kept.single.createdAt.isUtc, isTrue);

      // And nothing was written to the diagnosis store, which is the whole
      // distinction: no model ran, so no claim was made or stored.
      expect(
        await services.diagnosisStore.recent(),
        isEmpty,
        reason: 'the notebook must never create a diagnosis',
      );

      expect(find.byType(ObservationScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a note can be added after the fact and survives',
    timeout: _timeout,
    (tester) async {
      final camera = FakeCameraSession();
      final services = await pumpLoop(tester, camera);

      await _openNotebook(tester);
      await tester.tap(find.byKey(notebookCaptureKey));
      await tester.pumpAndSettle();
      await _emit(tester, camera);
      await tester.tap(find.byKey(shutterKey));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(observationNoteKey), 'brown spots');
      await tester.tap(find.byKey(observationSaveKey));
      await tester.pumpAndSettle();

      final kept = await services.observationStore.recent();
      expect(kept.single.note, 'brown spots');
    },
  );

  testWidgets('the notebook lists what was kept', timeout: _timeout, (
    tester,
  ) async {
    final services = await pumpApp(tester, locale: const Locale('en'));
    await services.observationStore.upsert(
      Observation(
        id: services.ids.newId(),
        imagePath: 'memory://photos/a.jpg',
        createdAt: DateTime.utc(2026, 8, 1),
        cropKey: 'tomato',
        note: 'wilting',
      ),
    );

    await _openNotebook(tester);

    expect(find.text('Tomato'), findsOneWidget);
    expect(find.text('wilting'), findsOneWidget);
    expect(find.text('You have no photos yet.'), findsNothing);
  });

  testWidgets(
    'an entry with no note says so, rather than showing a gap',
    timeout: _timeout,
    (tester) async {
      final services = await pumpApp(tester, locale: const Locale('en'));
      await services.observationStore.upsert(
        Observation(
          id: services.ids.newId(),
          imagePath: 'memory://photos/a.jpg',
          createdAt: DateTime.utc(2026, 8, 1),
          cropKey: 'tomato',
        ),
      );

      await _openNotebook(tester);

      expect(find.text('No note'), findsOneWidget);
    },
  );

  testWidgets(
    'deleting asks first, then removes the entry',
    timeout: _timeout,
    (tester) async {
      final services = await pumpApp(tester, locale: const Locale('en'));
      await services.observationStore.upsert(
        Observation(
          id: services.ids.newId(),
          imagePath: 'memory://photos/a.jpg',
          createdAt: DateTime.utc(2026, 8, 1),
          cropKey: 'tomato',
        ),
      );

      await _openNotebook(tester);
      await tester.tap(find.byType(InkWell).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(observationDeleteKey));
      await tester.pumpAndSettle();

      // A photograph of a crop that later died is not replaceable, so the
      // destructive path is never one tap.
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      expect(await services.observationStore.recent(), isEmpty);
    },
  );

  testWidgets('cancelling the delete keeps the entry', timeout: _timeout, (
    tester,
  ) async {
    final services = await pumpApp(tester, locale: const Locale('en'));
    await services.observationStore.upsert(
      Observation(
        id: services.ids.newId(),
        imagePath: 'memory://photos/a.jpg',
        createdAt: DateTime.utc(2026, 8, 1),
      ),
    );

    await _openNotebook(tester);
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(observationDeleteKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(await services.observationStore.recent(), hasLength(1));
  });
}
