import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/home_screen.dart';

import 'helpers/pump_app.dart';

void main() {
  const screens = <Size>[Size(320, 640), Size(360, 800), Size(412, 915)];
  const locales = <Locale>[Locale('ne'), Locale('hi'), Locale('en')];

  for (final screen in screens) {
    for (final locale in locales) {
      testWidgets(
        'shell fits ${screen.width}x${screen.height} in ${locale.languageCode}',
        (tester) async {
          useScreen(tester, screen, textScale: 1.3);
          await pumpApp(tester, locale: locale);

          expect(find.byKey(homeWorkTabKey), findsOneWidget);
          expect(find.byKey(homeAskTabKey), findsOneWidget);
          expect(find.byKey(homeMarketTabKey), findsOneWidget);
          expect(find.byKey(homeProfileTabKey), findsOneWidget);
          expect(find.byKey(homeScanFabKey), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byKey(homeAskTabKey));
          await tester.pumpAndSettle();
          expect(find.byKey(homeScanFabKey), findsNothing);

          await tester.tap(find.byKey(homeMarketTabKey));
          await tester.pumpAndSettle();
          expect(find.byKey(homeScanFabKey), findsNothing);

          await tester.tap(find.byKey(homeProfileTabKey));
          await tester.pumpAndSettle();
          expect(find.byKey(homeScanFabKey), findsNothing);
          expect(find.text('Records'), findsNothing);

          await tester.tap(find.byKey(homeWorkTabKey));
          await tester.pumpAndSettle();
          expect(find.byKey(homeScanFabKey), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('shell remains usable at maximum text size', (tester) async {
    useScreen(tester, const Size(360, 800), textScale: 2);
    await pumpApp(tester, locale: const Locale('ne'));
    await tester.scrollUntilVisible(
      find.byKey(homeAddWorkKey),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byKey(homeAddWorkKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
