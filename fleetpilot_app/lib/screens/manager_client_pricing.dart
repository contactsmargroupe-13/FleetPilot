import 'package:flutter/material.dart';

import '../store/app_store.dart';
import '../utils/design_constants.dart';
import 'models/client_pricing.dart';

class ManagerClientPricingPage extends StatefulWidget {
  const ManagerClientPricingPage({super.key});

  @override
  State<ManagerClientPricingPage> createState() =>
      _ManagerClientPricingPageState();
}

class _ManagerClientPricingPageState extends State<ManagerClientPricingPage> {
  @override
  Widget build(BuildContext context) {
    final List<ClientPricing> clientPricings = [...AppStore.clientPricings];

    clientPricings.sort(
      (a, b) => a.companyName.toLowerCase().compareTo(
            b.companyName.toLowerCase(),
          ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Contrats clients')),
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
                      'Aucun contrat client',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Ajoute un premier contrat client pour gérer tarifs et conditions.',
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
    final List<_OptionBadge> badges = [];
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
                Expanded(
                  child: Text(
                    pricing.companyName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
                    '${pricing.dailyRate.toStringAsFixed(0)} €/j',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: DC.primary,
                    ),
                  ),
                ),
              ],
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.speed_outlined,
                        size: 14, color: DC.warning),
                    const SizedBox(width: 6),
                    Text(
                      'Seuil : ${pricing.monthlyKmThreshold!.toStringAsFixed(0)} km/mois'
                      '${pricing.overKmRate != null ? ' • ${pricing.overKmRate!.toStringAsFixed(2)} €/km au-delà' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: DC.warning,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_outlined,
                        size: 14, color: Colors.green),
                    const SizedBox(width: 6),
                    Text(
                      'Seuil rentabilité : ${pricing.breakEvenAmount!.toStringAsFixed(0)} €/mois',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green,
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

  void _openAddForm() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ClientPricingFormPage(
          onSave: (pricing) {
            final alreadyExists = AppStore.clientPricings.any(
              (item) =>
                  item.companyName.toLowerCase() ==
                  pricing.companyName.toLowerCase(),
            );
            if (alreadyExists) {
              _showMessage('Ce client existe déjà');
              return false;
            }
            setState(() {
              AppStore.addClientPricing(pricing);
            });
            _showMessage('Contrat client ajouté');
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
            final duplicateExists = AppStore.clientPricings.any(
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
              AppStore.updateClientPricing(pricing.companyName, updated);
            });
            _showMessage('Contrat client modifié');
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
          title: const Text('Supprimer ce contrat ?'),
          content: Text(
            'Supprimer le contrat de ${pricing.companyName} ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  AppStore.deleteClientPricing(pricing.companyName);
                });
                Navigator.pop(context);
                _showMessage('Contrat client supprimé');
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

class _ClientPricingFormPage extends StatefulWidget {
  final ClientPricing? existing;
  final bool Function(ClientPricing pricing) onSave;

  const _ClientPricingFormPage({
    this.existing,
    required this.onSave,
  });

  @override
  State<_ClientPricingFormPage> createState() => _ClientPricingFormPageState();
}

class _ClientPricingFormPageState extends State<_ClientPricingFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _dailyRateCtrl;
  late final TextEditingController _fuelRefPriceCtrl;
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

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.companyName ?? '');
    _dailyRateCtrl = TextEditingController(
        text: e != null ? e.dailyRate.toStringAsFixed(0) : '');
    _fuelRefPriceCtrl = TextEditingController(
        text: e?.fuelRefPrice?.toString() ?? '');
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
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dailyRateCtrl.dispose();
    _fuelRefPriceCtrl.dispose();
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final dailyRate = _d(_dailyRateCtrl.text);
    if (dailyRate == null || dailyRate <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tarif journalier invalide')),
      );
      return;
    }

    final pricing = ClientPricing(
      companyName: _nameCtrl.text.trim(),
      dailyRate: dailyRate,
      fuelIndexEnabled: _fuelIndexEnabled,
      fuelRefPrice:
          _fuelIndexEnabled ? _d(_fuelRefPriceCtrl.text) : null,
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
        title: Text(isEdit ? 'Modifier le contrat' : 'Nouveau contrat'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Informations client ───────────────────────────────────────
            _sectionTitle('Informations client'),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom client / entreprise *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business_outlined),
              ),
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Nom obligatoire' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _dailyRateCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Tarif journalier (€/j) *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.euro_outlined),
              ),
              validator: (v) {
                final val = _d(v ?? '');
                if (val == null || val <= 0) return 'Tarif invalide';
                return null;
              },
            ),
            const SizedBox(height: 24),

            // ── Options contractuelles ────────────────────────────────────
            _sectionTitle('Options contractuelles'),

            // Indexation gasoil
            _OptionSwitch(
              title: 'Indexation gasoil',
              subtitle:
                  'Ajustement tarifaire selon le prix du gazole',
              value: _fuelIndexEnabled,
              onChanged: (v) => setState(() => _fuelIndexEnabled = v),
              child: _fuelIndexEnabled
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: TextFormField(
                        controller: _fuelRefPriceCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Prix gazole référence (€/L)',
                          border: OutlineInputBorder(),
                        ),
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
