import 'models/weather_forecast.dart';

/// Repository contract for weather information and forecast details.
abstract interface class WeatherRepository {
  /// Retrieves current weather and forecast for the campus.
  Future<WeatherForecast> getCurrentWeather({bool forceRefresh = false});
}
