/// Le relevé d'un commissionnaire pour un mois : ce qu'il a réellement
/// payé, et ce qu'il a retenu en pénalités.
///
/// Tant qu'il n'est pas saisi, le chiffre d'affaires du mois n'est qu'une
/// estimation calculée à partir des tarifs.
class ClientStatement {
  final String month; // 'yyyy-MM'
  final String companyName;

  /// Montant HT réglé par le commissionnaire, pénalités déjà déduites.
  final double paidAmount;

  /// Pénalités retenues (colis non livré, retard, avarie…), HT.
  final double penalties;
  final String? note;

  const ClientStatement({
    required this.month,
    required this.companyName,
    required this.paidAmount,
    this.penalties = 0,
    this.note,
  });

  String get id => idFor(month, companyName);

  static String idFor(String month, String companyName) =>
      '${month}_$companyName'.replaceAll('/', '-');

  Map<String, dynamic> toJson() => {
        'id': id,
        'month': month,
        'companyName': companyName,
        'paidAmount': paidAmount,
        'penalties': penalties,
        'note': note,
      };

  factory ClientStatement.fromJson(Map<String, dynamic> json) => ClientStatement(
        month: json['month'] as String,
        companyName: json['companyName'] as String,
        paidAmount: (json['paidAmount'] as num).toDouble(),
        penalties: (json['penalties'] as num?)?.toDouble() ?? 0,
        note: json['note'] as String?,
      );
}
