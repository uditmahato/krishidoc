import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import 'market_models.dart';

abstract interface class MarketService {
  Future<MarketSnapshot> fetch();
}

final class MarketServiceException implements Exception {
  const MarketServiceException(this.kind, [this.cause]);

  final MarketFailureKind kind;
  final Object? cause;

  @override
  String toString() => cause == null
      ? 'MarketServiceException($kind)'
      : 'MarketServiceException($kind, $cause)';
}

/// Retrieves Kalimati's latest published daily wholesale price table.
///
/// The official site currently exposes this as an HTML page rather than a
/// documented public JSON API. The strict parser deliberately fails the whole
/// refresh if the table changes or contains inconsistent values; callers can
/// then keep showing their last known-good snapshot instead of partial prices.
final class KalimatiMarketService implements MarketService {
  KalimatiMarketService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? providerUrl;

  static final Uri providerUrl = Uri.https('kalimatimarket.gov.np', '/price');
  static const String providerName =
      'Kalimati Fruits and Vegetable Market Development Board';
  static const Duration _timeout = Duration(seconds: 12);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<MarketSnapshot> fetch() async {
    late final http.Response response;
    try {
      response = await _client
          .get(
            _endpoint,
            headers: const {
              'Accept': 'text/html,application/xhtml+xml',
              'User-Agent': 'KrishiDoc/0.3 (Kalimati market price reader)',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const MarketServiceException(MarketFailureKind.network);
    } on SocketException {
      throw const MarketServiceException(MarketFailureKind.network);
    } on http.ClientException {
      throw const MarketServiceException(MarketFailureKind.network);
    } on Object {
      throw const MarketServiceException(MarketFailureKind.unknown);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const MarketServiceException(MarketFailureKind.serviceUnavailable);
    }

    try {
      final source = utf8.decode(response.bodyBytes);
      return _parse(source, DateTime.now().toUtc());
    } on MarketServiceException {
      rethrow;
    } on Object catch (error) {
      throw MarketServiceException(MarketFailureKind.invalidData, error);
    }
  }

  MarketSnapshot _parse(String source, DateTime fetchedAt) {
    final document = html_parser.parse(source);
    final table = document.querySelector('#commodityPriceParticular');
    if (table == null) {
      throw const FormatException('official commodity table is missing');
    }

    final headingElement = document.querySelector(
      '.project-detail h4.bottom-head',
    );
    final publicationHeading = _normalizedText(headingElement?.text ?? '');
    if (publicationHeading.isEmpty) {
      throw const FormatException('publication heading is missing');
    }
    final publishedDateLabel = _extractPublishedDate(publicationHeading);

    final rows = table.querySelectorAll('tbody tr');
    if (rows.isEmpty) {
      throw const FormatException('official commodity rows are missing');
    }

    final quotes = <MarketQuote>[];
    for (final row in rows) {
      final cells = row.querySelectorAll('td');
      if (cells.length != 5) {
        throw const FormatException('commodity row must have five columns');
      }

      final name = _normalizedText(cells[0].text);
      final unit = _normalizedText(cells[1].text);
      if (name.isEmpty || unit.isEmpty) {
        throw const FormatException('commodity name or unit is empty');
      }

      final minimum = _price(cells[2].text);
      final maximum = _price(cells[3].text);
      final average = _price(cells[4].text);
      if (minimum > average || average > maximum) {
        throw const FormatException('commodity prices are inconsistent');
      }

      quotes.add(
        MarketQuote(
          commodityName: name,
          unit: unit,
          minimum: minimum,
          maximum: maximum,
          average: average,
        ),
      );
    }

    return MarketSnapshot(
      quotes: quotes,
      publicationHeading: publicationHeading,
      publishedDateLabel: publishedDateLabel,
      fetchedAt: fetchedAt,
      providerName: providerName,
      providerUrl: providerUrl,
    );
  }

  static String _extractPublishedDate(String heading) {
    final separator = heading.lastIndexOf(' - ');
    final value = separator < 0 ? '' : heading.substring(separator + 3).trim();
    if (value.isEmpty) {
      throw const FormatException('published date is missing from heading');
    }
    return value;
  }

  static double _price(String source) {
    var normalized = _normalizedText(source);
    const nepaliDigits = '०१२३४५६७८९';
    for (var digit = 0; digit < nepaliDigits.length; digit++) {
      normalized = normalized.replaceAll(nepaliDigits[digit], '$digit');
    }
    final matches = RegExp(
      r'[0-9][0-9,]*(?:\.[0-9]+)?',
    ).allMatches(normalized).toList(growable: false);
    final numericText = matches.length == 1
        ? matches.single.group(0)!.replaceAll(',', '')
        : '';
    final value = normalized.contains('-')
        ? null
        : double.tryParse(numericText);
    if (value == null || !value.isFinite || value < 0) {
      throw FormatException(
        'price is not a non-negative number: "${_normalizedText(source)}" '
        'normalized to "$numericText"',
      );
    }
    return value;
  }

  static String _normalizedText(String value) =>
      value.replaceAll('\u00a0', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
}
