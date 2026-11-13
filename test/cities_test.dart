import 'dart:convert';
import 'dart:io';

import 'package:clima_ipupiara/data/city_store.dart';
import 'package:clima_ipupiara/data/dto.dart';
import 'package:clima_ipupiara/domain/aggregation.dart';
import 'package:clima_ipupiara/data/geocoding_api.dart';
import 'package:clima_ipupiara/data/weather_api.dart';
import 'package:clima_ipupiara/data/weather_cache.dart';
import 'package:clima_ipupiara/data/weather_repository.dart';
import 'package:clima_ipupiara/domain/city.dart';
import 'package:clima_ipupiara/domain/inputs.dart';
import 'package:clima_ipupiara/presentation/cities_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

City _city(String name, double lat, double lon, {String? ibge}) => City.create(
  name: name,
  latitude: lat,
  longitude: lon,
  admin1: 'Estado',
  country: 'Brasil',
  countryCode: 'BR',
  timezone: 'America/Sao_Paulo',
  ibgeCode: ibge,
);

CitiesController _controller({
  List<City>? cities,
  String? favorite,
  List<City>? removed,
}) {
  final list = cities ?? [City.ipupiara];
  return CitiesController(
    CityStore(),
    saved: SavedCities(list, favorite ?? list.first.id),
    onRemoved: removed == null ? null : (c) async => removed.add(c),
  );
}

/// API falsa: devolve os JSONs reais e conta as chamadas por cidade.
class _FakeWeatherApi extends WeatherApi {
  final forecastCalls = <String>[];

  @override
  Future<String> forecastRaw(City city) async {
    forecastCalls.add(city.id);
    return File('test/fixtures/forecast.json').readAsStringSync();
  }

  @override
  Future<String> ensembleRaw(City city) async =>
      File('test/fixtures/ensemble.json').readAsStringSync();

  @override
  Future<String> inmetRaw() async => throw Exception('INMET fora do ar');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('City', () {
    test('toJson/fromJson preserva os campos', () {
      final c = City.fromJson(jsonDecode(jsonEncode(City.ipupiara.toJson())))!;
      expect(c, City.ipupiara);
      expect(c.name, 'Ipupiara');
      expect(c.timezone, 'America/Bahia');
      expect(c.ibgeCode, '2914109');
      expect(c.headerLabel, 'Ipupiara · Bahia');
    });

    test('fromJson rejeita dados incompletos', () {
      expect(City.fromJson({'name': 'X'}), isNull);
      expect(City.fromJson({'latitude': 1, 'longitude': 2}), isNull);
      expect(City.fromJson('lixo'), isNull);
    });

    test('id é estável para coordenadas próximas (sem duplicar)', () {
      expect(City.idFor(-11.82028, -42.61417), City.ipupiara.id);
      expect(City.idFor(-11.8199, -42.6141), City.ipupiara.id);
    });
  });

  group('GeocodingApi', () {
    test('parse da resposta: ignora resultados inválidos e repetidos', () {
      final json = {
        'results': [
          {
            'name': 'Manaus',
            'latitude': -3.10194,
            'longitude': -60.025,
            'country_code': 'BR',
            'country': 'Brasil',
            'admin1': 'Amazonas',
            'timezone': 'America/Manaus',
          },
          {'name': 'Sem coordenadas'},
          {'latitude': 1.0, 'longitude': 2.0},
          {'name': 'Manaus', 'latitude': -3.10194, 'longitude': -60.025},
        ],
      };
      final r = GeocodingApi.parseSearch(json);
      expect(r, hasLength(1));
      expect(r.single.name, 'Manaus');
      expect(r.single.admin1, 'Amazonas');
      expect(r.single.timezone, 'America/Manaus');
      expect(r.single.isBrazil, isTrue);
    });

    test('sem "results" devolve lista vazia', () {
      expect(GeocodingApi.parseSearch({'generationtime_ms': 0.1}), isEmpty);
      expect(GeocodingApi.parseSearch(null), isEmpty);
    });

    test('fuso ausente vira "auto"', () {
      final r = GeocodingApi.parseSearch({
        'results': [
          {'name': 'Lugar', 'latitude': 1.0, 'longitude': 2.0},
        ],
      });
      expect(r.single.timezone, 'auto');
    });

    test('município do IBGE é achado sem diferenciar acento/caixa', () {
      final towns = [
        {'id': 2900108, 'nome': 'Abaíra'},
        {'id': 2914109, 'nome': 'Ipupiara'},
      ];
      expect(GeocodingApi.matchMunicipality(towns, 'IPUPIARA'), '2914109');
      expect(GeocodingApi.matchMunicipality(towns, 'abaira'), '2900108');
      expect(GeocodingApi.matchMunicipality(towns, 'Outra'), isNull);
      expect(GeocodingApi.matchMunicipality('x', 'Ipupiara'), isNull);
    });
  });

  group('CityStore', () {
    test('primeira execução: só Ipupiara, favorita', () async {
      final saved = await CityStore().load();
      expect(saved.cities, [City.ipupiara]);
      expect(saved.favoriteId, City.ipupiara.id);
    });

    test('salva e relê; favorita inválida cai na primeira', () async {
      final a = _city('A', -10, -40);
      final b = _city('B', -20, -50);
      await CityStore().save([a, b], b.id);
      var saved = await CityStore().load();
      expect(saved.cities, [a, b]);
      expect(saved.favoriteId, b.id);

      SharedPreferences.setMockInitialValues({
        CityStore.listKey: jsonEncode([a.toJson()]),
        CityStore.favoriteKey: 'nao-existe',
      });
      saved = await CityStore().load();
      expect(saved.favoriteId, a.id);
    });

    test('dado corrompido volta ao padrão', () async {
      SharedPreferences.setMockInitialValues({CityStore.listKey: '{{{'});
      final saved = await CityStore().load();
      expect(saved.cities, [City.ipupiara]);
    });
  });

