import 'dart:typed_data';

/// The model runtime, behind a port.
///
/// The concrete implementation (a quantized LiteRT interpreter, D-15) is
/// absent until it can be measured on real hardware: its latency budget and
/// its accuracy are both device facts, not desk facts. Everything decided
/// from its output is built and tested against this interface.
abstract interface class ImageClassifier {
  /// Raw, uncalibrated logits in the pack's label order.
  Future<List<double>> logits(Uint8List preparedImage);

  Future<void> dispose();
}
