/// Entradas "cruas" do domínio, já independentes do formato JSON da API.
library;

import 'models.dart';

/// Previsão determinística multimodelo.
class ForecastInput {
  const ForecastInput({
    required this.dates,
    required this.dailyByModel,
    required this.hourlyTimes,
    required this.hourlyTemp,
    required this.hourlyPrecip,
    required this.hourlyCode,
    required this.current,
    this.utcOffset = Duration.zero,
  });

  /// Deslocamento do fuso da cidade em relação ao UTC (`utc_offset_seconds`).
  final Duration utcOffset;

  /// yyyy-MM-dd (já no fuso da cidade).
  final List<String> dates;

  /// modelo -> lista (um item por dia, alinhada com [dates]).
  final Map<String, List<ModelDay>> dailyByModel;

  /// yyyy-MM-ddTHH:mm (horário local da cidade).
  final List<String> hourlyTimes;
  final Map<String, List<double?>> hourlyTemp;
  final Map<String, List<double?>> hourlyPrecip;
  final Map<String, List<int?>> hourlyCode;
  final CurrentConditions? current;
}

/// Séries horárias de precipitação de todos os membros do ensemble.
class EnsembleInput {
  const EnsembleInput({required this.times, required this.members});

  /// yyyy-MM-ddTHH:mm (horário local da cidade).
  final List<String> times;

  /// sufixo do modelo -> lista de membros (inclui a rodada de controle),
  /// cada membro com uma série horária alinhada com [times].
  final Map<String, List<List<double?>>> members;

  int get totalMembers => members.values.fold(0, (a, b) => a + b.length);
}
