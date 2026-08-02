import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../l10n/gen/app_localizations.dart';

/// The permanent sample-data notice required by ADR-0052 (D-52).
///
/// It lives in one place and is used by every surface that can render a sample
/// diagnosis, so that "does this screen carry the notice" is a question with a
/// single answer to audit rather than one per screen. It carries no dismiss
/// control on purpose.
///
/// The colour pair is the audited uncertain triplet rather than a new one, so
/// it arrives already covered by `contrast_test.dart` (7.73:1 ink on band)
/// instead of introducing an unmeasured combination on the one surface that
/// must stay readable.
class SampleNotice extends StatelessWidget {
  const SampleNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: KdColors.stateUncertainBand,
        borderRadius: BorderRadius.circular(KdRadius.md),
        border: Border.all(color: KdColors.stateUncertainRail),
      ),
      child: Padding(
        padding: const EdgeInsets.all(KdLayout.cardPadding),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              // A laboratory flask, not a warning triangle: this is not a
              // hazard in the plant, it is a statement about where the answer
              // came from. The same glyph marks the individual rows in
              // History, so the banner and the rows it refers to are tied
              // together by more than proximity.
              sampleMarkerIcon,
              color: KdColors.stateUncertainInk,
              size: kdScaledIcon(context, KdIconSize.md),
            ),
            const SizedBox(width: KdSpacing.smd),
            Expanded(
              child: Text(
                l10n.sampleDataNotice,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: KdColors.stateUncertainInk,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The glyph that marks sample-derived output wherever it is rendered.
const IconData sampleMarkerIcon = Icons.science_outlined;
