import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import '../utils/page_help.dart';
import 'models/client_pricing.dart';

class ManagerClientPricingPage extends ConsumerStatefulWidget {
  const ManagerClientPricingPage({super.key});

  @override
  ConsumerState<ManagerClientPricingPage> createState() =>
      _ManagerClientPricingPageState();
}

class _ManagerClientPricingPageState extends ConsumerState<ManagerClientPricingPage> {
  @override
  Widget build(BuildContext context) {
    final List<ClientPricing> clientPricings = [...ref.read(appStateProvider).clientPricings];

    clientPricings.sort(
      (a, b) => a.companyName.toLowerCase().compareTo(
            b.companyName.toLowerCase(),
          ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Commissionnaires'),
        actions: [
          helpButton(context, 'Commissionnaires',
            'Configurez vos commissionnaires et leurs tarifs.\n\n'
            '• À la fiche : forfait journalier et/ou tarif par fiche\n'
            '• Au point : forfait journalier et/ou tarif par colis\n'
            '• Ajoutez les options : gasoil, manutention, km sup.\n'
            '• Attribuez une couleur pour identifier rapidement'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddForm,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (clientPricings.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: const [
                    Icon(Icons.handshake_outlined, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Aucun commissionnaire',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ajoute un premier commissionnaire pour gérer tarifs et conditions.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...clientPricings.map(_buildClientCard),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildClientCard(ClientPricing pricing) {
    // Badges des options actives
    final List<_OptionBadge> badges = [
      _OptionBadge(
        label: billingModeLabel(pricing.billingMode),
        color: pricing.billingMode == BillingMode.auPoint ? Colors.indigo : Colors.teal,
      ),
    ];
    if (pricing.fuelIndexEnabled) {
      badges.add(_OptionBadge(
        label: 'Gasoil indexé',
        color: DC.warning,
      ));
    }
    if (pricing.extraKmEnabled) {
      badges.add(_OptionBadge(
        label: 'Extra km',
        color: DC.primary,
      ));
    }
    if (pricing.handlingEnabled) {
      badges.add(_OptionBadge(
        label: 'Manutention',
        color: DC.success,
      ));
    }
    if (pricing.extraTourEnabled) {
      badges.add(_OptionBadge(
        label: 'Tour sup.',
        color: Colors.purple,
      ));
    }

    // Nombre de chauffeurs affectés à ce commissionnaire
    final assignedDrivers = ref.watch(appStateProvider).assignments
        .where((a) => a.companyName?.toLowerCase() == pricing.companyName.toLowerCase())
        .length;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre + tarif
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: (pricing.colorValue != null
                          ? Color(pricing.colorValue!)
                          : DC.primary)
                      .withValues(alpha: 0.1),
                  child: Text(
                    pricing.companyName[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: pricing.colorValue != null
                            ? Color(pricing.colorValue!)
                            : DC.primary),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pricing.companyName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (pricing.siret != null && pricing.siret!.isNotEmpty)
                        Text(
                          'SIRET : ${pricing.siret}',
                          style: const TextStyle(fontSize: 11, color: DC.textSecondary),
                        ),
                      if (pricing.tvaIntra != null && pricing.tvaIntra!.isNotEmpty)
                        Text(
                          'TVA : ${pricing.tvaIntra}',
                          style: const TextStyle(fontSize: 11, color: DC.textSecondary),
                        ),
                      if (assignedDrivers > 0)
                        Text(
                          '$assignedDrivers chauffeur${assignedDrivers > 1 ? 's' : ''} affecté${assignedDrivers > 1 ? 's' : ''}',
                          style: const TextStyle(fontSize: 11, color: DC.textSecondary),
                        ),
                      // Aperçu chauffeurs + camions
                      ...ref.watch(appStateProvider).assignments
                          .where((a) => a.companyName?.toLowerCase() == pricing.companyName.toLowerCase())
                          .take(3)
                          .map((a) {
                        final truck = ref.read(appStateProvider).trucks
                            .where((t) => t.plate == a.truckPlate).firstOrNull;
                        return Text(
                          '${a.driverName} → ${a.truckPlate}${truck != null ? ' (${truck.model})' : ''}',
                          style: const TextStyle(fontSize: 10, color: DC.textSecondary),
                        );
                      }),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: DC.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    pricing.dailyRate > 0
                        ? '${pricing.dailyRate.toStringAsFixed(0)} €/j'
                        : pricing.billingMode == BillingMode.auPoint
                            ? '${pricing.pricePerPoint?.toStringAsFixed(2) ?? '—'} €/colis'
                            : '${pricing.pricePerPoint?.toStringAsFixed(2) ?? '—'} €/fiche',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: DC.primary,
                    ),
                  ),
                ),
              ],
            ),


            // ── Infos entreprise ──────────────────────────────────────────
            if (_hasCompanyInfo(pricing)) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (pricing.address != null && pricing.address!.isNotEmpty)
                      _infoLine(Icons.location_on_outlined, pricing.address!),
                    if (pricing.phone != null && pricing.phone!.isNotEmpty)
                      _infoLine(Icons.phone_outlined, pricing.phone!),
                    if (pricing.email != null && pricing.email!.isNotEmpty)
                      _infoLine(Icons.email_outlined, pricing.email!),
                    if (pricing.contactName != null && pricing.contactName!.isNotEmpty)
                      _infoLine(Icons.person_outline, pricing.contactName!),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // ── Grille tarifs détaillés ────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: Column(
                children: [
                  if (pricing.dailyRate > 0)
                    _priceLine('Forfait journalier', '${pricing.dailyRate.toStringAsFixed(2)} €/jour'),
                  if (pricing.pricePerPoint != null && pricing.pricePerPoint! > 0)
                    _priceLine(
                      pricing.billingMode == BillingMode.aLaFiche
                          ? 'Tarif par fiche'
                          : 'Tarif par colis',
                      '${pricing.pricePerPoint!.toStringAsFixed(2)} €',
                    ),
                  if (pricing.dailyRate > 0)
                    _priceLine('Estimation mois (22j)', '${(pricing.dailyRate * 22).toStringAsFixed(0)} € HT'),
                  if (pricing.handlingEnabled && pricing.handlingPrice != null)
                    _priceLine('Manutention', '${pricing.handlingPrice!.toStringAsFixed(2)} € / unité'),
                  if (pricing.extraKmEnabled && pricing.extraKmPrice != null)
                    _priceLine('Km supplémentaire', '${pricing.extraKmPrice!.toStringAsFixed(2)} € / km'),
                  if (pricing.extraTourEnabled && pricing.extraTourPrice != null)
                    _priceLine('Tour supplémentaire', '${pricing.extraTourPrice!.toStringAsFixed(2)} €'),
                  if (pricing.fuelIndexEnabled && pricing.fuelIndexPercent != null)
                    _priceLine('Indexation gasoil', '${pricing.fuelIndexPercent!.toStringAsFixed(1)} %'),
                ],
              ),
            ),

            // Options actives
            if (badges.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: badges,
              ),
            ],

            // Seuil km
            if (pricing.monthlyKmThreshold != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: DC.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: DC.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.speed_outlined,
                        size: 14, color: DC.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Seuil : ${pricing.monthlyKmThreshold!.toStringAsFixed(0)} km/mois'
                        '${pricing.overKmRate != null ? ' — ${pricing.overKmRate!.toStringAsFixed(2)} €/km au-delà' : ''}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: DC.warning,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Seuil de rentabilité
            if (pricing.breakEvenAmount != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: Colors.green.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.trending_up_outlined,
                        size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Seuil rentabilité : ${pricing.breakEvenAmount!.toStringAsFixed(0)} €/mois',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Note
            if (pricing.notes != null && pricing.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                pricing.notes!,
                style: const TextStyle(
                    fontSize: 12, color: DC.textSecondary),
              ),
            ],

            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditForm(pricing),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(pricing),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: DC.error,
                    side: const BorderSide(color: DC.error),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _hasCompanyInfo(ClientPricing p) =>
      (p.address != null && p.address!.isNotEmpty) ||
      (p.phone != null && p.phone!.isNotEmpty) ||
      (p.email != null && p.email!.isNotEmpty) ||
      (p.contactName != null && p.contactName!.isNotEmpty);

  Widget _infoLine(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.blue.shade400),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _priceLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: DC.textSecondary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _openAddForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClientPricingFormPage(
          onSave: (pricing) {
            final alreadyExists = ref.read(appStateProvider).clientPricings.any(
              (item) =>
                  item.companyName.toLowerCase() ==
                  pricing.companyName.toLowerCase(),
            );
            if (alreadyExists) {
              _showMessage('Ce commissionnaire existe déjà');
              return false;
            }
            setState(() {
              ref.read(appStateProvider).addClientPricing(pricing);
            });
            _showMessage('Commissionnaire ajouté');
            return true;
          },
        ),
      ),
    );
  }

  void _openEditForm(ClientPricing pricing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClientPricingFormPage(
          existing: pricing,
          onSave: (updated) {
            final duplicateExists = ref.read(appStateProvider).clientPricings.any(
              (item) =>
                  item.companyName.toLowerCase() ==
                      updated.companyName.toLowerCase() &&
                  item.companyName.toLowerCase() !=
                      pricing.companyName.toLowerCase(),
            );
            if (duplicateExists) {
              _showMessage('Un autre client porte déjà ce nom');
              return false;
            }
            setState(() {
              ref.read(appStateProvider).updateClientPricing(pricing.companyName, updated);
            });
            _showMessage('Commissionnaire modifié');
            return true;
          },
        ),
      ),
    );
  }

  void _confirmDelete(ClientPricing pricing) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Supprimer ce commissionnaire ?'),
          content: Text(
            'Supprimer le commissionnaire ${pricing.companyName} ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  ref.read(appStateProvider).deleteClientPricing(pricing.companyName);
                });
                Navigator.pop(context);
                _showMessage('Commissionnaire supprimé');
              },
              style: FilledButton.styleFrom(backgroundColor: DC.error),
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

