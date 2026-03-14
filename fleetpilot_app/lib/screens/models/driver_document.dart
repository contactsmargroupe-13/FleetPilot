enum DocumentType {
  // Permis
  permisB,
  permisC,
  permisCE,

  // Qualifications transport
  fimo,
  fco,
  adr,
  adrCiterne,

  // Formations matériels
  hayon,
  grueAuxiliaire,
  cacesGrue,
  cacesChariot,

  // Formations générales
  ecoConduite,
  securiteTransport,

  // Autres
  atr,
  assurance,
  contrat,
  other,

  // Rétrocompat
  permis,
}

String documentTypeLabel(DocumentType type) {
  switch (type) {
    case DocumentType.permisB:
      return 'Permis B';
    case DocumentType.permisC:
      return 'Permis C';
    case DocumentType.permisCE:
      return 'Permis CE';
    case DocumentType.fimo:
      return 'FIMO Marchandises';
    case DocumentType.fco:
      return 'FCO Marchandises';
    case DocumentType.adr:
      return 'ADR Matières dangereuses';
    case DocumentType.adrCiterne:
      return 'ADR Citerne';
    case DocumentType.hayon:
      return 'Formation hayon';
    case DocumentType.grueAuxiliaire:
      return 'Formation grue auxiliaire';
    case DocumentType.cacesGrue:
      return 'CACES Grue';
    case DocumentType.cacesChariot:
      return 'CACES Chariot embarqué';
    case DocumentType.ecoConduite:
      return 'Formation éco-conduite';
    case DocumentType.securiteTransport:
      return 'Formation sécurité transport';
    case DocumentType.atr:
      return 'ATR';
    case DocumentType.assurance:
      return 'Assurance';
    case DocumentType.contrat:
      return 'Contrat';
    case DocumentType.other:
      return 'Autre';
    case DocumentType.permis:
      return 'Permis de conduire';
  }
}

/// Catégorie pour regrouper dans l'UI
String documentTypeCategory(DocumentType type) {
  switch (type) {
    case DocumentType.permisB:
    case DocumentType.permisC:
    case DocumentType.permisCE:
    case DocumentType.permis:
      return 'Permis';
    case DocumentType.fimo:
    case DocumentType.fco:
    case DocumentType.adr:
    case DocumentType.adrCiterne:
      return 'Qualifications transport';
    case DocumentType.hayon:
    case DocumentType.grueAuxiliaire:
    case DocumentType.cacesGrue:
    case DocumentType.cacesChariot:
      return 'Formations matériel';
    case DocumentType.ecoConduite:
    case DocumentType.securiteTransport:
      return 'Formations générales';
    default:
      return 'Autres documents';
  }
}

class DriverDocument {
  final String id;
  final String driverName;
  final DocumentType type;
  final String? documentNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final String? note;

  const DriverDocument({
    required this.id,
    required this.driverName,
    required this.type,
    this.documentNumber,
    this.issueDate,
    this.expiryDate,
    this.note,
  });

  /// Nombre de jours avant expiration (négatif si expiré)
  int? get daysUntilExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final expiry = DateTime(
        expiryDate!.year, expiryDate!.month, expiryDate!.day);
    return expiry.difference(today).inDays;
  }

  bool get isExpired {
    final d = daysUntilExpiry;
    return d != null && d < 0;
  }

  bool get isExpiringSoon {
    final d = daysUntilExpiry;
    return d != null && d >= 0 && d <= 30;
  }

  /// 'expired' | 'warning' | 'ok' | 'none'
  String get alertLevel {
    if (expiryDate == null) return 'none';
    if (isExpired) return 'expired';
    if (isExpiringSoon) return 'warning';
    return 'ok';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'driverName': driverName,
        'type': type.name,
        'documentNumber': documentNumber,
        'issueDate': issueDate?.toIso8601String(),
        'expiryDate': expiryDate?.toIso8601String(),
        'note': note,
      };

  factory DriverDocument.fromJson(Map<String, dynamic> json) =>
      DriverDocument(
        id: json['id'] as String,
        driverName: json['driverName'] as String,
        type: DocumentType.values.firstWhere(
          (e) => e.name == json['type'],
          orElse: () => DocumentType.other,
        ),
        documentNumber: json['documentNumber'] as String?,
        issueDate: json['issueDate'] != null
            ? DateTime.parse(json['issueDate'] as String)
            : null,
        expiryDate: json['expiryDate'] != null
            ? DateTime.parse(json['expiryDate'] as String)
            : null,
        note: json['note'] as String?,
      );
}
