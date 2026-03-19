import 'dart:async';

import 'package:flutter/material.dart';

import '../services/driver_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'models/driver_day_entry.dart';
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

  // ── Formulaire tournée ───────────────────────────────────────────────────────
  String? _selectedTruck;
  final _tourNumberCtrl = TextEditingController();
  final _companyCtrl = TextEditingController();
  final _kmCtrl = TextEditingController();
  final _clientsCtrl = TextEditingController();
  final _weightCtrl = TextEditingController();
  final _handlingCtrl = TextEditingController();
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
    if (_tourStart != null) _startTimer();
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

  // ── Actions ──────────────────────────────────────────────────────────────────

  Future<void> _selectProfile(String name) async {
    await DriverSession.setDriverName(name);
    setState(() => _driverName = name);
  }

  Future<void> _demarrer() async {
    await DriverSession.startTour();
    setState(() => _tourStart = DriverSession.tourStartTime);
    _startTimer();
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

    await DriverSession.endTour();
    _timer?.cancel();
    _tourNumberCtrl.clear();
    _companyCtrl.clear();
    _kmCtrl.clear();
    _clientsCtrl.clear();
    _weightCtrl.clear();
    _handlingCtrl.clear();
    setState(() {
      _tourStart = null;
      _hasHandling = false;
      _extraTour = false;
    });
  }

  Future<void> _terminer() async {
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

    setState(() {
      _tourStart = null;
      _hasHandling = false;
      _extraTour = false;
    });

    _snack('Tournée ${tour.tourNumber} enregistrée — ${_fmtTime(start)} → ${_fmtTime(now)}');
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

    return Scaffold(
      appBar: AppBar(
        title: Text('Bonjour $_driverName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Changer de chauffeur',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Changer de chauffeur ?'),
                  content: const Text(
                      'Tu quitteras ton profil actuel.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Changer')),
                  ],
                ),
              );
              if (confirm == true) {
                await DriverSession.clearDriverName();
                setState(() => _driverName = null);
              }
            },
          ),
        ],
      ),
      body: _tourStart == null ? _buildIdle() : _buildActiveTour(),
    );
  }

  // ── Vue : pas de tournée en cours ────────────────────────────────────────

  Widget _buildIdle() {
    final now = DateTime.now();
    final day = now.day.toString().padLeft(2, '0');
    final month = _monthLabel(now.month);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Date
        Text(
          '$day $month ${now.year}',
          style: const TextStyle(fontSize: 16, color: Colors.grey),
        ),
        const SizedBox(height: 24),

        // Bouton démarrer
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _demarrer,
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

        const SizedBox(height: 20),

        // Camion
        DropdownButtonFormField<String>(
          value: _selectedTruck,
          decoration: const InputDecoration(
            labelText: 'Camion *',
            border: OutlineInputBorder(),
          ),
          items: trucks
              .map((t) => DropdownMenuItem(
                    value: t.plate,
                    child: Text('${t.plate} • ${t.model}'),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedTruck = v),
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
          decoration: const InputDecoration(
            labelText: 'Kilomètres parcourus *',
            border: OutlineInputBorder(),
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
            controller: _handlingCtrl,
            decoration: const InputDecoration(
              labelText: 'Client manutention',
              border: OutlineInputBorder(),
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
                    'Sélectionne ton nom — ce choix sera mémorisé.',
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
                          trailing:
                              const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => _selectProfile(d.name),
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
