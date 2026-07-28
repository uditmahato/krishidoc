import 'dart:convert';
import 'dart:math' as math;

/// Thrown when a model pack manifest is malformed. A pack that cannot be
/// trusted is never partially loaded: a wrong threshold is worse than no
/// diagnosis.
final class ModelPackFormatException implements Exception {
  const ModelPackFormatException(this.message);

  final String message;

  @override
  String toString() => 'ModelPackFormatException: $message';
}

/// What a label means clinically.
///
/// Distinguishing healthy from diseased is not cosmetic: advisory content and
/// treatment prompts must never be attached to a healthy leaf. V1 had no such
/// concept and would happily generate "treatment plans for tomato healthy".
enum LabelKind { disease, healthy }

/// One class the model can emit.
final class LabelSpec {
  const LabelSpec({
    required this.key,
    required this.kind,
    required this.threshold,
  });

  /// Stable model label key. Display names come from reviewed KB data (D-35);
  /// this value is never shown to a farmer.
  final String key;
  final LabelKind kind;

  /// Calibrated probability this class must reach to be called confident.
  /// Per class, because a mistake on a look-alike pair is not equally costly
  /// in both directions (D-17).
  final double threshold;
}

/// Everything needed to turn one model's raw output into a decision.
///
/// Thresholds and calibration ship with the model rather than living in the
/// app, so a recalibration is a pack update and not an app release, and every
/// prediction can be traced to the exact versions that produced it (D-18).
final class ModelPack {
  ModelPack({
    required this.cropKey,
    required this.modelVersion,
    required this.thresholdSetVersion,
    required this.labels,
    required this.temperature,
    required this.rejectionFloor,
    required this.minMargin,
  }) {
    if (labels.length < 2) {
      throw const ModelPackFormatException(
        'a pack needs at least two labels: a single-class model cannot '
        'classify, and every uncertainty rule below assumes alternatives',
      );
    }
    final keys = <String>{};
    for (final label in labels) {
      if (!keys.add(label.key)) {
        throw ModelPackFormatException('duplicate label "${label.key}"');
      }
      if (label.threshold <= 0 || label.threshold > 1) {
        throw ModelPackFormatException(
          'threshold for "${label.key}" must be within (0, 1]',
        );
      }
    }
    if (temperature <= 0) {
      throw const ModelPackFormatException('temperature must be positive');
    }
    if (rejectionFloor >= 1) {
      throw const ModelPackFormatException('rejectionFloor must be below 1');
    }
    // The top probability of a softmax over N classes is never below 1/N, so
    // a floor at or under chance level can never fire: the rule would look
    // like open-set rejection while silently doing nothing, and photos of
    // walls would be labelled as diseases. Refuse the pack instead.
    final chanceLevel = 1 / labels.length;
    if (rejectionFloor <= chanceLevel) {
      throw ModelPackFormatException(
        'rejectionFloor ($rejectionFloor) must exceed the chance level for '
        '${labels.length} labels (${chanceLevel.toStringAsFixed(3)}), '
        'otherwise nothing is ever rejected',
      );
    }
    if (minMargin < 0 || minMargin >= 1) {
      throw const ModelPackFormatException('minMargin must be within [0, 1)');
    }
  }

  final String cropKey;
  final String modelVersion;
  final String thresholdSetVersion;
  final List<LabelSpec> labels;

  /// Temperature-scaling divisor fitted on a held-out set. Raw network
  /// outputs are systematically overconfident; without this the thresholds
  /// would be calibrated against a lie.
  final double temperature;

  /// Below this top probability nothing plausibly matches: the photo is
  /// treated as outside coverage rather than forced onto a class (D-17).
  ///
  /// Must exceed chance level (1 / label count) or it can never fire. When a
  /// manifest omits it, [defaultRejectionFloor] scales it to the pack size.
  final double rejectionFloor;

  /// Half again above chance level: a leader that barely beats guessing is
  /// not a diagnosis. Provisional, pending device-lab and field validation.
  static double defaultRejectionFloor(int labelCount) =>
      math.min(1.5 / labelCount, 0.75);

  /// Minimum gap between the top two classes. Two diseases in a near tie can
  /// carry different treatments, so a coin flip is reported as uncertainty.
  final double minMargin;

  int get labelCount => labels.length;

  factory ModelPack.fromJson(Map<String, Object?> json) {
    T require<T>(String key) {
      final value = json[key];
      if (value is! T) {
        throw ModelPackFormatException('missing or invalid "$key"');
      }
      return value;
    }

    double requireNumber(String key, {double? orElse}) {
      final value = json[key];
      if (value == null && orElse != null) return orElse;
      if (value is! num) {
        throw ModelPackFormatException('missing or invalid "$key"');
      }
      return value.toDouble();
    }

    final rawLabels = json['labels'];
    if (rawLabels is! List || rawLabels.isEmpty) {
      throw const ModelPackFormatException('"labels" must be a non-empty list');
    }
    final labels = [for (final entry in rawLabels) _labelFromJson(entry)];

    return ModelPack(
      cropKey: require<String>('cropKey'),
      modelVersion: require<String>('modelVersion'),
      thresholdSetVersion: require<String>('thresholdSetVersion'),
      temperature: requireNumber('temperature', orElse: 1),
      rejectionFloor: requireNumber(
        'rejectionFloor',
        orElse: defaultRejectionFloor(labels.length),
      ),
      minMargin: requireNumber('minMargin', orElse: 0.1),
      labels: labels,
    );
  }

  factory ModelPack.parse(String source) {
    final Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw ModelPackFormatException('manifest is not valid JSON: $error');
    }
    if (decoded is! Map<String, Object?>) {
      throw const ModelPackFormatException('manifest must be a JSON object');
    }
    return ModelPack.fromJson(decoded);
  }

  static LabelSpec _labelFromJson(Object? entry) {
    if (entry is! Map) {
      throw const ModelPackFormatException('each label must be an object');
    }
    final map = entry.cast<String, Object?>();
    final key = map['key'];
    final kind = map['kind'];
    final threshold = map['threshold'];
    if (key is! String || key.isEmpty) {
      throw const ModelPackFormatException(
        'label "key" must be a non-empty string',
      );
    }
    if (threshold is! num) {
      throw ModelPackFormatException('label "$key" is missing "threshold"');
    }
    return LabelSpec(
      key: key,
      kind: switch (kind) {
        'healthy' => LabelKind.healthy,
        'disease' => LabelKind.disease,
        _ => throw ModelPackFormatException(
          'label "$key" has unknown kind "$kind"',
        ),
      },
      threshold: threshold.toDouble(),
    );
  }

  /// Temperature-scaled softmax over raw logits, in label order.
  ///
  /// The max logit is subtracted before exponentiating: without it, large
  /// logits overflow to infinity and every probability becomes NaN, which
  /// would sail past a naive threshold check.
  List<double> calibrate(List<double> logits) {
    if (logits.length != labels.length) {
      throw ModelPackFormatException(
        'model emitted ${logits.length} logits but the pack declares '
        '${labels.length} labels',
      );
    }
    for (final logit in logits) {
      if (logit.isNaN || logit.isInfinite) {
        throw const ModelPackFormatException(
          'model emitted a non-finite logit',
        );
      }
    }

    final scaled = [for (final logit in logits) logit / temperature];
    final maxLogit = scaled.reduce(math.max);
    final exponentials = [
      for (final value in scaled) math.exp(value - maxLogit),
    ];
    final total = exponentials.reduce((a, b) => a + b);
    return [for (final value in exponentials) value / total];
  }
}
