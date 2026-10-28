import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../viewmodels/weather_view_model.dart';
import 'weather_details_sheet.dart';

class WeatherBanner extends ConsumerWidget {
  const WeatherBanner({super.key});

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
  Widget build(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(weatherProvider);

    return weatherAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (forecast) => InkWell(
        onTap: () => showWeatherDetailsSheet(context, forecast),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: CampusColors.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(8),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(
                _iconForCode(forecast.weatherCode),
                color: _iconColorForCode(forecast.weatherCode),
                size: 26,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${forecast.temperature.toStringAsFixed(1)}°C • ${forecast.condition}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: CampusColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      forecast.isFallback
                          ? 'Campus weather (offline estimate)'
                          : 'Campus weather • View forecast and advice',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: CampusColors.teal,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: CampusColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
