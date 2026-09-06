import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:krishidoc_app/src/market/market.dart';

void main() {
  group('KalimatiMarketService', () {
    test('reads the official Nepali wholesale table from UTF-8 HTML', () async {
      http.Request? capturedRequest;
      final service = KalimatiMarketService(
        client: MockClient((request) async {
          capturedRequest = request;
          return http.Response.bytes(utf8.encode(_validPage), 200);
        }),
      );

      final snapshot = await service.fetch();

      expect(capturedRequest?.url, KalimatiMarketService.providerUrl);
      expect(capturedRequest?.headers['Accept'], contains('text/html'));
      expect(snapshot.providerName, KalimatiMarketService.providerName);
      expect(snapshot.providerUrl, KalimatiMarketService.providerUrl);
      expect(
        snapshot.publicationHeading,
        'संकलित दैनिक थोक मूल्य बारे जानकारी - वि.सं. भदौ ०८, २०८३',
      );
      expect(snapshot.publishedDateLabel, 'वि.सं. भदौ ०८, २०८३');
      expect(snapshot.fetchedAt.isUtc, isTrue);
      expect(snapshot.quotes, hasLength(2));
      expect(snapshot.quotes.first.commodityName, 'गोलभेडा ठूलो (नेपाली)');
      expect(snapshot.quotes.first.unit, 'के.जी.');
      expect(snapshot.quotes.first.minimum, 42);
      expect(snapshot.quotes.first.maximum, 55);
      expect(snapshot.quotes.first.average, 48.5);
      expect(snapshot.quotes.last.average, 1234.25);
    });

    test('maps HTTP errors to service unavailable', () async {
      final service = KalimatiMarketService(
        client: MockClient((request) async => http.Response('busy', 503)),
      );

      await expectLater(
        service.fetch(),
        throwsA(
          isA<MarketServiceException>().having(
            (error) => error.kind,
            'kind',
            MarketFailureKind.serviceUnavailable,
          ),
        ),
      );
    });

    test('maps client errors to a network failure', () async {
      final service = KalimatiMarketService(
        client: MockClient((request) async {
          throw http.ClientException('offline');
        }),
      );

      await expectLater(
        service.fetch(),
        throwsA(
          isA<MarketServiceException>().having(
            (error) => error.kind,
            'kind',
            MarketFailureKind.network,
          ),
        ),
      );
    });

    test('rejects a missing official table as invalid data', () async {
      final service = KalimatiMarketService(
        client: MockClient(
          (request) async => http.Response.bytes(
            utf8.encode('<html><body>changed</body></html>'),
            200,
          ),
        ),
      );

      await expectLater(
        service.fetch(),
        throwsA(
          isA<MarketServiceException>().having(
            (error) => error.kind,
            'kind',
            MarketFailureKind.invalidData,
          ),
        ),
      );
    });

    test(
      'rejects inconsistent price bounds rather than partial data',
      () async {
        final service = KalimatiMarketService(
          client: MockClient(
            (request) async => http.Response.bytes(
              utf8.encode(_validPage.replaceFirst('रू ४८.५०', 'रू ६०')),
              200,
            ),
          ),
        );

        await expectLater(
          service.fetch(),
          throwsA(
            isA<MarketServiceException>().having(
              (error) => error.kind,
              'kind',
              MarketFailureKind.invalidData,
            ),
          ),
        );
      },
    );
  });

  test('market snapshots round-trip through cache-safe JSON', () async {
    final service = KalimatiMarketService(
      client: MockClient(
        (request) async => http.Response.bytes(utf8.encode(_validPage), 200),
      ),
    );
    final original = await service.fetch();

    final restored = MarketSnapshot.fromJson(original.toJson());

    expect(restored.publicationHeading, original.publicationHeading);
    expect(restored.providerUrl, original.providerUrl);
    expect(restored.fetchedAt, original.fetchedAt);
    expect(restored.quotes.first.toJson(), original.quotes.first.toJson());
  });
}

const String _validPage = '''
<!doctype html>
<html>
  <body>
    <div class="project-detail">
      <h4 class="bottom-head">
        संकलित   दैनिक थोक मूल्य बारे जानकारी - वि.सं. भदौ ०८, २०८३
      </h4>
      <table id="commodityPriceParticular">
        <thead>
          <tr><th>उपज</th><th>एकाइ</th><th>न्यूनतम</th><th>अधिकतम</th><th>औसत</th></tr>
        </thead>
        <tbody>
          <tr>
            <td>गोलभेडा ठूलो (नेपाली)</td><td>के.जी.</td>
            <td>रू ४२</td><td>रू ५५</td><td>रू ४८.५०</td>
          </tr>
          <tr>
            <td>बन्दा (स्थानीय)</td><td>के.जी.</td>
            <td>रू. १,२००</td><td>रू. १,२५०</td><td>रू. १,२३४.२५</td>
          </tr>
        </tbody>
      </table>
    </div>
  </body>
</html>
''';
