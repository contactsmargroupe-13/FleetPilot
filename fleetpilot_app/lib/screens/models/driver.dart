import 'dart:convert';

import 'package:crypto/crypto.dart';

enum DriverStatus {
  cdi,
  cdd,
  interim,
  finDeMission,
  miseAPied,
  vire,
  demission,
}

String driverStatusLabel(DriverStatus status) {
  switch (status) {
    case DriverStatus.cdi:
      return 'CDI';
    case DriverStatus.cdd:
      return 'CDD';
    case DriverStatus.interim:
      return 'Intérim';
    case DriverStatus.finDeMission:
      return 'Fin de mission';
    case DriverStatus.miseAPied:
      return 'Mise à pied';
    case DriverStatus.vire:
      return 'Viré';
    case DriverStatus.demission:
      return 'Démission';
  }
}

String driverStatusColor(DriverStatus status) {
  switch (status) {
    case DriverStatus.cdi:
      return 'green';
    case DriverStatus.cdd:
      return 'blue';
    case DriverStatus.interim:
      return 'orange';
    case DriverStatus.finDeMission:
      return 'grey';
    case DriverStatus.miseAPied:
      return 'red';
    case DriverStatus.vire:
      return 'red';
    case DriverStatus.demission:
      return 'grey';
  }
}

class Driver {
  final String name;
  final double fixedSalary;
  final double bonus;

  // Informations personnelles
  final DateTime? birthDate;
  final String? socialSecurityNumber;
  final String? phone;

  // Permis
  final bool hasPermisB;
  final bool hasPermisC;
  final bool hasPermisCE;

  // Numéro de tournée attribué par le manager
  final String? assignedTourNumber;

  // PIN hashé (SHA-256) pour l'authentification chauffeur
  final String? pinHash;

  // Statut contractuel
  final DriverStatus status;

  const Driver({
    required this.name,
    required this.fixedSalary,
    this.bonus = 0,
    this.birthDate,
    this.socialSecurityNumber,
    this.phone,
    this.hasPermisB = false,
    this.hasPermisC = false,
    this.hasPermisCE = false,
    this.assignedTourNumber,
    this.pinHash,
    this.status = DriverStatus.cdi,
  });

  double get totalSalary => fixedSalary + bonus;

  bool get hasPinSet => pinHash != null && pinHash!.isNotEmpty;

  /// Vérifie le PIN saisi contre le hash stocké
  bool checkPin(String pin) {
    if (!hasPinSet) return false;
    return _hashPin(pin) == pinHash;
  }

  /// Liste des permis détenus
  String get permisLabel {
    final parts = <String>[];
    if (hasPermisB) parts.add('B');
    if (hasPermisC) parts.add('C');
    if (hasPermisCE) parts.add('CE');
    return parts.isEmpty ? 'Aucun' : parts.join(', ');
  }

  Driver copyWith({
    String? name,
    double? fixedSalary,
    double? bonus,
    DateTime? birthDate,
    String? socialSecurityNumber,
    String? phone,
    bool? hasPermisB,
    bool? hasPermisC,
    bool? hasPermisCE,
    String? assignedTourNumber,
    String? pinHash,
    DriverStatus? status,
  }) {
    return Driver(
      name: name ?? this.name,
      fixedSalary: fixedSalary ?? this.fixedSalary,
      bonus: bonus ?? this.bonus,
      birthDate: birthDate ?? this.birthDate,
      socialSecurityNumber:
          socialSecurityNumber ?? this.socialSecurityNumber,
      phone: phone ?? this.phone,
      hasPermisB: hasPermisB ?? this.hasPermisB,
      hasPermisC: hasPermisC ?? this.hasPermisC,
      hasPermisCE: hasPermisCE ?? this.hasPermisCE,
      assignedTourNumber: assignedTourNumber ?? this.assignedTourNumber,
      pinHash: pinHash ?? this.pinHash,
      status: status ?? this.status,
    );
  }

  /// Crée une copie avec un nouveau PIN (hashé automatiquement)
  Driver withPin(String pin) {
    return copyWith(pinHash: _hashPin(pin));
  }

  /// Crée une copie sans PIN
  Driver withoutPin() {
    return Driver(
      name: name,
      fixedSalary: fixedSalary,
      bonus: bonus,
      birthDate: birthDate,
      socialSecurityNumber: socialSecurityNumber,
      phone: phone,
      hasPermisB: hasPermisB,
      hasPermisC: hasPermisC,
      hasPermisCE: hasPermisCE,
      assignedTourNumber: assignedTourNumber,
      pinHash: null,
      status: status,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'fixedSalary': fixedSalary,
        'bonus': bonus,
        'birthDate': birthDate?.toIso8601String(),
        'socialSecurityNumber': socialSecurityNumber,
        'phone': phone,
        'hasPermisB': hasPermisB,
        'hasPermisC': hasPermisC,
        'hasPermisCE': hasPermisCE,
        'assignedTourNumber': assignedTourNumber,
        'pinHash': pinHash,
        'status': status.name,
      };

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        name: json['name'] as String,
        fixedSalary: (json['fixedSalary'] as num).toDouble(),
        bonus: (json['bonus'] as num).toDouble(),
        birthDate: json['birthDate'] != null
            ? DateTime.parse(json['birthDate'] as String)
            : null,
        socialSecurityNumber: json['socialSecurityNumber'] as String?,
        phone: json['phone'] as String?,
        hasPermisB: json['hasPermisB'] as bool? ?? false,
        hasPermisC: json['hasPermisC'] as bool? ?? false,
        hasPermisCE: json['hasPermisCE'] as bool? ?? false,
        assignedTourNumber: json['assignedTourNumber'] as String?,
        pinHash: json['pinHash'] as String?,
        status: json['status'] != null
            ? DriverStatus.values.firstWhere(
                (e) => e.name == json['status'],
                orElse: () => DriverStatus.cdi,
              )
            : DriverStatus.cdi,
      );

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }
}
