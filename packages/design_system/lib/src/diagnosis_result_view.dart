import 'package:flutter/material.dart';

import 'diagnosis_presentation.dart';
import 'theme.dart';
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

/// The shared shell: a coloured rail, a glyph, a heading, then the body.
///
/// Three states rendered as three identical white rectangles meant the state
/// lived only in words, in a language many of these users read slowly, at arm's
/// length in sunlight. The rail, the glyph and the heading are three
/// independent channels, which is required rather than decorative: three rails
/// that each stay dark enough to read on white cannot separate from each other
/// by more than about 3.5:1, so colour genuinely cannot carry this alone.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.rail,
    required this.band,
    required this.ink,
    required this.icon,
    required this.heading,
    required this.children,
  });

  final Color rail;
  final Color band;
  final Color ink;
  final IconData icon;
  final String heading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: band,
              border: Border(bottom: BorderSide(color: rail, width: 2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(KdSpacing.lmd),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: KdColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: rail),
                    ),
                    child: SizedBox.square(
                      dimension: 52,
                      child: Icon(
                        icon,
                        color: ink,
                        size: kdScaledIcon(context, KdIconSize.md),
                      ),
                    ),
                  ),
                  const SizedBox(width: KdSpacing.smd),
                  Expanded(
                    child: Text(
                      heading,
                      style: theme.textTheme.titleLarge?.copyWith(color: ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(KdSpacing.lmd),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

/// The route to bounded next-step guidance. Rendered on every state.
class _EscalationButton extends StatelessWidget {
  const _EscalationButton(this.presentation);

  final DiagnosisPresentation presentation;

  @override
  Widget build(BuildContext context) => FilledButton.icon(
    onPressed: presentation.onEscalate,
    icon: const Icon(Icons.menu_book_outlined),
    label: Text(presentation.escalationLabel),
  );
}

class _ConfidentCard extends StatelessWidget {
  const _ConfidentCard(this.presentation);

  final ConfidentDiagnosis presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StateCard(
      rail: KdColors.stateConfidentRail,
      band: KdColors.stateConfidentBand,
      ink: KdColors.stateConfidentInk,
      // Investigation imagery, not a success checkmark: an experimental
      // possible match must never look like a confirmed diagnosis.
      icon: switch (presentation.certainty) {
        CertaintyLevel.high => Icons.manage_search_rounded,
        CertaintyLevel.moderate => Icons.travel_explore_rounded,
        CertaintyLevel.low => Icons.help_outline,
      },
      // The whole statement, disease name inline: "This looks like late
      // blight." One sentence a farmer can repeat back, rather than a label
      // above a name, which asks the reader to assemble the meaning.
      heading: presentation.certaintyLabel,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: KdColors.surfaceSunken,
            borderRadius: BorderRadius.circular(KdRadius.md),
          ),
          child: Padding(
            padding: const EdgeInsets.all(KdSpacing.smd),
            child: Text(
              presentation.caveat,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: KdColors.inkBody,
              ),
            ),
          ),
        ),
        const SizedBox(height: KdSpacing.md),
        _EscalationButton(presentation),
        const SizedBox(height: KdSpacing.sm),
        // The correction path. Without it, a confident wrong answer is the one
        // state a farmer cannot argue with, and it is the state that costs the
        // most when it is wrong.
        TextButton(
          onPressed: presentation.onCorrect,
          child: Text(presentation.correctionLabel),
        ),
      ],
    );
  }
}

class _UncertainCard extends StatelessWidget {
  const _UncertainCard(this.presentation);

  final UncertainDiagnosis presentation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StateCard(
      rail: KdColors.stateUncertainRail,
      band: KdColors.stateUncertainBand,
      ink: KdColors.stateUncertainInk,
      icon: Icons.help_outline,
      heading: presentation.title,
      children: [
        for (final alternative in presentation.alternatives)
          Container(
            margin: const EdgeInsets.only(bottom: KdSpacing.sm),
            padding: const EdgeInsets.all(KdSpacing.smd),
            decoration: BoxDecoration(
              color: KdColors.stateUncertainBand,
              borderRadius: BorderRadius.circular(KdRadius.md),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.radio_button_unchecked,
                  color: KdColors.stateUncertainRail,
                  size: KdIconSize.sm,
                ),
                const SizedBox(width: KdSpacing.smd),
                Expanded(
                  child: Text(alternative, style: theme.textTheme.bodyLarge),
                ),
              ],
            ),
          ),
        const SizedBox(height: KdSpacing.sm),
        _EscalationButton(presentation),
      ],
    );
  }
}

class _OutOfScopeCard extends StatelessWidget {
  const _OutOfScopeCard(this.presentation);

  final OutOfScopeDiagnosis presentation;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      rail: KdColors.stateOutOfScopeRail,
      band: KdColors.stateOutOfScopeBand,
      ink: KdColors.stateOutOfScopeInk,
      icon: switch (presentation.cause) {
        OutOfScopeCause.notCovered => Icons.search_off_outlined,
        OutOfScopeCause.unreadablePhoto => Icons.filter_center_focus_outlined,
      },
      heading: presentation.guidance,
      children: [
        // Retaking the photo only helps when the photo was the problem.
        // Offering it for a coverage gap sends the farmer into a loop that
        // cannot succeed, which is exactly what the single old string did.
        if (presentation.cause == OutOfScopeCause.unreadablePhoto) ...[
          OutlinedButton.icon(
            onPressed: presentation.onRetry,
            icon: const Icon(Icons.photo_camera_outlined),
            label: Text(presentation.retryLabel),
          ),
          const SizedBox(height: KdSpacing.sm),
        ],
        _EscalationButton(presentation),
      ],
    );
  }
}
