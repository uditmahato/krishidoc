import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';

/// Sealed presentation model for a diagnosis (D-17).
///
/// There is deliberately no way to construct "a diagnosis to display" without
/// choosing one of the three certainty states, and each state forces the data
/// its rendering needs (uncertain cannot exist without alternatives and an
/// escalation action). This is the structural enforcement the design review
/// required: a certainty-free result screen is a compile error.
sealed class DiagnosisPresentation {
  const DiagnosisPresentation();

  ResultState get state;
}

final class ConfidentDiagnosis extends DiagnosisPresentation {
  const ConfidentDiagnosis({
    required this.diseaseName,
    required this.certaintyLabel,
  });

  /// Localized display name from the KB, never a raw classifier label (D-35).
  final String diseaseName;

  /// Reviewed plain-language certainty band, e.g. "very likely" (D-17).
  final String certaintyLabel;

  @override
  ResultState get state => ResultState.confident;
}

final class UncertainDiagnosis extends DiagnosisPresentation {
  const UncertainDiagnosis({
    required this.title,
    required this.alternatives,
    required this.escalationLabel,
    required this.onEscalate,
  }) : assert(alternatives.length > 0, 'uncertain requires alternatives');

  final String title;

  /// Top-k alternative display names, best first (D-17: top-3 shown, not hidden).
  final List<String> alternatives;

  /// Plant-clinic escalation call to action (D-07).
  final String escalationLabel;
  final VoidCallback onEscalate;

  @override
  ResultState get state => ResultState.uncertain;
}

final class OutOfScopeDiagnosis extends DiagnosisPresentation {
  const OutOfScopeDiagnosis({
    required this.guidance,
    required this.retryLabel,
    required this.onRetry,
  });

  /// Why no diagnosis was made and what to do (capture coaching, coverage).
  final String guidance;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  ResultState get state => ResultState.outOfScope;
}
