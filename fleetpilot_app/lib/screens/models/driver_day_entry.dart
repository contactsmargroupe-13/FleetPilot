class DriverDayEntry {
  final String id;
  final DateTime date;
  final String driverName;
  final String truckPlate;
  final double kmTotal;
  final int clientsCount;
  final int pickupCount; // nombre de ramasses

  const DriverDayEntry({
    required this.id,
    required this.date,
    required this.driverName,
    required this.truckPlate,
    required this.kmTotal,
    required this.clientsCount,
    this.pickupCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'driverName': driverName,
    'truckPlate': truckPlate,
    'kmTotal': kmTotal,
    'clientsCount': clientsCount,
    'pickupCount': pickupCount,
  };

  factory DriverDayEntry.fromJson(Map<String, dynamic> json) => DriverDayEntry(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    driverName: json['driverName'] as String,
    truckPlate: json['truckPlate'] as String,
    kmTotal: (json['kmTotal'] as num).toDouble(),
    clientsCount: json['clientsCount'] as int,
    pickupCount: json['pickupCount'] as int? ?? 0,
  );
}
