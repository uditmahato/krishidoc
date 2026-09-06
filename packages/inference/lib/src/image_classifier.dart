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

/// Raw condition logits plus an upstream open-set decision.
///
/// Some field models have a separate validity head. That head must be allowed
/// to reject a wall, another crop, or an unusable view before the condition
/// logits reach the ordinary label resolver. Keeping the boolean beside the
/// logits prevents an adapter from manufacturing a synthetic disease class.
final class GatedLogits {
  const GatedLogits({required this.logits, required this.accepted});

  final List<double> logits;
  final bool accepted;
}

/// Optional richer classifier contract for models with an open-set gate.
///
/// [ClassificationService] detects this interface and forces a rejected image
/// to the out-of-scope state. Existing single-head classifiers remain valid
/// [ImageClassifier] implementations.
abstract interface class GatedImageClassifier implements ImageClassifier {
  Future<GatedLogits> gatedLogits(Uint8List preparedImage);
}
