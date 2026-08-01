import 'package:core_domain/core_domain.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:krishidoc_app/l10n/gen/app_localizations.dart';
import 'package:krishidoc_app/main.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/providers.dart';

/// Module 12 verification that only real hardware can give.
///
/// The widget-test matrix already proves the home grid cannot overflow, but it
/// proves it with no font loaded: `flutter test` renders placeholder boxes, so
/// it can say nothing about whether Devanagari actually fits. Devanagari is
/// where the risk is. Vowel signs stack above the shirorekha and hang below
/// the baseline, so a line of Nepali inks a taller box than a line of English
/// at the same point size, and no font is bundled, which means the exact
/// extents come from whatever the OEM ROM ships.
///
/// This file therefore re-runs the same assertions against the device's real
/// Devanagari font. It drives only this app's own widget tree.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  AppServices? open;

  Future<void> bootHome(
    WidgetTester tester, {
    required Locale locale,
    required double textScale,
  }) async {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    // One connection at a time. `main` opens the real on-device database, and
    // a second open against the same file is refused with "database is
    // locked", so a test that boots twice must close the first.
    await open?.dispose();
    final services = await AppServices.open();
    open = services;
    addTearDown(() async {
      await services.dispose();
      open = null;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        // Keyed by locale so a second boot builds a NEW State. Without this
        // the element is reused, `initState` does not run again, and
        // `initialLocale` is silently ignored: a test that booted twice
        // measured the first locale both times and looked like a passing
        // comparison of a value against itself.
        child: KrishiDocApp(
          key: ValueKey(locale.languageCode),
          initialLocale: locale,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }

  for (final locale in const [Locale('ne'), Locale('hi'), Locale('en')]) {
    for (final scale in const [1.0, 1.3, 2.0]) {
      testWidgets(
        'home fits on this device in ${locale.languageCode} at '
        'x${scale.toStringAsFixed(1)}',
        (tester) async {
          await bootHome(tester, locale: locale, textScale: scale);
          expect(
            tester.takeException(),
            isNull,
            reason:
                'real-font layout overflowed in ${locale.languageCode} at '
                'scale $scale on this device',
          );
          // The tiles must still be there, not merely not-crashing.
          expect(find.byType(Card), findsNWidgets(4));
        },
      );
    }
  }

  testWidgets('Devanagari really does ink taller than Latin on this device', (
    tester,
  ) async {
    // The point of the KdType Devanagari column, measured rather than
    // asserted from the style object: the same string slot, laid out in two
    // scripts, must produce a taller line box in Devanagari. If a future edit
    // reverts to Flutter's tall2021 (which is byte-identical to the English
    // theme) this is the assertion that notices.
    // One fixed string, rendered in both scripts, so the comparison is of
    // line metrics and not of how long a translation happens to be.
    const probe = 'क ख ग घ';

    (double lineHeight, double inkHeight) measure(WidgetTester tester) {
      final context = tester.element(find.byType(Scaffold).first);
      final style = Theme.of(context).textTheme.bodyLarge!;
      final painter = TextPainter(
        text: TextSpan(text: probe, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      return (style.height!, painter.height);
    }

    await bootHome(tester, locale: const Locale('en'), textScale: 1.0);
    final (latinFactor, latinInk) = measure(tester);

    await bootHome(tester, locale: const Locale('ne'), textScale: 1.0);
    final (devaFactor, devaInk) = measure(tester);

    expect(
      devaFactor,
      greaterThanOrEqualTo(KdType.devanagariMinHeight),
      reason:
          'the running theme is not using the Devanagari column: line-height '
          'factor was $devaFactor, Latin is $latinFactor',
    );
    expect(
      devaInk,
      greaterThan(latinInk),
      reason:
          'Devanagari at Latin line metrics collides stacked matras between '
          'lines; measured Latin ${latinInk}px vs Devanagari ${devaInk}px '
          'for the same string',
    );
  });

  testWidgets('the audited tokens are the pixels on this screen', (
    tester,
  ) async {
    // The seed defect, closed on real hardware. `ColorScheme.fromSeed`
    // returned #3C6939 for a #1B5E20 seed, so for eleven modules the app
    // painted a green nobody had contrast checked.
    await bootHome(tester, locale: const Locale('ne'), textScale: 1.0);
    final theme = Theme.of(tester.element(find.byType(Scaffold).first));
    expect(theme.colorScheme.primary, KdColors.primary);
    expect(theme.scaffoldBackgroundColor, KdColors.canvas);
    expect(
      contrastRatio(theme.colorScheme.onSurface, theme.colorScheme.surface),
      greaterThan(12.0),
    );
  });

  testWidgets('history announces its state, not just a disease name', (
    tester,
  ) async {
    // P0-4: all three result states used to emit byte-identical semantics,
    // so certainty, the entire point of the tri-state design, never reached a
    // screen reader.
    final services = await AppServices.open();
    addTearDown(services.dispose);
    await services.diagnosisStore.upsert(
      DiagnosisRecord(
        id: '01900000-0000-7000-8000-000000000001',
        state: ResultState.confident,
        predictions: [
          TopPrediction(label: 'tomato_late_blight', confidence: 0.91),
        ],
        modelVersion: 'sample-v0',
        createdAt: DateTime.utc(2026, 8, 1, 10),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [servicesProvider.overrideWithValue(services)],
        child: const KrishiDocApp(initialLocale: Locale('en')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    final context = tester.element(find.byType(Scaffold).first);
    final expected = AppLocalizations.of(context).a11yStateConfident;

    await tester.tap(find.byIcon(Icons.history_outlined));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.bySemanticsLabel(RegExp('^$expected')).evaluate().isNotEmpty) {
        break;
      }
    }
    expect(find.bySemanticsLabel(RegExp('^$expected')), findsOneWidget);
  });
}
