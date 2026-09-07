import 'dart:typed_data';

import 'package:capture/capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/capture/capture_screen.dart';
import 'package:krishidoc_app/src/capture/camera_session.dart';
import 'package:krishidoc_app/src/capture/gallery_source.dart';
import 'package:krishidoc_app/src/capture/photo_review.dart';
import 'package:krishidoc_app/src/providers.dart';

import 'helpers/fakes.dart';
import 'helpers/pump_app.dart';

final _png = img.encodePng(img.Image(width: 64, height: 64));
const _good = CaptureQuality(issues: [], edgeEnergy: 20, meanLuminance: 128);

class _Gallery implements GallerySource {
  Uint8List? selection = _png;
  Uint8List? lost;
  bool fail = false;
  int picks = 0;
  @override
  Future<Uint8List?> pick() async {
    picks++;
    if (fail) throw const FormatException('broken photo');
    return selection;
  }

  @override
  Future<Uint8List?> recover() async => lost;
}

Future<AppServices> _pump(
  WidgetTester tester,
  FakeCameraSession camera,
  _Gallery gallery, {
  String? suggestion = 'potato',
  bool automatic = true,
  Locale locale = const Locale('en'),
  CaptureQuality quality = _good,
}) async {
  addTearDown(camera.close);
  return pumpApp(
    tester,
    locale: locale,
    startAt: '/diagnose/camera',
    overrides: [
      cameraSessionProvider.overrideWithValue(() => camera),
      gallerySourceProvider.overrideWithValue(gallery),
      autoDetectCropProvider.overrideWith((ref) => automatic),
      cropSuggestionProvider.overrideWithValue((image) async => suggestion),
      imagePreparationProvider.overrideWithValue((image) async => image),
      galleryQualityProvider.overrideWithValue((image) async => quality),
    ],
  );
}

