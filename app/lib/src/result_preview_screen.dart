import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';

/// Debug-only showcase of every diagnosis state (D-17). Serves as living
/// documentation for UX review and exercises the design system with real
/// localized strings, including all three certainty bands, which are otherwise
/// only reachable by taking enough photographs to hit each one.
class ResultPreviewScreen extends StatelessWidget {
  const ResultPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    const disease = 'Late blight';

    ConfidentDiagnosis confident(CertaintyLevel level, String label) =>
        ConfidentDiagnosis(
          diseaseName: disease,
          certainty: level,
          certaintyLabel: label,
          caveat: l10n.confidentCaveat,
          correctionLabel: l10n.resultNotMyProblem,
          onCorrect: () {},
          escalationLabel: l10n.escalateToClinic,
          onEscalate: () {},
        );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.devPreviewTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(KdLayout.pageGutter),
        itemCount: 6,
        separatorBuilder: (context, index) =>
            const SizedBox(height: KdLayout.itemGap),
        itemBuilder: (context, index) => DiagnosisResultView(
          presentation: switch (index) {
            0 => confident(CertaintyLevel.high, l10n.certaintyHigh(disease)),
            1 => confident(
              CertaintyLevel.moderate,
              l10n.certaintyModerate(disease),
            ),
            2 => confident(CertaintyLevel.low, l10n.certaintyLow(disease)),
            3 => UncertainDiagnosis(
              title: l10n.resultUncertainTitle,
              alternatives: const ['Late blight', 'Early blight', 'Leaf mold'],
              escalationLabel: l10n.escalateToClinic,
              onEscalate: () {},
            ),
            4 => OutOfScopeDiagnosis(
              guidance: l10n.outOfScopeNotCovered,
              cause: OutOfScopeCause.notCovered,
              retryLabel: l10n.retryCapture,
              onRetry: () {},
              escalationLabel: l10n.escalateToClinic,
              onEscalate: () {},
            ),
            _ => OutOfScopeDiagnosis(
              guidance: l10n.outOfScopeUnreadable,
              cause: OutOfScopeCause.unreadablePhoto,
              retryLabel: l10n.retryCapture,
              onRetry: () {},
              escalationLabel: l10n.escalateToClinic,
              onEscalate: () {},
            ),
          },
        ),
      ),
    );
  }
}
