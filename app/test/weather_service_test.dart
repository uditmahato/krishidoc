import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:krishidoc_app/src/weather/weather.dart';

void main() {
  group('OpenMeteoWeatherService', () {
    test('requests Nepal time and parses current and daily forecast', () async {
      Uri? requested;
      final client = MockClient((request) async {
        requested = request.url;
        return http.Response(jsonEncode(_validForecast), 200);
      });
      final service = OpenMeteoWeatherService(client: client);

      final snapshot = await service.fetch(NepalWeatherPresets.kathmandu);

      expect(requested?.queryParameters['timezone'], 'Asia/Kathmandu');
      expect(requested?.queryParameters['forecast_days'], '7');
      expect(requested?.queryParameters['current'], contains('weather_code'));
      expect(
        requested?.queryParameters['daily'],
        contains('precipitation_sum'),
      );
      expect(snapshot.location.id, 'kathmandu');
      expect(snapshot.providerName, 'Open-Meteo');
      expect(snapshot.current.temperatureC, 24.5);
      expect(snapshot.current.relativeHumidityPercent, 82);
      expect(snapshot.current.condition, WeatherCondition.partlyCloudy);
      expect(snapshot.current.observedAt, DateTime.utc(2026, 8, 4, 3, 15));
      expect(snapshot.daily, hasLength(2));
      expect(snapshot.daily.first.precipitationProbabilityPercent, 70);
      expect(snapshot.daily.first.precipitationSumMm, 12.4);
      expect(snapshot.daily.last.condition, WeatherCondition.thunderstorm);
    });

    test('maps provider failures to a safe service failure', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient((request) async => http.Response('busy', 503)),
      );

      await expectLater(
        service.fetch(NepalWeatherPresets.kathmandu),
        throwsA(
          isA<WeatherServiceException>().having(
            (error) => error.kind,
            'kind',
            WeatherFailureKind.serviceUnavailable,
          ),
        ),
      );
    });

    test('rejects malformed data rather than showing partial values', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode({
              ..._validForecast,
              'daily': {
                ...(_validForecast['daily']! as Map<String, Object?>),
                'temperature_2m_max': [28.0],
              },
            }),
            200,
          ),
        ),
      );

      await expectLater(
        service.fetch(NepalWeatherPresets.kathmandu),
        throwsA(
          isA<WeatherServiceException>().having(
            (error) => error.kind,
            'kind',
            WeatherFailureKind.invalidData,
          ),
        ),
      );
    });

    test('rejects a daily minimum above its maximum', () async {
      final service = OpenMeteoWeatherService(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(
              _withDaily(
                temperatureMinimums: [29.0, 19.8],
                temperatureMaximums: [28.0, 27.2],
              ),
            ),
            200,
          ),
        ),
      );

      await expectLater(
        service.fetch(NepalWeatherPresets.kathmandu),
        throwsA(
          isA<WeatherServiceException>().having(
            (error) => error.kind,
            'kind',
            WeatherFailureKind.invalidData,
          ),
        ),
      );
    });

    test('rejects negative rain and out-of-range probability', () async {
      for (final invalid in [
        _withDaily(precipitationSums: [-1.0, 22.0]),
        _withDaily(precipitationProbabilities: [101, 90]),
      ]) {
        final service = OpenMeteoWeatherService(
          client: MockClient(
            (request) async => http.Response(jsonEncode(invalid), 200),
          ),
        );

        await expectLater(
          service.fetch(NepalWeatherPresets.kathmandu),
          throwsA(
            isA<WeatherServiceException>().having(
              (error) => error.kind,
              'kind',
              WeatherFailureKind.invalidData,
            ),
          ),
        );
      }
    });
  });

  test('WMO codes map into farmer-readable condition groups', () {
    expect(weatherConditionFromWmo(0), WeatherCondition.clear);
    expect(weatherConditionFromWmo(63), WeatherCondition.rain);
    expect(weatherConditionFromWmo(95), WeatherCondition.thunderstorm);
    expect(weatherConditionFromWmo(999), WeatherCondition.unknown);
  });
}

const Map<String, Object?> _validForecast = {
  'utc_offset_seconds': 20700,
  'current': {
    'time': '2026-08-04T09:00',
    'temperature_2m': 24.5,
    'relative_humidity_2m': 82,
    'weather_code': 2,
    'wind_speed_10m': 8.3,
  },
  'daily': {
    'time': ['2026-08-04', '2026-08-05'],
    'weather_code': [61, 95],
    'temperature_2m_max': [28.0, 27.2],
    'temperature_2m_min': [20.1, 19.8],
    'precipitation_sum': [12.4, 22.0],
    'precipitation_probability_max': [70, 90],
    'wind_speed_10m_max': [14.2, 19.6],
  },
};

Map<String, Object?> _withDaily({
  List<double>? temperatureMaximums,
  List<double>? temperatureMinimums,
  List<double>? precipitationSums,
  List<int>? precipitationProbabilities,
}) {
  final daily = Map<String, Object?>.from(
    _validForecast['daily']! as Map<String, Object?>,
  );
  if (temperatureMaximums != null) {
    daily['temperature_2m_max'] = temperatureMaximums;
  }
  if (temperatureMinimums != null) {
    daily['temperature_2m_min'] = temperatureMinimums;
  }
  if (precipitationSums != null) {
    daily['precipitation_sum'] = precipitationSums;
  }
  if (precipitationProbabilities != null) {
    daily['precipitation_probability_max'] = precipitationProbabilities;
  }
  return {..._validForecast, 'daily': daily};
}
