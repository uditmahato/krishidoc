import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inference/inference.dart';

import '../../l10n/gen/app_localizations.dart';
import '../providers.dart';
import '../router.dart';
import 'certainty.dart';
import 'diagnosis_presenter.dart';
import 'sample_notice.dart';

/// What the shutter finally leads to.
///
/// The screen is addressed by record id and reads the store, rather than being
/// handed a diagnosis to render. That is the seam that keeps this screen and
/// History from ever disagreeing about what was decided, and it means a process
/// death between the write and the push loses nothing: the record is already
/// durable before this screen exists.
class ResultScreen extends ConsumerWidget {
  const ResultScreen({required this.diagnosisId, super.key});

  final String diagnosisId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final record = ref.watch(diagnosisByIdProvider(diagnosisId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resultTitle)),
      body: record.when(
        loading: () => _Pending(message: l10n.checking),
        error: (error, stackTrace) => _Stated(message: l10n.errorGeneric),
        // A missing record is not an empty result, it is a broken link, and it
        // is stated as an error rather than drawn as a blank card. Rendering
        // nothing here would read to a farmer as "your leaf is fine".
        data: (value) => value == null
            ? _Stated(message: l10n.errorGeneric)
            : _Result(record: value),
      ),
    );
  }
}

class _Pending extends StatelessWidget {
  const _Pending({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(KdLayout.pageGutter),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(KdSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const KdIconWell(icon: Icons.document_scanner_outlined),
              const SizedBox(height: KdSpacing.md),
              const CircularProgressIndicator(),
              const SizedBox(height: KdSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Stated extends StatelessWidget {
  const _Stated({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(KdLayout.pageGutter),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(KdSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              KdIconWell(
                icon: Icons.error_outline,
                backgroundColor: Theme.of(context).colorScheme.errorContainer,
                foregroundColor: KdColors.danger,
              ),
              const SizedBox(height: KdSpacing.md),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: KdColors.danger),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Result extends ConsumerWidget {
  const _Result({required this.record});

  final DiagnosisRecord record;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final cropKey = record.cropKey;
    final cropLabel = _cropLabel(l10n, cropKey);

    // The pack is read only to recover the certainty band. `certaintyFor`
    // refuses to reinterpret a probability against thresholds that have since
    // moved, so handing it a mismatched pack degrades to the most cautious
    // band rather than to a flattering one.
    final pack = cropKey == null ? null : ref.watch(modelPackProvider(cropKey));

    final presentation = presentDiagnosis(
      record: record,
      l10n: l10n,
      certainty: certaintyFor(record, pack),
      onEscalate: () => _openAssistant(context, ref),
      onCorrect: () => context.push(AppRoutes.diagnose),
      // Reachable only for an unreadable photo, which the resolver does not
      // currently produce. Popping returns to the camera the result was
      // pushed from.
      onRetry: () => context.pop(),
    );

    final imagePath = record.imagePath;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KdLayout.pageGutter,
        KdLayout.pageGutter,
        KdLayout.pageGutter,
        KdLayout.scrollBottomInset,
      ),
      children: [
        // First, above the answer, and not dismissable (D-52). A farmer who
        // reads only the first line must read this one.
        if (isSampleModelVersion(record.modelVersion)) ...[
          const SampleNotice(),
          const SizedBox(height: KdLayout.itemGap),
        ],
        if (isExperimentalModelVersion(record.modelVersion)) ...[
          const ExperimentalModelNotice(),
          const SizedBox(height: KdLayout.itemGap),
        ],
        if (cropLabel != null) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: KdStatusPill(
              icon: Icons.spa_outlined,
              label: l10n.diseaseSelectedCrop(cropLabel),
            ),
          ),
          const SizedBox(height: KdLayout.itemGap),
        ],
        if (imagePath != null) ...[
          _Photo(path: imagePath),
          const SizedBox(height: KdLayout.itemGap),
        ],
        DiagnosisResultView(presentation: presentation),
        const SizedBox(height: KdLayout.itemGap),
        Align(
          child: KdStatusPill(
            icon: Icons.offline_pin_outlined,
            label: l10n.savedOffline,
            backgroundColor: KdColors.surfaceSunken,
            foregroundColor: KdColors.inkMuted,
          ),
        ),
      ],
    );
  }

  Future<void> _openAssistant(BuildContext context, WidgetRef ref) async {
    final crop = record.cropKey == null
        ? null
        : ref.read(cropCatalogProvider).byKey(record.cropKey);
    if (crop != null) {
      await ref.read(selectedCropProvider.notifier).select(crop);
    }
    if (context.mounted) {
      final parameters = <String, String>{};
      if (record.cropKey case final cropKey?) {
        parameters['crop'] = cropKey;
      }
      if (record.predictions case [final top, ...]) {
        parameters['candidate'] = top.label;
      }
      await context.push(
        Uri(
          path: AppRoutes.assistant,
          queryParameters: parameters.isEmpty ? null : parameters,
        ).toString(),
      );
    }
  }
}

/// The leaf that was photographed.
///
/// Shown so the farmer can see which plant this answer is about; a result with
/// no photograph is indistinguishable from a result about the wrong plant.
class _Photo extends ConsumerWidget {
  const _Photo({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(diagnosisPhotoProvider(path));

    return bytes.maybeWhen(
      // An absent or unreadable file collapses to nothing rather than to a
      // broken-image glyph. Android reclaims app storage under pressure, so
      // this is an ordinary outcome, and the diagnosis is still the point of
      // the screen.
      data: (data) => data == null
          ? const SizedBox.shrink()
          : Card(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: Image.memory(
                  data,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  // Required, not defensive: without it a file that decodes to
                  // nothing throws during paint and takes the whole result
                  // down with it, losing the diagnosis over a thumbnail.
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

String? _cropLabel(AppLocalizations l10n, String? cropKey) => switch (cropKey) {
  'tomato' => l10n.cropTomato,
  'potato' => l10n.cropPotato,
  'maize' => l10n.cropMaize,
  _ => null,
};
