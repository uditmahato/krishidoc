import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/gen/app_localizations.dart';
import 'locale_scope.dart';
import 'router.dart';
import 'welcome/language_choice.dart';

/// Stable handles. Both rows are named because the layout matrix measures
/// them, and because a finder keyed on an icon breaks every time the glyph is
/// reconsidered.
const Key homeNotebookKey = Key('home.notebook');
const Key homeNotReadyKey = Key('home.notReady');
const Key homeHistoryKey = Key('home.history');

/// Debug-only door to the capture flow.
///
/// The spec for this module deletes the Diagnose tile, and that tile was the
/// only route to `/capture`. Deleting it outright would make the closed loop
/// unreachable, so it moves behind `kDebugMode` rather than disappearing:
/// D-52 already forbids distributing any build while a sample pack is wired,
/// and Home must not offer a farmer a diagnosis it cannot honestly give. A
/// debug entry satisfies both, and it is how `/capture` was reached before
/// the loop was closed.
const Key homeDebugCaptureKey = Key('home.debug.capture');

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final current = Localizations.localeOf(context).languageCode;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          PopupMenuButton<AppLanguage>(
            // A tooltip is not a label: it appears on long press and screen
            // readers announce it inconsistently. For a user who reads only
            // Nepali, this control is the single way out of an English app,
            // so the glyph itself carries a name.
            icon: Icon(Icons.language, semanticLabel: l10n.languageMenuTooltip),
            tooltip: l10n.languageMenuTooltip,
            onSelected: (language) {
              KdHaptics.selected();
              LocaleScope.of(context).setLocale(Locale(language.code));
            },
            // Read from the same list the chooser renders, so the two
            // surfaces cannot drift apart in spelling or in order. The
            // endonyms were hardcoded here, which is precisely the second
            // ungated string surface D-54 exists to prevent.
            itemBuilder: (context) => [
              for (final choice in kLanguageChoices)
                CheckedPopupMenuItem(
                  value: choice.language,
                  checked: choice.language.code == current,
                  child: Text(
                    choice.name(l10n),
                    style: KdType.forLocale(
                      choice.locale,
                    ).bodyLarge?.copyWith(color: KdColors.inkStrong),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KdLayout.pageGutter,
          KdLayout.pageGutter,
          KdLayout.pageGutter,
          KdLayout.scrollBottomInset,
        ),
        children: [
          Text(
            // The same key About renders, verbatim. It replaces a tagline
            // that promised "identification and advice", which named two
            // things this build cannot do.
            l10n.coverageStatement,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: KdColors.inkBody,
            ),
            // Start, not centre, so it shares the page's left edge with
            // everything below it.
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: KdLayout.sectionGap),
          // First, because it is the only thing on this screen a farmer can
          // actually finish today. Keeping a dated photograph needs no model
          // and makes no claim, so it is a real capability rather than a
          // placeholder for one.
          _DestinationRow(
            key: homeNotebookKey,
            icon: Icons.photo_camera_outlined,
            title: l10n.notebookTitle,
            onTap: () => context.push(AppRoutes.notebook),
          ),
          const SizedBox(height: KdLayout.itemGap),
          _NotReadyRow(
            key: homeNotReadyKey,
            icon: Icons.photo_camera_outlined,
            title: l10n.homeNotReadyTitle,
            status: l10n.homeNotReadyStatus,
            onTap: () => context.push(AppRoutes.welcomeAbout),
          ),
          const SizedBox(height: KdLayout.itemGap),
          _DestinationRow(
            key: homeHistoryKey,
            icon: Icons.history_outlined,
            title: l10n.tileHistory,
            onTap: () => context.push(AppRoutes.history),
          ),
          if (kDebugMode) ...[
            const SizedBox(height: KdLayout.sectionGap),
            TextButton(
              key: homeDebugCaptureKey,
              // The classifying path, explicitly. The release build reaches
              // the same camera through the notebook, where it makes no claim.
              onPressed: () => context.push('${AppRoutes.capture}?diagnose=1'),
              child: Text('${l10n.captureTitle} (diagnose)'),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.devResultPreview),
              child: Text(l10n.devPreviewTitle),
            ),
          ],
        ],
      ),
    );
  }
}

/// A live destination.
///
/// Row, not grid. A row is as tall as its content by construction, so the
/// `childAspectRatio` class of defect that overflowed the old tile grid at
/// default font size cannot return through a new component.
///
/// [onTap] is required and non-nullable, and that is the point: after this, a
/// dead destination is a compile error rather than a style choice. It is the
/// same discipline the sealed `DiagnosisPresentation` applies to certainty.
class _DestinationRow extends StatelessWidget {
  const _DestinationRow({
    required this.icon,
    required this.title,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      label: title,
      // Handler on the node, subtree excluded beneath it. The old _HomeTile
      // wrapped an ExcludeSemantics around the InkWell, which produced a node
      // announcing "button" with no tap action at all.
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(KdRadius.lg),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: KdSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(KdLayout.cardPadding),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: kdScaledIcon(context, KdIconSize.lg),
                    color: KdColors.primary,
                  ),
                  const SizedBox(width: KdSpacing.md),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: KdColors.inkStrong,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: kdScaledIcon(context, KdIconSize.md),
                    color: KdColors.inkMuted,
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

/// Not ready, and it says so at rest rather than on tap.
///
/// The same shape as [_DestinationRow] with the fill switched to sunken, the
/// ink dropped to disabled, and a second line the live row does not have.
/// `surfaceSunken` against `surface` measures 1.25:1, so the fill alone
/// cannot carry this and is not asked to: the sentence and the
/// missing-versus-present second line are load bearing, and the fill is the
/// fourth channel.
///
/// It is NOT inert. The whole card is one InkWell and it opens a real screen.
/// An inert block at the biggest tap magnet on Home is the "the tap is not
/// refused, it is unobserved" defect verbatim, and a farmer who touches a
/// camera glyph and gets nothing at all cannot tell the app from a frozen
/// phone. Its trailing glyph is a chevron rather than a camera, so what it
/// opens reads as an explanation and not as the camera.
class _NotReadyRow extends StatelessWidget {
  const _NotReadyRow({
    required this.icon,
    required this.title,
    required this.status,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      // The reason arrives in the same breath as the name. Deliberately NOT
      // `enabled: false`: this control is enabled, it navigates, and marking
      // it disabled would have TalkBack announce a dead control that then
      // works.
      label: '$title. $status',
      onTap: onTap,
      excludeSemantics: true,
      child: Card(
        color: KdColors.surfaceSunken,
        child: InkWell(
          borderRadius: BorderRadius.circular(KdRadius.lg),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: KdSpacing.minTouchTarget,
            ),
            child: Padding(
              padding: const EdgeInsets.all(KdLayout.cardPadding),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: kdScaledIcon(context, KdIconSize.lg),
                    color: KdColors.inkDisabled,
                  ),
                  const SizedBox(width: KdSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: KdColors.inkDisabled,
                          ),
                        ),
                        const SizedBox(height: KdSpacing.xxs),
                        Text(
                          status,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: KdColors.inkMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    size: kdScaledIcon(context, KdIconSize.md),
                    color: KdColors.inkMuted,
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
