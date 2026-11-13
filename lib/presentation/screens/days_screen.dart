import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/models.dart';
import '../../domain/time_utils.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../widgets/report_view.dart';
import 'day_detail_screen.dart';

class DaysScreen extends StatelessWidget {
  const DaysScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ReportView(
        builder: (context, report, c) {
          final today = wallClock(DateTime.now(), report.utcOffset);
          final theme = Theme.of(context);
          final n = report.days.length;
          final children = <Widget>[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Próximos $n dias',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${c.city.name} · média de ECMWF, ICON e GFS',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ];
          for (var i = 0; i < n; i++) {
            if (i == AppConstants.longRangeFromDayIndex) {
              children.add(
                const Padding(
                  padding: EdgeInsets.fromLTRB(0, 14, 0, 0),
                  child: SectionLabel('Longo prazo · incerteza maior'),
                ),
              );
            }
            children.add(_DayCard(day: report.days[i], today: today));
            if (i < n - 1) children.add(const SizedBox(height: 10));
          }
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: children,
          );
        },
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({required this.day, required this.today});
  final DayForecast day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => DayDetailScreen(day: day, today: today),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
          child: Row(
            children: [
              WeatherIcon(day.weatherCode, size: 34),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayTitle(day.date, today),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      day.models.length < AppConstants.forecastModels.length
                          ? '${dayShortDate(day.date)} · ${day.models.length} modelos'
                          : dayShortDate(day.date),
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.water_drop_outlined,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${day.probabilityIsEstimate ? '~' : ''}${fmtPct(day.rainProbability)}  ·  ${fmtMm(day.precipMean)}',
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: fmtTemp(day.tMax),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        TextSpan(
                          text: '  ${fmtTemp(day.tMin)}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  ConfidenceBadge(day.confidence.level, compact: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
