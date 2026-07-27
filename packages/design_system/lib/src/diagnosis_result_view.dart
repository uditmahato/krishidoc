import 'package:flutter/material.dart';

import 'diagnosis_presentation.dart';
import 'tokens.dart';

/// Renders a [DiagnosisPresentation]. The switch is exhaustive over the sealed
/// hierarchy: adding a new certainty state fails compilation until every
/// surface handles it.
class DiagnosisResultView extends StatelessWidget {
  const DiagnosisResultView({required this.presentation, super.key});

  final DiagnosisPresentation presentation;

  @override
  Widget build(BuildContext context) {
    return switch (presentation) {
      final ConfidentDiagnosis p => _ConfidentCard(p),
      final UncertainDiagnosis p => _UncertainCard(p),
      final OutOfScopeDiagnosis p => _OutOfScopeCard(p),
    };
  }
}

class _ConfidentCard extends StatelessWidget {
  const _ConfidentCard(this.presentation);

  final ConfidentDiagnosis presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(presentation.diseaseName, style: theme.textTheme.titleLarge),
            const SizedBox(height: KdSpacing.xs),
            Chip(
              label: Text(presentation.certaintyLabel),
              backgroundColor: theme.colorScheme.secondaryContainer,
            ),
          ],
        ),
      ),
    );
  }
}

class _UncertainCard extends StatelessWidget {
  const _UncertainCard(this.presentation);

  final UncertainDiagnosis presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.help_outline, color: KdColors.warning),
                const SizedBox(width: KdSpacing.sm),
                Expanded(
                  child: Text(
                    presentation.title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: KdSpacing.sm),
            for (final alternative in presentation.alternatives)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: KdSpacing.xs),
                child: Text('• $alternative'),
              ),
            const SizedBox(height: KdSpacing.sm),
            FilledButton.icon(
              onPressed: presentation.onEscalate,
              icon: const Icon(Icons.support_agent),
              label: Text(presentation.escalationLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutOfScopeCard extends StatelessWidget {
  const _OutOfScopeCard(this.presentation);

  final OutOfScopeDiagnosis presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(KdSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(presentation.guidance, style: theme.textTheme.bodyLarge),
            const SizedBox(height: KdSpacing.md),
            OutlinedButton.icon(
              onPressed: presentation.onRetry,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(presentation.retryLabel),
            ),
          ],
        ),
      ),
    );
  }
}
