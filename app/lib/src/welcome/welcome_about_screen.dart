import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/gen/app_localizations.dart';
import '../router.dart';

/// Stable handle for the first-run continue button. Named because the layout
/// matrix asserts its rect, not merely its existence.
const Key aboutContinueKey = Key('welcome.about.continue');

/// What this app is for, and what is not built yet.
///
/// One screen, not a three-card deck. Two of the three cards that deck would
/// have carried teach flows the farmer cannot enter today, and the third
/// promises a diagnosis and a person that neither exist (D-55).
class WelcomeAboutScreen extends StatelessWidget {
  const WelcomeAboutScreen({required this.first, super.key});

  /// True on the first run, reached from the chooser. Gives the screen its one
  /// forward button and removes the AppBar, because there is nothing behind it
  /// worth going back to yet.
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
                padding: const EdgeInsets.all(KdLayout.pageGutter),
                children: [
                  // No block titles. The glyph carries the category and the
                  // sentences carry the meaning, which removes three keys and
                  // six review units from the D-06 gate for nothing lost.
                  _AboutBlock(
                    icon: Icons.eco_outlined,
                    lines: [l10n.coverageStatement, l10n.coverageLimit],
                  ),
                  const SizedBox(height: KdLayout.sectionGap),
                  _AboutBlock(
                    icon: Icons.schedule_outlined,
                    lines: [l10n.aboutNotReadyBody],
                  ),
                  const SizedBox(height: KdLayout.sectionGap),
                  _AboutBlock(
                    icon: Icons.phone_android_outlined,
                    lines: [
                      l10n.aboutPrivacyOffline,
                      l10n.aboutPrivacyOnDevice,
                    ],
                  ),
                ],
              ),
            ),
            // OUTSIDE the ListView, pinned in the Column. This is the single
            // most important structural detail on the screen: a "one button,
            // always" guarantee whose button sits below the fold at the text
            // scales this audience uses is a lie at runtime, and a test
            // asserting "scrolls rather than overflows" cannot catch it,
            // because a ListView never overflows.
            //
            // Measured, not assumed: with this button as the last ListView
            // child it fell outside the viewport on EVERY 320x640 cell,
            // including at default font size, and on 360x800 from 1.3 up.
            if (first)
              Padding(
                padding: const EdgeInsets.all(KdLayout.pageGutter),
                child: FilledButton(
                  key: aboutContinueKey,
                  // `go`, not `push`: this clears the chooser from the stack,
                  // so the farmer cannot land back on a screen whose question
                  // they have already answered.
                  onPressed: () => context.go(AppRoutes.home),
                  child: Text(l10n.aboutContinue),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutBlock extends StatelessWidget {
  const _AboutBlock({required this.icon, required this.lines});

  final IconData icon;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      // One coherent statement per block, rather than eight fragments a
      // screen-reader user has to reassemble and cannot resume between.
      container: true,
      label: lines.join(' '),
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(KdLayout.cardPadding),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  size: kdScaledIcon(context, KdIconSize.lg),
                  color: KdColors.primary,
                ),
                const SizedBox(width: KdSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in lines) ...[
                        if (line != lines.first)
                          const SizedBox(height: KdSpacing.sm),
                        Text(
                          line,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: KdColors.inkBody,
                          ),
                        ),
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
}
