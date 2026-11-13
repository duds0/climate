import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/city_store.dart';
import 'data/geocoding_api.dart';
import 'data/weather_repository.dart';
import 'presentation/cities_controller.dart';
import 'presentation/screens/about_screen.dart';
import 'presentation/screens/cities_screen.dart';
import 'presentation/screens/days_screen.dart';
import 'presentation/screens/home_screen.dart';
import 'presentation/screens/map_screen.dart';
import 'presentation/theme.dart';
import 'presentation/weather_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final repository = WeatherRepository();
  final geocoding = GeocodingApi();
  // A cidade favorita já vem como ativa: é a que aparece ao abrir o app.
  final cities = await CitiesController.load(
    CityStore(),
    geocoding: geocoding,
    onRemoved: repository.forget,
  );
  runApp(
    MultiProvider(
      providers: [
        Provider<GeocodingApi>.value(value: geocoding),
        ChangeNotifierProvider<CitiesController>.value(value: cities),
        ChangeNotifierProvider<WeatherController>(
          create: (_) => WeatherController(repository, cities)..load(),
        ),
      ],
      child: const ClimaApp(),
    ),
  );
}

/// Espera [GeocodingApi], [CitiesController] e [WeatherController] acima na árvore.
class ClimaApp extends StatelessWidget {
  const ClimaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climate',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Shell(),
    );
  }
}

class _Shell extends StatefulWidget {
  const _Shell();

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with WidgetsBindingObserver {
  static const _mapIndex = 3;

  int _index = 0;
  // O Mapa (WebView) só é criado na primeira visita.
  bool _mapVisited = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Ao voltar para o app, atualiza (o cache de 30 min evita chamadas à toa).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      context.read<WeatherController>().load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const HomeScreen(),
          const DaysScreen(),
          CitiesScreen(onCityOpened: () => setState(() => _index = 0)),
          _mapVisited ? const MapScreen() : const SizedBox.shrink(),
          const AboutScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          if (i == _mapIndex) _mapVisited = true;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.wb_sunny_outlined),
            selectedIcon: Icon(Icons.wb_sunny),
            label: 'Hoje',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: '15 dias',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_city_outlined),
            selectedIcon: Icon(Icons.location_city),
            label: 'Cidades',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.info_outline),
            selectedIcon: Icon(Icons.info),
            label: 'Sobre',
          ),
        ],
      ),
    );
  }
}
