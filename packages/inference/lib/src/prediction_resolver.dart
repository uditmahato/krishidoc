import 'package:core_domain/core_domain.dart';

import 'model_pack.dart';

/// One candidate, after calibration.
final class RankedPrediction {
  const RankedPrediction({
    required this.label,
    required this.probability,
    required this.kind,
  });

  final String label;
  final double probability;
  final LabelKind kind;

  bool get isHealthy => kind == LabelKind.healthy;
}

/// How far past its own bar the leading answer got.
///
/// A single certainty phrase for every confident result was a real defect: a
/// calibrated 0.62 and a calibrated 0.98 spoke identically, so the app looked
/// calibrated while being uncalibrated, which is worse than showing nothing at
/// all. Module 8 computed [ClassificationOutcome.topProbability] and no screen
/// ever read it.
///
/// The band is measured as HEADROOM above the label's own threshold, not as a
/// raw probability. Thresholds are per class and ship with the model (D-18), so
/// 0.75 may be comfortably clear for one disease and barely scraping for
/// another; a fixed probability cut would compare the two as if they meant the
/// same thing. Headroom asks the only question a farmer cares about: how much
/// better than the bar this answer had to clear.
enum CertaintyBand {
  /// Well clear of its threshold.
  high,

  /// Clear, but not by much.
  moderate,

  /// Only just over the line. Worth checking again in a couple of days.
  low;

  /// Boundaries are on normalised headroom, `(p - threshold) / (1 - threshold)`.
  /// They are provisional in exactly the way every other calibration constant
  /// here is provisional: real cuts come from a fitted validation set, and
  /// choosing them is an ML plus Agri decision, not an engineering one.
  static const double highHeadroom = 0.50;
  static const double moderateHeadroom = 0.20;

  static CertaintyBand fromHeadroom(double headroom) {
    if (headroom >= highHeadroom) return CertaintyBand.high;
    if (headroom >= moderateHeadroom) return CertaintyBand.moderate;
    return CertaintyBand.low;
  }
}

/// What the model concluded, and how far it should be trusted.
final class ClassificationOutcome {
  const ClassificationOutcome({
    required this.state,
    required this.ranked,
    required this.modelVersion,
    required this.thresholdSetVersion,
    required this.topProbability,
    this.certainty,
  });

  final ResultState state;

  /// Best first. Empty when nothing plausible matched.
  final List<RankedPrediction> ranked;

  /// Recorded with every prediction so a bad diagnosis can be traced to the
  /// exact model and threshold set that produced it (D-18).
  final String modelVersion;
  final String thresholdSetVersion;

  /// Kept even when [ranked] is empty, for telemetry on rejected photos.
  final double topProbability;

  /// Non-null only when [state] is confident.
  ///
  /// Uncertain and out-of-scope have no band by construction: uncertainty is
  /// not a weak kind of certainty, and giving it a band would invite a screen
  /// to render "slightly sure" where the honest answer is "I do not know".
  final CertaintyBand? certainty;

  /// True only when the model is confident the leaf is healthy. Advisory and
  /// treatment surfaces key off this: a healthy leaf must never be handed a
  /// pesticide plan.
  bool get isHealthy =>
      state == ResultState.confident &&
      ranked.isNotEmpty &&
      ranked.first.isHealthy;
}

/// Turns calibrated probabilities into one of the three states a farmer can
/// be shown (D-17).
///
/// The order of the checks is the safety argument:
/// 1. Nothing plausible matched, so this is outside coverage. Forcing a
///    label here is how a photo of a wall becomes a disease diagnosis.
/// 2. The leader did not clear its own calibrated threshold.
/// 3. The top two are effectively tied. Their treatments may differ, so a
///    coin flip is reported as uncertainty rather than resolved silently.
/// Anything that survives all three is confident.
final class PredictionResolver {
  const PredictionResolver({this.topK = 3});

  /// How many alternatives an uncertain result offers.
  final int topK;

