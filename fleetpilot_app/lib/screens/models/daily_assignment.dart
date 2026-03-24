/// Affectation permanente : chauffeur → camion + commissionnaire
/// Tarif spécifique optionnel (surcharge le tarif du commissionnaire)
class DriverAssignment {
  final String driverName;
  final String truckPlate;
  final String? companyName; // commissionnaire par défaut

  /// Tarif journalier spécifique (surcharge ClientPricing.dailyRate si renseigné)
  final double? customDailyRate;

  /// Prix par point spécifique (surcharge ClientPricing.pricePerPoint si renseigné)
  final double? customPricePerPoint;

  const DriverAssignment({
    required this.driverName,
    required this.truckPlate,
    this.companyName,
    this.customDailyRate,
    this.customPricePerPoint,
  });

  bool get hasCustomRate =>
      customDailyRate != null || customPricePerPoint != null;

  Map<String, dynamic> toJson() => {
        'driverName': driverName,
        'truckPlate': truckPlate,
        'companyName': companyName,
        'customDailyRate': customDailyRate,
        'customPricePerPoint': customPricePerPoint,
      };

  factory DriverAssignment.fromJson(Map<String, dynamic> json) =>
      DriverAssignment(
        driverName: json['driverName'] as String,
        truckPlate: json['truckPlate'] as String,
        companyName: json['companyName'] as String?,
        customDailyRate: json['customDailyRate'] != null
            ? (json['customDailyRate'] as num).toDouble()
            : null,
        customPricePerPoint: json['customPricePerPoint'] != null
            ? (json['customPricePerPoint'] as num).toDouble()
            : null,
      );
}
