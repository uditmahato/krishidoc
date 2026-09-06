import 'dart:async';
import 'dart:isolate';

import 'package:capture/capture.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:inference/inference.dart';

import 'app_services.dart';
import 'capture/camera_session.dart';
import 'capture/launch_crop_catalog.dart';
import 'capture/platform_camera_session.dart';
import 'diagnosis/photo_store.dart';
import 'inference/experimental_tflite_classifier.dart';
import 'inference/potato_field_tflite_classifier.dart';
import 'inference/crop_suggestion.dart';

/// Release builds use the genuine but explicitly experimental TFLite model.
///
/// Debug/widget tests keep the deterministic sample by default so they never
/// depend on a native FFI library. A device debug build can opt in with
/// `--dart-define=KRISHIDOC_EXPERIMENTAL_MODEL=true`.
const bool useExperimentalPlantModel = bool.fromEnvironment(
  'KRISHIDOC_EXPERIMENTAL_MODEL',
  defaultValue: kReleaseMode,
);

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

/// Work and questions saved on this device, newest first.
final recentFarmTasksProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(servicesProvider).farmTaskStore.watchRecent(),
);

/// The model pack for a crop, or null when that crop is not covered.
///
/// Null is a first-class answer, not an error. Coverage is finite (D-49 pins
/// launch scope at three crops) and the honest response to a crop we do not
/// cover is to say so, never to run another crop's pack against the photo.
final modelPackProvider = Provider.family<ModelPack?, String>((ref, cropKey) {
  if (!useExperimentalPlantModel) return SamplePacks.forCrop(cropKey);
  if (cropKey == 'potato') return PotatoFieldResearchPack.pack;
  return ExperimentalPlantPack.forCrop(cropKey);
});

/// Native runtime behind an overridable seam for device and contract tests.
final experimentalTensorRunnerProvider = Provider<ExperimentalTensorRunner>((
  ref,
) {
  final runner = TfliteExperimentalTensorRunner();
  ref.onDispose(() => unawaited(runner.dispose()));
  return runner;
});

final experimentalPlantClassifierProvider = Provider<ImageClassifier>((ref) {
  return ExperimentalTfliteClassifier(
    runner: ref.watch(experimentalTensorRunnerProvider),
  );
});

/// Auto mode suggests a crop for confirmation; a manual choice can override it.
final autoDetectCropProvider = StateProvider<bool>((ref) => true);
typedef CropSuggestion = Future<String?> Function(Uint8List image);
final cropSuggestionProvider = Provider<CropSuggestion>((ref) {
  if (!useExperimentalPlantModel) return (image) async => null;
  return CropSuggestionService(
    ref.watch(experimentalPlantClassifierProvider),
  ).suggest;
});

/// Potato-specific dual-head field-model runtime.
///
/// This provider is lazy: selecting tomato or maize never allocates the second
/// interpreter or loads its 16 MB model asset.
final potatoFieldTensorRunnerProvider = Provider<PotatoFieldTensorRunner>((
  ref,
) {
  final runner = TflitePotatoFieldTensorRunner();
  ref.onDispose(() => unawaited(runner.dispose()));
  return runner;
});

final potatoFieldClassifierProvider = Provider<ImageClassifier>((ref) {
  return PotatoFieldTfliteClassifier(
    runner: ref.watch(potatoFieldTensorRunnerProvider),
  );
});

/// The on-device classification path for a crop.
///
/// Release output is a possible match from a genuine on-device model, never a
/// confident result. Potato uses the field-trained dual-head model and its
/// calibrated validity/OOD gate. Tomato and maize retain the globally scored,
/// crop-scoped PlantVillage model. Neither path has passed a locked Nepal field
/// evaluation, and neither may provide treatment or chemical advice.
///
/// Debug output remains the D-52 sample unless explicitly opted into the
/// experimental model, and every sample surface must still show its notice.
final classificationServiceProvider =
    Provider.family<ClassificationService?, String>((ref, cropKey) {
      final pack = ref.watch(modelPackProvider(cropKey));
      if (pack == null) return null;
      if (useExperimentalPlantModel) {
        if (cropKey == 'potato') {
          return ClassificationService(
            classifier: ref.watch(potatoFieldClassifierProvider),
            pack: pack,
          );
        }
        final allowed = ExperimentalPlantPack.allowedLabelsForCrop(cropKey);
        if (allowed == null) return null;
        return ClassificationService(
          classifier: ref.watch(experimentalPlantClassifierProvider),
          pack: pack,
          allowedLabelKeys: allowed,
        );
      }
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

typedef CameraSessionFactory = CameraSession Function();

/// Creates one real camera session per capture-screen lifetime.
///
/// A session cannot be an app-scoped singleton: final teardown closes its
/// frame stream, and reusing that object on a later visit leaves the quality
/// gate with no frames and the shutter disabled forever. Tests override the
/// factory with scriptable sessions, so every decision remains testable
/// without hardware.
final cameraSessionProvider = Provider<CameraSessionFactory>(
  (ref) => PlatformCameraSession.new,
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
