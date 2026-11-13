enum AbsenceReason { conge, maladie, formation, autre }

String absenceReasonLabel(AbsenceReason r) {
  switch (r) {
    case AbsenceReason.conge:
      return 'Congé';
    case AbsenceReason.maladie:
      return 'Maladie';
    case AbsenceReason.formation:
      return 'Formation';
    case AbsenceReason.autre:
      return 'Autre';
  }
}

/// Une absence prévue ou constatée, du premier au dernier jour inclus.
class Absence {
  final String id;
  final String driverName;
  final DateTime start;
  final DateTime end;
  final AbsenceReason reason;

  /// Chauffeur qui reprend sa tournée, s'il y en a un.
  final String? replacementName;

  const Absence({
    required this.id,
    required this.driverName,
    required this.start,
    required this.end,
    this.reason = AbsenceReason.conge,
    this.replacementName,
  });

  bool covers(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return !d.isBefore(s) && !d.isAfter(e);
  }

  int get days =>
      DateTime(end.year, end.month, end.day)
          .difference(DateTime(start.year, start.month, start.day))
          .inDays +
      1;

  Absence copyWith({String? replacementName, bool clearReplacement = false}) =>
      Absence(
        id: id,
        driverName: driverName,
        start: start,
        end: end,
        reason: reason,
        replacementName:
            clearReplacement ? null : (replacementName ?? this.replacementName),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'driverName': driverName,
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'reason': reason.name,
        'replacementName': replacementName,
      };

  factory Absence.fromJson(Map<String, dynamic> json) => Absence(
        id: json['id'] as String,
        driverName: json['driverName'] as String,
        start: DateTime.parse(json['start'] as String),
        end: DateTime.parse(json['end'] as String),
        reason: AbsenceReason.values.firstWhere(
          (r) => r.name == json['reason'],
          orElse: () => AbsenceReason.autre,
        ),
        replacementName: json['replacementName'] as String?,
      );
}
