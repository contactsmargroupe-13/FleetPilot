/// Affectation permanente : chauffeur → camion + commissionnaire
/// Valable tant qu'elle n'est pas modifiée
class DriverAssignment {
  final String driverName;
  final String truckPlate;
  final String? companyName; // commissionnaire par défaut

  const DriverAssignment({
    required this.driverName,
    required this.truckPlate,
    this.companyName,
  });

  Map<String, dynamic> toJson() => {
        'driverName': driverName,
        'truckPlate': truckPlate,
        'companyName': companyName,
      };

  factory DriverAssignment.fromJson(Map<String, dynamic> json) =>
      DriverAssignment(
        driverName: json['driverName'] as String,
        truckPlate: json['truckPlate'] as String,
        companyName: json['companyName'] as String?,
      );
}
