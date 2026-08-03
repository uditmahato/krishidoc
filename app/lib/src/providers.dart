import 'dart:isolate';
import 'dart:typed_data';

import 'package:capture/capture.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inference/inference.dart';

import 'app_services.dart';
import 'capture/camera_session.dart';
import 'capture/launch_crop_catalog.dart';
import 'capture/platform_camera_session.dart';
import 'diagnosis/photo_store.dart';

/// Overridden at the root (main or test pump); reading it unoverridden is a
/// wiring bug and fails loudly.
final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError('servicesProvider must be overridden at the root'),
);

/// Newest-first window of stored diagnoses for the History screen.
final recentDiagnosesProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(servicesProvider).diagnosisStore.watchRecent(),
);

/// Newest-first window of the field notebook.
///
/// Unlike diagnoses, this one has rows in a release build, because writing to
/// it needs no model: a photograph and a date are true whatever the app can
/// or cannot recognise.
final recentObservationsProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(servicesProvider).observationStore.watchRecent(),
);

/// The model pack for a crop, or null when that crop is not covered.
///
/// Null is a first-class answer, not an error. Coverage is finite (D-49 pins
/// launch scope at three crops) and the honest response to a crop we do not
/// cover is to say so, never to run another crop's pack against the photo.
final modelPackProvider = Provider.family<ModelPack?, String>(
  (ref, cropKey) => SamplePacks.forCrop(cropKey),
);

/// The on-device classification path for a crop.
///
/// **Sample data (D-52).** `SampleClassifier` hashes the image bytes and its
/// output means nothing about the plant. Every surface that renders a result
/// is required to check [isSamplePack] and say so, and no build carrying this
/// may be distributed outside the team.
final classificationServiceProvider =
    Provider.family<ClassificationService?, String>((ref, cropKey) {
      final pack = ref.watch(modelPackProvider(cropKey));
      if (pack == null) return null;
      return ClassificationService(
        classifier: SampleClassifier(pack: pack),
        pack: pack,
      );
    });

/// Where diagnosed photos are written. Overridden in tests with the in-memory
/// implementation, for the same reason drift is never live in a widget test.
final photoStoreProvider = Provider<PhotoStore>(
  (ref) =>
      throw StateError('photoStoreProvider must be overridden at the root'),
);

/// Bytes of a diagnosed photo, or null when the file is gone.
///
/// Keyed on the path so the read happens once per photo rather than on every
/// rebuild, and null stays a normal answer: Android reclaims app storage under
/// pressure, and a result whose photo has been evicted must still open.
final diagnosisPhotoProvider = FutureProvider.autoDispose
    .family<Uint8List?, String>(
      (ref, path) => ref.watch(photoStoreProvider).read(path),
    );

/// One stored diagnosis, for the result screen.
///
/// Read once rather than watched: a diagnosis is immutable after it is written
/// (a correction will create a new record rather than mutate this one), so a
/// stream here would be a subscription that can never fire.
final diagnosisByIdProvider = FutureProvider.autoDispose
    .family<DiagnosisRecord?, String>(
      (ref, id) => ref.watch(servicesProvider).diagnosisStore.byId(id),
    );

/// One notebook entry.
///
/// Watched rather than read once, unlike a diagnosis: an observation IS
/// mutable, because the note is the farmer's to change after the fact.
final observationByIdProvider = StreamProvider.autoDispose
    .family<Observation?, String>(
      (ref, id) => ref
          .watch(servicesProvider)
          .observationStore
          .watchRecent()
          .map((rows) => rows.where((row) => row.id == id).firstOrNull),
    );

final cropCatalogProvider = Provider<CropCatalog>(
  (ref) => const LaunchCropCatalog(),
);

/// The real camera. Tests override this with a scriptable fake, which is why
/// every decision the capture screen makes is testable without hardware.
final cameraSessionProvider = Provider<CameraSession>(
  (ref) => PlatformCameraSession(),
);

/// How often preview frames are assessed. Every frame is neither necessary
/// nor affordable on a low-end device (D-16, audit M-4); tests set zero.
final frameAssessmentIntervalProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 200),
);

typedef ImagePreparation = Future<Uint8List> Function(Uint8List original);

/// Preparation is CPU-bound, so it runs off the UI thread (D-12).
final imagePreparationProvider = Provider<ImagePreparation>(
  (ref) =>
      (original) => Isolate.run(() => const ImageProcessor().prepare(original)),
);

/// The remembered crop (D-16): restored from settings, persisted on change,
/// never demanded up front.
final selectedCropProvider = AsyncNotifierProvider<SelectedCropNotifier, Crop>(
  SelectedCropNotifier.new,
);

class SelectedCropNotifier extends AsyncNotifier<Crop> {
  @override
  Future<Crop> build() async {
    final catalog = ref.watch(cropCatalogProvider);
    final stored = await ref
        .read(servicesProvider)
        .settingsStore
        .read(SettingsKeys.selectedCrop);
    return catalog.byKey(stored) ?? catalog.fallback;
  }

  Future<void> select(Crop crop) async {
    state = AsyncData(crop);
    await ref
        .read(servicesProvider)
        .settingsStore
        .write(SettingsKeys.selectedCrop, crop.key);
  }
}
