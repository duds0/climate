import 'package:flutter/foundation.dart';

import '../data/city_store.dart';
import '../data/geocoding_api.dart';
import '../domain/city.dart';

/// Cidades do usuário: lista, favorita (abre no início) e ativa (a que as
/// abas Hoje/15 dias/Mapa mostram agora).
class CitiesController extends ChangeNotifier {
  CitiesController(
    this._store, {
    required SavedCities saved,
    GeocodingApi? geocoding,
    this.onRemoved,
  }) : _geocoding = geocoding,
       _cities = List.of(saved.cities),
       _favoriteId = saved.favoriteId,
       _activeId = saved.favoriteId;

  /// Carrega do armazenamento (a favorita já vira a cidade ativa).
  static Future<CitiesController> load(
    CityStore store, {
    GeocodingApi? geocoding,
    Future<void> Function(City city)? onRemoved,
  }) async => CitiesController(
    store,
    saved: await store.load(),
    geocoding: geocoding,
    onRemoved: onRemoved,
  );

  final CityStore _store;
  final GeocodingApi? _geocoding;

  /// Chamado depois de remover uma cidade (ex.: apagar o cache dela).
  final Future<void> Function(City city)? onRemoved;

  final List<City> _cities;
  String _favoriteId;
  String _activeId;

  List<City> get cities => List.unmodifiable(_cities);
  String get favoriteId => _favoriteId;
  String get activeId => _activeId;

  City get favorite => _cities.firstWhere((c) => c.id == _favoriteId);
  City get active => _cities.firstWhere((c) => c.id == _activeId);

  bool contains(City city) => _cities.any((c) => c.id == city.id);
  bool isFavorite(City city) => city.id == _favoriteId;
  bool isActive(City city) => city.id == _activeId;

  /// A última cidade não pode ser removida (o app sempre precisa de uma).
  bool get canRemove => _cities.length > 1;

  /// Adiciona (sem duplicar). Devolve false se já existia.
  Future<bool> add(City city) async {
    if (contains(city)) return false;
    _cities.add(city);
    await _persist();
    notifyListeners();
    _resolveIbge(city); // em segundo plano, melhor esforço
    return true;
  }

  Future<void> _resolveIbge(City city) async {
    final api = _geocoding;
    if (api == null || !city.isBrazil || city.ibgeCode != null) return;
    final code = await api.resolveIbgeCode(city);
    if (code == null) return;
    final i = _cities.indexWhere((c) => c.id == city.id);
    if (i < 0) return;
    _cities[i] = _cities[i].copyWith(ibgeCode: code);
    await _persist();
    notifyListeners();
  }

  /// Marca [city] como a única favorita.
  Future<void> setFavorite(City city) async {
    if (!contains(city) || _favoriteId == city.id) return;
    _favoriteId = city.id;
    await _persist();
    notifyListeners();
  }

  /// Torna [city] a cidade mostrada nas abas de previsão.
  void select(City city) {
    if (!contains(city) || _activeId == city.id) return;
    _activeId = city.id;
    notifyListeners();
  }

  /// Remove [city]. Se era a favorita, a primeira restante assume; se era a
  /// ativa, volta para a favorita. Devolve false se for a última cidade.
  Future<bool> remove(City city) async {
    if (!contains(city) || !canRemove) return false;
    final removed = _cities.firstWhere((c) => c.id == city.id);
    _cities.removeWhere((c) => c.id == city.id);
    if (_favoriteId == city.id) _favoriteId = _cities.first.id;
    if (_activeId == city.id) _activeId = _favoriteId;
    await _persist();
    notifyListeners();
    await onRemoved?.call(removed);
    return true;
  }

  Future<void> _persist() => _store.save(_cities, _favoriteId);
}
