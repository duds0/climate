import 'dart:convert';

import '../core/constants.dart';
import '../domain/inputs.dart';
import '../domain/models.dart';
import 'dto.dart';
import 'weather_api.dart';
import 'weather_cache.dart';

/// Dados brutos já parseados + metadados de origem.
class WeatherSnapshot {
  const WeatherSnapshot({
    required this.forecast,
    required this.ensemble,
    required this.alerts,
    required this.fetchedAt,
    required this.offline,
  });

  final ForecastInput forecast;
  final EnsembleInput? ensemble;
  final List<InmetAlert> alerts;

  /// Momento em que a previsão foi obtida da rede.
  final DateTime fetchedAt;

  /// true quando a rede falhou e estamos mostrando o cache.
  final bool offline;
}

class WeatherRepository {
  WeatherRepository({WeatherApi? api, WeatherCache? cache})
    : _api = api ?? WeatherApi(),
      _cache = cache ?? WeatherCache();

  final WeatherApi _api;
  final WeatherCache _cache;

  /// Carrega os dados. Sem [force], reaproveita o cache com menos de 30 min.
  /// Lança exceção só se não houver rede E não houver cache utilizável.
  Future<WeatherSnapshot> load({bool force = false}) async {
    final cachedForecast = await _cache.read(WeatherCache.forecastKey);

    if (!force &&
        cachedForecast != null &&
        cachedForecast.age < AppConstants.cacheTtl) {
      final snap = await _fromCache(cachedForecast, offline: false);
      if (snap != null) return snap;
    }

    // Busca as três fontes em paralelo; só a previsão é obrigatória.
    final forecastF = _api.forecastRaw();
    final ensembleF = _api
        .ensembleRaw()
        .then<String?>((v) => v)
        .catchError((_) => null);
    final inmetF = _api
        .inmetRaw()
        .then<String?>((v) => v)
        .catchError((_) => null);

    ForecastInput forecast;
    try {
      final raw = await forecastF;
      forecast = ForecastDto.parse(jsonDecode(raw) as Map<String, dynamic>);
      if (forecast.dates.isEmpty) {
        throw const FormatException('previsão sem dias');
      }
      await _cache.write(WeatherCache.forecastKey, raw);
    } catch (_) {
      // Rede/parse falhou: tenta o cache, por mais antigo que seja.
      if (cachedForecast != null) {
        final snap = await _fromCache(cachedForecast, offline: true);
        if (snap != null) return snap;
      }
      rethrow;
    }

    // Ensemble.
    EnsembleInput? ensemble;
    final ensembleRaw = await ensembleF;
    if (ensembleRaw != null) {
      try {
        ensemble = EnsembleDto.parse(
          jsonDecode(ensembleRaw) as Map<String, dynamic>,
        );
        if (ensemble.totalMembers == 0) {
          ensemble = null;
        } else {
          await _cache.write(WeatherCache.ensembleKey, ensembleRaw);
        }
      } catch (_) {
        ensemble = null;
      }
    }
    ensemble ??= await _recentEnsembleFromCache();

    // Alertas (opcional).
    List<InmetAlert>? alerts;
    final inmetRaw = await inmetF;
    if (inmetRaw != null) {
      try {
        alerts = InmetDto.parse(
          jsonDecode(inmetRaw),
          ibgeCode: AppConstants.ibgeCode,
        );
        await _cache.write(
          WeatherCache.alertsKey,
          jsonEncode(alerts.map((a) => a.toJson()).toList()),
        );
      } catch (_) {
        alerts = null;
      }
    }
    alerts ??= await _recentAlertsFromCache();

    return WeatherSnapshot(
      forecast: forecast,
      ensemble: ensemble,
      alerts: alerts,
      fetchedAt: DateTime.now(),
      offline: false,
    );
  }

  Future<WeatherSnapshot?> _fromCache(
    CacheEntry forecastEntry, {
    required bool offline,
  }) async {
    try {
      final forecast = ForecastDto.parse(
        jsonDecode(forecastEntry.body) as Map<String, dynamic>,
      );
      if (forecast.dates.isEmpty) return null;
      return WeatherSnapshot(
        forecast: forecast,
        ensemble: await _ensembleFromCache(
          maxAge: offline ? null : AppConstants.secondaryCacheMaxAge,
        ),
        alerts: await _recentAlertsFromCache(),
        fetchedAt: forecastEntry.savedAt,
        offline: offline,
      );
    } catch (_) {
      return null;
    }
  }

  Future<EnsembleInput?> _recentEnsembleFromCache() =>
      _ensembleFromCache(maxAge: AppConstants.secondaryCacheMaxAge);

  Future<EnsembleInput?> _ensembleFromCache({Duration? maxAge}) async {
    final e = await _cache.read(WeatherCache.ensembleKey);
    if (e == null || (maxAge != null && e.age > maxAge)) return null;
    try {
      final parsed = EnsembleDto.parse(
        jsonDecode(e.body) as Map<String, dynamic>,
      );
      return parsed.totalMembers == 0 ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  Future<List<InmetAlert>> _recentAlertsFromCache() async {
    final e = await _cache.read(WeatherCache.alertsKey);
    if (e == null || e.age > AppConstants.secondaryCacheMaxAge) return const [];
    try {
      return (jsonDecode(e.body) as List)
          .whereType<Map<String, dynamic>>()
          .map(InmetAlert.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
