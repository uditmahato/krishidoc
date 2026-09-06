import 'package:core_domain/core_domain.dart';
import 'package:flutter/foundation.dart';

/// How sure a confident answer is, in the presentation layer.
///
/// Mirrors `CertaintyBand` in `packages/inference` rather than importing it,
/// because the design system must not depend on the model layer: a portal or a
/// widgetbook renders these cards with no inference package present. The app
/// maps one to the other at the seam.
enum CertaintyLevel { high, moderate, low }

/// Sealed presentation model for a diagnosis (D-17).
///
/// There is deliberately no way to construct "a diagnosis to display" without
/// choosing one of the three certainty states, and each state forces the data
/// its rendering needs. A certainty-free result screen is a compile error.
///
/// **Safe next-step guidance is on the base class.** The original hierarchy
/// gave an onward route to uncertain and out-of-scope only. Confident-and-wrong
/// is the case that can cost money and put chemicals on a healthy crop, so
/// every state must provide a way to question the result and see bounded
/// treatment, prevention and control guidance.
///
/// Keeping the action on the base makes "a result with no next step"
/// unconstructible, the same structural trick the hierarchy plays on certainty.
sealed class DiagnosisPresentation {
  const DiagnosisPresentation({
    required this.escalationLabel,
    required this.onEscalate,
  });

  /// Route to bounded next-step guidance. Present on every state.
  final String escalationLabel;
  final VoidCallback onEscalate;

  ResultState get state;
}

final class ConfidentDiagnosis extends DiagnosisPresentation {
  const ConfidentDiagnosis({
    required this.diseaseName,
    required this.certaintyLabel,
    required this.certainty,
    required this.caveat,
    required this.correctionLabel,
    required this.onCorrect,
    required super.escalationLabel,
    required super.onEscalate,
  });

  /// Localized display name from the KB, never a raw classifier label (D-35).
  final String diseaseName;

  /// Reviewed plain-language certainty sentence for [certainty] (D-17). A
  /// complete sentence, never a fragment: "धेरै सम्भावना" is a bare noun phrase
  /// that a farmer cannot repeat back as a statement about their crop.
  final String certaintyLabel;

  /// Which band [certaintyLabel] came from, so the card can render the level
  /// visually as well as in words. Colour alone can never carry it.
  final CertaintyLevel certainty;

  /// Permanent footer, shown on every confident result. A phone photograph
  /// cannot be certain, and the moment to say so is the moment the app sounds
  /// most sure.
  final String caveat;

  /// "This is not what my leaf has." The correction path that was missing.
  final String correctionLabel;
  final VoidCallback onCorrect;

  @override
  ResultState get state => ResultState.confident;
}

final class UncertainDiagnosis extends DiagnosisPresentation {
  const UncertainDiagnosis({
    required this.title,
    required this.alternatives,
    required super.escalationLabel,
    required super.onEscalate,
  }) : assert(alternatives.length > 0, 'uncertain requires alternatives');

  final String title;

  /// Top-k alternative display names, best first (D-17: top-3 shown, not hidden).
  final List<String> alternatives;

  @override
  ResultState get state => ResultState.uncertain;
}

final class OutOfScopeDiagnosis extends DiagnosisPresentation {
  const OutOfScopeDiagnosis({
    required this.guidance,
    required this.cause,
    required this.retryLabel,
    required this.onRetry,
    required super.escalationLabel,
    required super.onEscalate,
  });

  /// Why no diagnosis was made and what to do about it.
  final String guidance;

  /// Which explanation [guidance] is giving.
  ///
  /// The original screen had one string, and it blamed the photograph. But the
  /// resolver reaches this state when nothing cleared the rejection floor,
  /// while photo-quality problems are caught earlier by the capture gate and
  /// never get this far. So the message was almost always the wrong
  /// explanation, and it sent farmers into a retake loop that could not
  /// succeed. Splitting the cause is the fix; carrying it as data is what stops
  /// the two from being confused again.
  final OutOfScopeCause cause;

  final String retryLabel;
  final VoidCallback onRetry;

  @override
  ResultState get state => ResultState.outOfScope;
}

/// Why the app produced no diagnosis.
enum OutOfScopeCause {
  /// The plant or disease is outside what this app covers. Retaking the photo
  /// cannot help, so the copy must not ask for one.
  notCovered,

  /// The image itself could not be read. A better photo genuinely helps.
  unreadablePhoto,
}
