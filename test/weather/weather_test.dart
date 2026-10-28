import 'dart:convert';
import 'package:campushub/features/weather/data/models/weather_forecast.dart';
import 'package:campushub/features/weather/data/open_meteo_service.dart';
import 'package:campushub/features/weather/data/weather_repository_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('UC-027: OpenMeteoService & Weather Models', () {
    test('parses open meteo response correctly', () {
      final sampleJson = {
        'current': {
          'temperature_2m': 29.5,
          'relative_humidity_2m': 65,
          'weather_code': 0,
          'wind_speed_10m': 12.3,
        },
        'daily': {
          'time': ['2026-10-28', '2026-10-29'],
          'weather_code': [0, 61],
          'temperature_2m_max': [33.0, 31.0],
          'temperature_2m_min': [24.0, 23.0],
          'precipitation_probability_max': [5, 70],
        },
      };

      final forecast = WeatherForecast.fromJson(sampleJson);
      expect(forecast.temperature, 29.5);
      expect(forecast.humidity, 65);
      expect(forecast.windSpeed, 12.3);
      expect(forecast.weatherCode, 0);
      expect(forecast.condition, 'Clear sky');
      expect(forecast.isFallback, isFalse);
      expect(forecast.daily.length, 2);
      expect(forecast.daily.first.tempMax, 33.0);
      expect(forecast.outdoorAdvisory, contains('Great weather'));
    });

    test('fallback weather provides safe default values', () {
      final fallback = WeatherForecast.fallback();
      expect(fallback.isFallback, isTrue);
      expect(fallback.temperature, greaterThan(20));
      expect(fallback.daily.isNotEmpty, isTrue);
    });

    test('OpenMeteoService returns fallback on client exception', () async {
      final mockClient = MockHttpClient();
      when(() => mockClient.get(any())).thenThrow(Exception('Network error'));

      final service = OpenMeteoService(client: mockClient);
      final forecast = await service.getForecast();
      expect(forecast.isFallback, isTrue);
    });

    test('OpenMeteoService returns parsed forecast on 200 OK', () async {
      final mockClient = MockHttpClient();
      final body = jsonEncode({
        'current': {
          'temperature_2m': 30.0,
          'relative_humidity_2m': 70,
          'weather_code': 1,
          'wind_speed_10m': 8.0,
        },
        'daily': {
          'time': ['2026-10-28'],
          'weather_code': [1],
          'temperature_2m_max': [32.0],
          'temperature_2m_min': [25.0],
          'precipitation_probability_max': [10],
        },
      });
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(body, 200));

      final service = OpenMeteoService(client: mockClient);
      final forecast = await service.getForecast();
      expect(forecast.isFallback, isFalse);
      expect(forecast.temperature, 30.0);
    });
  });

  group('UC-087: WeatherRepositoryImpl caching', () {
    test('reuses cached forecast when within TTL', () async {
      final mockClient = MockHttpClient();
      final body = jsonEncode({
        'current': {
          'temperature_2m': 28.0,
          'relative_humidity_2m': 75,
          'weather_code': 2,
          'wind_speed_10m': 10.0,
        },
        'daily': {'time': []},
      });
      when(
        () => mockClient.get(any()),
      ).thenAnswer((_) async => http.Response(body, 200));

      final service = OpenMeteoService(client: mockClient);
      final repo = WeatherRepositoryImpl(service: service);

      final first = await repo.getCurrentWeather();
      final second = await repo.getCurrentWeather();
      expect(first.temperature, 28.0);
      expect(second.temperature, 28.0);
      verify(() => mockClient.get(any())).called(1);
    });
  });
}
