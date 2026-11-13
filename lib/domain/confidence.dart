import '../core/constants.dart';
import 'models.dart';

/// Classifica a amplitude de temperatura entre modelos.
Confidence temperatureConfidence(double? spread) {
  if (spread == null) return Confidence.baixa;
  if (spread <= AppConstants.tempSpreadHigh) return Confidence.alta;
  if (spread <= AppConstants.tempSpreadMedium) return Confidence.media;
  return Confidence.baixa;
}

/// Chuva: concordância entre modelos (todos com ou todos sem chuva = alta,
/// senão baixa); probabilidade entre 30% e 70% rebaixa um nível.
Confidence rainConfidence({
  required int modelsWithRain,
  required int modelsAvailable,
  required double? probability,
}) {
  if (modelsAvailable < 2) return Confidence.baixa;
  final agree = modelsWithRain == 0 || modelsWithRain == modelsAvailable;
  var level = agree ? Confidence.alta : Confidence.baixa;
  if (isUncertainProbability(probability)) level = level.downgraded;
  return level;
}

bool isUncertainProbability(double? p) =>
    p != null &&
    p >= AppConstants.uncertainProbLow &&
    p <= AppConstants.uncertainProbHigh;

/// Confiança do dia = a pior entre temperatura e chuva.
ConfidenceResult assessConfidence({
  required double? tempSpread,
  required int tempModels,
  required int modelsWithRain,
  required int rainModels,
  required double? probability,
}) {
  final single = tempModels < 2 && rainModels < 2;
  final temp = tempModels < 2
      ? Confidence.baixa
      : temperatureConfidence(tempSpread);
  final rain = rainConfidence(
    modelsWithRain: modelsWithRain,
    modelsAvailable: rainModels,
    probability: probability,
  );
  return ConfidenceResult(
    level: Confidence.worst(temp, rain),
    temperature: temp,
    rain: rain,
    tempSpread: tempSpread,
    modelsAgreeOnRain:
        rainModels >= 2 &&
        (modelsWithRain == 0 || modelsWithRain == rainModels),
    probabilityUncertain: isUncertainProbability(probability),
    singleModel: single,
  );
}
