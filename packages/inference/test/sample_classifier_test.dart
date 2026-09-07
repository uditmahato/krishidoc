import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:inference/inference.dart';
import 'package:test/test.dart';

Uint8List image(int fill, {int length = 4096}) =>
    Uint8List.fromList(List<int>.filled(length, fill));

/// A photo whose bytes vary, which is what a real JPEG looks like to the hash.
Uint8List varied(int salt, {int length = 4096}) => Uint8List.fromList([
  for (var i = 0; i < length; i++) (i * 31 + salt * 17) & 0xFF,
]);

void main() {
  final pack = SamplePacks.forCrop('tomato')!;
  final service = ClassificationService(
    classifier: SampleClassifier(pack: pack),
    pack: pack,
  );

  group('sample packs', () {
    test('parse through the real manifest validation', () {
      for (final crop in SamplePacks.coveredCrops) {
        final pack = SamplePacks.forCrop(crop)!;
        expect(pack.cropKey, crop);
        expect(pack.labelCount, greaterThanOrEqualTo(2));
        expect(
          pack.labels.where((l) => l.kind == LabelKind.healthy),
          hasLength(1),
          reason:
              'a pack without a healthy label can only ever diagnose disease, '
              'which is how V1 offered treatment plans for a healthy crop',
        );
      }
    });

    test('an uncovered crop returns null rather than another crop', () {
      // Falling back would let a tomato pack answer a maize photo, which is a
      // confident wrong answer: the exact failure mode this project exists to
      // prevent.
      expect(SamplePacks.forCrop('rice'), isNull);
      expect(SamplePacks.forCrop(''), isNull);
    });

    test('every sample pack is identifiable as sample data forever', () {
      // The marker lives in modelVersion, which is recorded on every stored
      // diagnosis (D-18), so a record written today stays distinguishable from
      // a real one after the model lands.
      for (final crop in SamplePacks.coveredCrops) {
        expect(isSamplePack(SamplePacks.forCrop(crop)!), isTrue);
      }
    });

    test('assertNotSample gives release wiring one line to fail on', () {
      expect(() => assertNotSample(pack), throwsStateError);
    });
  });

  group('determinism', () {
    test('the same photo always gives the same answer', () async {
      // A farmer who retakes the same leaf and gets a different disease each
      // time learns the app is guessing, and that lesson cannot be un-taught.
      final photo = varied(7);
      final first = await service.classify(photo);
      final second = await service.classify(Uint8List.fromList(photo));

      expect(second.state, first.state);
      expect(second.topProbability, closeTo(first.topProbability, 1e-12));
      expect(
        second.ranked.map((r) => r.label),
        first.ranked.map((r) => r.label),
      );
    });

    test('different photos generally give different answers', () async {
      final labels = <String>{};
      for (var i = 0; i < 60; i++) {
        final outcome = await service.classify(varied(i));
        if (outcome.ranked.isNotEmpty) labels.add(outcome.ranked.first.label);
      }
      expect(
        labels.length,
        greaterThan(1),
        reason:
            'a stand-in that always answers the same is not exercising the UI',
      );
    });

    test('two images sharing a long prefix are told apart by length', () async {
      final short = await service.classify(image(9, length: 2048));
      final long = await service.classify(image(9, length: 4096));
      expect(
        short.topProbability != long.topProbability ||
            short.state != long.state ||
            short.ranked.firstOrNull?.label != long.ranked.firstOrNull?.label,
        isTrue,
      );
    });
  });

  group('it reaches all three states, by construction', () {
    test('across many photos every D-17 state appears', () async {
      final seen = <ResultState, int>{};
      for (var i = 0; i < 300; i++) {
        final outcome = await service.classify(varied(i));
        seen.update(outcome.state, (n) => n + 1, ifAbsent: () => 1);
      }
      for (final state in ResultState.values) {
        expect(
          seen[state],
          isNotNull,
          reason:
              'state $state never occurred, so the screens that render it '
              'would go unexercised: $seen',
        );
      }
    });

    test('confident outcomes really do clear their own threshold', () async {
      // The point of targeting the pack's constants rather than fixed numbers:
      // the resolver's own rules must agree with the profile we aimed at.
      var checked = 0;
      for (var i = 0; i < 300 && checked < 5; i++) {
        final outcome = await service.classify(varied(i));
        if (outcome.state != ResultState.confident) continue;
        checked++;
        final leader = outcome.ranked.first;
        final threshold = pack.labels
            .firstWhere((l) => l.key == leader.label)
            .threshold;
        expect(leader.probability, greaterThanOrEqualTo(threshold));
        expect(
          leader.probability - outcome.ranked[1].probability,
          greaterThanOrEqualTo(pack.minMargin),
        );
      }
      expect(checked, greaterThan(0));
    });

    test(
      'out-of-scope outcomes really are below the rejection floor',
      () async {
        var checked = 0;
        for (var i = 0; i < 300 && checked < 5; i++) {
          final outcome = await service.classify(varied(i));
          if (outcome.state != ResultState.outOfScope) continue;
          checked++;
          expect(outcome.topProbability, lessThan(pack.rejectionFloor));
          expect(
            outcome.ranked,
            isEmpty,
            reason: 'nothing is vouched for, so nothing may be offered',
          );
        }
        expect(checked, greaterThan(0));
      },
    );

    test('uncertain outcomes carry at least two candidates', () async {
      var checked = 0;
      for (var i = 0; i < 300 && checked < 5; i++) {
        final outcome = await service.classify(varied(i));
        if (outcome.state != ResultState.uncertain) continue;
        checked++;
        expect(outcome.ranked.length, greaterThanOrEqualTo(2));
        expect(
          outcome.topProbability,
          greaterThanOrEqualTo(pack.rejectionFloor),
        );
      }
      expect(checked, greaterThan(0));
    });
  });

  group('the targeting is exact, not approximate', () {
    test('emitted logits survive the pack temperature intact', () async {
      // ModelPack.calibrate computes softmax(logits / temperature). The
      // classifier emits temperature * ln(p), so calibration must return
      // exactly p. If this drifts, every band above becomes approximate and
      // the state distribution silently changes.
      expect(
        pack.temperature,
        isNot(1),
        reason: 'the test needs a real scaling',
      );
      final photo = varied(3);
      final logits = await SampleClassifier(pack: pack).logits(photo);
      final probabilities = pack.calibrate(logits);

      expect(probabilities.reduce((a, b) => a + b), closeTo(1, 1e-9));
      final top = probabilities.reduce((a, b) => a > b ? a : b);
      final outcome = await service.classify(photo);
      expect(outcome.topProbability, closeTo(top, 1e-12));
    });

    test('outcomes are constructible as domain records', () async {
      // The same guarantee Module 8 established for the real path: inference
      // can never emit something the store would reject.
      for (var i = 0; i < 40; i++) {
        final outcome = await service.classify(varied(i));
        expect(
          () => DiagnosisRecord(
            id: '01900000-0000-7000-8000-00000000000$i',
            state: outcome.state,
            predictions: [
              for (final r in outcome.ranked)
                TopPrediction(label: r.label, confidence: r.probability),
            ],
            modelVersion: outcome.modelVersion,
            createdAt: DateTime.utc(2026, 8, 1),
          ),
          returnsNormally,
        );
      }
    });
  });
}
