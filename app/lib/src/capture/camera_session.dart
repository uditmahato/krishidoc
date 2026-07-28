import 'dart:typed_data';

import 'package:flutter/widgets.dart';

/// One preview frame's luminance plane, straight from the camera.
///
/// Only the Y plane travels: the quality gate needs nothing else, and
/// decoding or converting frames would blow the per-frame budget (D-16).
final class LumaFrame {
  const LumaFrame({
    required this.luminance,
    required this.width,
    required this.height,
    int? bytesPerRow,
  }) : bytesPerRow = bytesPerRow ?? width;

  final Uint8List luminance;
  final int width;
  final int height;

  /// Row stride in bytes. Android pads YUV rows to an alignment boundary, so
  /// this is routinely larger than [width]; reading the plane as though rows
  /// were tightly packed shifts every row and corrupts the frame.
  final int bytesPerRow;
}

/// The platform camera, behind a port.
///
/// The concrete implementation (the `camera` plugin) is deliberately absent
/// until it can be verified on real hardware: the reference-device lab is
/// still an open milestone item, and platform code that cannot be exercised
/// by any test does not belong in the repo. Everything the capture screen
/// decides, coaching, gating, crop context, image preparation, is built and
/// tested against this port instead.
abstract interface class CameraSession {
  /// Throws if the camera is unavailable or permission is refused; the
  /// screen renders that as an error state, never as a frozen preview.
  Future<void> start();

  Stream<LumaFrame> get frames;

  /// Full-resolution capture. Preparation (downscale, EXIF stripping) is the
  /// caller's job, per D-12.
  Future<Uint8List> capturePhoto();

  Future<void> stop();

  /// Platform preview surface.
  Widget buildPreview(BuildContext context);
}
