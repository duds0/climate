import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models.dart';
import '../weather_controller.dart';
import 'common.dart';

/// Cuida de carregando / erro / pull-to-refresh e entrega o relatório pronto.
class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.builder});
  final Widget Function(
    BuildContext context,
    WeatherReport report,
    WeatherController c,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    final c = context.watch<WeatherController>();
    final report = c.report;

    if (report == null) {
      if (c.status == LoadStatus.error) {
        return ErrorState(
          message: c.lastError ?? 'Não foi possível carregar a previsão.',
          onRetry: () => c.load(force: true),
        );
      }
      return const Center(child: CircularProgressIndicator(strokeWidth: 2.5));
    }

    return RefreshIndicator(
      onRefresh: () => c.load(force: true),
      child: builder(context, report, c),
    );
  }
}
