/// Códigos WMO (weather_code) da Open-Meteo.
library;

enum WeatherKind {
  clear,
  partly,
  cloudy,
  fog,
  drizzle,
  rain,
  showers,
  thunder,
  snow,
}

WeatherKind weatherKind(int code) {
  if (code == 0 || code == 1) return WeatherKind.clear;
  if (code == 2) return WeatherKind.partly;
  if (code == 3) return WeatherKind.cloudy;
  if (code == 45 || code == 48) return WeatherKind.fog;
  if (code >= 51 && code <= 57) return WeatherKind.drizzle;
  if ((code >= 61 && code <= 67)) return WeatherKind.rain;
  if (code >= 71 && code <= 77) return WeatherKind.snow;
  if (code >= 80 && code <= 82) return WeatherKind.showers;
  if (code == 85 || code == 86) return WeatherKind.snow;
  if (code >= 95) return WeatherKind.thunder;
  return WeatherKind.cloudy;
}

/// true para qualquer código que signifique precipitação líquida.
bool isRainCode(int code) =>
    (code >= 51 && code <= 67) || (code >= 80 && code <= 82) || code >= 95;

String weatherDescription(int code) => switch (code) {
  0 => 'Céu limpo',
  1 => 'Predomínio de sol',
  2 => 'Parcialmente nublado',
  3 => 'Nublado',
  45 || 48 => 'Neblina',
  51 => 'Garoa fraca',
  53 => 'Garoa',
  55 => 'Garoa forte',
  56 || 57 => 'Garoa congelante',
  61 => 'Chuva fraca',
  63 => 'Chuva',
  65 => 'Chuva forte',
  66 || 67 => 'Chuva congelante',
  71 || 73 || 75 || 77 => 'Neve',
  80 => 'Pancadas fracas',
  81 => 'Pancadas de chuva',
  82 => 'Pancadas fortes',
  85 || 86 => 'Neve em pancadas',
  95 => 'Trovoada',
  96 || 99 => 'Trovoada com granizo',
  _ => 'Nublado',
};

/// Código mais frequente (soma de pesos).
///
/// Em empate (comum quando só 2 modelos cobrem o dia): com [preferRain] fica o
/// mais severo (maior código); sem ele, o mais brando (menor código).
int? mostFrequentCode(
  Map<String, int?> codes,
  Map<String, double> weights, {
  bool preferRain = true,
}) {
  final score = <int, double>{};
  codes.forEach((model, code) {
    if (code == null) return;
    score[code] = (score[code] ?? 0) + (weights[model] ?? 1.0);
  });
  if (score.isEmpty) return null;
  int? best;
  double bestScore = -1;
  score.forEach((code, s) {
    final tieWins =
        s == bestScore &&
        best != null &&
        (preferRain ? code > best! : code < best!);
    if (s > bestScore || tieWins) {
      best = code;
      bestScore = s;
    }
  });
  return best;
}
