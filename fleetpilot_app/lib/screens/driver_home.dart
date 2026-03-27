import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/driver_session.dart';
import '../services/gps_tracking_service.dart';
import '../services/ocr_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import 'chat_screen.dart';
import 'driver_dashboard.dart';
import 'driver_documents.dart';
import 'add_truck.dart';
import 'models/client_pricing.dart';
import 'models/driver.dart';
import 'models/driver_day_entry.dart';
import 'models/expense.dart';
import 'models/manager_alert.dart';
import 'models/tour.dart';

class DriverHomePage extends ConsumerStatefulWidget {
  final String? firebaseEmail;
  final String? firebaseName;

  const DriverHomePage({super.key, this.firebaseEmail, this.firebaseName});

  @override
  ConsumerState<DriverHomePage> createState() => _DriverHomePageState();
}

class _DriverHomePageState extends ConsumerState<DriverHomePage> {
  // ── Session ──────────────────────────────────────────────────────────────────
  String? _driverName;
  DateTime? _tourStart;
  Timer? _timer;
  bool _loading = true;

  // ── Navigation ──────────────────────────────────────────────────────────────
  int _tabIndex = 0;

  // ── GPS ─────────────────────────────────────────────────────────────────────
  final _gps = GpsTrackingService();
  double _gpsKm = 0.0;
  bool _gpsActive = false;
  bool _kmManuallyEdited = false;

  // ── Formulaire tournée ───────────────────────────────────────────────────────
  String? _selectedTruck;
  final _tourNumberCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _clientsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  final _handlingCtrl = TextEditingController();
  final _handlingCountCtrl = TextEditingController();
  bool _hasHandling = false;
  bool _extraTour = false;

  // ── Init ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DriverSession.init();

    // Auto-link : si pas de session, chercher le chauffeur par email Firebase
    String? name = DriverSession.driverName;
    if (name == null && widget.firebaseEmail != null) {
      final drivers = ref.read(appStateProvider).drivers;
      final match = drivers.cast<Driver?>().firstWhere(
        (d) => d!.email?.toLowerCase() == widget.firebaseEmail!.toLowerCase(),
        orElse: () => null,
      );
      if (match != null) {
        name = match.name;
        await DriverSession.setDriverName(name);
      }
    }
    // Fallback : chercher par nom Firebase
    if (name == null && widget.firebaseName != null) {
      final drivers = ref.read(appStateProvider).drivers;
      final match = drivers.cast<Driver?>().firstWhere(
        (d) => d!.name.toLowerCase() == widget.firebaseName!.toLowerCase(),
        orElse: () => null,
      );
      if (match != null) {
        name = match.name;
        await DriverSession.setDriverName(name);
      }
    }

    setState(() {
      _driverName = name;
      _tourStart = DriverSession.tourStartTime;
      _loading = false;
    });
    if (_tourStart != null) {
      _startTimer();
      // Reprendre le GPS si l'app a été tuée pendant une tournée
      _gps.onKmUpdate = _onGpsKmUpdate;
      final resumed = await _gps.resumeIfNeeded();
      if (resumed && mounted) {
        setState(() {
          _gpsActive = true;
          _gpsKm = _gps.currentKm;
        });
      }
    }
    if (ref.read(appStateProvider).trucks.isNotEmpty) {
      _selectedTruck = ref.read(appStateProvider).trucks.first.plate;
    }

    // Pré-remplir selon l'affectation permanente du chauffeur
    if (_driverName != null) {
      final assignment = ref.read(appStateProvider).getAssignment(_driverName!);
      if (assignment != null) {
        _selectedTruck = assignment.truckPlate;
        if (assignment.companyName != null && assignment.companyName!.isNotEmpty) {
          _companyCtrl.text = assignment.companyName!;
        }
      }
    }

