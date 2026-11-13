import 'package:flutter/foundation.dart';

import '../data/weather_repository.dart';
import '../domain/aggregation.dart';
import '../domain/models.dart';

enum LoadStatus { loading, ready, error }

class WeatherController extends ChangeNotifier {
  WeatherController(this._repo);
  final WeatherRepository _repo;

  LoadStatus status = LoadStatus.loading;
  WeatherReport? report;
  WeatherSnapshot? snapshot;
  bool refreshing = false;

  /// Mensagem de erro de uma atualização que falhou mas ainda há dados na tela.
  String? lastError;

  bool get offline => snapshot?.offline ?? false;
  DateTime? get updatedAt => snapshot?.fetchedAt;

  /// Carrega (respeitando o cache de 30 min) ou, com [force], atualiza da rede.
  Future<void> load({bool force = false}) async {
    if (refreshing) return;
    refreshing = true;
    lastError = null;
    if (report == null) {
      status = LoadStatus.loading;
    }
    notifyListeners();

    try {
      final snap = await _repo.load(force: force);
      snapshot = snap;
      report = buildReport(
        forecast: snap.forecast,
        ensemble: snap.ensemble,
        alerts: snap.alerts,
        nowInstant: DateTime.now(),
      );
      status = LoadStatus.ready;
    } catch (e) {
      lastError = 'Não foi possível atualizar. Verifique sua conexão.';
      if (report == null) status = LoadStatus.error;
    } finally {
      refreshing = false;
      notifyListeners();
    }
  }
}
