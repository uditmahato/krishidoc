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

/// What the model concluded, and how far it should be trusted.
final class ClassificationOutcome {
  const ClassificationOutcome({
    required this.state,
    required this.ranked,
    required this.modelVersion,
    required this.thresholdSetVersion,
    required this.topProbability,
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
  }) {
    if (probabilities.length != pack.labelCount) {
      throw ModelPackFormatException(
        'got ${probabilities.length} probabilities for '
        '${pack.labelCount} labels',
      );
    }

    final ranked = <RankedPrediction>[
      for (var i = 0; i < probabilities.length; i++)
        RankedPrediction(
          label: pack.labels[i].key,
          probability: probabilities[i],
          kind: pack.labels[i].kind,
        ),
    ]..sort((a, b) => b.probability.compareTo(a.probability));

    final leader = ranked.first;
    final runnerUp = ranked.length > 1 ? ranked[1] : null;
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

    if (leader.probability < pack.rejectionFloor) return outOfScope();
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
    );
  }
}
