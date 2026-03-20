enum DriverNotifType {
  amende,
  fichePaie,
  contrat,
  documentExpire,
  info,
}

String driverNotifTypeLabel(DriverNotifType type) {
  switch (type) {
    case DriverNotifType.amende:
      return 'Amende';
    case DriverNotifType.fichePaie:
      return 'Fiche de paie';
    case DriverNotifType.contrat:
      return 'Contrat';
    case DriverNotifType.documentExpire:
      return 'Document expiré';
    case DriverNotifType.info:
      return 'Information';
  }
}

class DriverNotification {
  final String id;
  final String driverName;
  final DriverNotifType type;
  final String title;
  final String? message;
  final DateTime date;
  final bool read;

  /// Montant (pour les amendes)
  final double? amount;

  /// Référence vers un document lié (ex: id d'un DriverDocument ou AdminDocument)
  final String? linkedDocId;

  const DriverNotification({
    required this.id,
    required this.driverName,
    required this.type,
    required this.title,
    required this.date,
    this.message,
    this.read = false,
    this.amount,
    this.linkedDocId,
  });

  DriverNotification copyWith({
    String? title,
    String? message,
    bool? read,
    double? amount,
  }) {
    return DriverNotification(
      id: id,
      driverName: driverName,
      type: type,
      title: title ?? this.title,
      date: date,
      message: message ?? this.message,
      read: read ?? this.read,
      amount: amount ?? this.amount,
      linkedDocId: linkedDocId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'driverName': driverName,
        'type': type.name,
        'title': title,
        'message': message,
        'date': date.toIso8601String(),
        'read': read,
        'amount': amount,
        'linkedDocId': linkedDocId,
      };

  factory DriverNotification.fromJson(Map<String, dynamic> json) =>
      DriverNotification(
        id: json['id'] as String,
        driverName: json['driverName'] as String,
        type: DriverNotifType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => DriverNotifType.info,
        ),
        title: json['title'] as String,
        message: json['message'] as String?,
        date: DateTime.parse(json['date'] as String),
        read: json['read'] as bool? ?? false,
        amount: json['amount'] != null
            ? (json['amount'] as num).toDouble()
            : null,
        linkedDocId: json['linkedDocId'] as String?,
      );
}
