class Tour {
  final String id;
  final String tourNumber;
  final DateTime date;

  final String driverName;
  final String truckPlate;
  final String? companyName;
  final String? sector;

  final String? startTime;
  final String? endTime;
  final String? breakTime;

  final double kmTotal;
  final int clientsCount;
  final double? weightKg;

  final bool hasHandling;
  final String? handlingClientName;
  final DateTime? handlingDate;

  final double extraKm;
  final bool extraTour;

  final String status;

  const Tour({
    required this.id,
    required this.tourNumber,
    required this.date,
    required this.driverName,
    required this.truckPlate,
    this.companyName,
    this.sector,
    this.startTime,
    this.endTime,
    this.breakTime,
    required this.kmTotal,
    required this.clientsCount,
    this.weightKg,
    required this.hasHandling,
    this.handlingClientName,
    this.handlingDate,
    this.extraKm = 0,
    this.extraTour = false,
    this.status = 'planifiée',
  });

  Tour copyWith({
    String? driverName,
    String? truckPlate,
    String? sector,
    String? status,
  }) {
    return Tour(
      id: id,
      tourNumber: tourNumber,
      date: date,
      driverName: driverName ?? this.driverName,
      truckPlate: truckPlate ?? this.truckPlate,
      companyName: companyName,
      sector: sector ?? this.sector,
      startTime: startTime,
      endTime: endTime,
      breakTime: breakTime,
      kmTotal: kmTotal,
      clientsCount: clientsCount,
      weightKg: weightKg,
      hasHandling: hasHandling,
      handlingClientName: handlingClientName,
      handlingDate: handlingDate,
      extraKm: extraKm,
      extraTour: extraTour,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tourNumber': tourNumber,
    'date': date.toIso8601String(),
    'driverName': driverName,
    'truckPlate': truckPlate,
    'companyName': companyName,
    'sector': sector,
    'startTime': startTime,
    'endTime': endTime,
    'breakTime': breakTime,
    'kmTotal': kmTotal,
    'clientsCount': clientsCount,
    'weightKg': weightKg,
    'hasHandling': hasHandling,
    'handlingClientName': handlingClientName,
    'handlingDate': handlingDate?.toIso8601String(),
    'extraKm': extraKm,
    'extraTour': extraTour,
    'status': status,
  };

  factory Tour.fromJson(Map<String, dynamic> json) => Tour(
    id: json['id'] as String,
    tourNumber: json['tourNumber'] as String,
    date: DateTime.parse(json['date'] as String),
    driverName: json['driverName'] as String,
    truckPlate: json['truckPlate'] as String,
    companyName: json['companyName'] as String?,
    sector: json['sector'] as String?,
    startTime: json['startTime'] as String?,
    endTime: json['endTime'] as String?,
    breakTime: json['breakTime'] as String?,
    kmTotal: (json['kmTotal'] as num).toDouble(),
    clientsCount: json['clientsCount'] as int,
    weightKg: json['weightKg'] != null ? (json['weightKg'] as num).toDouble() : null,
    hasHandling: json['hasHandling'] as bool,
    handlingClientName: json['handlingClientName'] as String?,
    handlingDate: json['handlingDate'] != null
        ? DateTime.parse(json['handlingDate'] as String)
        : null,
    extraKm: (json['extraKm'] as num).toDouble(),
    extraTour: json['extraTour'] as bool,
    status: json['status'] as String? ?? 'planifiée',
  );
}
