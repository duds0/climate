import 'package:flutter/foundation.dart';

import '../data/weather_repository.dart';
import '../domain/aggregation.dart';
import '../domain/city.dart';
import '../domain/models.dart';
import 'cities_controller.dart';

enum LoadStatus { loading, ready, error }

/// Previsão da cidade ativa de [CitiesController]. Ao trocar a cidade ativa,
/// descarta os dados antigos e carrega a nova.
class WeatherController extends ChangeNotifier {
  WeatherController(this._repo, this._cities) : _cityId = _cities.activeId {
    _cities.addListener(_onCitiesChanged);
  }

  final WeatherRepository _repo;
  final CitiesController _cities;

  String _cityId;
  String? _loadingCityId;

  /// Identifica a requisição mais recente; respostas antigas são descartadas.
  int _generation = 0;

  LoadStatus status = LoadStatus.loading;
  WeatherReport? report;
  WeatherSnapshot? snapshot;
  bool refreshing = false;

  /// Mensagem de erro de uma atualização que falhou mas ainda há dados na tela.
  String? lastError;

  City get city => _cities.active;
  bool get offline => snapshot?.offline ?? false;
  DateTime? get updatedAt => snapshot?.fetchedAt;

  void _onCitiesChanged() {
    if (_cities.activeId == _cityId) return;
    _cityId = _cities.activeId;
    report = null;
    snapshot = null;
    lastError = null;
    status = LoadStatus.loading;
    load();
  }

  /// Carrega (respeitando o cache de 30 min) ou, com [force], atualiza da rede.
  Future<void> load({bool force = false}) async {
    final city = _cities.active;
    if (refreshing && _loadingCityId == city.id) return;
    final generation = ++_generation;
    _loadingCityId = city.id;
    refreshing = true;
    lastError = null;
    if (report == null) {
      status = LoadStatus.loading;
    }
    notifyListeners();

    try {
      final snap = await _repo.load(city, force: force);
      if (generation != _generation) return;
      snapshot = snap;
      report = buildReport(
        forecast: snap.forecast,
        ensemble: snap.ensemble,
        alerts: snap.alerts,
        nowInstant: DateTime.now(),
      );
      status = LoadStatus.ready;
    } catch (e) {
      if (generation != _generation) return;
      lastError = 'Não foi possível atualizar. Verifique sua conexão.';
      if (report == null) status = LoadStatus.error;
    } finally {
      if (generation == _generation) {
        refreshing = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _cities.removeListener(_onCitiesChanged);
    super.dispose();
  }
}
