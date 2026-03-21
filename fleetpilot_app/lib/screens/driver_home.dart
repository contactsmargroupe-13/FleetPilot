import 'dart:async';

import 'package:flutter/material.dart';

import '../services/driver_session.dart';
import '../services/gps_tracking_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'driver_dashboard.dart';
import 'driver_documents.dart';
import 'add_truck.dart';
import 'models/driver.dart';
import 'models/driver_day_entry.dart';
import 'models/manager_alert.dart';
import 'models/tour.dart';

class DriverHomePage extends ConsumerStatefulWidget {
  const DriverHomePage({super.key});

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
    setState(() {
      _driverName = DriverSession.driverName;
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

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _selectProfile(Driver driver) async {
    if (driver.hasPinSet) {
      // Driver has a PIN → verify it
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DriverPinDialog(driver: driver, mode: _DriverPinMode.verify),
      );
      if (ok != true) return;
    } else {
      // No PIN → create one
      final ok = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DriverPinDialog(driver: driver, mode: _DriverPinMode.create),
      );
      if (ok != true) return;
    }

    await DriverSession.setDriverName(driver.name);
    setState(() => _driverName = driver.name);
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
    _tourNumberCtrl.clear();
    _companyCtrl.clear();
    _kmCtrl.clear();
    _clientsCtrl.clear();
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
      weightKg: _d(_weightCtrl.text),
      hasHandling: _hasHandling,
      handlingClientName: _hasHandling ? _handlingCtrl.text.trim() : null,
      handlingDate: _hasHandling ? now : null,
      extraTour: _extraTour,
    );

    ref.read(appStateProvider).addDriverDayEntry(entry);
    ref.read(appStateProvider).addTour(tour);

    await DriverSession.endTour();
    _timer?.cancel();

    // Reset formulaire
    _tourNumberCtrl.clear();
    _companyCtrl.clear();
    _kmCtrl.clear();
    _clientsCtrl.clear();
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
            _StatBox(label: 'Clients/jour (moy.)', value: clientsMoy.toStringAsFixed(1)),
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
          const Text('Aucune saisie ce mois.', style: TextStyle(color: Colors.grey))
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
                  // Clients
                  Expanded(
                    child: Text('${e.clientsCount} clients'),
                  ),
                  // Manutention
                  if (hasManu)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Manu ×${manutentionTours.length}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade800,
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

