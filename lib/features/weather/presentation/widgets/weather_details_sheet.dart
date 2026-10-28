import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/weather_forecast.dart';

void showWeatherDetailsSheet(BuildContext context, WeatherForecast forecast) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => WeatherDetailsSheet(forecast: forecast),
  );
}

class WeatherDetailsSheet extends StatelessWidget {
  const WeatherDetailsSheet({super.key, required this.forecast});
  final WeatherForecast forecast;

  IconData _iconForCode(int code) {
    return switch (code) {
      0 => Icons.wb_sunny_rounded,
      1 || 2 => Icons.wb_cloudy_rounded,
      3 => Icons.cloud_rounded,
      45 || 48 => Icons.foggy,
      51 || 53 || 55 => Icons.grain_rounded,
      61 || 63 || 65 || 80 || 81 || 82 => Icons.umbrella_rounded,
      95 || 96 || 99 => Icons.thunderstorm_rounded,
      _ => Icons.wb_sunny_outlined,
    };
  }

  Color _iconColorForCode(int code) {
    if (code == 0) return const Color(0xFFE6A23C);
    if (code >= 60) return const Color(0xFF409EFF);
    if (code >= 95) return const Color(0xFFF56C6C);
    return CampusColors.teal;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CAMPUS WEATHER',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w700,
                          color: CampusColors.muted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Forecast and activity advice',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close weather details',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Current Weather Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [CampusColors.ink, Color(0xFF2A4235)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    _iconForCode(forecast.weatherCode),
                    size: 54,
                    color: _iconColorForCode(forecast.weatherCode),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${forecast.temperature.toStringAsFixed(1)}°C',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          forecast.condition,
                          style: const TextStyle(
                            fontSize: 15,
                            color: CampusColors.gold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.water_drop_outlined,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${forecast.humidity}%',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.air_rounded,
                            size: 16,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${forecast.windSpeed.toStringAsFixed(0)} km/h',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Outdoor Advisory Banner (UC-087)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CampusColors.mint.withAlpha(80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: CampusColors.teal.withAlpha(120)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    color: CampusColors.teal,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Activity and event advice',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: CampusColors.ink,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          forecast.outdoorAdvisory,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: CampusColors.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Text(
              'Next days',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Daily forecast items
            ...forecast.daily.take(5).map((d) {
              final isToday =
                  d.date.day == DateTime.now().day &&
                  d.date.month == DateTime.now().month;
              final dayLabel = isToday
                  ? 'Today'
                  : '${_weekdayName(d.date.weekday)} (${d.date.day}/${d.date.month})';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Text(
                        dayLabel,
                        style: TextStyle(
                          fontWeight: isToday
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    Icon(
                      _iconForCode(d.weatherCode),
                      size: 20,
                      color: _iconColorForCode(d.weatherCode),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        d.conditionText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    if (d.precipitationProbability > 0) ...[
                      const Icon(
                        Icons.water_drop,
                        size: 14,
                        color: Color(0xFF409EFF),
                      ),
                      Text(
                        ' ${d.precipitationProbability}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF409EFF),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      '${d.tempMax.toStringAsFixed(0)}° / ${d.tempMin.toStringAsFixed(0)}°',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _weekdayName(int weekday) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][weekday - 1];
}
