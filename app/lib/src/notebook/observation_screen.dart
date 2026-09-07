import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../l10n/gen/app_localizations.dart';
import '../capture/capture_screen.dart' show cropName;
import '../providers.dart';

const Key observationNoteKey = Key('observation.note');
const Key observationSaveKey = Key('observation.save');
const Key observationDeleteKey = Key('observation.delete');

/// One kept photograph, with the one thing a farmer can add to it.
///
/// The photograph is already saved before this screen opens: capture writes
/// the file and the row, then navigates. So nothing here can lose the thing
/// the farmer actually did, and the note is genuinely optional rather than
/// optional-until-you-discover-it-was-not.
class ObservationScreen extends ConsumerStatefulWidget {
  const ObservationScreen({required this.observationId, super.key});

  final String observationId;

  @override
  ConsumerState<ObservationScreen> createState() => _ObservationScreenState();
}

class _ObservationScreenState extends ConsumerState<ObservationScreen> {
  final TextEditingController _note = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _saveNote(Observation entry) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(servicesProvider)
          .observationStore
          .upsert(
            Observation(
              id: entry.id,
              imagePath: entry.imagePath,
              createdAt: entry.createdAt,
              cropKey: entry.cropKey,
              note: _note.text,
            ),
          );
      if (mounted) context.pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmDelete(Observation entry) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.notebookDeleteConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.commonDelete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await ref.read(photoStoreProvider).delete(entry.imagePath);
    await ref.read(servicesProvider).observationStore.delete(entry.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final async = ref.watch(observationByIdProvider(widget.observationId));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.notebookTitle)),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => _stated(context, l10n.errorGeneric),
        data: (entry) {
          if (entry == null) return _stated(context, l10n.errorGeneric);
          if (!_loaded) {
            _loaded = true;
            _note.text = entry.note ?? '';
          }

          final locale = Localizations.localeOf(context).toLanguageTag();
          final when = DateFormat.yMMMd(
            locale,
          ).add_jm().format(entry.createdAt.toLocal());
          final crop = entry.cropKey == null
              ? null
              : ref.read(cropCatalogProvider).byKey(entry.cropKey);

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              KdLayout.pageGutter,
              KdLayout.pageGutter,
              KdLayout.pageGutter,
              KdLayout.scrollBottomInset,
            ),
            children: [
              _Photo(path: entry.imagePath),
              const SizedBox(height: KdLayout.itemGap),
              Text(
                crop == null ? when : '${cropName(l10n, crop)} · $when',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: KdColors.inkStrong,
                ),
              ),
              const SizedBox(height: KdSpacing.xs),
              Text(
                l10n.notebookPhotoSaved,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: KdColors.inkMuted,
                ),
              ),
              const SizedBox(height: KdLayout.sectionGap),
              TextField(
                key: observationNoteKey,
                controller: _note,
                maxLength: Observation.maxNoteLength,
                maxLines: 3,
                minLines: 1,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: l10n.notebookNoteHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: KdSpacing.smd),
              FilledButton(
                key: observationSaveKey,
                onPressed: _saving ? null : () => _saveNote(entry),
                child: Text(l10n.notebookSaveNote),
              ),
              const SizedBox(height: KdLayout.sectionGap),
              TextButton.icon(
                key: observationDeleteKey,
                onPressed: _saving ? null : () => _confirmDelete(entry),
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.notebookDelete),
                style: TextButton.styleFrom(foregroundColor: KdColors.danger),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _stated(BuildContext context, String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(KdSpacing.lg),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );
}

class _Photo extends ConsumerWidget {
  const _Photo({required this.path});

  final String path;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(diagnosisPhotoProvider(path));

    return bytes.maybeWhen(
      data: (data) => data == null
          ? const SizedBox.shrink()
          : ClipRRect(
              borderRadius: BorderRadius.circular(KdRadius.md),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Image.memory(
                  data,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}
