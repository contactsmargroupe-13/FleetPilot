import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import 'models/admin_document.dart';
import 'models/expense.dart';

class SmartScanPage extends ConsumerStatefulWidget {
  const SmartScanPage({super.key});

  @override
  ConsumerState<SmartScanPage> createState() => _SmartScanPageState();
}

class _SmartScanPageState extends ConsumerState<SmartScanPage> {
  bool _scanning = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _scan(ImageSource source) async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    final ext = xfile.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    setState(() {
      _scanning = true;
      _result = null;
      _error = null;
    });

    final result = await AiService.scanDocument(bytes, mimeType);

    if (!mounted) return;
    setState(() {
      _scanning = false;
      if (result.containsKey('error')) {
        _error = result['error'] as String;
      } else {
        _result = result;
      }
    });
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'carburant':
        return 'Ticket carburant';
      case 'assurance':
        return 'Contrat d\'assurance';
      case 'facture':
        return 'Facture / Prestataire';
      case 'contrat':
        return 'Contrat';
      case 'fiche_paie':
        return 'Fiche de paie';
      case 'amende':
        return 'Amende';
      default:
        return 'Document';
    }
  }

  IconData _typeIcon(String? type) {
    switch (type) {
      case 'carburant':
        return Icons.local_gas_station;
      case 'assurance':
        return Icons.shield_outlined;
      case 'facture':
        return Icons.receipt_long;
      case 'contrat':
        return Icons.description;
      case 'fiche_paie':
        return Icons.payments;
      case 'amende':
        return Icons.gavel;
      default:
        return Icons.document_scanner;
    }
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'carburant':
        return Colors.orange;
      case 'assurance':
        return Colors.blue;
      case 'facture':
        return Colors.purple;
      case 'contrat':
        return Colors.teal;
      case 'fiche_paie':
        return Colors.green;
      case 'amende':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _saveAsExpense() {
    if (_result == null) return;

    final type = _result!['type'] as String?;
    final amount = _result!['montant'];
    final plate = _result!['immatriculation'] as String?;

    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant non détecté')),
      );
      return;
    }

    DateTime? date;
    try {
      if (_result!['date'] != null) date = DateTime.parse(_result!['date']);
    } catch (_) {}

    ExpenseType expType;
    switch (type) {
      case 'carburant':
        expType = ExpenseType.fuel;
        break;
      case 'facture':
        expType = ExpenseType.repair;
        break;
      default:
        expType = ExpenseType.other;
    }

    // Trouver la plaque
    String? truckPlate = plate;
    final trucks = ref.read(appStateProvider).trucks;
    if (truckPlate != null) {
      final match = trucks.where((t) =>
          t.plate.replaceAll('-', '').replaceAll(' ', '').toLowerCase() ==
          truckPlate!.replaceAll('-', '').replaceAll(' ', '').toLowerCase());
      if (match.isNotEmpty) truckPlate = match.first.plate;
    }
    truckPlate ??= trucks.isNotEmpty ? trucks.first.plate : '';

    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date ?? DateTime.now(),
      truckPlate: truckPlate,
      type: expType,
      amount: (amount as num).toDouble(),
      liters: _result!['litres'] != null
          ? (_result!['litres'] as num).toDouble()
          : null,
      note: _result!['description'] as String? ??
          _result!['fournisseur'] as String?,
    );

    ref.read(appStateProvider).addExpense(expense);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Dépense enregistrée : ${expense.amount.toStringAsFixed(2)} €'),
        backgroundColor: Colors.green,
      ),
    );
    setState(() => _result = null);
  }

  void _saveAsAdminDoc() {
    if (_result == null) return;

    final type = _result!['type'] as String?;
    final plate = _result!['immatriculation'] as String?;
    final person = _result!['personne'] as String?;

    DateTime? date;
    try {
      if (_result!['date'] != null) date = DateTime.parse(_result!['date']);
    } catch (_) {}

    AdminDocCategory category;
    switch (type) {
      case 'assurance':
        category = AdminDocCategory.assurance;
        break;
      case 'contrat':
        category = AdminDocCategory.contratLocation;
        break;
      case 'fiche_paie':
        category = AdminDocCategory.fichePaie;
        break;
      case 'facture':
        category = AdminDocCategory.facturePrestataire;
        break;
      default:
        category = AdminDocCategory.other;
    }

    final doc = AdminDocument(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _result!['fournisseur'] as String? ??
          _result!['description'] as String? ??
          _typeLabel(type),
      category: category,
      date: date ?? DateTime.now(),
      linkedTruckPlate: plate,
      linkedDriverName: person,
      note: _result!['description'] as String?,
    );

    ref.read(appStateProvider).addAdminDocument(doc);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Document classé dans ${adminDocCategoryLabel(category)}'),
        backgroundColor: Colors.green,
      ),
    );
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Text('📸', style: TextStyle(fontSize: 22)),
            SizedBox(width: 8),
            Text('Scan intelligent'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Scannez n\'importe quel document : ticket, facture, contrat, fiche de paie...\n'
            'L\'IA identifie le type et extrait les informations.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Boutons scan
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _scanning ? null : () => _scan(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Photo'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _scanning ? null : () => _scan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Galerie'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Loading
          if (_scanning)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Analyse du document...',
                        style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
            ),

          // Erreur
          if (_error != null)
            Card(
              color: Colors.red.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_error!)),
                  ],
                ),
              ),
            ),

          // Résultat
          if (_result != null) ...[
            _buildResultCard(),
            const SizedBox(height: 12),
            _buildActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    final type = _result!['type'] as String?;
    final color = _typeColor(type);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type détecté
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_typeIcon(type), color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_typeLabel(type),
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: color)),
                      const Text('Document identifié par l\'IA',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Champs extraits
            if (_result!['montant'] != null)
              _field('Montant', '${(_result!['montant'] as num).toStringAsFixed(2)} €'),
            if (_result!['date'] != null) _field('Date', _result!['date']),
            if (_result!['fournisseur'] != null)
              _field('Fournisseur', _result!['fournisseur']),
            if (_result!['description'] != null)
              _field('Description', _result!['description']),
            if (_result!['immatriculation'] != null)
              _field('Camion', _result!['immatriculation']),
            if (_result!['personne'] != null)
              _field('Personne', _result!['personne']),
            if (_result!['date_debut'] != null)
              _field('Début', _result!['date_debut']),
            if (_result!['date_fin'] != null)
              _field('Fin', _result!['date_fin']),
            if (_result!['litres'] != null)
              _field('Litres', '${(_result!['litres'] as num).toStringAsFixed(2)}'),
            if (_result!['station'] != null)
              _field('Station', _result!['station']),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(fontSize: 13, color: Colors.grey)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _buildActions() {
    final type = _result!['type'] as String?;
    final hasAmount = _result!['montant'] != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Que voulez-vous faire ?',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
        const SizedBox(height: 8),
        if (hasAmount)
          FilledButton.icon(
            onPressed: _saveAsExpense,
            icon: const Icon(Icons.receipt_long_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Ajouter dans les dépenses'),
            ),
          ),
        if (hasAmount) const SizedBox(height: 8),
        FilledButton.tonalIcon(
          onPressed: _saveAsAdminDoc,
          icon: const Icon(Icons.folder_outlined),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('Classer dans Administratif'),
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => setState(() {
            _result = null;
            _error = null;
          }),
          icon: const Icon(Icons.refresh),
          label: const Text('Scanner un autre document'),
        ),
      ],
    );
  }
}
