import 'dart:convert';

import 'package:crypto/crypto.dart';

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
      );

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }
}
