import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:krishidoc_app/src/market/market_cache.dart';
import 'package:krishidoc_app/src/market/market_models.dart';

void main() {
  group('MemoryMarketSnapshotCache', () {
    test('round trips and clears a snapshot', () async {
      final cache = MemoryMarketSnapshotCache();

      expect(await cache.read(), isNull);
      await cache.write(_snapshot());
      _expectSnapshot(await cache.read(), average: 48);

      await cache.clear();
      expect(await cache.read(), isNull);
    });
  });

  group('FileMarketSnapshotCache', () {
    late Directory directory;
    late File file;
    late FileMarketSnapshotCache cache;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp(
        'krishidoc_market_cache_',
      );
      file = File(
        '${directory.path}${Platform.pathSeparator}market_snapshot.json',
      );
      cache = FileMarketSnapshotCache.forFile(file);
    });

    tearDown(() async {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    });

    test('a missing cache is a normal miss', () async {
      expect(await cache.read(), isNull);
    });

    test('persists every snapshot field and quote', () async {
      await cache.write(_snapshot());

      final stored = await cache.read();
      _expectSnapshot(stored, average: 48);
      expect(stored!.quotes, hasLength(2));
      expect(stored.quotes.last.commodityName, 'Potato Red');
      expect(stored.quotes.last.unit, 'Kg');
      expect(stored.quotes.last.minimum, 32);
      expect(stored.quotes.last.maximum, 38);
      expect(stored.quotes.last.average, 35);
    });

    test(
      'a corrupt primary falls back to the previous valid generation',
      () async {
        await cache.write(_snapshot());
        await cache.write(_snapshot(average: 52));
        await file.writeAsString('{not-json', flush: true);

        _expectSnapshot(await cache.read(), average: 48);
      },
    );

    test('a corrupt cache without a backup is a normal miss', () async {
      await file.parent.create(recursive: true);
      await file.writeAsString('{not-json', flush: true);

      expect(await cache.read(), isNull);
    });

    test('an unknown cache schema is ignored', () async {
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(<String, Object?>{
          'schemaVersion': 999,
          'snapshot': _snapshot().toJson(),
        }),
        flush: true,
      );

      expect(await cache.read(), isNull);
    });

    test('clear removes the primary and recovery generation', () async {
      await cache.write(_snapshot());
      await cache.write(_snapshot(average: 52));

      await cache.clear();

      expect(await cache.read(), isNull);
      expect(await file.exists(), isFalse);
      expect(await File('${file.path}.bak').exists(), isFalse);
    });
  });
}

MarketSnapshot _snapshot({double average = 48}) => MarketSnapshot(
  quotes: [
    MarketQuote(
      commodityName: 'Tomato Big (Nepali)',
      unit: 'Kg',
      minimum: 42,
      maximum: 55,
      average: average,
    ),
    MarketQuote(
      commodityName: 'Potato Red',
      unit: 'Kg',
      minimum: 32,
      maximum: 38,
      average: 35,
    ),
  ],
  publicationHeading: 'Daily wholesale prices',
  publishedDateLabel: 'August 24, 2026',
  fetchedAt: DateTime.utc(2026, 8, 24, 1, 15),
  providerName: 'Kalimati Fruits and Vegetable Market Development Board',
  providerUrl: Uri.parse('https://kalimatimarket.gov.np'),
);

void _expectSnapshot(MarketSnapshot? snapshot, {required double average}) {
  expect(snapshot, isNotNull);
  expect(snapshot!.publicationHeading, 'Daily wholesale prices');
  expect(snapshot.publishedDateLabel, 'August 24, 2026');
  expect(snapshot.fetchedAt, DateTime.utc(2026, 8, 24, 1, 15));
  expect(
    snapshot.providerName,
    'Kalimati Fruits and Vegetable Market Development Board',
  );
  expect(snapshot.providerUrl, Uri.parse('https://kalimatimarket.gov.np'));
  expect(snapshot.quotes.first.commodityName, 'Tomato Big (Nepali)');
  expect(snapshot.quotes.first.unit, 'Kg');
  expect(snapshot.quotes.first.minimum, 42);
  expect(snapshot.quotes.first.maximum, 55);
  expect(snapshot.quotes.first.average, average);
}
