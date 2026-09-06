import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:image/image.dart' as image_lib;
import 'package:inference/inference.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

const String experimentalPlantModelAsset =
    'assets/models/plant_disease_experimental.tflite';

final class ExperimentalModelContractException implements Exception {
  const ExperimentalModelContractException(this.message);

  final String message;

  @override
  String toString() => 'ExperimentalModelContractException: $message';
}

/// Tensor runner seam: tests supply deterministic output without loading FFI.
abstract interface class ExperimentalTensorRunner {
  Future<List<double>> run(Float32List rgbInput);

  Future<void> dispose();
}

/// Official TensorFlow Lite runtime for the pinned 38-output model.
///
/// Flutter assets must be read on the root isolate. Their bytes are transferred
/// once to a persistent worker isolate, where interpreter construction and
/// every invocation run away from Flutter's UI isolate. Requests are serialized
/// because a TensorFlow Lite interpreter must not be invoked concurrently.
///
/// The worker validates the tensor contract before announcing that it is
/// ready. A swapped or corrupt asset therefore fails closed instead of
/// silently attaching the wrong label order to its output.
final class TfliteExperimentalTensorRunner implements ExperimentalTensorRunner {
  TfliteExperimentalTensorRunner({
    this.assetPath = experimentalPlantModelAsset,
    this.threads = 2,
    this.startupTimeout = const Duration(seconds: 20),
    this.inferenceTimeout = const Duration(seconds: 15),
  });

  final String assetPath;
  final int threads;
  final Duration startupTimeout;
  final Duration inferenceTimeout;

  Future<_ExperimentalModelWorker>? _loading;
  bool _disposed = false;

  Future<_ExperimentalModelWorker> _ensureLoaded() {
    if (_disposed) {
      throw StateError('experimental tensor runner is disposed');
    }
    final existing = _loading;
    if (existing != null) return existing;
    final loading = _loadWorker();
    _loading = loading;
    return loading;
  }

  Future<_ExperimentalModelWorker> _loadWorker() async {
    try {
      return await _ExperimentalModelWorker.start(
        assetPath: assetPath,
        threads: threads,
        startupTimeout: startupTimeout,
      );
    } catch (_) {
      // A transient asset/runtime failure must not poison every later retry
      // for the lifetime of the provider container.
      _loading = null;
      rethrow;
    }
  }

  Future<void> _forgetAndStopWorker(
    _ExperimentalModelWorker worker,
    ExperimentalModelContractException failure,
  ) async {
    _loading = null;
    await worker.abort(failure);
  }

  ExperimentalModelContractException _inferenceTimeoutFailure() =>
      ExperimentalModelContractException(
        'model inference exceeded ${inferenceTimeout.inSeconds} seconds',
      );

  Future<List<double>> _runWithTimeout(
    _ExperimentalModelWorker worker,
    Float32List rgbInput,
  ) async {
    try {
      return await worker.run(rgbInput).timeout(inferenceTimeout);
    } on TimeoutException {
      final failure = _inferenceTimeoutFailure();
      await _forgetAndStopWorker(worker, failure);
      throw failure;
    } catch (_) {
      if (worker.isStopped) {
        _loading = null;
        await worker.dispose();
      }
      rethrow;
    }
  }

