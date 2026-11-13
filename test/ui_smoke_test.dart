import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clima_ipupiara/data/city_store.dart';
import 'package:clima_ipupiara/data/dto.dart';
import 'package:clima_ipupiara/data/geocoding_api.dart';
import 'package:clima_ipupiara/data/weather_repository.dart';
import 'package:clima_ipupiara/domain/city.dart';
import 'package:clima_ipupiara/domain/models.dart';
import 'package:clima_ipupiara/main.dart';
import 'package:clima_ipupiara/presentation/cities_controller.dart';
import 'package:clima_ipupiara/presentation/screens/day_detail_screen.dart';
import 'package:clima_ipupiara/presentation/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repositório falso: usa os JSONs reais salvos em test/fixtures.
class FakeRepo extends WeatherRepository {
  FakeRepo({
    this.withEnsemble = true,
    this.fail = false,
    this.alerts = const [],
  });
  final bool withEnsemble;
  final bool fail;
  final List<InmetAlert> alerts;

  /// Cidades para as quais a previsão foi pedida (na ordem).
  final requested = <String>[];

  @override
  Future<void> forget(City city) async {}

  @override
  Future<WeatherSnapshot> load(City city, {bool force = false}) async {
    requested.add(city.id);
    if (fail) throw Exception('sem rede');
    final f =
        jsonDecode(File('test/fixtures/forecast15.json').readAsStringSync())
            as Map<String, dynamic>;
    final e =
        jsonDecode(File('test/fixtures/ensemble15.json').readAsStringSync())
            as Map<String, dynamic>;
    return WeatherSnapshot(
      forecast: ForecastDto.parse(f),
      ensemble: withEnsemble ? EnsembleDto.parse(e) : null,
      alerts: alerts,
      fetchedAt: DateTime(2026, 11, 10, 13, 15),
      offline: false,
    );
  }
}

/// Geocoding falso: devolve sempre a lista dada, sem rede.
class FakeGeocoding extends GeocodingApi {
  FakeGeocoding([this.results = const []]);
  List<City> results;

  @override
  Future<List<City>> search(String query) async => results;

  @override
  Future<String?> resolveIbgeCode(City city) async => null;
}

final manaus = City.create(
  name: 'Manaus',
  admin1: 'Amazonas',
  country: 'Brasil',
  countryCode: 'BR',
  latitude: -3.10194,
  longitude: -60.025,
  timezone: 'America/Manaus',
);

/// Controllers prontos para uma tela: Ipupiara é a única cidade (e favorita).
({CitiesController cities, WeatherController weather, FakeGeocoding geo})
_setup(FakeRepo repo, {List<City> found = const []}) {
  SharedPreferences.setMockInitialValues({});
  final geo = FakeGeocoding(found);
  final cities = CitiesController(
    CityStore(),
    saved: SavedCities([City.ipupiara], City.ipupiara.id),
    geocoding: geo,
  );
  return (cities: cities, weather: WeatherController(repo, cities), geo: geo);
}

Future<void> _loadFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(
        Future.value(ByteData.view(File(f).readAsBytesSync().buffer)),
      );
    }
    await loader.load();
  }

  // Sem as fontes reais o teste usa a "Ahem" (larga) e estoura o layout.
  final root = Platform.environment['FLUTTER_ROOT'];
  final dir = root != null
      ? '$root/bin/cache/artifacts/material_fonts'
      : 'C:/flutter/bin/cache/artifacts/material_fonts';
  if (!Directory(dir).existsSync()) return;
  await load('Roboto', [
    '$dir/roboto-regular.ttf',
    '$dir/roboto-medium.ttf',
    '$dir/roboto-bold.ttf',
    '$dir/roboto-light.ttf',
    '$dir/roboto-thin.ttf',
  ]);
  await load('MaterialIcons', ['$dir/materialicons-regular.otf']);
}

final _boundaryKey = GlobalKey();

Widget _app(
  ({CitiesController cities, WeatherController weather, FakeGeocoding geo}) s, {
  Widget? home,
}) => RepaintBoundary(
  key: _boundaryKey,
  child: MultiProvider(
    providers: [
      Provider<GeocodingApi>.value(value: s.geo),
      ChangeNotifierProvider<CitiesController>.value(value: s.cities),
      ChangeNotifierProvider<WeatherController>.value(value: s.weather),
    ],
    child: home == null
        ? const ClimaApp()
        : MaterialApp(home: home, debugShowCheckedModeBanner: false),
  ),
);

