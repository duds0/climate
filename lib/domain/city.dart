/// Cidade que o usuário pode acompanhar (Dart puro, sem Flutter).
library;

class City {
  const City({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.admin1 = '',
    this.country = '',
    this.countryCode = '',
    this.timezone = 'auto',
    this.ibgeCode,
  });

  /// Cria a cidade gerando o [id] a partir das coordenadas.
  factory City.create({
    required String name,
    required double latitude,
    required double longitude,
    String admin1 = '',
    String country = '',
    String countryCode = '',
    String timezone = 'auto',
    String? ibgeCode,
  }) => City(
    id: idFor(latitude, longitude),
    name: name,
    latitude: latitude,
    longitude: longitude,
    admin1: admin1,
    country: country,
    countryCode: countryCode,
    timezone: timezone,
    ibgeCode: ibgeCode,
  );

  /// Cidade inicial do app (primeira execução).
  static const ipupiara = City(
    id: '-11.82,-42.61',
    name: 'Ipupiara',
    admin1: 'Bahia',
    country: 'Brasil',
    countryCode: 'BR',
    latitude: -11.82028,
    longitude: -42.61417,
    timezone: 'America/Bahia',
    ibgeCode: '2914109',
  );

  /// Duas casas decimais (~1 km): evita duplicatas da mesma cidade.
  static String idFor(double lat, double lon) =>
      '${lat.toStringAsFixed(2)},${lon.toStringAsFixed(2)}';

  final String id;
  final String name;
  final String admin1;
  final String country;
  final String countryCode;
  final double latitude;
  final double longitude;

  /// Nome IANA (ex.: America/Bahia) ou `auto`.
  final String timezone;

  /// Código IBGE do município (só cidades do Brasil; usado nos avisos do INMET).
  final String? ibgeCode;

  bool get isBrazil => countryCode.toUpperCase() == 'BR';

  /// "Cidade, Estado, País" (partes vazias são omitidas).
  String get fullLabel => [name, admin1, country]
      .where((s) => s.isNotEmpty)
      .fold<List<String>>([], (acc, s) => acc.contains(s) ? acc : [...acc, s])
      .join(', ');

  /// "Estado, País" (ou só o que existir), para subtítulos.
  String get regionLabel =>
      [admin1, country].where((s) => s.isNotEmpty && s != name).join(', ');

  /// "Cidade · Estado" (ou "Cidade · País" quando não há estado).
  String get headerLabel {
    final region = admin1.isNotEmpty ? admin1 : country;
    return region.isEmpty || region == name ? name : '$name · $region';
  }

  City copyWith({String? ibgeCode}) => City(
    id: id,
    name: name,
    latitude: latitude,
    longitude: longitude,
    admin1: admin1,
    country: country,
    countryCode: countryCode,
    timezone: timezone,
    ibgeCode: ibgeCode ?? this.ibgeCode,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'admin1': admin1,
    'country': country,
    'countryCode': countryCode,
    'latitude': latitude,
    'longitude': longitude,
    'timezone': timezone,
    'ibgeCode': ibgeCode,
  };

  /// Devolve null se faltar nome ou coordenadas.
  static City? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final lat = json['latitude'];
    final lon = json['longitude'];
    if (name is! String || name.isEmpty || lat is! num || lon is! num) {
      return null;
    }
    final latitude = lat.toDouble();
    final longitude = lon.toDouble();
    final id = json['id'];
    return City(
      id: id is String && id.isNotEmpty ? id : idFor(latitude, longitude),
      name: name,
      admin1: json['admin1'] as String? ?? '',
      country: json['country'] as String? ?? '',
      countryCode: json['countryCode'] as String? ?? '',
      latitude: latitude,
      longitude: longitude,
      timezone: json['timezone'] as String? ?? 'auto',
      ibgeCode: json['ibgeCode'] as String?,
    );
  }

  @override
  bool operator ==(Object other) => other is City && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
