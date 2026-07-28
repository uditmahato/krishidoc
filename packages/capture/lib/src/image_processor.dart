import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Thrown when bytes handed to [ImageProcessor] are not a decodable image.
final class ImageDecodeException implements Exception {
  const ImageDecodeException();

  @override
  String toString() => 'ImageDecodeException: bytes are not a decodable image';
}

/// Prepares a captured photo for inference, storage, and (under consent)
/// upload, per D-12.
///
/// Three things happen, in this order, and all three matter:
/// 1. EXIF orientation is baked into the pixels, so downstream consumers
///    never need to interpret orientation tags.
/// 2. The long edge is capped at [maxEdge]. Classifier input is far smaller
///    than a camera frame, so the extra megabytes buy nothing and cost
///    minutes of upload on a rural uplink.
/// 3. Metadata is dropped entirely before re-encoding. Camera EXIF can carry
///    GPS coordinates of a farmer's plot; nothing here is allowed to leave
///    the device as a side channel. Location is a separate, consented field.
///
/// This is CPU-bound: call it from an isolate (`Isolate.run`, or `compute`
/// in Flutter), never on the UI thread.
final class ImageProcessor {
  const ImageProcessor({this.maxEdge = 1024, this.quality = 85})
    : assert(maxEdge > 0, 'maxEdge must be positive'),
      assert(quality > 0 && quality <= 100, 'quality must be within (0, 100]');

  final int maxEdge;
  final int quality;

  /// Returns re-encoded JPEG bytes. Throws [ImageDecodeException] if
  /// [originalBytes] cannot be decoded.
  Uint8List prepare(Uint8List originalBytes) {
    final img.Image? decoded;
    try {
      decoded = img.decodeImage(originalBytes);
    } catch (_) {
      // Decoders can throw (range errors, format assertions) on truncated or
      // hostile bytes. Camera output is not always well-formed and a shared
      // photo never is, so every failure mode becomes one typed exception
      // the UI can render as a retry, not a crash.
      throw const ImageDecodeException();
    }
    if (decoded == null) {
      throw const ImageDecodeException();
    }

    final oriented = img.bakeOrientation(decoded);
    final resized = _downscaleToFit(oriented);

    // Belt and braces: bakeOrientation clears the orientation tag only.
    resized.exif = img.ExifData();

    return img.encodeJpg(resized, quality: quality);
  }

  img.Image _downscaleToFit(img.Image image) {
    final longestEdge = math.max(image.width, image.height);
    if (longestEdge <= maxEdge) {
      return image; // Never upscale: it invents detail the model would read.
    }
    final scale = maxEdge / longestEdge;
    return img.copyResize(
      image,
      width: (image.width * scale).round(),
      height: (image.height * scale).round(),
      interpolation: img.Interpolation.average,
    );
  }
}
