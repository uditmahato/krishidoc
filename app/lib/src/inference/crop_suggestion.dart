import 'dart:typed_data';

import 'package:inference/inference.dart';

/// Crop identification from the existing global model, before disease routing.
/// Thresholds are provisional UX heuristics, not calibrated accuracy claims.
/// Every suggestion must be confirmed or corrected by the farmer.
final class CropSuggestionService {
  const CropSuggestionService(this.classifier);
  final ImageClassifier classifier;

  Future<String?> suggest(Uint8List image) async {
    final probabilities = ExperimentalPlantPack.global.calibrate(
      await classifier.logits(image),
    );
    return fromProbabilities(probabilities);
  }

  static String? fromProbabilities(List<double> probabilities) {
    if (probabilities.length != ExperimentalPlantPack.outputCount ||
        probabilities.any((p) => !p.isFinite || p < 0 || p > 1)) {
      throw const FormatException('Invalid crop identification output');
    }
    final total = probabilities.fold<double>(0, (a, b) => a + b);
    if ((total - 1).abs() > 0.02) {
      throw const FormatException('Crop probabilities must sum to one');
    }
    var best = 0;
    for (var i = 1; i < probabilities.length; i++) {
      if (probabilities[i] > probabilities[best]) best = i;
    }
    final winner = ExperimentalPlantPack.labelKeys[best];
    // Do not filter unsupported crops first: doing so manufactures a supported
    // crop out of a globally stronger apple, pepper, or other plant prediction.
    final crop = winner.split('_').first;
    if (!ExperimentalPlantPack.enabledCrops.contains(crop)) return null;
    final scores = <String, double>{};
    for (var i = 0; i < probabilities.length; i++) {
      final key = ExperimentalPlantPack.labelKeys[i].split('_').first;
      scores[key] = (scores[key] ?? 0) + probabilities[i];
    }
    final score = scores[crop]!;
    final competing = scores.entries
        .where((entry) => entry.key != crop)
        .fold<double>(
          0,
          (best, entry) => entry.value > best ? entry.value : best,
        );
    if (score < 0.70 || score - competing < 0.15) return null;
    return crop;
  }
}
