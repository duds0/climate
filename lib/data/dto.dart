/// Parse defensivo do JSON das APIs -> entradas do domínio.
///
/// Os nomes das chaves NÃO são montados a partir do nome do modelo: tudo é
/// descoberto por regex, agrupando pelo sufixo. Se a API mudar um sufixo, o
/// app continua funcionando.
library;

import '../domain/inputs.dart';
import '../domain/models.dart';
import '../domain/time_utils.dart';

double? _num(Object? v) => v is num ? v.toDouble() : null;
int? _int(Object? v) => v is num ? v.round() : null;
List _list(Object? v) => v is List ? v : const [];
Map<String, dynamic> _map(Object? v) =>
    v is Map<String, dynamic> ? v : const {};

abstract final class ForecastDto {
  static final _dailyKey = RegExp(
    r'^(temperature_2m_max|temperature_2m_min|precipitation_sum|wind_speed_10m_max|weather_code)_(.+)$',
  );
  static final _hourlyKey = RegExp(
    r'^(temperature_2m|precipitation|weather_code)_(.+)$',
  );

  static ForecastInput parse(Map<String, dynamic> json) {
    final daily = _map(json['daily']);
    final dates = _list(daily['time']).whereType<String>().toList();

    // modelo -> variável -> série
    final dailySeries = <String, Map<String, List>>{};
    for (final entry in daily.entries) {
      final m = _dailyKey.firstMatch(entry.key);
      if (m == null) continue;
      (dailySeries[m.group(2)!] ??= {})[m.group(1)!] = _list(entry.value);
    }

    final dailyByModel = <String, List<ModelDay>>{};
    dailySeries.forEach((model, vars) {
      T? at<T>(String v, int i, T? Function(Object?) conv) {
        final l = vars[v];
        return l == null || i >= l.length ? null : conv(l[i]);
      }

      dailyByModel[model] = [
        for (var i = 0; i < dates.length; i++)
          ModelDay(
            model: model,
            tMax: at('temperature_2m_max', i, _num),
            tMin: at('temperature_2m_min', i, _num),
            precip: at('precipitation_sum', i, _num),
            wind: at('wind_speed_10m_max', i, _num),
            weatherCode: at('weather_code', i, _int),
          ),
      ];
    });

    final hourly = _map(json['hourly']);
    final times = _list(hourly['time']).whereType<String>().toList();
    final temp = <String, List<double?>>{};
    final precip = <String, List<double?>>{};
    final code = <String, List<int?>>{};
    for (final entry in hourly.entries) {
      final m = _hourlyKey.firstMatch(entry.key);
      if (m == null) continue;
      final model = m.group(2)!;
      switch (m.group(1)) {
        case 'temperature_2m':
          temp[model] = _list(entry.value).map(_num).toList();
        case 'precipitation':
          precip[model] = _list(entry.value).map(_num).toList();
        case 'weather_code':
          code[model] = _list(entry.value).map(_int).toList();
      }
    }

    final cur = _map(json['current']);
    final current = cur.isEmpty
        ? null
        : CurrentConditions(
            time: parseLocal(cur['time'] as String?),
            temperature: _num(cur['temperature_2m']),
            humidity: _num(cur['relative_humidity_2m']),
            precipitation: _num(cur['precipitation']),
            weatherCode: _int(cur['weather_code']),
            windSpeed: _num(cur['wind_speed_10m']),
          );

    return ForecastInput(
      dates: dates,
      dailyByModel: dailyByModel,
      hourlyTimes: times,
      hourlyTemp: temp,
      hourlyPrecip: precip,
      hourlyCode: code,
      current: current,
      utcOffset: Duration(seconds: _int(json['utc_offset_seconds']) ?? 0),
    );
  }
}

abstract final class EnsembleDto {
  /// `precipitation_member07_ecmwf_ifs025_ensemble` e a rodada de controle
  /// `precipitation_ecmwf_ifs025_ensemble` (sem `memberNN`, conta como membro).
  static final _key = RegExp(r'^precipitation(_member\d+)?_(.+)$');

  static EnsembleInput parse(Map<String, dynamic> json) {
    final hourly = _map(json['hourly']);
    final times = _list(hourly['time']).whereType<String>().toList();
    final members = <String, List<List<double?>>>{};
    for (final entry in hourly.entries) {
      final m = _key.firstMatch(entry.key);
      if (m == null || entry.value is! List) continue;
      (members[m.group(2)!] ??= []).add(_list(entry.value).map(_num).toList());
    }
    return EnsembleInput(times: times, members: members);
  }
}

abstract final class InmetDto {
  /// Lê `{hoje:[...], futuro:[...]}` e devolve só os avisos do município.
  static List<InmetAlert> parse(Object? json, {required String ibgeCode}) {
    if (json is! Map) return const [];
    final seen = <int>{};
    final out = <InmetAlert>[];
    for (final section in const ['hoje', 'futuro']) {
      for (final raw in _list(json[section])) {
        if (raw is! Map) continue;
        final geocodes = (raw['geocodes'] as String? ?? '')
            .split(',')
            .map((s) => s.trim());
        if (!geocodes.contains(ibgeCode)) continue;
        final id = _int(raw['id_aviso']) ?? _int(raw['id']) ?? 0;
        if (!seen.add(id)) continue;
        out.add(
          InmetAlert(
            id: id,
            title: raw['descricao'] as String? ?? 'Aviso',
            severity: raw['severidade'] as String? ?? '',
            colorHex: raw['aviso_cor'] as String? ?? '#FFFE00',
            start: DateTime.tryParse(
              (raw['inicio'] as String? ?? '').replaceFirst(' ', 'T'),
            ),
            end: DateTime.tryParse(
              (raw['fim'] as String? ?? '').replaceFirst(' ', 'T'),
            ),
            risks: _list(
              raw['riscos'],
            ).whereType<String>().map((s) => s.trim()).toList(),
            instructions: _list(
              raw['instrucoes'],
            ).whereType<String>().map((s) => s.trim()).toList(),
          ),
        );
      }
    }
    return out;
  }
}
