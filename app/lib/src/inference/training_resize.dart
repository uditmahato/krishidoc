import 'dart:math' as math;

import 'package:image/image.dart' as img;

/// Separable, antialiased triangle resampling for the potato training contract.
/// Downsampling must integrate neighbouring pixels, not just sample four points.
/// Pixel-centre coordinates and 8-bit intermediate rounding match Pillow's RGB
/// bilinear transform. Fixed reference fixtures guard this numerical contract.
img.Image resizeTrainingRgb(img.Image source, int width, int height) {
  if (source.width == width && source.height == height) return source;
  const precision = 1 << 22;
  List<({int start, List<int> weights})> coefficients(int input, int output) {
    final scale = input / output;
    final radius = math.max(1.0, scale);
    return List.generate(output, (position) {
      final centre = (position + 0.5) * scale;
      final start = math.max(0, (centre - radius + 0.5).floor());
      final end = math.min(input, (centre + radius + 0.5).floor());
      final weights = List.generate(
        end - start,
        (offset) =>
            math.max(0.0, 1 - ((start + offset + 0.5 - centre) / radius).abs()),
      );
      final total = weights.reduce((a, b) => a + b);
      return (
        start: start,
        weights: [
          for (final weight in weights) (weight / total * precision).round(),
        ],
      );
    });
  }

  img.Image pass(img.Image input, int outputSize, {required bool horizontal}) {
    final table = coefficients(
      horizontal ? input.width : input.height,
      outputSize,
    );
    final output = img.Image(
      width: horizontal ? outputSize : input.width,
      height: horizontal ? input.height : outputSize,
      numChannels: 3,
    );
    for (final pixel in output) {
      final entry = table[horizontal ? pixel.x : pixel.y];
      var red = precision ~/ 2;
      var green = red;
      var blue = red;
      for (var k = 0; k < entry.weights.length; k++) {
        final p = input.getPixel(
          horizontal ? entry.start + k : pixel.x,
          horizontal ? pixel.y : entry.start + k,
        );
        final weight = entry.weights[k];
        red += p.r.toInt() * weight;
        green += p.g.toInt() * weight;
        blue += p.b.toInt() * weight;
      }
      pixel
        ..r = (red >> 22).clamp(0, 255)
        ..g = (green >> 22).clamp(0, 255)
        ..b = (blue >> 22).clamp(0, 255);
    }
    return output;
  }

  final intermediate = source.width == width
      ? source
      : pass(source, width, horizontal: true);
  return source.height == height
      ? intermediate
      : pass(intermediate, height, horizontal: false);
}

/// Python's round uses ties-to-even for the training letterbox dimensions.
int trainingRound(double value) {
  final lower = value.floor();
  return value - lower == 0.5
      ? (lower.isEven ? lower : lower + 1)
      : value.round();
}
