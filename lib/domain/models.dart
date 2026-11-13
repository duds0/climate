/// Modelos de domínio (Dart puro, sem Flutter).
library;

enum Confidence {
  alta,
  media,
  baixa;

  /// Rebaixa um nível (baixa permanece baixa).
  Confidence get downgraded => switch (this) {
    Confidence.alta => Confidence.media,
    Confidence.media => Confidence.baixa,
    Confidence.baixa => Confidence.baixa,
  };

  String get label => switch (this) {
    Confidence.alta => 'alta',
    Confidence.media => 'média',
    Confidence.baixa => 'baixa',
  };
}

/// Valores diários de UM modelo para UM dia (qualquer campo pode ser null).
class ModelDay {
  const ModelDay({
    required this.model,
    this.tMax,
    this.tMin,
    this.precip,
    this.wind,
    this.weatherCode,
  });

  final String model;
  final double? tMax;
  final double? tMin;
  final double? precip;
  final double? wind;
  final int? weatherCode;

  bool get isEmpty =>
      tMax == null &&
      tMin == null &&
      precip == null &&
      wind == null &&
      weatherCode == null;
}

/// Faixa (mín–máx) entre modelos.
class Range {
  const Range(this.min, this.max);
  final double min;
  final double max;
  double get spread => max - min;
}

/// Condição atual.
class CurrentConditions {
  const CurrentConditions({
    this.time,
    this.temperature,
    this.humidity,
    this.precipitation,
    this.weatherCode,
    this.windSpeed,
  });

  final DateTime? time;
  final double? temperature;
  final double? humidity;
  final double? precipitation;
  final int? weatherCode;
  final double? windSpeed;
}

/// Probabilidade de chuva de um modelo do ensemble.
class ModelRainProbability {
  const ModelRainProbability({
    required this.key,
    required this.members,
    required this.withRain,
    required this.meanMm,
  });

  /// Sufixo bruto da API (ex.: `ecmwf_ifs025_ensemble`).
  final String key;
  final int members;
  final int withRain;

  /// Chuva diária média entre os membros (mm).
  final double meanMm;

  double get probability => members == 0 ? 0 : withRain / members;
}

/// Resultado do ensemble para um dia.
class EnsembleDay {
  const EnsembleDay({
    required this.date,
    required this.total,
    required this.withRain,
    required this.byModel,
  });

  final String date; // yyyy-MM-dd
  final int total;
  final int withRain;
  final Map<String, ModelRainProbability> byModel;

  double? get probability => total == 0 ? null : withRain / total;
}

/// Resultado final de um dia, já cruzando os modelos.
class DayForecast {
  const DayForecast({
    required this.date,
    required this.models,
    required this.tMax,
    required this.tMin,
    required this.tMaxRange,
    required this.tMinRange,
    required this.precipMean,
    required this.precipRange,
    required this.modelsWithRain,
    required this.modelsWithPrecipData,
    required this.wind,
    required this.weatherCode,
    required this.iconFromProbability,
    required this.rainProbability,
    required this.probabilityIsEstimate,
    required this.ensemble,
    required this.confidence,
  });

  /// Data local (meia-noite, sem fuso).
  final DateTime date;
  final List<ModelDay> models;

  final double? tMax;
  final double? tMin;
  final Range? tMaxRange;
  final Range? tMinRange;

  final double? precipMean;
  final Range? precipRange;
  final int modelsWithRain;
  final int modelsWithPrecipData;

  final double? wind;

  final int weatherCode;

  /// true quando o ícone foi trocado por "chuva" devido à probabilidade >= 60%.
  final bool iconFromProbability;

  final double? rainProbability;

  /// true quando a probabilidade veio do fallback (sem ensemble).
  final bool probabilityIsEstimate;
  final EnsembleDay? ensemble;
  final ConfidenceResult confidence;
}

/// Resultado do cálculo de confiança, com os ingredientes para explicar ao usuário.
class ConfidenceResult {
  const ConfidenceResult({
    required this.level,
    required this.modelsAgreeOnRain,
    required this.probabilityUncertain,
    required this.singleModel,
    this.limitedByCoverage = false,
  });

  /// Confiança na previsão de chuva do dia.
  final Confidence level;
  final bool modelsAgreeOnRain;

  /// Probabilidade entre 30% e 70%.
  final bool probabilityUncertain;

  /// Menos de 2 modelos com dado de chuva: não dá para medir divergência.
  final bool singleModel;

  ConfidenceResult copyWith({Confidence? level, bool? limitedByCoverage}) =>
      ConfidenceResult(
        level: level ?? this.level,
        modelsAgreeOnRain: modelsAgreeOnRain,
        probabilityUncertain: probabilityUncertain,
        singleModel: singleModel,
        limitedByCoverage: limitedByCoverage ?? this.limitedByCoverage,
      );

  /// true quando algum modelo não cobre o dia e a confiança foi limitada a "média".
  final bool limitedByCoverage;
}

/// Ponto horário (média dos modelos).
class HourPoint {
  const HourPoint({
    required this.time,
    this.temp,
    this.precip,
    this.weatherCode,
  });
  final DateTime time;
  final double? temp;
  final double? precip;
  final int? weatherCode;
}

/// Aviso do INMET (nunca entra na média).
class InmetAlert {
  const InmetAlert({
    required this.id,
    required this.title,
    required this.severity,
    required this.colorHex,
    required this.start,
    required this.end,
    required this.risks,
    required this.instructions,
  });

  final int id;
  final String title;
  final String severity;
  final String colorHex;
  final DateTime? start;
  final DateTime? end;
  final List<String> risks;
  final List<String> instructions;

  bool isActiveAt(DateTime wallClock) =>
      (start == null || !wallClock.isBefore(start!)) &&
      (end == null || !wallClock.isAfter(end!));

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'severity': severity,
    'colorHex': colorHex,
    'start': start?.toIso8601String(),
    'end': end?.toIso8601String(),
    'risks': risks,
    'instructions': instructions,
  };

  factory InmetAlert.fromJson(Map<String, dynamic> j) => InmetAlert(
    id: (j['id'] as num?)?.toInt() ?? 0,
    title: j['title'] as String? ?? 'Aviso',
    severity: j['severity'] as String? ?? '',
    colorHex: j['colorHex'] as String? ?? '#FFFE00',
    start: DateTime.tryParse(j['start'] as String? ?? ''),
    end: DateTime.tryParse(j['end'] as String? ?? ''),
    risks: (j['risks'] as List?)?.whereType<String>().toList() ?? const [],
    instructions:
        (j['instructions'] as List?)?.whereType<String>().toList() ?? const [],
  );
}

/// Tudo que a UI precisa.
class WeatherReport {
  const WeatherReport({
    required this.days,
    required this.hours,
    required this.current,
    required this.alerts,
    required this.ensembleAvailable,
    this.utcOffset = Duration.zero,
  });

  /// Deslocamento UTC do fuso da cidade (para calcular "agora" local).
  final Duration utcOffset;

  final List<DayForecast> days;
  final List<HourPoint> hours;
  final CurrentConditions? current;
  final List<InmetAlert> alerts;
  final bool ensembleAvailable;

  DayForecast? get today => days.isEmpty ? null : days.first;
}
