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
  });

  final ImageClassifier classifier;
  final ModelPack pack;
  final PredictionResolver resolver;

  Future<ClassificationOutcome> classify(Uint8List preparedImage) async {
    final logits = await classifier.logits(preparedImage);
    final probabilities = pack.calibrate(logits);
    return resolver.resolve(probabilities: probabilities, pack: pack);
  }
}
