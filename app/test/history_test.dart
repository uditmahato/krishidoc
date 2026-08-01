import 'package:core_domain/core_domain.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/app_services.dart';

import 'helpers/pump_app.dart';

/// Fail fast instead of the 10-minute testWidgets default.
const _timeout = Timeout(Duration(minutes: 1));

Future<void> _openHistory(WidgetTester tester) async {
  // Locale-independent target; the tile can sit below the test viewport.
  final tile = find.byIcon(Icons.history_outlined);
  await tester.scrollUntilVisible(
    tile,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(tile);
  await tester.pumpAndSettle();
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

DiagnosisRecord _record(
  AppServices services, {
  required ResultState state,
  required DateTime createdAt,
  List<TopPrediction> predictions = const [],
}) => DiagnosisRecord(
  id: services.ids.newId(),
  state: state,
  predictions: predictions,
  modelVersion: 'tomato-v1',
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
        find.text('अहिलेसम्म कुनै रोग पहिचान छैन। नतिजाहरू यहाँ देखिनेछन्।'),
        findsOneWidget,
      );
    },
  );

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

      expect(find.text('late_blight'), findsOneWidget);
      expect(find.text('Could not identify'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
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

      expect(find.text('early_blight'), findsOneWidget);
    },
  );
}
