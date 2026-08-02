import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('boots to home saying what the app is for (en)', (tester) async {
    await pumpApp(tester, locale: const Locale('en'));
    expect(find.text('KrishiDoc'), findsOneWidget);
    // What replaced the four tiles: a true statement of coverage, one control
    // that is honest about not being ready, and one that works.
    expect(
      find.text('This app is for the leaves of tomato, potato and maize.'),
      findsOneWidget,
    );
    expect(find.text('Check a leaf'), findsOneWidget);
    expect(find.text('This is not ready yet.'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    // Deleted, with their strings, so they cannot be re-added by accident.
    expect(find.text('Ask a question'), findsNothing);
    expect(find.text('Settings'), findsNothing);
  });

  testWidgets('renders Nepali with the reviewed register (D-06/D-35)', (
    tester,
  ) async {
    await pumpApp(tester, locale: const Locale('ne'));
    expect(find.text('पात जाँच्नुहोस्'), findsOneWidget);
    expect(
      find.textContaining('गोलभेँडा, आलु र मकै'),
      findsOneWidget,
      reason: 'coverage must use the same crop register as cropTomato et al',
    );
  });

  testWidgets('renders Hindi (D-06)', (tester) async {
    await pumpApp(tester, locale: const Locale('hi'));
    expect(find.text('पत्ता जाँचें'), findsOneWidget);
    expect(find.text('यह अभी तैयार नहीं है।'), findsOneWidget);
  });

  testWidgets('language switch applies and persists (D-35 + M2 promise)', (
    tester,
  ) async {
    final services = await pumpApp(tester, locale: const Locale('en'));
    await tester.tap(find.byIcon(Icons.language));
    await tester.pumpAndSettle();
    await tester.tap(find.text('नेपाली'));
    await tester.pumpAndSettle();

    expect(find.text('पात जाँच्नुहोस्'), findsOneWidget);
    expect(find.text('Check a leaf'), findsNothing);
    expect(
      await services.settingsStore.read(SettingsKeys.selectedLanguage),
      'ne',
      reason: 'the choice must survive restarts',
    );
  });

  testWidgets('persisted language is restored on boot', (tester) async {
    // Now passing for a better reason than before: the helper reads the
    // seeded value and boots Hindi through the real pre-runApp shape, rather
    // than through a post-frame restore that has been deleted.
    await pumpApp(
      tester,
      seed: (services) =>
          services.settingsStore.write(SettingsKeys.selectedLanguage, 'hi'),
    );
    await tester.pumpAndSettle();
    expect(find.text('पत्ता जाँचें'), findsOneWidget);
    expect(find.text('Check a leaf'), findsNothing);
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
    // All three certainty bands, uncertain, and both out-of-scope causes.
    // One certainty string used to serve every confident result, so a
    // calibrated 0.62 and a 0.98 read identically.
    //
    // Scrolled to each in turn because the preview list is lazy: asserting
    // without scrolling would only ever see the first card and would pass
    // just as happily if the other five were deleted.
    final preview = find.byType(Scrollable).last;
    for (final expected in const [
      'This looks like',
      'This is probably',
      'This might be',
      'We are not sure',
      'I do not know this one',
      'I could not read this photo',
    ]) {
      final target = find.textContaining(expected);
      await tester.scrollUntilVisible(target, 200, scrollable: preview);
      expect(target, findsOneWidget, reason: expected);
      // Escalation lives on the sealed base class, so every state renders it.
      expect(
        find.text('See crop experts near you'),
        findsWidgets,
        reason: 'no state may be a dead end',
      );
    }
  });
}
