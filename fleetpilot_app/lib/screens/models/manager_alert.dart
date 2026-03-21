enum ManagerAlertType {
  truckChange,     // Changement de camion temporaire (panne)
  documentExpire,  // Document expiré
  info,            // Information générale
}

String managerAlertTypeLabel(ManagerAlertType type) {
  switch (type) {
    case ManagerAlertType.truckChange:
      return 'Changement de camion';
    case ManagerAlertType.documentExpire:
      return 'Document expiré';
    case ManagerAlertType.info:
      return 'Information';
  }
}

class ManagerAlert {
  final String id;
  final ManagerAlertType type;
  final String title;
  final String? message;
  final DateTime date;
  final bool read;

  /// Chauffeur concerné
  final String? driverName;

  /// Ancien camion (pour truckChange)
  final String? oldTruckPlate;

  /// Nouveau camion (pour truckChange)
  final String? newTruckPlate;

  const ManagerAlert({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    this.message,
    this.read = false,
    this.driverName,
    this.oldTruckPlate,
    this.newTruckPlate,
  });

  ManagerAlert copyWith({
    String? title,
    String? message,
    bool? read,
  }) {
    return ManagerAlert(
      id: id,
      type: type,
      title: title ?? this.title,
      date: date,
      message: message ?? this.message,
      read: read ?? this.read,
      driverName: driverName,
      oldTruckPlate: oldTruckPlate,
      newTruckPlate: newTruckPlate,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'message': message,
        'date': date.toIso8601String(),
        'read': read,
        'driverName': driverName,
        'oldTruckPlate': oldTruckPlate,
        'newTruckPlate': newTruckPlate,
      };

  factory ManagerAlert.fromJson(Map<String, dynamic> json) => ManagerAlert(
        id: json['id'] as String,
        type: ManagerAlertType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => ManagerAlertType.info,
        ),
        title: json['title'] as String,
        message: json['message'] as String?,
        date: DateTime.parse(json['date'] as String),
        read: json['read'] as bool? ?? false,
        driverName: json['driverName'] as String?,
        oldTruckPlate: json['oldTruckPlate'] as String?,
        newTruckPlate: json['newTruckPlate'] as String?,
      );
}
