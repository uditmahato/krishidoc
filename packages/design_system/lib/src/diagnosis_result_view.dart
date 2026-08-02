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
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: rail, width: KdSpacing.sm),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tone band behind the heading, so the state is visible before a
            // single word is read.
            ColoredBox(
              color: band,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: KdLayout.cardPadding,
                  vertical: KdSpacing.smd,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      icon,
                      color: ink,
                      size: kdScaledIcon(context, KdIconSize.md),
                    ),
                    const SizedBox(width: KdSpacing.smd),
                    Expanded(
                      child: Text(
                        heading,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(KdLayout.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The route to a person. Rendered on every state, by construction.
class _EscalationButton extends StatelessWidget {
  const _EscalationButton(this.presentation);

  final DiagnosisPresentation presentation;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: presentation.onEscalate,
    // A headset is a call centre. The person this refers to stands in a field,
    // so the glyph is a person rather than a switchboard.
    icon: const Icon(Icons.person_search_outlined),
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
      // Three filled circles at three sizes: the level is legible as a shape,
      // for a farmer who cannot read the sentence beside it.
      icon: switch (presentation.certainty) {
        CertaintyLevel.high => Icons.check_circle,
        CertaintyLevel.moderate => Icons.check_circle_outline,
        CertaintyLevel.low => Icons.help_outline,
      },
      // The whole statement, disease name inline: "This looks like late
      // blight." One sentence a farmer can repeat back, rather than a label
      // above a name, which asks the reader to assemble the meaning.
      heading: presentation.certaintyLabel,
      children: [
        Text(
          presentation.caveat,
          style: theme.textTheme.bodyMedium?.copyWith(color: KdColors.inkMuted),
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
          Padding(
            padding: const EdgeInsets.only(bottom: KdSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // A hanging indent, so a wrapped Devanagari line does not run
                // back under the bullet.
                Text('•  ', style: theme.textTheme.bodyLarge),
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
