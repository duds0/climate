import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../domain/models.dart';
import '../../domain/weather_code.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({super.key, required this.day, required this.today});
  final DayForecast day;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final desc = day.iconFromProbability
        ? 'Chuva provável'
        : weatherDescription(day.weatherCode);

    return Scaffold(
      appBar: AppBar(title: Text(dayLongDate(day.date))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // Cabeçalho
          Row(
            children: [
              WeatherIcon(day.weatherCode, size: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: fmtTemp(day.tMax),
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                          TextSpan(
                            text: '  ${fmtTemp(day.tMin)}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: muted,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      desc,
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: ConfidenceBadge(day.confidence.level),
          ),
          const SizedBox(height: 24),

          const SectionLabel('Resumo do cruzamento'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _Summary(day: day),
            ),
          ),
          const SizedBox(height: 24),

          const SectionLabel('Por modelo'),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
              child: _ModelTable(day: day),
            ),
          ),
          if (day.models.length < AppConstants.forecastModels.length) ...[
            const SizedBox(height: 10),
            InfoBanner(
              icon: Icons.info_outline,
              text:
                  'Só ${day.models.length} de ${AppConstants.forecastModels.length} '
                  'modelos chegam a este dia. Quanto mais distante a data, '
                  'menor a precisão.'
                  '${day.confidence.limitedByCoverage ? ' A confiança fica limitada a média.' : ''}',
            ),
          ],
          const SizedBox(height: 24),

          if (day.ensemble != null) ...[
            const SectionLabel('Chance de chuva por modelo (ensemble)'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: _EnsembleBars(day: day),
              ),
            ),
            const SizedBox(height: 24),
          ],

          const SectionLabel('Sobre a confiança'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: _ConfidenceExplanation(day: day),
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.detail});
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (detail != null)
                  Text(
                    detail!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _range(Range? r, String Function(double) f) =>
    r == null ? '' : 'entre modelos: ${f(r.min)} a ${f(r.max)}';

class _Summary extends StatelessWidget {
  const _Summary({required this.day});
  final DayForecast day;

  @override
  Widget build(BuildContext context) {
    final probDetail = day.probabilityIsEstimate
        ? 'estimativa: ${day.modelsWithRain} de ${day.modelsWithPrecipData} modelos (ensemble indisponível)'
        : '${day.ensemble!.withRain} de ${day.ensemble!.total} simulações do ensemble';
    return Column(
      children: [
        _Row(
          'Máxima',
          fmtTemp(day.tMax),
          detail: _range(day.tMaxRange, (v) => fmtTemp(v)),
        ),
        const Divider(),
        _Row(
          'Mínima',
          fmtTemp(day.tMin),
          detail: _range(day.tMinRange, (v) => fmtTemp(v)),
        ),
        const Divider(),
        _Row(
          'Chuva',
          fmtMm(day.precipMean),
          detail: day.precipRange == null
              ? null
              : '${_range(day.precipRange, fmtMm)}\n'
                    '${day.modelsWithRain} de ${day.modelsWithPrecipData} modelos preveem chuva '
                    '(≥ ${AppConstants.rainThresholdMm.toStringAsFixed(0)} mm)',
        ),
        const Divider(),
        _Row(
          'Probabilidade',
          day.probabilityIsEstimate
              ? '~${fmtPct(day.rainProbability)}'
              : fmtPct(day.rainProbability),
          detail: probDetail,
        ),
        const Divider(),
        _Row('Vento máx.', fmtWind(day.wind)),
      ],
    );
  }
}

class _ModelTable extends StatelessWidget {
  const _ModelTable({required this.day});
  final DayForecast day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6,
    );
    final cell = theme.textTheme.bodyMedium;

    TableRow row(List<Widget> cells) => TableRow(
      children: [
        for (final c in cells)
          Padding(padding: const EdgeInsets.symmetric(vertical: 9), child: c),
      ],
    );
    Widget t(String s, {TextStyle? style, TextAlign align = TextAlign.end}) =>
        Text(s, textAlign: align, style: style ?? cell);

    final models = [...day.models]
      ..sort((a, b) => modelLabel(a.model).compareTo(modelLabel(b.model)));

    return Table(
      columnWidths: const {0: FlexColumnWidth(1.4)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        row([
          t('MODELO', style: head, align: TextAlign.start),
          t('MÁX', style: head),
          t('MÍN', style: head),
          t('CHUVA', style: head),
          t('VENTO', style: head),
        ]),
        for (final m in models)
          row([
            t(
              modelLabel(m.model),
              style: cell?.copyWith(fontWeight: FontWeight.w600),
              align: TextAlign.start,
            ),
            t(fmtTemp(m.tMax)),
            t(fmtTemp(m.tMin)),
            t(
              fmtMm(m.precip),
              style: cell?.copyWith(
                color: (m.precip ?? 0) >= AppConstants.rainThresholdMm
                    ? theme.colorScheme.primary
                    : null,
                fontWeight: (m.precip ?? 0) >= AppConstants.rainThresholdMm
                    ? FontWeight.w600
                    : null,
              ),
            ),
            t(m.wind == null ? '–' : '${m.wind!.round()}'),
          ]),
        TableRow(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          children: [
            for (final s in [
              ('MÉDIA', TextAlign.start),
              (fmtTemp(day.tMax), TextAlign.end),
              (fmtTemp(day.tMin), TextAlign.end),
              (fmtMm(day.precipMean), TextAlign.end),
              (day.wind == null ? '–' : '${day.wind!.round()}', TextAlign.end),
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Text(
                  s.$1,
                  textAlign: s.$2,
                  style: cell?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _EnsembleBars extends StatelessWidget {
  const _EnsembleBars({required this.day});
  final DayForecast day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ens = day.ensemble!;
    final entries = ens.byModel.values.toList()
      ..sort((a, b) => modelLabel(a.key).compareTo(modelLabel(b.key)));
    return Column(
      children: [
        for (final m in entries) ...[
          Row(
            children: [
              SizedBox(
                width: 64,
                child: Text(
                  modelLabel(m.key),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: m.probability,
                    minHeight: 10,
                    backgroundColor: theme.colorScheme.surfaceContainer,
                  ),
                ),
              ),
              SizedBox(
                width: 52,
                child: Text(
                  fmtPct(m.probability),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 64, top: 2, bottom: 12),
            child: Text(
              '${m.withRain} de ${m.members} membros · média ${fmtMm(m.meanMm)}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        Text(
          'Total: ${ens.withRain} de ${ens.total} simulações passam de '
          '${AppConstants.rainThresholdMm.toStringAsFixed(0)} mm → ${fmtPct(ens.probability)}.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ConfidenceExplanation extends StatelessWidget {
  const _ConfidenceExplanation({required this.day});
  final DayForecast day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = day.confidence;

    Widget line(Confidence level, String title, String text) {
      final color = level.color(theme.brightness);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 12),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$title · ${level.label}\n',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text: text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final tempText = c.singleModel || c.tempSpread == null
        ? 'Só um modelo disponível: não dá para medir a divergência.'
        : 'Os modelos diferem em até ${c.tempSpread!.toStringAsFixed(1).replaceAll('.', ',')} °C '
              '(até 2 °C = alta, até 4 °C = média).';

    final rainText = StringBuffer(
      c.modelsAgreeOnRain
          ? 'Os modelos concordam sobre haver ou não chuva.'
          : 'Os modelos divergem: ${day.modelsWithRain} de ${day.modelsWithPrecipData} preveem chuva.',
    );
    if (c.probabilityUncertain) {
      rainText.write(
        ' A probabilidade entre 30% e 70% reduz a confiança em um nível.',
      );
    }

    return Column(
      children: [
        line(c.temperature, 'Temperatura', tempText),
        line(c.rain, 'Chuva', rainText.toString()),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'A confiança do dia é a pior das duas. Dias mais distantes tendem a ter confiança menor.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
