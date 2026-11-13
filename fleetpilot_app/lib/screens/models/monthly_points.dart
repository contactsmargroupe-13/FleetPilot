/// Points livrés sur un mois, pour un commissionnaire payé « au point »,
/// saisis par le manager à partir du relevé du commissionnaire.
///
/// Le chauffeur ne compte plus ses clients : c'est ce relevé qui fait foi.
class MonthlyPoints {
  final String month; // 'yyyy-MM'
  final String companyName;
  final String driverName;
  final int points;

  const MonthlyPoints({
    required this.month,
    required this.companyName,
    required this.driverName,
    required this.points,
  });

  String get id => idFor(month, companyName, driverName);

  static String idFor(String month, String companyName, String driverName) =>
      '${month}_${companyName}_$driverName'.replaceAll('/', '-');

  static String monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'id': id,
        'month': month,
        'companyName': companyName,
        'driverName': driverName,
        'points': points,
      };

  factory MonthlyPoints.fromJson(Map<String, dynamic> json) => MonthlyPoints(
        month: json['month'] as String,
        companyName: json['companyName'] as String,
        driverName: json['driverName'] as String,
        points: (json['points'] as num).toInt(),
      );
}
