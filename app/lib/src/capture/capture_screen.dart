import 'dart:async';

import 'package:capture/capture.dart';
import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/gen/app_localizations.dart';
import '../providers.dart';
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

class CaptureScreen extends ConsumerStatefulWidget {
  const CaptureScreen({super.key});

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
  int? _preparedBytes;
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
    setState(() {
      _isCapturing = true;
      _preparedBytes = null;
    });
    try {
      final original = await _session.capturePhoto();
      final prepared = await ref.read(imagePreparationProvider)(original);
      if (mounted) setState(() => _preparedBytes = prepared.length);
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
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
                Padding(
                  padding: const EdgeInsets.all(KdSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _CropChip(),
                      const SizedBox(height: KdSpacing.md),
                      FilledButton.icon(
                        // Stable handle for tests: the `.icon` factory builds
                        // a private subclass, which `find.byType` cannot
                        // match because it compares exact runtime types.
                        key: shutterKey,
                        onPressed: canCapture ? _capture : null,
                        icon: const Icon(Icons.photo_camera),
                        label: Text(l10n.shutterLabel),
                      ),
                      if (_preparedBytes != null)
                        Padding(
                          padding: const EdgeInsets.only(top: KdSpacing.sm),
                          child: Text(
                            // Developer readout: this screen is debug-only
                            // until a diagnosis can follow the capture.
                            'Prepared $_preparedBytes bytes',
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
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

    return DecoratedBox(
      decoration: BoxDecoration(
        color: (isReady ? KdColors.primary : KdColors.textPrimary).withValues(
          alpha: 0.85,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.sm),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isReady ? Icons.check_circle : Icons.info_outline,
              color: KdColors.onPrimary,
            ),
            const SizedBox(width: KdSpacing.sm),
            Flexible(
              child: Text(
                message,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: KdColors.onPrimary,
                ),
              ),
            ),
          ],
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
          children: [
            for (final crop in crops)
              ListTile(
                title: Text(cropName(l10n, crop)),
                trailing: crop == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(crop),
              ),
          ],
        ),
      ),
    );

    if (chosen != null && chosen != current) {
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
