import 'package:flutter/material.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum OwnershipType { achat, location }

enum TruckStatus { fonctionnel, enPanne, enReparation, hs, vendu }

String truckStatusLabel(TruckStatus s) {
  switch (s) {
    case TruckStatus.fonctionnel: return 'Fonctionnel';
    case TruckStatus.enPanne: return 'En panne';
    case TruckStatus.enReparation: return 'En réparation';
    case TruckStatus.hs: return 'HS';
    case TruckStatus.vendu: return 'Vendu';
  }
}

Color truckStatusColor(TruckStatus s) {
  switch (s) {
    case TruckStatus.fonctionnel: return const Color(0xFF2E7D32);
    case TruckStatus.enPanne: return const Color(0xFFE65100);
    case TruckStatus.enReparation: return const Color(0xFF1565C0);
    case TruckStatus.hs: return const Color(0xFFB71C1C);
    case TruckStatus.vendu: return const Color(0xFF616161);
  }
}

enum VehicleType { vl, vl6m3, vl10m3, vl12m3, vl16m3, vl20m3, t75, t12, t19, t26, semi }

String vehicleTypeLabel(VehicleType type) {
  switch (type) {
    case VehicleType.vl:
      return 'VL';
    case VehicleType.vl6m3:
      return 'VL 6m³';
    case VehicleType.vl10m3:
      return 'VL 10m³';
    case VehicleType.vl12m3:
      return 'VL 12m³';
    case VehicleType.vl16m3:
      return 'VL 16m³';
    case VehicleType.vl20m3:
      return 'VL 20m³';
    case VehicleType.t75:
      return '7.5T';
    case VehicleType.t12:
      return '12T';
    case VehicleType.t19:
      return '19T';
    case VehicleType.t26:
      return '26T';
    case VehicleType.semi:
      return 'Semi';
  }
}

// ── ServiceEntry (réparation / entretien) ─────────────────────────────────────

class ServiceEntry {
  final String id;
  final DateTime date;
  final String description;
  final double? cost;

  const ServiceEntry({
    required this.id,
    required this.date,
    required this.description,
    this.cost,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'description': description,
        'cost': cost,
      };

  factory ServiceEntry.fromJson(Map<String, dynamic> json) => ServiceEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        description: json['description'] as String,
        cost: json['cost'] != null ? (json['cost'] as num).toDouble() : null,
      );
}

// ── Modèle Truck ──────────────────────────────────────────────────────────────

class Truck {
  final String plate;
  final String brand;
  final String model;
  final int? year;
  final double dailyRate;

  final OwnershipType ownershipType;

  // Achat
  final double? purchasePrice;
  final int? amortMonths;

  // Location
  final double? rentMonthly;
  final String? rentCompany;

  // Identité
  final VehicleType vehicleType;
  final String? companyName;

  // Assurance
  final String? insurerName;
  final DateTime? insuranceStart;
  final DateTime? insuranceExpiry;
  /// Montant mensuel de l'assurance (€ / mois). Inclus dans les coûts fixes du camion.
  final double? insuranceMonthly;

  // Contrôle technique
  final DateTime? ctDate;
  final DateTime? ctExpiry;

  /// Statut CT : 0=ok, 1=<3mois, 2=<1mois, 3=<1semaine, 4=expiré
  int get ctStatus {
    if (ctExpiry == null) return 0;
    final diff = ctExpiry!.difference(DateTime.now()).inDays;
    if (diff < 0) return 4;
    if (diff < 7) return 3;
    if (diff < 30) return 2;
    if (diff < 90) return 1;
    return 0;
  }

  // Historiques
  final List<ServiceEntry> repairs;
  final List<ServiceEntry> maintenances;

  // Seuil km mensuel pour alerte
  final double? monthlyKmThreshold;

  // Chauffeur assigné
  final String? assignedDriverName;

  // Statut du camion
  final TruckStatus truckStatus;

