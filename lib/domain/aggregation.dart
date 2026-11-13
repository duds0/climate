import '../core/constants.dart';
import 'confidence.dart';
import 'ensemble_aggregator.dart';
import 'inputs.dart';
import 'models.dart';
import 'time_utils.dart';
import 'weather_code.dart';

/// Média ponderada ignorando nulls. null se não houver nenhum valor.
double? weightedMean(Map<String, double?> values, Map<String, double> weights) {
  var sum = 0.0;
  var wSum = 0.0;
  values.forEach((model, v) {
    if (v == null) return;
    final w = weights[model] ?? 1.0;
    sum += v * w;
    wSum += w;
  });
  return wSum == 0 ? null : sum / wSum;
}

Range? rangeOf(Iterable<double?> values) {
  double? lo;
  double? hi;
  for (final v in values) {
    if (v == null) continue;
    lo = lo == null || v < lo ? v : lo;
    hi = hi == null || v > hi ? v : hi;
  }
  return lo == null ? null : Range(lo, hi!);
}

/// Cruza os modelos de UM dia.
///
/// [ensembleDay] pode ser null (ensemble indisponível): usa-se o fallback
/// `modelosComChuva / modelosDisponíveis` e a probabilidade é marcada como estimativa.
DayForecast buildDay({
  required DateTime date,
  required List<ModelDay> models,
  EnsembleDay? ensembleDay,
  Map<String, double> weights = AppConstants.pesosModelos,
  double rainThresholdMm = AppConstants.rainThresholdMm,
  double rainIconProbability = AppConstants.rainIconProbability,
  int expectedModels = 0,
}) {
  final present = models.where((m) => !m.isEmpty).toList();

  Map<String, double?> pick(double? Function(ModelDay) f) => {
    for (final m in present) m.model: f(m),
  };

  final maxByModel = pick((m) => m.tMax);
  final minByModel = pick((m) => m.tMin);
  final precipByModel = pick((m) => m.precip);
  final windByModel = pick((m) => m.wind);

  final tMaxRange = rangeOf(maxByModel.values);
  final tMinRange = rangeOf(minByModel.values);
  final precipRange = rangeOf(precipByModel.values);

  final precipValues = precipByModel.values.whereType<double>().toList();
  final withRain = precipValues.where((v) => v >= rainThresholdMm).length;

  // Probabilidade: ensemble, ou fallback.
  final useEnsemble = ensembleDay != null && ensembleDay.total > 0;
  double? probability;
  var estimate = false;
  if (useEnsemble) {
    probability = ensembleDay.probability;
  } else if (precipValues.isNotEmpty) {
    probability = withRain / precipValues.length;
    estimate = true;
  }

  // Ícone.
  // Empates entre modelos são decididos pela probabilidade de chuva.
  var code =
      mostFrequentCode(
        {for (final m in present) m.model: m.weatherCode},
        weights,
        preferRain: probability == null || probability >= 0.5,
      ) ??
      3;
  var iconFromProb = false;
  if (probability != null &&
      probability >= rainIconProbability &&
      !isRainCode(code)) {
    code = 61;
    iconFromProb = true;
  }

  // Confiança (apenas chuva).
  var confidence = assessConfidence(
    modelsWithRain: withRain,
    rainModels: precipValues.length,
    probability: probability,
  );

  // Menos modelos que o esperado cobrem o dia (ex.: ICON só vai até ~7 dias):
  // concordância entre 2 modelos é evidência mais fraca, então o teto é "média".
  if (present.length < expectedModels && confidence.level == Confidence.alta) {
    confidence = confidence.copyWith(
      level: Confidence.media,
      limitedByCoverage: true,
    );
  }

  return DayForecast(
    date: date,
    models: present,
    tMax: weightedMean(maxByModel, weights),
    tMin: weightedMean(minByModel, weights),
    tMaxRange: tMaxRange,
    tMinRange: tMinRange,
    precipMean: weightedMean(precipByModel, weights),
    precipRange: precipRange,
    modelsWithRain: withRain,
    modelsWithPrecipData: precipValues.length,
    wind: weightedMean(windByModel, weights),
    weatherCode: code,
    iconFromProbability: iconFromProb,
    rainProbability: probability,
    probabilityIsEstimate: estimate,
    ensemble: useEnsemble ? ensembleDay : null,
    confidence: confidence,
  );
}

/// Próximas [count] horas (a partir da hora cheia de [nowLocal]), médias dos modelos.
List<HourPoint> buildHours(
  ForecastInput f, {
  required DateTime nowLocal,
  int count = 24,
  Map<String, double> weights = AppConstants.pesosModelos,
}) {
  final start = DateTime(
    nowLocal.year,
    nowLocal.month,
    nowLocal.day,
    nowLocal.hour,
  );
  final out = <HourPoint>[];
  for (var i = 0; i < f.hourlyTimes.length && out.length < count; i++) {
    final t = parseLocal(f.hourlyTimes[i]);
    if (t == null || t.isBefore(start)) continue;
    final temp = weightedMean({
      for (final e in f.hourlyTemp.entries) e.key: _at(e.value, i),
    }, weights);
    final precip = weightedMean({
      for (final e in f.hourlyPrecip.entries) e.key: _at(e.value, i),
    }, weights);
    final code = mostFrequentCode({
      for (final e in f.hourlyCode.entries) e.key: _at(e.value, i),
    }, weights);
    if (temp == null && precip == null) continue;
    out.add(HourPoint(time: t, temp: temp, precip: precip, weatherCode: code));
  }
  return out;
}

T? _at<T>(List<T?> list, int i) => i < list.length ? list[i] : null;

/// Monta o relatório completo.
WeatherReport buildReport({
  required ForecastInput forecast,
  EnsembleInput? ensemble,
  List<InmetAlert> alerts = const [],
  required DateTime nowInstant,
  Map<String, double> weights = AppConstants.pesosModelos,
  double rainThresholdMm = AppConstants.rainThresholdMm,
}) {
  final nowLocal = wallClock(nowInstant, forecast.utcOffset);
  final today = DateTime(nowLocal.year, nowLocal.month, nowLocal.day);

  final ensembleByDay = ensemble == null
      ? const <String, EnsembleDay>{}
      : aggregateEnsemble(ensemble, thresholdMm: rainThresholdMm);

  final all = <DayForecast>[];
  for (var i = 0; i < forecast.dates.length; i++) {
    final date = parseLocal(forecast.dates[i]);
    if (date == null) continue;
    final models = [
      for (final e in forecast.dailyByModel.entries)
        if (i < e.value.length) e.value[i],
    ];
    if (models.every((m) => m.isEmpty)) continue;
    all.add(
      buildDay(
        date: date,
        models: models,
        expectedModels: forecast.dailyByModel.length,
        ensembleDay: ensembleByDay[forecast.dates[i]],
        weights: weights,
        rainThresholdMm: rainThresholdMm,
      ),
    );
  }

  // Cache antigo: descarta dias que já passaram (se sobrar algum).
  var days = all.where((d) => !d.date.isBefore(today)).toList();
  if (days.isEmpty) days = all;

  return WeatherReport(
    days: days,
    hours: buildHours(forecast, nowLocal: nowLocal, weights: weights),
    current: forecast.current,
    alerts: alerts,
    ensembleAvailable: ensemble != null && ensembleByDay.isNotEmpty,
    utcOffset: forecast.utcOffset,
  );
}
