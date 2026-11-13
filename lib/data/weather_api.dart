import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';

/// Clientes HTTP (devolvem JSON decodificado; lançam exceção em falha).
class WeatherApi {
  WeatherApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<String> _get(Uri uri, {Duration? timeout}) async {
    final res = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(timeout ?? AppConstants.requestTimeout);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', uri);
    }
    // Decodifica como UTF-8 explicitamente (INMET não declara charset).
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  Map<String, String> get _common => {
    'latitude': '${AppConstants.latitude}',
    'longitude': '${AppConstants.longitude}',
    'timezone': AppConstants.timezone,
    'forecast_days': '${AppConstants.forecastDays}',
  };

  /// Retorna o corpo bruto (para cache) — o parse é feito depois.
  Future<String> forecastRaw() => _get(
    Uri.parse(AppConstants.forecastUrl).replace(
      queryParameters: {
        ..._common,
        'models': AppConstants.forecastModels.join(','),
        'daily':
            'temperature_2m_max,temperature_2m_min,precipitation_sum,'
            'wind_speed_10m_max,weather_code',
        'hourly': 'temperature_2m,precipitation,weather_code',
        'current':
            'temperature_2m,relative_humidity_2m,precipitation,'
            'weather_code,wind_speed_10m',
      },
    ),
  );

  Future<String> ensembleRaw() => _get(
    Uri.parse(AppConstants.ensembleUrl).replace(
      queryParameters: {
        ..._common,
        'models': AppConstants.ensembleModels.join(','),
        'hourly': 'precipitation',
      },
    ),
  );

  Future<String> inmetRaw() => _get(
    Uri.parse(AppConstants.inmetUrl),
    timeout: const Duration(seconds: 12),
  );

  void close() => _client.close();
}