  const Truck({
    required this.plate,
    required this.model,
    required this.dailyRate,
    required this.ownershipType,
    this.brand = '',
    this.year,
    this.purchasePrice,
    this.amortMonths,
    this.rentMonthly,
    this.rentCompany,
    this.vehicleType = VehicleType.vl,
    this.companyName,
    this.insurerName,
    this.insuranceStart,
    this.insuranceExpiry,
    this.insuranceMonthly,
    this.ctDate,
    this.ctExpiry,
    this.repairs = const [],
    this.maintenances = const [],
    this.monthlyKmThreshold,
    this.assignedDriverName,
    this.truckStatus = TruckStatus.fonctionnel,
  });

  /// Coût mensuel de détention pur (amortissement OU loyer), sans assurance.
  double? get ownershipMonthlyCost {
    if (ownershipType == OwnershipType.achat) {
      if (purchasePrice == null || amortMonths == null || amortMonths! <= 0) {
        return null;
      }
      return purchasePrice! / amortMonths!;
    }
    return rentMonthly;
  }

  /// Coût mensuel total du camion (détention + assurance).
  /// Utilisé par le dashboard pour calculer le profit.
  double get totalMonthlyCost {
    return (ownershipMonthlyCost ?? 0) + (insuranceMonthly ?? 0);
  }

  /// Alias historique — conservé pour compat avec le code existant.
  double? get monthlyCost => ownershipMonthlyCost;

  String get monthlyCostLabel {
    final cost = monthlyCost;
    if (cost == null) return '';
    return ownershipType == OwnershipType.achat
        ? 'Amort: ${cost.toStringAsFixed(0)}€/mois'
        : 'Location: ${cost.toStringAsFixed(0)}€/mois';
  }

  /// Statut assurance : 0=ok, 1=<90j, 2=<30j, 3=expirée
  int get insuranceStatus {
    if (insuranceExpiry == null) return 0;
    final diff = insuranceExpiry!.difference(DateTime.now()).inDays;
    if (diff < 0) return 3;
    if (diff < 30) return 2;
    if (diff < 90) return 1;
    return 0;
  }

  Truck copyWith({
    String? plate,
    String? brand,
    String? model,
    int? year,
    double? dailyRate,
    OwnershipType? ownershipType,
    double? purchasePrice,
    int? amortMonths,
    double? rentMonthly,
    String? rentCompany,
    VehicleType? vehicleType,
    String? companyName,
    String? insurerName,
    DateTime? insuranceStart,
    DateTime? insuranceExpiry,
    double? insuranceMonthly,
    DateTime? ctDate,
    DateTime? ctExpiry,
    List<ServiceEntry>? repairs,
    List<ServiceEntry>? maintenances,
    double? monthlyKmThreshold,
    Object? assignedDriverName = _sentinel,
    TruckStatus? truckStatus,
  }) =>
      Truck(
        plate: plate ?? this.plate,
        brand: brand ?? this.brand,
        model: model ?? this.model,
        year: year ?? this.year,
        dailyRate: dailyRate ?? this.dailyRate,
        ownershipType: ownershipType ?? this.ownershipType,
        purchasePrice: purchasePrice ?? this.purchasePrice,
        amortMonths: amortMonths ?? this.amortMonths,
        rentMonthly: rentMonthly ?? this.rentMonthly,
        rentCompany: rentCompany ?? this.rentCompany,
        vehicleType: vehicleType ?? this.vehicleType,
        companyName: companyName ?? this.companyName,
        insurerName: insurerName ?? this.insurerName,
        insuranceStart: insuranceStart ?? this.insuranceStart,
        insuranceExpiry: insuranceExpiry ?? this.insuranceExpiry,
        insuranceMonthly: insuranceMonthly ?? this.insuranceMonthly,
        ctDate: ctDate ?? this.ctDate,
        ctExpiry: ctExpiry ?? this.ctExpiry,
        repairs: repairs ?? this.repairs,
        maintenances: maintenances ?? this.maintenances,
        monthlyKmThreshold: monthlyKmThreshold ?? this.monthlyKmThreshold,
        assignedDriverName: assignedDriverName == _sentinel
            ? this.assignedDriverName
            : assignedDriverName as String?,
        truckStatus: truckStatus ?? this.truckStatus,
      );

static const Object _sentinel = Object();

