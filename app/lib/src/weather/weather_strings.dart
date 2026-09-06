import 'weather_models.dart';

typedef WeatherValueText = String Function(String value);
typedef WeatherPercentText = String Function(int value);
typedef WeatherNumberText = String Function(String value);
typedef WeatherRangeText = String Function(String minimum, String maximum);
typedef WeatherLocationText = String Function(String location);
typedef WeatherCropDaysText =
    String Function(int days, int total, String minimum, String maximum);

/// Copy is injected so this feature can be wired to the app ARBs without
/// making the service, controller, or models depend on generated l10n code.
final class WeatherStrings {
  const WeatherStrings({
    required this.title,
    required this.location,
    required this.refresh,
    required this.retry,
    required this.loading,
    required this.currentConditions,
    required this.sevenDayForecast,
    required this.today,
    required this.humidity,
    required this.wind,
    required this.rain,
    required this.maximumWind,
    required this.staleTitle,
    required this.staleBody,
    required this.cachedAfterFailure,
    required this.networkError,
    required this.serviceError,
    required this.dataError,
    required this.unknownError,
    required this.disclaimer,
    required this.updatedAt,
    required this.provider,
    required this.rainChance,
    required this.rainAmount,
    required this.windSpeed,
    required this.temperatureRange,
    required this.cropWeatherFitTitle,
    required this.cropWeatherFitEstimate,
    required this.cropWeatherFitIntro,
    required this.cropWeatherFitFavorable,
    required this.cropWeatherFitMixed,
    required this.cropWeatherFitWeak,
    required this.cropWeatherFitInsufficient,
    required this.cropWeatherFitNotEnoughForecast,
    required this.cropWeatherPreferredDays,
    required this.cropWeatherForecastContext,
    required this.cropWeatherRainTotal,
    required this.cropWeatherPeakWind,
    required this.cropWeatherThunderstormDays,
    required this.cropWeatherLimits,
    required this.cropWeatherMethod,
    required this.cropNames,
    required this.conditions,
  });

  factory WeatherStrings.english() => WeatherStrings(
    title: 'Nepal weather',
    location: 'Forecast location',
    refresh: 'Refresh forecast',
    retry: 'Try again',
    loading: 'Getting the latest forecast…',
    currentConditions: 'Current conditions',
    sevenDayForecast: '7-day forecast',
    today: 'Today',
    humidity: 'Humidity',
    wind: 'Wind',
    rain: 'Rain',
    maximumWind: 'Maximum wind',
    staleTitle: 'Saved forecast',
    staleBody: 'This forecast is more than 3 hours old.',
    cachedAfterFailure: 'The latest update failed. Showing the last forecast.',
    networkError: 'No internet connection. Try again when you are online.',
    serviceError: 'The weather provider is unavailable right now.',
    dataError: 'The weather provider returned data this app could not read.',
    unknownError: 'The forecast could not be updated.',
    disclaimer:
        'City forecasts are estimates, not field measurements. Check official '
        'DHM warnings before weather-sensitive work.',
    updatedAt: (value) => 'Updated $value',
    provider: (value) => 'Source: $value',
    rainChance: (value) => '$value% chance',
    rainAmount: (value) => '$value mm',
    windSpeed: (value) => '$value km/h',
    temperatureRange: (minimum, maximum) => '$minimum–$maximum °C',
    cropWeatherFitTitle: '7-day crop weather fit',
    cropWeatherFitEstimate: 'Planning estimate',
    cropWeatherFitIntro: (location) =>
        'Temperature comparison for the three supported crops in $location.',
    cropWeatherFitFavorable: 'Mostly favorable',
    cropWeatherFitMixed: 'Mixed',
    cropWeatherFitWeak: 'Often outside range',
    cropWeatherFitInsufficient: 'Not enough data',
    cropWeatherFitNotEnoughForecast:
        'At least 3 forecast days are needed for this comparison.',
    cropWeatherPreferredDays: (days, total, minimum, maximum) =>
        '$days of $total days are within the preferred '
        '$minimum–$maximum °C range.',
    cropWeatherForecastContext: 'Forecast context',
    cropWeatherRainTotal: (value) => '$value mm rain',
    cropWeatherPeakWind: (value) => '$value km/h peak wind',
    cropWeatherThunderstormDays: (value) => '$value thunderstorm days',
    cropWeatherLimits:
        'Weather is only one input. Soil, drainage, elevation, irrigation, '
        'crop stage, variety, local planting calendar and market are not '
        'checked. Confirm before buying seed or changing a planting plan.',
    cropWeatherMethod: (provider) =>
        'Method: $provider forecast daily-average temperature compared with '
        'FAO EcoCrop ranges. This is not a planting or yield recommendation.',
    cropNames: const {'tomato': 'Tomato', 'potato': 'Potato', 'maize': 'Maize'},
    conditions: const {
      WeatherCondition.clear: 'Clear',
      WeatherCondition.partlyCloudy: 'Partly cloudy',
      WeatherCondition.fog: 'Fog',
      WeatherCondition.drizzle: 'Drizzle',
      WeatherCondition.rain: 'Rain',
      WeatherCondition.snow: 'Snow',
      WeatherCondition.showers: 'Showers',
      WeatherCondition.thunderstorm: 'Thunderstorm',
      WeatherCondition.unknown: 'Conditions unavailable',
    },
  );

  final String title;
  final String location;
  final String refresh;
  final String retry;
  final String loading;
  final String currentConditions;
  final String sevenDayForecast;
  final String today;
  final String humidity;
  final String wind;
  final String rain;
  final String maximumWind;
  final String staleTitle;
  final String staleBody;
  final String cachedAfterFailure;
  final String networkError;
  final String serviceError;
  final String dataError;
  final String unknownError;
  final String disclaimer;
  final WeatherValueText updatedAt;
  final WeatherValueText provider;
  final WeatherPercentText rainChance;
  final WeatherNumberText rainAmount;
  final WeatherNumberText windSpeed;
  final WeatherRangeText temperatureRange;
  final String cropWeatherFitTitle;
  final String cropWeatherFitEstimate;
  final WeatherLocationText cropWeatherFitIntro;
  final String cropWeatherFitFavorable;
  final String cropWeatherFitMixed;
  final String cropWeatherFitWeak;
  final String cropWeatherFitInsufficient;
  final String cropWeatherFitNotEnoughForecast;
  final WeatherCropDaysText cropWeatherPreferredDays;
  final String cropWeatherForecastContext;
  final WeatherNumberText cropWeatherRainTotal;
  final WeatherNumberText cropWeatherPeakWind;
  final WeatherPercentText cropWeatherThunderstormDays;
  final String cropWeatherLimits;
  final WeatherValueText cropWeatherMethod;
  final Map<String, String> cropNames;
  final Map<WeatherCondition, String> conditions;

  String condition(WeatherCondition value) =>
      conditions[value] ?? conditions[WeatherCondition.unknown] ?? '';

  String cropName(String key) => cropNames[key] ?? key;

  String failure(WeatherFailureKind kind) => switch (kind) {
    WeatherFailureKind.network => networkError,
    WeatherFailureKind.serviceUnavailable => serviceError,
    WeatherFailureKind.invalidData => dataError,
    WeatherFailureKind.unknown => unknownError,
  };
}
