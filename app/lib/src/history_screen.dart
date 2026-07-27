import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import 'providers.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final recent = ref.watch(recentDiagnosesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.tileHistory)),
      body: recent.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(KdSpacing.lg),
            child: Text(l10n.errorGeneric, textAlign: TextAlign.center),
          ),
        ),
        data: (records) => records.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(KdSpacing.lg),
                  child: Text(l10n.historyEmpty, textAlign: TextAlign.center),
                ),
              )
            : ListView.separated(
                padding: const EdgeInsets.all(KdSpacing.md),
                itemCount: records.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: KdSpacing.sm),
                itemBuilder: (context, index) =>
                    _HistoryTile(record: records[index]),
              ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final DiagnosisRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (icon, color) = switch (record.state) {
      ResultState.confident => (Icons.check_circle_outline, KdColors.primary),
      ResultState.uncertain => (Icons.help_outline, KdColors.warning),
      ResultState.outOfScope => (
        Icons.image_not_supported_outlined,
        KdColors.textSecondary,
      ),
    };
    // Raw model label as a stopgap: KB display names replace this when the
    // advisory content module lands (D-35). Records only exist via dev flows
    // until the capture module ships.
    final title = record.predictions.isEmpty
        ? l10n.historyNoIdentification
        : record.predictions.first.label;

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title),
        subtitle: Text(
          DateFormat.yMMMd(locale).add_jm().format(record.createdAt.toLocal()),
        ),
      ),
    );
  }
}
