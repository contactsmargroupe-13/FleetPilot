class Candidate {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final DateTime applyDate;
  final String status; // 'candidature' | 'entretien' | 'embauché' | 'refusé'
  final List<String> licenseTypes; // ex: ['C', 'CE']
  final bool hasFimo;
  final bool hasFco;
  final String? note;

  const Candidate({
    required this.id,
    required this.name,
    required this.applyDate,
    this.phone,
    this.email,
    this.status = 'candidature',
    this.licenseTypes = const [],
    this.hasFimo = false,
    this.hasFco = false,
    this.note,
  });

  Candidate copyWith({
    String? name,
    String? phone,
    String? email,
    DateTime? applyDate,
    String? status,
    List<String>? licenseTypes,
    bool? hasFimo,
    bool? hasFco,
    String? note,
  }) =>
      Candidate(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        email: email ?? this.email,
        applyDate: applyDate ?? this.applyDate,
        status: status ?? this.status,
        licenseTypes: licenseTypes ?? this.licenseTypes,
        hasFimo: hasFimo ?? this.hasFimo,
        hasFco: hasFco ?? this.hasFco,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'applyDate': applyDate.toIso8601String(),
        'status': status,
        'licenseTypes': licenseTypes,
        'hasFimo': hasFimo,
        'hasFco': hasFco,
        'note': note,
      };

  factory Candidate.fromJson(Map<String, dynamic> json) => Candidate(
        id: json['id'] as String,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        applyDate: DateTime.parse(json['applyDate'] as String),
        status: json['status'] as String? ?? 'candidature',
        licenseTypes: (json['licenseTypes'] as List?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        hasFimo: json['hasFimo'] as bool? ?? false,
        hasFco: json['hasFco'] as bool? ?? false,
        note: json['note'] as String?,
      );
}
