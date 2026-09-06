/// One manually selectable Nepal forecast location.
///
/// Coordinates are city-centre points, not a farmer's exact field. Keeping the
/// choice explicit avoids requesting location permission and makes the
/// forecast's geographic precision visible to the farmer.
final class NepalWeatherLocation {
  const NepalWeatherLocation({
    required this.id,
    required this.names,
    required this.latitude,
    required this.longitude,
  });

  final String id;
  final Map<String, String> names;
  final double latitude;
  final double longitude;

  String nameFor(String languageCode) =>
      names[languageCode] ?? names['en'] ?? id;
}

/// Presets span all seven provinces. They are intentionally city-level rather
/// than pretending a gridded forecast is field-level measurement.
abstract final class NepalWeatherPresets {
  static const NepalWeatherLocation kathmandu = NepalWeatherLocation(
    id: 'kathmandu',
    names: {'en': 'Kathmandu', 'ne': 'काठमाडौं', 'hi': 'काठमांडू'},
    latitude: 27.7172,
    longitude: 85.3240,
  );

  static const List<NepalWeatherLocation> all = [
    NepalWeatherLocation(
      id: 'biratnagar',
      names: {'en': 'Biratnagar', 'ne': 'विराटनगर', 'hi': 'विराटनगर'},
      latitude: 26.4525,
      longitude: 87.2718,
    ),
    NepalWeatherLocation(
      id: 'janakpurdham',
      names: {'en': 'Janakpurdham', 'ne': 'जनकपुरधाम', 'hi': 'जनकपुरधाम'},
      latitude: 26.7288,
      longitude: 85.9258,
    ),
    kathmandu,
    NepalWeatherLocation(
      id: 'pokhara',
      names: {'en': 'Pokhara', 'ne': 'पोखरा', 'hi': 'पोखरा'},
      latitude: 28.2096,
      longitude: 83.9856,
    ),
    NepalWeatherLocation(
      id: 'butwal',
      names: {'en': 'Butwal', 'ne': 'बुटवल', 'hi': 'बुटवल'},
      latitude: 27.7006,
      longitude: 83.4484,
    ),
    NepalWeatherLocation(
      id: 'birendranagar',
      names: {
        'en': 'Birendranagar',
        'ne': 'वीरेन्द्रनगर',
        'hi': 'वीरेन्द्रनगर',
      },
      latitude: 28.6019,
      longitude: 81.6339,
    ),
    NepalWeatherLocation(
      id: 'dhangadhi',
      names: {'en': 'Dhangadhi', 'ne': 'धनगढी', 'hi': 'धनगढ़ी'},
      latitude: 28.7010,
      longitude: 80.5898,
    ),
  ];

  static const NepalWeatherLocation defaultLocation = kathmandu;

  static NepalWeatherLocation? byId(String id) {
    for (final location in all) {
      if (location.id == id) return location;
    }
    return null;
  }
}

enum WeatherCondition {
  clear,
  partlyCloudy,
  fog,
  drizzle,
  rain,
  snow,
  showers,
  thunderstorm,
  unknown,
}

/// Converts World Meteorological Organization weather interpretation codes.
WeatherCondition weatherConditionFromWmo(int code) => switch (code) {
  0 || 1 => WeatherCondition.clear,
  2 || 3 => WeatherCondition.partlyCloudy,
  45 || 48 => WeatherCondition.fog,
  51 || 53 || 55 || 56 || 57 => WeatherCondition.drizzle,
  61 || 63 || 65 || 66 || 67 => WeatherCondition.rain,
  71 || 73 || 75 || 77 => WeatherCondition.snow,
  80 || 81 || 82 || 85 || 86 => WeatherCondition.showers,
  95 || 96 || 99 => WeatherCondition.thunderstorm,
  _ => WeatherCondition.unknown,
};

final class CurrentWeather {
  const CurrentWeather({
    required this.observedAt,
    required this.temperatureC,
    required this.relativeHumidityPercent,
    required this.windSpeedKmh,
    required this.condition,
  });

  final DateTime observedAt;
  final double temperatureC;
  final int relativeHumidityPercent;
  final double windSpeedKmh;
  final WeatherCondition condition;
}

final class DailyWeatherForecast {
  const DailyWeatherForecast({
    required this.date,
    required this.condition,
    required this.minimumTemperatureC,
    required this.maximumTemperatureC,
    required this.precipitationSumMm,
    required this.maximumWindSpeedKmh,
    this.precipitationProbabilityPercent,
  });

  /// Calendar date in the provider's Nepal timezone. Time-of-day is ignored.
  final DateTime date;
  final WeatherCondition condition;
  final double minimumTemperatureC;
  final double maximumTemperatureC;
  final int? precipitationProbabilityPercent;
  final double precipitationSumMm;
  final double maximumWindSpeedKmh;
}

final class WeatherSnapshot {
  const WeatherSnapshot({
    required this.location,
    required this.current,
    required this.daily,
    required this.fetchedAt,
    required this.providerName,
    required this.providerUrl,
  });

  static const Duration freshnessWindow = Duration(hours: 3);

  final NepalWeatherLocation location;
  final CurrentWeather current;
  final List<DailyWeatherForecast> daily;
  final DateTime fetchedAt;
  final String providerName;
  final Uri providerUrl;

  bool isStaleAt(DateTime now) =>
      now.toUtc().difference(current.observedAt.toUtc()) > freshnessWindow;
}

enum WeatherFailureKind { network, serviceUnavailable, invalidData, unknown }

final class WeatherFailure {
  const WeatherFailure(this.kind);

  final WeatherFailureKind kind;
}
