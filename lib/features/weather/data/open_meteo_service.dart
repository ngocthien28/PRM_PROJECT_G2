import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models/weather_forecast.dart';

/// Service calling Open-Meteo API for real-time weather & multi-day forecast.
class OpenMeteoService {
  OpenMeteoService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _baseUrl = 'https://api.open-meteo.com/v1/forecast';

  /// Fetches weather for campus coordinates (defaults to Can Tho campus: 10.0452, 105.7469).
  Future<WeatherForecast> getForecast({
    double latitude = 10.0452,
    double longitude = 105.7469,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'current':
            'temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m',
        'daily':
            'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
        'timezone': 'auto',
      },
    );

    try {
      final response = await _client.get(uri).timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return WeatherForecast.fromJson(data);
      }
      debugPrint(
        'Open-Meteo returned status ${response.statusCode}: ${response.body}',
      );
      return WeatherForecast.fallback();
    } on TimeoutException {
      debugPrint('Open-Meteo request timed out.');
      return WeatherForecast.fallback();
    } on SocketException catch (e) {
      debugPrint('Open-Meteo network unreachable: $e');
      return WeatherForecast.fallback();
    } catch (e, stack) {
      debugPrint('Open-Meteo unexpected error: $e\n$stack');
      return WeatherForecast.fallback();
    }
  }
}
