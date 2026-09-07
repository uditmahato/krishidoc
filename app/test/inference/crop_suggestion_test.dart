import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:inference/inference.dart';
import 'package:krishidoc_app/src/capture/photo_review.dart';
import 'package:krishidoc_app/src/inference/crop_suggestion.dart';

void main() {
  List<double> scores(Map<int, double> values) {
    final result = List<double>.filled(ExperimentalPlantPack.outputCount, 0);
    values.forEach((index, value) => result[index] = value);
    return result;
  }

  test('suggests each supported crop and combines its condition classes', () {
    expect(
      CropSuggestionService.fromProbabilities(scores({20: 0.8, 28: 0.2})),
      'potato',
    );
    expect(
      CropSuggestionService.fromProbabilities(scores({28: 0.8, 20: 0.2})),
      'tomato',
    );
    expect(
      CropSuggestionService.fromProbabilities(
        scores({8: 0.5, 9: 0.3, 20: 0.2}),
      ),
      'maize',
    );
  });
  test('does not force an unsupported crop into a supported one', () {
    expect(
      CropSuggestionService.fromProbabilities(scores({18: 0.8, 28: 0.2})),
      isNull,
    );
  });
  test('ambiguous and flat outputs require manual selection', () {
    expect(
      CropSuggestionService.fromProbabilities(scores({20: 0.51, 28: 0.49})),
      isNull,
    );
    expect(
      CropSuggestionService.fromProbabilities(List.filled(38, 1 / 38)),
      isNull,
    );
  });
  test('rejects malformed outputs', () {
    for (final values in [
      <double>[1],
      List.filled(38, double.nan),
      scores({20: 0.9}),
    ]) {
      expect(
        () => CropSuggestionService.fromProbabilities(values),
        throwsFormatException,
      );
    }
  });
  test('gallery quality rejects dark, flat, tiny and undecodable images', () {
    final image = img.Image(width: 64, height: 64);
    expect(assessGalleryPhoto(img.encodePng(image)).isAcceptable, isFalse);
    img.fill(image, color: img.ColorRgb8(128, 128, 128));
    expect(assessGalleryPhoto(img.encodePng(image)).isAcceptable, isFalse);
    expect(() => assessGalleryPhoto(Uint8List(10)), throwsFormatException);
    expect(
      () => assessGalleryPhoto(img.encodePng(img.Image(width: 1, height: 1))),
      throwsFormatException,
    );
  });
}
