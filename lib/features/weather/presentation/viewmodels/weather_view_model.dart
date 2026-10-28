import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/weather_forecast.dart';
import '../../data/weather_repository.dart';
import '../../data/weather_repository_impl.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>(
  (ref) => WeatherRepositoryImpl(),
);

final weatherProvider = FutureProvider<WeatherForecast>((ref) async {
  final repo = ref.watch(weatherRepositoryProvider);
  return repo.getCurrentWeather();
});
