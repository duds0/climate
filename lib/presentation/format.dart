import 'package:intl/intl.dart';

final _oneDecimal = NumberFormat('0.0', 'pt_BR');

String fmtTemp(double? v) => v == null ? '–' : '${v.round()}°';

String fmtMm(double? v) {
  if (v == null) return '–';
  if (v < 0.05) return '0 mm';
  if (v < 10) return '${_oneDecimal.format(v)} mm';
  return '${v.round()} mm';
}

String fmtPct(double? p) => p == null ? '–' : '${(p * 100).round()}%';

String fmtWind(double? v) => v == null ? '–' : '${v.round()} km/h';

String capitalize(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String dayTitle(DateTime date, DateTime today) {
  final diff = dateOnly(date).difference(dateOnly(today)).inDays;
  if (diff == 0) return 'Hoje';
  if (diff == 1) return 'Amanhã';
  return capitalize(DateFormat('EEEE', 'pt_BR').format(date).split('-').first);
}

String dayShortDate(DateTime d) =>
    DateFormat('d MMM', 'pt_BR').format(d).replaceAll('.', '');

String dayLongDate(DateTime d) =>
    capitalize(DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(d));

String hourLabel(DateTime d) => '${d.hour}h';

String updatedLabel(DateTime d) => DateFormat('dd/MM HH:mm').format(d);

/// Nome amigável do modelo (determinístico ou ensemble).
String modelLabel(String key) {
  final k = key.toLowerCase();
  if (k.contains('ecmwf')) return 'ECMWF';
  if (k.contains('icon')) return 'ICON';
  if (k.contains('gfs') || k.contains('gefs')) return 'GFS';
  return key;
}
