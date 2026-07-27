import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/main.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/providers.dart';

import 'fakes.dart';

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
      overrides: [servicesProvider.overrideWithValue(services)],
      child: KrishiDocApp(initialLocale: locale),
    ),
  );
  await tester.pumpAndSettle();
  return services;
}
