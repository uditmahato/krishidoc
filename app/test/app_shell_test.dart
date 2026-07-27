import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/main.dart';

void main() {
  testWidgets('boots to home with all four tiles (en)', (tester) async {
    await tester.pumpWidget(const KrishiDocApp(initialLocale: Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('KrishiDoc'), findsOneWidget);
    expect(find.text('Identify disease'), findsOneWidget);
    expect(find.text('Ask a question'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('renders Nepali with the reviewed register (D-06/D-35)', (
    tester,
  ) async {
    await tester.pumpWidget(const KrishiDocApp(initialLocale: Locale('ne')));
    await tester.pumpAndSettle();
    expect(find.text('रोग पहिचान गर्नुहोस्'), findsOneWidget);
    expect(
      find.textContaining('बालीको रोग पहिचान'),
      findsOneWidget,
      reason: 'tagline must use crop (बाली) register, not plant/seedling',
    );
  });

  testWidgets('renders Hindi tiles (D-06)', (tester) async {
    await tester.pumpWidget(const KrishiDocApp(initialLocale: Locale('hi')));
    await tester.pumpAndSettle();
    expect(find.text('रोग पहचानें'), findsOneWidget);
    expect(find.text('सवाल पूछें'), findsOneWidget);
  });

  testWidgets('language menu switches locale in place', (tester) async {
    await tester.pumpWidget(const KrishiDocApp(initialLocale: Locale('en')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('नेपाली'));
    await tester.pumpAndSettle();
    expect(find.text('रोग पहिचान गर्नुहोस्'), findsOneWidget);
    expect(find.text('Identify disease'), findsNothing);
  });

  testWidgets('dev preview shows all three result states (D-17)', (
    tester,
  ) async {
    await tester.pumpWidget(const KrishiDocApp(initialLocale: Locale('en')));
    await tester.pumpAndSettle();
    // Lazy ListView child: drag until built, then align fully into view.
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