// ── Widget badge option ───────────────────────────────────────────────────────

class _OptionBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _OptionBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

// ── Formulaire complet contrat client ────────────────────────────────────────

class _ClientPricingFormPage extends ConsumerStatefulWidget {
  final ClientPricing? existing;
  final bool Function(ClientPricing pricing) onSave;

  const _ClientPricingFormPage({
    this.existing,
    required this.onSave,
  });

  @override
  ConsumerState<_ClientPricingFormPage> createState() => _ClientPricingFormPageState();
}

class _ClientPricingFormPageState extends ConsumerState<_ClientPricingFormPage> {
  static const _colorOptions = [
    Colors.indigo,
    Colors.blue,
    Colors.teal,
    Colors.green,
    Colors.orange,
    Colors.red,
    Colors.purple,
    Colors.pink,
    Colors.brown,
    Colors.blueGrey,
  ];

  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _siretCtrl;
  late final TextEditingController _tvaIntraCtrl;
  late final TextEditingController _pricePerPointCtrl;
  late BillingMode _billingMode;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _contactCtrl;
  late final TextEditingController _dailyRateCtrl;
  late final TextEditingController _fuelIndexPercentCtrl;
  late final TextEditingController _extraKmPriceCtrl;
  late final TextEditingController _handlingPriceCtrl;
  late final TextEditingController _extraTourPriceCtrl;
  late final TextEditingController _monthlyKmThresholdCtrl;
  late final TextEditingController _overKmRateCtrl;
  late final TextEditingController _breakEvenCtrl;
  late final TextEditingController _notesCtrl;

