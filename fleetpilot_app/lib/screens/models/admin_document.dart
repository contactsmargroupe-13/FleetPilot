enum AdminDocCategory {
  contratChauffeur,
  contratLocation,
  fichePaie,
  assurance,
  facturePrestataire,
  other,
}

String adminDocCategoryLabel(AdminDocCategory cat) {
  switch (cat) {
    case AdminDocCategory.contratChauffeur:
      return 'Contrat chauffeur';
    case AdminDocCategory.contratLocation:
      return 'Contrat location camion';
    case AdminDocCategory.fichePaie:
      return 'Fiche de paie';
    case AdminDocCategory.assurance:
      return 'Assurance';
    case AdminDocCategory.facturePrestataire:
      return 'Facture / Prestataire';
    case AdminDocCategory.other:
      return 'Autre';
  }
}

class AdminDocument {
  final String id;
  final String title;
  final AdminDocCategory category;

  /// Chauffeur lié (optionnel)
  final String? linkedDriverName;

  /// Camion lié (optionnel)
  final String? linkedTruckPlate;

  final DateTime date;
  final String? note;

  /// Chemin du fichier copié dans le répertoire documents de l'app
  final String? filePath;

  /// Nom original du fichier
  final String? fileName;

  const AdminDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    this.linkedDriverName,
    this.linkedTruckPlate,
    this.note,
    this.filePath,
    this.fileName,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'category': category.name,
        'linkedDriverName': linkedDriverName,
        'linkedTruckPlate': linkedTruckPlate,
        'date': date.toIso8601String(),
        'note': note,
        'filePath': filePath,
        'fileName': fileName,
      };

  factory AdminDocument.fromJson(Map<String, dynamic> json) => AdminDocument(
        id: json['id'] as String,
        title: json['title'] as String,
        category: AdminDocCategory.values.firstWhere(
          (e) => e.name == json['category'],
          orElse: () => AdminDocCategory.other,
        ),
        linkedDriverName: json['linkedDriverName'] as String?,
        linkedTruckPlate: json['linkedTruckPlate'] as String?,
        date: DateTime.parse(json['date'] as String),
        note: json['note'] as String?,
        filePath: json['filePath'] as String?,
        fileName: json['fileName'] as String?,
      );
}
