import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('boots to home with all four tiles (en)', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    expect(find.text('KrishiDoc'), findsOneWidget);
    expect(find.text('Identify disease'), findsOneWidget);
    expect(find.text('Ask a question'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('renders Nepali with the reviewed register (D-06/D-35)', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('ne'));
    expect(find.text('रोग पहिचान गर्नुहोस्'), findsOneWidget);
    expect(
      find.textContaining('बालीको रोग पहिचान'),
      findsOneWidget,
      reason: 'tagline must use crop (बाली) register, not plant/seedling',
    );
  });

  testWidgets('renders Hindi tiles (D-06)', (tester) async {
    await pumpApp(tester, locale: const Locale('hi'));
    expect(find.text('रोग पहचानें'), findsOneWidget);
    expect(find.text('सवाल पूछें'), findsOneWidget);
  });

  testWidgets('language switch applies and persists (D-35 + M2 promise)', (
    tester,
  ) async {
    final services = await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('नेपाली'));
    await tester.pumpAndSettle();

    expect(find.text('रोग पहिचान गर्नुहोस्'), findsOneWidget);
    expect(find.text('Identify disease'), findsNothing);
    expect(
      await services.settingsStore.read(SettingsKeys.selectedLanguage),
      'ne',
      reason: 'the choice must survive restarts',
    );
  });

  testWidgets('persisted language is restored on boot', (tester) async {
    await pumpApp(
      tester,
      seed: (services) =>
          services.settingsStore.write(SettingsKeys.selectedLanguage, 'hi'),
    );
    await tester.pumpAndSettle();
    expect(find.text('रोग पहचानें'), findsOneWidget);
    expect(find.text('Identify disease'), findsNothing);
  });

  testWidgets('dev preview shows all three result states (D-17)', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));
    await tester.scrollUntilVisible(
      find.text('UI preview'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('UI preview'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UI preview'));
    await tester.pumpAndSettle();
    expect(find.text('Very likely'), findsOneWidget);
    expect(find.text('We are not sure'), findsOneWidget);
    expect(find.text('Ask a nearby crop expert'), findsOneWidget);
    expect(find.text('Take another photo'), findsOneWidget);
  });
}