  late bool _fuelIndexEnabled;
  late bool _extraKmEnabled;
  late bool _handlingEnabled;
  late bool _extraTourEnabled;
  late int? _colorValue;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.companyName ?? '');
    _siretCtrl = TextEditingController(text: e?.siret ?? '');
    _tvaIntraCtrl = TextEditingController(text: e?.tvaIntra ?? '');
    _pricePerPointCtrl = TextEditingController(
        text: e?.pricePerPoint?.toString() ?? '');
    _billingMode = e?.billingMode ?? BillingMode.aLaFiche;
    _addressCtrl = TextEditingController(text: e?.address ?? '');
    _phoneCtrl = TextEditingController(text: e?.phone ?? '');
    _emailCtrl = TextEditingController(text: e?.email ?? '');
    _contactCtrl = TextEditingController(text: e?.contactName ?? '');
    _dailyRateCtrl = TextEditingController(
        text: e != null ? e.dailyRate.toStringAsFixed(0) : '');
    _fuelIndexPercentCtrl = TextEditingController(
        text: e?.fuelIndexPercent?.toString() ?? '');
    _extraKmPriceCtrl = TextEditingController(
        text: e?.extraKmPrice?.toString() ?? '');
    _handlingPriceCtrl = TextEditingController(
        text: e?.handlingPrice?.toString() ?? '');
    _extraTourPriceCtrl = TextEditingController(
        text: e?.extraTourPrice?.toString() ?? '');
    _monthlyKmThresholdCtrl = TextEditingController(
        text: e?.monthlyKmThreshold?.toStringAsFixed(0) ?? '');
    _overKmRateCtrl = TextEditingController(
        text: e?.overKmRate?.toString() ?? '');
    _breakEvenCtrl = TextEditingController(
        text: e?.breakEvenAmount?.toStringAsFixed(0) ?? '');
    _notesCtrl = TextEditingController(text: e?.notes ?? '');

    _fuelIndexEnabled = e?.fuelIndexEnabled ?? false;
    _extraKmEnabled = e?.extraKmEnabled ?? false;
    _handlingEnabled = e?.handlingEnabled ?? false;
    _extraTourEnabled = e?.extraTourEnabled ?? false;
    _colorValue = e?.colorValue;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _siretCtrl.dispose();
    _tvaIntraCtrl.dispose();
    _pricePerPointCtrl.dispose();
    _addressCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _contactCtrl.dispose();
    _dailyRateCtrl.dispose();
    _fuelIndexPercentCtrl.dispose();
    _extraKmPriceCtrl.dispose();
    _handlingPriceCtrl.dispose();
    _extraTourPriceCtrl.dispose();
    _monthlyKmThresholdCtrl.dispose();
    _overKmRateCtrl.dispose();
    _breakEvenCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double? _d(String s) =>
      double.tryParse(s.replaceAll(',', '.').trim());

  String? _optionalPositive(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final val = _d(v);
    if (val == null || val < 0) return 'Valeur invalide';
    return null;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final dailyRate = _d(_dailyRateCtrl.text) ?? 0;
    final unitPrice = _d(_pricePerPointCtrl.text);
    if (dailyRate <= 0 && (unitPrice == null || unitPrice <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Renseignez au moins un tarif (journalier ou à l\'unité)')),
      );
      return;
    }

    String? _optStr(TextEditingController c) {
      final v = c.text.trim();
      return v.isEmpty ? null : v;
    }

    final pricing = ClientPricing(
      companyName: _nameCtrl.text.trim(),
      billingMode: _billingMode,
      pricePerPoint: unitPrice,
      siret: _optStr(_siretCtrl),
      tvaIntra: _optStr(_tvaIntraCtrl),
      address: _optStr(_addressCtrl),
      phone: _optStr(_phoneCtrl),
      email: _optStr(_emailCtrl),
      contactName: _optStr(_contactCtrl),
      dailyRate: dailyRate,
      fuelIndexEnabled: _fuelIndexEnabled,
      fuelIndexPercent:
          _fuelIndexEnabled ? _d(_fuelIndexPercentCtrl.text) : null,
      extraKmEnabled: _extraKmEnabled,
      extraKmPrice:
          _extraKmEnabled ? _d(_extraKmPriceCtrl.text) : null,
      handlingEnabled: _handlingEnabled,
      handlingPrice:
          _handlingEnabled ? _d(_handlingPriceCtrl.text) : null,
      extraTourEnabled: _extraTourEnabled,
      extraTourPrice:
          _extraTourEnabled ? _d(_extraTourPriceCtrl.text) : null,
      monthlyKmThreshold: _monthlyKmThresholdCtrl.text.trim().isNotEmpty
          ? _d(_monthlyKmThresholdCtrl.text)
          : null,
      overKmRate: _monthlyKmThresholdCtrl.text.trim().isNotEmpty &&
              _overKmRateCtrl.text.trim().isNotEmpty
          ? _d(_overKmRateCtrl.text)
          : null,
      breakEvenAmount: _breakEvenCtrl.text.trim().isNotEmpty
          ? _d(_breakEvenCtrl.text)
          : null,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      colorValue: _colorValue,
    );

    final success = widget.onSave(pricing);
    if (success) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Modifier le commissionnaire' : 'Nouveau commissionnaire'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Informations client ───────────────────────────────────────
            _sectionTitle('Informations commissionnaire'),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom commissionnaire / entreprise *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 12),

            // Couleur
            Row(
              children: [
                const Text('Couleur', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ..._colorOptions.map((c) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: GestureDetector(
                        onTap: () => setState(() => _colorValue = c.value),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _colorValue == c.value
                                  ? Colors.black87
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                          child: _colorValue == c.value
                              ? const Icon(Icons.check, size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
                    )),
                if (_colorValue != null)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18),
                    onPressed: () => setState(() => _colorValue = null),
                    tooltip: 'Aucune couleur',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _siretCtrl,
              decoration: const InputDecoration(
                labelText: 'SIRET',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _tvaIntraCtrl,
              decoration: const InputDecoration(
                labelText: 'N° TVA intracommunautaire',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance_outlined),
                hintText: 'FR12345678901',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on_outlined),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contactCtrl,
              decoration: const InputDecoration(
                labelText: 'Personne de contact',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 24),

            // ── Tarification ───────────────────────────────────────────
            _sectionTitle('Tarification'),

            // Mode de calcul
            const Text('Mode de calcul de la base',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<BillingMode>(
              segments: const [
                ButtonSegment(
                  value: BillingMode.aLaFiche,
                  label: Text('À la fiche'),
                  icon: Icon(Icons.description_outlined),
                ),
                ButtonSegment(
                  value: BillingMode.auPoint,
                  label: Text('Au point'),
                  icon: Icon(Icons.pin_drop_outlined),
                ),
              ],
              selected: {_billingMode},
              onSelectionChanged: (v) =>
                  setState(() => _billingMode = v.first),
            ),
            const SizedBox(height: 4),
            Text(
              _billingMode == BillingMode.aLaFiche
                  ? 'Facturation par fiche réalisée et/ou forfait journalier'
                  : 'Facturation par colis livré et/ou forfait journalier',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 16),

            // Forfait journalier — toujours visible, par défaut car le plus courant
            TextFormField(
              controller: _dailyRateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Forfait journalier (€/jour)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro_outlined),
                helperText: 'Le plus courant — laissez vide si facturation uniquement à l\'unité',
              ),
            ),
            const SizedBox(height: 12),

            // Prix par fiche ou par colis selon le mode
            TextFormField(
              controller: _pricePerPointCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _billingMode == BillingMode.aLaFiche
                    ? 'Tarif par fiche (€/fiche)'
                    : 'Tarif par colis (€/colis)',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(_billingMode == BillingMode.aLaFiche
                    ? Icons.description_outlined
                    : Icons.inventory_2_outlined),
                helperText: 'Laissez vide si forfait journalier uniquement',
              ),
            ),
            const SizedBox(height: 24),

            // ── Options contractuelles ────────────────────────────────────
            _sectionTitle('Options contractuelles'),

            // Indexation gasoil
            _OptionSwitch(
              title: 'Indexation gasoil',
              subtitle:
                  'Pourcentage d\'indexation appliqué au tarif',
              value: _fuelIndexEnabled,
              onChanged: (v) => setState(() => _fuelIndexEnabled = v),
              child: _fuelIndexEnabled
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextFormField(
                        controller: _fuelIndexPercentCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Indexation gasoil (%)',
                          border: OutlineInputBorder(),
                          suffixText: '%',
                        ),
                        validator: _optionalPositive,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),

            // Extra km
            _OptionSwitch(
              title: 'Extra kilomètres',
              subtitle: 'Facturation des km supplémentaires',
              value: _extraKmEnabled,
              onChanged: (v) => setState(() => _extraKmEnabled = v),
              child: _extraKmEnabled
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextFormField(
                        controller: _extraKmPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Prix km supplémentaire (€/km)',
                          border: OutlineInputBorder(),
                        ),
                        validator: _optionalPositive,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),

            // Manutention
            _OptionSwitch(
              title: 'Manutention',
              subtitle: 'Facturation unitaire des manutentions',
              value: _handlingEnabled,
              onChanged: (v) => setState(() => _handlingEnabled = v),
              child: _handlingEnabled
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextFormField(
                        controller: _handlingPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Prix unitaire manutention (€)',
                          border: OutlineInputBorder(),
                        ),
                        validator: _optionalPositive,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),

            // Tour supplémentaire
            _OptionSwitch(
              title: 'Tour supplémentaire',
              subtitle: 'Facturation des tournées supplémentaires',
              value: _extraTourEnabled,
              onChanged: (v) => setState(() => _extraTourEnabled = v),
              child: _extraTourEnabled
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextFormField(
                        controller: _extraTourPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Prix tour sup. (€)',
                          border: OutlineInputBorder(),
                        ),
                        validator: _optionalPositive,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 24),

            // ── Seuil kilométrique ────────────────────────────────────────
            _sectionTitle('Seuil kilométrique (optionnel)'),
            TextFormField(
              controller: _monthlyKmThresholdCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Seuil km mensuel',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.speed_outlined),
                helperText: 'Nombre de km max avant majoration',
              ),
              validator: _optionalPositive,
              onChanged: (_) => setState(() {}),
            ),
            if (_monthlyKmThresholdCtrl.text.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _overKmRateCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Tarif km au-delà (€/km)',
                  border: OutlineInputBorder(),
                ),
                validator: _optionalPositive,
              ),
            ],
            const SizedBox(height: 24),

            // ── Seuil de rentabilité ──────────────────────────────────────
            _sectionTitle('Seuil de rentabilité (optionnel)'),
            TextFormField(
              controller: _breakEvenCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Seuil de rentabilité (€/mois)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.trending_up_outlined),
                helperText: 'Montant minimum à facturer pour être rentable',
              ),
              validator: _optionalPositive,
            ),
            const SizedBox(height: 24),

            // ── Note ─────────────────────────────────────────────────────
            _sectionTitle('Note libre'),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Observations, conditions particulières...',
                border: OutlineInputBorder(),
              ),
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
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
}

// ── Widget switch avec enfant conditionnel ────────────────────────────────────

class _OptionSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? child;

  const _OptionSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(
          color: value
              ? DC.primary.withValues(alpha: 0.4)
              : DC.border,
        ),
        color: value
            ? DC.primary.withValues(alpha: 0.04)
            : Colors.transparent,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: DC.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
          if (value && child != null) child!,
        ],
      ),
    );
  }
}
