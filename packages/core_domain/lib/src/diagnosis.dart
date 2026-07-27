import 'result_state.dart';

/// One classifier candidate. [confidence] is a calibrated probability in
/// [0, 1]; percentages and display formatting are presentation concerns.
final class TopPrediction {
  TopPrediction({required this.label, required this.confidence}) {
    if (confidence.isNaN || confidence < 0 || confidence > 1) {
      throw ArgumentError.value(
        confidence,
        'confidence',
        'must be within [0, 1]',
      );
    }
    if (label.trim().isEmpty) {
      throw ArgumentError.value(label, 'label', 'must not be empty');
    }
  }

  /// Stable model label key. Display names come from KB data (D-35), never
  /// from this value.
  final String label;
  final double confidence;

  Map<String, Object> toJson() => {'label': label, 'confidence': confidence};

  factory TopPrediction.fromJson(Map<String, Object?> json) => TopPrediction(
    label: json['label']! as String,
    confidence: (json['confidence']! as num).toDouble(),
  );

  @override
  bool operator ==(Object other) =>
      other is TopPrediction &&
      other.label == label &&
      other.confidence == confidence;

  @override
  int get hashCode => Object.hash(label, confidence);
}

/// A locally stored diagnosis (D-05: history is device-first).
///
/// Invariants follow D-17: a confident record carries at least one
/// prediction, an uncertain record carries at least two (there is nothing to
/// be uncertain between otherwise), and an out-of-scope record may carry
/// none. Construction is the only way to get an instance, so invalid states
/// are unrepresentable at rest as well as on screen.
final class DiagnosisRecord {
  DiagnosisRecord({
    required this.id,
    required this.state,
    required this.predictions,
    required this.modelVersion,
    required this.createdAt,
    this.cropKey,
    this.imagePath,
  }) {
    final minimum = switch (state) {
      ResultState.confident => 1,
      ResultState.uncertain => 2,
      ResultState.outOfScope => 0,
    };
    if (predictions.length < minimum) {
      throw ArgumentError(
        '${state.name} requires at least $minimum prediction(s), '
        'got ${predictions.length}',
      );
    }
    if (!createdAt.isUtc) {
      throw ArgumentError.value(createdAt, 'createdAt', 'must be UTC');
    }
  }

  /// Client-generated UUIDv7 (D-11): identity exists offline at birth.
  final String id;
  final ResultState state;
  final List<TopPrediction> predictions;
  final String modelVersion;
  final DateTime createdAt;
  final String? cropKey;

  /// Device-local path of the captured derivative, if retained (D-12).
  final String? imagePath;
}
