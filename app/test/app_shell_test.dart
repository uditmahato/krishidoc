import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/diagnosis/disease_scan_intro_screen.dart';
import 'package:krishidoc_app/src/home_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('boots to the working farmer shell', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    expect(find.text('KrishiDoc'), findsOneWidget);
    expect(find.text('Work'), findsWidgets);
    expect(find.text('Doctor'), findsOneWidget);
    expect(find.text('Market'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(find.text('Records'), findsNothing);
    expect(find.byKey(homeWorkTabKey), findsOneWidget);
    expect(find.byKey(homeAskTabKey), findsOneWidget);
    expect(find.byKey(homeMarketTabKey), findsOneWidget);
    expect(find.byKey(homeProfileTabKey), findsOneWidget);
    expect(find.byKey(homeCaptureKey), findsOneWidget);
    expect(find.byKey(homeScanFabKey), findsOneWidget);
    expect(find.text('Check a leaf'), findsNothing);
    expect(find.text('This is not ready yet.'), findsNothing);

    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(
      navigationBar.destinations.cast<NavigationDestination>().map(
        (destination) => destination.label,
      ),
      orderedEquals(const ['Work', 'Doctor', 'Market', 'Profile']),
    );
  });

  testWidgets('renders Nepali shell labels', (tester) async {
    await pumpApp(tester, locale: const Locale('ne'));
    expect(find.text('काम'), findsWidgets);
    expect(find.text('बाली डाक्टर'), findsOneWidget);
    expect(find.byKey(homeMarketTabKey), findsOneWidget);
    expect(find.byKey(homeProfileTabKey), findsOneWidget);
  });

  testWidgets('renders Hindi shell labels', (tester) async {
    await pumpApp(tester, locale: const Locale('hi'));
    expect(find.text('काम'), findsWidgets);
    expect(find.text('फसल डॉक्टर'), findsOneWidget);
    expect(find.byKey(homeMarketTabKey), findsOneWidget);
    expect(find.byKey(homeProfileTabKey), findsOneWidget);
  });

  testWidgets('Work scan action opens the disease scan preparation screen', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('en'));

    final scanFab = find.byKey(homeScanFabKey);
    expect(scanFab, findsOneWidget);
    expect(
      find.descendant(
        of: scanFab,
        matching: find.byIcon(Icons.photo_camera_outlined),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: scanFab, matching: find.text('Scan')),
      findsOneWidget,
    );

    await tester.tap(scanFab);
    await tester.pumpAndSettle();

    expect(find.byType(DiseaseScanIntroScreen), findsOneWidget);
  });

  testWidgets('Profile owns the existing farm records content', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));

    await tester.tap(find.byKey(homeProfileTabKey));
    await tester.pumpAndSettle();

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );
    await tester.scrollUntilVisible(
      find.byKey(homeViewAllPhotosKey),
      200,
      scrollable: find.byType(Scrollable).hitTestable().first,
    );
    expect(find.byKey(homeDiagnosisHistoryKey), findsOneWidget);
    expect(find.byKey(homeViewAllPhotosKey), findsOneWidget);
    expect(find.byKey(homeScanFabKey), findsNothing);
  });

  testWidgets('language switch applies and persists', (tester) async {
    final services = await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CheckedPopupMenuItem<AppLanguage>).first);
    await tester.pumpAndSettle();

    expect(find.text('बाली डाक्टर'), findsOneWidget);
    expect(
      await services.settingsStore.read(SettingsKeys.selectedLanguage),
      'ne',
    );
  });

  testWidgets('persisted language is restored on boot', (tester) async {
    await pumpApp(
      tester,
      seed: (services) =>
          services.settingsStore.write(SettingsKeys.selectedLanguage, 'hi'),
    );
    expect(find.text('फसल डॉक्टर'), findsOneWidget);
  });

  testWidgets('dev preview still covers all result states directly', (
    tester,
  ) async {
    await pumpApp(
      tester,
      locale: const Locale('en'),
      startAt: '/dev/result-preview',
    );
    expect(find.text('UI preview'), findsOneWidget);
    expect(find.textContaining('This looks like'), findsOneWidget);
  });
}