  ClassificationOutcome resolve({
    required List<double> probabilities,
    required ModelPack pack,
    Set<String>? allowedLabelKeys,
    bool forceOutOfScope = false,
  }) {
    if (probabilities.length != pack.labelCount) {
      throw ModelPackFormatException(
        'got ${probabilities.length} probabilities for '
        '${pack.labelCount} labels',
      );
    }

    if (allowedLabelKeys != null) {
      if (allowedLabelKeys.isEmpty) {
        throw const ModelPackFormatException(
          'allowedLabelKeys must not be empty',
        );
      }
      final packKeys = pack.labels.map((label) => label.key).toSet();
      final unknown = allowedLabelKeys.difference(packKeys);
      if (unknown.isNotEmpty) {
        throw ModelPackFormatException(
          'allowedLabelKeys contains labels absent from the pack: '
          '${unknown.join(', ')}',
        );
      }
    }

    final globalRanked = <RankedPrediction>[
      for (var i = 0; i < probabilities.length; i++)
        RankedPrediction(
          label: pack.labels[i].key,
          probability: probabilities[i],
          kind: pack.labels[i].kind,
        ),
    ]..sort((a, b) => b.probability.compareTo(a.probability));

    final leader = globalRanked.first;
    final runnerUp = globalRanked.length > 1 ? globalRanked[1] : null;
    final ranked = allowedLabelKeys == null
        ? globalRanked
        : globalRanked
              .where((candidate) => allowedLabelKeys.contains(candidate.label))
              .toList(growable: false);
    final threshold = pack.labels
        .firstWhere((label) => label.key == leader.label)
        .threshold;

    ClassificationOutcome outOfScope() => ClassificationOutcome(
      state: ResultState.outOfScope,
      // Deliberately empty: if we cannot vouch for any candidate, offering
      // one anyway invites the farmer to act on it.
      ranked: const [],
      modelVersion: pack.modelVersion,
      thresholdSetVersion: pack.thresholdSetVersion,
      topProbability: leader.probability,
    );

    ClassificationOutcome uncertain() {
      final alternatives = ranked.take(topK).toList(growable: false);
      // Uncertainty means "it could be one of these". With fewer than two
      // candidates there is nothing to choose between, and the domain record
      // forbids it, so the honest answer is that this is outside coverage.
      if (alternatives.length < 2) return outOfScope();
      return ClassificationOutcome(
        state: ResultState.uncertain,
        ranked: alternatives,
        modelVersion: pack.modelVersion,
        thresholdSetVersion: pack.thresholdSetVersion,
        topProbability: leader.probability,
      );
    }

    // A separate validity/OOD head has precedence over every condition score.
    // A rejected image must never become an uncertain list of diseases merely
    // because the condition head is forced to choose one of its known labels.
    if (forceOutOfScope) return outOfScope();

    // Crop scope is checked against the GLOBAL winner before any candidate is
    // hidden. Otherwise filtering then renormalising a maize-leading output to
    // tomato labels could manufacture a tomato match from a crop mismatch.
    if (allowedLabelKeys != null && !allowedLabelKeys.contains(leader.label)) {
      return outOfScope();
    }
    if (leader.probability < pack.rejectionFloor) return outOfScope();
    if (pack.decisionMode == ModelDecisionMode.possibleMatchOnly) {
      return uncertain();
    }
    if (leader.probability < threshold) return uncertain();
    if (runnerUp != null &&
        leader.probability - runnerUp.probability < pack.minMargin) {
      return uncertain();
    }

    return ClassificationOutcome(
      state: ResultState.confident,
      ranked: ranked.take(topK).toList(growable: false),
      modelVersion: pack.modelVersion,
      thresholdSetVersion: pack.thresholdSetVersion,
      topProbability: leader.probability,
      // Guarded because a threshold of exactly 1 would divide by zero. Such a
      // pack is loadable (thresholds are validated as 0 to 1 inclusive) and
      // means "never confident", so anything that does clear it is as clear as
      // it is possible to be.
      certainty: threshold >= 1
          ? CertaintyBand.high
          : CertaintyBand.fromHeadroom(
              (leader.probability - threshold) / (1 - threshold),
            ),
    );
  }
}
