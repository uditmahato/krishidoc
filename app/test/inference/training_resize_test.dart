import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:krishidoc_app/src/inference/training_resize.dart';

void main() {
  test('antialiased resize matches every RGB byte in training goldens', () {
    final fixture =
        jsonDecode(
              File('test/fixtures/training_resize.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final raw in fixture['cases'] as List<dynamic>) {
      final row = raw as Map<String, dynamic>;
      final input = img.Image(
        width: row['width'] as int,
        height: row['height'] as int,
      );
      for (final p in input) {
        p
          ..r = (p.x * 31 + p.y * 7) % 256
          ..g = (p.x * 3 + p.y * 47) % 256
          ..b = (p.x * 73 + p.y * 11) % 256;
      }
      final output = resizeTrainingRgb(
        input,
        row['outputWidth'] as int,
        row['outputHeight'] as int,
      );
      expect([
        for (final p in output) ...[p.r.toInt(), p.g.toInt(), p.b.toInt()],
      ], row['rgb']);
    }
  });
  test('letterbox dimensions use training ties-to-even rounding', () {
    expect(trainingRound(4.5), 4);
    expect(trainingRound(5.5), 6);
    expect(trainingRound(4.6), 5);
  });
}
