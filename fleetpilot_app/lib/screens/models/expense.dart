enum ExpenseType {
  fuel,
  repair,
  material,
  other,
  toll,
  fine,
  maintenance,
  claim,
}

String expenseTypeLabel(ExpenseType type) {
  switch (type) {
    case ExpenseType.fuel:
      return "Carburant";
    case ExpenseType.repair:
      return "Réparation";
    case ExpenseType.material:
      return "Matériel";
    case ExpenseType.other:
      return "Autre";
    case ExpenseType.toll:
      return "Péage";
    case ExpenseType.fine:
      return "Amende / PV";
    case ExpenseType.maintenance:
      return "Entretien";
    case ExpenseType.claim:
      return "Sinistre / franchise";
  }
}

/// Ordre d'affichage dans les formulaires : les plus fréquentes d'abord.
const expenseTypesOrdered = [
  ExpenseType.fuel,
  ExpenseType.toll,
  ExpenseType.maintenance,
  ExpenseType.repair,
  ExpenseType.fine,
  ExpenseType.claim,
  ExpenseType.material,
  ExpenseType.other,
];

/// TVA habituelle par type. Une amende ou une franchise n'en portent pas ;
/// le gazole d'un utilitaire est récupérable à 100 %.
double defaultVatRate(ExpenseType type) {
  switch (type) {
    case ExpenseType.fine:
    case ExpenseType.claim:
      return 0;
    default:
      return 0.20;
  }
}

const vatRates = [0.20, 0.10, 0.055, 0.0];

String vatLabel(double rate) => rate == 0
    ? 'Sans TVA'
    : '${(rate * 100).toStringAsFixed(rate * 100 % 1 == 0 ? 0 : 1).replaceAll('.', ',')} %';

class Expense {
  final String id;
  final DateTime date;
  final String truckPlate;
  final ExpenseType type;

  /// Montant payé, TTC — c'est ce qui figure sur le ticket.
  final double amount;
  final double? liters;
  final String? note;

  /// Taux de TVA ; null = taux habituel du type (voir [defaultVatRate]).
  final double? vatRate;

  /// Chauffeur concerné — surtout pour une amende, à désigner.
  final String? driverName;

  const Expense({
    required this.id,
    required this.date,
    required this.truckPlate,
    required this.type,
    required this.amount,
    this.liters,
    this.note,
    this.vatRate,
    this.driverName,
  });

  double get effectiveVatRate => vatRate ?? defaultVatRate(type);

  /// Ce que la dépense coûte vraiment à l'entreprise : la TVA est récupérée.
  double get amountHT => amount / (1 + effectiveVatRate);
  double get vat => amount - amountHT;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'truckPlate': truckPlate,
    'type': type.name,
    'amount': amount,
    'liters': liters,
    'note': note,
    'vatRate': vatRate,
    'driverName': driverName,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    truckPlate: json['truckPlate'] as String,
    type: ExpenseType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => ExpenseType.other,
    ),
    amount: (json['amount'] as num).toDouble(),
    liters: json['liters'] != null ? (json['liters'] as num).toDouble() : null,
    note: json['note'] as String?,
    vatRate: json['vatRate'] != null ? (json['vatRate'] as num).toDouble() : null,
    driverName: json['driverName'] as String?,
  );
}
