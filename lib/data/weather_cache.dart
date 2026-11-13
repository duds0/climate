import 'package:shared_preferences/shared_preferences.dart';

/// Entrada de cache: corpo bruto + momento em que foi obtido.
class CacheEntry {
  const CacheEntry(this.body, this.savedAt);
  final String body;
  final DateTime savedAt;
  Duration get age => DateTime.now().difference(savedAt);
}

/// Cache local da última resposta bem-sucedida de cada fonte.
class WeatherCache {
  static const forecastKey = 'forecast';
  static const ensembleKey = 'ensemble';
  static const alertsKey = 'alerts';

  Future<CacheEntry?> read(String key) async {
    try {
      final p = await SharedPreferences.getInstance();
      final body = p.getString('cache.$key');
      final ts = p.getInt('cache.$key.ts');
      if (body == null || ts == null) return null;
      return CacheEntry(body, DateTime.fromMillisecondsSinceEpoch(ts));
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, String body) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('cache.$key', body);
      await p.setInt('cache.$key.ts', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Cache é só otimização: falha silenciosa.
    }
  }
}
