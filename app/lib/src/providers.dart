import 'dart:isolate';
import 'dart:typed_data';

import 'package:capture/capture.dart';
import 'package:core_domain/core_domain.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_services.dart';
import 'capture/camera_session.dart';
import 'capture/launch_crop_catalog.dart';

/// Overridden at the root (main or test pump); reading it unoverridden is a
/// wiring bug and fails loudly.
final servicesProvider = Provider<AppServices>(
  (ref) => throw StateError('servicesProvider must be overridden at the root'),
);

/// Newest-first window of stored diagnoses for the History screen.
final recentDiagnosesProvider = StreamProvider.autoDispose(
  (ref) => ref.watch(servicesProvider).diagnosisStore.watchRecent(),
);

final cropCatalogProvider = Provider<CropCatalog>(
  (ref) => const LaunchCropCatalog(),
);

/// Overridden with the platform camera once one exists; tests supply a fake.
final cameraSessionProvider = Provider<CameraSession>(
  (ref) => throw StateError('cameraSessionProvider must be overridden'),
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
