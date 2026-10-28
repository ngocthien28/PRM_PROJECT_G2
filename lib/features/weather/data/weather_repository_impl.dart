import 'models/weather_forecast.dart';
import 'open_meteo_service.dart';
import 'weather_repository.dart';

class WeatherRepositoryImpl implements WeatherRepository {
  WeatherRepositoryImpl({OpenMeteoService? service})
      : _service = service ?? OpenMeteoService();

  final OpenMeteoService _service;
  WeatherForecast? _cachedForecast;
  DateTime? _lastFetchTime;
  static const Duration _cacheDuration = Duration(minutes: 15);

  @override
  Future<WeatherForecast> getCurrentWeather({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedForecast != null &&
        _lastFetchTime != null &&
        now.difference(_lastFetchTime!) < _cacheDuration) {
      return _cachedForecast!;
    }

    try {
      final fresh = await _service.getForecast();
      _cachedForecast = fresh;
      _lastFetchTime = now;
      return fresh;
    } catch (_) {
      if (_cachedForecast != null) {
        return _cachedForecast!;
      }
      return WeatherForecast.fallback();
    }
  }
}