  group('CitiesController', () {
    final a = _city('A', -10, -40);
    final b = _city('B', -20, -50);

    test('adiciona sem duplicar e persiste', () async {
      final c = _controller();
      expect(await c.add(a), isTrue);
      expect(await c.add(a), isFalse);
      expect(c.cities, [City.ipupiara, a]);
      final saved = await CityStore().load();
      expect(saved.cities, [City.ipupiara, a]);
    });

    test('só existe uma favorita; abre na favorita salva', () async {
      final c = _controller(cities: [City.ipupiara, a]);
      expect(c.favorite, City.ipupiara);
      await c.setFavorite(a);
      expect(c.favoriteId, a.id);
      expect(c.cities.where(c.isFavorite), hasLength(1));
      expect(c.activeId, City.ipupiara.id); // a ativa só muda ao selecionar

      // Ao reabrir o app, a favorita é a cidade ativa.
      final reopened = await CitiesController.load(CityStore());
      expect(reopened.favoriteId, a.id);
      expect(reopened.activeId, a.id);
    });

    test('select troca a cidade ativa e notifica', () {
      final c = _controller(cities: [City.ipupiara, a]);
      var notified = 0;
      c.addListener(() => notified++);
      c.select(a);
      expect(c.active, a);
      expect(notified, 1);
      c.select(a); // repetido: nada muda
      expect(notified, 1);
      c.select(b); // fora da lista: ignorado
      expect(c.active, a);
    });

    test('remover a favorita promove a primeira restante', () async {
      final removed = <City>[];
      final c = _controller(
        cities: [City.ipupiara, a, b],
        favorite: a.id,
        removed: removed,
      );
      c.select(a);
      expect(await c.remove(a), isTrue);
      expect(c.favoriteId, City.ipupiara.id);
      expect(c.activeId, City.ipupiara.id);
      expect(removed, [a]);
    });

    test('a última cidade não pode ser removida', () async {
      final c = _controller();
      expect(c.canRemove, isFalse);
      expect(await c.remove(City.ipupiara), isFalse);
      expect(c.cities, [City.ipupiara]);
    });
  });

  group('Cache por cidade', () {
    final a = _city('A', -10, -40);
    final b = _city('B', -20, -50);

    test('previsão de uma cidade não vaza para outra', () async {
      final api = _FakeWeatherApi();
      final repo = WeatherRepository(api: api, cache: WeatherCache());

      await repo.load(a);
      await repo.load(a); // cache fresco: sem nova chamada
      expect(api.forecastCalls, [a.id]);

      await repo.load(b); // outra cidade: busca de novo
      expect(api.forecastCalls, [a.id, b.id]);
    });

    test('forget apaga só o cache da cidade removida', () async {
      final api = _FakeWeatherApi();
      final repo = WeatherRepository(api: api, cache: WeatherCache());
      await repo.load(a);
      await repo.load(b);
      await repo.forget(a);

      await repo.load(b); // ainda em cache
      await repo.load(a); // precisa buscar de novo
      expect(api.forecastCalls, [a.id, b.id, a.id]);
    });

    test('cidade sem código IBGE não consulta o INMET', () async {
      final api = _FakeWeatherApi();
      final repo = WeatherRepository(api: api, cache: WeatherCache());
      final snap = await repo.load(a);
      expect(snap.alerts, isEmpty);
    });

    test('o fuso da resposta vira o offset da previsão', () async {
      final repo = WeatherRepository(
        api: _FakeWeatherApi(),
        cache: WeatherCache(),
      );
      final snap = await repo.load(a);
      expect(snap.forecast.utcOffset, const Duration(hours: -3));
    });
  });

  group('Fuso da cidade', () {
    test('o offset da resposta define o "hoje" do relatório', () {
      // 2026-11-11T02:00Z: em UTC-3 ainda é dia 10; em UTC-4, também (22h).
      // Mas às 03:30Z: UTC-3 já é dia 11 (00:30) e UTC-4 ainda é dia 10 (23:30).
      final instant = DateTime.utc(2026, 11, 11, 3, 30);
      ForecastInput input(int offsetSeconds) => ForecastDto.parse({
        'utc_offset_seconds': offsetSeconds,
        'daily': {
          'time': ['2026-11-10', '2026-11-11'],
          'temperature_2m_max_ecmwf_ifs025': [30.0, 31.0],
          'temperature_2m_min_ecmwf_ifs025': [20.0, 21.0],
          'precipitation_sum_ecmwf_ifs025': [0.0, 0.0],
        },
      });

      final bahia = buildReport(forecast: input(-10800), nowInstant: instant);
      final manaus = buildReport(forecast: input(-14400), nowInstant: instant);
      expect(bahia.utcOffset, const Duration(hours: -3));
      expect(manaus.utcOffset, const Duration(hours: -4));
      expect(bahia.today!.date, DateTime(2026, 11, 11));
      expect(manaus.today!.date, DateTime(2026, 11, 10));
    });
  });
}
