import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normal app does not bundle labelled audit photos', () {
    expect(
      File('pubspec.yaml').readAsStringSync(),
      isNot(contains('- test_assets/mobile_audit/')),
    );
  });
  test('audit target is isolated from the normal app package', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('gradleProperty("target")'));
    expect(gradle, contains('contains("labelled_model_audit")'));
    expect(
      gradle,
      contains('"com.krishidoc.app.modelaudit" else "com.krishidoc.app"'),
    );
  });
}
