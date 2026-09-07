import 'dart:typed_data';

import 'package:capture/capture.dart';
import 'package:image/image.dart' as img;
import 'package:test/test.dart';

/// High-frequency content, so the encoded fixtures behave like real photos
/// rather than compressing to nothing.
img.Image photoLike(int width, int height) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      image.setPixelRgb(
        x,
        y,
        (x * 7) % 256,
        (y * 11) % 256,
        ((x + y) * 13) % 256,
      );
    }
  }
  return image;
}

bool containsAscii(Uint8List haystack, String needle) {
  final pattern = needle.codeUnits;
  for (var i = 0; i <= haystack.length - pattern.length; i++) {
    var matched = true;
    for (var j = 0; j < pattern.length; j++) {
      if (haystack[i + j] != pattern[j]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

void main() {
  const processor = ImageProcessor();

  group('downscaling', () {
    test('caps the long edge at 1024 and keeps the aspect ratio', () {
      final source = Uint8List.fromList(img.encodeJpg(photoLike(1500, 1000)));

      final prepared = img.decodeImage(processor.prepare(source))!;

      expect(prepared.width, 1024);
      expect(prepared.height, 683); // 1000 * (1024 / 1500), rounded
    });

    test('leaves an already-small image at its own size', () {
      final source = Uint8List.fromList(img.encodeJpg(photoLike(800, 600)));

      final prepared = img.decodeImage(processor.prepare(source))!;

      expect(prepared.width, 800);
      expect(prepared.height, 600);
    });

    test('honours a custom long edge', () {
      const small = ImageProcessor(maxEdge: 256);
      final source = Uint8List.fromList(img.encodeJpg(photoLike(1500, 1000)));

      final prepared = img.decodeImage(small.prepare(source))!;

      expect(prepared.width, 256);
    });

    test('cuts the payload substantially', () {
      final source = Uint8List.fromList(
        img.encodeJpg(photoLike(1500, 1000), quality: 95),
      );

      final prepared = processor.prepare(source);

      // The synthetic fixture is deliberately noisy, which is the worst case
      // for JPEG: it still shrinks about 3x here. Real camera photos of
      // leaves shrink far more, since a full-resolution original is several
      // megabytes and the derivative lands in the low hundreds of kilobytes.
      expect(
        prepared.length * 2,
        lessThan(source.length),
        reason: 'uploads ride rural uplinks; the derivative must be small',
      );
    });
  });

  group('metadata stripping (D-12)', () {
    test('drops EXIF, including anything location-shaped', () {
      const canary = 'KRISHIDOC_GPS_CANARY';
      final withExif = photoLike(1500, 1000)
        ..exif.imageIfd['Make'] = canary
        ..exif.gpsIfd['GPSLatitudeRef'] = 'N';
      final source = Uint8List.fromList(img.encodeJpg(withExif));

      // The fixture must actually carry metadata, or this test proves nothing.
      expect(containsAscii(source, canary), isTrue);
      expect(img.decodeImage(source)!.exif.isEmpty, isFalse);

      final prepared = processor.prepare(source);

      expect(containsAscii(prepared, canary), isFalse);
      expect(containsAscii(prepared, 'Exif'), isFalse);
      expect(img.decodeImage(prepared)!.exif.isEmpty, isTrue);
    });

    test('strips metadata even when no resize is needed', () {
      const canary = 'KRISHIDOC_GPS_CANARY';
      final withExif = photoLike(640, 480)..exif.imageIfd['Make'] = canary;
      final source = Uint8List.fromList(img.encodeJpg(withExif));
      expect(containsAscii(source, canary), isTrue);

      expect(containsAscii(processor.prepare(source), canary), isFalse);
    });
  });

  group('input handling', () {
    test('throws a typed error on undecodable bytes', () {
      expect(
        () => processor.prepare(Uint8List.fromList([1, 2, 3, 4])),
        throwsA(isA<ImageDecodeException>()),
      );
    });

    test('accepts PNG input and returns JPEG', () {
      final source = Uint8List.fromList(img.encodePng(photoLike(1200, 900)));

      final prepared = processor.prepare(source);

      expect(img.findDecoderForData(prepared), isA<img.JpegDecoder>());
      expect(img.decodeImage(prepared)!.width, 1024);
    });
  });
}
