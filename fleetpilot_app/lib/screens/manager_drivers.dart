import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'models/driver.dart';
import 'models/driver_document.dart';

class ManagerDriversPage extends ConsumerStatefulWidget {
  const ManagerDriversPage({super.key});

  @override
  ConsumerState<ManagerDriversPage> createState() => _ManagerDriversPageState();
}

class _ManagerDriversPageState extends ConsumerState<ManagerDriversPage> {

  // ── Navigation vers page chauffeur ───────────────────────────────────────

  Future<void> _openDriverPage(Driver? existing) async {
    final result = await Navigator.push<Driver>(
      context,
      MaterialPageRoute(
        builder: (_) => _DriverFormPage(driver: existing),
      ),
    );
    if (result == null) return;

    setState(() {
      if (existing == null) {
        ref.read(appStateProvider).addDriver(result);
        _msg('Chauffeur ajouté');
      } else {
        ref.read(appStateProvider).updateDriver(existing.name, result);
        _msg('Chauffeur modifié');
      }
    });
  }

  void _confirmDelete(Driver driver) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le chauffeur ?'),
        content: Text('Supprimer ${driver.name} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => ref.read(appStateProvider).deleteDriver(driver.name));
              Navigator.pop(context);
              _msg('Chauffeur supprimé');
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ── Documents administratifs ─────────────────────────────────────────────

  void _openDocuments(Driver driver) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DocumentsSheet(driverName: driver.name),
    ).then((_) => setState(() {}));
  }

  Widget? _alertBadge(String driverName) {
    final docs = ref.read(appStateProvider).documentsForDriver(driverName);
    final expired = docs.where((d) => d.isExpired).length;
    final soon = docs.where((d) => d.isExpiringSoon).length;

    if (expired > 0) return _badge('$expired expiré(s)', Colors.red);
    if (soon > 0) return _badge('$soon à renouveler', Colors.orange);
    return null;
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final drivers = [...ref.read(appStateProvider).drivers]
      ..sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openDriverPage(null),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Chauffeurs',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          if (drivers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucun chauffeur. Cliquez sur Ajouter.'),
              ),
            )
          else
            ...drivers.map((d) => _buildDriverCard(d)),

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildDriverCard(Driver driver) {
    final alert = _alertBadge(driver.name);

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête nom + alerte
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(driver.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17)),
                          const SizedBox(width: 8),
                          _statusBadge(driver.status),
                          if (alert != null) ...[
                            const SizedBox(width: 8),
                            alert,
                          ],
                        ],
                      ),
                      if (driver.phone != null)
                        Text(driver.phone!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                // Badge permis
                if (driver.hasPermisB ||
                    driver.hasPermisC ||
                    driver.hasPermisCE)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Permis ${driver.permisLabel}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Stats
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _box('Salaire fixe',
                    '${driver.fixedSalary.toStringAsFixed(0)} €',
                    Icons.payments_outlined),
                _box('Bonus',
                    '${driver.bonus.toStringAsFixed(0)} €',
                    Icons.workspace_premium_outlined),
                _box('Total mensuel',
                    '${driver.totalSalary.toStringAsFixed(0)} €',
                    Icons.account_balance_wallet_outlined),
              ],
            ),
            const SizedBox(height: 14),

            // Actions
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openDocuments(driver),
                  icon: const Icon(Icons.folder_outlined),
                  label: const Text('Documents'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _openDriverPage(driver),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(driver),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(String label, String value, IconData icon, {bool highlight = false}) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: highlight ? Colors.blue.withValues(alpha: 0.5) : Colors.black12,
        ),
        color: highlight ? Colors.blue.withValues(alpha: 0.07) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: highlight ? Colors.blue : null),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: highlight ? Colors.blue : null)),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: highlight ? Colors.blue : null)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(DriverStatus status) {
    final colorStr = driverStatusColor(status);
    final Color color;
    switch (colorStr) {
      case 'green':
        color = Colors.green;
        break;
      case 'blue':
        color = Colors.blue;
        break;
      case 'orange':
        color = Colors.orange;
        break;
      case 'red':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        driverStatusLabel(status),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  void _msg(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Page formulaire chauffeur ─────────────────────────────────────────────────

class _DriverFormPage extends ConsumerStatefulWidget {
  final Driver? driver;
  const _DriverFormPage({this.driver});

  @override
  ConsumerState<_DriverFormPage> createState() => _DriverFormPageState();
}

class _DriverFormPageState extends ConsumerState<_DriverFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _salaryCtrl;
  late final TextEditingController _bonusCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _ssCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _nationalityCtrl;
  late final TextEditingController _emergencyContactCtrl;
  late final TextEditingController _emergencyPhoneCtrl;
  late final TextEditingController _licenseNumberCtrl;

  DateTime? _birthDate;
  DateTime? _hireDate;
  DateTime? _licenseExpiryDate;
  late bool _permisB;
  late bool _permisC;
  late bool _permisCE;
  late bool _permisD;
  late bool _permisEB;
  late DriverStatus _status;

  @override
  void initState() {
    super.initState();
    final d = widget.driver;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _firstNameCtrl = TextEditingController(text: d?.firstName ?? '');
    _salaryCtrl = TextEditingController(
        text: d?.fixedSalary != null
            ? d!.fixedSalary.toStringAsFixed(0)
            : '');
    _bonusCtrl = TextEditingController(
        text: d?.bonus != null && d!.bonus > 0
            ? d.bonus.toStringAsFixed(0)
            : '');
    _phoneCtrl = TextEditingController(text: d?.phone ?? '');
    _emailCtrl = TextEditingController(text: d?.email ?? '');
    _ssCtrl = TextEditingController(text: d?.socialSecurityNumber ?? '');
    _addressCtrl = TextEditingController(text: d?.address ?? '');
    _nationalityCtrl = TextEditingController(text: d?.nationality ?? '');
    _emergencyContactCtrl = TextEditingController(text: d?.emergencyContact ?? '');
    _emergencyPhoneCtrl = TextEditingController(text: d?.emergencyPhone ?? '');
    _licenseNumberCtrl = TextEditingController(text: d?.licenseNumber ?? '');
    _birthDate = d?.birthDate;
    _hireDate = d?.hireDate;
    _licenseExpiryDate = d?.licenseExpiryDate;
    _permisB = d?.hasPermisB ?? false;
    _permisC = d?.hasPermisC ?? false;
    _permisCE = d?.hasPermisCE ?? false;
    _permisD = d?.hasPermisD ?? false;
    _permisEB = d?.hasPermisEB ?? false;
    _status = d?.status ?? DriverStatus.cdi;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _firstNameCtrl.dispose();
    _salaryCtrl.dispose();
    _bonusCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ssCtrl.dispose();
    _addressCtrl.dispose();
    _nationalityCtrl.dispose();
    _emergencyContactCtrl.dispose();
    _emergencyPhoneCtrl.dispose();
    _licenseNumberCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  double _parseDouble(String s) =>
      double.tryParse(s.replaceAll(',', '.').trim()) ?? 0.0;

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final isEdit = widget.driver != null;

    final duplicate = ref.read(appStateProvider).drivers.any((d) =>
        d.name.toLowerCase() == name.toLowerCase() &&
        d.name.toLowerCase() !=
            (widget.driver?.name ?? '').toLowerCase());
    if (duplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Un chauffeur avec ce nom existe déjà')),
      );
      return;
    }

    Navigator.pop(
      context,
      Driver(
        name: name,
        firstName: _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
        fixedSalary: _parseDouble(_salaryCtrl.text),
        bonus: _parseDouble(_bonusCtrl.text),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
        socialSecurityNumber: _ssCtrl.text.trim().isEmpty ? null : _ssCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
        nationality: _nationalityCtrl.text.trim().isEmpty ? null : _nationalityCtrl.text.trim(),
        emergencyContact: _emergencyContactCtrl.text.trim().isEmpty ? null : _emergencyContactCtrl.text.trim(),
        emergencyPhone: _emergencyPhoneCtrl.text.trim().isEmpty ? null : _emergencyPhoneCtrl.text.trim(),
        licenseNumber: _licenseNumberCtrl.text.trim().isEmpty ? null : _licenseNumberCtrl.text.trim(),
        licenseExpiryDate: _licenseExpiryDate,
        birthDate: _birthDate,
        hireDate: _hireDate,
        hasPermisB: _permisB,
        hasPermisC: _permisC,
        hasPermisCE: _permisCE,
        hasPermisD: _permisD,
        hasPermisEB: _permisEB,
        status: _status,
        pinHash: widget.driver?.pinHash,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.driver != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit
            ? 'Modifier ${widget.driver!.name}'
            : 'Ajouter un chauffeur'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Identité ────────────────────────────────────────────────
            _sectionTitle('Identité'),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Prénom',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Nom obligatoire' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _addressCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Adresse',
                prefixIcon: Icon(Icons.home_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            // Date de naissance
            _DateTile(
              label: 'Date de naissance',
              date: _birthDate,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _birthDate ??
                      DateTime.now()
                          .subtract(const Duration(days: 365 * 30)),
                  firstDate: DateTime(1940),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _birthDate = d);
              },
              onClear: () => setState(() => _birthDate = null),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _nationalityCtrl,
              decoration: const InputDecoration(
                labelText: 'Nationalité',
                prefixIcon: Icon(Icons.flag_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _ssCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'N° Sécurité sociale',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Contact d'urgence ───────────────────────────────────────
            _sectionTitle('Contact d\'urgence'),

            TextFormField(
              controller: _emergencyContactCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du contact',
                prefixIcon: Icon(Icons.emergency_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _emergencyPhoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone d\'urgence',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            // ── Statut contractuel ──────────────────────────────────────
            _sectionTitle('Statut contractuel'),

            DropdownButtonFormField<DriverStatus>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Statut *',
                prefixIcon: Icon(Icons.work_outline),
                border: OutlineInputBorder(),
              ),
              items: DriverStatus.values
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(driverStatusLabel(s)),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 20),

            // ── Permis ──────────────────────────────────────────────────
            _sectionTitle('Permis de conduire'),

            TextFormField(
              controller: _licenseNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'N° de permis',
                prefixIcon: Icon(Icons.credit_card_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

            _DateTile(
              label: 'Date d\'expiration du permis',
              date: _licenseExpiryDate,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _licenseExpiryDate ?? DateTime.now().add(const Duration(days: 365 * 5)),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2050),
                );
                if (d != null) setState(() => _licenseExpiryDate = d);
              },
              onClear: () => setState(() => _licenseExpiryDate = null),
            ),
            const SizedBox(height: 12),

            Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Permis B'),
                    value: _permisB,
                    onChanged: (v) => setState(() => _permisB = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Permis C'),
                    value: _permisC,
                    onChanged: (v) => setState(() => _permisC = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Permis CE (Super lourd)'),
                    value: _permisCE,
                    onChanged: (v) => setState(() => _permisCE = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Permis D (Transport de personnes)'),
                    value: _permisD,
                    onChanged: (v) => setState(() => _permisD = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Permis EB (Remorque)'),
                    value: _permisEB,
                    onChanged: (v) => setState(() => _permisEB = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Emploi ──────────────────────────────────────────────────
            _sectionTitle('Emploi'),

            _DateTile(
              label: 'Date d\'embauche',
              date: _hireDate,
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _hireDate ?? DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (d != null) setState(() => _hireDate = d);
              },
              onClear: () => setState(() => _hireDate = null),
            ),
            const SizedBox(height: 20),

            // ── Rémunération ─────────────────────────────────────────────
            _sectionTitle('Rémunération'),

            TextFormField(
              controller: _salaryCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Salaire fixe (€)',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final val = double.tryParse(v.replaceAll(',', '.').trim());
                if (val == null || val < 0) return 'Montant invalide';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bonusCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Bonus (€)',
                prefixIcon: Icon(Icons.workspace_premium_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final val = double.tryParse(v.replaceAll(',', '.').trim());
                if (val == null || val < 0) return 'Montant invalide';
                return null;
              },
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
        child: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

// ── Widget date tile ──────────────────────────────────────────────────────────

class _DateTile extends StatelessWidget {
  const _DateTile({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.grey)),
                  Text(
                    date != null ? _fmt(date!) : 'Non renseignée',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: date != null ? null : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.clear, size: 16,
                    color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Feuille documents ─────────────────────────────────────────────────────────

class _DocumentsSheet extends ConsumerStatefulWidget {
  final String driverName;
  const _DocumentsSheet({required this.driverName});

  @override
  ConsumerState<_DocumentsSheet> createState() => _DocumentsSheetState();
}

class _DocumentsSheetState extends ConsumerState<_DocumentsSheet> {
  // Types ordonnés par catégorie pour la sélection
  static const _orderedTypes = [
    DocumentType.permisB,
    DocumentType.permisC,
    DocumentType.permisCE,
    DocumentType.fimo,
    DocumentType.fco,
    DocumentType.adr,
    DocumentType.adrCiterne,
    DocumentType.hayon,
    DocumentType.grueAuxiliaire,
    DocumentType.cacesGrue,
    DocumentType.cacesChariot,
    DocumentType.ecoConduite,
    DocumentType.securiteTransport,
    DocumentType.atr,
    DocumentType.assurance,
    DocumentType.contrat,
    DocumentType.other,
  ];

  void _openDocumentDialog(DriverDocument? existing) {
    DocumentType selectedType =
        existing?.type ?? DocumentType.permisB;
    final numCtrl =
        TextEditingController(text: existing?.documentNumber ?? '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    DateTime? issueDate = existing?.issueDate;
    DateTime? expiryDate = existing?.expiryDate;

    String fmt(DateTime? d) {
      if (d == null) return '—';
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    }

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(existing == null
              ? 'Ajouter un document'
              : 'Modifier le document'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<DocumentType>(
                    value: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Type de document',
                      border: OutlineInputBorder(),
                    ),
                    items: _orderedTypes
                        .map((t) => DropdownMenuItem(
                              value: t,
                              child: Text(documentTypeLabel(t)),
                            ))
                        .toList(),
                    onChanged: (v) => setDialog(
                        () => selectedType = v ?? selectedType),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: numCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Numéro (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: issueDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setDialog(() => issueDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text("Obtention : ${fmt(issueDate)}"),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: expiryDate ??
                            DateTime.now()
                                .add(const Duration(days: 365)),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2200),
                      );
                      if (picked != null) {
                        setDialog(() => expiryDate = picked);
                      }
                    },
                    icon: const Icon(Icons.event_busy_outlined,
                        size: 16),
                    label: Text("Expiration : ${fmt(expiryDate)}"),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Note (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final doc = DriverDocument(
                  id: existing?.id ??
                      DateTime.now().microsecondsSinceEpoch.toString(),
                  driverName: widget.driverName,
                  type: selectedType,
                  documentNumber: numCtrl.text.trim().isEmpty
                      ? null
                      : numCtrl.text.trim(),
                  issueDate: issueDate,
                  expiryDate: expiryDate,
                  note: noteCtrl.text.trim().isEmpty
                      ? null
                      : noteCtrl.text.trim(),
                );
                setState(() {
                  if (existing == null) {
                    ref.read(appStateProvider).addDriverDocument(doc);
                  } else {
                    ref.read(appStateProvider).updateDriverDocument(existing.id, doc);
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteDocument(DriverDocument doc) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le document ?'),
        content: Text(documentTypeLabel(doc.type)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => ref.read(appStateProvider).deleteDriverDocument(doc.id));
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDocs = ref.read(appStateProvider).documentsForDriver(widget.driverName);

    // Regrouper par catégorie
    final Map<String, List<DriverDocument>> grouped = {};
    for (final doc in allDocs) {
      final cat = documentTypeCategory(doc.type);
      grouped.putIfAbsent(cat, () => []).add(doc);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Documents — ${widget.driverName}',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _openDocumentDialog(null),
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (allDocs.isEmpty)
            const Center(
                child: Text('Aucun document enregistré.'))
          else
            for (final cat in grouped.keys) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(cat,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey)),
              ),
              ...grouped[cat]!.map((doc) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _DocumentTile(
                      doc: doc,
                      onEdit: () => _openDocumentDialog(doc),
                      onDelete: () => _deleteDocument(doc),
                    ),
                  )),
            ],
        ],
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final DriverDocument doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DocumentTile({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
  });

  String _fmt(DateTime? d) {
    if (d == null) return '—';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final level = doc.alertLevel;
    final Color borderColor;
    final Color bgColor;
    final Widget statusWidget;

    switch (level) {
      case 'expired':
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.06);
        statusWidget =
            _statusChip('Expiré', Colors.red, Icons.error_outline);
        break;
      case 'warning':
        borderColor = Colors.orange;
        bgColor = Colors.orange.withValues(alpha: 0.06);
        statusWidget = _statusChip(
            'Expire dans ${doc.daysUntilExpiry}j',
            Colors.orange,
            Icons.warning_amber_outlined);
        break;
      case 'ok':
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.04);
        statusWidget =
            _statusChip('Valide', Colors.green, Icons.check_circle_outline);
        break;
      default:
        borderColor = Colors.black12;
        bgColor = Colors.transparent;
        statusWidget = const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(documentTypeLabel(doc.type),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
              statusWidget,
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
          if (doc.documentNumber != null)
            Text('N° ${doc.documentNumber}',
                style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 16,
            children: [
              Text("Obtention : ${_fmt(doc.issueDate)}",
                  style: const TextStyle(fontSize: 12)),
              Text("Expiration : ${_fmt(doc.expiryDate)}",
                  style: const TextStyle(fontSize: 12)),
            ],
          ),
          if (doc.note != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(doc.note!,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.black54)),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color, IconData icon) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

