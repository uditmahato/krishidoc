import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:inference/inference.dart';

import '../../l10n/gen/app_localizations.dart';
import 'label_names.dart';

/// Turns a stored [DiagnosisRecord] into something the design system can draw.
///
/// The seam matters: `DiagnosisPresentation` is sealed and knows nothing about
/// models, and `DiagnosisRecord` knows nothing about screens. This function is
/// the only place the two meet, so the rules about what a farmer is shown for a
/// given certainty live in one readable place instead of being spread across
/// widgets.
DiagnosisPresentation presentDiagnosis({
  required DiagnosisRecord record,
  required AppLocalizations l10n,
  required CertaintyBand? certainty,
  required void Function() onEscalate,
  required void Function() onCorrect,
  required void Function() onRetry,
}) {
  final top = record.predictions.isEmpty ? null : record.predictions.first;
  final name = top == null
      ? ''
      : stopgapLabelName(top.label, cropKey: record.cropKey);

  return switch (record.state) {
    ResultState.confident => ConfidentDiagnosis(
      diseaseName: name,
      // A record can outlive the band that produced it: bands were added after
      // the store existed, and nothing is persisted for older rows. Falling
      // back to the most cautious sentence is the only safe direction, because
      // the failure mode of guessing high is a farmer spraying on our word.
      certainty: _level(certainty ?? CertaintyBand.low),
      certaintyLabel: switch (certainty ?? CertaintyBand.low) {
        CertaintyBand.high => l10n.certaintyHigh(name),
        CertaintyBand.moderate => l10n.certaintyModerate(name),
        CertaintyBand.low => l10n.certaintyLow(name),
      },
      caveat: l10n.confidentCaveat,
      correctionLabel: l10n.resultNotMyProblem,
      onCorrect: onCorrect,
      escalationLabel: l10n.escalateToClinic,
      onEscalate: onEscalate,
    ),
    ResultState.uncertain => UncertainDiagnosis(
      title: l10n.resultUncertainTitle,
      alternatives: [
        for (final prediction in record.predictions)
          stopgapLabelName(prediction.label, cropKey: record.cropKey),
      ],
      escalationLabel: l10n.escalateToClinic,
      onEscalate: onEscalate,
    ),
    // Out of scope always means coverage here, never a bad photograph. The
    // resolver reaches this state when nothing cleared the rejection floor,
    // and a photo too poor to classify never gets this far: the capture gate
    // refuses the shutter first. The unreadable-photo wording exists for the
    // decode failure path, which is raised separately.
    ResultState.outOfScope => OutOfScopeDiagnosis(
      guidance: l10n.outOfScopeNotCovered,
      cause: OutOfScopeCause.notCovered,
      retryLabel: l10n.retryCapture,
      onRetry: onRetry,
      escalationLabel: l10n.escalateToClinic,
      onEscalate: onEscalate,
    ),
  };
}

CertaintyLevel _level(CertaintyBand band) => switch (band) {
  CertaintyBand.high => CertaintyLevel.high,
  CertaintyBand.moderate => CertaintyLevel.moderate,
  CertaintyBand.low => CertaintyLevel.low,
};
