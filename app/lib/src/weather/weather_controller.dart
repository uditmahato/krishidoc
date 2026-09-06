import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:core_domain/core_domain.dart';

import '../providers.dart';
import 'weather_models.dart';
import 'weather_service.dart';

final weatherServiceProvider = Provider<WeatherService>(
  (ref) => OpenMeteoWeatherService(),
);

final nepalWeatherControllerProvider =
    NotifierProvider<NepalWeatherController, NepalWeatherState>(
      NepalWeatherController.new,
    );

final class NepalWeatherState {
  const NepalWeatherState({
    required this.location,
    this.snapshot,
    this.failure,
    this.isLoading = false,
  });

  factory NepalWeatherState.initial() =>
      const NepalWeatherState(location: NepalWeatherPresets.defaultLocation);

  final NepalWeatherLocation location;
  final WeatherSnapshot? snapshot;
  final WeatherFailure? failure;
  final bool isLoading;
}

final class NepalWeatherController extends Notifier<NepalWeatherState> {
  final Map<String, WeatherSnapshot> _cache = {};
  var _requestSerial = 0;
  var _hasLoaded = false;

  @override
  NepalWeatherState build() => NepalWeatherState.initial();

  Future<void> ensureLoaded() async {
    if (_hasLoaded || state.isLoading) return;
    _hasLoaded = true;
    final storedLocation = await _readStoredLocation();
    final restored = storedLocation == null
        ? null
        : NepalWeatherPresets.byId(storedLocation);
    if (restored != null) {
      state = NepalWeatherState(location: restored);
    }
    await refresh();
  }

  Future<void> selectLocation(NepalWeatherLocation location) async {
    if (location.id == state.location.id) return;
    _requestSerial++;
    final cached = _cache[location.id];
    state = NepalWeatherState(location: location, snapshot: cached);
    await _storeLocation(location.id);
    await refresh();
  }

  Future<String?> _readStoredLocation() async {
    try {
      return await ref
          .read(servicesProvider)
          .settingsStore
          .read(SettingsKeys.weatherLocation);
    } on Object {
      // Weather remains usable when settings storage is unavailable. The
      // visible Kathmandu selector is then the explicit fallback.
      return null;
    }
  }

  Future<void> _storeLocation(String id) async {
    try {
      await ref
          .read(servicesProvider)
          .settingsStore
          .write(SettingsKeys.weatherLocation, id);
    } on Object {
      // A persistence failure must not block a live forecast request.
    }
  }

  Future<void> refresh() async {
    final location = state.location;
    final cached = _cache[location.id] ?? state.snapshot;
    final request = ++_requestSerial;
    state = NepalWeatherState(
      location: location,
      snapshot: cached,
      isLoading: true,
    );

    try {
      final snapshot = await ref.read(weatherServiceProvider).fetch(location);
      if (request != _requestSerial || state.location.id != location.id) return;
      _cache[location.id] = snapshot;
      state = NepalWeatherState(location: location, snapshot: snapshot);
    } on WeatherServiceException catch (error) {
      if (request != _requestSerial || state.location.id != location.id) return;
      state = NepalWeatherState(
        location: location,
        snapshot: cached,
        failure: WeatherFailure(error.kind),
      );
    } on Object {
      if (request != _requestSerial || state.location.id != location.id) return;
      state = NepalWeatherState(
        location: location,
        snapshot: cached,
        failure: const WeatherFailure(WeatherFailureKind.unknown),
      );
    }
  }
}
