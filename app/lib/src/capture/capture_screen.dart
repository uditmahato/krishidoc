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
import 'gallery_source.dart';
import 'photo_review.dart';

/// Pre-capture screen: live coaching from the quality gate (D-16), the
/// remembered crop as a one-tap chip, and a shutter that stays disabled
/// until the frame is worth classifying.
///
/// The shutter, exposed so tests can assert on its enabled state.
const Key shutterKey = Key('capture.shutter');
const Key galleryKey = Key('capture.gallery');
const Set<String> kDiseaseScanCropKeys = {'tomato', 'potato', 'maize'};

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

  /// Classify it with the explicitly experimental on-device model.
  diagnose,
}

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({this.mode = CaptureMode.notebook, super.key});

  final CaptureMode mode;

  @override
  ConsumerState<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends ConsumerState<CaptureScreen>
    with WidgetsBindingObserver {
  static const QualityGate _gate = QualityGate();

  /// Held rather than read from `ref` on demand: `dispose` must be able to
  /// stop the camera without touching a container that may already be gone.
  late final CameraSession _session;
  StreamSubscription<LumaFrame>? _frames;
  CaptureQuality? _quality;
  bool _cameraFailed = false;
  bool _isCapturing = false;
  bool _failed = false;
  String? _photoError;
  bool _recoveringGallery = true;
  bool _reviewingPhoto = false;
  bool _appIsResumed = true;
  bool _routePaused = false;
  bool? _cameraDemand;
  DateTime? _lastAssessment;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final lifecycleState = WidgetsBinding.instance.lifecycleState;
    _appIsResumed =
        lifecycleState == null || lifecycleState == AppLifecycleState.resumed;
    _cameraDemand = _appIsResumed;
    _session = ref.read(cameraSessionProvider)();
    unawaited(_startCamera());
    unawaited(_recoverGallery());
  }

  Future<void> _recoverGallery() async {
    Uint8List? recovered;
    try {
      recovered = await ref.read(gallerySourceProvider).recover();
    } catch (_) {
      // Recovery failure must not prevent a fresh camera or gallery attempt.
    } finally {
      if (mounted) setState(() => _recoveringGallery = false);
    }
    if (recovered != null && mounted && !_isCapturing) {
      await _capture(fromGallery: true, recovered: recovered);
    }
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
    // The permission dialog can outlive the app's foreground state. If the
    // app was backgrounded while start awaited Android, do not leave the
    // sensor open behind another app.
    if (!_appIsResumed || _routePaused) {
      try {
        await _session.pause();
      } catch (_) {
        if (mounted) setState(() => _cameraFailed = true);
      }
    }
    if (!mounted) return;
    _frames = _session.frames.listen(_onFrame);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isResumed = state == AppLifecycleState.resumed;
    if (_appIsResumed == isResumed) return;
    _appIsResumed = isResumed;
    unawaited(_syncCameraDemand());
  }

  Future<void> _syncCameraDemand() async {
    final shouldBeActive = _appIsResumed && !_routePaused;
    if (_cameraDemand == shouldBeActive) return;
    _cameraDemand = shouldBeActive;

    if (mounted) {
      setState(() {
        _quality = null;
        if (shouldBeActive) _cameraFailed = false;
      });
    }
    try {
      if (shouldBeActive) {
        await _session.resume();
      } else {
        await _session.pause();
      }
      if (mounted) setState(() {});
    } catch (_) {
      _cameraDemand = null;
      if (mounted && shouldBeActive) {
        setState(() => _cameraFailed = true);
      }
    }
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

  Future<void> _capture({
    bool fromGallery = false,
    Uint8List? recovered,
  }) async {
    if (_isCapturing) return;
    // Fired before any await, so the confirmation arrives with the tap rather
    // than with the result of the tap. Without it the wait that follows reads
    // as "nothing happened" and the second tap is inevitable.
    unawaited(KdHaptics.shutter());
    setState(() {
      _isCapturing = true;
      _failed = false;
      _photoError = null;
    });
    try {
      var crop = ref.read(selectedCropProvider).valueOrNull;
      if (fromGallery) {
        _routePaused = true;
        await _syncCameraDemand();
      }
      if (!mounted) return;
      final original = fromGallery
          ? recovered ?? await ref.read(gallerySourceProvider).pick()
          : await _session.capturePhoto();
      if (original == null || !mounted) return;
      // The result is pushed over this route, so dispose the active hardware
      // before doing the slower preparation/inference work. The screen keeps
      // its frame subscription and reacquires the sensor only if the farmer
      // returns here.
      _routePaused = true;
      await _syncCameraDemand();
      if (!mounted) return;
      final prepared = await ref.read(imagePreparationProvider)(original);
      if (!mounted) return;
      final isDiagnosis = widget.mode == CaptureMode.diagnose;
      var blurWarning = false;
      if (fromGallery && isDiagnosis) {
        final quality = await ref.read(galleryQualityProvider)(prepared);
        if (!mounted) return;
        if (quality.issues.contains(CaptureIssue.tooDark) ||
            quality.issues.contains(CaptureIssue.tooBright)) {
          setState(
            () => _photoError = AppLocalizations.of(context).galleryPhotoPoor,
          );
          return;
        }
        // A global edge score can flag a detailed leaf with a plain background
        // as blurry. Offer explicit review, not an uncalibrated hard veto.
        blurWarning = quality.issues.contains(CaptureIssue.tooBlurry);
      }
      final automatic = isDiagnosis && ref.read(autoDetectCropProvider);
      if (isDiagnosis && (automatic || fromGallery)) {
        String? suggestion = automatic ? null : crop?.key;
        if (automatic && !blurWarning) {
          try {
            suggestion = await ref.read(cropSuggestionProvider)(prepared);
          } catch (_) {
            // Crop recognition is optional; the farmer can still choose a crop
            // if this model is unavailable. Disease inference errors stay fatal.
          }
        }
        if (!mounted) return;
        setState(() => _reviewingPhoto = true);
        final chosen = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (_) => PhotoReviewSheet(
            image: prepared,
            initialCrop: suggestion,
            automatic: automatic && !blurWarning,
            blurWarning: blurWarning,
          ),
        );
        if (mounted) setState(() => _reviewingPhoto = false);
        if (chosen == null || !mounted) return;
        crop = ref.read(cropCatalogProvider).byKey(chosen);
        if (crop == null) return;
      }
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
      if (mounted) {
        setState(() {
          if (fromGallery) {
            _photoError = AppLocalizations.of(context).galleryImportFailed;
          } else {
            _failed = true;
          }
        });
      }
    } finally {
      if (_routePaused) {
        _routePaused = false;
        if (mounted) await _syncCameraDemand();
      }
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _reviewingPhoto = false;
        });
      }
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
    final photos = ref.read(photoStoreProvider);
    final path = await photos.save(id, prepared);
    try {
      await services.observationStore.upsert(
        Observation(
          id: id,
          imagePath: path,
          createdAt: DateTime.now().toUtc(),
          cropKey: crop?.key,
        ),
      );
    } catch (_) {
      // The row is the owner of the derivative. If its durable write fails,
      // roll the file back so repeated attempts do not leak orphan photos.
      try {
        await photos.delete(path);
      } catch (_) {}
      rethrow;
    }
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

    // Run inference before retaining the derivative. A model/runtime failure
    // therefore cannot leave a photo that has no diagnosis record.
    final outcome = await service?.classify(prepared);
    final photos = ref.read(photoStoreProvider);
    final path = await photos.save(id, prepared);
    try {
      await services.diagnosisStore.upsert(
        DiagnosisRecord(
          id: id,
          state: outcome?.state ?? ResultState.outOfScope,
          cropKey: cropKey,
          predictions: [
            if (outcome != null)
              for (final ranked in outcome.ranked)
                TopPrediction(
                  label: ranked.label,
                  confidence: ranked.probability,
                ),
          ],
          modelVersion: outcome?.modelVersion ?? 'none',
          thresholdSetVersion: outcome?.thresholdSetVersion ?? 'none',
          imagePath: path,
          createdAt: DateTime.now().toUtc(),
        ),
      );
    } catch (_) {
      try {
        await photos.delete(path);
      } catch (_) {}
      rethrow;
    }
    return id;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_frames?.cancel());
    unawaited(_session.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final quality = _quality;
    final canCapture = quality != null && quality.isAcceptable && !_isCapturing;
    final automatic =
        widget.mode == CaptureMode.diagnose &&
        ref.watch(autoDetectCropProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF090B08),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090B08),
        foregroundColor: KdColors.onPrimary,
        shape: const Border(
          bottom: BorderSide(color: Color(0xFF252920), width: 1),
        ),
        title: Text(
          widget.mode == CaptureMode.diagnose
              ? l10n.diseaseCaptureTitle
              : l10n.captureTitle,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: KdColors.onPrimary),
        ),
      ),
      bottomNavigationBar: _CaptureControls(
        canCapture: canCapture && !_cameraFailed,
        isDiagnosis: widget.mode == CaptureMode.diagnose,
        onCapture: _capture,
        onGallery: _isCapturing || _recoveringGallery
            ? null
            : () => _capture(fromGallery: true),
      ),
      body: _cameraFailed
          ? _isCapturing && !_reviewingPhoto
                ? _CaptureProgressOverlay(message: l10n.checking)
                : _CameraUnavailableView(error: _photoError)
          : Stack(
              fit: StackFit.expand,
              children: [
                _session.buildPreview(context),
                _ViewfinderGuides(isReady: canCapture),
                Positioned(
                  top: KdSpacing.md,
                  left: KdSpacing.md,
                  right: KdSpacing.md,
                  child: Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.mode == CaptureMode.diagnose)
                          FilterChip(
                            label: Text(l10n.autoDetectCrop),
                            selected: automatic,
                            onSelected: _isCapturing
                                ? null
                                : (value) =>
                                      ref
                                              .read(
                                                autoDetectCropProvider.notifier,
                                              )
                                              .state =
                                          value,
                          ),
                        if (!automatic)
                          _CropChip(
                            allowedCropKeys: widget.mode == CaptureMode.diagnose
                                ? kDiseaseScanCropKeys
                                : null,
                            enabled: !_isCapturing,
                          ),
                      ],
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.35,
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: _photoError != null || _failed
                            ? Text(
                                _photoError ?? l10n.diagnosisFailed,
                                style: const TextStyle(
                                  color: Color(0xFFFFDAD6),
                                  backgroundColor: Color(0xFF3A1818),
                                ),
                              )
                            : _CoachingBanner(quality: quality),
                      ),
                    ),
                  ),
                ),
                if (_isCapturing && !_reviewingPhoto)
                  _CaptureProgressOverlay(
                    message: widget.mode == CaptureMode.diagnose
                        ? l10n.checking
                        : l10n.shutterLabel,
                  ),
              ],
            ),
    );
  }
}