void main() {
  for (final locale in ['en', 'ne', 'hi']) {
    testWidgets('camera and review fit 320px with large text in $locale', (
      tester,
    ) async {
      useScreen(tester, const Size(320, 640), textScale: 2);
      await _pump(
        tester,
        FakeCameraSession(),
        _Gallery(),
        locale: Locale(locale),
      );
      expect(tester.takeException(), isNull);
      final galleryRect = tester.getRect(find.byKey(galleryKey));
      final shutterRect = tester.getRect(find.byKey(shutterKey));
      expect(galleryRect.top, greaterThan(320));
      expect(galleryRect.bottom, lessThanOrEqualTo(640));
      expect(galleryRect.right, lessThan(shutterRect.left));
      expect(galleryRect.top, shutterRect.top);
      expect(find.byKey(galleryKey).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(galleryKey));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoReviewSheet), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('review.analyze')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'gallery works without camera permission and requires confirmation',
    (tester) async {
      final camera = FakeCameraSession(failOnStart: true);
      final services = await _pump(tester, camera, _Gallery());
      await tester.tap(find.byKey(galleryKey));
      await tester.pumpAndSettle();
      expect(find.byType(PhotoReviewSheet), findsOneWidget);
      expect(find.textContaining('Looks like Potato'), findsOneWidget);
      expect(await services.diagnosisStore.recent(), isEmpty);
      await tester.tap(find.byKey(const Key('review.analyze')));
      await tester.pumpAndSettle();
      expect((await services.diagnosisStore.recent()).single.cropKey, 'potato');
      expect(camera.captureCount, 0);
    },
  );

  testWidgets('correction routes the same gallery photo to the chosen crop', (
    tester,
  ) async {
    final services = await _pump(tester, FakeCameraSession(), _Gallery());
    await tester.tap(find.byKey(galleryKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('review.crop.maize')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('review.analyze')));
    await tester.pumpAndSettle();
    expect((await services.diagnosisStore.recent()).single.cropKey, 'maize');
  });

  testWidgets('unknown crop is not replaced by the remembered crop', (
    tester,
  ) async {
    final services = await _pump(
      tester,
      FakeCameraSession(),
      _Gallery(),
      suggestion: null,
    );
    await tester.tap(find.byKey(galleryKey));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('review.analyze')))
          .onPressed,
      isNull,
    );
    expect(await services.diagnosisStore.recent(), isEmpty);
  });

  testWidgets('picker cancellation saves nothing and resumes the camera', (
    tester,
  ) async {
    final camera = FakeCameraSession();
    final services = await _pump(tester, camera, _Gallery()..selection = null);
    await tester.tap(find.byKey(galleryKey));
    await tester.pumpAndSettle();
    expect(camera.pauseCount, 1);
    expect(camera.resumeCount, 1);
    expect(await services.diagnosisStore.recent(), isEmpty);
    expect(find.byType(PhotoReviewSheet), findsNothing);
  });

  testWidgets('review cancellation saves nothing', (tester) async {
    final camera = FakeCameraSession();
    final services = await _pump(tester, camera, _Gallery());
    await tester.tap(find.byKey(galleryKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose another photo'));
    await tester.pumpAndSettle();
    expect(await services.diagnosisStore.recent(), isEmpty);
    expect(camera.resumeCount, 1);
  });

  testWidgets(
    'poor gallery photo is blocked before crop or disease inference',
    (tester) async {
      final services = await _pump(
        tester,
        FakeCameraSession(),
        _Gallery(),
        quality: const CaptureQuality(
          issues: [CaptureIssue.tooDark],
          edgeEnergy: 20,
          meanLuminance: 0,
        ),
      );
      await tester.tap(find.byKey(galleryKey));
      await tester.pumpAndSettle();
      expect(find.textContaining('too dark, bright or blurry'), findsOneWidget);
      expect(find.byType(PhotoReviewSheet), findsNothing);
      expect(await services.diagnosisStore.recent(), isEmpty);
    },
  );

  testWidgets('import failure stays visible and permits retry', (tester) async {
    final gallery = _Gallery()..fail = true;
    final services = await _pump(tester, FakeCameraSession(), gallery);
    await tester.tap(find.byKey(galleryKey));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('We could not check this photo'),
      findsOneWidget,
    );
    expect(await services.diagnosisStore.recent(), isEmpty);
    gallery.fail = false;
    await tester.tap(find.byKey(galleryKey));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoReviewSheet), findsOneWidget);
  });

  testWidgets(
    'blur-only gallery warning requires crop choice and explicit check',
    (tester) async {
      final services = await _pump(
        tester,
        FakeCameraSession(),
        _Gallery(),
        quality: const CaptureQuality(
          issues: [CaptureIssue.tooBlurry],
          edgeEnergy: 5,
          meanLuminance: 128,
        ),
      );
      await tester.tap(find.byKey(galleryKey));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('review.qualityWarning')), findsOneWidget);
      expect(find.textContaining('Looks like Potato'), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('review.analyze')))
            .onPressed,
        isNull,
      );
      expect(await services.diagnosisStore.recent(), isEmpty);
      await tester.tap(find.byKey(const Key('review.crop.potato')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('review.analyze')));
      await tester.tap(find.text('Check anyway'));
      await tester.pumpAndSettle();
      expect((await services.diagnosisStore.recent()).single.cropKey, 'potato');
    },
  );

  testWidgets('gallery failure is visible when camera permission is denied', (
    tester,
  ) async {
    await _pump(
      tester,
      FakeCameraSession(failOnStart: true),
      _Gallery()..fail = true,
    );
    await tester.tap(find.byKey(galleryKey));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('We could not check this photo'),
      findsOneWidget,
    );
    expect(find.byKey(galleryKey).hitTestable(), findsOneWidget);
  });

  testWidgets(
    'Android recovered selection is reviewed without reopening picker',
    (tester) async {
      final gallery = _Gallery()..lost = _png;
      final services = await _pump(tester, FakeCameraSession(), gallery);
      expect(find.byType(PhotoReviewSheet), findsOneWidget);
      expect(gallery.picks, 0);
      expect(await services.diagnosisStore.recent(), isEmpty);
    },
  );

  testWidgets('camera photos also use automatic crop confirmation', (
    tester,
  ) async {
    final camera = FakeCameraSession()..photoBytes = _png;
    final services = await _pump(tester, camera, _Gallery());
    final plane = Uint8List.fromList(
      List.generate(64 * 64, (i) => (i ~/ 64 + i % 64).isEven ? 90 : 200),
    );
    camera.emit(LumaFrame(luminance: plane, width: 64, height: 64));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(shutterKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('Looks like Potato'), findsOneWidget);
    expect(await services.diagnosisStore.recent(), isEmpty);
    await tester.tap(find.byKey(const Key('review.analyze')));
    await tester.pumpAndSettle();
    expect((await services.diagnosisStore.recent()).single.cropKey, 'potato');
  });
}