  Map<String, dynamic> toJson() => {
        'plate': plate,
        'brand': brand,
        'model': model,
        'year': year,
        'dailyRate': dailyRate,
        'ownershipType': ownershipType.name,
        'purchasePrice': purchasePrice,
        'amortMonths': amortMonths,
        'rentMonthly': rentMonthly,
        'rentCompany': rentCompany,
        'vehicleType': vehicleType.name,
        'companyName': companyName,
        'insurerName': insurerName,
        'insuranceStart': insuranceStart?.toIso8601String(),
        'insuranceExpiry': insuranceExpiry?.toIso8601String(),
        'insuranceMonthly': insuranceMonthly,
        'ctDate': ctDate?.toIso8601String(),
        'ctExpiry': ctExpiry?.toIso8601String(),
        'repairs': repairs.map((e) => e.toJson()).toList(),
        'maintenances': maintenances.map((e) => e.toJson()).toList(),
        'monthlyKmThreshold': monthlyKmThreshold,
        'assignedDriverName': assignedDriverName,
        'truckStatus': truckStatus.name,
      };

  factory Truck.fromJson(Map<String, dynamic> json) => Truck(
        plate: json['plate'] as String,
        brand: json['brand'] as String? ?? '',
        model: json['model'] as String,
        year: json['year'] as int?,
        dailyRate: (json['dailyRate'] as num).toDouble(),
        ownershipType: OwnershipType.values.firstWhere(
          (e) => e.name == json['ownershipType'],
        ),
        purchasePrice: json['purchasePrice'] != null
            ? (json['purchasePrice'] as num).toDouble()
            : null,
        amortMonths: json['amortMonths'] as int?,
        rentMonthly: json['rentMonthly'] != null
            ? (json['rentMonthly'] as num).toDouble()
            : null,
        rentCompany: json['rentCompany'] as String?,
        vehicleType: json['vehicleType'] != null
            ? VehicleType.values.firstWhere(
                (e) => e.name == json['vehicleType'],
                orElse: () => VehicleType.vl,
              )
            : VehicleType.vl,
        companyName: json['companyName'] as String?,
        insurerName: json['insurerName'] as String?,
        insuranceStart: json['insuranceStart'] != null
            ? DateTime.parse(json['insuranceStart'] as String)
            : null,
        insuranceExpiry: json['insuranceExpiry'] != null
            ? DateTime.parse(json['insuranceExpiry'] as String)
            : null,
        insuranceMonthly: json['insuranceMonthly'] != null
            ? (json['insuranceMonthly'] as num).toDouble()
            : null,
        ctDate: json['ctDate'] != null
            ? DateTime.parse(json['ctDate'] as String)
            : null,
        ctExpiry: json['ctExpiry'] != null
            ? DateTime.parse(json['ctExpiry'] as String)
            : null,
        repairs: (json['repairs'] as List<dynamic>? ?? [])
            .map((e) => ServiceEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        maintenances: (json['maintenances'] as List<dynamic>? ?? [])
            .map((e) => ServiceEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        monthlyKmThreshold: json['monthlyKmThreshold'] != null
            ? (json['monthlyKmThreshold'] as num).toDouble()
            : null,
        assignedDriverName: json['assignedDriverName'] as String?,
        truckStatus: json['truckStatus'] != null
            ? TruckStatus.values.firstWhere(
                (e) => e.name == json['truckStatus'],
                orElse: () => TruckStatus.fonctionnel,
              )
            : TruckStatus.fonctionnel,
      );
}

// ── Page ajout / modification camion ─────────────────────────────────────────

class AddTruckPage extends StatefulWidget {
  final Truck? truck;

  const AddTruckPage({super.key, this.truck});

  @override
  State<AddTruckPage> createState() => _AddTruckPageState();
}

class _AddTruckPageState extends State<AddTruckPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _plateCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _modelCtrl;
  late final TextEditingController _yearCtrl;
  late final TextEditingController _rateCtrl;
  late final TextEditingController _purchaseCtrl;
  late final TextEditingController _amortCtrl;
  late final TextEditingController _rentCtrl;
  late final TextEditingController _rentCompanyCtrl;
  late final TextEditingController _companyCtrl;
  late final TextEditingController _insurerCtrl;
  late final TextEditingController _insuranceMonthlyCtrl;
  late final TextEditingController _monthlyKmThresholdCtrl;

  late OwnershipType _ownershipType;
  late VehicleType _vehicleType;
  late TruckStatus _truckStatus;
  DateTime? _insuranceStart;
  DateTime? _insuranceExpiry;
  DateTime? _ctDate;
  DateTime? _ctExpiry;

  late List<ServiceEntry> _repairs;
  late List<ServiceEntry> _maintenances;

  @override
  void initState() {
    super.initState();
    final t = widget.truck;
    _plateCtrl = TextEditingController(text: t?.plate ?? '');
    _brandCtrl = TextEditingController(text: t?.brand ?? '');
    _modelCtrl = TextEditingController(text: t?.model ?? '');
    _yearCtrl = TextEditingController(text: t?.year?.toString() ?? '');
    _rateCtrl = TextEditingController(
        text: t?.dailyRate.toStringAsFixed(0) ?? '230');
    _purchaseCtrl = TextEditingController(
      text: t?.purchasePrice != null
          ? t!.purchasePrice!.toStringAsFixed(0)
          : '',
    );
    _amortCtrl = TextEditingController(
      text: t?.amortMonths != null ? t!.amortMonths.toString() : '',
    );
    _rentCtrl = TextEditingController(
      text: t?.rentMonthly != null
          ? t!.rentMonthly!.toStringAsFixed(0)
          : '',
    );
    _rentCompanyCtrl = TextEditingController(text: t?.rentCompany ?? '');
    _companyCtrl = TextEditingController(text: t?.companyName ?? '');
    _insurerCtrl = TextEditingController(text: t?.insurerName ?? '');
    _insuranceMonthlyCtrl = TextEditingController(
      text: t?.insuranceMonthly != null
          ? t!.insuranceMonthly!.toStringAsFixed(0)
          : '',
    );
    _monthlyKmThresholdCtrl = TextEditingController(
      text: t?.monthlyKmThreshold != null
          ? t!.monthlyKmThreshold!.toStringAsFixed(0)
          : '',
    );
    _ownershipType = t?.ownershipType ?? OwnershipType.achat;
    _vehicleType = t?.vehicleType ?? VehicleType.vl;
    _truckStatus = t?.truckStatus ?? TruckStatus.fonctionnel;
    _insuranceStart = t?.insuranceStart;
    _insuranceExpiry = t?.insuranceExpiry;
    _ctDate = t?.ctDate;
    _ctExpiry = t?.ctExpiry;
    _repairs = List.from(t?.repairs ?? []);
    _maintenances = List.from(t?.maintenances ?? []);
  }

  @override
  void dispose() {
    _plateCtrl.dispose();
    _brandCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _rateCtrl.dispose();
    _purchaseCtrl.dispose();
    _amortCtrl.dispose();
    _rentCtrl.dispose();
    _rentCompanyCtrl.dispose();
    _companyCtrl.dispose();
    _insurerCtrl.dispose();
    _insuranceMonthlyCtrl.dispose();
    _monthlyKmThresholdCtrl.dispose();
    super.dispose();
  }

  double? _d(String s) => double.tryParse(s.replaceAll(',', '.').trim());
  int? _i(String s) => int.tryParse(s.trim());

  String _formatDate(DateTime? d) {
    if (d == null) return 'Non renseignée';
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }

  Future<DateTime?> _pickDate(DateTime? initial) async {
    return showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2040),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final plate = _plateCtrl.text.trim().toUpperCase();
    final brand = _brandCtrl.text.trim();
    final model = _modelCtrl.text.trim();
    final year = _i(_yearCtrl.text);
    final dailyRate = _d(_rateCtrl.text) ?? 0.0;
    final company = _companyCtrl.text.trim().isEmpty
        ? null
        : _companyCtrl.text.trim();
    final insurer = _insurerCtrl.text.trim().isEmpty
        ? null
        : _insurerCtrl.text.trim();
    final insuranceMonthly = _insuranceMonthlyCtrl.text.trim().isEmpty
        ? null
        : _d(_insuranceMonthlyCtrl.text);
    final monthlyKmThreshold = _monthlyKmThresholdCtrl.text.trim().isEmpty
        ? null
        : _d(_monthlyKmThresholdCtrl.text);

    if (_ownershipType == OwnershipType.achat) {
      final purchase = _purchaseCtrl.text.trim().isEmpty
          ? null
          : _d(_purchaseCtrl.text);
      final amort = _amortCtrl.text.trim().isEmpty
          ? null
          : _i(_amortCtrl.text);

      if ((purchase != null && amort == null) ||
          (purchase == null && amort != null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Achat: renseigne Prix d'achat + Durée amortissement."),
          ),
        );
        return;
      }

      Navigator.pop(
        context,
        Truck(
          plate: plate,
          brand: brand,
          model: model,
          year: year,
          dailyRate: dailyRate,
          ownershipType: OwnershipType.achat,
          purchasePrice: purchase,
          amortMonths: amort,
          vehicleType: _vehicleType,
          companyName: company,
          insurerName: insurer,
          insuranceStart: _insuranceStart,
          insuranceExpiry: _insuranceExpiry,
          insuranceMonthly: insuranceMonthly,
          ctDate: _ctDate,
          ctExpiry: _ctExpiry,
          repairs: _repairs,
          maintenances: _maintenances,
          monthlyKmThreshold: monthlyKmThreshold,
          truckStatus: _truckStatus,
        ),
      );
    } else {
      final rent = _d(_rentCtrl.text);
      if (rent == null || rent <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location: renseigne un loyer mensuel valide.'),
          ),
        );
        return;
      }
      final rentCompany = _rentCompanyCtrl.text.trim().isEmpty
          ? null
          : _rentCompanyCtrl.text.trim();

      Navigator.pop(
        context,
        Truck(
          plate: plate,
          brand: brand,
          model: model,
          year: year,
          dailyRate: dailyRate,
          ownershipType: OwnershipType.location,
          rentMonthly: rent,
          rentCompany: rentCompany,
          vehicleType: _vehicleType,
          companyName: company,
          insurerName: insurer,
          insuranceStart: _insuranceStart,
          insuranceExpiry: _insuranceExpiry,
          insuranceMonthly: insuranceMonthly,
          ctDate: _ctDate,
          ctExpiry: _ctExpiry,
          repairs: _repairs,
          maintenances: _maintenances,
          monthlyKmThreshold: monthlyKmThreshold,
          truckStatus: _truckStatus,
        ),
      );
    }
  }

  void _addServiceEntry(bool isRepair) async {
    final result = await showDialog<ServiceEntry>(
      context: context,
      builder: (_) => _ServiceEntryDialog(isRepair: isRepair),
    );
    if (result != null) {
      setState(() {
        if (isRepair) {
          _repairs = [..._repairs, result];
        } else {
          _maintenances = [..._maintenances, result];
        }
      });
    }
  }

  void _deleteServiceEntry(bool isRepair, String id) {
    setState(() {
      if (isRepair) {
        _repairs = _repairs.where((e) => e.id != id).toList();
      } else {
        _maintenances = _maintenances.where((e) => e.id != id).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.truck != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier le camion' : 'Ajouter un camion'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Identification ───────────────────────────────────────────
            _sectionTitle('Identification'),

            TextFormField(
              controller: _plateCtrl,
              enabled: !isEdit,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Plaque *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Plaque obligatoire' : null,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _brandCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Marque',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 100,
                  child: TextFormField(
                    controller: _yearCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Année',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _modelCtrl,
              decoration: const InputDecoration(
                labelText: 'Modèle *',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Modèle obligatoire' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<VehicleType>(
              value: _vehicleType,
              decoration: const InputDecoration(
                labelText: 'Type de véhicule',
                border: OutlineInputBorder(),
              ),
              items: VehicleType.values
                  .map((t) => DropdownMenuItem(
                        value: t,
                        child: Text(vehicleTypeLabel(t)),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _vehicleType = v ?? VehicleType.vl),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<TruckStatus>(
              value: _truckStatus,
              decoration: const InputDecoration(
                labelText: 'Statut du camion',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.build_circle_outlined),
              ),
              items: TruckStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: truckStatusColor(s),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(truckStatusLabel(s)),
                          ],
                        ),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _truckStatus = v ?? TruckStatus.fonctionnel),
            ),
            const SizedBox(height: 12),

            const SizedBox(height: 20),

            // ── Acquisition ──────────────────────────────────────────────
            _sectionTitle('Acquisition'),

            const Text(
              "Mode d'acquisition",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            Card(
              child: Column(
                children: [
                  RadioListTile<OwnershipType>(
                    title: const Text('Achat (amortissement)'),
                    value: OwnershipType.achat,
                    groupValue: _ownershipType,
                    onChanged: (v) => setState(() => _ownershipType = v!),
                  ),
                  RadioListTile<OwnershipType>(
                    title: const Text('Location / Leasing'),
                    value: OwnershipType.location,
                    groupValue: _ownershipType,
                    onChanged: (v) => setState(() => _ownershipType = v!),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (_ownershipType == OwnershipType.achat) ...[
              TextFormField(
                controller: _purchaseCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Prix d'achat (€) (optionnel)",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = _d(v);
                  if (val == null || val < 0) return 'Prix invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amortCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Durée amortissement (mois) (optionnel)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final val = int.tryParse(v.trim());
                  if (val == null || val <= 0) return 'Durée invalide';
                  return null;
                },
              ),
            ] else ...[
              TextFormField(
                controller: _rentCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Loyer mensuel (€) *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final val = _d(v ?? '');
                  if (_ownershipType == OwnershipType.location &&
                      (val == null || val <= 0)) {
                    return 'Loyer invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _rentCompanyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Société de location (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 20),

            // ── Assurance ────────────────────────────────────────────────
            _sectionTitle('Assurance'),

            TextFormField(
              controller: _insurerCtrl,
              decoration: const InputDecoration(
                labelText: "Nom de l'assureur (optionnel)",
                prefixIcon: Icon(Icons.shield_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _insuranceMonthlyCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Prime mensuelle assurance (€)',
                helperText:
                    'Inclus dans les coûts fixes du camion sur le dashboard',
                prefixIcon: Icon(Icons.euro_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _DatePickerTile(
                    label: 'Début assurance',
                    date: _insuranceStart,
                    onTap: () async {
                      final d = await _pickDate(_insuranceStart);
                      if (d != null) setState(() => _insuranceStart = d);
                    },
                    onClear: () => setState(() => _insuranceStart = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerTile(
                    label: 'Expiration assurance',
                    date: _insuranceExpiry,
                    isExpiry: true,
                    onTap: () async {
                      final d = await _pickDate(_insuranceExpiry);
                      if (d != null) setState(() => _insuranceExpiry = d);
                    },
                    onClear: () => setState(() => _insuranceExpiry = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Contrôle technique ──────────────────────────────────────
            _sectionTitle('Contrôle technique'),

            Row(
              children: [
                Expanded(
                  child: _DatePickerTile(
                    label: 'Date dernier CT',
                    date: _ctDate,
                    onTap: () async {
                      final d = await _pickDate(_ctDate);
                      if (d != null) setState(() => _ctDate = d);
                    },
                    onClear: () => setState(() => _ctDate = null),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DatePickerTile(
                    label: 'Expiration CT',
                    date: _ctExpiry,
                    isExpiry: true,
                    onTap: () async {
                      final d = await _pickDate(_ctExpiry);
                      if (d != null) setState(() => _ctExpiry = d);
                    },
                    onClear: () => setState(() => _ctExpiry = null),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Historique réparations ───────────────────────────────────
            _sectionTitle('Historique réparations'),
            _ServiceList(
              entries: _repairs,
              onAdd: () => _addServiceEntry(true),
              onDelete: (id) => _deleteServiceEntry(true, id),
            ),
            const SizedBox(height: 20),

            // ── Historique entretiens ────────────────────────────────────
            _sectionTitle('Historique entretiens'),
            _ServiceList(
              entries: _maintenances,
              onAdd: () => _addServiceEntry(false),
              onDelete: (id) => _deleteServiceEntry(false, id),
            ),
            const SizedBox(height: 28),

            FilledButton(
              onPressed: _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(isEdit ? 'Mettre à jour' : 'Enregistrer'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );

}

// ── Widget liste de service (réparations / entretiens) ────────────────────────

class _ServiceList extends StatelessWidget {
  const _ServiceList({
    required this.entries,
    required this.onAdd,
    required this.onDelete,
  });

  final List<ServiceEntry> entries;
  final VoidCallback onAdd;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Aucune entrée.',
                style: TextStyle(color: Colors.grey)),
          )
        else
          ...entries.map((e) => _ServiceTile(entry: e, onDelete: onDelete)),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add),
          label: const Text('Ajouter une entrée'),
        ),
      ],
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.entry, required this.onDelete});
  final ServiceEntry entry;
  final void Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    final d = entry.date;
    final dateStr = '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(entry.description),
        subtitle: Text(dateStr),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (entry.cost != null)
              Text(
                '${entry.cost!.toStringAsFixed(0)} €',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  size: 20, color: Colors.red),
              onPressed: () => onDelete(entry.id),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dialog ajout entrée service ───────────────────────────────────────────────

class _ServiceEntryDialog extends StatefulWidget {
  const _ServiceEntryDialog({required this.isRepair});
  final bool isRepair;

  @override
  State<_ServiceEntryDialog> createState() => _ServiceEntryDialogState();
}

class _ServiceEntryDialogState extends State<_ServiceEntryDialog> {
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _descCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isRepair ? 'Ajouter une réparation' : 'Ajouter un entretien'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.calendar_today_outlined),
            title: Text(_formatDate(_date)),
            subtitle: const Text('Date'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _date = d);
            },
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description *',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _costCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Coût (€) (optionnel)',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: () {
            if (_descCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              ServiceEntry(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                date: _date,
                description: _descCtrl.text.trim(),
                cost: double.tryParse(
                    _costCtrl.text.replaceAll(',', '.').trim()),
              ),
            );
          },
          child: const Text('Ajouter'),
        ),
      ],
    );
  }
}

// ── Widget date picker tile ───────────────────────────────────────────────────

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
    this.isExpiry = false,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool isExpiry;

  String _format(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _expiryColor() {
    if (date == null) return Colors.grey;
    final diff = date!.difference(DateTime.now()).inDays;
    if (diff < 0) return Colors.red;
    if (diff < 30) return Colors.orange;
    if (diff < 90) return Colors.amber;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final color = isExpiry ? _expiryColor() : null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: color ?? Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today_outlined,
                size: 16, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.grey)),
                  Text(
                    date != null ? _format(date!) : 'Sélectionner',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear, size: 16, color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}
