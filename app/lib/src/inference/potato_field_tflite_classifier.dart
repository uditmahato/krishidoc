import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as image_lib;
import 'package:inference/inference.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'training_resize.dart';

const String potatoFieldModelAsset = PotatoFieldResearchPack.useV7
    ? 'assets/models/potato_field_v7_efficientnet_b0_float32.tflite'
    : 'assets/models/potato_field_v3_efficientnet_b0_float32.tflite';
const String potatoFieldMetadataAsset = PotatoFieldResearchPack.useV7
    ? 'assets/models/potato_field_v7_efficientnet_b0.metadata.json'
    : 'assets/models/potato_field_v3_efficientnet_b0.metadata.json';

final class PotatoFieldModelContractException implements Exception {
  const PotatoFieldModelContractException(this.message);

  final String message;

  @override
  String toString() => 'PotatoFieldModelContractException: $message';
}

final class PotatoFieldRawOutput {
  const PotatoFieldRawOutput({
    required this.validityLogits,
    required this.conditionLogits,
  });

  final List<double> validityLogits;
  final List<double> conditionLogits;
}

/// Runtime seam used by unit tests and the physical-device benchmark.
abstract interface class PotatoFieldTensorRunner {
  Future<PotatoFieldRawOutput> run(Float32List normalizedRgbInput);

  Future<void> dispose();
}

/// Runs the dual-head potato model through TensorFlow Lite off the UI isolate.
///
/// The interpreter is constructed once, its tensor contract is checked before
/// use, and calls are serialized because one interpreter cannot be invoked
/// concurrently. The public input is NHWC after ONNX-to-TFLite conversion.
final class TflitePotatoFieldTensorRunner implements PotatoFieldTensorRunner {
  TflitePotatoFieldTensorRunner({
    this.assetPath = potatoFieldModelAsset,
    this.threads = 2,
    this.startupTimeout = const Duration(seconds: 20),
    this.inferenceTimeout = const Duration(seconds: 15),
  });

  final String assetPath;
  final int threads;
  final Duration startupTimeout;
  final Duration inferenceTimeout;

  Future<_LoadedPotatoFieldRuntime>? _loading;
  Future<void> _requestTail = Future<void>.value();
  bool _disposed = false;

  Future<_LoadedPotatoFieldRuntime> _ensureLoaded() {
    if (_disposed) {
      throw StateError('potato field tensor runner is disposed');
    }
    final existing = _loading;
    if (existing != null) return existing;
    final loading = _load();
    _loading = loading;
    return loading;
  }

  Future<_LoadedPotatoFieldRuntime> _load() async {
    Interpreter? interpreter;
    try {
      final options = InterpreterOptions()..threads = threads;
      try {
        interpreter = await Interpreter.fromAsset(
          assetPath,
          options: options,
        ).timeout(startupTimeout);
      } finally {
        options.delete();
      }
      _validateTensorContract(interpreter);
      final isolate = await IsolateInterpreter.create(
        address: interpreter.address,
        debugName: 'KrishiDocPotatoFieldModel',
      ).timeout(startupTimeout);
      return _LoadedPotatoFieldRuntime(
        interpreter: interpreter,
        isolate: isolate,
      );
    } catch (_) {
      interpreter?.close();
      _loading = null;
      rethrow;
    }
  }

  static void _validateTensorContract(Interpreter interpreter) {
    final inputs = interpreter.getInputTensors();
    final outputs = interpreter.getOutputTensors();
    const expectedInput = [
      1,
      PotatoFieldResearchPack.inputHeight,
      PotatoFieldResearchPack.inputWidth,
      PotatoFieldResearchPack.inputChannels,
    ];
    const expectedValidity = [1, PotatoFieldResearchPack.validityOutputCount];
    const expectedCondition = [1, PotatoFieldResearchPack.conditionOutputCount];

    if (inputs.length != 1 ||
        inputs.single.type != TensorType.float32 ||
        !_sameShape(inputs.single.shape, expectedInput)) {
      throw PotatoFieldModelContractException(
        'expected one float32 input $expectedInput, got '
        '${inputs.map((tensor) => '${tensor.type} ${tensor.shape}').join(', ')}',
      );
    }
    if (outputs.length != 2 ||
        outputs[0].name != 'validity_logits' ||
        outputs[0].type != TensorType.float32 ||
        !_sameShape(outputs[0].shape, expectedValidity) ||
        outputs[1].name != 'condition_logits' ||
        outputs[1].type != TensorType.float32 ||
        !_sameShape(outputs[1].shape, expectedCondition)) {
      throw PotatoFieldModelContractException(
        'expected float32 validity_logits $expectedValidity followed by '
        'condition_logits $expectedCondition, got '
        '${outputs.map((tensor) => '${tensor.name} ${tensor.type} ${tensor.shape}').join(', ')}',
      );
    }
  }

