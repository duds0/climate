import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/weather_code.dart';
import '../theme.dart';

IconData weatherIconData(int code, {bool night = false}) =>
    switch (weatherKind(code)) {
      WeatherKind.clear =>
        night ? Icons.nightlight_outlined : Icons.wb_sunny_outlined,
      WeatherKind.partly =>
        night ? Icons.nights_stay_outlined : Icons.filter_drama_outlined,
      WeatherKind.cloudy => Icons.cloud_outlined,
      WeatherKind.fog => Icons.foggy,
      WeatherKind.drizzle => Icons.grain,
      WeatherKind.rain => Icons.water_drop_outlined,
      WeatherKind.showers => Icons.shower_outlined,
      WeatherKind.thunder => Icons.thunderstorm_outlined,
      WeatherKind.snow => Icons.ac_unit,
    };

class WeatherIcon extends StatelessWidget {
  const WeatherIcon(
    this.code, {
    super.key,
    this.size = 28,
    this.color,
    this.night = false,
  });
  final int code;
  final double size;
  final Color? color;
  final bool night;

  @override
  Widget build(BuildContext context) {
    return Icon(
      weatherIconData(code, night: night),
      size: size,
      color: color ?? Theme.of(context).colorScheme.primary,
    );
  }
}

/// Selo de confiança: ponto colorido + texto.
class ConfidenceBadge extends StatelessWidget {
  const ConfidenceBadge(this.level, {super.key, this.compact = false});
  final Confidence level;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = level.color(theme.brightness);
    final text = compact
        ? capitalizeFirst(level.label)
        : 'Confiança ${level.label}';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: theme.textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String capitalizeFirst(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Título de seção discreto.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Faixa informativa (offline, estimativa, erro...).
class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.icon,
    required this.text,
    this.color,
  });
  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Estado de erro com botão "Tentar novamente".
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}
