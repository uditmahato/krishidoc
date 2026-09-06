import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../capture/capture_screen.dart' show cropName, kDiseaseScanCropKeys;
import '../providers.dart';
import '../router.dart';

const Key diseaseScanStartKey = Key('disease.scan.start');
const Key diseaseUseTomatoKey = Key('disease.crop.tomato');
const Key diseaseUsePotatoKey = Key('disease.crop.potato');

/// Honest entry point for the experimental on-device classifier.
///
/// The limitations are shown before the camera rather than buried below a
/// result. A farmer can therefore decide whether a possible match is useful
/// before giving the feature their time.
class DiseaseScanIntroScreen extends ConsumerWidget {
  const DiseaseScanIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final selected = ref.watch(selectedCropProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.diseaseScanTitle)),
      bottomNavigationBar: selected.when(
        loading: () => const _LoadingActionBar(),
        error: (error, stackTrace) => null,
        data: (crop) => kDiseaseScanCropKeys.contains(crop.key)
            ? _ScanActionBar(crop: crop)
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KdLayout.pageGutter,
          KdLayout.pageGutter,
          KdLayout.pageGutter,
          KdLayout.scrollBottomInset,
        ),
        children: [
          const _LeafScanHero(),
          const SizedBox(height: KdLayout.sectionGap),
          selected.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Text(l10n.errorGeneric),
            data: (crop) => _CropDecision(crop: crop),
          ),
          const SizedBox(height: KdLayout.sectionGap),
          const _PhotoPreparationCard(),
          const SizedBox(height: KdLayout.sectionGap),
          const _TrustPanel(),
        ],
      ),
    );
  }
}

class _LeafScanHero extends StatelessWidget {
  const _LeafScanHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: KdColors.primarySoft,
        borderRadius: BorderRadius.circular(KdRadius.hero),
        border: Border.all(color: KdColors.outlineSoft),
        boxShadow: KdElevation.raised,
      ),
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: KdSpacing.smd,
              runSpacing: KdSpacing.smd,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const _LeafScanEmblem(),
                KdStatusPill(
                  icon: Icons.biotech_outlined,
                  label: l10n.diseaseExperimentalTitle,
                  backgroundColor: KdColors.surface,
                  foregroundColor: KdColors.primaryPressed,
                ),
              ],
            ),
            const SizedBox(height: KdSpacing.lmd),
            Text(
              l10n.diseaseScanLead,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: KdColors.inkStrong,
                height: 1.25,
              ),
            ),
            const SizedBox(height: KdSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.eco_outlined,
                  size: kdScaledIcon(context, KdIconSize.sm),
                  color: KdColors.primaryPressed,
                ),
                const SizedBox(width: KdSpacing.sm),
                Expanded(
                  child: Text(
                    l10n.diseaseSupportedCrops,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: KdColors.inkBody,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LeafScanEmblem extends StatelessWidget {
  const _LeafScanEmblem();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: KdIconWell(
        icon: Icons.document_scanner_outlined,
        backgroundColor: KdColors.surface,
        foregroundColor: KdColors.primaryPressed,
        size: KdSpacing.xxxl,
      ),
    );
  }
}

