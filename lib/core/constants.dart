/// Constantes do app. Tudo que é "ajustável" fica aqui.
abstract final class AppConstants {
  // ---- Modelos ----
  static const forecastModels = [
    'ecmwf_ifs025',
    'icon_seamless',
    'gfs_seamless',
  ];
  static const ensembleModels = ['ecmwf_ifs025', 'icon_seamless', 'gfs025'];

  /// Pesos por modelo da previsão determinística. Começa igual; ajuste
  /// depois (ex.: 'ecmwf_ifs025': 1.5) se um modelo se mostrar melhor.
  static const Map<String, double> pesosModelos = {
    'ecmwf_ifs025': 1.0,
    'icon_seamless': 1.0,
    'gfs_seamless': 1.0,
  };

  // ---- Chuva ----
  /// Limiar de chuva diária (mm). Um membro/modelo "tem chuva" se soma >= isso.
  /// O ECMWF tem garoa persistente de 0,1 mm/h; se inflar a probabilidade, teste 2.0.
  static const rainThresholdMm = 1.0;

  /// Probabilidade a partir da qual o ícone do dia vira "chuva".
  static const rainIconProbability = 0.60;

  // ---- Confiança ----
  // A confiança considera só a chuva: concordância entre modelos e
  // probabilidade "incerta" (entre estes limites) rebaixa um nível.
  static const uncertainProbLow = 0.30;
  static const uncertainProbHigh = 0.70;

  // ---- Rede / cache ----
  static const requestTimeout = Duration(seconds: 10);
  static const cacheTtl = Duration(minutes: 30);
  static const secondaryCacheMaxAge = Duration(hours: 6);
  static const forecastDays = 15;

  /// A partir do N-ésimo dia (0 = hoje) a previsão é "de longo prazo": o ICON
  /// já não cobre e a incerteza cresce. Usado só para avisar o usuário.
  static const longRangeFromDayIndex = 7;

  // ---- Endpoints ----
  static const forecastUrl = 'https://api.open-meteo.com/v1/forecast';
  static const ensembleUrl = 'https://ensemble-api.open-meteo.com/v1/ensemble';
  static const inmetUrl = 'https://apiprevmet3.inmet.gov.br/avisos/ativos';
  static const geocodingUrl = 'https://geocoding-api.open-meteo.com/v1/search';
  static const ibgeUrl = 'https://servicodados.ibge.gov.br/api/v1/localidades';

  static const satelliteBase =
      'https://satelite.cptec.inpe.br/repositoriogoes/goes19/goes19_web/ams_ret_ch13_baixa';

  /// Mapa do Windy (chuva) centrado na coordenada informada.
  static String windyUrl(double lat, double lon) {
    final la = lat.toStringAsFixed(2);
    final lo = lon.toStringAsFixed(2);
    return 'https://embed.windy.com/embed2.html'
        '?lat=$la&lon=$lo&detailLat=$la&detailLon=$lo&zoom=7'
        '&level=surface&overlay=rain&product=ecmwf&menu=&message=true&marker=true'
        '&calendar=now&type=map&location=coordinates&detail=&metricWind=km%2Fh'
        '&metricTemp=%C2%B0C&radarRange=-1';
  }
}
