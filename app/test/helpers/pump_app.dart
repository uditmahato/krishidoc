import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/l10n/gen/app_localizations.dart';
import 'package:krishidoc_app/main.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/diagnosis/photo_store.dart';
import 'package:krishidoc_app/src/providers.dart';
import 'package:krishidoc_app/src/welcome/first_run.dart';

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
/// Pumps the full app the way `main()` boots it.
///
/// [firstRun] leaves the language unset, so the app opens on the chooser.
/// Every other call seeds a language first, because a test that means to
/// assert something about Home would otherwise land on the chooser and pass
/// or fail for a reason it never states.
Future<AppServices> pumpApp(
  WidgetTester tester, {
  Locale? locale,
  Future<void> Function(AppServices services)? seed,
  List<Override> overrides = const [],
  bool firstRun = false,
  SettingsStore? settingsStore,
  String? startAt,
}) async {
  final services = AppServices.forTest(
    diagnosisStore: FakeDiagnosisStore(),
    observationStore: FakeObservationStore(),
    // Injectable so a test can supply a deliberately slow store. Without one,
    // "the write is awaited" is untestable: an instant fake completes in a
    // microtask either way, so the assertion would pass against code that
    // merely started the write.
    settingsStore: settingsStore ?? FakeSettingsStore(),
  );
  if (seed != null) {
    await seed(services);
  }

  var stored = await services.settingsStore.read(SettingsKeys.selectedLanguage);
  if (stored == null && !firstRun) {
    stored = locale?.languageCode ?? 'en';
    await services.settingsStore.write(SettingsKeys.selectedLanguage, stored);
  }

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        servicesProvider.overrideWithValue(services),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        ...overrides,
      ],
      child: KrishiDocApp(
        initialLocale: stored == null ? null : Locale(stored),
        // The SAME function main() calls. A helper that reimplemented the
        // boot decision would be a second copy of the thing under test, and
        // the two would agree right up until the moment it mattered.
        //
        // [startAt] overrides it for tests that are about a screen rather
        // than about how it was reached. Any test asserting the boot decision
        // itself must leave it null, or it is asserting its own argument.
        initialLocation: startAt ?? initialLocationFor(stored),
      ),
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
    observationStore: FakeObservationStore(),
    settingsStore: FakeSettingsStore(),
  );
  if (seed != null) {
    await seed(services);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        servicesProvider.overrideWithValue(services),
        photoStoreProvider.overrideWithValue(MemoryPhotoStore()),
        ...overrides,
      ],
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
