import 'dart:math' as math;
import 'dart:typed_data';

import 'image_classifier.dart';
import 'model_pack.dart';

/// A stand-in for the model runtime that produces **agronomically meaningless**
/// output.
///
/// It exists because every screen downstream of inference (the result card, the
/// certainty band, History, the escalation path) is unbuildable and untestable
/// until something answers the shutter, and the real LiteRT runtime is blocked
/// on a trained `.tflite` that does not exist yet.
///
/// ## This must never reach a farmer
///
/// The output is a hash of the image bytes. It has no relationship whatsoever to
/// what is in the photograph. A farmer acting on it would spray a healthy crop
/// or leave a diseased one untreated. Two guards keep that from happening
/// quietly:
///
/// * every pack it is used with carries a `modelVersion` beginning `sample-`,
///   which the UI is required to surface as a permanent, non-dismissable notice;
/// * `assertNotSample` below gives release wiring one line to fail on.
///
/// ## Why it is deterministic
///
/// The same image always yields the same answer. A farmer who retakes what is
/// effectively the same photograph and gets a different disease each time learns
/// that the app is guessing, and that lesson is not one we can un-teach later.
/// Determinism also means tests can pin exact outcomes.
///
/// ## Why it is specified by the pack rather than by constants
///
/// It emits logits that, after the pack's own temperature scaling, land on a
/// probability profile chosen relative to that pack's `rejectionFloor`, its
/// per-label `threshold`, and its `minMargin`. So it produces all three of the
/// D-17 states by construction, for any pack, and it stays correct if those
/// calibration constants are retuned. `ModelPack.calibrate` computes
/// `softmax(logits / temperature)`, so emitting `temperature * ln(p)` recovers
/// exactly `p`, which is what makes the targeting exact instead of approximate.
final class SampleClassifier implements ImageClassifier {
  const SampleClassifier({required this.pack, this.seed = 0x9E3779B9});

  final ModelPack pack;

  /// Changes which photographs land in which band, without making any single
  /// photograph's answer unstable.
  final int seed;

  /// Roughly how often each outcome appears across many different photos.
  /// Weighted towards confident so the flow is demonstrable, while still
  /// exercising the two states that carry the app's honesty.
  static const double _confidentShare = 0.60;
  static const double _uncertainShare = 0.25; // out of scope takes the rest

  @override
  Future<List<double>> logits(Uint8List preparedImage) async {
    final digest = _hash(preparedImage);
    final band = _unitFrom(digest);
    final winner = (digest >> 16) % pack.labelCount;

    final probabilities = _profile(band: band, winner: winner);

    // softmax(logits / temperature) == probabilities, exactly.
    return [for (final p in probabilities) pack.temperature * math.log(p)];
  }

  List<double> _profile({required double band, required int winner}) {
    final threshold = pack.labels[winner].threshold;
    final double top;
    if (band < _confidentShare) {
      // Clear of its own threshold, and far enough clear of the runner up that
      // the near-tie rule cannot fire.
      top = math.min(0.97, threshold + (1 - threshold) * 0.6);
    } else if (band < _confidentShare + _uncertainShare) {
      // Above the rejection floor but under its own threshold: uncertain by
      // the second rule in PredictionResolver, which is the interesting one.
      top = pack.rejectionFloor + (threshold - pack.rejectionFloor) * 0.5;
    } else {
      // Under the floor, so nothing is vouched for and the answer is "this is
      // outside what I cover".
      top = pack.rejectionFloor * 0.8;
    }

    final rest = (1 - top) / (pack.labelCount - 1);
    assert(
      rest < top,
      'the intended winner must actually rank first: top $top, rest $rest',
    );
    return [for (var i = 0; i < pack.labelCount; i++) i == winner ? top : rest];
  }

  /// FNV-1a over a strided sample of the bytes. Striding keeps this cheap on a
  /// megabyte of JPEG while still reading the whole file, and the length is
  /// mixed in so two images sharing a prefix cannot collide.
  int _hash(Uint8List bytes) {
    var hash = 0x811C9DC5 ^ seed;
    final stride = math.max(1, bytes.length ~/ 512);
    for (var i = 0; i < bytes.length; i += stride) {
      hash = (hash ^ bytes[i]) * 0x01000193;
      hash &= 0x7FFFFFFF;
    }
    hash = (hash ^ bytes.length) * 0x01000193;
    return hash & 0x7FFFFFFF;
  }

  double _unitFrom(int digest) => (digest % 1000) / 1000.0;

  @override
  Future<void> dispose() async {}
}

/// Fails loudly if a pack is a sample pack.
///
/// Call this from any code path that must only ever run against a real model,
/// so that shipping the stand-in is a crash at wiring time rather than a wrong
/// answer in a field.
void assertNotSample(ModelPack pack) {
  if (isSamplePack(pack)) {
    throw StateError(
      'refusing to run against sample model pack "${pack.modelVersion}": '
      'its output is a hash of the image and means nothing',
    );
  }
}

/// Whether this pack's answers are stand-in data rather than a model's.
///
/// The UI keys its permanent sample-data notice off this, so the marker lives
/// in the version string that is already recorded on every stored diagnosis
/// (D-18). A record written today stays identifiable as sample data forever,
/// which matters the first time real and sample records share a database.
bool isSamplePack(ModelPack pack) => isSampleModelVersion(pack.modelVersion);

/// The same rule, asked of a version string rather than a loaded pack.
///
/// A screen rendering a *stored* diagnosis must ask it this way. Asking the
/// pack currently in hand answers a different question: once a real pack
/// replaces the stand-in, `isSamplePack` on that pack is false while the old
/// record is still sample data, and the notice would quietly disappear from
/// the very rows that most need it. ADR-0052 requires the marker to outlive
/// the pack that wrote it, so the predicate has to read the record's own
/// `modelVersion`.
bool isSampleModelVersion(String modelVersion) =>
    modelVersion.startsWith('sample-');
