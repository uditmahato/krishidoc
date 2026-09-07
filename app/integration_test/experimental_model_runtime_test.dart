import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:inference/inference.dart';
import 'package:integration_test/integration_test.dart';
import 'package:krishidoc_app/src/inference/experimental_tflite_classifier.dart';
import 'package:krishidoc_app/src/inference/potato_field_tflite_classifier.dart';

Uint8List _syntheticLeafPng() {
  final image = image_lib.Image(width: 96, height: 96);
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final dx = (x - 48) / 38;
      final dy = (y - 48) / 27;
      final insideLeaf = (dx * dx) + (dy * dy) <= 1;
      if (insideLeaf) {
        final green = 105 + ((x + y) % 70);
        image.setPixelRgb(x, y, 42, green, 50);
      } else {
        image.setPixelRgb(x, y, 194, 188, 170);
      }
    }
  }
  return Uint8List.fromList(image_lib.encodePng(image));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('bundled experimental model runs on the Android device', (
    tester,
  ) async {
    final runner = TfliteExperimentalTensorRunner(threads: 2);
    addTearDown(runner.dispose);

    final input = const ExperimentalPlantImagePreprocessor().prepare(
      _syntheticLeafPng(),
    );
    final stopwatch = Stopwatch()..start();
    final probabilities = await runner.run(input);
    stopwatch.stop();

    expect(probabilities, hasLength(ExperimentalPlantPack.outputCount));
    for (final probability in probabilities) {
      expect(probability.isFinite, isTrue);
      expect(probability, inInclusiveRange(0.0, 1.0));
    }

    final total = probabilities.fold<double>(0, (sum, value) => sum + value);
    expect(total, closeTo(1.0, 0.02));

    final winner = probabilities.indexOf(
      probabilities.reduce((left, right) => left >= right ? left : right),
    );
    debugPrint(
      'Experimental model runtime verified: '
      '${probabilities.length} outputs, sum=${total.toStringAsFixed(6)}, '
      'topIndex=$winner, '
      'topProbability=${probabilities[winner].toStringAsFixed(6)}, '
      'latencyMs=${stopwatch.elapsedMilliseconds}',
    );
  });

  testWidgets('bundled potato field model runs both heads on Android', (
    tester,
  ) async {
    final runner = TflitePotatoFieldTensorRunner(threads: 2);
    addTearDown(runner.dispose);

    final encoded = _syntheticLeafPng();
    final input = const PotatoFieldImagePreprocessor().prepare(encoded);
    final stopwatch = Stopwatch()..start();
    final output = await runner.run(input);
    stopwatch.stop();

    expect(
      output.validityLogits,
      hasLength(PotatoFieldResearchPack.validityOutputCount),
    );
    expect(
      output.conditionLogits,
      hasLength(PotatoFieldResearchPack.conditionOutputCount),
    );
    expect(output.validityLogits.every((value) => value.isFinite), isTrue);
    expect(output.conditionLogits.every((value) => value.isFinite), isTrue);

    final classifier = PotatoFieldTfliteClassifier(
      runner: _FixedPotatoOutputRunner(output),
    );
    final gated = await classifier.gatedLogits(encoded);
    expect(gated.logits, output.conditionLogits);
    debugPrint(
      'Potato field runtime verified: validity=${output.validityLogits}, '
      'condition=${output.conditionLogits}, accepted=${gated.accepted}, '
      'latencyMs=${stopwatch.elapsedMilliseconds}',
    );
  });
}

final class _FixedPotatoOutputRunner implements PotatoFieldTensorRunner {
  const _FixedPotatoOutputRunner(this.output);

  final PotatoFieldRawOutput output;

  @override
  Future<PotatoFieldRawOutput> run(Float32List normalizedRgbInput) async =>
      output;

  @override
  Future<void> dispose() async {}
}
