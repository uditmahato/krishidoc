import 'package:core_domain/core_domain.dart';
import 'package:inference/inference.dart';
import 'package:test/test.dart';

ModelPack _pack({
  List<LabelSpec>? labels,
  double rejectionFloor = 0.30,
  double minMargin = 0.1,
}) => ModelPack(
  cropKey: 'tomato',
  modelVersion: 'tomato-v1.2.0',
  thresholdSetVersion: 'ts-2026-07',
  temperature: 1,
  rejectionFloor: rejectionFloor,
  minMargin: minMargin,
  labels:
      labels ??
      const [
        LabelSpec(key: 'late_blight', kind: LabelKind.disease, threshold: 0.7),
        LabelSpec(key: 'early_blight', kind: LabelKind.disease, threshold: 0.7),
        LabelSpec(key: 'leaf_mold', kind: LabelKind.disease, threshold: 0.7),
        LabelSpec(key: 'healthy', kind: LabelKind.healthy, threshold: 0.8),
      ],
);

const _resolver = PredictionResolver();

ClassificationOutcome _resolve(List<double> probabilities, {ModelPack? pack}) =>
    _resolver.resolve(probabilities: probabilities, pack: pack ?? _pack());

void main() {
  group('confident', () {
    test('a clear leader above its threshold is confident', () {
      final outcome = _resolve([0.90, 0.05, 0.03, 0.02]);

      expect(outcome.state, ResultState.confident);
      expect(outcome.ranked.first.label, 'late_blight');
      expect(outcome.isHealthy, isFalse);
    });

    test('a confident healthy leaf is flagged as healthy', () {
      final outcome = _resolve([0.05, 0.03, 0.02, 0.90]);

      expect(outcome.state, ResultState.confident);
      expect(outcome.ranked.first.label, 'healthy');
      expect(
        outcome.isHealthy,
        isTrue,
        reason: 'treatment surfaces key off this: a healthy leaf gets none',
      );
    });

    test('every prediction carries its model and threshold versions', () {
      final outcome = _resolve([0.90, 0.05, 0.03, 0.02]);

      expect(outcome.modelVersion, 'tomato-v1.2.0');
      expect(outcome.thresholdSetVersion, 'ts-2026-07');
    });
  });

  group('uncertain', () {
    test('a leader below its own threshold is uncertain, not a diagnosis', () {
      final outcome = _resolve([0.60, 0.20, 0.15, 0.05]);

      expect(outcome.state, ResultState.uncertain);
      expect(outcome.ranked, hasLength(3));
      expect(outcome.ranked.first.label, 'late_blight');
      expect(outcome.ranked[1].label, 'early_blight');
    });

    test('a near tie is uncertain even when the leader clears threshold', () {
      // 0.72 clears the 0.70 threshold, but 0.02 separates the top two and
      // their treatments differ.
      final outcome = _resolve([0.72, 0.70, 0.01, 0.01]);

      expect(outcome.state, ResultState.uncertain);
      expect(outcome.ranked.first.label, 'late_blight');
    });

    test('thresholds are per class, not global', () {
      // 0.75 is confident for a disease (0.70) but not for healthy (0.80):
      // claiming a plant is fine deserves more evidence than flagging it.
      final asDisease = _resolve([0.75, 0.10, 0.10, 0.05]);
      final asHealthy = _resolve([0.10, 0.10, 0.05, 0.75]);

      expect(asDisease.state, ResultState.confident);
      expect(asHealthy.state, ResultState.uncertain);
    });

    test('alternatives are ordered best first', () {
      final outcome = _resolve([0.30, 0.45, 0.20, 0.05]);

      final probabilities = outcome.ranked
          .map((p) => p.probability)
          .toList(growable: false);
      expect(probabilities, orderedEquals(<double>[0.45, 0.30, 0.20]));
    });
  });

  group('out of scope', () {
    test('a flat distribution matches nothing and is refused', () {
      final outcome = _resolve([0.24, 0.24, 0.24, 0.28]);

      expect(outcome.state, ResultState.outOfScope);
      expect(
        outcome.ranked,
        isEmpty,
        reason: 'offering a candidate we cannot vouch for invites action',
      );
      expect(outcome.topProbability, closeTo(0.28, 1e-9));
    });

    test('uncertainty with nothing to compare against is out of scope', () {
      // "It might be one of these" needs at least two candidates, and the
      // domain record forbids a one-candidate uncertain result. A resolver
      // configured to offer a single alternative must therefore refuse
      // rather than emit an unstorable outcome.
      final outcome = const PredictionResolver(
        topK: 1,
      ).resolve(probabilities: [0.60, 0.20, 0.15, 0.05], pack: _pack());

      expect(outcome.state, ResultState.outOfScope);
      expect(outcome.ranked, isEmpty);
    });
  });

  group('contract', () {
    test('states map onto domain rules for storing a record (D-17)', () {
      final confident = _resolve([0.90, 0.05, 0.03, 0.02]);
      final uncertain = _resolve([0.60, 0.20, 0.15, 0.05]);
      final rejected = _resolve([0.24, 0.24, 0.24, 0.28]);

      // Every outcome must be constructible as a DiagnosisRecord, whose
      // invariants are stricter than this resolver's own bookkeeping.
      for (final outcome in [confident, uncertain, rejected]) {
        expect(
          () => DiagnosisRecord(
            id: 'id',
            state: outcome.state,
            predictions: [
              for (final p in outcome.ranked)
                TopPrediction(label: p.label, confidence: p.probability),
            ],
            modelVersion: outcome.modelVersion,
            createdAt: DateTime.now().toUtc(),
          ),
          returnsNormally,
          reason: '${outcome.state.name} must satisfy the record invariants',
        );
      }
    });

    test('rejects a probability count that disagrees with the pack', () {
      expect(
        () => _resolve([0.5, 0.5]),
        throwsA(isA<ModelPackFormatException>()),
      );
    });
  });
}
