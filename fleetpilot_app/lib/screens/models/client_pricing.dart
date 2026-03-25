enum BillingMode { aLaFiche, auPoint }

String billingModeLabel(BillingMode mode) {
  switch (mode) {
    case BillingMode.aLaFiche:
      return 'À la fiche';
    case BillingMode.auPoint:
      return 'Au point';
  }
}

class ClientPricing {
  final String companyName;

  // Mode de facturation
  final BillingMode billingMode;

  // Prix par point (mode auPoint)
  final double? pricePerPoint;

  // Infos entreprise
  final String? siret;
  final String? tvaIntra;
  final String? address;
  final String? phone;
  final String? email;
  final String? contactName;

  // Base obligatoire
  final double dailyRate;

  // Indexation gasoil en % (optionnel)
  final bool fuelIndexEnabled;
  final double? fuelIndexPercent;

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

  // Couleur identitaire (stockée en hex, ex: 0xFF4CAF50)
  final int? colorValue;

  const ClientPricing({
    required this.companyName,
    this.billingMode = BillingMode.aLaFiche,
    this.pricePerPoint,
    this.siret,
    this.tvaIntra,
    this.address,
    this.phone,
    this.email,
    this.contactName,
    this.dailyRate = 0,
    this.fuelIndexEnabled = false,
    this.fuelIndexPercent,
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
    this.colorValue,
  });

  ClientPricing copyWith({
    String? companyName,
    BillingMode? billingMode,
    double? pricePerPoint,
    String? siret,
    String? tvaIntra,
    String? address,
    String? phone,
    String? email,
    String? contactName,
    double? dailyRate,
    bool? fuelIndexEnabled,
    double? fuelIndexPercent,
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
    int? colorValue,
  }) {
    return ClientPricing(
      companyName: companyName ?? this.companyName,
      billingMode: billingMode ?? this.billingMode,
      pricePerPoint: pricePerPoint ?? this.pricePerPoint,
      siret: siret ?? this.siret,
      tvaIntra: tvaIntra ?? this.tvaIntra,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      contactName: contactName ?? this.contactName,
      dailyRate: dailyRate ?? this.dailyRate,
      fuelIndexEnabled: fuelIndexEnabled ?? this.fuelIndexEnabled,
      fuelIndexPercent: fuelIndexPercent ?? this.fuelIndexPercent,
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
      colorValue: colorValue ?? this.colorValue,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'billingMode': billingMode.name,
        'pricePerPoint': pricePerPoint,
        'siret': siret,
        'tvaIntra': tvaIntra,
        'address': address,
        'phone': phone,
        'email': email,
        'contactName': contactName,
        'dailyRate': dailyRate,
        'fuelIndexEnabled': fuelIndexEnabled,
        'fuelIndexPercent': fuelIndexPercent,
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
        'colorValue': colorValue,
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
      billingMode: json['billingMode'] != null
          ? BillingMode.values.firstWhere(
              (e) => e.name == json['billingMode'],
              orElse: () => BillingMode.aLaFiche,
            )
          : BillingMode.aLaFiche,
      pricePerPoint: json['pricePerPoint'] != null
          ? (json['pricePerPoint'] as num).toDouble()
          : null,
      siret: json['siret'] as String?,
      tvaIntra: json['tvaIntra'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      contactName: json['contactName'] as String?,
      dailyRate: json['dailyRate'] != null
          ? (json['dailyRate'] as num).toDouble()
          : 0.0,
      fuelIndexEnabled: json['fuelIndexEnabled'] as bool? ?? false,
      fuelIndexPercent: json['fuelIndexPercent'] != null
          ? (json['fuelIndexPercent'] as num).toDouble()
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
      colorValue: json['colorValue'] as int?,
    );
  }
}
