import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clima_ipupiara/data/dto.dart';
import 'package:clima_ipupiara/data/weather_repository.dart';
import 'package:clima_ipupiara/domain/models.dart';
import 'package:clima_ipupiara/main.dart';
import 'package:clima_ipupiara/presentation/screens/day_detail_screen.dart';
import 'package:clima_ipupiara/presentation/weather_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

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

  @override
  Future<WeatherSnapshot> load({bool force = false}) async {
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

  const dir = 'C:/flutter/bin/cache/artifacts/material_fonts';
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

Widget _app(WeatherController c, {Widget? home}) => RepaintBoundary(
  key: _boundaryKey,
  child: ChangeNotifierProvider.value(
    value: c,
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
    final c = WeatherController(
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
    await c.load();
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    expect(find.text('Ipupiara · BA'), findsOneWidget);
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
    final c = WeatherController(FakeRepo());
    await c.load();
    final day = c.report!.days[10];
    await t.pumpWidget(
      _app(
        c,
        home: DayDetailScreen(day: day, today: DateTime(2026, 11, 10)),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Por modelo'.toUpperCase()), findsOneWidget);
    await _shot(t, '3_detail');
  });

  testWidgets('Sem ensemble: mostra estimativa; modo escuro', (t) async {
    phone(t);
    t.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(t.platformDispatcher.clearPlatformBrightnessTestValue);
    final c = WeatherController(FakeRepo(withEnsemble: false));
    await c.load();
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    expect(find.textContaining('Probabilidade estimada'), findsOneWidget);
    await _shot(t, '5_home_dark_noensemble');
  });

  testWidgets('Erro sem cache: botão Tentar novamente', (t) async {
    phone(t);
    final c = WeatherController(FakeRepo(fail: true));
    await c.load();
    await t.pumpWidget(_app(c));
    await t.pumpAndSettle();
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}
