import 'dart:async';
import 'dart:typed_data';

import 'package:capture/capture.dart';
import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../providers.dart';
import '../router.dart';
import 'camera_session.dart';

/// Pre-capture screen: live coaching from the quality gate (D-16), the
/// remembered crop as a one-tap chip, and a shutter that stays disabled
/// until the frame is worth classifying.
///
/// Reachable only in debug builds until inference exists: a shutter that
/// leads nowhere would be exactly the dead-end UI this rebuild exists to
/// avoid.
/// The shutter, exposed so tests can assert on its enabled state.
const Key shutterKey = Key('capture.shutter');

/// What the shutter leads to.
///
/// The split exists because the two outcomes have different truth conditions.
/// A notebook entry asserts only that this photograph was taken today; a
/// diagnosis asserts something about the plant. ADR-0052 governs the second
/// and has nothing to say about the first, which is why one of them can ship
/// in a release build today and the other cannot.
enum CaptureMode {
  /// Keep the photograph with a date. No model involved, no claim made.
  notebook,

  /// Classify it. Debug only until a trained model exists, because every
  /// answer it can produce today is a hash of the image bytes.
  diagnose,
}

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({this.mode = CaptureMode.notebook, super.key});

  final CaptureMode mode;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen> {
  static const QualityGate _gate = QualityGate();

  /// Held rather than read from `ref` on demand: `dispose` must be able to
  /// stop the camera without touching a container that may already be gone.
  late final CameraSession _session;
  StreamSubscription<LumaFrame>? _frames;
  CaptureQuality? _quality;
  bool _cameraFailed = false;
  bool _isCapturing = false;
  bool _failed = false;
  DateTime? _lastAssessment;

  @override
  void initState() {
    super.initState();
    _session = ref.read(cameraSessionProvider);
    unawaited(_startCamera());
  }

  Future<void> _startCamera() async {
    try {
      await _session.start();
    } catch (_) {
      // Permission refused or no camera: an honest error state, never a
      // frozen preview the farmer waits on.
      if (mounted) setState(() => _cameraFailed = true);
      return;
    }
    if (!mounted) return;
    _frames = _session.frames.listen(_onFrame);
  }

  void _onFrame(LumaFrame frame) {
    final interval = ref.read(frameAssessmentIntervalProvider);
    final now = DateTime.now();
    final last = _lastAssessment;
    if (last != null && now.difference(last) < interval) {
      return; // Frame skipping keeps the gate inside its budget.
    }
    _lastAssessment = now;

    final quality = _gate.assess(
      frame.luminance,
      width: frame.width,
      height: frame.height,
      bytesPerRow: frame.bytesPerRow,
    );
    if (mounted) setState(() => _quality = quality);
  }

  Future<void> _capture() async {
    // Fired before any await, so the confirmation arrives with the tap rather
    // than with the result of the tap. Without it the wait that follows reads
    // as "nothing happened" and the second tap is inevitable.
    unawaited(KdHaptics.shutter());
    setState(() {
      _isCapturing = true;
      _failed = false;
    });
    try {
      final crop = ref.read(selectedCropProvider).valueOrNull;
      final original = await _session.capturePhoto();
      final prepared = await ref.read(imagePreparationProvider)(original);
      final isDiagnosis = widget.mode == CaptureMode.diagnose;
      final id = isDiagnosis
          ? await _diagnose(crop: crop, prepared: prepared)
          : await _observe(crop: crop, prepared: prepared);
      if (!mounted) return;
      unawaited(KdHaptics.completed());
      // `push`, not `go`: backing out returns to the camera, which is where a
      // farmer who wants a second photograph already is.
      await context.push(
        isDiagnosis
            ? '${AppRoutes.resultBase}/$id'
            : '${AppRoutes.notebook}/$id',
      );
    } catch (_) {
      // Previously a bare try/finally, so a failed capture was indistinguishable
      // from the app ignoring the tap. A failure the farmer cannot see is a
      // failure they will blame themselves for.
      unawaited(KdHaptics.refused());
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  /// Stores the photo and writes a notebook entry. Returns its id.
  ///
  /// Nothing here consults a model, so nothing here can be wrong about a
  /// plant. That is the whole reason this path can reach a farmer today while
  /// the diagnosis path cannot.
  Future<String> _observe({
    required Crop? crop,
    required Uint8List prepared,
  }) async {
    final services = ref.read(servicesProvider);
    final id = services.ids.newId();
    // The photo is written first and the row second, so a row can never point
    // at a file that was never created. The reverse order would leave a
    // notebook entry with nothing behind it after a process death.
    final path = await ref.read(photoStoreProvider).save(id, prepared);
    await services.observationStore.upsert(
      Observation(
        id: id,
        imagePath: path,
        createdAt: DateTime.now().toUtc(),
        cropKey: crop?.key,
      ),
    );
    return id;
  }

  /// Classifies, stores the photo, and writes the record. Returns its id.
  ///
  /// The write happens before navigation on purpose: the result screen reads
  /// the stored record rather than being handed one, so History and the result
  /// can never disagree about what was decided, and a process death between
  /// the two loses nothing.
  Future<String> _diagnose({
    required Crop? crop,
    required Uint8List prepared,
  }) async {
    final services = ref.read(servicesProvider);
    final id = services.ids.newId();
    final cropKey = crop?.key;
    final service = cropKey == null
        ? null
        : ref.read(classificationServiceProvider(cropKey));

    final path = await ref.read(photoStoreProvider).save(id, prepared);

    if (service == null) {
      // No pack for this crop. Recorded honestly as outside coverage rather
      // than run through another crop's model, which would produce a confident
      // answer about a plant we have never trained on.
      await services.diagnosisStore.upsert(
        DiagnosisRecord(
          id: id,
          state: ResultState.outOfScope,
          cropKey: cropKey,
          predictions: const [],
          modelVersion: 'none',
          imagePath: path,
          createdAt: DateTime.now().toUtc(),
        ),
      );
      return id;
    }

    final outcome = await service.classify(prepared);
    await services.diagnosisStore.upsert(
      DiagnosisRecord(
        id: id,
        state: outcome.state,
        cropKey: cropKey,
        predictions: [
          for (final ranked in outcome.ranked)
            TopPrediction(label: ranked.label, confidence: ranked.probability),
        ],
        modelVersion: outcome.modelVersion,
        imagePath: path,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    return id;
  }

  @override
  void dispose() {
    unawaited(_frames?.cancel());
    unawaited(_session.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quality = _quality;
    final canCapture = quality != null && quality.isAcceptable && !_isCapturing;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.captureTitle)),
      body: _cameraFailed
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(KdSpacing.lg),
                child: Text(
                  l10n.cameraUnavailable,
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _session.buildPreview(context),
                      Positioned(
                        left: KdSpacing.md,
                        right: KdSpacing.md,
                        bottom: KdSpacing.md,
                        child: _CoachingBanner(quality: quality),
                      ),
                    ],
                  ),
                ),
                // `targetSdk 35` makes Android 15 draw edge to edge with no
                // opt-out, and Scaffold keeps the inset in its MediaQuery
                // without applying it to the body box. Measured before this
                // was added: the shutter had 16dp of bottom clearance, so 32
                // of its 48dp sat behind a three-button navigation bar and
                // its lower edge fell inside the gesture exclusion zone.
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(KdLayout.pageGutter),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _CropChip(),
                        const SizedBox(height: KdSpacing.md),
                        FilledButton.icon(
                          // Stable handle for tests: the `.icon` factory
                          // builds a private subclass, which `find.byType`
                          // cannot match because it compares exact runtime
                          // types.
                          key: shutterKey,
                          onPressed: canCapture ? _capture : null,
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: Text(l10n.shutterLabel),
                        ),
                        if (_failed)
                          Padding(
                            padding: const EdgeInsets.only(top: KdSpacing.smd),
                            child: Text(
                              // Inline and persistent, never a snackbar. The
                              // one message that must not evaporate after four
                              // seconds is the explanation of a failure.
                              l10n.diagnosisFailed,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: KdColors.danger),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Turns gate findings into one piece of advice. Farmers get the single most
/// useful instruction, not a list of faults.
class _CoachingBanner extends StatelessWidget {
  const _CoachingBanner({required this.quality});

  final CaptureQuality? quality;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = quality;

    final (message, isReady) = switch (current) {
      null => (l10n.coachHoldStill, false),
      _ when current.isAcceptable => (l10n.coachReady, true),
      // Order matters: exposure is the fixable-by-moving problem, so it is
      // named before blur when both are wrong.
      _ when current.issues.contains(CaptureIssue.tooDark) => (
        l10n.coachTooDark,
        false,
      ),
      _ when current.issues.contains(CaptureIssue.tooBright) => (
        l10n.coachTooBright,
        false,
      ),
      _ => (l10n.coachTooBlurry, false),
    };

    return Semantics(
      // The coaching line changes without the user touching anything, and it
      // is the only thing that explains why the shutter is refusing them.
      // Without liveRegion, TalkBack announces neither "hold steady" nor
      // "ready", so a blind or low-vision user gets a button that silently
      // toggles for reasons never spoken aloud.
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            // Opaque, not 85 percent. This floats over live video, and a
            // translucent fill has no contrast ratio at all: what it is
            // legible against depends on whatever leaf or sky happens to be
            // behind it that frame.
            color: isReady ? KdColors.coachReadyFill : KdColors.coachBusyFill,
            borderRadius: BorderRadius.circular(KdRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: KdSpacing.md,
              vertical: KdSpacing.smd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  // Glyph and words carry readiness, because the two fills
                  // cannot: both must stay dark enough for white text, which
                  // caps them at about 1.95:1 apart. The large signal is the
                  // shutter arming underneath.
                  isReady ? Icons.check_circle_outline : Icons.info_outline,
                  color: KdColors.coachInk,
                  size: kdScaledIcon(context, KdIconSize.md),
                ),
                const SizedBox(width: KdSpacing.smd),
                Flexible(
                  child: Text(
                    message,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: KdColors.coachInk,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The remembered crop, changeable in one tap (D-16): never a gate in front
/// of the camera.
class _CropChip extends ConsumerWidget {
  const _CropChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(selectedCropProvider);

    return selected.when(
      loading: () => const SizedBox(height: KdSpacing.minTouchTarget),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (crop) => Align(
        child: ActionChip(
          avatar: const Icon(Icons.spa_outlined),
          label: Text('${l10n.cropLabel}: ${cropName(l10n, crop)}'),
          onPressed: () => _showCropPicker(context, ref, crop),
        ),
      ),
    );
  }

  Future<void> _showCropPicker(
    BuildContext context,
    WidgetRef ref,
    Crop current,
  ) async {
    final l10n = AppLocalizations.of(context);
    final crops = ref.read(cropCatalogProvider).available;

    final chosen = await showModalBottomSheet<Crop>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Without a title the sheet announces itself as the generic
            // "Dialog" and gives no clue what the list is for.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                KdLayout.pageGutter,
                0,
                KdLayout.pageGutter,
                KdSpacing.sm,
              ),
              child: Text(
                l10n.cropLabel,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final crop in crops)
              ListTile(
                title: Text(cropName(l10n, crop)),
                selected: crop == current,
                trailing: crop == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(crop),
              ),
          ],
        ),
      ),
    );

    if (chosen != null && chosen != current) {
      unawaited(KdHaptics.selected());
      await ref.read(selectedCropProvider.notifier).select(chosen);
    }
  }
}

/// Crop display names live in ARB only until the reviewed KB supplies them
/// (D-35); an unknown key degrades to the key itself rather than blanking.
String cropName(AppLocalizations l10n, Crop crop) => switch (crop.key) {
  'tomato' => l10n.cropTomato,
  'potato' => l10n.cropPotato,
  'maize' => l10n.cropMaize,
  _ => crop.key,
};
