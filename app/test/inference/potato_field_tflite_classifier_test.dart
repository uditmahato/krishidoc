import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:core_domain/core_domain.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:inference/inference.dart';
import 'package:krishidoc_app/src/inference/potato_field_tflite_classifier.dart';

final class _FakePotatoRunner implements PotatoFieldTensorRunner {
  _FakePotatoRunner(this.output);

  final PotatoFieldRawOutput output;
  Float32List? lastInput;
  bool disposed = false;

  @override
  Future<PotatoFieldRawOutput> run(Float32List normalizedRgbInput) async {
    lastInput = Float32List.fromList(normalizedRgbInput);
    return output;
  }

  @override
  Future<void> dispose() async => disposed = true;
}

Uint8List _solidPng(int width, int height, int red, int green, int blue) {
  final image = image_lib.Image(width: width, height: height);
  for (final pixel in image) {
    pixel
      ..r = red
      ..g = green
      ..b = blue;
  }
  return Uint8List.fromList(image_lib.encodePng(image));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'V7 opt-in selects stricter calibration, not just different weights',
    () async {
      final result = await PotatoFieldTfliteClassifier(
        runner: _FakePotatoRunner(
          const PotatoFieldRawOutput(
            validityLogits: [3, 0, 0, 0, 0],
            conditionLogits: [8, 0, 0],
          ),
        ),
      ).gatedLogits(_solidPng(64, 64, 0, 180, 0));
      expect(result.accepted, !PotatoFieldResearchPack.useV7);
      expect(
        potatoFieldModelAsset.contains('_v7_'),
        PotatoFieldResearchPack.useV7,
      );
    },
  );

  test('preprocessor letterboxes and applies ImageNet normalization', () {
    final values = const PotatoFieldImagePreprocessor().prepare(
      _solidPng(2, 1, 255, 0, 0),
    );

    expect(
      values,
      hasLength(
        PotatoFieldResearchPack.inputWidth *
            PotatoFieldResearchPack.inputHeight *
            PotatoFieldResearchPack.inputChannels,
      ),
    );
    expect(values[0], closeTo((124 / 255 - 0.485) / 0.229, 1e-6));
    expect(values[1], closeTo((116 / 255 - 0.456) / 0.224, 1e-6));
    expect(values[2], closeTo((104 / 255 - 0.406) / 0.225, 1e-6));

    final centreOffset = ((112 * PotatoFieldResearchPack.inputWidth) + 112) * 3;
    expect(values[centreOffset], closeTo((1 - 0.485) / 0.229, 1e-6));
    expect(values[centreOffset + 1], closeTo((0 - 0.456) / 0.224, 1e-6));
    expect(values[centreOffset + 2], closeTo((0 - 0.406) / 0.225, 1e-6));
  });

  test('three-signal gate accepts a strong usable potato prediction', () async {
    final runner = _FakePotatoRunner(
      const PotatoFieldRawOutput(
        validityLogits: [8, 0, 0, 0, 0],
        conditionLogits: [8, 0, 0],
      ),
    );
    final service = ClassificationService(
      classifier: PotatoFieldTfliteClassifier(runner: runner),
      pack: PotatoFieldResearchPack.pack,
    );

    final outcome = await service.classify(_solidPng(1, 1, 0, 180, 0));

    expect(runner.lastInput, isNotNull);
    expect(outcome.state, ResultState.uncertain);
    expect(outcome.ranked.first.label, 'potato_early_blight');
    expect(outcome.certainty, isNull);
  });

  test(
    'validity head refuses a confident condition from another plant',
    () async {
      final service = ClassificationService(
        classifier: PotatoFieldTfliteClassifier(
          runner: _FakePotatoRunner(
            const PotatoFieldRawOutput(
              validityLogits: [0, 0, 0, 8, 0],
              conditionLogits: [8, 0, 0],
            ),
          ),
        ),
        pack: PotatoFieldResearchPack.pack,
      );

      final outcome = await service.classify(_solidPng(1, 1, 0, 180, 0));

      expect(outcome.state, ResultState.outOfScope);
      expect(outcome.ranked, isEmpty);
    },
  );

  test('wrong tensor sizes and non-finite logits fail closed', () async {
    final wrongSize = PotatoFieldTfliteClassifier(
      runner: _FakePotatoRunner(
        const PotatoFieldRawOutput(
          validityLogits: [1],
          conditionLogits: [1, 2, 3],
        ),
      ),
    );
    final nonFinite = PotatoFieldTfliteClassifier(
      runner: _FakePotatoRunner(
        const PotatoFieldRawOutput(
          validityLogits: [8, 0, 0, 0, 0],
          conditionLogits: [double.nan, 0, 0],
        ),
      ),
    );

    expect(
      () => wrongSize.gatedLogits(_solidPng(1, 1, 0, 180, 0)),
      throwsA(isA<PotatoFieldModelContractException>()),
    );
    expect(
      () => nonFinite.gatedLogits(_solidPng(1, 1, 0, 180, 0)),
      throwsA(isA<PotatoFieldModelContractException>()),
    );
  });

  test('bundled metadata matches the frozen model and safety policy', () async {
    final candidates = [
      File('app/$potatoFieldMetadataAsset'),
      File(potatoFieldMetadataAsset),
    ];
    final metadataFile = candidates.firstWhere((file) => file.existsSync());
    final metadata =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
    final artifact = metadata['artifact'] as Map<String, dynamic>;
    final outputs = metadata['outputs'] as List<dynamic>;
    final safety = metadata['safetyPolicy'] as Map<String, dynamic>;
    final limitations = (metadata['limitations'] as List<dynamic>)
        .cast<String>();

    expect(metadata['modelVersion'], PotatoFieldResearchPack.modelVersion);
    expect(
      metadata['thresholdSetVersion'],
      PotatoFieldResearchPack.thresholdSetVersion,
    );
    expect(artifact['sha256'], PotatoFieldResearchPack.artifactSha256);
    final binary = File(
      '${metadataFile.parent.path}/${(artifact['path'] as String).split('/').last}',
    );
    expect(
      sha256.convert(await binary.readAsBytes()).toString(),
      artifact['sha256'],
    );
    final calibration = metadata['calibration'] as Map<String, dynamic>;
    expect(
      calibration['validityTemperature'],
      PotatoFieldResearchPack.validityTemperature,
    );
    expect(
      calibration['conditionTemperature'],
      PotatoFieldResearchPack.conditionTemperature,
    );
    expect(
      calibration['validityProbabilityMin'],
      PotatoFieldResearchPack.validityProbabilityMin,
    );
    expect(
      calibration['conditionProbabilityMin'],
      PotatoFieldResearchPack.conditionProbabilityMin,
    );
    expect(
      calibration['conditionEnergyMax'],
      PotatoFieldResearchPack.conditionEnergyMax,
    );
    expect(
      (outputs[0] as Map<String, dynamic>)['labels'],
      PotatoFieldResearchPack.validityLabelKeys,
    );
    expect(
      (outputs[1] as Map<String, dynamic>)['labels'],
      PotatoFieldResearchPack.conditionLabelKeys,
    );
    expect(safety['confidentResultsAllowed'], isFalse);
    expect(safety['validityGateRequired'], isTrue);
    expect(limitations, contains('not_nepal_field_validated'));
    if (PotatoFieldResearchPack.useV7) {
      final native = metadata['nativeValidation'] as Map<String, dynamic>;
      expect(native['photoCount'], 79);
      expect(native['processingErrors'], 0);
      expect(native['gateDisagreements'], 0);
      expect(native['promotionEligible'], isFalse);
      expect(limitations, contains('single_device_latency_only'));
    } else {
      expect(limitations, contains('physical_device_latency_not_yet_measured'));
    }
  });
}
