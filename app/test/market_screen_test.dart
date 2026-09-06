import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/home_screen.dart';
import 'package:krishidoc_app/src/market/market.dart';

import 'helpers/pump_app.dart';

void main() {
  testWidgets('Market waits until its bottom tab is selected', (tester) async {
    final service = _MarketService(() async => _snapshot());
    final cache = MemoryMarketSnapshotCache();
    await pumpApp(tester, marketService: service, marketCache: cache);

    expect(service.calls, 0);

    await tester.tap(find.byKey(homeMarketTabKey));
    await tester.pumpAndSettle();

    expect(service.calls, 1);
    await _scrollTo(tester, find.text('Tomato Big (Nepali)'));
    expect(find.text('Tomato Big (Nepali)'), findsOneWidget);
    expect(
      find.text('Kalimati Fruits and Vegetable Market Development Board'),
      findsOneWidget,
    );
    expect(find.text('Published: August 24, 2026'), findsOneWidget);
    expect(find.text('Rs 48.50'), findsOneWidget);
    expect(find.text('Kg'), findsWidgets);
    await _scrollTo(
      tester,
      find.textContaining('Wholesale reference prices only'),
    );
    expect(find.textContaining('Farmgate'), findsOneWidget);
    expect((await cache.read())?.quotes, hasLength(2));
  });

  testWidgets('search filters official commodity names', (tester) async {
    await pumpApp(
      tester,
      marketService: _MarketService(() async => _snapshot()),
    );
    await tester.tap(find.byKey(homeMarketTabKey));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(marketSearchKey));
    await tester.enterText(find.byKey(marketSearchKey), 'potato');
    await tester.pump();

    await _scrollTo(tester, find.text('Potato Red'));
    expect(find.text('Potato Red'), findsOneWidget);
    expect(find.text('Tomato Big (Nepali)'), findsNothing);

    await tester.enterText(find.byKey(marketSearchKey), 'coffee');
    await tester.pump();
    expect(find.text('No produce matches this search.'), findsOneWidget);
  });

  testWidgets('a failed refresh keeps the saved official list visible', (
    tester,
  ) async {
    final cache = MemoryMarketSnapshotCache(_snapshot());
    final service = _MarketService(
      () async => throw const MarketServiceException(MarketFailureKind.network),
    );
    await pumpApp(tester, marketService: service, marketCache: cache);

    await tester.tap(find.byKey(homeMarketTabKey));
    await tester.pumpAndSettle();

    expect(find.byKey(marketFailureKey), findsOneWidget);
    expect(find.byKey(marketSavedKey), findsOneWidget);
    expect(
      find.textContaining('last official list saved on this phone'),
      findsOneWidget,
    );
    await _scrollTo(tester, find.text('Tomato Big (Nepali)'));
    expect(find.text('Tomato Big (Nepali)'), findsOneWidget);
  });

  testWidgets('Market remains usable in Nepali at large text size', (
    tester,
  ) async {
    useScreen(tester, const Size(360, 800), textScale: 2);
    await pumpApp(
      tester,
      locale: const Locale('ne'),
      marketService: _MarketService(() async => _snapshot()),
    );

    await tester.tap(find.byKey(homeMarketTabKey));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byKey(marketSearchKey));
    expect(find.byKey(marketSearchKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    240,
    scrollable: find
        .descendant(
          of: find.byKey(marketPriceListKey),
          matching: find.byType(Scrollable),
        )
        .first,
  );
}

final class _MarketService implements MarketService {
  _MarketService(this._fetch);

  final Future<MarketSnapshot> Function() _fetch;
  int calls = 0;

  @override
  Future<MarketSnapshot> fetch() {
    calls++;
    return _fetch();
  }
}

MarketSnapshot _snapshot() => MarketSnapshot(
  quotes: [
    MarketQuote(
      commodityName: 'Tomato Big (Nepali)',
      unit: 'Kg',
      minimum: 42,
      maximum: 55,
      average: 48.5,
    ),
    MarketQuote(
      commodityName: 'Potato Red',
      unit: 'Kg',
      minimum: 32,
      maximum: 38,
      average: 35,
    ),
  ],
  publicationHeading: 'Daily wholesale prices - August 24, 2026',
  publishedDateLabel: 'August 24, 2026',
  fetchedAt: DateTime.utc(2026, 8, 24, 1, 15),
  providerName: KalimatiMarketService.providerName,
  providerUrl: KalimatiMarketService.providerUrl,
);
