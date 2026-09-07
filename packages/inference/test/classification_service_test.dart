import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:inference/inference.dart';
import 'package:test/test.dart';

/// Stands in for the LiteRT interpreter: the runtime is a device fact, the
/// decisions it feeds are not.
final class FakeClassifier implements ImageClassifier {
  FakeClassifier(this._logits);

  final List<double> _logits;
  int calls = 0;
  bool disposed = false;

  @override
  Future<List<double>> logits(Uint8List preparedImage) async {
    calls++;
    return _logits;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

final class FakeGatedClassifier implements GatedImageClassifier {
  FakeGatedClassifier(this._result);

  final GatedLogits _result;
  int gatedCalls = 0;
  int plainCalls = 0;

  @override
  Future<GatedLogits> gatedLogits(Uint8List preparedImage) async {
    gatedCalls++;
    return _result;
  }

  @override
  Future<List<double>> logits(Uint8List preparedImage) async {
    plainCalls++;
    return _result.logits;
  }

  @override
  Future<void> dispose() async {}
}

final _pack = ModelPack(
  cropKey: 'tomato',
  modelVersion: 'tomato-v1.2.0',
  thresholdSetVersion: 'ts-2026-07',
  temperature: 1,
  rejectionFloor: 0.40,
  minMargin: 0.1,
  labels: const [
    LabelSpec(key: 'late_blight', kind: LabelKind.disease, threshold: 0.7),
    LabelSpec(key: 'early_blight', kind: LabelKind.disease, threshold: 0.7),
    LabelSpec(key: 'healthy', kind: LabelKind.healthy, threshold: 0.8),
  ],
);

Uint8List get _image => Uint8List(16);

void main() {
  test('a decisive model yields a confident diagnosis', () async {
    final classifier = FakeClassifier([8, 0, 0]);
    final service = ClassificationService(classifier: classifier, pack: _pack);

    final outcome = await service.classify(_image);

    expect(classifier.calls, 1);
    expect(outcome.state, ResultState.confident);
    expect(outcome.ranked.first.label, 'late_blight');
  });

  test('a hesitant model yields uncertainty with alternatives', () async {
    final service = ClassificationService(
      classifier: FakeClassifier([1.0, 0.9, 0.2]),
      pack: _pack,
    );

    final outcome = await service.classify(_image);

    expect(outcome.state, ResultState.uncertain);
    expect(outcome.ranked.length, greaterThanOrEqualTo(2));
  });

  test('a model with no opinion is refused rather than forced', () async {
    final service = ClassificationService(
      classifier: FakeClassifier([0, 0, 0]),
      pack: _pack,
    );

    final outcome = await service.classify(_image);

    expect(outcome.state, ResultState.outOfScope);
    expect(outcome.ranked, isEmpty);
  });

  test('a model disagreeing with the pack fails loudly', () async {
    final service = ClassificationService(
      classifier: FakeClassifier([1, 2]),
      pack: _pack,
    );

    expect(
      () => service.classify(_image),
      throwsA(isA<ModelPackFormatException>()),
    );
  });

  test(
    'a rejected validity gate overrides decisive condition logits',
    () async {
      final classifier = FakeGatedClassifier(
        const GatedLogits(logits: [8, 0, 0], accepted: false),
      );
      final service = ClassificationService(
        classifier: classifier,
        pack: _pack,
      );

      final outcome = await service.classify(_image);

      expect(classifier.gatedCalls, 1);
      expect(classifier.plainCalls, 0);
      expect(outcome.state, ResultState.outOfScope);
      expect(outcome.ranked, isEmpty);
    },
  );

  test(
    'an accepted validity gate continues through the normal resolver',
    () async {
      final classifier = FakeGatedClassifier(
        const GatedLogits(logits: [8, 0, 0], accepted: true),
      );
      final service = ClassificationService(
        classifier: classifier,
        pack: _pack,
      );

      final outcome = await service.classify(_image);

      expect(outcome.state, ResultState.confident);
      expect(outcome.ranked.first.label, 'late_blight');
    },
  );

  test('the whole path runs without any network', () async {
    // Nothing in this package imports dart:io or http; the offline core loop
    // (D-05) depends on that staying true.
    final service = ClassificationService(
      classifier: FakeClassifier([9, 0, 0]),
      pack: _pack,
    );

    expect((await service.classify(_image)).state, ResultState.confident);
  });
}
