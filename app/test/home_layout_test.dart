import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/home_screen.dart';

import 'helpers/pump_app.dart';

/// Layout regression guard for the home grid.
///
/// The grid used to size its tiles with `childAspectRatio`, which derives
/// height from width and therefore ignores the content entirely. That produced
/// real `RenderFlex overflowed` exceptions on 320x640 and 360x800 at the
/// default font size, no accessibility settings involved, and 360x800 is one
/// of the most common resolutions in this market. It survived four modules of
/// green tests because the default flutter_test surface is 800x600, which is
/// wider and shorter than any phone the app actually runs on.
///
/// These are not pixel goldens on purpose. Widget tests render with no real
/// font loaded, so a golden would pin the layout of placeholder boxes and
/// prove nothing about whether Devanagari fits; it would also break on every
/// unrelated platform font change. Asserting "no overflow, every tile
/// reachable, across the real matrix of sizes, scales and languages" tests the
/// property that actually failed.
void main() {
  // Chosen from the target hardware, not from convenience. 320x640 is the
  // floor this app supports; 360x800 is the volume device; 412x915 is a
  // mid-range phone.
  const screens = <String, Size>{
    '320x640': Size(320, 640),
    '360x800': Size(360, 800),
    '412x915': Size(412, 915),
  };

  // 1.0 is default, 1.3 is Android's "Large", 2.0 is the maximum the system
  // font slider reaches on recent versions.
  const scales = <double>[1.0, 1.3, 2.0];

  // Nepali first: it is the language most of these users read, and its labels
  // wrap sooner than English, so it fails first. Testing only English is how
  // the overflow stayed hidden.
  const locales = <String, Locale>{
    'ne': Locale('ne'),
    'hi': Locale('hi'),
    'en': Locale('en'),
  };

  for (final screen in screens.entries) {
    for (final scale in scales) {
      for (final locale in locales.entries) {
        testWidgets('home lays out without overflow at ${screen.key} '
            'x${scale.toStringAsFixed(1)} in ${locale.key}', (tester) async {
          useScreen(tester, screen.value, textScale: scale);
          await pumpApp(tester, locale: locale.value);

          // An overflow reports itself through FlutterError during paint,
          // which the harness surfaces here. Reading it explicitly gives a
          // failure message that names the exact combination.
          expect(
            tester.takeException(),
            isNull,
            reason: 'overflow at ${screen.key} scale $scale in ${locale.key}',
          );

          // Overflow is not the only way to lose a row: content can also sit
          // below the fold with no way to reach it. The page scrolls, so
          // every row must be findable after scrolling to it. Keyed rather
          // than found by icon, because the not-ready row and the debug
          // capture door now share the camera glyph.
          for (final row in [
            find.byKey(homeNotReadyKey),
            find.byKey(homeHistoryKey),
          ]) {
            await tester.scrollUntilVisible(
              row,
              120,
              scrollable: find.byType(Scrollable).first,
            );
            expect(row, findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  // Landscape has never been covered by any test in this repo, and review 06
  // records it as broken under the old grid. A short wide viewport is where a
  // scrolling page and a fixed-height child disagree.
  for (final scale in <double>[1.0, 2.0]) {
    testWidgets('home lays out in landscape 915x412 x$scale in ne', (
      tester,
    ) async {
      useScreen(tester, const Size(915, 412), textScale: scale);
      await pumpApp(tester, locale: const Locale('ne'));

      expect(tester.takeException(), isNull);
      for (final row in [
        find.byKey(homeNotReadyKey),
        find.byKey(homeHistoryKey),
      ]) {
        await tester.scrollUntilVisible(
          row,
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(row, findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('tiles grow with the text scaler rather than clipping', (
    tester,
  ) async {
    // The positive statement behind the guard above: at a larger scale the
    // tile must get taller. Under the old aspect-ratio grid this height was
    // identical at every scale, which is exactly why the label had nowhere to
    // go and overflowed instead.
    // Scrolled into view before measuring. The page is a lazy ListView, so at
    // scale 2.0 the history row is below the fold and simply not built, and
    // the finder fails with "No element" rather than with a wrong height.
    Future<double> rowHeight(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.byKey(homeHistoryKey),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      return tester
          .getSize(
            find
                .descendant(
                  of: find.byKey(homeHistoryKey),
                  matching: find.byType(Card),
                )
                .first,
          )
          .height;
    }

    useScreen(tester, const Size(360, 800));
    await pumpApp(tester, locale: const Locale('ne'));
    final atDefault = await rowHeight(tester);

    useScreen(tester, const Size(360, 800), textScale: 2.0);
    await pumpApp(tester, locale: const Locale('ne'));
    final atDouble = await rowHeight(tester);

    expect(
      atDouble,
      greaterThan(atDefault),
      reason: 'a tile whose height ignores its content will clip it',
    );
  });

  testWidgets('every home row clears the 48dp touch minimum', (tester) async {
    useScreen(tester, const Size(320, 640));
    await pumpApp(tester, locale: const Locale('ne'));

    for (final key in [homeNotReadyKey, homeHistoryKey]) {
      final size = tester.getSize(
        find.descendant(of: find.byKey(key), matching: find.byType(Card)).first,
      );
      expect(size.width, greaterThanOrEqualTo(48.0), reason: '$key width');
      expect(size.height, greaterThanOrEqualTo(48.0), reason: '$key height');
    }
  });
}
