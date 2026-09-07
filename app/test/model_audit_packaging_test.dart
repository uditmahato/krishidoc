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
  test('V7 test and audit targets each have a separate app identity', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(gradle, contains('contains("labelled_model_audit_v7")'));
    expect(gradle, contains('contains("main_potato_v7")'));
    expect(gradle, contains('"com.krishidoc.app.v7audit"'));
    expect(gradle, contains('"com.krishidoc.app.v7test"'));
    expect(
      File('lib/main_potato_v7.dart').readAsStringSync(),
      contains('PotatoFieldResearchPack.useV7'),
    );
    expect(
      File(
        'integration_test/labelled_model_audit_v7_app.dart',
      ).readAsStringSync(),
      contains('PotatoFieldResearchPack.useV7'),
    );
  });
}
