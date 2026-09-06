/// One commodity row exactly as published by the Kalimati market board.
final class MarketQuote {
  MarketQuote({
    required this.commodityName,
    required this.unit,
    required this.minimum,
    required this.maximum,
    required this.average,
  }) {
    if (commodityName.trim().isEmpty || unit.trim().isEmpty) {
      throw ArgumentError('Commodity name and unit must not be empty.');
    }
    if (![minimum, maximum, average].every((value) => value.isFinite) ||
        minimum < 0 ||
        maximum < 0 ||
        average < 0 ||
        minimum > average ||
        average > maximum) {
      throw ArgumentError('Market prices must satisfy min <= average <= max.');
    }
  }

  final String commodityName;
  final String unit;
  final double minimum;
  final double maximum;
  final double average;

  /// Matches the official Nepali label and a small set of common search terms.
  ///
  /// This does not translate the value shown to the user. Kalimati's official
  /// commodity name and unit remain the source of truth.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;

    final haystack = '${commodityName.toLowerCase()} ${unit.toLowerCase()}';
    if (haystack.contains(needle)) return true;

    for (final entry in _searchAliases.entries) {
      if (commodityName.contains(entry.key) &&
          entry.value.any((alias) => alias.contains(needle))) {
        return true;
      }
    }
    return false;
  }

  Map<String, Object?> toJson() => {
    'commodityName': commodityName,
    'unit': unit,
    'minimum': minimum,
    'maximum': maximum,
    'average': average,
  };

  factory MarketQuote.fromJson(Map<String, Object?> json) => MarketQuote(
    commodityName: _jsonString(json, 'commodityName'),
    unit: _jsonString(json, 'unit'),
    minimum: _jsonNumber(json, 'minimum').toDouble(),
    maximum: _jsonNumber(json, 'maximum').toDouble(),
    average: _jsonNumber(json, 'average').toDouble(),
  );

  static const Map<String, List<String>> _searchAliases = {
    'गोलभेडा': ['tomato', 'टमाटर'],
    'आलु': ['potato', 'आलू'],
    'मकै': ['maize', 'corn', 'मक्का'],
    'प्याज': ['onion'],
    'लसुन': ['garlic'],
    'गाजर': ['carrot'],
    'बन्दा': ['cabbage'],
    'काउली': ['cauliflower'],
    'काँक्रो': ['cucumber'],
    'अदुवा': ['ginger'],
    'खुर्सानी': ['chilli', 'chili'],
    'केरा': ['banana'],
    'स्याउ': ['apple'],
    'कागती': ['lemon', 'lime'],
    'भिन्डी': ['okra', 'lady finger'],
  };
}

/// Latest complete daily wholesale list retrieved from the official source.
final class MarketSnapshot {
  MarketSnapshot({
    required List<MarketQuote> quotes,
    required this.publicationHeading,
    required this.publishedDateLabel,
    required this.fetchedAt,
    required this.providerName,
    required this.providerUrl,
  }) : quotes = List.unmodifiable(quotes) {
    if (quotes.isEmpty ||
        publicationHeading.trim().isEmpty ||
        publishedDateLabel.trim().isEmpty ||
        providerName.trim().isEmpty ||
        !providerUrl.hasScheme ||
        !providerUrl.hasAuthority) {
      throw ArgumentError('Market snapshot metadata must be complete.');
    }
  }

  final List<MarketQuote> quotes;

  /// Full official heading, retained verbatim apart from whitespace folding.
  final String publicationHeading;

  /// The raw Bikram Sambat date label extracted from [publicationHeading].
  final String publishedDateLabel;
  final DateTime fetchedAt;
  final String providerName;
  final Uri providerUrl;

  Map<String, Object?> toJson() => {
    'quotes': quotes.map((quote) => quote.toJson()).toList(growable: false),
    'publicationHeading': publicationHeading,
    'publishedDateLabel': publishedDateLabel,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
    'providerName': providerName,
    'providerUrl': providerUrl.toString(),
  };

  factory MarketSnapshot.fromJson(Map<String, Object?> json) {
    final rawQuotes = json['quotes'];
    if (rawQuotes is! List<Object?>) {
      throw const FormatException('quotes must be an array');
    }
    return MarketSnapshot(
      quotes: rawQuotes
          .map((rawQuote) {
            if (rawQuote is! Map<String, Object?>) {
              throw const FormatException('quote must be an object');
            }
            return MarketQuote.fromJson(rawQuote);
          })
          .toList(growable: false),
      publicationHeading: _jsonString(json, 'publicationHeading'),
      publishedDateLabel: _jsonString(json, 'publishedDateLabel'),
      fetchedAt: DateTime.parse(_jsonString(json, 'fetchedAt')).toUtc(),
      providerName: _jsonString(json, 'providerName'),
      providerUrl: Uri.parse(_jsonString(json, 'providerUrl')),
    );
  }
}

enum MarketFailureKind { network, serviceUnavailable, invalidData, unknown }

final class MarketFailure {
  const MarketFailure(this.kind);

  final MarketFailureKind kind;
}

String _jsonString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('$key must be a string');
  return value;
}

num _jsonNumber(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('$key must be a number');
  return value;
}