    // Sinon, pré-remplir avec les dernières valeurs
    final lastTour = DriverSession.lastTourNumber;
    final lastCompany = DriverSession.lastCompany;
    if (lastTour != null && lastTour.isNotEmpty) {
      _tourNumberCtrl.text = lastTour;
    }
    if (_companyCtrl.text.isEmpty && lastCompany != null && lastCompany.isNotEmpty) {
      _companyCtrl.text = lastCompany;
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tourNumberCtrl.dispose();
    _companyCtrl.dispose();
    _kmCtrl.dispose();
    _clientsCtrl.dispose();
    _pickupCtrl.dispose();
    _weightCtrl.dispose();
    _handlingCtrl.dispose();
    _handlingCountCtrl.dispose();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  String _elapsed() {
    if (_tourStart == null) return '00:00';
    final diff = DateTime.now().difference(_tourStart!);
    final h = diff.inHours.toString().padLeft(2, '0');
    final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtTime(DateTime d) {
    final h = d.hour.toString().padLeft(2, '0');
    final m = d.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  double? _d(String s) => double.tryParse(s.replaceAll(',', '.').trim());

  void _onGpsKmUpdate(double km) {
    if (!mounted) return;
    setState(() {
      _gpsKm = km;
      // Pré-remplir le champ km si pas édité manuellement
      if (!_kmManuallyEdited) {
        _kmCtrl.text = km.toStringAsFixed(1);
      }
    });
  }

  // ── Dépense carburant chauffeur ─────────────────────────────────────────────

  bool _isScanning = false;

  /// Ouvre un bottom sheet : scanner (caméra/galerie) ou saisie manuelle
  Future<void> _addFuelExpense() async {
    if (_selectedTruck == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne d\'abord un camion.')),
      );
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Ajouter une dépense carburant',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Prendre en photo'),
              subtitle: const Text('Photographier le ticket'),
              onTap: () => Navigator.pop(ctx, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choisir une image'),
              subtitle: const Text('Depuis la galerie'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Saisie manuelle'),
              subtitle: const Text('Entrer le montant et les litres'),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    if (choice == 'manual') {
      _manualFuelEntry();
    } else {
      _scanFuelTicket(choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
    }
  }

  Future<void> _scanFuelTicket(ImageSource source) async {
    final picker = ImagePicker();
    final XFile? xfile = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1200,
    );
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    final ext = xfile.name.split('.').last.toLowerCase();
    final mimeType = ext == 'png' ? 'image/png' : 'image/jpeg';

    setState(() => _isScanning = true);

    final result = await OcrService.analyze(bytes, mimeType);
    if (!mounted) return;

    setState(() => _isScanning = false);

    if (result.error != null || result.amount == null) {
      // Scan échoué → proposer saisie manuelle
      final goManual = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Scan échoué'),
          content: Text(result.error ?? 'Impossible de lire le montant sur le ticket.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Saisie manuelle'),
            ),
          ],
        ),
      );
      if (goManual == true && mounted) _manualFuelEntry();
      return;
    }

    // Montrer un résumé avant de valider
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ticket scanné'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _scanLine('Montant', '${result.amount!.toStringAsFixed(2)} €'),
            if (result.liters != null)
              _scanLine('Litres', result.liters!.toStringAsFixed(2)),
            if (result.pricePerLiter != null)
              _scanLine('Prix/L', '${result.pricePerLiter!.toStringAsFixed(3)} €'),
            if (result.date != null)
              _scanLine('Date',
                  '${result.date!.day.toString().padLeft(2, '0')}/${result.date!.month.toString().padLeft(2, '0')}/${result.date!.year}'),
            if (result.station != null)
              _scanLine('Station', result.station!),
            const SizedBox(height: 12),
            Text('Camion : $_selectedTruck',
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _saveFuelExpense(
      amount: result.amount!,
      liters: result.liters,
      date: result.date,
      station: result.station,
      source: 'scan',
    );
  }

  /// Saisie manuelle d'une dépense carburant
  Future<void> _manualFuelEntry() async {
    final amountCtrl = TextEditingController();
    final litersCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dépense carburant'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Camion : $_selectedTruck',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Montant (€) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: litersCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Litres (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_gas_station),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note / Station (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(
                  amountCtrl.text.replaceAll(',', '.').trim());
              if (amount == null || amount <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Montant invalide')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final amount = double.tryParse(
        amountCtrl.text.replaceAll(',', '.').trim());
    final liters = double.tryParse(
        litersCtrl.text.replaceAll(',', '.').trim());
    final note = noteCtrl.text.trim();

    amountCtrl.dispose();
    litersCtrl.dispose();
    noteCtrl.dispose();

    if (amount == null || amount <= 0) return;

    _saveFuelExpense(
      amount: amount,
      liters: liters,
      station: note.isEmpty ? null : note,
      source: 'manuel',
    );
  }

  /// Enregistre la dépense + alerte manager
  void _saveFuelExpense({
    required double amount,
    double? liters,
    DateTime? date,
    String? station,
    required String source,
  }) {
    final expense = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: date ?? DateTime.now(),
      truckPlate: _selectedTruck!,
      type: ExpenseType.fuel,
      amount: amount,
      liters: liters,
      note: '${source == 'scan' ? 'Scan' : 'Saisie'} chauffeur ${_driverName ?? ""}${station != null ? ' - $station' : ''}',
    );

    ref.read(appStateProvider).addExpense(expense);

    // Notifier le manager
    ref.read(appStateProvider).addManagerAlert(ManagerAlert(
      id: 'fuel_${expense.id}',
      type: ManagerAlertType.fuelScan,
      title: source == 'scan'
          ? 'Ticket carburant scanné'
          : 'Dépense carburant ajoutée',
      message:
          '${_driverName ?? "Chauffeur"} a ${source == 'scan' ? 'scanné' : 'saisi'} une dépense de ${amount.toStringAsFixed(2)} €'
          '${liters != null ? ' (${liters.toStringAsFixed(1)} L)' : ''}'
          ' pour le camion $_selectedTruck.'
          '${station != null ? '\n$station' : ''}',
      date: DateTime.now(),
      driverName: _driverName,
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Dépense enregistrée : ${amount.toStringAsFixed(2)} € — Manager notifié.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _scanLine(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(color: DC.textSecondary, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _selectProfile(Driver driver) async {
    await DriverSession.setDriverName(driver.name);
    setState(() {
      _driverName = driver.name;
      // Appliquer l'affectation permanente
      final assignment = ref.read(appStateProvider).getAssignment(driver.name);
      if (assignment != null) {
        _selectedTruck = assignment.truckPlate;
        if (assignment.companyName != null && assignment.companyName!.isNotEmpty) {
          _companyCtrl.text = assignment.companyName!;
        }
      }
    });
  }

  Future<void> _demarrer() async {
    await DriverSession.startTour();
    setState(() {
      _tourStart = DriverSession.tourStartTime;
      _kmManuallyEdited = false;
      _gpsKm = 0.0;
    });
    _startTimer();

    // Démarrer le GPS en arrière-plan
    _gps.onKmUpdate = _onGpsKmUpdate;
    final started = await _gps.startTracking();
    if (mounted) {
      setState(() => _gpsActive = started);
      if (!started) {
        _snack('GPS indisponible — saisis les km manuellement.');
      }
    }
  }

  Future<void> _annuler() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Annuler le démarrage ?'),
        content: const Text(
            'La tournée sera annulée. Aucune donnée ne sera enregistrée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuler le démarrage'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Arrêter le GPS
    await _gps.stopTracking();

    await DriverSession.endTour();
    _timer?.cancel();
    _kmCtrl.clear();
    _clientsCtrl.clear();
    _pickupCtrl.clear();
    _weightCtrl.clear();
    _handlingCtrl.clear();
    _handlingCountCtrl.clear();
    setState(() {
      _tourStart = null;
      _hasHandling = false;
      _extraTour = false;
      _gpsActive = false;
      _gpsKm = 0.0;
      _kmManuallyEdited = false;
    });
  }

  Future<void> _terminer() async {
    // Arrêter le GPS et récupérer le total
    final gpsTotal = await _gps.stopTracking();

    // Utiliser le GPS si pas édité manuellement, sinon la valeur saisie
    if (!_kmManuallyEdited && gpsTotal > 0) {
      _kmCtrl.text = gpsTotal.toStringAsFixed(1);
    }

    final km = _d(_kmCtrl.text);
    final clients = int.tryParse(_clientsCtrl.text.trim());
    final pickups = int.tryParse(_pickupCtrl.text.trim()) ?? 0;

    if (_selectedTruck == null) {
      _snack('Choisis un camion.');
      return;
    }
    if (_tourNumberCtrl.text.trim().isEmpty) {
      _snack('Numéro de tournée obligatoire.');
      return;
    }
    if (km == null || km <= 0) {
      _snack('Kilométrage invalide.');
      return;
    }
    if (clients == null || clients < 0) {
      _snack('Nombre de clients invalide.');
      return;
    }
    if (_hasHandling && _handlingCtrl.text.trim().isEmpty) {
      _snack('Nom du client manutention obligatoire.');
      return;
    }
    if (_hasHandling &&
        (int.tryParse(_handlingCountCtrl.text.trim()) == null ||
            int.parse(_handlingCountCtrl.text.trim()) <= 0)) {
      _snack('Nombre de manutentions invalide.');
      return;
    }

    final now = DateTime.now();
    final start = _tourStart ?? now;

    final entry = DriverDayEntry(
      id: now.microsecondsSinceEpoch.toString(),
      date: now,
      driverName: _driverName!,
      truckPlate: _selectedTruck!,
      kmTotal: km,
      clientsCount: clients,
      pickupCount: pickups,
    );

    final tour = Tour(
      id: '${now.microsecondsSinceEpoch}_tour',
      tourNumber: _tourNumberCtrl.text.trim(),
      date: now,
      driverName: _driverName!,
      truckPlate: _selectedTruck!,
      companyName: _companyCtrl.text.trim().isEmpty
          ? null
          : _companyCtrl.text.trim(),
      startTime: _fmtTime(start),
      endTime: _fmtTime(now),
      kmTotal: km,
      clientsCount: clients,
      pickupCount: pickups,
      weightKg: _d(_weightCtrl.text),
      hasHandling: _hasHandling,
      handlingClientName: _hasHandling ? _handlingCtrl.text.trim() : null,
      handlingDate: _hasHandling ? now : null,
      extraTour: _extraTour,
    );

    ref.read(appStateProvider).addDriverDayEntry(entry);
    ref.read(appStateProvider).addTour(tour);

    // Sauvegarder n° tournée et client pour la prochaine fois
    await DriverSession.saveLastTour(
      _tourNumberCtrl.text.trim(),
      _companyCtrl.text.trim(),
    );

    await DriverSession.endTour();
    _timer?.cancel();

    // Reset formulaire (garder tourNumber et company pré-remplis)
    _kmCtrl.clear();
    _clientsCtrl.clear();
    _pickupCtrl.clear();
    _weightCtrl.clear();
    _handlingCtrl.clear();
    _handlingCountCtrl.clear();

    setState(() {
      _tourStart = null;
      _hasHandling = false;
      _extraTour = false;
      _gpsActive = false;
      _gpsKm = 0.0;
      _kmManuallyEdited = false;
    });

    _snack('Tournée ${tour.tourNumber} enregistrée — ${_fmtTime(start)} → ${_fmtTime(now)}');
  }

  Future<void> _signalerPanne(List<Truck> trucks) async {
    // Motif obligatoire
    String? motif;
    final motifs = ['Panne mécanique', 'Panne électrique', 'Crevaison', 'Accident', 'Autre'];

    motif = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Motif du changement'),
        children: motifs.map((m) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, m),
          child: Text(m),
        )).toList(),
      ),
    );
    if (motif == null || !mounted) return;

    // Choisir le nouveau camion (flotte ou prêt)
    final availableTrucks = trucks.where((t) =>
        t.plate != _selectedTruck &&
        t.truckStatus == TruckStatus.fonctionnel).toList();

    final newTruck = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final plateCtrl = TextEditingController();
        return SimpleDialog(
          title: const Text('Camion de remplacement'),
          children: [
            // Camions de la flotte
            ...availableTrucks.map((t) => SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.plate),
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(t.plate),
                subtitle: Text(t.model),
                contentPadding: EdgeInsets.zero,
              ),
            )),
            // Séparateur
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(),
            ),
            // Camion de prêt (hors flotte)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Camion de prêt (hors flotte)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: plateCtrl,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Immatriculation du camion prêté',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.drive_eta_outlined),
                      hintText: 'Ex: AB-123-CD',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        final plate = plateCtrl.text.trim().toUpperCase();
                        if (plate.isEmpty) return;
                        plateCtrl.dispose();
                        Navigator.pop(ctx, 'PRET:$plate');
                      },
                      style: FilledButton.styleFrom(backgroundColor: Colors.orange),
                      icon: const Icon(Icons.car_rental_outlined, size: 18),
                      label: const Text('Utiliser ce camion de prêt'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
    if (newTruck == null || !mounted) return;

    // Déterminer si c'est un prêt ou un camion flotte
    final bool isPret = newTruck.startsWith('PRET:');
    final String actualPlate = isPret ? newTruck.substring(5) : newTruck;
    final truckModel = isPret
        ? 'Prêt'
        : (trucks.where((t) => t.plate == actualPlate).firstOrNull?.model ?? '');
    final oldTruck = _selectedTruck;

    // Mettre l'ancien camion en panne
    final oldTruckObj = trucks.where((t) => t.plate == oldTruck).firstOrNull;
    if (oldTruckObj != null) {
      ref.read(appStateProvider).updateTruck(
        oldTruck!,
        oldTruckObj.copyWith(truckStatus: TruckStatus.enPanne),
      );
    }

    setState(() => _selectedTruck = actualPlate);

    // Alerte manager avec motif
    final now = DateTime.now();
    final pretLabel = isPret ? ' (CAMION DE PRÊT)' : '';
    final alert = ManagerAlert(
      id: '${now.microsecondsSinceEpoch}_truck_change',
      type: ManagerAlertType.truckChange,
      title: '$_driverName — changement camion$pretLabel',
      message: 'Changement : $oldTruck → $actualPlate${isPret ? ' (camion de prêt, hors flotte)' : ' ($truckModel)'}.\n'
          'Motif : $motif.\n'
          'Le camion $oldTruck a été passé en statut "En panne".',
      date: now,
      driverName: _driverName,
      oldTruckPlate: oldTruck,
      newTruckPlate: actualPlate,
    );
    ref.read(appStateProvider).addManagerAlert(alert);

    _snack(isPret
        ? 'Camion de prêt $actualPlate activé. Le manager a été alerté.'
        : 'Camion changé → $actualPlate. Le manager a été alerté.');
  }

  Future<void> _changerCamion(List<Truck> trucks) async {
    // Étape 1 : choisir le nouveau camion
    final newTruck = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Changer de camion'),
        children: trucks
            .where((t) => t.plate != _selectedTruck)
            .map((t) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, t.plate),
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(t.plate),
                    subtitle: Text(t.model),
                    contentPadding: EdgeInsets.zero,
                  ),
                ))
            .toList(),
      ),
    );
    if (newTruck == null || !mounted) return;

    final truckModel = trucks.where((t) => t.plate == newTruck).firstOrNull?.model ?? '';

    // Étape 2 : confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirmer le changement'),
        content: Text(
          'Tu vas passer du camion $_selectedTruck au camion $newTruck ($truckModel).\n\nEs-tu sûr ? Cette action est liée à une panne ou un remplacement.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirmer le changement'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final oldTruck = _selectedTruck;
    setState(() => _selectedTruck = newTruck);

    // Créer une alerte manager
    final now = DateTime.now();
    final alert = ManagerAlert(
      id: '${now.microsecondsSinceEpoch}_truck_change',
      type: ManagerAlertType.truckChange,
      title: '$_driverName a changé de camion',
      message: 'Changement temporaire : $oldTruck → $newTruck ($truckModel). '
          'Motif probable : panne ou remplacement.',
      date: now,
      driverName: _driverName,
      oldTruckPlate: oldTruck,
      newTruckPlate: newTruck,
    );
    ref.read(appStateProvider).addManagerAlert(alert);

    // Mettre à jour les day entries du jour pour ce chauffeur
    ref.read(appStateProvider).updateDriverDayEntryTruck(
      driverName: _driverName!,
      date: now,
      newTruckPlate: newTruck,
    );

    _snack('Camion changé → $newTruck ($truckModel)');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Stats chauffeur (sans CA) ─────────────────────────────────────────────

  Widget _buildStats() {
    final now = DateTime.now();
    final name = _driverName!.toLowerCase();

    final entries = ref.read(appStateProvider).driverDayEntries
        .where((e) =>
            e.driverName.toLowerCase() == name &&
            e.date.year == now.year &&
            e.date.month == now.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final allTours = ref.read(appStateProvider).tours
        .where((t) =>
            t.driverName.toLowerCase() == name &&
            t.date.year == now.year &&
            t.date.month == now.month)
        .toList();

    final kmTotal = entries.fold(0.0, (sum, e) => sum + e.kmTotal);
    final clientsTotal = entries.fold(0, (sum, e) => sum + e.clientsCount);
    final jours = entries
        .map((e) => '${e.date.year}-${e.date.month}-${e.date.day}')
        .toSet()
        .length;

    // Km/j et clients/j moyens
    final kmMoy = jours > 0 ? kmTotal / jours : 0.0;
    final clientsMoy = jours > 0 ? clientsTotal / jours : 0.0;

    final monthLabel = _monthLabel(now.month);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Mon mois — $monthLabel ${now.year}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _StatBox(label: 'Jours travaillés', value: '$jours'),
            const SizedBox(width: 10),
            _StatBox(label: 'Tournées', value: '${allTours.length}'),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _StatBox(label: 'Km/jour (moy.)', value: '${kmMoy.toStringAsFixed(0)} km'),
            const SizedBox(width: 10),
            _StatBox(label: 'Colis/jour (moy.)', value: clientsMoy.toStringAsFixed(1)),
          ],
        ),
        const SizedBox(height: 20),

        // Historique par jour
        const Text(
          'Détail par jour',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),

        if (entries.isEmpty)
          const Text('Aucune saisie ce mois.', style: TextStyle(color: DC.textSecondary))
        else
          ...entries.map((e) {
            final dayKey = '${e.date.year}-${e.date.month}-${e.date.day}';
            final dayTours = allTours.where((t) {
              return '${t.date.year}-${t.date.month}-${t.date.day}' == dayKey;
            }).toList();

            final manutentionTours = dayTours.where((t) => t.hasHandling).toList();
            final hasManu = manutentionTours.isNotEmpty;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Date
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${e.date.day.toString().padLeft(2, '0')}/${e.date.month.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Km
                  Expanded(
                    child: Text('${e.kmTotal.toStringAsFixed(0)} km'),
                  ),
                  // Colis
                  Expanded(
                    child: Text('${e.clientsCount} colis'),
                  ),
                  // Ramasses
                  if (e.pickupCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text('${e.pickupCount} ram.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade700)),
                    ),
                  // Manutention
                  if (hasManu)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Manu ×${manutentionTours.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }),
      ],
    );
  }

  String _monthLabel(int m) {
    const months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[m];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ── Sélection profil ─────────────────────────────────────────────────────
    if (_driverName == null) {
      return _buildProfileSelector();
    }

    final unreadCount =
        ref.watch(appStateProvider).unreadCountForDriver(_driverName!);
    final unreadMsgCount =
        ref.watch(appStateProvider).unreadMessagesForDriver(_driverName!);

    final pages = [
      _tourStart == null ? _buildIdle() : _buildActiveTour(),
      DriverDashboardPage(driverName: _driverName!),
      ChatScreen(driverName: _driverName!, isManager: false, showAppBar: false),
      _buildSettings(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour $_driverName'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DriverDocumentsPage(driverName: _driverName!),
                ),
              );
            },
          ),
        ],
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.route_outlined),
            label: 'Tournée',
          ),
          const NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadMsgCount > 0,
              label: Text('$unreadMsgCount'),
              child: const Icon(Icons.chat_outlined),
            ),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unreadCount > 0,
              label: Text('$unreadCount'),
              child: const Icon(Icons.settings_outlined),
            ),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  // ── Vue : Paramètres ───────────────────────────────────────────────────

  Widget _buildSettings() {
    final unreadCount =
        ref.watch(appStateProvider).unreadCountForDriver(_driverName!);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Avatar + nom
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 36,
                child: Text(
                  _driverName![0].toUpperCase(),
                  style: const TextStyle(fontSize: 28),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _driverName!,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Builder(builder: (_) {
                final driver = ref.read(appStateProvider).drivers
                    .where((d) => d.name == _driverName)
                    .firstOrNull;
                if (driver == null) return const SizedBox.shrink();
                final colorStr = driverStatusColor(driver.status);
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
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    driverStatusLabel(driver.status),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 28),

        // Section Mes informations
        const Text(
          'Mon profil',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: DC.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.person_outline,
          title: 'Mes informations',
          subtitle: 'Identité, adresse, permis, contact',
          onTap: () {
            final driver = ref.read(appStateProvider).drivers
                .where((d) => d.name == _driverName)
                .firstOrNull;
            if (driver == null) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => _DriverInfoPage(driver: driver),
              ),
            );
          },
        ),

        const SizedBox(height: 20),

        // Section Documents
        const Text(
          'Documents',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: DC.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.folder_outlined,
          title: 'Mes documents',
          subtitle: 'FIMO, FCO, ADR, formations',
          badge: unreadCount,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DriverDocumentsPage(driverName: _driverName!),
              ),
            );
          },
        ),

        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.local_gas_station_outlined,
          title: 'Dépense carburant',
          subtitle: 'Scanner ou saisir manuellement',
          onTap: _addFuelExpense,
        ),

        const SizedBox(height: 20),

        // Section Compte
        const Text(
          'Compte',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: DC.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.swap_horiz,
          title: 'Changer de chauffeur',
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Changer de chauffeur ?'),
                content: const Text('Tu quitteras ton profil actuel.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Changer'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await DriverSession.clearDriverName();
              setState(() {
                _driverName = null;
                _tabIndex = 0;
              });
            }
          },
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.logout,
          title: 'Se déconnecter',
          color: Colors.red,
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Se déconnecter ?'),
                content: const Text(
                  'Tu seras redirigé vers la sélection de profil.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text('Se déconnecter'),
                  ),
                ],
              ),
            );
            if (confirm == true) {
              await DriverSession.clearDriverName();
              setState(() {
                _driverName = null;
                _tabIndex = 0;
              });
            }
          },
        ),
      ],
    );
  }

  // ── Vue : pas de tournée en cours ────────────────────────────────────────

  Widget _buildIdle() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = _monthLabel(now.month);
    final trucks = ref.read(appStateProvider).trucks;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Date
        Text(
          '$day $month ${now.year}',
          style: const TextStyle(fontSize: 16, color: DC.textSecondary),
        ),
        const SizedBox(height: 24),

        // Sélection camion obligatoire
        DropdownButtonFormField<String>(
          value: _selectedTruck,
          decoration: const InputDecoration(
            labelText: 'Camion *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.local_shipping_outlined),
          ),
          items: trucks
              .map((t) => DropdownMenuItem(
                    value: t.plate,
                    child: Text('${t.plate} • ${t.model}'),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedTruck = v),
        ),
        const SizedBox(height: 16),

        // Bouton démarrer
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _selectedTruck == null ? null : _demarrer,
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Démarrer la tournée',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Dépense carburant
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _selectedTruck == null || _isScanning
                ? null
                : _addFuelExpense,
            icon: _isScanning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.local_gas_station_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                _isScanning
                    ? 'Analyse en cours...'
                    : 'Dépense carburant',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),

        const SizedBox(height: 32),
        const Divider(),
        const SizedBox(height: 16),

        // Stats du mois
        _buildStats(),
      ],
    );
  }

  // ── Vue : tournée en cours ───────────────────────────────────────────────

  Widget _buildActiveTour() {
    final trucks = ref.read(appStateProvider).trucks;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Chrono
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.orange),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Démarré à ${_fmtTime(_tourStart!)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'En cours : ${_elapsed()}',
                    style: const TextStyle(color: Colors.orange, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // GPS live km
        if (_gpsActive)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.gps_fixed, color: Colors.green.shade700, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_gpsKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Suivi GPS en cours',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                // Pastille pulsante
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: DC.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: DC.border),
            ),
            child: Row(
              children: [
                Icon(Icons.gps_off, color: DC.textTertiary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'GPS inactif — saisis les km manuellement',
                  style: TextStyle(color: DC.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Affectation (camion + commissionnaire) — lecture seule, vient du manager
        Builder(builder: (_) {
          final assignment = ref.read(appStateProvider).getAssignment(_driverName ?? '');
          final truck = _selectedTruck != null
              ? trucks.where((t) => t.plate == _selectedTruck).firstOrNull
              : null;
          final companyName = _companyCtrl.text.trim();
          final pricing = companyName.isNotEmpty
              ? ref.read(appStateProvider).getClientPricing(companyName)
              : null;
          final commColor = pricing?.colorValue != null
              ? Color(pricing!.colorValue!)
              : Colors.indigo;

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: commColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: commColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Commissionnaire
                if (companyName.isNotEmpty) ...[
                  Row(
                    children: [
                      Icon(Icons.handshake_outlined, size: 16, color: commColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          companyName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: commColor,
                          ),
                        ),
                      ),
                      if (pricing != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: commColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            billingModeLabel(pricing.billingMode),
                            style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.w600, color: commColor),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                // Camion
                Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined, size: 16, color: Colors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        truck != null
                            ? '${truck.plate} • ${truck.model}'
                            : _selectedTruck ?? 'Aucun camion',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                // Indication + bouton panne
                if (assignment != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.lock_outline, size: 12, color: DC.textTertiary),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Affectation définie par le manager',
                          style: TextStyle(fontSize: 10, color: DC.textTertiary),
                        ),
                      ),
                      InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => _signalerPanne(trucks),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                              SizedBox(width: 4),
                              Text('Panne / Changer',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.orange)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: 12),

        // N° tournée (sauvegardé, auto-rempli, modifiable)
        TextField(
          controller: _tourNumberCtrl,
          decoration: InputDecoration(
            labelText: 'Numéro de tournée *',
            border: const OutlineInputBorder(),
            helperText: _tourNumberCtrl.text.isNotEmpty
                ? 'Enregistré — modifiable si besoin'
                : null,
            helperStyle: TextStyle(fontSize: 11, color: DC.textTertiary),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),

        // Km
        TextField(
          controller: _kmCtrl,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => _kmManuallyEdited = true,
          decoration: InputDecoration(
            labelText: _gpsActive
                ? 'Km (GPS auto — modifiable)'
                : 'Kilomètres parcourus *',
            border: const OutlineInputBorder(),
            suffixIcon: _gpsActive && _kmManuallyEdited
                ? IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Remettre la valeur GPS',
                    onPressed: () {
                      setState(() {
                        _kmManuallyEdited = false;
                        _kmCtrl.text = _gpsKm.toStringAsFixed(1);
                      });
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),

        // ── Section Fiches / Colis + Ramasses ──────────────────────────
        Builder(builder: (_) {
          final companyName = _companyCtrl.text.trim();
          final pricing = companyName.isNotEmpty
              ? ref.read(appStateProvider).getClientPricing(companyName)
              : null;
          final isFiche = pricing?.billingMode == BillingMode.aLaFiche;
          final commColor = pricing?.colorValue != null
              ? Color(pricing!.colorValue!)
              : (isFiche ? Colors.teal : Colors.indigo);

          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: commColor.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: commColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isFiche ? Icons.description_outlined : Icons.inventory_2_outlined,
                      size: 16,
                      color: commColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isFiche ? 'Fiches & Ramasses' : 'Colis & Ramasses',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: commColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _clientsCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: isFiche
                        ? 'Nombre de fiches *'
                        : 'Nombre de colis *',
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(isFiche
                        ? Icons.description_outlined
                        : Icons.inventory_2_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pickupCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de ramasses',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.move_to_inbox_outlined),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 12),

        // Poids
        TextField(
          controller: _weightCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Poids chargé (kg) — optionnel',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.scale_outlined),
          ),
        ),
        const SizedBox(height: 8),

        // Manutention
        SwitchListTile(
          value: _hasHandling,
          title: const Text('Manutention'),
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _hasHandling = v),
        ),
        if (_hasHandling) ...[
          TextField(
            controller: _handlingCountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Nombre de manutentions *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.numbers),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _handlingCtrl,
            decoration: const InputDecoration(
              labelText: 'Nom du client manutention *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.business),
            ),
          ),
          const SizedBox(height: 8),
        ],

        // Tournée supplémentaire
        SwitchListTile(
          value: _extraTour,
          title: const Text('Tournée supplémentaire'),
          contentPadding: EdgeInsets.zero,
          onChanged: (v) => setState(() => _extraTour = v),
        ),

        const SizedBox(height: 20),

        // Bouton terminer
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _terminer,
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            icon: const Icon(Icons.stop_circle_outlined, size: 24),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Terminer la tournée',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Bouton annuler démarrage
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _annuler,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.cancel_outlined, size: 20),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Annuler le démarrage', style: TextStyle(fontSize: 16)),
            ),
          ),
        ),
      ],
    );
  }

  // ── Sélection du profil (premier lancement) ──────────────────────────────

  Widget _buildProfileSelector() {
    final drivers = ref.read(appStateProvider).drivers;

    return Scaffold(
      appBar: AppBar(title: const Text('FleetPilote — Chauffeur')),
      body: drivers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun chauffeur enregistré.\nDemande à ton manager d\'ajouter ton profil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: DC.textSecondary),
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 32, 24, 8),
                  child: Text(
                    'Qui es-tu ?',
                    style: TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Text(
                    'Sélectionne ton profil pour commencer.',
                    style: TextStyle(color: DC.textSecondary),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: drivers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final d = drivers[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(d.name[0].toUpperCase()),
                          ),
                          title: Text(
                            d.name,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_forward_ios, size: 16, color: DC.textSecondary),
                            ],
                          ),
                          onTap: () => _selectProfile(d),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

// ── Widget stat ───────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String label;
  final String value;

  const _StatBox({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: DC.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Page Mes informations (lecture seule) ─────────────────────────────────────

class _DriverInfoPage extends StatelessWidget {
  final Driver driver;
  const _DriverInfoPage({required this.driver});

  String _fmt(DateTime? d) {
    if (d == null) return 'Non renseigné';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes informations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Identité
          _section('Identité'),
          _infoRow(Icons.person_outline, 'Nom', driver.name),
          _infoRow(Icons.person_outline, 'Prénom', driver.firstName ?? 'Non renseigné'),
          _infoRow(Icons.cake_outlined, 'Date de naissance', _fmt(driver.birthDate)),
          _infoRow(Icons.flag_outlined, 'Nationalité', driver.nationality ?? 'Non renseignée'),
          const SizedBox(height: 16),

          // ── Contact
          _section('Contact'),
          _infoRow(Icons.phone_outlined, 'Téléphone', driver.phone ?? 'Non renseigné'),
          _infoRow(Icons.email_outlined, 'Email', driver.email ?? 'Non renseigné'),
          _infoRow(Icons.home_outlined, 'Adresse', driver.address ?? 'Non renseignée'),
          const SizedBox(height: 16),

          // ── Administratif
          _section('Administratif'),
          _infoRow(Icons.badge_outlined, 'N° Sécurité sociale', driver.socialSecurityNumber ?? 'Non renseigné'),
          _infoRow(Icons.work_outline, 'Statut', driverStatusLabel(driver.status)),
          _infoRow(Icons.calendar_today_outlined, 'Date d\'embauche', _fmt(driver.hireDate)),
          const SizedBox(height: 16),

          // ── Permis de conduire
          _section('Permis de conduire'),
          _infoRow(Icons.credit_card_outlined, 'N° de permis', driver.licenseNumber ?? 'Non renseigné'),
          _infoRow(Icons.event_busy_outlined, 'Expiration permis', _fmt(driver.licenseExpiryDate)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Catégories détenues',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _permitChip('B', driver.hasPermisB),
                      _permitChip('C', driver.hasPermisC),
                      _permitChip('CE', driver.hasPermisCE),
                      _permitChip('D', driver.hasPermisD),
                      _permitChip('EB', driver.hasPermisEB),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Contact d'urgence
          _section('Contact d\'urgence'),
          _infoRow(Icons.emergency_outlined, 'Nom', driver.emergencyContact ?? 'Non renseigné'),
          _infoRow(Icons.phone_outlined, 'Téléphone', driver.emergencyPhone ?? 'Non renseigné'),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pour modifier tes informations, contacte ton manager.',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _infoRow(IconData icon, String label, String value) {
    final isDefault = value == 'Non renseigné' || value == 'Non renseignée';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: DC.textSecondary),
          const SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: DC.textSecondary)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDefault ? Colors.grey : null,
                fontStyle: isDefault ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _permitChip(String label, bool has) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: has ? Colors.green.withValues(alpha: 0.12) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: has ? Colors.green.withValues(alpha: 0.4) : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: has ? Colors.green : Colors.grey,
        ),
      ),
    );
  }
}

// ── Tuile paramètres ─────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final int badge;
  final Color? color;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.badge = 0,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    return Card(
      child: ListTile(
        leading: Icon(icon, color: c),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.w600, color: c),
        ),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badge > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badge',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, color: DC.textSecondary),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

