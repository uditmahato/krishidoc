import 'package:core_domain/core_domain.dart';
import 'package:inference/inference.dart';

/// Recovers the certainty band for a stored diagnosis.
///
/// The band is not persisted. That is a deliberate choice rather than an
/// oversight: a band is an interpretation of a probability against a threshold,
/// thresholds ship with the model and are expected to be retuned (D-18), and
/// storing the interpretation would freeze a reading of the data next to the
/// data it was read from, which is how the two silently disagree.
///
/// The safety rule is the whole point of this function. A band may only be
/// recomputed when the pack that produced the record is the pack in hand. If
/// the model version has moved on, the stored probability was calibrated
/// against thresholds we no longer have, so reinterpreting it would be a guess
/// wearing a number's clothes. In that case, and whenever the label is absent
/// from the pack, the answer is the most cautious band available: over-stating
/// certainty is how a farmer ends up spraying on our word.
CertaintyBand? certaintyFor(DiagnosisRecord record, ModelPack? pack) {
  if (record.state != ResultState.confident) return null;
  if (record.predictions.isEmpty) return null;
  if (pack == null || pack.modelVersion != record.modelVersion) {
    return CertaintyBand.low;
  }

  final top = record.predictions.first;
  final spec = pack.labels.where((label) => label.key == top.label).firstOrNull;
  if (spec == null) return CertaintyBand.low;
  if (spec.threshold >= 1) return CertaintyBand.high;

  return CertaintyBand.fromHeadroom(
    (top.confidence - spec.threshold) / (1 - spec.threshold),
  );
}
