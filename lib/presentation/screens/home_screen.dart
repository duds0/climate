import 'package:flutter/material.dart';

import '../../domain/models.dart';
import '../../domain/time_utils.dart';
import '../../domain/weather_code.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/alert_banner.dart';
import '../widgets/common.dart';
import '../widgets/hourly_strip.dart';
import '../widgets/report_view.dart';
import '../weather_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ReportView(
        builder: (context, report, c) => _HomeBody(report: report, c: c),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({required this.report, required this.c});
  final WeatherReport report;
  final WeatherController c;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = report.today;
    final now = wallClock(DateTime.now(), report.utcOffset);
    final cur = report.current;
    final night = now.hour < 5 || now.hour >= 18;

    final heroTemp = cur?.temperature ?? today?.tMax;
    final heroCode = cur?.weatherCode ?? today?.weatherCode ?? 3;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        // Cabeçalho
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.city.headerLabel,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    dayLongDate(now),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (c.refreshing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        const SizedBox(height: 16),

        if (c.offline || c.lastError != null) ...[
          InfoBanner(
            icon: Icons.cloud_off_outlined,
            text: c.updatedAt == null
                ? 'Sem conexão.'
                : 'Sem conexão — atualizado em ${updatedLabel(c.updatedAt!)}',
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(height: 12),
        ],

        // Hero
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              fmtTemp(heroTemp),
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 104,
                height: 1,
                fontWeight: FontWeight.w200,
                letterSpacing: -4,
              ),
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                WeatherIcon(heroCode, size: 56, night: night),
                const SizedBox(height: 6),
                Text(
                  weatherDescription(heroCode),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (today != null)
          Text(
            'Máx ${fmtTemp(today.tMax)}  ·  Mín ${fmtTemp(today.tMin)}'
            '${cur?.humidity != null ? '  ·  Umidade ${cur!.humidity!.round()}%' : ''}'
            '${cur?.windSpeed != null ? '  ·  Vento ${fmtWind(cur!.windSpeed)}' : ''}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 24),

        // Resumo do dia
        if (today != null) _TodaySummary(day: today),
        if (today?.probabilityIsEstimate ?? false) ...[
          const SizedBox(height: 10),
          InfoBanner(
            icon: Icons.info_outline,
            text:
                'Probabilidade estimada: o ensemble não está disponível agora.',
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],

        // Alertas
        if (report.alerts.isNotEmpty) ...[
          const SizedBox(height: 20),
          for (final a in report.alerts) ...[
            AlertBanner(a),
            const SizedBox(height: 10),
          ],
        ],

        // Próximas 24 h
        const SizedBox(height: 24),
        const SectionLabel('Próximas 24 horas'),
        Card(child: HourlyStrip(report.hours)),

        const SizedBox(height: 20),
        if (c.updatedAt != null)
          Center(
            child: Text(
              'Atualizado em ${updatedLabel(c.updatedAt!)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.day});
  final DayForecast day;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(
              label: 'Chuva',
              value: fmtPct(day.rainProbability),
              caption: day.probabilityIsEstimate
                  ? 'estimativa'
                  : 'probabilidade',
              icon: Icons.water_drop_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Tile(
              label: 'Volume',
              value: fmtMm(day.precipMean),
              caption: 'esperado hoje',
              icon: Icons.opacity_outlined,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _ConfidenceTile(day.confidence.level)),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.caption,
    required this.icon,
  });
  final String label;
  final String value;
  final String caption;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 15, color: theme.colorScheme.primary),
                const SizedBox(width: 5),
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfidenceTile extends StatelessWidget {
  const _ConfidenceTile(this.level);
  final Confidence level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = level.color(theme.brightness);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified_outlined, size: 15, color: color),
                const SizedBox(width: 5),
                Text(
                  'Confiança',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                capitalizeFirst(level.label),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'da chuva',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