  static void _validateTensorContract(Interpreter interpreter) {
    final inputs = interpreter.getInputTensors();
    final outputs = interpreter.getOutputTensors();
    const expectedInput = [
      1,
      ExperimentalPlantPack.inputHeight,
      ExperimentalPlantPack.inputWidth,
      ExperimentalPlantPack.inputChannels,
    ];
    const expectedOutput = [1, ExperimentalPlantPack.outputCount];

    if (inputs.length != 1 ||
        inputs.single.type != TensorType.float32 ||
        !_sameShape(inputs.single.shape, expectedInput)) {
      throw ExperimentalModelContractException(
        'expected one float32 input $expectedInput, got '
        '${inputs.map((tensor) => '${tensor.type} ${tensor.shape}').join(', ')}',
      );
    }
    if (outputs.length != 1 ||
        outputs.single.type != TensorType.float32 ||
        !_sameShape(outputs.single.shape, expectedOutput)) {
      throw ExperimentalModelContractException(
        'expected one float32 output $expectedOutput, got '
        '${outputs.map((tensor) => '${tensor.type} ${tensor.shape}').join(', ')}',
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
  Future<List<double>> run(Float32List rgbInput) async {
    const elementCount =
        ExperimentalPlantPack.inputWidth *
        ExperimentalPlantPack.inputHeight *
        ExperimentalPlantPack.inputChannels;
    if (rgbInput.length != elementCount) {
      throw ExperimentalModelContractException(
        'expected $elementCount RGB values, got ${rgbInput.length}',
      );
    }

    final worker = await _ensureLoaded();
    return _runWithTimeout(worker, rgbInput);
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final loading = _loading;
    if (loading == null) return;
    try {
      final worker = await loading;
      await worker.dispose();
    } catch (_) {
      // Startup failures are already returned to the caller that triggered
      // loading. Disposal remains safe and idempotent after such a failure.
    }
  }
}

final class _ExperimentalModelWorker {
  _ExperimentalModelWorker._({
    required Isolate isolate,
    required ReceivePort handshakePort,
    required ReceivePort errorPort,
    required ReceivePort exitPort,
  }) : _isolate = isolate,
       _handshakePort = handshakePort,
       _errorPort = errorPort,
       _exitPort = exitPort {
    _handshakeSubscription = _handshakePort.listen(_handleHandshake);
    _errorSubscription = _errorPort.listen(_handleIsolateError);
    _exitSubscription = _exitPort.listen(_handleIsolateExit);
  }

  static Future<_ExperimentalModelWorker> start({
    required String assetPath,
    required int threads,
    required Duration startupTimeout,
  }) async {
    final modelData = await rootBundle
        .load(assetPath)
        .timeout(
          startupTimeout,
          onTimeout: () => throw ExperimentalModelContractException(
            'model asset load exceeded ${startupTimeout.inSeconds} seconds',
          ),
        );
    if (modelData.lengthInBytes == 0) {
      throw ExperimentalModelContractException(
        'model asset is missing or empty: $assetPath',
      );
    }
    final modelBytes = TransferableTypedData.fromList([
      modelData.buffer.asUint8List(
        modelData.offsetInBytes,
        modelData.lengthInBytes,
      ),
    ]);

    final handshakePort = ReceivePort('KrishiDocModelHandshake');
    final errorPort = ReceivePort('KrishiDocModelErrors');
    final exitPort = ReceivePort('KrishiDocModelExit');
    Isolate? isolate;
    _ExperimentalModelWorker? worker;
    try {
      isolate = await Isolate.spawn<_ExperimentalWorkerBootstrap>(
        _experimentalModelWorkerMain,
        _ExperimentalWorkerBootstrap(
          modelBytes: modelBytes,
          threads: threads,
          handshakePort: handshakePort.sendPort,
        ),
        debugName: 'KrishiDocExperimentalPlantModel',
        errorsAreFatal: true,
        onError: errorPort.sendPort,
        onExit: exitPort.sendPort,
      );
      worker = _ExperimentalModelWorker._(
        isolate: isolate,
        handshakePort: handshakePort,
        errorPort: errorPort,
        exitPort: exitPort,
      );
      await worker._waitUntilReady().timeout(
        startupTimeout,
        onTimeout: () => throw ExperimentalModelContractException(
          'model worker startup exceeded ${startupTimeout.inSeconds} seconds',
        ),
      );
      return worker;
    } catch (error) {
      final activeWorker = worker;
      if (activeWorker != null) {
        await activeWorker.abort(
          ExperimentalModelContractException(
            'model worker startup aborted: $error',
          ),
        );
      } else {
        isolate?.kill(priority: Isolate.immediate);
        handshakePort.close();
        errorPort.close();
        exitPort.close();
      }
      rethrow;
    }
  }

  final Isolate _isolate;
  final ReceivePort _handshakePort;
  final ReceivePort _errorPort;
  final ReceivePort _exitPort;
  final Completer<Object> _startup = Completer<Object>();
  final Completer<ExperimentalModelContractException> _stopped =
      Completer<ExperimentalModelContractException>();
  final Completer<void> _exited = Completer<void>();

  late final StreamSubscription<Object?> _handshakeSubscription;
  late final StreamSubscription<Object?> _errorSubscription;
  late final StreamSubscription<Object?> _exitSubscription;

  SendPort? _commands;
  Future<void> _requestTail = Future<void>.value();
  Future<void>? _disposing;
  var _nextRequestId = 0;
  var _acceptingRequests = true;
  var _closing = false;
  var _portsClosed = false;

  bool get isStopped => _stopped.isCompleted || _exited.isCompleted;

  void _handleHandshake(Object? message) {
    switch (message) {
      case _ExperimentalWorkerReady(:final commands):
        _commands = commands;
        if (!_startup.isCompleted) _startup.complete(commands);
      case _ExperimentalWorkerFailure(:final message, :final stackTrace):
        final failure = ExperimentalModelContractException(
          'model worker could not start: $message\n$stackTrace',
        );
        if (!_startup.isCompleted) _startup.complete(failure);
        _markStopped(failure);
      default:
        final failure = ExperimentalModelContractException(
          'model worker sent an invalid startup message: $message',
        );
        if (!_startup.isCompleted) _startup.complete(failure);
        _markStopped(failure);
    }
  }

  void _handleIsolateError(Object? message) {
    final parts = message is List<Object?> ? message : <Object?>[message];
    final failure = ExperimentalModelContractException(
      'model worker crashed: ${parts.join('\n')}',
    );
    if (!_startup.isCompleted) _startup.complete(failure);
    _markStopped(failure);
  }

  void _handleIsolateExit(Object? _) {
    if (!_exited.isCompleted) _exited.complete();
    if (_closing) return;
    final failure = const ExperimentalModelContractException(
      'model worker exited unexpectedly',
    );
    if (!_startup.isCompleted) _startup.complete(failure);
    _markStopped(failure);
  }

  void _markStopped(ExperimentalModelContractException failure) {
    if (!_stopped.isCompleted) _stopped.complete(failure);
  }

  Future<void> _waitUntilReady() async {
    final result = await Future.any<Object>([_startup.future, _stopped.future]);
    if (result case final ExperimentalModelContractException failure) {
      throw failure;
    }
    if (result is! SendPort) {
      throw const ExperimentalModelContractException(
        'model worker did not return a command port',
      );
    }
  }

  Future<List<double>> run(Float32List input) {
    if (!_acceptingRequests) {
      return Future<List<double>>.error(
        StateError('experimental tensor runner is disposed'),
      );
    }

    final transferable = TransferableTypedData.fromList([
      input.buffer.asUint8List(input.offsetInBytes, input.lengthInBytes),
    ]);
    return _enqueue(() => _sendRun(transferable));
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = Completer<T>();
    _requestTail = _requestTail.then<void>((_) async {
      try {
        result.complete(await operation());
      } catch (error, stackTrace) {
        result.completeError(error, stackTrace);
      }
    });
    return result.future;
  }

  Future<List<double>> _sendRun(TransferableTypedData input) async {
    final commands = _commands;
    if (commands == null) {
      throw const ExperimentalModelContractException(
        'model worker has no command port',
      );
    }

    final requestId = _nextRequestId++;
    final replyPort = ReceivePort('KrishiDocModelReply$requestId');
    try {
      commands.send(
        _ExperimentalRunRequest(
          requestId: requestId,
          input: input,
          replyPort: replyPort.sendPort,
        ),
      );
      final response = await Future.any<Object?>([
        replyPort.cast<Object?>().first,
        _stopped.future,
      ]);
      switch (response) {
        case _ExperimentalRunSuccess(
          requestId: final responseId,
          :final probabilities,
        ):
          if (responseId != requestId ||
              probabilities.length != ExperimentalPlantPack.outputCount) {
            throw ExperimentalModelContractException(
              'model worker returned an invalid response for request '
              '$requestId',
            );
          }
          return List<double>.unmodifiable(probabilities);
        case _ExperimentalWorkerFailure(
          requestId: final responseId,
          :final message,
          :final stackTrace,
        ):
          throw ExperimentalModelContractException(
            'model inference ${responseId ?? requestId} failed: '
            '$message\n$stackTrace',
          );
        case final ExperimentalModelContractException failure:
          throw failure;
        default:
          throw ExperimentalModelContractException(
            'model worker returned an invalid response: $response',
          );
      }
    } finally {
      replyPort.close();
    }
  }

  Future<void> dispose() => _disposing ??= _dispose();

  Future<void> abort(ExperimentalModelContractException failure) {
    _acceptingRequests = false;
    _closing = true;
    _markStopped(failure);
    _isolate.kill(priority: Isolate.immediate);
    return dispose();
  }

  Future<void> _dispose() async {
    _acceptingRequests = false;
    try {
      await _requestTail.timeout(const Duration(seconds: 3));
    } on TimeoutException {
      _markStopped(
        const ExperimentalModelContractException(
          'model worker did not finish its active request during shutdown',
        ),
      );
      _isolate.kill(priority: Isolate.immediate);
    }
    _closing = true;

    try {
      if (!_exited.isCompleted && !_stopped.isCompleted) {
        final commands = _commands;
        if (commands != null) {
          final replyPort = ReceivePort('KrishiDocModelDispose');
          try {
            commands.send(_ExperimentalDisposeRequest(replyPort.sendPort));
            Object? response;
            try {
              response = await Future.any<Object?>([
                replyPort.cast<Object?>().first,
                _stopped.future,
                _exited.future.then<Object?>(
                  (_) => const _ExperimentalWorkerExited(),
                ),
              ]).timeout(const Duration(seconds: 3));
            } on TimeoutException {
              _isolate.kill(priority: Isolate.immediate);
              response = const _ExperimentalWorkerExited();
            }
            if (response is! _ExperimentalWorkerDisposed &&
                response is! _ExperimentalWorkerExited &&
                response is! ExperimentalModelContractException) {
              throw ExperimentalModelContractException(
                'model worker returned an invalid dispose response: $response',
              );
            }
          } finally {
            replyPort.close();
          }
        }
      }

      if (!_exited.isCompleted) {
        _isolate.kill(priority: Isolate.immediate);
        try {
          await _exited.future.timeout(const Duration(seconds: 3));
        } on TimeoutException {
          // Native code may be uninterruptible. All Dart callers are already
          // released through _stopped, so teardown remains bounded.
        }
      }
    } finally {
      await _closePorts();
    }
  }

  Future<void> _closePorts() async {
    if (_portsClosed) return;
    _portsClosed = true;
    await _handshakeSubscription.cancel();
    await _errorSubscription.cancel();
    await _exitSubscription.cancel();
    _handshakePort.close();
    _errorPort.close();
    _exitPort.close();
  }
}

final class _ExperimentalWorkerBootstrap {
  const _ExperimentalWorkerBootstrap({
    required this.modelBytes,
    required this.threads,
    required this.handshakePort,
  });

  final TransferableTypedData modelBytes;
  final int threads;
  final SendPort handshakePort;
}

final class _ExperimentalWorkerReady {
  const _ExperimentalWorkerReady(this.commands);

  final SendPort commands;
}

final class _ExperimentalRunRequest {
  const _ExperimentalRunRequest({
    required this.requestId,
    required this.input,
    required this.replyPort,
  });

  final int requestId;
  final TransferableTypedData input;
  final SendPort replyPort;
}

final class _ExperimentalDisposeRequest {
  const _ExperimentalDisposeRequest(this.replyPort);

  final SendPort replyPort;
}

final class _ExperimentalRunSuccess {
  const _ExperimentalRunSuccess({
    required this.requestId,
    required this.probabilities,
  });

  final int requestId;
  final List<double> probabilities;
}

final class _ExperimentalWorkerFailure {
  const _ExperimentalWorkerFailure({
    required this.requestId,
    required this.message,
    required this.stackTrace,
  });

  final int? requestId;
  final String message;
  final String stackTrace;
}

final class _ExperimentalWorkerDisposed {
  const _ExperimentalWorkerDisposed();
}

final class _ExperimentalWorkerExited {
  const _ExperimentalWorkerExited();
}

@pragma('vm:entry-point')
Future<void> _experimentalModelWorkerMain(
  _ExperimentalWorkerBootstrap bootstrap,
) async {
  final requests = ReceivePort('KrishiDocModelCommands');
  Interpreter? interpreter;
  try {
    final modelBytes = bootstrap.modelBytes.materialize().asUint8List();
    final options = InterpreterOptions()..threads = bootstrap.threads;
    try {
      interpreter = Interpreter.fromBuffer(modelBytes, options: options);
    } finally {
      options.delete();
    }
    TfliteExperimentalTensorRunner._validateTensorContract(interpreter);

    bootstrap.handshakePort.send(_ExperimentalWorkerReady(requests.sendPort));

    await for (final message in requests) {
      switch (message) {
        case _ExperimentalRunRequest(
          :final requestId,
          :final input,
          :final replyPort,
        ):
          try {
            final bytes = input.materialize().asUint8List();
            final values = Float32List.view(
              bytes.buffer,
              bytes.offsetInBytes,
              bytes.lengthInBytes ~/ Float32List.bytesPerElement,
            );
            const elementCount =
                ExperimentalPlantPack.inputWidth *
                ExperimentalPlantPack.inputHeight *
                ExperimentalPlantPack.inputChannels;
            if (values.length != elementCount) {
              throw ExperimentalModelContractException(
                'worker expected $elementCount RGB values, got '
                '${values.length}',
              );
            }

            final tensorInput = values.reshape<double>(const [
              1,
              ExperimentalPlantPack.inputHeight,
              ExperimentalPlantPack.inputWidth,
              ExperimentalPlantPack.inputChannels,
            ]);
            final output = [
              List<double>.filled(ExperimentalPlantPack.outputCount, 0),
            ];
            final activeInterpreter = interpreter;
            if (activeInterpreter == null) {
              throw const ExperimentalModelContractException(
                'model worker interpreter is not available',
              );
            }
            activeInterpreter.run(tensorInput, output);
            replyPort.send(
              _ExperimentalRunSuccess(
                requestId: requestId,
                probabilities: output.single,
              ),
            );
          } catch (error, stackTrace) {
            replyPort.send(
              _ExperimentalWorkerFailure(
                requestId: requestId,
                message: '$error',
                stackTrace: '$stackTrace',
              ),
            );
          }
        case _ExperimentalDisposeRequest(:final replyPort):
          interpreter?.close();
          interpreter = null;
          replyPort.send(const _ExperimentalWorkerDisposed());
          requests.close();
        default:
          throw ExperimentalModelContractException(
            'model worker received an invalid command: $message',
          );
      }
    }
  } catch (error, stackTrace) {
    bootstrap.handshakePort.send(
      _ExperimentalWorkerFailure(
        requestId: null,
        message: '$error',
        stackTrace: '$stackTrace',
      ),
    );
  } finally {
    interpreter?.close();
    requests.close();
  }
}

/// Decodes and stretches a captured RGB image to the pinned model dimensions.
///
/// The pinned source's training and test programs resize RGB images to
/// 224 x 224 and divide each channel by 255 before invoking the model. The
/// transform is not embedded in the graph, so this caller must reproduce it.
final class ExperimentalPlantImagePreprocessor {
  const ExperimentalPlantImagePreprocessor();

  Float32List prepare(Uint8List encodedImage) {
    final decoded = image_lib.decodeImage(encodedImage);
    if (decoded == null) {
      throw const ExperimentalModelContractException(
        'captured bytes are not a decodable image',
      );
    }
    final oriented = image_lib.bakeOrientation(decoded);
    final resized = image_lib.copyResize(
      oriented,
      width: ExperimentalPlantPack.inputWidth,
      height: ExperimentalPlantPack.inputHeight,
      maintainAspect: false,
      interpolation: image_lib.Interpolation.nearest,
    );

    final values = Float32List(
      ExperimentalPlantPack.inputWidth *
          ExperimentalPlantPack.inputHeight *
          ExperimentalPlantPack.inputChannels,
    );
    var offset = 0;
    for (var y = 0; y < resized.height; y++) {
      for (var x = 0; x < resized.width; x++) {
        final pixel = resized.getPixel(x, y);
        values[offset++] = pixel.r.toDouble() / 255;
        values[offset++] = pixel.g.toDouble() / 255;
        values[offset++] = pixel.b.toDouble() / 255;
      }
    }
    return values;
  }
}

/// Genuine on-device model adapter, restricted to experimental possible matches.
final class ExperimentalTfliteClassifier implements ImageClassifier {
  const ExperimentalTfliteClassifier({
    required this.runner,
    this.preprocessor = const ExperimentalPlantImagePreprocessor(),
  });

  final ExperimentalTensorRunner runner;
  final ExperimentalPlantImagePreprocessor preprocessor;

  @override
  Future<List<double>> logits(Uint8List preparedImage) async {
    final input = preprocessor.prepare(preparedImage);
    final probabilities = await runner.run(input);
    if (probabilities.length != ExperimentalPlantPack.outputCount) {
      throw ExperimentalModelContractException(
        'expected ${ExperimentalPlantPack.outputCount} outputs, got '
        '${probabilities.length}',
      );
    }

    var total = 0.0;
    for (final value in probabilities) {
      if (!value.isFinite || value < 0 || value > 1) {
        throw ExperimentalModelContractException(
          'model emitted invalid softmax value $value',
        );
      }
      total += value;
    }
    if ((total - 1).abs() > 0.02) {
      throw ExperimentalModelContractException(
        'softmax output must sum to 1, got $total',
      );
    }

    // ClassificationService expects logits and applies its pack calibration.
    // The graph already emits softmax probabilities, so log(p) reconstructs
    // logits whose temperature-1 softmax returns the same distribution.
    return [
      for (final probability in probabilities)
        math.log(math.max(probability, 1e-12)),
    ];
  }

  @override
  Future<void> dispose() => runner.dispose();
}
