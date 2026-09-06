import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/router.dart';
import 'package:krishidoc_app/src/welcome/welcome_about_screen.dart';

import 'helpers/pump_app.dart';

const _timeout = Timeout(Duration(minutes: 1));

/// Sizes taken from target hardware, matching the existing home matrix.
const _portrait = <Size>[Size(320, 640), Size(360, 800), Size(412, 915)];
const _scales = <double>[1.0, 1.3, 2.0];
const _locales = <String>['ne', 'hi', 'en'];

/// Landscape is included because it has never been covered by any test in
/// this repo, and a short wide viewport is exactly where a pinned button and
/// a scrolling body disagree.
const _landscape = Size(915, 412);

Future<void> _pumpAbout(
  WidgetTester tester, {
  required String locale,
  required bool first,
  Size size = const Size(360, 800),
  double scale = 1.0,
}) async {
  useScreen(tester, size, textScale: scale);
  await pumpApp(
    tester,
    locale: Locale(locale),
    startAt: first
        ? '${AppRoutes.welcomeAbout}?first=1'
        : AppRoutes.welcomeAbout,
  );
}

void main() {
  group('the continue button is reachable without scrolling', () {
    // The single most important assertion on this screen. A "one button,
    // always" guarantee whose button sits below the fold at the text scales
    // this audience actually uses is a compile-time claim and a runtime lie,
    // and a test asserting "scrolls rather than overflows" cannot catch it
    // because a ListView never overflows.
    for (final size in _portrait) {
      for (final scale in _scales) {
        for (final locale in _locales) {
          testWidgets(
            'at ${size.width.toInt()}x${size.height.toInt()} x$scale in $locale',
            timeout: _timeout,
            (tester) async {
              await _pumpAbout(
                tester,
                locale: locale,
                first: true,
                size: size,
                scale: scale,
              );

              expect(tester.takeException(), isNull);
              final rect = tester.getRect(find.byKey(aboutContinueKey));
              expect(
                rect.top >= 0 && rect.bottom <= size.height,
                isTrue,
                reason:
                    'continue button at $rect falls outside the '
                    '${size.width.toInt()}x${size.height.toInt()} viewport',
              );
            },
          );
        }
      }
    }

    for (final scale in <double>[1.0, 2.0]) {
      testWidgets('landscape 915x412 x$scale in ne', timeout: _timeout, (
        tester,
      ) async {
        await _pumpAbout(
          tester,
          locale: 'ne',
          first: true,
          size: _landscape,
          scale: scale,
        );

        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byKey(aboutContinueKey));
        expect(
          rect.top >= 0 && rect.bottom <= _landscape.height,
          isTrue,
          reason:
              'continue button at $rect falls outside the landscape '
              'viewport',
        );
      });
    }
  });

  group('first run and a later visit are different screens', () {
    testWidgets(
      'first=1 gives one forward button and no way back',
      timeout: _timeout,
      (tester) async {
        await _pumpAbout(tester, locale: 'ne', first: true);

        expect(find.byType(AppBar), findsNothing);
        expect(find.byKey(aboutContinueKey), findsOneWidget);
      },
    );

    testWidgets(
      'a later visit gives the AppBar and no bottom bar',
      timeout: _timeout,
      (tester) async {
        await _pumpAbout(tester, locale: 'ne', first: false);

        expect(find.byType(AppBar), findsOneWidget);
        expect(
          find.byKey(aboutContinueKey),
          findsNothing,
          reason:
              'the back arrow is the exit; a second one is a second thing '
              'to keep in step',
        );
      },
    );

    for (final scale in _scales) {
      testWidgets(
        'a later visit lays out at 320x640 x$scale in ne',
        timeout: _timeout,
        (tester) async {
          await _pumpAbout(
            tester,
            locale: 'ne',
            first: false,
            size: const Size(320, 640),
            scale: scale,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  testWidgets('continue clears the chooser off the stack', timeout: _timeout, (
    tester,
  ) async {
    // Driven through the real first-run flow rather than started at About,
    // because the thing under test is what the button leaves behind.
    await pumpApp(tester, firstRun: true);
    await tester.tap(find.byType(InkWell).first);
    await tester.pumpAndSettle();
    expect(find.byType(WelcomeAboutScreen), findsOneWidget);

    await tester.tap(find.byKey(aboutContinueKey));
    await tester.pumpAndSettle();

    expect(find.byType(WelcomeAboutScreen), findsNothing);
    // `go`, not `push`: nothing of the first run is left to go back to.
    expect(
      tester.state<NavigatorState>(find.byType(Navigator).first).canPop(),
      isFalse,
      reason:
          'a farmer must not be able to walk backwards into a question '
          'they have already answered',
    );
  });

  testWidgets(
    'the introduction names the working crop-help and market paths',
    timeout: _timeout,
    (tester) async {
      await _pumpAbout(tester, locale: 'en', first: true);

      await tester.scrollUntilVisible(
        find.byKey(aboutLeafCheckKey),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(aboutLeafCheckKey), findsOneWidget);
      expect(find.byKey(aboutCropGuideKey), findsOneWidget);
      expect(find.byKey(aboutWeatherKey), findsOneWidget);
      expect(find.byKey(aboutMarketKey), findsOneWidget);
      expect(find.textContaining('possible matches'), findsOneWidget);
      expect(find.textContaining('not a field measurement'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.textContaining('does not upload'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('does not upload'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing, reason: 'no Skip action');
    },
  );

  testWidgets(
    'every block reads as one statement to a screen reader',
    timeout: _timeout,
    (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpAbout(tester, locale: 'en', first: true);

      // Coherent statements, not fragments a reader has to
      // reassemble and cannot resume between.
      expect(
        find.bySemanticsLabel(
          'Plan work, use Nepal crop guidance, check local weather and see '
          'official Kalimati wholesale prices for tomato, potato and maize. '
          'Photo scanning is experimental, covers tomato, potato and maize, '
          'and does not confirm a diagnosis.',
        ),
        findsOneWidget,
      );
      handle.dispose();
    },
  );
}
