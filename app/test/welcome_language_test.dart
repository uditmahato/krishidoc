import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/welcome/welcome_about_screen.dart';
import 'package:krishidoc_app/src/welcome/welcome_language_screen.dart';

import 'helpers/fakes.dart';
import 'helpers/pump_app.dart';

const _timeout = Timeout(Duration(minutes: 1));

Finder _target(AppLanguage language) => find.byKey(languageTargetKey(language));

void main() {
  testWidgets('a fresh install opens on the chooser', timeout: _timeout, (
    tester,
  ) async {
    await pumpApp(tester, firstRun: true);
    expect(find.byType(WelcomeLanguageScreen), findsOneWidget);
  });

  testWidgets(
    'a reader who already answered never sees it again',
    timeout: _timeout,
    (tester) async {
      await pumpApp(tester, locale: const Locale('ne'));
      expect(find.byType(WelcomeLanguageScreen), findsNothing);
    },
  );

  testWidgets(
    'each endonym renders in its own script metrics',
    timeout: _timeout,
    (tester) async {
      // The app is in English here, which is the whole point: no language has
      // been chosen yet, so the ambient theme is Latin. Taking the style from
      // Theme.of would paint both Devanagari endonyms at Latin line height on
      // the one screen whose premise is that each option appears readable in
      // its own script.
      await pumpApp(tester, firstRun: true);

      for (final language in [AppLanguage.ne, AppLanguage.hi]) {
        final text = tester.widget<Text>(
          find.descendant(of: _target(language), matching: find.byType(Text)),
        );
        expect(
          text.style!.height,
          greaterThanOrEqualTo(KdType.devanagariMinHeight),
          reason: '${language.code} would collide stacked matras',
        );
        expect(
          text.style!.letterSpacing,
          0,
          reason: 'letter spacing breaks the shirorekha',
        );
      }
    },
  );

  testWidgets(
    'every target is a button a screen reader can actually press',
    timeout: _timeout,
    (tester) async {
      final handle = tester.ensureSemantics();
      await pumpApp(tester, firstRun: true);

      for (final choice in [AppLanguage.ne, AppLanguage.hi, AppLanguage.en]) {
        final node = tester.getSemantics(_target(choice)).getSemanticsData();
        expect(
          node.hasFlag(SemanticsFlag.isButton),
          isTrue,
          reason: '${choice.code} must announce as a button',
        );
        // The assertion that matters. Asserting the flag alone passes while the
        // screen is completely unusable: a node can announce "button" and carry
        // no tap action at all, which is what happens when the handler sits
        // inside an excluded subtree. On an unskippable gate that is a hard
        // lock for a blind user.
        expect(
          node.hasAction(SemanticsAction.tap),
          isTrue,
          reason:
              '${choice.code} announces as a button but cannot be activated',
        );
      }
      handle.dispose();
    },
  );

  testWidgets(
    'each endonym appears exactly once, in every locale',
    timeout: _timeout,
    (tester) async {
      for (final locale in [
        const Locale('en'),
        const Locale('ne'),
        const Locale('hi'),
      ]) {
        await pumpApp(tester, firstRun: true, locale: locale);
        expect(
          find.text('नेपाली'),
          findsOneWidget,
          reason:
              'endonyms are not translations (D-54); in ${locale.languageCode} '
              'a translated copy would make this two',
        );
        expect(find.text('हिन्दी'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'the choice is durable before the next screen appears',
    timeout: _timeout,
    (tester) async {
      // A store slow enough that starting the write and awaiting it are
      // distinguishable. Against an implementation that merely started it, the
      // About screen arrives while the value is still unwritten.
      final store = FakeSettingsStore(
        writeDelay: const Duration(milliseconds: 300),
      );
      await pumpApp(tester, firstRun: true, settingsStore: store);

      await tester.tap(_target(AppLanguage.ne));

      // Deliberately NOT pumpAndSettle. Settling runs the clock past the
      // write delay whatever the screen did, so it cannot tell an awaited
      // write from a merely started one. Stepping forward and stopping at the
      // first frame that shows About is what makes the two distinguishable.
      const step = Duration(milliseconds: 20);
      var elapsed = Duration.zero;
      while (find.byType(WelcomeAboutScreen).evaluate().isEmpty &&
          elapsed < const Duration(seconds: 2)) {
        await tester.pump(step);
        elapsed += step;
      }

      expect(find.byType(WelcomeAboutScreen), findsOneWidget);
      expect(
        await store.read(SettingsKeys.selectedLanguage),
        'ne',
        reason:
            'the language must be on disk by the time the reader has moved '
            'on, or a crash here loses the only answer they gave us',
      );
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'choosing repaints the app in the chosen script',
    timeout: _timeout,
    (tester) async {
      await pumpApp(tester, firstRun: true);
      await tester.tap(_target(AppLanguage.ne));
      await tester.pumpAndSettle();

      // The About screen is now rendering, and it is rendering in Nepali.
      expect(
        find.text(
          'गोलभेँडा, आलु र मकैका लागि काम योजना, नेपाल-केन्द्रित बाली '
          'मार्गदर्शन, स्थानीय मौसम र कालीमाटीको आधिकारिक थोक मूल्य '
          'हेर्नुहोस्।',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'all three targets fit a small screen with no scroll',
    timeout: _timeout,
    (tester) async {
      useScreen(tester, const Size(320, 640));
      await pumpApp(tester, firstRun: true, locale: const Locale('ne'));

      final viewport = tester.view.physicalSize / tester.view.devicePixelRatio;
      for (final language in [AppLanguage.ne, AppLanguage.hi, AppLanguage.en]) {
        final rect = tester.getRect(_target(language));
        expect(
          rect.top >= 0 && rect.bottom <= viewport.height,
          isTrue,
          reason:
              '${language.code} target at $rect is outside the viewport; '
              'a reader who cannot read the screen cannot be asked to scroll it',
        );
      }
      expect(tester.takeException(), isNull);
    },
  );
}
