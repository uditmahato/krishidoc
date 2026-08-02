import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:inference/inference.dart';
import 'package:intl/intl.dart';

import '../l10n/gen/app_localizations.dart';
import 'diagnosis/sample_notice.dart';
import 'providers.dart';
import 'router.dart';

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
            ? const _EmptyHistory()
            : Column(
                children: [
                  // D-52. History renders stored diagnoses, so it is a surface
                  // that can present a sample answer as a real one, and the
                  // notice is mandatory here for the same reason it is on the
                  // result. It sits outside the scroll view rather than as the
                  // first row: a mandatory notice that scrolls away is a
                  // notice only the farmer who does not scroll ever reads.
                  //
                  // Shown only when a sample record is actually visible, so it
                  // stops appearing on its own once real records replace them,
                  // and the individual rows carry the marker so the sentence
                  // still points at the right ones in a mixed list.
                  if (records.any(
                    (record) => isSampleModelVersion(record.modelVersion),
                  ))
                    const Padding(
                      padding: EdgeInsets.fromLTRB(
                        KdSpacing.md,
                        KdSpacing.md,
                        KdSpacing.md,
                        0,
                      ),
                      child: SampleNotice(),
                    ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(KdSpacing.md),
                      itemCount: records.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: KdSpacing.sm),
                      itemBuilder: (context, index) =>
                          _HistoryTile(record: records[index]),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Stable handle for the empty-state action, measured by the layout matrix.
const Key historyEmptyActionKey = Key('history.empty.action');

/// Empty History as a funnel rather than a dead end.
///
/// The glyph is a leaf, not a broken image or an empty box: nothing is broken
/// and nothing is missing. The reader has simply not done a thing that cannot
/// be done yet, and the screen says which.
class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: ListView(
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
                    Icons.eco_outlined,
                    size: kdScaledIcon(context, KdIconSize.xxl),
                    color: KdColors.inkMuted,
                  ),
                ),
              ),
              const SizedBox(height: KdSpacing.lg),
              Semantics(
                container: true,
                label: '${l10n.historyEmptyTitle} ${l10n.historyEmptyBody}',
                child: ExcludeSemantics(
                  child: Column(
                    children: [
                      Text(
                        l10n.historyEmptyTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: KdColors.inkStrong,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: KdSpacing.smd),
                      Text(
                        l10n.historyEmptyBody,
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
          ),
        ),
        // Outside the scroll view, same rule as About.
        //
        // Deliberately NOT "Take your first photo", disabled or otherwise. No
        // model exists, so a disabled primary here would be the coming-soon
        // tile wearing different clothes. When inference ships this becomes
        // `label: takePhoto, onPressed: () => context.push(AppRoutes.capture)`
        // at this same widget key: a one-line change, recorded now so it is
        // not rediscovered.
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(KdLayout.pageGutter),
            child: FilledButton(
              key: historyEmptyActionKey,
              onPressed: () => context.push(AppRoutes.welcomeAbout),
              child: Text(l10n.historyEmptyAction),
            ),
          ),
        ),
      ],
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
    final (icon, rail, stateName) = switch (record.state) {
      ResultState.confident => (
        Icons.check_circle_outline,
        KdColors.stateConfidentRail,
        l10n.a11yStateConfident,
      ),
      ResultState.uncertain => (
        Icons.help_outline,
        KdColors.stateUncertainRail,
        l10n.a11yStateUncertain,
      ),
      ResultState.outOfScope => (
        Icons.search_off_outlined,
        KdColors.stateOutOfScopeRail,
        l10n.a11yStateOutOfScope,
      ),
    };
    // Raw model label as a stopgap: KB display names replace this when the
    // advisory content module lands (D-35). Records only exist via dev flows
    // until the capture module ships.
    final title = record.predictions.isEmpty
        ? l10n.historyNoIdentification
        : record.predictions.first.label;
    final when = DateFormat.yMMMd(
      locale,
    ).add_jm().format(record.createdAt.toLocal());

    final isSample = isSampleModelVersion(record.modelVersion);

    return Semantics(
      // All three states used to produce byte-identical semantics, so the
      // certainty of a result, the whole point of the tri-state design, was
      // invisible to a screen reader. The state is now spoken first, before
      // the disease name, because "not sure" changes what the rest means.
      //
      // A sample row speaks the notice too: the banner above is a separate
      // node, so a reader moving row by row would otherwise never meet it,
      // and the marker glyph alone says nothing aloud.
      label: isSample
          ? '$stateName. $title. $when. ${l10n.sampleDataNotice}'
          : '$stateName. $title. $when',
      button: true,
      child: ExcludeSemantics(
        child: Card(
          // The rail is a border rather than a sibling box: a stretched child
          // inside a list gets unbounded height, and an IntrinsicHeight here
          // would add a layout pass per row for something a border already
          // does. Deliberately paired with a distinct glyph and a spoken
          // state name, because three colours that each stay dark enough to
          // read on white cannot separate from each other by more than about
          // 3.5:1. Colour is support here, never the signal.
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: rail, width: KdSpacing.xs),
              ),
            ),
            child: ListTile(
              leading: Icon(icon, color: rail),
              title: Text(title),
              subtitle: Text(when),
              // Marks exactly the rows the banner is about. Without it a
              // mixed list would carry one sentence over rows it does not
              // apply to, which is a different kind of lie from the one the
              // notice exists to prevent.
              trailing: isSample
                  ? const Icon(
                      sampleMarkerIcon,
                      color: KdColors.stateUncertainRail,
                    )
                  : null,
              // The row looked tappable for four modules and was inert. Now it
              // opens the result it summarises.
              onTap: () => context.push('${AppRoutes.resultBase}/${record.id}'),
            ),
          ),
        ),
      ),
    );
  }
}
