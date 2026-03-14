class ClientPricing {
  final String companyName;

  // Base obligatoire
  final double dailyRate;

  // Indexation gasoil (optionnel)
  final bool fuelIndexEnabled;
  final double? fuelRefPrice;

  // Extra km (optionnel)
  final bool extraKmEnabled;
  final double? extraKmPrice;

  // Manutention (optionnel)
  final bool handlingEnabled;
  final double? handlingPrice;

  // Tour supplémentaire (optionnel)
  final bool extraTourEnabled;
  final double? extraTourPrice;

  // Seuil km mensuel
  final double? monthlyKmThreshold;
  final double? overKmRate;

  // Seuil de rentabilité (€/mois)
  final double? breakEvenAmount;

  final String? notes;

  const ClientPricing({
    required this.companyName,
    required this.dailyRate,
    this.fuelIndexEnabled = false,
    this.fuelRefPrice,
    this.extraKmEnabled = false,
    this.extraKmPrice,
    this.handlingEnabled = false,
    this.handlingPrice,
    this.extraTourEnabled = false,
    this.extraTourPrice,
    this.monthlyKmThreshold,
    this.overKmRate,
    this.breakEvenAmount,
    this.notes,
  });

  ClientPricing copyWith({
    String? companyName,
    double? dailyRate,
    bool? fuelIndexEnabled,
    double? fuelRefPrice,
    bool? extraKmEnabled,
    double? extraKmPrice,
    bool? handlingEnabled,
    double? handlingPrice,
    bool? extraTourEnabled,
    double? extraTourPrice,
    double? monthlyKmThreshold,
    double? overKmRate,
    double? breakEvenAmount,
    String? notes,
  }) {
    return ClientPricing(
      companyName: companyName ?? this.companyName,
      dailyRate: dailyRate ?? this.dailyRate,
      fuelIndexEnabled: fuelIndexEnabled ?? this.fuelIndexEnabled,
      fuelRefPrice: fuelRefPrice ?? this.fuelRefPrice,
      extraKmEnabled: extraKmEnabled ?? this.extraKmEnabled,
      extraKmPrice: extraKmPrice ?? this.extraKmPrice,
      handlingEnabled: handlingEnabled ?? this.handlingEnabled,
      handlingPrice: handlingPrice ?? this.handlingPrice,
      extraTourEnabled: extraTourEnabled ?? this.extraTourEnabled,
      extraTourPrice: extraTourPrice ?? this.extraTourPrice,
      monthlyKmThreshold: monthlyKmThreshold ?? this.monthlyKmThreshold,
      overKmRate: overKmRate ?? this.overKmRate,
      breakEvenAmount: breakEvenAmount ?? this.breakEvenAmount,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'dailyRate': dailyRate,
        'fuelIndexEnabled': fuelIndexEnabled,
        'fuelRefPrice': fuelRefPrice,
        'extraKmEnabled': extraKmEnabled,
        'extraKmPrice': extraKmPrice,
        'handlingEnabled': handlingEnabled,
        'handlingPrice': handlingPrice,
        'extraTourEnabled': extraTourEnabled,
        'extraTourPrice': extraTourPrice,
        'monthlyKmThreshold': monthlyKmThreshold,
        'overKmRate': overKmRate,
        'breakEvenAmount': breakEvenAmount,
        'notes': notes,
      };

  factory ClientPricing.fromJson(Map<String, dynamic> json) {
    // Rétrocompatibilité : ancien modèle avait handlingPrice/extraKmPrice/extraTourPrice requis
    final double? legacyHandlingPrice = json['handlingPrice'] != null
        ? (json['handlingPrice'] as num).toDouble()
        : null;
    final double? legacyExtraKmPrice = json['extraKmPrice'] != null
        ? (json['extraKmPrice'] as num).toDouble()
        : null;
    final double? legacyExtraTourPrice = json['extraTourPrice'] != null
        ? (json['extraTourPrice'] as num).toDouble()
        : null;

    return ClientPricing(
      companyName: json['companyName'] as String,
      dailyRate: json['dailyRate'] != null
          ? (json['dailyRate'] as num).toDouble()
          : 0.0,
      fuelIndexEnabled: json['fuelIndexEnabled'] as bool? ?? false,
      fuelRefPrice: json['fuelRefPrice'] != null
          ? (json['fuelRefPrice'] as num).toDouble()
          : null,
      extraKmEnabled: json['extraKmEnabled'] as bool? ??
          (legacyExtraKmPrice != null && legacyExtraKmPrice > 0),
      extraKmPrice: json['extraKmPrice'] != null
          ? (json['extraKmPrice'] as num).toDouble()
          : legacyExtraKmPrice,
      handlingEnabled: json['handlingEnabled'] as bool? ??
          (legacyHandlingPrice != null && legacyHandlingPrice > 0),
      handlingPrice: json['handlingPrice'] != null
          ? (json['handlingPrice'] as num).toDouble()
          : legacyHandlingPrice,
      extraTourEnabled: json['extraTourEnabled'] as bool? ??
          (legacyExtraTourPrice != null && legacyExtraTourPrice > 0),
      extraTourPrice: json['extraTourPrice'] != null
          ? (json['extraTourPrice'] as num).toDouble()
          : legacyExtraTourPrice,
      monthlyKmThreshold: json['monthlyKmThreshold'] != null
          ? (json['monthlyKmThreshold'] as num).toDouble()
          : null,
      overKmRate: json['overKmRate'] != null
          ? (json['overKmRate'] as num).toDouble()
          : null,
      breakEvenAmount: json['breakEvenAmount'] != null
          ? (json['breakEvenAmount'] as num).toDouble()
          : null,
      notes: json['notes'] as String?,
    );
  }
}
