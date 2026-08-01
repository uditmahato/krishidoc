import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
        testWidgets(
          'home lays out without overflow at ${screen.key} '
          'x${scale.toStringAsFixed(1)} in ${locale.key}',
          (tester) async {
            useScreen(tester, screen.value, textScale: scale);
            await pumpApp(tester, locale: locale.value);

            // An overflow reports itself through FlutterError during paint,
            // which the harness surfaces here. Reading it explicitly gives a
            // failure message that names the exact combination.
            expect(
              tester.takeException(),
              isNull,
              reason:
                  'overflow at ${screen.key} scale $scale in ${locale.key}',
            );

            // Overflow is not the only way to lose a tile: content can also
            // sit below the fold with no way to reach it. The page scrolls,
            // so every tile must be findable after scrolling to it.
            for (final tile in [
              find.byIcon(Icons.photo_camera_outlined),
              find.byIcon(Icons.chat_bubble_outline),
              find.byIcon(Icons.history_outlined),
              find.byIcon(Icons.settings_outlined),
            ]) {
              await tester.scrollUntilVisible(
                tile,
                120,
                scrollable: find.byType(Scrollable).first,
              );
              expect(tile, findsOneWidget);
            }
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('tiles grow with the text scaler rather than clipping', (
    tester,
  ) async {
    // The positive statement behind the guard above: at a larger scale the
    // tile must get taller. Under the old aspect-ratio grid this height was
    // identical at every scale, which is exactly why the label had nowhere to
    // go and overflowed instead.
    double tileHeight(WidgetTester tester) => tester
        .getSize(
          find
              .ancestor(
                of: find.byIcon(Icons.history_outlined),
                matching: find.byType(Card),
              )
              .first,
        )
        .height;

    useScreen(tester, const Size(360, 800));
    await pumpApp(tester, locale: const Locale('ne'));
    final atDefault = tileHeight(tester);

    useScreen(tester, const Size(360, 800), textScale: 2.0);
    await pumpApp(tester, locale: const Locale('ne'));
    final atDouble = tileHeight(tester);

    expect(
      atDouble,
      greaterThan(atDefault),
      reason: 'a tile whose height ignores its content will clip it',
    );
  });

  testWidgets('every home tile clears the 48dp touch minimum', (tester) async {
    useScreen(tester, const Size(320, 640));
    await pumpApp(tester, locale: const Locale('ne'));

    for (final icon in [
      Icons.photo_camera_outlined,
      Icons.chat_bubble_outline,
      Icons.history_outlined,
      Icons.settings_outlined,
    ]) {
      final size = tester.getSize(
        find.ancestor(of: find.byIcon(icon), matching: find.byType(Card)).first,
      );
      expect(size.width, greaterThanOrEqualTo(48.0), reason: '$icon width');
      expect(size.height, greaterThanOrEqualTo(48.0), reason: '$icon height');
    }
  });
}
