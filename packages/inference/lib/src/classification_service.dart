import 'dart:typed_data';

import 'image_classifier.dart';
import 'model_pack.dart';
import 'prediction_resolver.dart';

/// Runs one image through the on-device path: model, calibration, decision.
///
/// Nothing here touches the network. This is the offline core loop's engine
/// (D-05), and it must keep working when the app has no signal at all.
final class ClassificationService {
  const ClassificationService({
    required this.classifier,
    required this.pack,
    this.resolver = const PredictionResolver(),
    this.allowedLabelKeys,
  });

  final ImageClassifier classifier;
  final ModelPack pack;
  final PredictionResolver resolver;

  /// Optional closed crop scope for a global model.
  ///
  /// A model may emit labels for several crops while the farmer has selected
  /// exactly one. The resolver keeps the global output intact and rejects a
  /// winner outside this set. It must never renormalise only the selected
  /// crop's labels: doing so would turn "this looks like another crop" into a
  /// confident disease match for the wrong crop.
  final Set<String>? allowedLabelKeys;

  Future<ClassificationOutcome> classify(Uint8List preparedImage) async {
    final gated = classifier is GatedImageClassifier
        ? await (classifier as GatedImageClassifier).gatedLogits(preparedImage)
        : GatedLogits(
            logits: await classifier.logits(preparedImage),
            accepted: true,
          );
    final logits = gated.logits;
    final probabilities = pack.calibrate(logits);
    return resolver.resolve(
      probabilities: probabilities,
      pack: pack,
      allowedLabelKeys: allowedLabelKeys,
      forceOutOfScope: !gated.accepted,
    );
  }
}
