import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../capture/capture_screen.dart' show cropName;
import '../providers.dart';
import '../router.dart';

const Key notebookCaptureKey = Key('notebook.capture');

/// The photographs a farmer has kept.
///
/// This is the first screen in the app that can have content in a release
/// build, because filling it needs only a camera and a clock. Every other
/// list in the product waits on a model, a knowledge base, or a server.
class NotebookScreen extends ConsumerWidget {
  const NotebookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final entries = ref.watch(recentObservationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTitle)),
      body: entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(KdSpacing.lg),
            child: Text(l10n.errorGeneric, textAlign: TextAlign.center),
          ),
        ),
        data: (rows) => rows.isEmpty
            ? const _EmptyNotebook()
            : ListView.separated(
                padding: const EdgeInsets.all(KdLayout.pageGutter),
                itemCount: rows.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: KdLayout.itemGap),
                itemBuilder: (context, index) => _EntryRow(entry: rows[index]),
              ),
      ),
      floatingActionButton: null,
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(KdLayout.pageGutter),
          child: FilledButton.icon(
            key: notebookCaptureKey,
            // Pinned rather than a FAB: an extended FAB derives its width from
            // its label, Nepali runs about 1.7x English here, and M3 clips
            // rather than wraps. It would also float over the last row.
            onPressed: () => context.push(AppRoutes.capture),
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(l10n.captureTitle),
          ),
        ),
      ),
    );
  }
}

class _EmptyNotebook extends StatelessWidget {
  const _EmptyNotebook();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        KdLayout.pageGutter,
        KdLayout.sectionGap,
        KdLayout.pageGutter,
        KdLayout.pageGutter,
      ),
      children: [
        ExcludeSemantics(
          child: Center(
            child: Icon(
              Icons.photo_camera_outlined,
              size: kdScaledIcon(context, KdIconSize.xxl),
              color: KdColors.inkMuted,
            ),
          ),
        ),
        const SizedBox(height: KdSpacing.lg),
        Semantics(
          container: true,
          label: '${l10n.notebookEmptyTitle} ${l10n.notebookEmptyBody}',
          child: ExcludeSemantics(
            child: Column(
              children: [
                Text(
                  l10n.notebookEmptyTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: KdColors.inkStrong,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: KdSpacing.smd),
                Text(
                  l10n.notebookEmptyBody,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: KdColors.inkBody,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends ConsumerWidget {
  const _EntryRow({required this.entry});

  final Observation entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final when = DateFormat.yMMMd(
      locale,
    ).add_jm().format(entry.createdAt.toLocal());
    final crop = entry.cropKey == null
        ? null
        : ref.read(cropCatalogProvider).byKey(entry.cropKey);
    final title = crop == null ? when : cropName(l10n, crop);
    final subtitle = entry.note ?? l10n.notebookNoNote;

    return Semantics(
      button: true,
      label: '$title. $when. $subtitle',
      onTap: () => context.push('${AppRoutes.notebook}/${entry.id}'),
      excludeSemantics: true,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(KdRadius.lg),
          onTap: () => context.push('${AppRoutes.notebook}/${entry.id}'),
          child: Padding(
            padding: const EdgeInsets.all(KdSpacing.sm),
            child: Row(
              children: [
                _Thumbnail(path: entry.imagePath),
                const SizedBox(width: KdSpacing.smd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: KdColors.inkStrong,
                        ),
                      ),
                      const SizedBox(height: KdSpacing.xxs),
                      Text(
                        when,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: KdColors.inkMuted,
                        ),
                      ),
                      const SizedBox(height: KdSpacing.xxs),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: entry.note == null
                              ? KdColors.inkDisabled
                              : KdColors.inkBody,
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
    );
  }
}

/// The photograph, small.
///
/// Fixed square rather than intrinsic: a list whose row heights depend on
/// decoded image dimensions reflows as thumbnails arrive, which on a slow
/// device moves the row out from under the farmer's finger mid-tap.
class _Thumbnail extends ConsumerWidget {
  const _Thumbnail({required this.path});

  final String path;

  static const double _side = 72;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(diagnosisPhotoProvider(path));

    return ClipRRect(
      borderRadius: BorderRadius.circular(KdRadius.sm),
      child: SizedBox(
        width: _side,
        height: _side,
        child: bytes.maybeWhen(
          data: (data) => data == null
              ? const _MissingThumbnail()
              : Image.memory(
                  data,
                  fit: BoxFit.cover,
                  // A file that decodes to nothing must not take the row down
                  // with it. Android reclaims app storage under pressure.
                  errorBuilder: (context, error, stackTrace) =>
                      const _MissingThumbnail(),
                ),
          orElse: () => const _MissingThumbnail(),
        ),
      ),
    );
  }
}

class _MissingThumbnail extends StatelessWidget {
  const _MissingThumbnail();

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: KdColors.surfaceSunken,
    child: Icon(
      Icons.image_outlined,
      color: KdColors.inkDisabled,
      size: kdScaledIcon(context, KdIconSize.md),
    ),
  );
}
