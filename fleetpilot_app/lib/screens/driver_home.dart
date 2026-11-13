import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/driver_session.dart';
import '../services/gps_tracking_service.dart';
import '../services/ocr_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import '../utils/shared_widgets.dart';
import '../utils/theme_ctx.dart';
import 'chat_screen.dart';
import 'driver_dashboard.dart';
import 'driver_documents.dart';
import 'add_truck.dart';
import 'models/driver.dart';
import 'models/driver_day_entry.dart';
import 'models/expense.dart';
import 'models/manager_alert.dart';
import 'models/odometer_reading.dart';
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
  bool _gpsStarting = false;

  // ── Journée en cours ────────────────────────────────────────────────────────
  String? _dayMode; // 'gps' | 'compteur'
  int? _startKm;

  // ── Journée ─────────────────────────────────────────────────────────────────
  // Le chauffeur ne saisit que ses km. Le reste vient de son affectation ou
  // de sa dernière journée, et reste corrigeable dans « Détails ».
  String? _selectedTruck;
  final _tourNumberCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();

  // ── Init ─────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await DriverSession.init();

    // Connecté avec un compte chauffeur : c'est ce compte qui dit qui l'on
    // est, pas le nom mémorisé — le téléphone a pu servir à un collègue.
    String? name = widget.firebaseEmail == null
        ? DriverSession.driverName
        : null;
    final drivers = ref.read(appStateProvider).drivers;
    if (name == null && widget.firebaseEmail != null) {
      final email = widget.firebaseEmail!.toLowerCase();
      final match = drivers.cast<Driver?>().firstWhere(
        (d) => d!.accessEmail?.toLowerCase() == email,
        orElse: () => null,
      );
      name = match?.name;
    }
    // Fallback : chercher par nom Firebase
    if (name == null && widget.firebaseName != null) {
      final match = drivers.cast<Driver?>().firstWhere(
        (d) =>
            d!.name.toLowerCase() == widget.firebaseName!.toLowerCase() ||
            d.fullName.toLowerCase() == widget.firebaseName!.toLowerCase(),
        orElse: () => null,
      );
      name = match?.name;
    }
    if (name != null) await DriverSession.setDriverName(name);

    setState(() {
      _driverName = name;
      _tourStart = DriverSession.tourStartTime;
      _dayMode = DriverSession.dayMode ?? (_tourStart != null ? 'gps' : null);
      _startKm = DriverSession.startKm;
      _loading = false;
    });
    if (_tourStart != null) {
      _startTimer();
      if (_dayMode == 'gps') {
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
    }
    if (ref.read(appStateProvider).trucks.isNotEmpty) {
      _selectedTruck = ref.read(appStateProvider).trucks.first.plate;
    }

    // Pré-remplir selon l'affectation permanente du chauffeur
    if (_driverName != null) {
      final assignment = ref.read(appStateProvider).getAssignment(_driverName!);
      if (assignment != null) {
        _selectedTruck = assignment.truckPlate;
        if (assignment.companyName != null &&
            assignment.companyName!.isNotEmpty) {
          _companyCtrl.text = assignment.companyName!;
        }
      }
    }

    // Le QR scanné ce matin l'emporte sur l'affectation habituelle.
    final pending = DriverSession.pendingTruck;
    if (pending != null &&
        ref.read(appStateProvider).trucks.any((t) => t.plate == pending)) {
      _selectedTruck = pending;
    }
    await DriverSession.setPendingTruck(null);

    if (_tourNumberCtrl.text.isEmpty && _driverName != null) {
      final assigned = ref
          .read(appStateProvider)
          .drivers
          .where((d) => d.name == _driverName)
          .firstOrNull
          ?.assignedTourNumber;
      if (assigned != null) _tourNumberCtrl.text = assigned;
    }

    // Sinon, pré-remplir avec les dernières valeurs
    final lastTour = DriverSession.lastTourNumber;
    final lastCompany = DriverSession.lastCompany;
    if (_tourNumberCtrl.text.isEmpty &&
        lastTour != null &&
        lastTour.isNotEmpty) {
      _tourNumberCtrl.text = lastTour;
    }
    if (_companyCtrl.text.isEmpty &&
        lastCompany != null &&
        lastCompany.isNotEmpty) {
      _companyCtrl.text = lastCompany;
    }
    if (mounted) setState(() {});
    await _closeForgottenDay();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final start = _tourStart;
      final now = DateTime.now();
      if (start != null && start.day != now.day && _dayMode == 'gps') {
        _closeForgottenDay();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _tourNumberCtrl.dispose();
    _companyCtrl.dispose();
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

  void _onGpsKmUpdate(double km) {
    if (!mounted) return;
    setState(() => _gpsKm = km);
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
              child: Text(
                'Ajouter une dépense carburant',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
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
      _scanFuelTicket(
        choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
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
          content: Text(
            result.error ?? 'Impossible de lire le montant sur le ticket.',
          ),
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
              _scanLine(
                'Prix/L',
                '${result.pricePerLiter!.toStringAsFixed(3)} €',
              ),
            if (result.date != null)
              _scanLine(
                'Date',
                '${result.date!.day.toString().padLeft(2, '0')}/${result.date!.month.toString().padLeft(2, '0')}/${result.date!.year}',
              ),
            if (result.station != null) _scanLine('Station', result.station!),
            const SizedBox(height: 12),
            Text(
              'Camion : $_selectedTruck',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
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
              Text(
                'Camion : $_selectedTruck',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Montant (€) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.euro),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: litersCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
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
                amountCtrl.text.replaceAll(',', '.').trim(),
              );
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

    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.').trim());
    final liters = double.tryParse(litersCtrl.text.replaceAll(',', '.').trim());
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
      note:
          '${source == 'scan' ? 'Scan' : 'Saisie'} chauffeur ${_driverName ?? ""}${station != null ? ' - $station' : ''}',
      driverName: _driverName,
    );

    ref.read(appStateProvider).addExpense(expense);

    // Notifier le manager
    ref
        .read(appStateProvider)
        .addManagerAlert(
          ManagerAlert(
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
          ),
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Dépense enregistrée : ${amount.toStringAsFixed(2)} € — Manager notifié.',
          ),
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
          child: Text(
            label,
            style: const TextStyle(color: DC.textSecondary, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
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
        if (assignment.companyName != null &&
            assignment.companyName!.isNotEmpty) {
          _companyCtrl.text = assignment.companyName!;
        }
      }
    });
  }

  /// Saisie à la main : le recours quand ni photo ni GPS ne sont possibles.
  Future<void> _saisirKm() async {
    final result = await _openDaySheet(measuredKm: null, source: null);
    if (result == null) return;
    await _saveDay(result, start: null, kmSource: 'saisie');
  }

  /// Choix recommandé : une photo du compteur le matin, une le soir.
  Future<void> _photoDepart() async {
    if (_selectedTruck == null) return;
    final last = ref.read(appStateProvider).lastOdometer(_selectedTruck!);
    final reading = await _captureOdometer(
      title: 'Compteur au départ',
      minKm: last?.km,
    );
    if (reading == null || !mounted) return;
    ref
        .read(appStateProvider)
        .addOdometer(
          OdometerReading(
            id: '${DateTime.now().microsecondsSinceEpoch}_odo',
            truckPlate: _selectedTruck!,
            date: DateTime.now(),
            km: reading.$1,
            driverName: _driverName,
            source: reading.$2,
            isStart: true,
          ),
        );
    await DriverSession.startTour();
    await DriverSession.setDay(mode: 'compteur', startKm: reading.$1);
    setState(() {
      _dayMode = 'compteur';
      _startKm = reading.$1;
      _tourStart = DriverSession.tourStartTime;
    });
    _startTimer();
  }

  /// Le GPS compte les km jusqu'à « Terminer la journée ».
  Future<void> _lancerGps() async {
    if (_gpsStarting) return;
    setState(() => _gpsStarting = true);
    _gps.onKmUpdate = _onGpsKmUpdate;
    bool started;
    try {
      started = await _gps.startTracking();
    } catch (_) {
      started = false;
    }
    if (!mounted) return;
    if (!started) {
      setState(() => _gpsStarting = false);
      _snack(
        'GPS indisponible : autorise la localisation, '
        'ou prends le compteur en photo.',
      );
      return;
    }
    await DriverSession.startTour();
    await DriverSession.setDay(mode: 'gps');
    setState(() {
      _gpsStarting = false;
      _gpsActive = true;
      _gpsKm = 0.0;
      _dayMode = 'gps';
      _tourStart = DriverSession.tourStartTime;
    });
    _startTimer();
  }

  Future<void> _annuler() async {
    final gps = _dayMode == 'gps';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          gps ? 'Arrêter le GPS sans enregistrer ?' : 'Annuler la journée ?',
        ),
        content: Text(
          gps
              ? 'Les km comptés depuis le départ seront perdus.'
              : 'Le relevé du matin est conservé ; la journée ne sera pas enregistrée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Annuler la journée'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (gps) await _gps.stopTracking();
    await _endSession();
  }

  Future<void> _terminer() async {
    if (_dayMode == 'compteur' && _startKm != null) {
      final reading = await _captureOdometer(
        title: 'Compteur à l’arrivée',
        minKm: _startKm,
      );
      if (reading == null || !mounted) return;
      final km = (reading.$1 - _startKm!).toDouble();
      final result = await _openDaySheet(measuredKm: km, source: 'compteur');
      if (result == null) return;
      ref
          .read(appStateProvider)
          .addOdometer(
            OdometerReading(
              id: '${DateTime.now().microsecondsSinceEpoch}_odo',
              truckPlate: _selectedTruck!,
              date: DateTime.now(),
              km: reading.$1,
              driverName: _driverName,
              source: reading.$2,
              isStart: false,
            ),
          );
      await _saveDay(
        result,
        start: _tourStart,
        kmSource: (result.km - km).abs() < 1 ? 'compteur' : 'saisie',
      );
      return;
    }

    // GPS : il continue tant que le chauffeur n'a pas validé ; s'il referme
    // la feuille, sa journée n'est pas coupée.
    final gpsKm = _gps.currentKm;
    final result = await _openDaySheet(measuredKm: gpsKm, source: 'gps');
    if (result == null) return;
    await _gps.stopTracking();
    final edited = gpsKm > 0 && (result.km - gpsKm).abs() > gpsKm * 0.05;
    await _saveDay(
      result,
      start: _tourStart,
      kmSource: edited || gpsKm == 0 ? 'saisie' : 'gps',
    );
  }

  /// Journée commencée un autre jour et jamais terminée.
  ///
  /// Au GPS, on l'enregistre avec les km comptés : mieux vaut une journée
  /// mesurée qu'une journée perdue. Au compteur, on ne peut rien en dire :
  /// le relevé du prochain départ du camion la complétera côté manager.
  bool _closing = false;

  Future<void> _closeForgottenDay() async {
    final start = _tourStart;
    if (start == null || _closing) return;
    final now = DateTime.now();
    if (start.year == now.year &&
        start.month == now.month &&
        start.day == now.day) {
      return;
    }
    _closing = true;
    try {
      await _closeDay(start);
    } finally {
      _closing = false;
    }
  }

  Future<void> _closeDay(DateTime start) async {
    if (_dayMode == 'gps') {
      final km = await _gps.stopTracking();
      if (km > 0 && _selectedTruck != null && _driverName != null) {
        await _saveDay(
          _DayResult(
            km: km,
            tourNumber: _tourNumberCtrl.text.trim(),
            company: _companyCtrl.text.trim(),
            pickups: 0,
            handlingClient: null,
            extraTour: false,
          ),
          start: start,
          kmSource: 'gps-auto',
          date: start,
          quiet: true,
        );
        _snack(
          'Ta journée du ${start.day}/${start.month} a été enregistrée '
          'automatiquement : ${km.toStringAsFixed(0)} km au GPS.',
        );
        return;
      }
    } else {
      _snack(
        'Ta journée du ${start.day}/${start.month} n’a pas été terminée : '
        'la photo du compteur de ce matin la complétera.',
      );
    }
    await _endSession();
  }

  Future<void> _endSession() async {
    await DriverSession.endTour();
    await DriverSession.clearDay();
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _tourStart = null;
      _gpsActive = false;
      _gpsKm = 0.0;
      _dayMode = null;
      _startKm = null;
    });
  }

  /// Photo du compteur → chiffre lu automatiquement, que le chauffeur
  /// confirme ou corrige. Renvoie (km, 'photo' | 'saisie').
  Future<(int, String)?> _captureOdometer({required String title, int? minKm}) {
    return showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _OdometerSheet(title: title, minKm: minKm),
    );
  }

  Future<_DayResult?> _openDaySheet({
    required double? measuredKm,
    required String? source,
  }) {
    final state = ref.read(appStateProvider);
    final assignment = state.getAssignment(_driverName ?? '');
    final lockedCompany =
        assignment?.companyName != null && assignment!.companyName!.isNotEmpty;
    return showModalBottomSheet<_DayResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DaySheet(
        measuredKm: measuredKm,
        source: source,
        tourNumber: _tourNumberCtrl.text.trim(),
        company: _companyCtrl.text.trim(),
        companyLocked: lockedCompany,
        companies: [for (final c in state.clientPricings) c.companyName],
      ),
    );
  }

  Future<void> _saveDay(
    _DayResult r, {
    required DateTime? start,
    required String kmSource,
    DateTime? date,
    bool quiet = false,
  }) async {
    if (_selectedTruck == null || _driverName == null) {
      _snack('Choisis d’abord un camion.');
      return;
    }
    final now = DateTime.now();
    final day = date ?? now;
    final state = ref.read(appStateProvider);

    state.addDriverDayEntry(
      DriverDayEntry(
        id: now.microsecondsSinceEpoch.toString(),
        date: day,
        driverName: _driverName!,
        truckPlate: _selectedTruck!,
        kmTotal: r.km,
        clientsCount: 0,
        pickupCount: r.pickups,
      ),
    );
    state.addTour(
      Tour(
        id: '${now.microsecondsSinceEpoch}_tour',
        tourNumber: r.tourNumber,
        date: day,
        driverName: _driverName!,
        truckPlate: _selectedTruck!,
        companyName: r.company.isEmpty ? null : r.company,
        startTime: start != null ? _fmtTime(start) : null,
        endTime: start != null && date == null ? _fmtTime(now) : null,
        kmTotal: r.km,
        // Les points livrés viennent du relevé du commissionnaire, saisi
        // par le manager : on ne les demande plus au chauffeur.
        clientsCount: 0,
        pickupCount: r.pickups,
        hasHandling: r.handlingClient != null,
        handlingClientName: r.handlingClient,
        handlingDate: r.handlingClient != null ? day : null,
        extraTour: r.extraTour,
        status: 'terminée',
        kmSource: kmSource,
      ),
    );

    _tourNumberCtrl.text = r.tourNumber;
    _companyCtrl.text = r.company;
    await DriverSession.saveLastTour(r.tourNumber, r.company);
    await _endSession();
    if (!quiet) {
      _snack(
        'Journée enregistrée — ${r.km.toStringAsFixed(r.km % 1 == 0 ? 0 : 1)} km',
      );
    }
  }

  Future<void> _signalerPanne(List<Truck> trucks) async {
    // Motif obligatoire
    String? motif;
    final motifs = [
      'Panne mécanique',
      'Panne électrique',
      'Crevaison',
      'Accident',
      'Autre',
    ];

    motif = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Motif du changement'),
        children: motifs
            .map(
              (m) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, m),
                child: Text(m),
              ),
            )
            .toList(),
      ),
    );
    if (motif == null || !mounted) return;

    // Choisir le nouveau camion (flotte ou prêt)
    final availableTrucks = trucks
        .where(
          (t) =>
              t.plate != _selectedTruck &&
              t.truckStatus == TruckStatus.fonctionnel,
        )
        .toList();

    final newTruck = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final plateCtrl = TextEditingController();
        return SimpleDialog(
          title: const Text('Camion de remplacement'),
          children: [
            // Camions de la flotte
            ...availableTrucks.map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, t.plate),
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(t.plate),
                  subtitle: Text(t.model),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
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
                  Text(
                    'Camion de prêt (hors flotte)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                      ),
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
        : (trucks.where((t) => t.plate == actualPlate).firstOrNull?.model ??
              '');
    final oldTruck = _selectedTruck;

    // Mettre l'ancien camion en panne
    final oldTruckObj = trucks.where((t) => t.plate == oldTruck).firstOrNull;
    if (oldTruckObj != null) {
      ref
          .read(appStateProvider)
          .updateTruck(
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
      message:
          'Changement : $oldTruck → $actualPlate${isPret ? ' (camion de prêt, hors flotte)' : ' ($truckModel)'}.\n'
          'Motif : $motif.\n'
          'Le camion $oldTruck a été passé en statut "En panne".',
      date: now,
      driverName: _driverName,
      oldTruckPlate: oldTruck,
      newTruckPlate: actualPlate,
    );
    ref.read(appStateProvider).addManagerAlert(alert);

    _snack(
      isPret
          ? 'Camion de prêt $actualPlate activé. Le manager a été alerté.'
          : 'Camion changé → $actualPlate. Le manager a été alerté.',
    );
  }

  Future<void> _changerCamion(List<Truck> trucks) async {
    // Étape 1 : choisir le nouveau camion
    final newTruck = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Changer de camion'),
        children: trucks
            .where((t) => t.plate != _selectedTruck)
            .map(
              (t) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, t.plate),
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(t.plate),
                  subtitle: Text(t.model),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            )
            .toList(),
      ),
    );
    if (newTruck == null || !mounted) return;

    final truckModel =
        trucks.where((t) => t.plate == newTruck).firstOrNull?.model ?? '';

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
      message:
          'Changement temporaire : $oldTruck → $newTruck ($truckModel). '
          'Motif probable : panne ou remplacement.',
      date: now,
      driverName: _driverName,
      oldTruckPlate: oldTruck,
      newTruckPlate: newTruck,
    );
    ref.read(appStateProvider).addManagerAlert(alert);

    // Mettre à jour les day entries du jour pour ce chauffeur
    ref
        .read(appStateProvider)
        .updateDriverDayEntryTruck(
          driverName: _driverName!,
          date: now,
          newTruckPlate: newTruck,
        );

    _snack('Camion changé → $newTruck ($truckModel)');
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Stats chauffeur (sans CA) ─────────────────────────────────────────────

  Widget _buildStats() {
    final now = DateTime.now();
    final name = _driverName!.toLowerCase();

    final entries =
        ref
            .read(appStateProvider)
            .driverDayEntries
            .where(
              (e) =>
                  e.driverName.toLowerCase() == name &&
                  e.date.year == now.year &&
                  e.date.month == now.month,
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final allTours = ref
        .read(appStateProvider)
        .tours
        .where(
          (t) =>
              t.driverName.toLowerCase() == name &&
              t.date.year == now.year &&
              t.date.month == now.month,
        )
        .toList();

    final kmTotal = entries.fold(0.0, (sum, e) => sum + e.kmTotal);
    final jours = entries
        .map((e) => '${e.date.year}-${e.date.month}-${e.date.day}')
        .toSet()
        .length;

    final kmMoy = jours > 0 ? kmTotal / jours : 0.0;

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
            _StatBox(
              label: 'Km ce mois',
              value: '${kmTotal.toStringAsFixed(0)} km',
            ),
            const SizedBox(width: 10),
            _StatBox(
              label: 'Km/jour (moy.)',
              value: '${kmMoy.toStringAsFixed(0)} km',
            ),
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
          const Text(
            'Aucune saisie ce mois.',
            style: TextStyle(color: DC.textSecondary),
          )
        else
          ...entries.map((e) {
            final dayKey = '${e.date.year}-${e.date.month}-${e.date.day}';
            final dayTours = allTours.where((t) {
              return '${t.date.year}-${t.date.month}-${t.date.day}' == dayKey;
            }).toList();

            final manutentionTours = dayTours
                .where((t) => t.hasHandling)
                .toList();
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
                  Expanded(child: Text('${e.kmTotal.toStringAsFixed(0)} km')),
                  // Ramasses
                  if (e.pickupCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(
                        '${e.pickupCount} ram.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ),
                  // Manutention
                  if (hasManu)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
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
      '',
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    return months[m];
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chargement...')),
        body: const DCShimmerList(itemCount: 4),
      );
    }

    // ── Sélection profil ─────────────────────────────────────────────────────
    if (_driverName == null) {
      return _buildProfileSelector();
    }

    final unreadCount = ref
        .watch(appStateProvider)
        .unreadCountForDriver(_driverName!);
    final unreadMsgCount = ref
        .watch(appStateProvider)
        .unreadMessagesForDriver(_driverName!);

    final pages = [
      _tourStart == null ? _buildIdle() : _buildActiveTour(),
      DriverDashboardPage(driverName: _driverName!),
      ChatScreen(driverName: _driverName!, isManager: false, showAppBar: false),
      _buildSettings(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour $_driverName', overflow: TextOverflow.ellipsis),
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
    final unreadCount = ref
        .watch(appStateProvider)
        .unreadCountForDriver(_driverName!);

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
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Builder(
                builder: (_) {
                  final driver = ref
                      .read(appStateProvider)
                      .drivers
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
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
                },
              ),
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
            final driver = ref
                .read(appStateProvider)
                .drivers
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
            if (confirm == true) await _quitterProfil();
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
            if (confirm == true) await _quitterProfil();
          },
        ),
      ],
    );
  }

  /// Connecté avec un compte chauffeur, quitter son profil c'est se
  /// déconnecter : le téléphone revient à la liste des chauffeurs du QR.
  Future<void> _quitterProfil() async {
    await DriverSession.clearDriverName();
    if (widget.firebaseEmail != null) {
      if (_tourStart != null) {
        await _gps.stopTracking();
        await DriverSession.endTour();
      }
      await AuthService.signOut();
      return;
    }
    setState(() {
      _driverName = null;
      _tabIndex = 0;
    });
  }

  // ── Vue : pas de tournée en cours ────────────────────────────────────────

  Widget _buildIdle() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = _monthLabel(now.month);
    final state = ref.watch(appStateProvider);
    final today = state.tours
        .where(
          (t) =>
              t.driverName == _driverName &&
              t.date.year == now.year &&
              t.date.month == now.month &&
              t.date.day == now.day,
        )
        .toList();
    final todayKm = today.fold<double>(0, (s, t) => s + t.kmTotal);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Text(
          '$day $month ${now.year}',
          style: context.tBody(15, color: context.cInk2),
        ),
        const SizedBox(height: 12),

        _truckCard(state.trucks, allowChange: true),

        if (today.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.cSuccessBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: DC.success, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Déjà enregistré aujourd’hui : ${todayKm.toStringAsFixed(0)} km',
                    style: context.tBody(14, w: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),
        Text('Tes kilomètres', style: context.tTitle(20)),
        const SizedBox(height: 10),
        _ChoiceCard(
          icon: Icons.photo_camera_outlined,
          color: DC.primary,
          title: 'Photo du compteur',
          subtitle:
              'Une photo au départ, une au retour : les km se calculent seuls',
          badge: 'Le plus fiable',
          onTap: _selectedTruck == null ? null : _photoDepart,
        ),
        const SizedBox(height: 10),
        _ChoiceCard(
          icon: Icons.gps_fixed,
          color: DC.success,
          title: 'Lancer le GPS',
          subtitle: 'Les km se comptent tout seuls jusqu’à la fin',
          busy: _gpsStarting,
          onTap: _selectedTruck == null ? null : _lancerGps,
        ),
        Center(
          child: TextButton(
            onPressed: _selectedTruck == null ? null : _saisirKm,
            child: const Text('Ou saisir mes km à la main'),
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
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
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              _isScanning ? 'Analyse en cours...' : 'Dépense carburant',
            ),
          ),
        ),

        const SizedBox(height: 28),
        const Divider(),
        const SizedBox(height: 16),
        _buildStats(),
      ],
    );
  }

  /// Le camion du jour : celui du QR scanné, sinon celui de l'affectation.
  Widget _truckCard(List<Truck> trucks, {required bool allowChange}) {
    final truck = trucks.where((t) => t.plate == _selectedTruck).firstOrNull;
    final company = _companyCtrl.text.trim();
    final assignment = ref
        .read(appStateProvider)
        .getAssignment(_driverName ?? '');

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(
        children: [
          Icon(Icons.local_shipping_outlined, color: context.cInk2),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  truck?.plate ?? 'Aucun camion choisi',
                  style: context.tMono(
                    17,
                    w: FontWeight.w800,
                    color: truck == null ? DC.error : context.cInk,
                  ),
                ),
                if (truck != null && truck.model.isNotEmpty)
                  Text(
                    truck.model,
                    style: context.tBody(12.5, color: context.cInk2),
                  ),
                if (company.isNotEmpty)
                  Text(
                    company,
                    style: context.tBody(
                      12.5,
                      w: FontWeight.w600,
                      color: context.cInk2,
                    ),
                  ),
              ],
            ),
          ),
          if (allowChange)
            TextButton(
              onPressed: trucks.isEmpty ? null : () => _pickTruck(trucks),
              child: Text(truck == null ? 'Choisir' : 'Changer'),
            )
          else if (assignment != null)
            TextButton.icon(
              onPressed: () => _signalerPanne(trucks),
              style: TextButton.styleFrom(foregroundColor: DC.warning),
              icon: const Icon(Icons.warning_amber_rounded, size: 16),
              label: const Text('Panne'),
            ),
        ],
      ),
    );
  }

  Future<void> _pickTruck(List<Truck> trucks) async {
    final plate = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Quel camion ?'),
        children: [
          for (final t in trucks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, t.plate),
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  t.plate == _selectedTruck
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                ),
                title: Text(t.plate),
                subtitle: t.model.isEmpty ? null : Text(t.model),
              ),
            ),
        ],
      ),
    );
    if (plate != null) setState(() => _selectedTruck = plate);
  }

  // ── Vue : GPS en cours ───────────────────────────────────────────────────

  Widget _buildActiveTour() {
    final trucks = ref.read(appStateProvider).trucks;
    final compteur = _dayMode == 'compteur';
    final ok = compteur || _gpsActive;
    final accent = compteur
        ? DC.primary
        : (_gpsActive ? DC.success : DC.warning);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
                decoration: BoxDecoration(
                  color: compteur
                      ? context.cPrimaryBg
                      : (ok ? context.cSuccessBg : context.cWarningBg),
                  borderRadius: BorderRadius.circular(DC.rCard),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          compteur
                              ? Icons.speed
                              : (_gpsActive ? Icons.gps_fixed : Icons.gps_off),
                          size: 18,
                          color: accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          compteur
                              ? 'Journée en cours'
                              : (_gpsActive
                                    ? 'GPS en cours'
                                    : 'GPS interrompu'),
                          style: context.tBody(
                            14,
                            w: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FittedBox(
                      child: Text(
                        compteur
                            ? '${_startKm ?? '—'} km'
                            : '${_gpsKm.toStringAsFixed(1)} km',
                        style: context.tTitle(
                          compteur ? 40 : 54,
                          w: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (compteur)
                      Text(
                        'au compteur ce matin',
                        style: context.tBody(13, color: context.cInk2),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Départ ${_fmtTime(_tourStart!)} · ${_elapsed()}',
                      style: context.tBody(14, color: context.cInk2),
                    ),
                    if (!ok) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Tu pourras corriger les km en terminant la journée.',
                        textAlign: TextAlign.center,
                        style: context.tBody(12.5, color: context.cInk2),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _truckCard(trucks, allowChange: false),
              const SizedBox(height: 12),
              Text(
                compteur
                    ? 'Au retour, touche « Terminer » et photographie le compteur : '
                          'les km de la journée se calculent seuls.'
                    : 'Garde l’application ouverte pendant la tournée : '
                          'sur certains téléphones, le GPS s’arrête quand l’écran est verrouillé.',
                style: context.tBody(12.5, color: context.cInk3),
              ),
            ],
          ),
        ),
        DCStickyBottomBar(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _annuler,
                style: OutlinedButton.styleFrom(
                  foregroundColor: DC.error,
                  side: const BorderSide(color: DC.error),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Annuler'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _terminer,
                style: FilledButton.styleFrom(
                  backgroundColor: compteur ? DC.primary : DC.success,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: Icon(
                  compteur ? Icons.photo_camera_outlined : Icons.flag_outlined,
                  size: 20,
                ),
                label: const Text(
                  'Terminer la journée',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
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
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: DC.textSecondary,
                              ),
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
          _infoRow(
            Icons.person_outline,
            'Prénom',
            driver.firstName ?? 'Non renseigné',
          ),
          _infoRow(
            Icons.cake_outlined,
            'Date de naissance',
            _fmt(driver.birthDate),
          ),
          _infoRow(
            Icons.flag_outlined,
            'Nationalité',
            driver.nationality ?? 'Non renseignée',
          ),
          const SizedBox(height: 16),

          // ── Contact
          _section('Contact'),
          _infoRow(
            Icons.phone_outlined,
            'Téléphone',
            driver.phone ?? 'Non renseigné',
          ),
          _infoRow(
            Icons.email_outlined,
            'Email',
            driver.email ?? 'Non renseigné',
          ),
          _infoRow(
            Icons.home_outlined,
            'Adresse',
            driver.address ?? 'Non renseignée',
          ),
          const SizedBox(height: 16),

          // ── Administratif
          _section('Administratif'),
          _infoRow(
            Icons.badge_outlined,
            'N° Sécurité sociale',
            driver.socialSecurityNumber ?? 'Non renseigné',
          ),
          _infoRow(
            Icons.work_outline,
            'Statut',
            driverStatusLabel(driver.status),
          ),
          _infoRow(
            Icons.calendar_today_outlined,
            'Date d\'embauche',
            _fmt(driver.hireDate),
          ),
          const SizedBox(height: 16),

          // ── Permis de conduire
          _section('Permis de conduire'),
          _infoRow(
            Icons.credit_card_outlined,
            'N° de permis',
            driver.licenseNumber ?? 'Non renseigné',
          ),
          _infoRow(
            Icons.event_busy_outlined,
            'Expiration permis',
            _fmt(driver.licenseExpiryDate),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Catégories détenues',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
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
          _infoRow(
            Icons.emergency_outlined,
            'Nom',
            driver.emergencyContact ?? 'Non renseigné',
          ),
          _infoRow(
            Icons.phone_outlined,
            'Téléphone',
            driver.emergencyPhone ?? 'Non renseigné',
          ),

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
    child: Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
    ),
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
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: DC.textSecondary),
            ),
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
        color: has
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: has
              ? Colors.green.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: 0.3),
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

// ── Les deux choix du matin ──────────────────────────────────────────────────

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, subtitle;
  final bool busy;
  final String? badge;
  final VoidCallback? onTap;

  const _ChoiceCard({
    this.badge,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: onTap == null ? 0.5 : 1,
      child: Material(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(DC.rCard),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(DC.rCard),
              border: Border.all(
                color: color.withValues(alpha: 0.45),
                width: 1.4,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: busy
                      ? Padding(
                          padding: const EdgeInsets.all(15),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: color,
                          ),
                        )
                      : Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.tTitle(19)),
                      if (badge != null) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            badge!,
                            style: context.tBody(
                              10.5,
                              w: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: context.tBody(13.5, color: context.cInk2),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: context.cInk3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Fin de journée ───────────────────────────────────────────────────────────

class _DayResult {
  final double km;
  final String tourNumber, company;
  final int pickups;
  final String? handlingClient;
  final bool extraTour;
  const _DayResult({
    required this.km,
    required this.tourNumber,
    required this.company,
    required this.pickups,
    required this.handlingClient,
    required this.extraTour,
  });
}

/// Les km, et c'est tout. Le reste — n° de tournée, commissionnaire, options
/// facturables — est prérempli et replié dans « Détails ».
class _DaySheet extends StatefulWidget {
  /// Km mesurés (GPS ou compteur) ; null en saisie manuelle.
  final double? measuredKm;

  /// 'gps' ou 'compteur' ; null en saisie manuelle.
  final String? source;
  final String tourNumber, company;
  final bool companyLocked;
  final List<String> companies;

  const _DaySheet({
    required this.measuredKm,
    required this.source,
    required this.tourNumber,
    required this.company,
    required this.companyLocked,
    required this.companies,
  });

  @override
  State<_DaySheet> createState() => _DaySheetState();
}

class _DaySheetState extends State<_DaySheet> {
  late final _km = TextEditingController(
    text: widget.measuredKm != null && widget.measuredKm! > 0
        ? widget.measuredKm!.toStringAsFixed(widget.source == 'gps' ? 1 : 0)
        : '',
  );
  late final _tour = TextEditingController(text: widget.tourNumber);
  late final _company = TextEditingController(text: widget.company);
  final _pickups = TextEditingController();
  final _handling = TextEditingController();
  bool _hasHandling = false;
  bool _extraTour = false;
  String? _error;

  @override
  void dispose() {
    _km.dispose();
    _tour.dispose();
    _company.dispose();
    _pickups.dispose();
    _handling.dispose();
    super.dispose();
  }

  void _submit() {
    final km = double.tryParse(_km.text.replaceAll(',', '.').trim());
    if (km == null || km <= 0) {
      setState(() => _error = 'Indique les kilomètres parcourus');
      return;
    }
    if (km > 2000) {
      setState(
        () => _error = 'Plus de 2 000 km en une journée ? Vérifie le chiffre.',
      );
      return;
    }
    if (_hasHandling && _handling.text.trim().isEmpty) {
      setState(() => _error = 'Indique le client de la manutention');
      return;
    }
    Navigator.pop(
      context,
      _DayResult(
        km: km,
        tourNumber: _tour.text.trim(),
        company: _company.text.trim(),
        pickups: int.tryParse(_pickups.text.trim()) ?? 0,
        handlingClient: _hasHandling ? _handling.text.trim() : null,
        extraTour: _extraTour,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gps = widget.measuredKm != null;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              gps ? 'Fin de journée' : 'Mes km du jour',
              style: context.tTitle(22),
            ),
            const SizedBox(height: 4),
            Text(
              gps
                  ? (widget.source == 'compteur'
                        ? 'D’après le compteur : ${widget.measuredKm!.toStringAsFixed(0)} km.'
                        : 'Le GPS a compté ${widget.measuredKm!.toStringAsFixed(1)} km. '
                              'Corrige si besoin.')
                  : 'Le total parcouru aujourd’hui avec le camion.',
              style: context.tBody(13.5, color: context.cInk2),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _km,
              autofocus: !gps,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textAlign: TextAlign.center,
              style: context.tTitle(34, w: FontWeight.w800),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '0',
                suffixText: 'km',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Détails (facultatif)',
                  style: context.tBody(14, w: FontWeight.w600),
                ),
                subtitle: Text(
                  [
                    if (_tour.text.isNotEmpty) 'Tournée ${_tour.text}',
                    if (_company.text.isNotEmpty) _company.text,
                  ].join(' · '),
                  style: context.tBody(12, color: context.cInk3),
                ),
                childrenPadding: const EdgeInsets.only(bottom: 8),
                children: [
                  TextField(
                    controller: _tour,
                    decoration: const InputDecoration(
                      labelText: 'N° de tournée',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (widget.companyLocked)
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Commissionnaire (affecté par le manager)',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(_company.text),
                    )
                  else
                    Autocomplete<String>(
                      initialValue: TextEditingValue(text: _company.text),
                      optionsBuilder: (v) => widget.companies.where(
                        (c) => c.toLowerCase().contains(v.text.toLowerCase()),
                      ),
                      onSelected: (v) => _company.text = v,
                      fieldViewBuilder: (ctx, ctrl, focus, onSubmit) =>
                          TextField(
                            controller: ctrl,
                            focusNode: focus,
                            onChanged: (v) => _company.text = v,
                            decoration: const InputDecoration(
                              labelText: 'Commissionnaire',
                              border: OutlineInputBorder(),
                            ),
                          ),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _pickups,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Ramasses',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Manutention'),
                    value: _hasHandling,
                    onChanged: (v) => setState(() => _hasHandling = v),
                  ),
                  if (_hasHandling)
                    TextField(
                      controller: _handling,
                      decoration: const InputDecoration(
                        labelText: 'Client de la manutention',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Tournée supplémentaire'),
                    value: _extraTour,
                    onChanged: (v) => setState(() => _extraTour = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Enregistrer la journée',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Photo du compteur ────────────────────────────────────────────────────────

/// Le chauffeur photographie le compteur ; le chiffre est lu tout seul et il
/// n'a qu'à confirmer. Sans lecture possible (pas de réseau, photo floue),
/// il tape le chiffre : la journée n'est jamais bloquée.
class _OdometerSheet extends StatefulWidget {
  final String title;

  /// Dernier relevé connu du camion : un compteur ne recule pas.
  final int? minKm;

  const _OdometerSheet({required this.title, this.minKm});

  @override
  State<_OdometerSheet> createState() => _OdometerSheetState();
}

class _OdometerSheetState extends State<_OdometerSheet> {
  final _km = TextEditingController();
  Uint8List? _photo;
  bool _reading = false;
  bool _fromPhoto = false;
  String? _info;
  String? _error;

  @override
  void initState() {
    super.initState();
    // On ouvre directement l'appareil photo : c'est le geste attendu.
    WidgetsBinding.instance.addPostFrameCallback((_) => _shoot());
  }

  @override
  void dispose() {
    _km.dispose();
    super.dispose();
  }

  Future<void> _shoot() async {
    final x = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1400,
    );
    if (x == null || !mounted) return;
    final bytes = await x.readAsBytes();
    setState(() {
      _photo = bytes;
      _reading = true;
      _info = null;
      _error = null;
    });
    final mime = x.name.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';
    final r = await OcrService.readOdometer(bytes, mime);
    if (!mounted) return;
    setState(() {
      _reading = false;
      if (r.km != null) {
        _km.text = '${r.km}';
        _fromPhoto = true;
        _info = 'Lu sur la photo — vérifie le chiffre.';
      } else {
        _info = 'Chiffre non reconnu : tape-le ci-dessous.';
      }
    });
  }

  void _submit() {
    final km = int.tryParse(_km.text.replaceAll(RegExp(r'\s'), ''));
    if (km == null || km <= 0) {
      setState(() => _error = 'Indique le kilométrage du compteur');
      return;
    }
    final min = widget.minKm;
    if (min != null && km < min) {
      setState(
        () => _error =
            'Plus petit que le dernier relevé ($min km). '
            'Un compteur ne recule pas : vérifie.',
      );
      return;
    }
    if (min != null && km - min > 3000) {
      setState(
        () => _error =
            '${km - min} km depuis le dernier relevé ? '
            'Vérifie le chiffre.',
      );
      return;
    }
    Navigator.pop(context, (km, _fromPhoto ? 'photo' : 'saisie'));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: context.tTitle(22)),
            const SizedBox(height: 4),
            Text(
              'Le compteur kilométrique total, pas le compteur journalier.',
              style: context.tBody(13.5, color: context.cInk2),
            ),
            const SizedBox(height: 14),
            InkWell(
              onTap: _reading ? null : _shoot,
              borderRadius: BorderRadius.circular(DC.rCard),
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: context.cSurface2,
                  borderRadius: BorderRadius.circular(DC.rCard),
                  border: Border.all(color: context.cBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: _photo == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.photo_camera_outlined,
                            size: 40,
                            color: DC.primary,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Photographier le compteur',
                            style: context.tBody(
                              15,
                              w: FontWeight.w600,
                              color: DC.primary,
                            ),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.memory(_photo!, fit: BoxFit.cover),
                          if (_reading)
                            Container(
                              color: Colors.black45,
                              alignment: Alignment.center,
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Lecture du compteur…',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
              ),
            ),
            if (_info != null) ...[
              const SizedBox(height: 8),
              Text(_info!, style: context.tBody(12.5, color: context.cInk2)),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _km,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: context.tTitle(30, w: FontWeight.w800),
              onChanged: (_) => setState(() {
                _error = null;
                _fromPhoto = false;
              }),
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: widget.minKm != null ? '${widget.minKm}' : '000000',
                suffixText: 'km',
                errorText: _error,
                errorMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _reading ? null : _submit,
              icon: const Icon(Icons.check),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Valider', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
