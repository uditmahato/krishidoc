import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:krishidoc_app/src/app_services.dart';
import 'package:krishidoc_app/src/history_screen.dart';
import 'package:krishidoc_app/src/home_screen.dart';
import 'package:krishidoc_app/src/diagnosis/disease_scan_intro_screen.dart';

import 'helpers/pump_app.dart';

/// Fail fast instead of the 10-minute testWidgets default.
const _timeout = Timeout(Duration(minutes: 1));

Future<void> _openHistory(WidgetTester tester) async {
  // Diagnosis history is an internal/sample surface now, so tests address it
  // directly instead of requiring a misleading farmer-shell entry point.
  GoRouter.of(tester.element(find.byType(HomeScreen))).go('/history');
  await tester.pumpAndSettle();
}

DiagnosisRecord _record(
  AppServices services, {
  required ResultState state,
  required DateTime createdAt,
  List<TopPrediction> predictions = const [],
  String modelVersion = 'tomato-v1',
}) => DiagnosisRecord(
  id: services.ids.newId(),
  state: state,
  predictions: predictions,
  modelVersion: modelVersion,
  createdAt: createdAt,
);

void main() {
  testWidgets(
    'empty history shows the localized empty state',
    timeout: _timeout,
    (tester) async {
      await pumpApp(tester, locale: const Locale('ne'));
      await _openHistory(tester);
      expect(
        find.text('तपाईंले अझै कुनै पात जाँच्नुभएको छैन।'),
        findsOneWidget,
      );
      expect(find.byKey(historyEmptyActionKey), findsOneWidget);
    },
  );

  testWidgets(
    'the empty state funnels to disease scan setup',
    timeout: _timeout,
    (tester) async {
      await pumpApp(tester, locale: const Locale('en'));
      await _openHistory(tester);

      await tester.tap(find.byKey(historyEmptyActionKey));
      await tester.pumpAndSettle();

      expect(find.byType(DiseaseScanIntroScreen), findsOneWidget);
    },
  );

  group('the empty-state action stays reachable', () {
    // Same rule as About: the button lives outside the scroll view, so it
    // must be inside the viewport at every size, scale and language.
    for (final size in const [Size(320, 640), Size(360, 800)]) {
      for (final scale in const [1.0, 1.3, 2.0]) {
        for (final locale in const ['ne', 'hi', 'en']) {
          testWidgets(
            'at ${size.width.toInt()}x${size.height.toInt()} x$scale in $locale',
            timeout: _timeout,
            (tester) async {
              useScreen(tester, size, textScale: scale);
              await pumpApp(tester, locale: Locale(locale));
              await _openHistory(tester);

              expect(tester.takeException(), isNull);
              final rect = tester.getRect(find.byKey(historyEmptyActionKey));
              expect(
                rect.top >= 0 && rect.bottom <= size.height,
                isTrue,
                reason: 'action at $rect falls outside the viewport',
              );
            },
          );
        }
      }
    }

    testWidgets('in landscape 915x412 x2.0 in ne', timeout: _timeout, (
      tester,
    ) async {
      useScreen(tester, const Size(915, 412), textScale: 2.0);
      await pumpApp(tester, locale: const Locale('ne'));
      await _openHistory(tester);

      expect(tester.takeException(), isNull);
      final rect = tester.getRect(find.byKey(historyEmptyActionKey));
      expect(rect.top >= 0 && rect.bottom <= 412, isTrue, reason: '$rect');
    });
  });

  testWidgets(
    'records render newest first with state icons',
    timeout: _timeout,
    (tester) async {
      final services = await pumpApp(tester, locale: const Locale('en'));
      await services.diagnosisStore.upsert(
        _record(
          services,
          state: ResultState.confident,
          createdAt: DateTime.utc(2026, 7, 1),
          predictions: [TopPrediction(label: 'late_blight', confidence: 0.9)],
        ),
      );
      await services.diagnosisStore.upsert(
        _record(
          services,
          state: ResultState.outOfScope,
          createdAt: DateTime.utc(2026, 7, 2),
        ),
      );

      await _openHistory(tester);

      expect(find.text('Late blight'), findsOneWidget);
      expect(find.text('Could not identify'), findsOneWidget);
      expect(find.byIcon(Icons.manage_search_rounded), findsOneWidget);
      // `search_off`, not `image_not_supported`. The out-of-scope state means
      // "this app does not cover that plant yet", and a broken-image glyph
      // blames the farmer's photo for a gap in our coverage.
      expect(find.byIcon(Icons.search_off_outlined), findsOneWidget);

      final tiles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .toList(growable: false);
      expect(tiles, hasLength(2));
      expect(
        (tiles.first.title! as Text).data,
        'Could not identify',
        reason: 'newest record (July 2) renders first',
      );
    },
  );

  testWidgets(
    'new records appear reactively while the screen is open',
    timeout: _timeout,
    (tester) async {
      final services = await pumpApp(tester, locale: const Locale('en'));
      await _openHistory(tester);
      expect(find.byType(ListTile), findsNothing);

      await services.diagnosisStore.upsert(
        _record(
          services,
          state: ResultState.confident,
          createdAt: DateTime.utc(2026, 7, 3),
          predictions: [TopPrediction(label: 'early_blight', confidence: 0.8)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Early blight'), findsOneWidget);
    },
  );

  // D-52 forbids ANY surface presenting a sample answer as a real one, and
  // History is a surface: it renders a stored diagnosis with a confident glyph
  // and a disease name. These two tests are what turns that from a rule
  // someone has to remember into one the suite refuses to let go.
  group('sample data is declared (D-52)', () {
    testWidgets(
      'a sample record is marked, in words and in glyph',
      timeout: _timeout,
      (tester) async {
        final services = await pumpApp(tester, locale: const Locale('en'));
        await services.diagnosisStore.upsert(
          _record(
            services,
            state: ResultState.confident,
            createdAt: DateTime.utc(2026, 7, 4),
            predictions: [TopPrediction(label: 'late_blight', confidence: 0.9)],
            modelVersion: 'sample-tomato-v0',
          ),
        );

        await _openHistory(tester);

        expect(
          find.textContaining('Sample data'),
          findsOneWidget,
          reason: 'History must not present a sample answer as a real one',
        );
        expect(find.byIcon(Icons.science_outlined), findsWidgets);
      },
    );

    testWidgets('a real record carries no sample notice', timeout: _timeout, (
      tester,
    ) async {
      final services = await pumpApp(tester, locale: const Locale('en'));
      await services.diagnosisStore.upsert(
        _record(
          services,
          state: ResultState.confident,
          createdAt: DateTime.utc(2026, 7, 5),
          predictions: [TopPrediction(label: 'late_blight', confidence: 0.9)],
        ),
      );

      await _openHistory(tester);

      // The inverse assertion matters as much as the first: a notice that is
      // always on says nothing, and would train the reader to skip it before
      // the first real model ever ships.
      expect(find.textContaining('Sample data'), findsNothing);
      expect(find.byIcon(Icons.science_outlined), findsNothing);
    });
  });
}
