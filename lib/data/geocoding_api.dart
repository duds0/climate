import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/constants.dart';
import '../domain/city.dart';

/// Busca de cidades (Open-Meteo Geocoding) e resolução do código IBGE.
class GeocodingApi {
  GeocodingApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Future<Object?> _getJson(Uri uri) async {
    final res = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(AppConstants.requestTimeout);
    if (res.statusCode != 200) {
      throw http.ClientException('HTTP ${res.statusCode}', uri);
    }
    return jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
  }

  /// Pesquisa cidades pelo nome. Lança exceção em falha de rede.
  Future<List<City>> search(String query) async {
    final q = query.trim();
    if (q.length < 2) return const [];
    final json = await _getJson(
      Uri.parse(AppConstants.geocodingUrl).replace(
        queryParameters: {
          'name': q,
          'count': '10',
          'language': 'pt',
          'format': 'json',
        },
      ),
    );
    return parseSearch(json);
  }

  /// Parse defensivo: ignora resultados sem nome ou coordenadas.
  static List<City> parseSearch(Object? json) {
    if (json is! Map || json['results'] is! List) return const [];
    final out = <City>[];
    final seen = <String>{};
    for (final raw in json['results'] as List) {
      if (raw is! Map) continue;
      final name = raw['name'];
      final lat = raw['latitude'];
      final lon = raw['longitude'];
      if (name is! String || name.isEmpty || lat is! num || lon is! num) {
        continue;
      }
      final tz = raw['timezone'];
      final city = City.create(
        name: name,
        latitude: lat.toDouble(),
        longitude: lon.toDouble(),
        admin1: raw['admin1'] as String? ?? '',
        country: raw['country'] as String? ?? '',
        countryCode: raw['country_code'] as String? ?? '',
        timezone: tz is String && tz.isNotEmpty ? tz : 'auto',
      );
      if (seen.add(city.id)) out.add(city);
    }
    return out;
  }

  /// Código IBGE do município (só Brasil). Melhor esforço: devolve null se
  /// não achar ou se a rede falhar — os avisos do INMET simplesmente não
  /// aparecem para essa cidade.
  Future<String?> resolveIbgeCode(City city) async {
    if (!city.isBrazil || city.admin1.isEmpty) return null;
    try {
      final states = await _getJson(
        Uri.parse('${AppConstants.ibgeUrl}/estados'),
      );
      String? uf;
      final wantedState = normalizeName(city.admin1);
      if (states is List) {
        for (final s in states) {
          if (s is Map && normalizeName('${s['nome']}') == wantedState) {
            uf = s['sigla'] as String?;
            break;
          }
        }
      }
      if (uf == null) return null;
      final towns = await _getJson(
        Uri.parse('${AppConstants.ibgeUrl}/estados/$uf/municipios'),
      );
      return matchMunicipality(towns, city.name);
    } catch (_) {
      return null;
    }
  }

  /// Procura o município pelo nome (sem acento/caixa) na lista do IBGE.
  static String? matchMunicipality(Object? towns, String name) {
    if (towns is! List) return null;
    final wanted = normalizeName(name);
    for (final t in towns) {
      if (t is Map && normalizeName('${t['nome']}') == wanted) {
        final id = t['id'];
        return id == null ? null : '$id';
      }
    }
    return null;
  }

  /// Minúsculas, sem acentos e sem espaços nas pontas.
  static String normalizeName(String s) {
    const from = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const to = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final ch in s.trim().toLowerCase().split('')) {
      final i = from.indexOf(ch);
      b.write(i >= 0 ? to[i] : ch);
    }
    return b.toString();
  }

  void close() => _client.close();
}
