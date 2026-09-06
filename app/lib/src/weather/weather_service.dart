import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'weather_models.dart';

abstract interface class WeatherService {
  Future<WeatherSnapshot> fetch(NepalWeatherLocation location);
}

final class WeatherServiceException implements Exception {
  const WeatherServiceException(this.kind);

  final WeatherFailureKind kind;
}

/// Live Open-Meteo forecast adapter.
///
/// The public endpoint needs no credential. The client is injected for tests
/// and for a future backend proxy if traffic or commercial terms require one.
final class OpenMeteoWeatherService implements WeatherService {
  OpenMeteoWeatherService({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? Uri.https('api.open-meteo.com', '/v1/forecast');

  static final Uri providerUrl = Uri(scheme: 'https', host: 'open-meteo.com');
  static const Duration _timeout = Duration(seconds: 12);

  final http.Client _client;
  final Uri _endpoint;

  @override
  Future<WeatherSnapshot> fetch(NepalWeatherLocation location) async {
    final uri = _endpoint.replace(
      queryParameters: {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'current': [
          'temperature_2m',
          'relative_humidity_2m',
          'weather_code',
          'wind_speed_10m',
        ].join(','),
        'daily': [
          'weather_code',
          'temperature_2m_max',
          'temperature_2m_min',
          'precipitation_sum',
          'precipitation_probability_max',
          'wind_speed_10m_max',
        ].join(','),
        'timezone': 'Asia/Kathmandu',
        'forecast_days': '7',
      },
    );

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(_timeout);
    } on TimeoutException {
      throw const WeatherServiceException(WeatherFailureKind.network);
    } on SocketException {
      throw const WeatherServiceException(WeatherFailureKind.network);
    } on http.ClientException {
      throw const WeatherServiceException(WeatherFailureKind.network);
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const WeatherServiceException(
        WeatherFailureKind.serviceUnavailable,
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('forecast must be an object');
      }
      return _parse(decoded, location, DateTime.now().toUtc());
    } on WeatherServiceException {
      rethrow;
    } on Object {
      throw const WeatherServiceException(WeatherFailureKind.invalidData);
    }
  }

  WeatherSnapshot _parse(
    Map<String, Object?> json,
    NepalWeatherLocation location,
    DateTime fetchedAt,
  ) {
    final utcOffsetSeconds = _number(json, 'utc_offset_seconds').toInt();
    final currentJson = _object(json, 'current');
    final dailyJson = _object(json, 'daily');

    final dates = _list(dailyJson, 'time');
    final weatherCodes = _list(dailyJson, 'weather_code');
    final maximums = _list(dailyJson, 'temperature_2m_max');
    final minimums = _list(dailyJson, 'temperature_2m_min');
    final precipitation = _list(dailyJson, 'precipitation_sum');
    final probability = _list(dailyJson, 'precipitation_probability_max');
    final wind = _list(dailyJson, 'wind_speed_10m_max');
    final lists = [
      weatherCodes,
      maximums,
      minimums,
      precipitation,
      probability,
      wind,
    ];
    if (dates.isEmpty || lists.any((values) => values.length != dates.length)) {
      throw const FormatException('daily arrays have different lengths');
    }

    final daily = <DailyWeatherForecast>[];
    for (var index = 0; index < dates.length; index++) {
      final rawDate = dates[index];
      if (rawDate is! String) {
        throw const FormatException('daily date is not a string');
      }
      final parsedDate = DateTime.parse(rawDate);
      final rawProbability = probability[index];
      final minimum = _temperature(_listNumber(minimums[index]));
      final maximum = _temperature(_listNumber(maximums[index]));
      if (minimum > maximum) {
        throw const FormatException('daily minimum exceeds maximum');
      }
      daily.add(
        DailyWeatherForecast(
          date: DateTime.utc(parsedDate.year, parsedDate.month, parsedDate.day),
          condition: weatherConditionFromWmo(
            _listNumber(weatherCodes[index]).toInt(),
          ),
          minimumTemperatureC: minimum,
          maximumTemperatureC: maximum,
          precipitationProbabilityPercent: rawProbability == null
              ? null
              : _percentage(_listNumber(rawProbability)),
          precipitationSumMm: _nonNegative(
            _listNumber(precipitation[index]),
            'daily precipitation',
          ),
          maximumWindSpeedKmh: _nonNegative(
            _listNumber(wind[index]),
            'daily wind',
          ),
        ),
      );
    }

    return WeatherSnapshot(
      location: location,
      current: CurrentWeather(
        observedAt: _providerTimeToUtc(
          _string(currentJson, 'time'),
          utcOffsetSeconds,
        ),
        temperatureC: _temperature(_number(currentJson, 'temperature_2m')),
        relativeHumidityPercent: _percentage(
          _number(currentJson, 'relative_humidity_2m'),
        ),
        windSpeedKmh: _nonNegative(
          _number(currentJson, 'wind_speed_10m'),
          'current wind',
        ),
        condition: weatherConditionFromWmo(
          _number(currentJson, 'weather_code').toInt(),
        ),
      ),
      daily: List.unmodifiable(daily),
      fetchedAt: fetchedAt,
      providerName: 'Open-Meteo',
      providerUrl: providerUrl,
    );
  }

  static DateTime _providerTimeToUtc(String value, int offsetSeconds) {
    final local = DateTime.parse(value);
    final wallClockAsUtc = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
    return wallClockAsUtc.subtract(Duration(seconds: offsetSeconds));
  }

  static Map<String, Object?> _object(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! Map<String, Object?>) {
      throw FormatException('$key must be an object');
    }
    return value;
  }

  static List<Object?> _list(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! List<Object?>) {
      throw FormatException('$key must be an array');
    }
    return value;
  }

  static num _number(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! num) throw FormatException('$key must be a number');
    return value;
  }

  static num _listNumber(Object? value) {
    if (value is! num) throw const FormatException('value must be a number');
    return value;
  }

  static double _temperature(num value) {
    final temperature = value.toDouble();
    if (!temperature.isFinite || temperature < -90 || temperature > 60) {
      throw const FormatException('temperature is outside a plausible range');
    }
    return temperature;
  }

  static double _nonNegative(num value, String name) {
    final result = value.toDouble();
    if (!result.isFinite || result < 0) {
      throw FormatException('$name must be a finite non-negative number');
    }
    return result;
  }

  static int _percentage(num value) {
    final percentage = value.toDouble();
    if (!percentage.isFinite || percentage < 0 || percentage > 100) {
      throw const FormatException('percentage must be between 0 and 100');
    }
    return percentage.round();
  }

  static String _string(Map<String, Object?> json, String key) {
    final value = json[key];
    if (value is! String) throw FormatException('$key must be a string');
    return value;
  }
}
