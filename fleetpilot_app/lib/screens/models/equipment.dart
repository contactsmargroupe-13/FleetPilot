enum EquipmentCategory {
  outillage,
  informatique,
  mobilier,
  manutention,
  securite,
  autre,
}

String equipmentCategoryLabel(EquipmentCategory cat) {
  switch (cat) {
    case EquipmentCategory.outillage: return 'Outillage';
    case EquipmentCategory.informatique: return 'Informatique';
    case EquipmentCategory.mobilier: return 'Mobilier';
    case EquipmentCategory.manutention: return 'Manutention';
    case EquipmentCategory.securite: return 'Sécurité';
    case EquipmentCategory.autre: return 'Autre';
  }
}

class Equipment {
  final String id;
  final String name;
  final EquipmentCategory category;
  final double purchasePrice;
  final DateTime purchaseDate;
  final int amortMonths;
  final String? note;
  final String? assignedTruckPlate;

  const Equipment({
    required this.id,
    required this.name,
    required this.category,
    required this.purchasePrice,
    required this.purchaseDate,
    required this.amortMonths,
    this.note,
    this.assignedTruckPlate,
  });

  /// Valeur résiduelle (amortissement linéaire)
  double get currentValue {
    final monthsElapsed = DateTime.now().difference(purchaseDate).inDays / 30.44;
    if (monthsElapsed >= amortMonths) return 0.0;
    return purchasePrice * (1 - monthsElapsed / amortMonths);
  }

  /// Pourcentage amorti
  double get amortPercent {
    final monthsElapsed = DateTime.now().difference(purchaseDate).inDays / 30.44;
    return (monthsElapsed / amortMonths).clamp(0.0, 1.0);
  }

  /// Amortissement mensuel
  double get monthlyAmort => amortMonths > 0 ? purchasePrice / amortMonths : 0;

  /// Mois restants
  int get monthsRemaining {
    final elapsed = DateTime.now().difference(purchaseDate).inDays / 30.44;
    return (amortMonths - elapsed).ceil().clamp(0, amortMonths);
  }

  bool get isFullyAmortized => currentValue <= 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'purchasePrice': purchasePrice,
        'purchaseDate': purchaseDate.toIso8601String(),
        'amortMonths': amortMonths,
        'note': note,
        'assignedTruckPlate': assignedTruckPlate,
      };

  factory Equipment.fromJson(Map<String, dynamic> json) => Equipment(
        id: json['id'] as String,
        name: json['name'] as String,
        category: EquipmentCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => EquipmentCategory.autre,
        ),
        purchasePrice: (json['purchasePrice'] as num).toDouble(),
        purchaseDate: DateTime.parse(json['purchaseDate'] as String),
        amortMonths: json['amortMonths'] as int,
        note: json['note'] as String?,
        assignedTruckPlate: json['assignedTruckPlate'] as String?,
      );
}