class _CropDecision extends ConsumerWidget {
  const _CropDecision({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final supported = kDiseaseScanCropKeys.contains(crop.key);
    final automatic = ref.watch(autoDetectCropProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KdSectionHeader(
          title: automatic
              ? l10n.autoDetectCrop
              : l10n.diseaseSelectedCrop(cropName(l10n, crop)),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.autoDetectCrop),
          subtitle: Text(l10n.autoDetectCropHelp),
          value: automatic,
          onChanged: (value) =>
              ref.read(autoDetectCropProvider.notifier).state = value,
        ),
        const SizedBox(height: KdSpacing.smd),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(KdLayout.cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KdIconWell(icon: Icons.spa_outlined),
                const SizedBox(width: KdSpacing.smd),
                Expanded(
                  child: Wrap(
                    spacing: KdSpacing.sm,
                    runSpacing: KdSpacing.sm,
                    children: [
                      ChoiceChip(
                        key: diseaseUseTomatoKey,
                        label: Text(l10n.cropTomato),
                        selected: !automatic && crop.key == 'tomato',
                        onSelected: (_) => _select(ref, 'tomato'),
                      ),
                      ChoiceChip(
                        key: diseaseUsePotatoKey,
                        label: Text(l10n.cropPotato),
                        selected: !automatic && crop.key == 'potato',
                        onSelected: (_) => _select(ref, 'potato'),
                      ),
                      ChoiceChip(
                        label: Text(l10n.cropMaize),
                        selected: !automatic && crop.key == 'maize',
                        onSelected: (_) => _select(ref, 'maize'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!supported) ...[
          const SizedBox(height: KdSpacing.smd),
          _InformationCard(
            icon: Icons.info_outline,
            title: l10n.diseaseMaizeUnavailable,
            body: l10n.diseaseChooseSupportedCrop,
            color: KdColors.stateOutOfScopeRail,
          ),
        ],
      ],
    );
  }

  Future<void> _select(WidgetRef ref, String key) async {
    ref.read(autoDetectCropProvider.notifier).state = false;
    final crop = ref.read(cropCatalogProvider).byKey(key);
    if (crop != null) {
      await ref.read(selectedCropProvider.notifier).select(crop);
    }
  }
}

class _PhotoPreparationCard extends StatelessWidget {
  const _PhotoPreparationCard();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        KdSectionHeader(title: l10n.diseaseCaptureTitle),
        const SizedBox(height: KdSpacing.smd),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(KdLayout.cardPadding),
            child: Column(
              children: [
                _PreparationTip(
                  icon: Icons.center_focus_strong_outlined,
                  text: l10n.coachTooBlurry,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: KdSpacing.smd),
                  child: Divider(),
                ),
                _PreparationTip(
                  icon: Icons.light_mode_outlined,
                  text: l10n.coachTooDark,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: KdSpacing.smd),
                  child: Divider(),
                ),
                _PreparationTip(
                  icon: Icons.wb_sunny_outlined,
                  text: l10n.coachTooBright,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PreparationTip extends StatelessWidget {
  const _PreparationTip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        KdIconWell(icon: icon),
        const SizedBox(width: KdSpacing.smd),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _TrustPanel extends StatelessWidget {
  const _TrustPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: KdColors.stateUncertainBand,
        borderRadius: BorderRadius.circular(KdRadius.lg),
        border: const Border(
          left: BorderSide(color: KdColors.stateUncertainRail, width: 4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KdLayout.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KdIconWell(
                  icon: Icons.phonelink_lock_outlined,
                  backgroundColor: KdColors.surface,
                  foregroundColor: KdColors.stateUncertainInk,
                ),
                const SizedBox(width: KdSpacing.smd),
                Expanded(
                  child: Text(
                    l10n.diseasePhotoPrivacy,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: KdColors.stateUncertainInk,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: KdSpacing.md),
              child: Divider(color: KdColors.stateUncertainRail),
            ),
            Text(
              l10n.diseaseExperimentalTitle,
              style: theme.textTheme.titleSmall?.copyWith(
                color: KdColors.stateUncertainInk,
              ),
            ),
            const SizedBox(height: KdSpacing.xs),
            Text(
              l10n.diseaseExperimentalBody,
              style: theme.textTheme.bodySmall?.copyWith(
                color: KdColors.stateUncertainInk,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanActionBar extends ConsumerWidget {
  const _ScanActionBar({required this.crop});

  final Crop crop;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Material(
      color: KdColors.surface,
      elevation: 8,
      shadowColor: const Color(0x26000000),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            KdLayout.pageGutter,
            KdSpacing.smd,
            KdLayout.pageGutter,
            KdSpacing.smd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ref.watch(autoDetectCropProvider)
                    ? l10n.autoDetectCrop
                    : l10n.diseaseSelectedCrop(cropName(l10n, crop)),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: KdColors.inkMuted),
              ),
              const SizedBox(height: KdSpacing.sm),
              FilledButton.icon(
                key: diseaseScanStartKey,
                onPressed: () => context.push(AppRoutes.diagnoseCapture),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l10n.diseaseStartCamera),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingActionBar extends StatelessWidget {
  const _LoadingActionBar();

  @override
  Widget build(BuildContext context) {
    return const Material(
      color: KdColors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(KdSpacing.md),
          child: LinearProgressIndicator(),
        ),
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KdLayout.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: KdSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: KdSpacing.xs),
                  Text(body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
