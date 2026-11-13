import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/expense.dart';
import '../services/ocr_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';

class AddExpensePage extends ConsumerStatefulWidget {
  final Expense? existing;
  const AddExpensePage({super.key, this.existing});

  @override
  ConsumerState<AddExpensePage> createState() => _AddExpensePageState();
}

class _AddExpensePageState extends ConsumerState<AddExpensePage> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedPlate;
  ExpenseType _type = ExpenseType.fuel;
  DateTime _selectedDate = DateTime.now();
  double? _vatRate; // null = taux habituel du type
  String? _driverName;

  final _amountCtrl = TextEditingController();
  final _litersCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  bool _isScanning = false;
  Uint8List? _imagePreview;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final e = widget.existing!;
      _selectedPlate = e.truckPlate;
      _type = e.type;
      _selectedDate = e.date;
      _amountCtrl.text = e.amount.toStringAsFixed(2);
      if (e.liters != null) _litersCtrl.text = e.liters!.toStringAsFixed(2);
      if (e.note != null) _noteCtrl.text = e.note!;
      _vatRate = e.vatRate;
      _driverName = e.driverName;
    } else if (ref.read(appStateProvider).trucks.isNotEmpty) {
      _selectedPlate = ref.read(appStateProvider).trucks.first.plate;
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _litersCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  double? _d(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  String _fmt(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    final ext = xfile.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    setState(() {
      _isScanning = true;
      _imagePreview = bytes;
    });

    final result = await OcrService.analyze(bytes, mimeType);
    if (!mounted) return;

    if (result.error != null) {
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error!),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }

    setState(() {
      _isScanning = false;
      if (result.amount != null) {
        _amountCtrl.text = result.amount!.toStringAsFixed(2);
      }
      if (result.liters != null) {
        _type = ExpenseType.fuel;
        _litersCtrl.text = result.liters!.toStringAsFixed(2);
      }
      if (result.date != null) {
        _selectedDate = result.date!;
      }
      if (result.station != null) {
        _noteCtrl.text = 'Carburant - ${result.station}';
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ticket analysé — vérifiez et validez.')),
    );
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final amount = _d(_amountCtrl.text)!;
    final liters =
        _litersCtrl.text.trim().isEmpty ? null : _d(_litersCtrl.text);

    final expense = Expense(
      id: _isEditing ? widget.existing!.id : DateTime.now().millisecondsSinceEpoch.toString(),
      date: _selectedDate,
      truckPlate: _selectedPlate!,
      type: _type,
      amount: amount,
      liters: _type == ExpenseType.fuel ? liters : null,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      vatRate: _vatRate,
      driverName: _driverName,
    );

    Navigator.pop(context, expense);
  }

  @override
  Widget build(BuildContext context) {
    final trucks = ref.read(appStateProvider).trucks;

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Modifier la dépense' : 'Ajouter une dépense')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // ── Scan ticket ─────────────────────────────────────────────
              FilledButton.icon(
                onPressed: _isScanning ? null : _scanReceipt,
                icon: _isScanning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.document_scanner_outlined),
                label: Text(
                  _isScanning ? 'Analyse en cours...' : 'Scanner le ticket',
                ),
              ),

              // Aperçu image
              if (_imagePreview != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    _imagePreview!,
                    height: 160,
                    fit: BoxFit.cover,
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Date ────────────────────────────────────────────────────
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today),
                label: Text('Date : ${_fmt(_selectedDate)}'),
              ),
              const SizedBox(height: 12),

              // ── Camion ───────────────────────────────────────────────────
              DropdownButtonFormField<String>(
                value: _selectedPlate,
                decoration: const InputDecoration(
                  labelText: 'Camion',
                  border: OutlineInputBorder(),
                ),
                items: trucks
                    .map((t) => DropdownMenuItem(
                          value: t.plate,
                          child: Text('${t.plate} • ${t.model}'),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _selectedPlate = v),
                validator: (v) => v == null ? 'Choisis un camion' : null,
              ),
              const SizedBox(height: 12),

              // ── Type ─────────────────────────────────────────────────────
              DropdownButtonFormField<ExpenseType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Type de dépense',
                  border: OutlineInputBorder(),
                ),
                items: expenseTypesOrdered
                    .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(expenseTypeLabel(t)),
                        ))
                    .toList(),
                onChanged: (v) => setState(() {
                  _type = v ?? ExpenseType.fuel;
                  _vatRate = null;
                }),
              ),
              const SizedBox(height: 12),

              // ── Chauffeur (amende : à désigner) ─────────────────────────
              if (_type == ExpenseType.fine || _type == ExpenseType.claim) ...[
                DropdownButtonFormField<String>(
                  value: _driverName,
                  decoration: InputDecoration(
                    labelText: _type == ExpenseType.fine
                        ? 'Chauffeur à désigner'
                        : 'Chauffeur au volant',
                    border: const OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                        value: null, child: Text('Non renseigné')),
                    for (final d in ref.read(appStateProvider).drivers)
                      DropdownMenuItem(value: d.name, child: Text(d.fullName)),
                  ],
                  onChanged: (v) => setState(() => _driverName = v),
                ),
                const SizedBox(height: 12),
              ],

              // ── Montant ──────────────────────────────────────────────────
              TextFormField(
                controller: _amountCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant payé TTC (€)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  final val = _d(v ?? '');
                  if (val == null || val <= 0) return 'Montant invalide';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // ── TVA ─────────────────────────────────────────────────────
              Builder(builder: (_) {
                final rate = _vatRate ?? defaultVatRate(_type);
                final ttc = _d(_amountCtrl.text);
                return DropdownButtonFormField<double>(
                  value: rate,
                  decoration: InputDecoration(
                    labelText: 'TVA',
                    border: const OutlineInputBorder(),
                    helperText: ttc == null
                        ? 'La TVA est récupérée : seul le HT compte dans le résultat'
                        : 'Soit ${(ttc / (1 + rate)).toStringAsFixed(2).replaceAll('.', ',')} € HT',
                  ),
                  items: [
                    for (final r in vatRates)
                      DropdownMenuItem(value: r, child: Text(vatLabel(r))),
                  ],
                  onChanged: (v) => setState(() => _vatRate = v),
                );
              }),
              const SizedBox(height: 12),

              // ── Litres ───────────────────────────────────────────────────
              if (_type == ExpenseType.fuel) ...[
                TextFormField(
                  controller: _litersCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Litres (optionnel)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final val = _d(v);
                    if (val == null || val <= 0) return 'Litres invalides';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
              ],

              // ── Note ─────────────────────────────────────────────────────
              TextFormField(
                controller: _noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              FilledButton(
                onPressed: _save,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
