import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/city.dart';

/// Lista de cidades e cidade favorita guardadas localmente.
class SavedCities {
  const SavedCities(this.cities, this.favoriteId);
  final List<City> cities;
  final String favoriteId;
}

class CityStore {
  static const listKey = 'cities.list';
  static const favoriteKey = 'cities.favorite';

  /// Lê o que foi salvo. Na primeira execução (ou dado corrompido) devolve só
  /// Ipupiara, marcada como favorita.
  Future<SavedCities> load() async {
    var cities = <City>[];
    String? favorite;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(listKey);
      if (raw != null) {
        final seen = <String>{};
        for (final item in jsonDecode(raw) as List) {
          final c = City.fromJson(item);
          if (c != null && seen.add(c.id)) cities.add(c);
        }
      }
      favorite = p.getString(favoriteKey);
    } catch (_) {
      cities = [];
    }
    if (cities.isEmpty) {
      cities = [City.ipupiara];
      favorite = City.ipupiara.id;
    }
    if (!cities.any((c) => c.id == favorite)) favorite = cities.first.id;
    return SavedCities(cities, favorite!);
  }

  Future<void> save(List<City> cities, String favoriteId) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        listKey,
        jsonEncode(cities.map((c) => c.toJson()).toList()),
      );
      await p.setString(favoriteKey, favoriteId);
    } catch (_) {
      // Sem persistência o app continua funcionando na sessão atual.
    }
  }
}
