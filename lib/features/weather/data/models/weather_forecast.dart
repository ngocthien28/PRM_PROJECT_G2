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
      0 => 'Trời quang đãng',
      1 => 'Ít mây',
      2 => 'Mây rải rác',
      3 => 'Trời nhiều mây',
      45 || 48 => 'Có sương mù',
      51 || 53 || 55 => 'Mưa phùn nhẹ',
      61 || 63 => 'Mưa rào nhẹ',
      65 => 'Mưa lớn',
      80 || 81 || 82 => 'Mưa rào',
      95 || 96 || 99 => 'Có dông sét',
      _ => 'Nắng dịu',
    };
  }

  static String advisoryFor(int code, int precipitationProbability) {
    if (code >= 95) {
      return 'Cảnh báo dông sét: Khuyến nghị chuyển các hoạt động vào trong nhà.';
    }
    if (code >= 60 || precipitationProbability >= 60) {
      return 'Khả năng có mưa ($precipitationProbability%): Nên chuẩn bị ô/dù và phương án sự kiện trong nhà.';
    }
    if (code >= 51 || precipitationProbability >= 30) {
      return 'Có thể có mưa nhẹ rải rác: Hãy mang theo áo mưa hoặc mũ nón.';
    }
    return 'Thời tiết lý tưởng: Rất thuận lợi cho các sự kiện và hoạt động ngoài trời!';
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
      dailyList.add(DailyWeather(
        date: parsedDate,
        weatherCode: i < codes.length ? (codes[i] as num).toInt() : code,
        tempMax:
            i < maxTemps.length ? (maxTemps[i] as num).toDouble() : temp + 2,
        tempMin:
            i < minTemps.length ? (minTemps[i] as num).toDouble() : temp - 3,
        precipitationProbability:
            i < precip.length ? (precip[i] as num).toInt() : 10,
      ));
    }

    final maxPrecip =
        dailyList.isNotEmpty ? dailyList.first.precipitationProbability : 10;

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
    condition: 'Nắng dịu có mây',
    outdoorAdvisory:
        'Thời tiết ổn định, thuận lợi cho các hoạt động học tập và sự kiện khuôn viên.',
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
