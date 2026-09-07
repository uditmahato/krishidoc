import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'camera_session.dart';

/// The real camera, behind the port the capture screen was built against.
///
/// Nothing here decides anything: it starts the hardware, forwards luminance
/// planes, and takes a picture. Coaching, gating, and preparation all live in
/// tested code that never touches a device.
final class PlatformCameraSession implements CameraSession {
  PlatformCameraSession({this.resolution = ResolutionPreset.medium});

  /// Preview resolution. Medium is deliberate: the quality gate reads
  /// luminance, not detail, and a larger preview costs battery and frame time
  /// for nothing. The captured photo is full resolution regardless.
  final ResolutionPreset resolution;

  final StreamController<LumaFrame> _frames =
      StreamController<LumaFrame>.broadcast();
  CameraController? _controller;
  Future<void> _lifecycle = Future<void>.value();

  @override
  Stream<LumaFrame> get frames => _frames.stream;

  @override
  Future<void> start() => _enqueue(_activate);

  /// Serialises activation, still capture, pause and final teardown.
  ///
  /// Permission prompts and camera initialisation can outlive the route that
  /// started them. Without this queue, `dispose -> stop` can run while
  /// `start` is still awaiting Android and the late completion can reopen the
  /// sensor after the screen has gone away.
  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _lifecycle.then<T>(
      (_) => operation(),
      onError: (Object _, StackTrace __) => operation(),
    );
    _lifecycle = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return result;
  }

  Future<void> _activate() async {
    if (_frames.isClosed) {
      throw StateError('camera session has already been stopped');
    }
    if (_controller != null) return;
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw CameraException('no_camera', 'This device reports no cameras.');
    }

    final controller = CameraController(
      cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      ),
      resolution,
      enableAudio: false,
      // YUV420 hands us the Y plane directly. Anything else would mean a
      // colour-space conversion per frame purely to throw the colour away.
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await controller.initialize();
    _controller = controller;

    await controller.startImageStream(_forward);
  }

  @override
  Future<Uint8List> capturePhoto() => _enqueue(_capturePhoto);

  Future<Uint8List> _capturePhoto() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      throw CameraException('not_started', 'The camera is not running.');
    }
    // The stream and a still capture contend for the sensor on some devices,
    // so the stream pauses for the shot and resumes afterwards.
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    try {
      final file = await controller.takePicture();
      return await file.readAsBytes();
    } finally {
      if (!controller.value.isStreamingImages) {
        await controller.startImageStream(_forward);
      }
    }
  }

  void _forward(CameraImage image) {
    if (_frames.isClosed) return;
    final plane = image.planes.first;
    _frames.add(
      LumaFrame(
        luminance: plane.bytes,
        width: image.width,
        height: image.height,
        // Passed through rather than assumed: see LumaFrame.bytesPerRow.
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  Future<void> pause() => _enqueue(_deactivate);

  @override
  Future<void> resume() => _enqueue(_activate);

  Future<void> _deactivate() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
      await controller.dispose();
    }
  }

  @override
  Future<void> stop() => _enqueue(_stop);

  Future<void> _stop() async {
    await _deactivate();
    if (!_frames.isClosed) {
      await _frames.close();
    }
  }

  @override
  Widget buildPreview(BuildContext context) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const SizedBox.expand();
    }
    return CameraPreview(controller);
  }
}
