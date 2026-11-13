import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../format.dart';
import 'common.dart';

/// Próximas 24 h: hora, ícone, temperatura média e barra de chuva.
class HourlyStrip extends StatelessWidget {
  const HourlyStrip(this.hours, {super.key});
  final List<HourPoint> hours;

  static const _barMax = 34.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (hours.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text('Sem dados horários.', style: theme.textTheme.bodyMedium),
      );
    }
    final maxRain = hours
        .map((h) => h.precip ?? 0)
        .fold<double>(0, (a, b) => a > b ? a : b);
    // Escala mínima de 2 mm para que garoa não vire barra gigante.
    final scale = maxRain < 2 ? 2.0 : maxRain;

    return SizedBox(
      height: 152,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        itemCount: hours.length,
        itemBuilder: (context, i) {
          final h = hours[i];
          final rain = h.precip ?? 0;
          final barH = rain < 0.05
              ? 3.0
              : (rain / scale * _barMax).clamp(5.0, _barMax);
          final night = h.time.hour < 5 || h.time.hour >= 18;
          return SizedBox(
            width: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  i == 0 ? 'Agora' : hourLabel(h.time),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: i == 0 ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                WeatherIcon(h.weatherCode ?? 3, size: 22, night: night),
                Text(
                  fmtTemp(h.temp),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  height: _barMax,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: 8,
                      height: barH,
                      decoration: BoxDecoration(
                        color: rain < 0.05
                            ? theme.colorScheme.outlineVariant
                            : theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                Text(
                  rain < 0.05
                      ? ' '
                      : rain.toStringAsFixed(1).replaceAll('.', ','),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