    final pages = [
      _tourStart == null ? _buildIdle() : _buildActiveTour(),
      DriverDashboardPage(driverName: _driverName!),
      _buildSettings(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour $_driverName'),
      ),
      body: pages[_tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            label: 'Tournée',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
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

        // Section Documents
        const Text(
          'Documents',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 8),
        _SettingsTile(
          icon: Icons.folder_outlined,
          title: 'Mes documents',
          subtitle: 'Permis, fiches de paie, contrats',
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

        const SizedBox(height: 20),

        // Section Compte
        const Text(
          'Compte',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey,
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
          icon: Icons.lock_reset,
          title: 'Modifier mon PIN',
          onTap: () async {
            final driver = ref.read(appStateProvider).drivers
                .where((d) => d.name == _driverName)
                .firstOrNull;
            if (driver == null) return;
            await showDialog<bool>(
              context: context,
              barrierDismissible: false,
              builder: (_) => _DriverPinDialog(
                driver: driver,
                mode: _DriverPinMode.change,
              ),
            );
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
          style: const TextStyle(fontSize: 16, color: Colors.grey),
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
    final clients = ref.read(appStateProvider).clientPricings.map((c) => c.companyName).toList();

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
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.gps_off, color: Colors.grey.shade500, size: 20),
                const SizedBox(width: 10),
                Text(
                  'GPS inactif — saisis les km manuellement',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ],
            ),
          ),

        const SizedBox(height: 20),

        // Camion (verrouillé pendant la tournée, changeable via bouton)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_shipping_outlined, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Camion',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    Text(
                      _selectedTruck != null
                          ? '${_selectedTruck!} • ${trucks.where((t) => t.plate == _selectedTruck).firstOrNull?.model ?? ''}'
                          : 'Aucun',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _changerCamion(trucks),
                icon: const Icon(Icons.swap_horiz, size: 18),
                label: const Text('Changer'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // N° tournée
        TextField(
          controller: _tourNumberCtrl,
          decoration: const InputDecoration(
            labelText: 'Numéro de tournée *',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),

        // Client / entreprise
        if (clients.isNotEmpty)
          DropdownButtonFormField<String>(
            value: _companyCtrl.text.isEmpty ? null : _companyCtrl.text,
            decoration: const InputDecoration(
              labelText: 'Client / Entreprise',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('— Non renseigné —')),
              ...clients.map((c) => DropdownMenuItem(value: c, child: Text(c))),
            ],
            onChanged: (v) => setState(
                () => _companyCtrl.text = v ?? ''),
          )
        else
          TextField(
            controller: _companyCtrl,
            decoration: const InputDecoration(
              labelText: 'Client / Entreprise',
              border: OutlineInputBorder(),
            ),
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

        // Clients de la journée
        TextField(
          controller: _clientsCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Clients de la journée *',
            border: OutlineInputBorder(),
          ),
        ),
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
      appBar: AppBar(title: const Text('FleetPilot — Chauffeur')),
      body: drivers.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Aucun chauffeur enregistré.\nDemande à ton manager d\'ajouter ton profil.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
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
                    'Sélectionne ton nom et saisis ton code PIN.',
                    style: TextStyle(color: Colors.grey),
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
                              if (d.hasPinSet)
                                const Icon(Icons.lock_outline,
                                    size: 16, color: Colors.green)
                              else
                                const Icon(Icons.lock_open_outlined,
                                    size: 16, color: Colors.orange),
                              const SizedBox(width: 8),
                              const Icon(Icons.arrow_forward_ios, size: 16),
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
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

// ── Dialog PIN chauffeur ──────────────────────────────────────────────────────

enum _DriverPinMode { create, verify, change }

class _DriverPinDialog extends StatefulWidget {
  const _DriverPinDialog({required this.driver, required this.mode});
  final Driver driver;
  final _DriverPinMode mode;

  @override
  State<_DriverPinDialog> createState() => _DriverPinDialogState();
}

class _DriverPinDialogState extends State<_DriverPinDialog> {
  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  String? _error;

  // Pour le mode change : étape 0 = ancien PIN, étape 1 = nouveau, étape 2 = confirmer
  int _changeStep = 0;
  String _oldPin = '';
  String _newPin = '';

  void _onKey(String digit) {
    setState(() {
      _error = null;

      if (widget.mode == _DriverPinMode.change) {
        _onKeyChange(digit);
        return;
      }

      if (_confirming) {
        if (_confirmPin.length < 4) _confirmPin += digit;
        if (_confirmPin.length == 4) _validate();
      } else {
        if (_pin.length < 4) _pin += digit;
        if (widget.mode == _DriverPinMode.verify && _pin.length == 4) {
          _validate();
        }
        if (widget.mode == _DriverPinMode.create && _pin.length == 4) {
          _confirming = true;
        }
      }
    });
  }

  void _onKeyChange(String digit) {
    if (_changeStep == 0) {
      if (_oldPin.length < 4) _oldPin += digit;
      if (_oldPin.length == 4) {
        if (widget.driver.checkPin(_oldPin)) {
          _changeStep = 1;
        } else {
          _oldPin = '';
          _error = 'Code actuel incorrect';
        }
      }
    } else if (_changeStep == 1) {
      if (_newPin.length < 4) _newPin += digit;
      if (_newPin.length == 4) {
        _changeStep = 2;
      }
    } else {
      if (_confirmPin.length < 4) _confirmPin += digit;
      if (_confirmPin.length == 4) {
        if (_newPin == _confirmPin) {
          final container = ProviderScope.containerOf(context);
          final appState = container.read(appStateProvider);
          final updated = widget.driver.withPin(_newPin);
          appState.updateDriver(widget.driver.name, updated);
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PIN modifié avec succès')),
          );
        } else {
          _confirmPin = '';
          _changeStep = 1;
          _newPin = '';
          _error = 'Les codes ne correspondent pas, recommencez';
        }
      }
    }
  }

  void _onDelete() {
    setState(() {
      _error = null;

      if (widget.mode == _DriverPinMode.change) {
        if (_changeStep == 0) {
          if (_oldPin.isNotEmpty) _oldPin = _oldPin.substring(0, _oldPin.length - 1);
        } else if (_changeStep == 1) {
          if (_newPin.isNotEmpty) _newPin = _newPin.substring(0, _newPin.length - 1);
        } else {
          if (_confirmPin.isNotEmpty) _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
        return;
      }

      if (_confirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  void _validate() {
    if (widget.mode == _DriverPinMode.verify) {
      if (widget.driver.checkPin(_pin)) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _pin = '';
          _error = 'Code incorrect, réessayez';
        });
      }
    } else {
      // Création
      if (_pin == _confirmPin) {
        // Save the PIN hash on the driver via AppState
        final container = ProviderScope.containerOf(context);
        final appState = container.read(appStateProvider);
        final updated = widget.driver.withPin(_pin);
        appState.updateDriver(widget.driver.name, updated);
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _confirmPin = '';
          _confirming = false;
          _pin = '';
          _error = 'Les codes ne correspondent pas, recommencez';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String currentPin;
    if (widget.mode == _DriverPinMode.change) {
      currentPin = _changeStep == 0 ? _oldPin : (_changeStep == 1 ? _newPin : _confirmPin);
    } else {
      currentPin = _confirming ? _confirmPin : _pin;
    }

    String title;
    String subtitle;
    if (widget.mode == _DriverPinMode.change) {
      if (_changeStep == 0) {
        title = 'Modifier le PIN';
        subtitle = 'Entrez votre code actuel';
      } else if (_changeStep == 1) {
        title = 'Nouveau code PIN';
        subtitle = 'Choisissez 4 chiffres';
      } else {
        title = 'Confirmer le nouveau code';
        subtitle = 'Saisissez à nouveau le code';
      }
    } else if (widget.mode == _DriverPinMode.verify) {
      title = widget.driver.name;
      subtitle = 'Entrez votre code PIN';
    } else if (_confirming) {
      title = 'Confirmer le code';
      subtitle = 'Saisissez à nouveau le code';
    } else {
      title = 'Créer votre code PIN';
      subtitle = '${widget.driver.name} — choisissez 4 chiffres';
    }

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: Colors.green, size: 28),
            ),
            const SizedBox(height: 16),

            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center),

            const SizedBox(height: 28),

            // Indicateurs chiffres
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Colors.green : Colors.transparent,
                    border: Border.all(
                      color: filled ? Colors.green : Colors.grey,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 28),

            // Pavé numérique
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '⌫'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) {
                  if (k.isEmpty) return const SizedBox(width: 68, height: 52);
                  return GestureDetector(
                    onTap: () => k == '⌫' ? _onDelete() : _onKey(k),
                    child: Container(
                      width: 68,
                      height: 52,
                      margin: const EdgeInsets.all(5),
                      decoration: k == '⌫'
                          ? null
                          : BoxDecoration(
                              color: Theme.of(context).colorScheme.surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Theme.of(context).dividerColor),
                            ),
                      alignment: Alignment.center,
                      child: k == '⌫'
                          ? const Icon(Icons.backspace_outlined,
                              color: Colors.grey, size: 20)
                          : Text(k,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 16),

            // Annuler
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler',
                  style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}
