import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../router.dart';

/// Stable handles for the first-run action and the capability rows.
const Key aboutContinueKey = Key('welcome.about.continue');
const Key aboutLeafCheckKey = Key('welcome.about.leafCheck');
const Key aboutCropGuideKey = Key('welcome.about.cropGuide');
const Key aboutWeatherKey = Key('welcome.about.weather');
const Key aboutMarketKey = Key('welcome.about.market');

/// A concise, truthful introduction to the product that is also reachable as
/// the standalone About screen.
class WelcomeAboutScreen extends StatelessWidget {
  const WelcomeAboutScreen({required this.first, super.key});

  /// First run has one pinned forward action and no AppBar. A later visit uses
  /// the normal back AppBar and omits the onboarding action.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: KdColors.canvas,
      appBar: first ? null : AppBar(title: Text(l10n.aboutTitle)),
      body: SafeArea(
        top: first,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  KdLayout.pageGutter,
                  KdSpacing.lg,
                  KdLayout.pageGutter,
                  KdSpacing.xl,
                ),
                children: [
                  if (first) ...[
                    Row(
                      children: [
                        KdBrandMark(size: 48, semanticLabel: l10n.appTitle),
                        const SizedBox(width: KdSpacing.smd),
                        Expanded(
                          child: Text(
                            l10n.appTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: KdSpacing.lg),
                  ],
                  _PurposeHero(
                    lines: [l10n.coverageStatement, l10n.coverageLimit],
                  ),
                  const SizedBox(height: KdSpacing.lg),
                  _SectionLabel(label: l10n.aboutCapabilitiesTitle),
                  const SizedBox(height: KdSpacing.smd),
                  Card(
                    child: Column(
                      children: [
                        _CapabilityRow(
                          key: aboutLeafCheckKey,
                          icon: Icons.photo_camera_outlined,
                          iconBackground: KdColors.primarySoft,
                          iconForeground: KdColors.primaryPressed,
                          title: l10n.aboutLeafCheckTitle,
                          body: l10n.aboutLeafCheckBody,
                        ),
                        const Divider(),
                        _CapabilityRow(
                          key: aboutCropGuideKey,
                          icon: Icons.menu_book_outlined,
                          iconBackground: KdColors.brandGoldSoft,
                          iconForeground: KdColors.brandGoldInk,
                          title: l10n.aboutCropGuideTitle,
                          body: l10n.aboutCropGuideBody,
                        ),
                        const Divider(),
                        _CapabilityRow(
                          key: aboutWeatherKey,
                          icon: Icons.cloud_outlined,
                          iconBackground: KdColors.skySoft,
                          iconForeground: KdColors.skyInk,
                          title: l10n.aboutWeatherTitle,
                          body: l10n.aboutWeatherBody,
                        ),
                        const Divider(),
                        _CapabilityRow(
                          key: aboutMarketKey,
                          icon: Icons.storefront_outlined,
                          iconBackground: KdColors.earthSoft,
                          iconForeground: KdColors.earthInk,
                          title: l10n.aboutMarketTitle,
                          body: l10n.aboutMarketBody,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: KdSpacing.lg),
                  _SectionLabel(label: l10n.aboutPrivacyTitle),
                  const SizedBox(height: KdSpacing.smd),
                  _PrivacyPanel(
                    lines: [
                      l10n.aboutPrivacyOffline,
                      l10n.aboutPrivacyOnDevice,
                    ],
                  ),
                ],
              ),
            ),
            // Kept outside the scroll view so it remains visible on small
            // screens and at enlarged text sizes.
            if (first)
              DecoratedBox(
                decoration: const BoxDecoration(
                  color: KdColors.surface,
                  border: Border(top: BorderSide(color: KdColors.outlineSoft)),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(KdLayout.pageGutter),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: aboutContinueKey,
                        // `go` clears the chooser, so Back cannot reopen a
                        // first-run question the reader already answered.
                        onPressed: () => context.go(AppRoutes.home),
                        child: Text(l10n.aboutContinue),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label,
    style: Theme.of(context).textTheme.labelLarge?.copyWith(
      color: KdColors.inkMuted,
      fontWeight: FontWeight.w700,
    ),
  );
}

class _PurposeHero extends StatelessWidget {
  const _PurposeHero({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      container: true,
      label: lines.join(' '),
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: KdColors.primarySoft,
            borderRadius: BorderRadius.circular(KdRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KdSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const KdIconWell(
                  icon: Icons.eco_outlined,
                  backgroundColor: KdColors.surface,
                  foregroundColor: KdColors.primaryPressed,
                  size: 52,
                ),
                const SizedBox(height: KdSpacing.md),
                Text(lines.first, style: theme.textTheme.titleLarge),
                const SizedBox(height: KdSpacing.smd),
                Text(
                  lines.last,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: KdColors.inkMuted,
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

class _CapabilityRow extends StatelessWidget {
  const _CapabilityRow({
    required this.icon,
    required this.iconBackground,
    required this.iconForeground,
    required this.title,
    required this.body,
    super.key,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconForeground;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$title. $body',
    child: ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            KdIconWell(
              icon: icon,
              backgroundColor: iconBackground,
              foregroundColor: iconForeground,
              size: 52,
            ),
            const SizedBox(width: KdSpacing.smd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: KdSpacing.xs),
                  Text(
                    body,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: KdColors.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PrivacyPanel extends StatelessWidget {
  const _PrivacyPanel({required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: lines.join(' '),
    child: ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: KdColors.primarySoft,
          borderRadius: BorderRadius.circular(KdRadius.lg),
        ),
        child: Padding(
          padding: const EdgeInsets.all(KdSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const KdIconWell(
                icon: Icons.shield_outlined,
                backgroundColor: KdColors.surface,
              ),
              const SizedBox(width: KdSpacing.smd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final line in lines) ...[
                      if (line != lines.first)
                        const SizedBox(height: KdSpacing.sm),
                      Text(line),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
