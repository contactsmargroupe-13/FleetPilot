/// Un relevé du compteur kilométrique d'un camion.
///
/// Les km d'une journée sont la différence entre deux relevés du même
/// camion : si un chauffeur oublie de photographier le soir, le relevé du
/// lendemain matin rattrape le total. C'est la source la plus fiable.
class OdometerReading {
  final String id;
  final String truckPlate;
  final DateTime date;
  final int km;
  final String? driverName;

  /// 'photo' (lue sur la photo) ou 'saisie' (tapée par le chauffeur).
  final String source;

  /// Début ou fin de journée.
  final bool isStart;

  const OdometerReading({
    required this.id,
    required this.truckPlate,
    required this.date,
    required this.km,
    this.driverName,
    this.source = 'photo',
    this.isStart = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'truckPlate': truckPlate,
        'date': date.toIso8601String(),
        'km': km,
        'driverName': driverName,
        'source': source,
        'isStart': isStart,
      };

  factory OdometerReading.fromJson(Map<String, dynamic> json) => OdometerReading(
        id: json['id'] as String,
        truckPlate: json['truckPlate'] as String,
        date: DateTime.parse(json['date'] as String),
        km: (json['km'] as num).toInt(),
        driverName: json['driverName'] as String?,
        source: json['source'] as String? ?? 'photo',
        isStart: json['isStart'] as bool? ?? true,
      );
}
