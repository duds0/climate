import 'inputs.dart';
import 'models.dart';

/// Soma, por dia local, a precipitação horária de cada membro do ensemble e
/// conta quantos passam do limiar.
///
/// Os horários de [EnsembleInput.times] já vêm no fuso da cidade (a
/// requisição pede o mesmo `timezone` da previsão), então o dia é o prefixo
/// `yyyy-MM-dd`. Membros sem nenhum dado no dia são ignorados naquele dia.
Map<String, EnsembleDay> aggregateEnsemble(
  EnsembleInput input, {
  required double thresholdMm,
}) {
  // dia -> índices horários
  final indexesByDay = <String, List<int>>{};
  for (var i = 0; i < input.times.length; i++) {
    final t = input.times[i];
    if (t.length < 10) continue;
    (indexesByDay[t.substring(0, 10)] ??= []).add(i);
  }

  final result = <String, EnsembleDay>{};
  indexesByDay.forEach((day, idx) {
    var total = 0;
    var withRain = 0;
    final byModel = <String, ModelRainProbability>{};

    input.members.forEach((key, members) {
      var mTotal = 0;
      var mRain = 0;
      var mSum = 0.0;
      for (final series in members) {
        double sum = 0;
        var any = false;
        for (final i in idx) {
          if (i >= series.length) continue;
          final v = series[i];
          if (v == null) continue;
          any = true;
          sum += v;
        }
        if (!any) continue;
        // Evita erro de ponto flutuante (10 x 0,1 = 0,9999999999999999).
        sum = (sum * 1000).round() / 1000;
        mTotal++;
        mSum += sum;
        if (sum >= thresholdMm) mRain++;
      }
      if (mTotal > 0) {
        byModel[key] = ModelRainProbability(
          key: key,
          members: mTotal,
          withRain: mRain,
          meanMm: mSum / mTotal,
        );
        total += mTotal;
        withRain += mRain;
      }
    });

    result[day] = EnsembleDay(
      date: day,
      total: total,
      withRain: withRain,
      byModel: byModel,
    );
  });
  return result;
}
