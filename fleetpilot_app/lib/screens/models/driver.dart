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
  final String? firstName;
  final DateTime? birthDate;
  final String? socialSecurityNumber;
  final String? phone;
  final String? email;
  final String? address;
  final String? nationality;
  final String? emergencyContact;
  final String? emergencyPhone;

  // Permis
  final bool hasPermisB;
  final bool hasPermisC;
  final bool hasPermisCE;
  final bool hasPermisD;
  final bool hasPermisEB;
  final String? licenseNumber;
  final DateTime? licenseExpiryDate;

  // Numéro de tournée attribué par le manager
  final String? assignedTourNumber;

  // PIN hashé (SHA-256) pour l'authentification chauffeur
  final String? pinHash;

  // Statut contractuel
  final DriverStatus status;

  // Date d'embauche
  final DateTime? hireDate;

  const Driver({
    required this.name,
    required this.fixedSalary,
    this.bonus = 0,
    this.firstName,
    this.birthDate,
    this.socialSecurityNumber,
    this.phone,
    this.email,
    this.address,
    this.nationality,
    this.emergencyContact,
    this.emergencyPhone,
    this.hasPermisB = false,
    this.hasPermisC = false,
    this.hasPermisCE = false,
    this.hasPermisD = false,
    this.hasPermisEB = false,
    this.licenseNumber,
    this.licenseExpiryDate,
    this.assignedTourNumber,
    this.pinHash,
    this.status = DriverStatus.cdi,
    this.hireDate,
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
    if (hasPermisD) parts.add('D');
    if (hasPermisEB) parts.add('EB');
    return parts.isEmpty ? 'Aucun' : parts.join(', ');
  }

  String get fullName =>
      firstName != null && firstName!.isNotEmpty ? '$firstName $name' : name;

  Driver copyWith({
    String? name,
    double? fixedSalary,
    double? bonus,
    String? firstName,
    DateTime? birthDate,
    String? socialSecurityNumber,
    String? phone,
    String? email,
    String? address,
    String? nationality,
    String? emergencyContact,
    String? emergencyPhone,
    bool? hasPermisB,
    bool? hasPermisC,
    bool? hasPermisCE,
    bool? hasPermisD,
    bool? hasPermisEB,
    String? licenseNumber,
    DateTime? licenseExpiryDate,
    String? assignedTourNumber,
    String? pinHash,
    DriverStatus? status,
    DateTime? hireDate,
  }) {
    return Driver(
      name: name ?? this.name,
      fixedSalary: fixedSalary ?? this.fixedSalary,
      bonus: bonus ?? this.bonus,
      firstName: firstName ?? this.firstName,
      birthDate: birthDate ?? this.birthDate,
      socialSecurityNumber:
          socialSecurityNumber ?? this.socialSecurityNumber,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      nationality: nationality ?? this.nationality,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      hasPermisB: hasPermisB ?? this.hasPermisB,
      hasPermisC: hasPermisC ?? this.hasPermisC,
      hasPermisCE: hasPermisCE ?? this.hasPermisCE,
      hasPermisD: hasPermisD ?? this.hasPermisD,
      hasPermisEB: hasPermisEB ?? this.hasPermisEB,
      licenseNumber: licenseNumber ?? this.licenseNumber,
      licenseExpiryDate: licenseExpiryDate ?? this.licenseExpiryDate,
      assignedTourNumber: assignedTourNumber ?? this.assignedTourNumber,
      pinHash: pinHash ?? this.pinHash,
      status: status ?? this.status,
      hireDate: hireDate ?? this.hireDate,
    );
  }

  /// Crée une copie avec un nouveau PIN (hashé automatiquement)
  Driver withPin(String pin) {
    return copyWith(pinHash: _hashPin(pin));
  }

  /// Crée une copie sans PIN
  Driver withoutPin() {
    return Driver(
      name: name, fixedSalary: fixedSalary, bonus: bonus,
      firstName: firstName, birthDate: birthDate,
      socialSecurityNumber: socialSecurityNumber, phone: phone,
      email: email, address: address, nationality: nationality,
      emergencyContact: emergencyContact, emergencyPhone: emergencyPhone,
      hasPermisB: hasPermisB, hasPermisC: hasPermisC, hasPermisCE: hasPermisCE,
      hasPermisD: hasPermisD, hasPermisEB: hasPermisEB,
      licenseNumber: licenseNumber, licenseExpiryDate: licenseExpiryDate,
      assignedTourNumber: assignedTourNumber, pinHash: null,
      status: status, hireDate: hireDate,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'fixedSalary': fixedSalary,
        'bonus': bonus,
        'firstName': firstName,
        'birthDate': birthDate?.toIso8601String(),
        'socialSecurityNumber': socialSecurityNumber,
        'phone': phone,
        'email': email,
        'address': address,
        'nationality': nationality,
        'emergencyContact': emergencyContact,
        'emergencyPhone': emergencyPhone,
        'hasPermisB': hasPermisB,
        'hasPermisC': hasPermisC,
        'hasPermisCE': hasPermisCE,
        'hasPermisD': hasPermisD,
        'hasPermisEB': hasPermisEB,
        'licenseNumber': licenseNumber,
        'licenseExpiryDate': licenseExpiryDate?.toIso8601String(),
        'assignedTourNumber': assignedTourNumber,
        'pinHash': pinHash,
        'status': status.name,
        'hireDate': hireDate?.toIso8601String(),
      };

  factory Driver.fromJson(Map<String, dynamic> json) => Driver(
        name: json['name'] as String,
        fixedSalary: (json['fixedSalary'] as num).toDouble(),
        bonus: (json['bonus'] as num).toDouble(),
        firstName: json['firstName'] as String?,
        birthDate: json['birthDate'] != null
            ? DateTime.parse(json['birthDate'] as String)
            : null,
        socialSecurityNumber: json['socialSecurityNumber'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        nationality: json['nationality'] as String?,
        emergencyContact: json['emergencyContact'] as String?,
        emergencyPhone: json['emergencyPhone'] as String?,
        hasPermisB: json['hasPermisB'] as bool? ?? false,
        hasPermisC: json['hasPermisC'] as bool? ?? false,
        hasPermisCE: json['hasPermisCE'] as bool? ?? false,
        hasPermisD: json['hasPermisD'] as bool? ?? false,
        hasPermisEB: json['hasPermisEB'] as bool? ?? false,
        licenseNumber: json['licenseNumber'] as String?,
        licenseExpiryDate: json['licenseExpiryDate'] != null
            ? DateTime.parse(json['licenseExpiryDate'] as String)
            : null,
        assignedTourNumber: json['assignedTourNumber'] as String?,
        pinHash: json['pinHash'] as String?,
        status: json['status'] != null
            ? DriverStatus.values.firstWhere(
                (e) => e.name == json['status'],
                orElse: () => DriverStatus.cdi,
              )
            : DriverStatus.cdi,
        hireDate: json['hireDate'] != null
            ? DateTime.parse(json['hireDate'] as String)
            : null,
      );

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }
}
