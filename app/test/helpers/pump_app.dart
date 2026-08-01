import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/l10n/gen/app_localizations.dart';
import 'package:krishidoc_app/main.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/providers.dart';

import 'fakes.dart';

/// Sizes the test view in logical pixels and restores it at teardown.
///
/// The default 800x600 test surface is wider and shorter than any phone this
/// app runs on, which is how a grid that overflowed on every common handset
/// resolution passed the suite for four modules.
void useScreen(WidgetTester tester, Size logical, {double textScale = 1.0}) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logical;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

/// Pumps the full app against in-memory port fakes and returns the services
/// for seeding and assertions. [seed] runs before the first frame, so
/// restored state (like the persisted language) is visible on boot.
///
/// No database is involved: see fakes.dart for why drift is banned in
/// widget tests.
Future<AppServices> pumpApp(
  WidgetTester tester, {
  Locale? locale,
  Future<void> Function(AppServices services)? seed,
  List<Override> overrides = const [],
}) async {
  final services = AppServices.forTest(
    diagnosisStore: FakeDiagnosisStore(),
    settingsStore: FakeSettingsStore(),
  );
  if (seed != null) {
    await seed(services);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services), ...overrides],
      child: KrishiDocApp(initialLocale: locale),
    ),
  );
  await tester.pumpAndSettle();
  return services;
}

/// Pumps a single screen with the app's theme and localizations, for screens
/// tested in isolation rather than through navigation.
Future<AppServices> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Locale locale = const Locale('en'),
  Future<void> Function(AppServices services)? seed,
  List<Override> overrides = const [],
}) async {
  final services = AppServices.forTest(
    diagnosisStore: FakeDiagnosisStore(),
    settingsStore: FakeSettingsStore(),
  );
  if (seed != null) {
    await seed(services);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services), ...overrides],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: kdLightTheme(locale: locale),
        home: screen,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return services;
}
