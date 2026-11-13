import '../core/constants.dart';

/// Converte um instante absoluto para o "relógio de parede" de Bahia (UTC-3),
/// devolvido como DateTime sem fuso (campos locais de Bahia).
DateTime bahiaWallClock(DateTime instant) {
  final s = instant.toUtc().add(AppConstants.bahiaUtcOffset);
  return DateTime(s.year, s.month, s.day, s.hour, s.minute, s.second);
}

/// Chave de dia `yyyy-MM-dd` de um DateTime sem fuso.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Chave de dia (Bahia) de um instante absoluto. Cuida da virada de dia:
/// 2026-11-11T02:00Z -> 2026-11-10 (23h em Bahia).
String bahiaDateKey(DateTime instant) => dateKey(bahiaWallClock(instant));

/// Parse tolerante de `yyyy-MM-dd` ou `yyyy-MM-ddTHH:mm` (sem fuso).
DateTime? parseLocal(String? s) {
  if (s == null) return null;
  final d = DateTime.tryParse(s);
  if (d == null) return null;
  return d.isUtc
      ? DateTime(d.year, d.month, d.day, d.hour, d.minute, d.second)
      : d;
}
