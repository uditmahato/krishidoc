import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/gen/app_localizations.dart';
import 'locale_scope.dart';
import 'router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            icon: Icon(
              Icons.language,
              semanticLabel: l10n.languageMenuTooltip,
            ),
            tooltip: l10n.languageMenuTooltip,
            onSelected: (language) {
              KdHaptics.selected();
              LocaleScope.of(context).setLocale(Locale(language.code));
            },
            itemBuilder: (context) => [
              for (final (language, name) in const [
                (AppLanguage.en, 'English'),
                (AppLanguage.ne, 'नेपाली'),
                (AppLanguage.hi, 'हिन्दी'),
              ])
                CheckedPopupMenuItem(
                  value: language,
                  checked: language.code == current,
                  child: Text(name),
                ),
            ],
          ),
        ],
      ),
      // Scrollable so large font scales and small screens never clip the
      // page. Note that this alone was NOT enough: the tiles below used to
      // derive their height from their width, which put the overflow inside a
      // box the scroll view had no way to grow. See _HomeTile.
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          KdLayout.pageGutter,
          KdLayout.pageGutter,
          KdLayout.pageGutter,
          KdLayout.scrollBottomInset,
        ),
        children: [
          Text(
            l10n.homeTagline,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KdLayout.sectionGap),
          _TileGrid(
            children: [
              // Still "coming soon" on purpose: the camera works, but no
              // diagnosis can follow the shutter until a model ships, and a
              // capture that ends in a byte count is the dead end this
              // rebuild exists to avoid.
              _HomeTile(
                icon: Icons.photo_camera_outlined,
                label: l10n.tileDiagnose,
              ),
              _HomeTile(icon: Icons.chat_bubble_outline, label: l10n.tileAsk),
              _HomeTile(
                icon: Icons.history_outlined,
                label: l10n.tileHistory,
                onTap: (context) => context.push(AppRoutes.history),
              ),
              _HomeTile(
                icon: Icons.settings_outlined,
                label: l10n.tileSettings,
              ),
            ],
          ),
          if (kDebugMode) ...[
            const SizedBox(height: KdLayout.sectionGap),
            TextButton(
              onPressed: () => context.push(AppRoutes.devResultPreview),
              child: Text(l10n.devPreviewTitle),
            ),
            TextButton(
              onPressed: () => context.push(AppRoutes.capture),
              child: const Text('Camera preview (debug)'),
            ),
          ],
        ],
      ),
    );
  }
}

/// A two-column grid whose rows are as tall as their content.
///
/// This replaces `GridView.count(childAspectRatio: 1.2)`, which was a real
/// defect rather than a preference: an aspect ratio derives tile height from
/// tile *width*, so the height was fixed no matter how tall the label inside
/// it grew. Measured result was `RenderFlex overflowed` exceptions on 320x640
/// and 360x800 at the default font size, with no font scaling involved at all,
/// and 360x800 is one of the most common resolutions in this market. Nepali
/// reaches three lines sooner than English, so the failure was worst in the
/// language most of these users read.
///
/// `IntrinsicHeight` costs an extra layout pass over its children. With four
/// tiles that is irrelevant, and it buys a grid that cannot overflow at any
/// text scale in any language, which is the property that matters.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (rows.isNotEmpty) {
        rows.add(const SizedBox(height: KdLayout.itemGap));
      }
      final right = i + 1 < children.length ? children[i + 1] : null;
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: children[i]),
              const SizedBox(width: KdLayout.itemGap),
              // An odd number of tiles keeps the last one half width rather
              // than letting it stretch across the row and read as a
              // different kind of thing.
              Expanded(child: right ?? const SizedBox.shrink()),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }
}

class _HomeTile extends StatelessWidget {
  const _HomeTile({required this.icon, required this.label, this.onTap});

  final IconData icon;
  final String label;

  /// Defaults to the honest "coming soon" notice until the feature exists.
  final void Function(BuildContext context)? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final live = onTap != null;

    return Semantics(
      button: true,
      // A tile that only raises a snackbar is not a destination, and a screen
      // reader should not announce it as one.
      enabled: live,
      label: label,
      child: ExcludeSemantics(
        child: Card(
          child: InkWell(
            borderRadius: BorderRadius.circular(KdRadius.lg),
            onTap: live
                ? () => onTap!(context)
                : () => ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(SnackBar(content: Text(l10n.comingSoon))),
            child: Padding(
              padding: const EdgeInsets.all(KdLayout.cardPadding),
              child: Column(
                // Top aligned, not centred. Tiles in a row share a height,
                // so centring each tile's own content puts the icons at
                // different heights as soon as one label wraps to more lines
                // than its neighbour, which Nepali does at large font sizes.
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Icon(
                    icon,
                    // Grows with the user's font setting. Android's font size
                    // slider scales text and not icons, so a fixed glyph
                    // beside a growing label inverts their relationship for
                    // exactly the people who navigate by picture.
                    size: kdScaledIcon(context, KdIconSize.lg),
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: KdSpacing.smd),
                  Text(
                    label,
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
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
