import 'package:capture/capture.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:krishidoc_app/src/capture/platform_camera_session.dart';

/// Verifies the real camera on real hardware: that frames arrive, that their
/// luminance plane is shaped the way the quality gate expects, and that a
/// capture produces bytes the preparation pipeline can actually read.
///
/// Requires the CAMERA permission to be granted beforehand:
///   adb shell pm grant com.krishidoc.app android.permission.CAMERA
/// Granting it here would need input injection into a system dialog, which
/// the phone-automation boundary forbids.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the camera starts and delivers usable luminance frames', (
    tester,
  ) async {
    final session = PlatformCameraSession();
    addTearDown(session.stop);

    await session.start();
    final frame = await session.frames.first.timeout(
      const Duration(seconds: 10),
    );

    debugPrint(
      'MEASURED camera_frame width=${frame.width} height=${frame.height} '
      'bytesPerRow=${frame.bytesPerRow} planeBytes=${frame.luminance.length}',
    );

    expect(frame.width, greaterThan(0));
    expect(frame.height, greaterThan(0));
    expect(
      frame.bytesPerRow,
      greaterThanOrEqualTo(frame.width),
      reason: 'a stride below the width would mean the plane is misdescribed',
    );
    expect(
      frame.luminance.length,
      greaterThanOrEqualTo(frame.bytesPerRow * frame.height),
      reason: 'the plane must hold every row it claims',
    );
  });

  testWidgets('the quality gate reads a real frame without complaint', (
    tester,
  ) async {
    final session = PlatformCameraSession();
    addTearDown(session.stop);

    await session.start();
    final frame = await session.frames.first.timeout(
      const Duration(seconds: 10),
    );

    // The gate's own validation is the assertion: if the real stride were
    // being dropped or misreported, this throws rather than returning a
    // verdict. What the verdict is depends on where the phone is pointing,
    // so only its plausibility is checked.
    final quality = const QualityGate().assess(
      frame.luminance,
      width: frame.width,
      height: frame.height,
      bytesPerRow: frame.bytesPerRow,
    );

    debugPrint(
      'MEASURED gate_on_real_frame edgeEnergy=${quality.edgeEnergy.toStringAsFixed(1)} '
      'meanLuminance=${quality.meanLuminance.toStringAsFixed(1)} '
      'issues=${quality.issues.map((i) => i.name).join(",")}',
    );

    expect(quality.meanLuminance, inInclusiveRange(0, 255));
    expect(quality.edgeEnergy, greaterThanOrEqualTo(0));
  });

  testWidgets('a captured photo survives the preparation pipeline', (
    tester,
  ) async {
    final session = PlatformCameraSession();
    addTearDown(session.stop);

    await session.start();
    await session.frames.first.timeout(const Duration(seconds: 10));

    final original = await session.capturePhoto();
    final prepared = const ImageProcessor().prepare(original);

    debugPrint(
      'MEASURED capture original_kb=${(original.length / 1024).round()} '
      'prepared_kb=${(prepared.length / 1024).round()}',
    );

    expect(original, isA<Uint8List>());
    expect(original.length, greaterThan(1024));
    expect(
      prepared.length,
      lessThan(original.length),
      reason: 'the derivative must be smaller than a full-resolution photo',
    );
  });

  testWidgets('the stream keeps running after a still capture', (tester) async {
    // Some devices contend between the preview stream and a still capture,
    // so the session stops and restarts the stream around a shot. If that
    // restart failed, coaching would freeze the moment a farmer took one
    // photo and tried again.
    final session = PlatformCameraSession();
    addTearDown(session.stop);

    await session.start();
    await session.frames.first.timeout(const Duration(seconds: 10));
    await session.capturePhoto();

    final afterCapture = await session.frames.first.timeout(
      const Duration(seconds: 10),
    );

    expect(afterCapture.width, greaterThan(0));
  });
}
