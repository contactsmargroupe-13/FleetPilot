enum ExpenseType {
  fuel,
  repair,
  material,
  other,
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
  }
}

class Expense {
  final String id;
  final DateTime date;
  final String truckPlate;
  final ExpenseType type;
  final double amount;
  final double? liters;
  final String? note;

  const Expense({
    required this.id,
    required this.date,
    required this.truckPlate,
    required this.type,
    required this.amount,
    this.liters,
    this.note,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'truckPlate': truckPlate,
    'type': type.name,
    'amount': amount,
    'liters': liters,
    'note': note,
  };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    truckPlate: json['truckPlate'] as String,
    type: ExpenseType.values.firstWhere((e) => e.name == json['type']),
    amount: (json['amount'] as num).toDouble(),
    liters: json['liters'] != null ? (json['liters'] as num).toDouble() : null,
    note: json['note'] as String?,
  );
}