class _CameraUnavailableView extends StatelessWidget {
  const _CameraUnavailableView({this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(KdSpacing.lg),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF181B16),
              borderRadius: BorderRadius.circular(KdRadius.lg),
              border: Border.all(color: const Color(0xFF3C4237)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(KdSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Color(0xFF32201F),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(KdSpacing.md),
                      child: Icon(
                        Icons.no_photography_outlined,
                        color: const Color(0xFFFFB4AB),
                        size: kdScaledIcon(context, KdIconSize.lg),
                      ),
                    ),
                  ),
                  const SizedBox(height: KdSpacing.md),
                  Text(
                    l10n.cameraUnavailable,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: KdColors.onPrimary,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: KdSpacing.md),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Color(0xFFFFDAD6)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewfinderGuides extends StatelessWidget {
  const _ViewfinderGuides({required this.isReady});

  final bool isReady;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KdSpacing.xxl,
            KdSpacing.xxxl + KdSpacing.lg,
            KdSpacing.xxl,
            KdSpacing.xxxl + KdSpacing.lg,
          ),
          child: Center(
            child: AspectRatio(
              aspectRatio: 0.82,
              child: CustomPaint(
                painter: _ViewfinderPainter(isReady: isReady),
                child: Center(
                  child: Icon(
                    Icons.eco_outlined,
                    color: KdColors.onPrimary.withValues(alpha: 0.35),
                    size: kdScaledIcon(context, KdIconSize.xl),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter({required this.isReady});

  final bool isReady;

  @override
  void paint(Canvas canvas, Size size) {
    const corner = KdSpacing.xxl;
    const radius = Radius.circular(KdRadius.md);
    final path = Path()
      ..moveTo(0, corner)
      ..lineTo(0, KdRadius.md)
      ..arcToPoint(const Offset(KdRadius.md, 0), radius: radius)
      ..lineTo(corner, 0)
      ..moveTo(size.width - corner, 0)
      ..lineTo(size.width - KdRadius.md, 0)
      ..arcToPoint(Offset(size.width, KdRadius.md), radius: radius)
      ..lineTo(size.width, corner)
      ..moveTo(size.width, size.height - corner)
      ..lineTo(size.width, size.height - KdRadius.md)
      ..arcToPoint(
        Offset(size.width - KdRadius.md, size.height),
        radius: radius,
      )
      ..lineTo(size.width - corner, size.height)
      ..moveTo(corner, size.height)
      ..lineTo(KdRadius.md, size.height)
      ..arcToPoint(Offset(0, size.height - KdRadius.md), radius: radius)
      ..lineTo(0, size.height - corner);

    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x99000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = isReady ? const Color(0xFF8DDE8F) : KdColors.onPrimary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ViewfinderPainter oldDelegate) =>
      oldDelegate.isReady != isReady;
}

class _CaptureControls extends StatelessWidget {
  const _CaptureControls({
    required this.canCapture,
    required this.isDiagnosis,
    required this.onCapture,
    this.onGallery,
  });

  final bool canCapture;
  final bool isDiagnosis;
  final VoidCallback onCapture;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final label = isDiagnosis ? l10n.diseaseShutterLabel : l10n.shutterLabel;

    return ColoredBox(
      color: const Color(0xFF12170F),
      child: SafeArea(
        top: false,
        child: Padding(
          // Android 15 is edge-to-edge, so this inset is part of the actual
          // shutter hit target rather than decorative whitespace.
          padding: const EdgeInsets.fromLTRB(
            KdLayout.pageGutter,
            KdSpacing.md,
            KdLayout.pageGutter,
            KdLayout.pageGutter,
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: galleryKey,
                    onPressed: onGallery,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF293323),
                      side: const BorderSide(
                        color: Color(0xFFB6C8A6),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.photo_library_outlined, size: 30),
                        const SizedBox(height: 8),
                        Text(
                          l10n.galleryButtonLabel,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: KdSpacing.smd),
                Expanded(
                  child: FilledButton(
                    // This must remain a concrete FilledButton: widget tests read
                    // its enabled state directly through this stable key.
                    key: shutterKey,
                    onPressed: canCapture ? onCapture : null,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 14,
                      ),
                      minimumSize: const Size.fromHeight(KdSpacing.xxxl),
                      backgroundColor: KdColors.primary,
                      foregroundColor: KdColors.onPrimary,
                      disabledBackgroundColor: const Color(0xFF363B32),
                      disabledForegroundColor: const Color(0xFFC1C7BC),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(KdRadius.lg),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.document_scanner_outlined,
                          size: kdScaledIcon(context, KdIconSize.md),
                        ),
                        const SizedBox(height: KdSpacing.smd),
                        Text(
                          l10n.captureButtonLabel,
                          semanticsLabel: label,
                          textAlign: TextAlign.center,
                        ),
                      ],
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

class _CaptureProgressOverlay extends StatelessWidget {
  const _CaptureProgressOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message,
      child: ExcludeSemantics(
        child: ColoredBox(
          color: const Color(0xE611130F),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(KdSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox.square(
                    dimension: KdSpacing.xxl,
                    child: CircularProgressIndicator(
                      color: KdColors.onPrimary,
                      strokeWidth: 3,
                    ),
                  ),
                  const SizedBox(height: KdSpacing.lmd),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge?.copyWith(color: KdColors.onPrimary),
                  ),
                ],
              ),
            ),
          ),
        ),
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
  const _CropChip({this.allowedCropKeys, this.enabled = true});

  final Set<String>? allowedCropKeys;
  final bool enabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(selectedCropProvider);

    return selected.when(
      loading: () => const SizedBox(height: KdSpacing.minTouchTarget),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (crop) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: ActionChip(
          avatar: const Icon(Icons.spa_outlined, color: KdColors.primary),
          label: Text('${l10n.cropLabel}: ${cropName(l10n, crop)}'),
          labelStyle: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: KdColors.inkStrong),
          backgroundColor: const Color(0xF2FFFFFF),
          side: const BorderSide(color: KdColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(KdRadius.xl),
          ),
          onPressed: enabled ? () => _showCropPicker(context, ref, crop) : null,
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
    final crops = ref
        .read(cropCatalogProvider)
        .available
        .where(
          (crop) =>
              allowedCropKeys == null || allowedCropKeys!.contains(crop.key),
        )
        .toList(growable: false);

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