/// Salva um PNG da tela em $SHOT_DIR (só se a variável existir).
Future<void> _shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SHOT_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final rb =
        _boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await rb.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await _loadFonts();
  });

  void phone(WidgetTester t) {
    t.view.physicalSize = const Size(390 * 2, 844 * 2);
    t.view.devicePixelRatio = 2;
    addTearDown(t.view.reset);
  }

  testWidgets('Início, 15 dias e Sobre renderizam sem erros (com ensemble)', (
    t,
  ) async {
    phone(t);
    final s = _setup(
      FakeRepo(
        alerts: [
          const InmetAlert(
            id: 1,
            title: 'Acumulado de Chuva',
            severity: 'Perigo Potencial',
            colorHex: '#FFFE00',
            start: null,
            end: null,
            risks: ['Chuva entre 20 a 30 mm/h'],
            instructions: ['Evite enfrentar o mau tempo.'],
          ),
        ],
      ),
    );
    await s.weather.load();
    await t.pumpWidget(_app(s));
    await t.pumpAndSettle();
    expect(find.text('Ipupiara · Bahia'), findsOneWidget);
    expect(find.textContaining('Alerta do INMET'), findsOneWidget);
    await _shot(t, '1_home');

    await t.tap(find.text('15 dias'));
    await t.pumpAndSettle();
    expect(find.text('Hoje'), findsWidgets);
    await _shot(t, '2_days');
    await t.drag(find.byType(ListView).first, const Offset(0, -800));
    await t.pumpAndSettle();
    expect(find.textContaining('LONGO PRAZO'), findsOneWidget);
    await _shot(t, '2b_days_long');

    await t.tap(find.text('Sobre'));
    await t.pumpAndSettle();
    expect(find.textContaining('Open-Meteo.com'), findsOneWidget);
    await _shot(t, '4_about');
  });

  testWidgets('Detalhe do dia', (t) async {
    phone(t);
    final s = _setup(FakeRepo());
    await s.weather.load();
    final day = s.weather.report!.days[10];
    await t.pumpWidget(
      _app(
        s,
        home: DayDetailScreen(day: day, today: DateTime(2026, 11, 10)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Por modelo'.toUpperCase()), findsOneWidget);
    // A confiança explica só a chuva (a lista é preguiçosa: rola até o fim).
    final rainLine = find.textContaining('Chuva ·', findRichText: true);
    await t.scrollUntilVisible(rainLine, 300);
    expect(rainLine, findsOneWidget);
    expect(
      find.textContaining('Temperatura ·', findRichText: true),
      findsNothing,
    );
    await _shot(t, '3_detail');
  });

  testWidgets('Sem ensemble: mostra estimativa; modo escuro', (t) async {
    phone(t);
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    final s = _setup(FakeRepo(withEnsemble: false));
    await s.weather.load();
    await t.pumpWidget(_app(s));
    await t.pumpAndSettle();
    expect(find.textContaining('Probabilidade estimada'), findsOneWidget);
    await _shot(t, '5_home_dark_noensemble');
  });

  testWidgets('Erro sem cache: botão Tentar novamente', (t) async {
    phone(t);
    final s = _setup(FakeRepo(fail: true));
    await s.weather.load();
    await t.pumpWidget(_app(s));
    await t.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('Aba Cidades: pesquisar, adicionar, favoritar e abrir', (
    t,
  ) async {
    phone(t);
    final repo = FakeRepo();
    final s = _setup(repo, found: [manaus]);
    await s.weather.load();
    await t.pumpWidget(_app(s));
    await t.pumpAndSettle();
    expect(repo.requested, [City.ipupiara.id]);

    await t.tap(find.text('Cidades'));
    await t.pumpAndSettle();
    expect(find.text('Minhas cidades'.toUpperCase()), findsOneWidget);

    // Pesquisa e adiciona.
    await t.enterText(find.byType(TextField), 'Manaus');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    await t.tap(find.byKey(ValueKey('result-${manaus.id}')));
    await t.pumpAndSettle();
    expect(s.cities.contains(manaus), isTrue);
    expect(find.byKey(ValueKey('city-${manaus.id}')), findsOneWidget);

    // Favorita a nova cidade: a estrela passa de Ipupiara para Manaus.
    await t.tap(
      find.descendant(
        of: find.byKey(ValueKey('city-${manaus.id}')),
        matching: find.byIcon(Icons.star_border),
      ),
    );
    await t.pumpAndSettle();
    expect(s.cities.favoriteId, manaus.id);
    expect(find.byIcon(Icons.star), findsOneWidget);

    // Tocar na cidade mostra a previsão dela na aba Hoje.
    await t.tap(find.byKey(ValueKey('city-${manaus.id}')));
    await t.pumpAndSettle();
    expect(repo.requested.last, manaus.id);
    expect(find.text('Manaus · Amazonas'), findsOneWidget);
    await _shot(t, '6_cities');
  });
}
