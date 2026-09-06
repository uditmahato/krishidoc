import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';

/// The launch window against the app's own canvas.
///
/// Most of Step 9 is genuinely not automatable: whether the screen stays one
/// continuous colour from the end of the launcher animation to the first Dart
/// frame has to be seen, on a device, with the OS in dark mode. This is the
/// part that can be checked, and it is the part most likely to rot: two
/// values in two languages in two files that must agree exactly, where a
/// near-miss reads as a flash rather than as an obvious bug.
void main() {
  String res(String path) =>
      File('android/app/src/main/res/$path').readAsStringSync();

  /// Comments in these files legitimately quote the values being removed, in
  /// order to explain what was wrong with them. Asserting against raw text
  /// would make the explanation itself a failure.
  String declarations(String path) =>
      res(path).replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');

  test('kd_canvas matches KdColors.canvas exactly', () {
    final colors = res('values/colors.xml');
    final match = RegExp(
      r'<color name="kd_canvas">#([0-9A-Fa-f]{6})</color>',
    ).firstMatch(colors);
    expect(match, isNotNull, reason: 'kd_canvas is missing from colors.xml');

    final fromXml = int.parse('FF${match!.group(1)!}', radix: 16);
    expect(
      fromXml,
      // ignore: deprecated_member_use
      KdColors.canvas.value,
      reason:
          'the launch window and the first Dart frame must be the same '
          'colour; a near miss is a visible flash on every cold start',
    );
  });

  test('both launch backgrounds point at the token, not at an OS colour', () {
    for (final path in const [
      'drawable/launch_background.xml',
      'drawable-v21/launch_background.xml',
    ]) {
      final xml = declarations(path);
      expect(
        xml.contains('@color/kd_canvas'),
        isTrue,
        reason: '$path does not use the app canvas',
      );
      // ?android:colorBackground resolves from the device theme, so the launch
      // window was whatever the ROM chose, and black on a dark-mode device.
      expect(xml.contains('?android:colorBackground'), isFalse, reason: path);
      expect(xml.contains('@android:color/white'), isFalse, reason: path);
      expect(
        xml.contains('@drawable/kd_splash_mark'),
        isTrue,
        reason: '$path does not include the KrishiDoc splash mark',
      );
    }
  });

  test('pre-31 themes use the branded launch drawable and normal canvas', () {
    for (final path in const ['values/styles.xml', 'values-night/styles.xml']) {
      final xml = declarations(path);
      expect(
        xml.contains('?android:colorBackground'),
        isFalse,
        reason:
            '$path still lets the device theme paint the window behind the '
            'Flutter UI',
      );
      expect(
        xml.contains('Theme.Black'),
        isFalse,
        reason: '$path must not promise a dark system surface for a light app',
      );
      expect(
        RegExp('@drawable/launch_background').allMatches(xml).length,
        1,
        reason: '$path LaunchTheme must paint the branded drawable',
      );
      expect(
        RegExp('@color/kd_canvas').allMatches(xml).length,
        1,
        reason: '$path NormalTheme must keep the Flutter canvas behind UI',
      );
    }
  });

  test('Android 12 splash keeps the same canvas and brand mark', () {
    for (final path in const [
      'values-v31/styles.xml',
      'values-night-v31/styles.xml',
    ]) {
      final xml = declarations(path);
      expect(xml.contains('@color/kd_canvas'), isTrue, reason: path);
      expect(xml.contains('@drawable/kd_splash_mark'), isTrue, reason: path);
    }
  });
}
