class DailyWeather {
  const DailyWeather({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationProbability,
  });

  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final int precipitationProbability;

  String get conditionText => WeatherForecast.descriptionForCode(weatherCode);
}

class WeatherForecast {
  const WeatherForecast({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
    required this.weatherCode,
    required this.condition,
    required this.outdoorAdvisory,
    required this.daily,
    required this.fetchedAt,
    this.isFallback = false,
  });

  final double temperature;
  final int humidity;
  final double windSpeed;
  final int weatherCode;
  final String condition;
  final String outdoorAdvisory;
  final List<DailyWeather> daily;
  final DateTime fetchedAt;
  final bool isFallback;

  static String descriptionForCode(int code) {
    return switch (code) {
      0 => 'Clear sky',
      1 => 'Mainly clear',
      2 => 'Partly cloudy',
      3 => 'Overcast',
      45 || 48 => 'Foggy',
      51 || 53 || 55 => 'Light drizzle',
      61 || 63 => 'Light rain',
      65 => 'Heavy rain',
      80 || 81 || 82 => 'Rain showers',
      95 || 96 || 99 => 'Thunderstorms',
      _ => 'Mild sunshine',
    };
  }

  static String advisoryFor(int code, int precipitationProbability) {
    if (code >= 95) {
      return 'Thunderstorm warning: Move planned activities indoors.';
    }
    if (code >= 60 || precipitationProbability >= 60) {
      return 'Rain is likely ($precipitationProbability%). Bring an umbrella and prepare an indoor event plan.';
    }
    if (code >= 51 || precipitationProbability >= 30) {
      return 'Scattered light rain is possible. Bring a raincoat or umbrella.';
    }
    return 'Great weather for outdoor events and campus activities.';
  }

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final dailyJson = json['daily'] as Map<String, dynamic>? ?? {};

    final temp = (current['temperature_2m'] as num?)?.toDouble() ?? 28.0;
    final humidity = (current['relative_humidity_2m'] as num?)?.toInt() ?? 70;
    final wind = (current['wind_speed_10m'] as num?)?.toDouble() ?? 10.0;
    final code = (current['weather_code'] as num?)?.toInt() ?? 0;

    final dates = (dailyJson['time'] as List<dynamic>?) ?? [];
    final codes = (dailyJson['weather_code'] as List<dynamic>?) ?? [];
    final maxTemps = (dailyJson['temperature_2m_max'] as List<dynamic>?) ?? [];
    final minTemps = (dailyJson['temperature_2m_min'] as List<dynamic>?) ?? [];
    final precip =
        (dailyJson['precipitation_probability_max'] as List<dynamic>?) ?? [];

    final dailyList = <DailyWeather>[];
    for (int i = 0; i < dates.length && i < 7; i++) {
      final dateStr = dates[i]?.toString();
      final parsedDate = dateStr != null
          ? DateTime.tryParse(dateStr) ?? DateTime.now()
          : DateTime.now();
      dailyList.add(
        DailyWeather(
          date: parsedDate,
          weatherCode: i < codes.length ? (codes[i] as num).toInt() : code,
          tempMax: i < maxTemps.length
              ? (maxTemps[i] as num).toDouble()
              : temp + 2,
          tempMin: i < minTemps.length
              ? (minTemps[i] as num).toDouble()
              : temp - 3,
          precipitationProbability: i < precip.length
              ? (precip[i] as num).toInt()
              : 10,
        ),
      );
    }

    final maxPrecip = dailyList.isNotEmpty
        ? dailyList.first.precipitationProbability
        : 10;

    return WeatherForecast(
      temperature: temp,
      humidity: humidity,
      windSpeed: wind,
      weatherCode: code,
      condition: descriptionForCode(code),
      outdoorAdvisory: advisoryFor(code, maxPrecip),
      daily: dailyList,
      fetchedAt: DateTime.now(),
      isFallback: false,
    );
  }

  factory WeatherForecast.fallback() => WeatherForecast(
    temperature: 28.5,
    humidity: 72,
    windSpeed: 11.0,
    weatherCode: 1,
    condition: 'Partly cloudy',
    outdoorAdvisory:
        'Stable conditions for classes, campus activities, and outdoor events.',
    daily: List.generate(
      5,
      (i) => DailyWeather(
        date: DateTime.now().add(Duration(days: i)),
        weatherCode: 1,
        tempMax: 32.0,
        tempMin: 25.0,
        precipitationProbability: 15,
      ),
    ),
    fetchedAt: DateTime.now(),
    isFallback: true,
  );
}
