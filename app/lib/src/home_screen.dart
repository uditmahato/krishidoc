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
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appTitle),
        actions: [
          PopupMenuButton<AppLanguage>(
            icon: const Icon(Icons.language),
            tooltip: l10n.languageMenuTooltip,
            onSelected: (language) =>
                LocaleScope.of(context).setLocale(Locale(language.code)),
            itemBuilder: (context) => const [
              PopupMenuItem(value: AppLanguage.en, child: Text('English')),
              PopupMenuItem(value: AppLanguage.ne, child: Text('नेपाली')),
              PopupMenuItem(value: AppLanguage.hi, child: Text('हिन्दी')),
            ],
          ),
        ],
      ),
      // Scrollable so large font scales and small screens never clip content
      // (fixed-height home layouts were a V1 accessibility finding). The
      // shrink-wrapped grid builds all tiles regardless of viewport.
      body: ListView(
        padding: const EdgeInsets.all(KdSpacing.md),
        children: [
          Text(
            l10n.homeTagline,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: KdSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: KdSpacing.md,
            crossAxisSpacing: KdSpacing.md,
            childAspectRatio: 1.2,
            children: [
              // Still "coming soon" on purpose: the camera works, but no
              // diagnosis can follow the shutter until a model ships, and a
              // capture that ends in a byte count is the dead end this
              // rebuild exists to avoid. The screen is reachable in debug
              // below, and this tile lights up when inference lands.
              _HomeTile(
                icon: Icons.photo_camera_outlined,
                label: l10n.tileDiagnose,
              ),
              _HomeTile(icon: Icons.chat_bubble_outline, label: l10n.tileAsk),
              _HomeTile(
                icon: Icons.history,
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
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap != null
            ? () => onTap!(context)
            : () => ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(l10n.comingSoon))),
        child: Padding(
          padding: const EdgeInsets.all(KdSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: theme.colorScheme.primary),
              const SizedBox(height: KdSpacing.sm),
              Text(
                label,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
