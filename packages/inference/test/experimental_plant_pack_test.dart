import 'dart:math' as math;
import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:inference/inference.dart';
import 'package:test/test.dart';

final class _TensorClassifier implements ImageClassifier {
  const _TensorClassifier(this.values);

  final List<double> values;

  @override
  Future<List<double>> logits(Uint8List preparedImage) async => values;

  @override
  Future<void> dispose() async {}
}

List<double> _logitsWith({required int winner, double top = 0.80}) {
  final rest = (1 - top) / (ExperimentalPlantPack.outputCount - 1);
  return [
    for (var index = 0; index < ExperimentalPlantPack.outputCount; index++)
      math.log(index == winner ? top : rest),
  ];
}

void main() {
  group('pinned model contract', () {
    test('keeps the source-controlled 38-output label order', () {
      expect(ExperimentalPlantPack.labelKeys, hasLength(38));
      expect(
        ExperimentalPlantPack.labelKeys[7],
        'maize_cercospora_leaf_spot_gray_leaf_spot',
      );
      expect(ExperimentalPlantPack.labelKeys[20], 'potato_early_blight');
      expect(ExperimentalPlantPack.labelKeys[28], 'tomato_bacterial_spot');
      expect(ExperimentalPlantPack.labelKeys[37], 'tomato_healthy');
      expect(ExperimentalPlantPack.global.labelCount, 38);
    });

    test(
      'uses a persistent experimental identity and possible-match policy',
      () {
        expect(
          isExperimentalModelVersion(ExperimentalPlantPack.modelVersion),
          isTrue,
        );
        expect(
          ExperimentalPlantPack.global.decisionMode,
          ModelDecisionMode.possibleMatchOnly,
        );
        expect(ExperimentalPlantPack.artifactSha256, hasLength(64));
      },
    );

    test('enables only the three crops in the app catalog', () {
      expect(ExperimentalPlantPack.forCrop('tomato'), isNotNull);
      expect(ExperimentalPlantPack.forCrop('potato'), isNotNull);
      expect(ExperimentalPlantPack.forCrop('maize'), isNotNull);
      expect(ExperimentalPlantPack.forCrop('pepper'), isNull);
      expect(ExperimentalPlantPack.forCrop('rice'), isNull);
    });
  });

  group('global output crop guard', () {
    test('rejects a global winner from another crop', () async {
      // Index 28 is tomato bacterial spot. A potato-scoped request must not
      // hide that winner and renormalise the three potato values.
      final service = ClassificationService(
        classifier: _TensorClassifier(_logitsWith(winner: 28)),
        pack: ExperimentalPlantPack.global,
        allowedLabelKeys: ExperimentalPlantPack.allowedLabelsForCrop('potato'),
      );

      final outcome = await service.classify(Uint8List(1));

      expect(outcome.state, ResultState.outOfScope);
      expect(outcome.ranked, isEmpty);
    });

    test(
      'offers only same-crop alternatives when the winner matches',
      () async {
        final service = ClassificationService(
          classifier: _TensorClassifier(_logitsWith(winner: 28)),
          pack: ExperimentalPlantPack.global,
          allowedLabelKeys: ExperimentalPlantPack.allowedLabelsForCrop(
            'tomato',
          ),
        );

        final outcome = await service.classify(Uint8List(1));

        expect(outcome.state, ResultState.uncertain);
        expect(outcome.ranked, hasLength(3));
        expect(
          outcome.ranked.every(
            (candidate) => candidate.label.startsWith('tomato_'),
          ),
          isTrue,
        );
      },
    );

    test('cannot become confident even when softmax rounds to one', () {
      final probabilities = List<double>.filled(38, 0)..[28] = 1;

      final outcome = const PredictionResolver().resolve(
        probabilities: probabilities,
        pack: ExperimentalPlantPack.global,
        allowedLabelKeys: ExperimentalPlantPack.allowedLabelsForCrop('tomato'),
      );

      expect(outcome.state, ResultState.uncertain);
      expect(outcome.certainty, isNull);
    });
  });
}