  static bool _sameShape(List<int> actual, List<int> expected) {
    if (actual.length != expected.length) return false;
    for (var index = 0; index < actual.length; index++) {
      if (actual[index] != expected[index]) return false;
    }
    return true;
  }

  @override
  Future<PotatoFieldRawOutput> run(Float32List normalizedRgbInput) {
    const elementCount =
        PotatoFieldResearchPack.inputWidth *
        PotatoFieldResearchPack.inputHeight *
        PotatoFieldResearchPack.inputChannels;
    if (normalizedRgbInput.length != elementCount) {
      throw PotatoFieldModelContractException(
        'expected $elementCount normalized RGB values, got '
        '${normalizedRgbInput.length}',
      );
    }
    if (_disposed) {
      throw StateError('potato field tensor runner is disposed');
    }

    final result = Completer<PotatoFieldRawOutput>();
    _requestTail = _requestTail.then<void>((_) async {
      try {
        result.complete(await _run(normalizedRgbInput));
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<PotatoFieldRawOutput> _run(Float32List normalizedRgbInput) async {
    final runtime = await _ensureLoaded();
    final input = normalizedRgbInput.reshape<double>(const [
      1,
      PotatoFieldResearchPack.inputHeight,
      PotatoFieldResearchPack.inputWidth,
      PotatoFieldResearchPack.inputChannels,
    ]);
    final validity = [
      List<double>.filled(PotatoFieldResearchPack.validityOutputCount, 0),
    ];
    final condition = [
      List<double>.filled(PotatoFieldResearchPack.conditionOutputCount, 0),
    ];
    try {
      await runtime.isolate
          .runForMultipleInputs([input], {0: validity, 1: condition})
          .timeout(inferenceTimeout);
    } on TimeoutException {
      await dispose();
      throw PotatoFieldModelContractException(
        'model inference exceeded ${inferenceTimeout.inSeconds} seconds',
      );
    }
    return PotatoFieldRawOutput(
      validityLogits: List<double>.unmodifiable(validity.single),
      conditionLogits: List<double>.unmodifiable(condition.single),
    );
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final loading = _loading;
    if (loading == null) return;
    try {
      final runtime = await loading;
      await runtime.isolate.close();
      runtime.interpreter.close();
    } catch (_) {
      // A startup error is returned to the caller that initiated loading.
    }
  }
}

final class _LoadedPotatoFieldRuntime {
  const _LoadedPotatoFieldRuntime({
    required this.interpreter,
    required this.isolate,
  });

  final Interpreter interpreter;
  final IsolateInterpreter isolate;
}

/// Reproduces the evaluation transform: orientation, aspect-preserving
/// bilinear resize, symmetric mean-colour padding, then ImageNet normalize.
final class PotatoFieldImagePreprocessor {
  const PotatoFieldImagePreprocessor();

  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  Float32List prepare(Uint8List encodedImage) {
    final decoded = image_lib.decodeImage(encodedImage);
    if (decoded == null) {
      throw const PotatoFieldModelContractException(
        'captured bytes are not a decodable image',
      );
    }
    final oriented = image_lib.bakeOrientation(decoded);
    final scale =
        PotatoFieldResearchPack.inputWidth /
        math.max(oriented.width, oriented.height);
    final resizedWidth = trainingRound(
      oriented.width * scale,
    ).clamp(1, PotatoFieldResearchPack.inputWidth);
    final resizedHeight = trainingRound(
      oriented.height * scale,
    ).clamp(1, PotatoFieldResearchPack.inputHeight);
    final resized = resizeTrainingRgb(oriented, resizedWidth, resizedHeight);
    final letterboxed = image_lib.Image(
      width: PotatoFieldResearchPack.inputWidth,
      height: PotatoFieldResearchPack.inputHeight,
      numChannels: 3,
    );
    image_lib.fill(letterboxed, color: image_lib.ColorUint8.rgb(124, 116, 104));
    image_lib.compositeImage(
      letterboxed,
      resized,
      dstX: (PotatoFieldResearchPack.inputWidth - resizedWidth) ~/ 2,
      dstY: (PotatoFieldResearchPack.inputHeight - resizedHeight) ~/ 2,
      blend: image_lib.BlendMode.direct,
    );

    final values = Float32List(
      PotatoFieldResearchPack.inputWidth *
          PotatoFieldResearchPack.inputHeight *
          PotatoFieldResearchPack.inputChannels,
    );
    var offset = 0;
    for (var y = 0; y < letterboxed.height; y++) {
      for (var x = 0; x < letterboxed.width; x++) {
        final pixel = letterboxed.getPixel(x, y);
        values[offset++] = (pixel.r.toDouble() / 255 - _mean[0]) / _std[0];
        values[offset++] = (pixel.g.toDouble() / 255 - _mean[1]) / _std[1];
        values[offset++] = (pixel.b.toDouble() / 255 - _mean[2]) / _std[2];
      }
    }
    return values;
  }
}

/// Applies both calibrated heads and the frozen three-signal refusal gate.
final class PotatoFieldTfliteClassifier implements GatedImageClassifier {
  const PotatoFieldTfliteClassifier({
    required this.runner,
    this.preprocessor = const PotatoFieldImagePreprocessor(),
  });

  final PotatoFieldTensorRunner runner;
  final PotatoFieldImagePreprocessor preprocessor;

  @override
  Future<GatedLogits> gatedLogits(Uint8List preparedImage) async {
    final input = preprocessor.prepare(preparedImage);
    final output = await runner.run(input);
    _validateFinite(
      output.validityLogits,
      PotatoFieldResearchPack.validityOutputCount,
      'validity',
    );
    _validateFinite(
      output.conditionLogits,
      PotatoFieldResearchPack.conditionOutputCount,
      'condition',
    );

    final validityProbabilities = _softmax(
      output.validityLogits,
      PotatoFieldResearchPack.validityTemperature,
    );
    final conditionProbabilities = _softmax(
      output.conditionLogits,
      PotatoFieldResearchPack.conditionTemperature,
    );
    final conditionProbability = conditionProbabilities.reduce(math.max);
    final conditionEnergy = _energy(
      output.conditionLogits,
      PotatoFieldResearchPack.conditionTemperature,
    );
    final accepted =
        validityProbabilities.first >=
            PotatoFieldResearchPack.validityProbabilityMin &&
        conditionProbability >=
            PotatoFieldResearchPack.conditionProbabilityMin &&
        conditionEnergy <= PotatoFieldResearchPack.conditionEnergyMax;

    return GatedLogits(
      logits: List<double>.unmodifiable(output.conditionLogits),
      accepted: accepted,
    );
  }

  @override
  Future<List<double>> logits(Uint8List preparedImage) async =>
      (await gatedLogits(preparedImage)).logits;

  static void _validateFinite(
    List<double> values,
    int expectedCount,
    String head,
  ) {
    if (values.length != expectedCount) {
      throw PotatoFieldModelContractException(
        '$head head expected $expectedCount logits, got ${values.length}',
      );
    }
    if (values.any((value) => !value.isFinite)) {
      throw PotatoFieldModelContractException(
        '$head head emitted a non-finite logit',
      );
    }
  }

  static List<double> _softmax(List<double> logits, double temperature) {
    final scaled = [for (final value in logits) value / temperature];
    final maximum = scaled.reduce(math.max);
    final exponentials = [
      for (final value in scaled) math.exp(value - maximum),
    ];
    final total = exponentials.reduce((left, right) => left + right);
    return [for (final value in exponentials) value / total];
  }

  static double _energy(List<double> logits, double temperature) {
    final scaled = [for (final value in logits) value / temperature];
    final maximum = scaled.reduce(math.max);
    final exponentialTotal = scaled
        .map((value) => math.exp(value - maximum))
        .reduce((left, right) => left + right);
    return -temperature * (maximum + math.log(exponentialTotal));
  }

  @override
  Future<void> dispose() => runner.dispose();
}
