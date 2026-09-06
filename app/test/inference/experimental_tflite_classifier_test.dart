import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:inference/inference.dart';
import 'package:krishidoc_app/src/inference/experimental_tflite_classifier.dart';

final class _FakeTensorRunner implements ExperimentalTensorRunner {
  _FakeTensorRunner(this.output);

  final List<double> output;
  Float32List? lastInput;
  bool disposed = false;

  @override
  Future<List<double>> run(Float32List rgbInput) async {
    lastInput = Float32List.fromList(rgbInput);
    return output;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

Uint8List _solidPng(int red, int green, int blue) {
  final image = image_lib.Image(width: 1, height: 1)
    ..setPixelRgb(0, 0, red, green, blue);
  return Uint8List.fromList(image_lib.encodePng(image));
}

List<double> _probabilities({int winner = 28, double top = 0.80}) {
  final rest = (1 - top) / (ExperimentalPlantPack.outputCount - 1);
  return [
    for (var index = 0; index < ExperimentalPlantPack.outputCount; index++)
      index == winner ? top : rest,
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('preprocessor emits deterministic RGB/255 floats in model order', () {
    final values = const ExperimentalPlantImagePreprocessor().prepare(
      _solidPng(12, 34, 56),
    );

    expect(
      values,
      hasLength(
        ExperimentalPlantPack.inputWidth *
            ExperimentalPlantPack.inputHeight *
            ExperimentalPlantPack.inputChannels,
      ),
    );
    for (var offset = 0; offset < values.length; offset += 3) {
      expect(values[offset], closeTo(12 / 255, 1e-7));
      expect(values[offset + 1], closeTo(34 / 255, 1e-7));
      expect(values[offset + 2], closeTo(56 / 255, 1e-7));
    }
  });

  test('fake tensor output survives the logits adapter unchanged', () async {
    final expected = _probabilities();
    final runner = _FakeTensorRunner(expected);
    final classifier = ExperimentalTfliteClassifier(runner: runner);

    final logits = await classifier.logits(_solidPng(1, 2, 3));
    final recovered = ExperimentalPlantPack.global.calibrate(logits);

    expect(runner.lastInput, isNotNull);
    for (var index = 0; index < expected.length; index++) {
      expect(recovered[index], closeTo(expected[index], 1e-9));
    }
  });

  test('wrong output count fails closed', () async {
    final classifier = ExperimentalTfliteClassifier(
      runner: _FakeTensorRunner(const [1]),
    );

    expect(
      () => classifier.logits(_solidPng(1, 2, 3)),
      throwsA(isA<ExperimentalModelContractException>()),
    );
  });

  test(
    'bundled metadata matches code and carries safety limitations',
    () async {
      final candidates = [
        File('app/assets/models/plant_disease_experimental.metadata.json'),
        File('assets/models/plant_disease_experimental.metadata.json'),
      ];
      final metadataFile = candidates.firstWhere((file) => file.existsSync());
      final source = await metadataFile.readAsString();
      final metadata = jsonDecode(source) as Map<String, dynamic>;
      final artifact = metadata['artifact'] as Map<String, dynamic>;
      final output = metadata['output'] as Map<String, dynamic>;
      final labels = output['labels'] as List<dynamic>;
      final safety = metadata['safetyPolicy'] as Map<String, dynamic>;
      final limitations = (metadata['limitations'] as List<dynamic>)
          .cast<String>();

      expect(metadata['modelVersion'], ExperimentalPlantPack.modelVersion);
      expect(artifact['sha256'], ExperimentalPlantPack.artifactSha256);
      expect(labels, hasLength(ExperimentalPlantPack.outputCount));
      expect([
        for (final label in labels) (label as Map<String, dynamic>)['key'],
      ], ExperimentalPlantPack.labelKeys);
      expect(safety['confidentResultsAllowed'], isFalse);
      expect(safety['chemicalAdviceAllowed'], isFalse);
      expect(limitations, contains('not_nepal_field_validated'));
      expect(limitations, contains('no_non_plant_class'));
    },
  );
}
