import 'dart:math';
import 'dart:typed_data';

import 'package:capture/capture.dart';
import 'package:test/test.dart';

/// Alternating pixels: maximum local contrast. Its period of 2 also aliases
/// with even strides, which is exactly why it is worth testing.
Uint8List checkerboard(
  int width,
  int height, {
  required int dark,
  required int light,
}) {
  final plane = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      plane[y * width + x] = (x + y).isEven ? dark : light;
    }
  }
  return plane;
}

Uint8List flat(int width, int height, int value) =>
    Uint8List(width * height)..fillRange(0, width * height, value);

/// Detail with no periodicity, so sampling stride cannot alias with it.
Uint8List noise(int width, int height, {int seed = 42}) {
  final random = Random(seed);
  final plane = Uint8List(width * height);
  for (var i = 0; i < plane.length; i++) {
    plane[i] = random.nextInt(256);
  }
  return plane;
}

void main() {
  const gate = QualityGate();

  group('sharpness', () {
    test('a flat frame is refused as blurry', () {
      final quality = gate.assess(flat(64, 64, 128), width: 64, height: 64);
      expect(quality.issues, contains(CaptureIssue.tooBlurry));
      expect(quality.edgeEnergy, lessThan(1));
      expect(quality.isAcceptable, isFalse);
    });

    test('a detailed, well-exposed frame is accepted', () {
      final quality = gate.assess(
        checkerboard(64, 64, dark: 90, light: 200),
        width: 64,
        height: 64,
      );
      expect(quality.issues, isEmpty);
      expect(quality.isAcceptable, isTrue);
      expect(quality.edgeEnergy, greaterThan(gate.minEdgeEnergy));
    });

    test('a regular texture aliased by the stride is still scored sharp', () {
      // Regression guard: a period-2 pattern sampled at stride 2 yields
      // same-sign Laplacians everywhere. A variance-based score collapses to
      // zero here and refuses a sharp frame; mean absolute Laplacian does
      // not. Woven mats and mesh screens make this a field case, not a
      // synthetic one.
      final aliased = checkerboard(64, 64, dark: 90, light: 200);

      final quality = const QualityGate(
        stride: 2,
      ).assess(aliased, width: 64, height: 64);

      expect(quality.issues, isNot(contains(CaptureIssue.tooBlurry)));
      expect(quality.edgeEnergy, greaterThan(100));
    });
  });

  group('exposure', () {
    test('a sharp but dark frame is refused for exposure only', () {
      final quality = gate.assess(
        checkerboard(64, 64, dark: 0, light: 30),
        width: 64,
        height: 64,
      );
      expect(quality.issues, [CaptureIssue.tooDark]);
      expect(quality.meanLuminance, lessThan(gate.minMeanLuminance));
    });

    test('a sharp but blown-out frame is refused for exposure only', () {
      final quality = gate.assess(
        checkerboard(64, 64, dark: 225, light: 255),
        width: 64,
        height: 64,
      );
      expect(quality.issues, [CaptureIssue.tooBright]);
      expect(quality.meanLuminance, greaterThan(gate.maxMeanLuminance));
    });

    test('a frame can fail several checks at once', () {
      final quality = gate.assess(flat(64, 64, 2), width: 64, height: 64);
      expect(
        quality.issues,
        containsAll([CaptureIssue.tooBlurry, CaptureIssue.tooDark]),
      );
    });
  });

  group('sampling', () {
    test('stride does not change the verdict on aperiodic detail', () {
      final plane = noise(128, 128);
      final dense = const QualityGate(
        stride: 1,
      ).assess(plane, width: 128, height: 128);
      final sparse = const QualityGate(
        stride: 4,
      ).assess(plane, width: 128, height: 128);

      expect(dense.isAcceptable, isTrue);
      expect(sparse.isAcceptable, isTrue);
      expect(sparse.meanLuminance, closeTo(dense.meanLuminance, 8));
      expect(sparse.edgeEnergy, closeTo(dense.edgeEnergy, 20));
    });

    test('a 640x480 frame is assessed well inside a frame budget', () {
      final plane = noise(640, 480);
      final stopwatch = Stopwatch()..start();
      gate.assess(plane, width: 640, height: 480);
      stopwatch.stop();

      // Smoke bound only: it catches an order-of-magnitude regression on a
      // dev machine. The real D-16 budget (30 ms on a 2018 device) is a
      // device-lab measurement, not a CI assertion.
      expect(stopwatch.elapsedMilliseconds, lessThan(500));
    });
  });

  group('input validation', () {
    test('rejects frames too small for the kernel', () {
      expect(
        () => gate.assess(flat(2, 2, 128), width: 2, height: 2),
        throwsArgumentError,
      );
    });

    test('rejects a plane shorter than its declared dimensions', () {
      expect(
        () => gate.assess(Uint8List(100), width: 64, height: 64),
        throwsArgumentError,
      );
    });
  });
}
