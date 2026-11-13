import '../core/constants.dart';
import 'models.dart';

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

/// Confiança do dia: considera apenas a previsão de chuva.
ConfidenceResult assessConfidence({
  required int modelsWithRain,
  required int rainModels,
  required double? probability,
}) {
  return ConfidenceResult(
    level: rainConfidence(
      modelsWithRain: modelsWithRain,
      modelsAvailable: rainModels,
      probability: probability,
    ),
    modelsAgreeOnRain:
        rainModels >= 2 &&
        (modelsWithRain == 0 || modelsWithRain == rainModels),
    probabilityUncertain: isUncertainProbability(probability),
    singleModel: rainModels < 2,
  );
}
