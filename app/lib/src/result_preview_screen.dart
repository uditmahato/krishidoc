import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../l10n/gen/app_localizations.dart';

/// Debug-only showcase of the three diagnosis states (D-17). Serves as living
/// documentation for UX review and exercises the design system with real
/// localized strings.
class ResultPreviewScreen extends StatelessWidget {
  const ResultPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.devPreviewTitle)),
      body: ListView(
        padding: const EdgeInsets.all(KdSpacing.md),
        children: [
          DiagnosisResultView(
            presentation: ConfidentDiagnosis(
              diseaseName: 'Late blight',
              certaintyLabel: l10n.certaintyVeryLikely,
            ),
          ),
          const SizedBox(height: KdSpacing.md),
          DiagnosisResultView(
            presentation: UncertainDiagnosis(
              title: l10n.resultUncertainTitle,
              alternatives: const ['Late blight', 'Early blight', 'Leaf mold'],
              escalationLabel: l10n.escalateToClinic,
              onEscalate: () {},
            ),
          ),
          const SizedBox(height: KdSpacing.md),
          DiagnosisResultView(
            presentation: OutOfScopeDiagnosis(
              guidance: l10n.resultOutOfScopeGuidance,
              retryLabel: l10n.retryCapture,
              onRetry: () {},
            ),
          ),
        ],
      ),
    );
  }
}
