// ignore_for_file: avoid_print
// Verificação ponta a ponta contra as APIs reais: dart run tool/live_check.dart
import 'dart:convert';

import 'package:clima_ipupiara/core/constants.dart';
import 'package:clima_ipupiara/data/dto.dart';
import 'package:clima_ipupiara/data/weather_api.dart';
import 'package:clima_ipupiara/domain/aggregation.dart';
import 'package:clima_ipupiara/domain/weather_code.dart';

Future<void> main() async {
  final api = WeatherApi();
  final f = ForecastDto.parse(
    jsonDecode(await api.forecastRaw()) as Map<String, dynamic>,
  );
  final e = EnsembleDto.parse(
    jsonDecode(await api.ensembleRaw()) as Map<String, dynamic>,
  );
  var alerts = <dynamic>[];
  try {
    alerts = InmetDto.parse(
      jsonDecode(await api.inmetRaw()),
      ibgeCode: AppConstants.ibgeCode,
    );
  } catch (err) {
    print('INMET falhou: $err');
  }
  final r = buildReport(forecast: f, ensemble: e, nowInstant: DateTime.now());
  print(
    'membros ensemble: ${e.totalMembers}; dias: ${r.days.length}; horas: ${r.hours.length}; alertas Ipupiara: ${alerts.length}',
  );
  print(
    'agora: ${r.current?.temperature}° ${weatherDescription(r.current?.weatherCode ?? 3)}',
  );
  for (final d in r.days) {
    print(
      '${d.date.toString().substring(0, 10)}  ${d.tMax!.toStringAsFixed(1)}/${d.tMin!.toStringAsFixed(1)}°  '
      '${d.precipMean!.toStringAsFixed(1)}mm  prob=${(d.rainProbability! * 100).round()}%  '
      'conf=${d.confidence.level.label}  cod=${d.weatherCode}  modelos=${d.models.length}',
    );
  }
  api.close();
}
