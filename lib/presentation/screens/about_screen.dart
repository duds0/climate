import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../format.dart';
import '../widgets/common.dart';
import '../weather_controller.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final c = context.watch<WeatherController>();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Sobre',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),

          // Atualização
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Última atualização',
                    style: theme.textTheme.labelMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    c.updatedAt == null ? '–' : updatedLabel(c.updatedAt!),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (c.offline) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Sem conexão: mostrando dados salvos.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton.tonalIcon(
                    onPressed: c.refreshing ? null : () => c.load(force: true),
                    icon: c.refreshing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh),
                    label: const Text('Atualizar agora'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const SectionLabel('Como funciona'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Para(
                    'Em vez de confiar em um único número, o app cruza até três modelos '
                    'meteorológicos (ECMWF, ICON e GFS) e mostra a média, a faixa entre eles '
                    'e o quanto concordam.',
                  ),
                  _Para(
                    'A probabilidade de chuva vem de até 122 simulações (ensemble): conta quantas '
                    'passam de ${AppConstants.rainThresholdMm.toStringAsFixed(0)} mm no dia.',
                  ),
                  _Para(
                    'A confiança é Alta, Média ou Baixa e vale só para a chuva: depende de os '
                    'modelos concordarem se vai chover e de a probabilidade estar longe do meio-termo.',
                  ),
                  _Para(
                    'Depois de 7 dias o ICON deixa de cobrir e, depois de cerca de 11, o GFS '
                    'sai do ensemble: a previsão passa a depender de menos modelos e a '
                    'incerteza cresce. Use esses dias como tendência.',
                  ),
                  _Para(
                    'Alertas do INMET aparecem à parte e nunca entram na média.',
                    last: true,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const SectionLabel('Fontes'),
          Card(
            child: Column(
              children: [
                _LinkTile(
                  title: 'Dados meteorológicos: Open-Meteo.com',
                  subtitle: 'Uso não comercial · licença CC BY 4.0',
                  url: 'https://open-meteo.com/',
                ),
                const Divider(),
                _LinkTile(
                  title: 'Avisos: INMET',
                  subtitle: 'Instituto Nacional de Meteorologia',
                  url: 'https://alertas2.inmet.gov.br/',
                ),
                const Divider(),
                _LinkTile(
                  title: 'Satélite: CPTEC/INPE',
                  subtitle: 'GOES-19',
                  url: 'https://satelite.cptec.inpe.br/',
                ),
                const Divider(),
                _LinkTile(
                  title: 'Mapa: Windy.com',
                  subtitle: 'Radar e nuvens',
                  url: 'https://www.windy.com/',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '${c.city.headerLabel} · '
              '${c.city.latitude.toStringAsFixed(2)}, ${c.city.longitude.toStringAsFixed(2)}',
              style: theme.textTheme.labelSmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _Para extends StatelessWidget {
  const _Para(this.text, {this.last = false});
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12),
    child: Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
    ),
  );
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.title,
    required this.subtitle,
    required this.url,
  });
  final String title;
  final String subtitle;
  final String url;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.open_in_new, size: 18),
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
    );
  }
}
