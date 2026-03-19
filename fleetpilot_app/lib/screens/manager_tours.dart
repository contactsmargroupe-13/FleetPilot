import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'add_truck.dart';
import 'models/tour.dart';

class ManagerTours extends ConsumerStatefulWidget {
  const ManagerTours({super.key});

  @override
  ConsumerState<ManagerTours> createState() => _ManagerToursState();
}

class _ManagerToursState extends ConsumerState<ManagerTours> {
  String _searchText = '';
  String _selectedDriver = 'Tous';
  String _selectedTruck = 'Tous';
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const List<String> _statusOptions = [
    'planifiée',
    'en cours',
    'terminée',
    'annulée',
  ];

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final allTours = [...ref.read(appStateProvider).tours]
      ..sort((a, b) => b.date.compareTo(a.date));

    final driverNames = allTours.map((t) => t.driverName).toSet().toList()
      ..sort();
    final truckPlates = allTours.map((t) => t.truckPlate).toSet().toList()
      ..sort();
    final drivers = ['Tous', ...driverNames];
    final trucks = ['Tous', ...truckPlates];

    final filteredTours = allTours.where((tour) {
      final sameMonth = tour.date.year == _selectedMonth.year &&
          tour.date.month == _selectedMonth.month;
      final matchesDriver =
          _selectedDriver == 'Tous' || tour.driverName == _selectedDriver;
      final matchesTruck =
          _selectedTruck == 'Tous' || tour.truckPlate == _selectedTruck;
      final q = _searchText.trim().toLowerCase();
      final matchesSearch = q.isEmpty ||
          tour.tourNumber.toLowerCase().contains(q) ||
          tour.driverName.toLowerCase().contains(q) ||
          tour.truckPlate.toLowerCase().contains(q) ||
          (tour.companyName ?? '').toLowerCase().contains(q) ||
          (tour.sector ?? '').toLowerCase().contains(q);
      return sameMonth && matchesDriver && matchesTruck && matchesSearch;
    }).toList();

    final totalKm = filteredTours.fold(0.0, (s, t) => s + t.kmTotal);
    final totalClients = filteredTours.fold(0, (s, t) => s + t.clientsCount);
    final totalWeight = filteredTours.fold(
        0.0, (s, t) => s + (t.weightKg ?? 0));
    final totalExtraKm = filteredTours.fold(0.0, (s, t) => s + t.extraKm);
    final handlingCount = filteredTours.where((t) => t.hasHandling).length;
    final extraTourCount = filteredTours.where((t) => t.extraTour).length;

    final totalHandlingBilling =
        filteredTours.fold(0.0, (s, t) => s + _handlingBilling(t));
    final totalExtraKmBilling =
        filteredTours.fold(0.0, (s, t) => s + _extraKmBilling(t));
    final totalExtraTourBilling =
        filteredTours.fold(0.0, (s, t) => s + _extraTourBilling(t));
    final totalBilling =
        totalHandlingBilling + totalExtraKmBilling + totalExtraTourBilling;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openTourDialog(null),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1300),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filtres
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _pickMonth,
                          icon: const Icon(Icons.calendar_month_outlined),
                          label: Text(_monthLabel(_selectedMonth)),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: drivers.contains(_selectedDriver)
                                ? _selectedDriver
                                : 'Tous',
                            decoration: const InputDecoration(
                              labelText: 'Chauffeur',
                              border: OutlineInputBorder(),
                            ),
                            items: drivers
                                .map((d) => DropdownMenuItem<String>(
                                      value: d,
                                      child: Text(d),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedDriver = v ?? 'Tous'),
                          ),
                        ),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: trucks.contains(_selectedTruck)
                                ? _selectedTruck
                                : 'Tous',
                            decoration: const InputDecoration(
                              labelText: 'Camion',
                              border: OutlineInputBorder(),
                            ),
                            items: trucks
                                .map((t) => DropdownMenuItem<String>(
                                      value: t,
                                      child: Text(t),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedTruck = v ?? 'Tous'),
                          ),
                        ),
                        SizedBox(
                          width: 280,
                          child: TextField(
                            decoration: InputDecoration(
                              labelText: 'Recherche',
                              hintText: 'Numéro, chauffeur, camion…',
                              prefixIcon: const Icon(Icons.search),
                              suffixIcon: _searchText.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () =>
                                          setState(() => _searchText = ''),
                                      icon: const Icon(Icons.clear),
                                    ),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (v) => setState(() => _searchText = v),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _resetFilters,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réinitialiser'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Stats transport
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _StatCard(
                        title: 'Tournées',
                        value: '${filteredTours.length}',
                        icon: Icons.route),
                    _StatCard(
                        title: 'Kilomètres',
                        value: '${totalKm.toStringAsFixed(0)} km',
                        icon: Icons.speed),
                    _StatCard(
                        title: 'Clients',
                        value: '$totalClients',
                        icon: Icons.people_alt_outlined),
                    _StatCard(
                        title: 'Poids total',
                        value: '${totalWeight.toStringAsFixed(0)} kg',
                        icon: Icons.scale_outlined),
                    _StatCard(
                        title: 'Manutentions',
                        value: '$handlingCount',
                        icon: Icons.handyman_outlined),
                    _StatCard(
                        title: 'Extra tours',
                        value: '$extraTourCount',
                        icon: Icons.add_road_outlined),
                    _StatCard(
                        title: 'Extra km',
                        value: '${totalExtraKm.toStringAsFixed(0)} km',
                        icon: Icons.alt_route),
                  ],
                ),
                const SizedBox(height: 16),

                // Facturation extras
                const Text(
                  'Facturation extras',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _BillingCard(
                        title: 'Manutention',
                        value: '${totalHandlingBilling.toStringAsFixed(2)} €',
                        icon: Icons.handyman_outlined),
                    _BillingCard(
                        title: 'Extra km',
                        value: '${totalExtraKmBilling.toStringAsFixed(2)} €',
                        icon: Icons.alt_route),
                    _BillingCard(
                        title: 'Extra tour',
                        value: '${totalExtraTourBilling.toStringAsFixed(2)} €',
                        icon: Icons.add_road_outlined),
                    _BillingCard(
                        title: 'Total facturable',
                        value: '${totalBilling.toStringAsFixed(2)} €',
                        icon: Icons.euro_outlined,
                        emphasized: true),
                  ],
                ),
                const SizedBox(height: 20),

                // Détail par camion
                const Text(
                  'Détail par camion',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                if (filteredTours.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text('Aucune tournée trouvée pour cette période.'),
                      ),
                    ),
                  )
                else
                  ..._buildTruckSections(filteredTours),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Sections par camion ────────────────────────────────────────────────────

  List<Widget> _buildTruckSections(List<Tour> tours) {
    final Map<String, List<Tour>> byTruck = {};
    for (final t in tours) {
      byTruck.putIfAbsent(t.truckPlate, () => []).add(t);
    }
    final sortedTrucks = byTruck.keys.toList()..sort();

    return sortedTrucks.map((plate) {
      final truckTours = byTruck[plate]!
        ..sort((a, b) => b.date.compareTo(a.date));

      return _TruckSection(
        key: ValueKey(plate),
        plate: plate,
        tours: truckTours,
        onEdit: _openTourDialog,
        onDelete: _confirmDeleteTour,
        onShowDetails: _showTourDetails,
        handlingBilling: _handlingBilling,
        extraKmBilling: _extraKmBilling,
        extraTourBilling: _extraTourBilling,
        onRefresh: () => setState(() {}),
      );
    }).toList();
  }

  Widget _buildPricingBox({
    required bool hasPricing,
    required double handlingBilling,
    required double extraKmBilling,
    required double extraTourBilling,
    required double totalBilling,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasPricing
            ? Colors.green.withValues(alpha: 0.06)
            : Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasPricing
              ? Colors.green.shade200
              : Colors.orange.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasPricing
                    ? Icons.receipt_long_outlined
                    : Icons.warning_amber,
                size: 18,
                color: hasPricing ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                hasPricing
                    ? 'Facturation extras'
                    : 'Facturation extras indisponible',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!hasPricing)
            const Text(
                'Aucun tarif client trouvé. Ajoute le contrat dans "Tarifs".'),
          if (hasPricing) ...[
            _billingLine('Manutention',
                '${handlingBilling.toStringAsFixed(2)} €'),
            const SizedBox(height: 6),
            _billingLine(
                'Extra km', '${extraKmBilling.toStringAsFixed(2)} €'),
            const SizedBox(height: 6),
            _billingLine(
                'Tour supplémentaire', '${extraTourBilling.toStringAsFixed(2)} €'),
            const SizedBox(height: 10),
            const Divider(),
            const SizedBox(height: 6),
            _billingLine(
                'Total facturable', '${totalBilling.toStringAsFixed(2)} €',
                bold: true),
          ],
        ],
      ),
    );
  }

  // ── Dialog ajout / modification (unifié) ──────────────────────────────────

  void _openTourDialog(Tour? existing) {
    final isEdit = existing != null;

    DateTime selectedDate = existing?.date ?? DateTime.now();
    String? selectedDriver = existing?.driverName ??
        (ref.read(appStateProvider).drivers.isNotEmpty ? ref.read(appStateProvider).drivers.first.name : null);
    String? selectedTruck = existing?.truckPlate ??
        (ref.read(appStateProvider).trucks.isNotEmpty ? ref.read(appStateProvider).trucks.first.plate : null);
    String selectedStatus = existing?.status ?? 'planifiée';

    final tourNumberCtrl =
        TextEditingController(text: existing?.tourNumber ?? '');
    final companyCtrl =
        TextEditingController(text: existing?.companyName ?? '');
    final sectorCtrl = TextEditingController(text: existing?.sector ?? '');
    final startCtrl = TextEditingController(text: existing?.startTime ?? '');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '');
    final breakCtrl = TextEditingController(text: existing?.breakTime ?? '');
    final weightCtrl = TextEditingController(
        text: existing?.weightKg?.toString() ?? '');
    final kmCtrl =
        TextEditingController(text: existing?.kmTotal.toString() ?? '');
    final clientsCtrl = TextEditingController(
        text: existing?.clientsCount.toString() ?? '');
    final handlingClientCtrl =
        TextEditingController(text: existing?.handlingClientName ?? '');
    final extraKmCtrl =
        TextEditingController(text: existing?.extraKm.toString() ?? '');

    bool hasHandling = existing?.hasHandling ?? false;
    bool extraTour = existing?.extraTour ?? false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialog) {
            return AlertDialog(
              title: Text(isEdit
                  ? 'Modifier tournée ${existing.tourNumber}'
                  : 'Ajouter une tournée'),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: 520,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Date
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: selectedDate,
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialog(() => selectedDate = picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text('Date : ${_fmt(selectedDate)}'),
                      ),
                      const SizedBox(height: 12),

                      // Numéro
                      TextField(
                        controller: tourNumberCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Numéro de tournée',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Statut
                      DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'Statut',
                          border: OutlineInputBorder(),
                        ),
                        items: _statusOptions
                            .map((s) => DropdownMenuItem<String>(
                                  value: s,
                                  child: Text(s),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialog(() => selectedStatus = v ?? selectedStatus),
                      ),
                      const SizedBox(height: 12),

                      // Chauffeur
                      DropdownButtonFormField<String>(
                        value: selectedDriver,
                        decoration: const InputDecoration(
                          labelText: 'Chauffeur',
                          border: OutlineInputBorder(),
                        ),
                        items: ref.read(appStateProvider).drivers
                            .map((d) => DropdownMenuItem<String>(
                                  value: d.name,
                                  child: Text(d.name),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialog(() => selectedDriver = v),
                      ),
                      const SizedBox(height: 12),

                      // Camion
                      DropdownButtonFormField<String>(
                        value: selectedTruck,
                        decoration: const InputDecoration(
                          labelText: 'Camion',
                          border: OutlineInputBorder(),
                        ),
                        items: ref.read(appStateProvider).trucks
                            .map((t) => DropdownMenuItem<String>(
                                  value: t.plate,
                                  child: Text('${t.plate} • ${t.model}'),
                                ))
                            .toList(),
                        onChanged: (v) =>
                            setDialog(() => selectedTruck = v),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: companyCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Entreprise / client',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: sectorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Secteur',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: startCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Heure début',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: endCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Heure fin',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: breakCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Pause',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: kmCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Kilomètres *',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: clientsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Clients',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      TextField(
                        controller: weightCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Poids (kg)',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      SwitchListTile(
                        value: hasHandling,
                        onChanged: (v) => setDialog(() => hasHandling = v),
                        title: const Text('Manutention'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      if (hasHandling) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: handlingClientCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Client manutention',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),

                      SwitchListTile(
                        value: extraTour,
                        onChanged: (v) => setDialog(() => extraTour = v),
                        title: const Text('Tour supplémentaire'),
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 8),

                      TextField(
                        controller: extraKmCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Extra km',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () {
                    final tourNumber = tourNumberCtrl.text.trim();
                    final km = _parseDouble(kmCtrl.text);
                    final clients =
                        int.tryParse(clientsCtrl.text.trim()) ?? 0;
                    final weight = weightCtrl.text.trim().isEmpty
                        ? null
                        : _parseDouble(weightCtrl.text);
                    final extraKm = _parseDouble(extraKmCtrl.text);

                    if (tourNumber.isEmpty) {
                      _msg('Le numéro de tournée est obligatoire');
                      return;
                    }
                    if (selectedDriver == null || selectedTruck == null) {
                      _msg('Choisis un chauffeur et un camion');
                      return;
                    }
                    if (km <= 0) {
                      _msg('Les kilomètres doivent être supérieurs à 0');
                      return;
                    }
                    if (hasHandling &&
                        handlingClientCtrl.text.trim().isEmpty) {
                      _msg('Le client manutention est obligatoire');
                      return;
                    }

                    final tour = Tour(
                      id: existing?.id ??
                          '${DateTime.now().microsecondsSinceEpoch}_manager',
                      tourNumber: tourNumber,
                      date: selectedDate,
                      driverName: selectedDriver!,
                      truckPlate: selectedTruck!,
                      companyName: companyCtrl.text.trim().isEmpty
                          ? null
                          : companyCtrl.text.trim(),
                      sector: sectorCtrl.text.trim().isEmpty
                          ? null
                          : sectorCtrl.text.trim(),
                      startTime: startCtrl.text.trim().isEmpty
                          ? null
                          : startCtrl.text.trim(),
                      endTime: endCtrl.text.trim().isEmpty
                          ? null
                          : endCtrl.text.trim(),
                      breakTime: breakCtrl.text.trim().isEmpty
                          ? null
                          : breakCtrl.text.trim(),
                      kmTotal: km,
                      clientsCount: clients,
                      weightKg: weight,
                      hasHandling: hasHandling,
                      handlingClientName:
                          hasHandling ? handlingClientCtrl.text.trim() : null,
                      handlingDate:
                          hasHandling ? (existing?.handlingDate ?? selectedDate) : null,
                      extraKm: extraKm,
                      extraTour: extraTour,
                      status: selectedStatus,
                    );

                    setState(() {
                      if (isEdit) {
                        ref.read(appStateProvider).updateTour(existing.id, tour);
                        _msg('Tournée modifiée');
                      } else {
                        ref.read(appStateProvider).addTour(tour);
                        _msg('Tournée ajoutée');
                      }
                    });

                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Enregistrer'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Suppression ───────────────────────────────────────────────────────────

  void _confirmDeleteTour(Tour tour) {
    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text('Supprimer la tournée ?'),
          content: Text('Supprimer la tournée ${tour.tourNumber} ?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                setState(() => ref.read(appStateProvider).deleteTour(tour.id));
                Navigator.pop(context);
                _msg('Tournée supprimée');
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );
  }

  // ── Détail tournée ────────────────────────────────────────────────────────

  void _showTourDetails(Tour tour) {
    final pricing = ref.read(appStateProvider).getClientPricing(tour.companyName);
    final handlingBilling = _handlingBilling(tour);
    final extraKmBilling = _extraKmBilling(tour);
    final extraTourBilling = _extraTourBilling(tour);
    final totalBilling =
        handlingBilling + extraKmBilling + extraTourBilling;

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text('Détail tournée ${tour.tourNumber}'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 480,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _dl('Date', _fmt(tour.date)),
                  _dl('Statut', tour.status),
                  _dl('Chauffeur', tour.driverName),
                  _dl('Camion', tour.truckPlate),
                  _dl('Entreprise', tour.companyName ?? '—'),
                  _dl('Secteur', tour.sector ?? '—'),
                  _dl('Horaire',
                      '${tour.startTime ?? '—'} → ${tour.endTime ?? '—'}'),
                  _dl('Pause', tour.breakTime ?? '—'),
                  _dl('Kilomètres',
                      '${tour.kmTotal.toStringAsFixed(0)} km'),
                  _dl('Clients', '${tour.clientsCount}'),
                  _dl(
                      'Poids',
                      tour.weightKg != null
                          ? '${tour.weightKg!.toStringAsFixed(0)} kg'
                          : '—'),
                  _dl('Manutention', tour.hasHandling ? 'Oui' : 'Non'),
                  if (tour.hasHandling)
                    _dl('Client manutention',
                        tour.handlingClientName ?? '—'),
                  _dl('Tour supplémentaire', tour.extraTour ? 'Oui' : 'Non'),
                  _dl('Extra km',
                      '${tour.extraKm.toStringAsFixed(0)} km'),
                  const SizedBox(height: 12),
                  _buildPricingBox(
                    hasPricing: pricing != null,
                    handlingBilling: handlingBilling,
                    extraKmBilling: extraKmBilling,
                    extraTourBilling: extraTourBilling,
                    totalBilling: totalBilling,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _openTourDialog(tour);
              },
              child: const Text('Modifier'),
            ),
          ],
        );
      },
    );
  }

  // ── Calculs facturation ───────────────────────────────────────────────────

  double _handlingBilling(Tour tour) {
    final pricing = ref.read(appStateProvider).getClientPricing(tour.companyName);
    if (pricing == null || !tour.hasHandling || !pricing.handlingEnabled) {
      return 0.0;
    }
    return pricing.handlingPrice ?? 0.0;
  }

  double _extraKmBilling(Tour tour) {
    final pricing = ref.read(appStateProvider).getClientPricing(tour.companyName);
    if (pricing == null || !pricing.extraKmEnabled) return 0.0;
    return tour.extraKm * (pricing.extraKmPrice ?? 0.0);
  }

  double _extraTourBilling(Tour tour) {
    final pricing = ref.read(appStateProvider).getClientPricing(tour.companyName);
    if (pricing == null || !tour.extraTour || !pricing.extraTourEnabled) {
      return 0.0;
    }
    return pricing.extraTourPrice ?? 0.0;
  }

  // ── Filtres ───────────────────────────────────────────────────────────────

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    int year = _selectedMonth.year;
    int month = _selectedMonth.month;

    final result = await showDialog<DateTime>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Choisir le mois'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              value: year,
              decoration: const InputDecoration(
                  labelText: 'Année', border: OutlineInputBorder()),
              items: List.generate(7, (i) => now.year - 3 + i)
                  .map((y) =>
                      DropdownMenuItem(value: y, child: Text('$y')))
                  .toList(),
              onChanged: (v) => year = v ?? year,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: month,
              decoration: const InputDecoration(
                  labelText: 'Mois', border: OutlineInputBorder()),
              items: List.generate(12, (i) => i + 1)
                  .map((m) => DropdownMenuItem(
                      value: m,
                      child: Text(m.toString().padLeft(2, '0'))))
                  .toList(),
              onChanged: (v) => month = v ?? month,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, DateTime(year, month, 1)),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (result != null) setState(() => _selectedMonth = result);
  }

  void _resetFilters() {
    setState(() {
      _searchText = '';
      _selectedDriver = 'Tous';
      _selectedTruck = 'Tous';
      _selectedMonth =
          DateTime(DateTime.now().year, DateTime.now().month);
    });
  }

  // ── Widgets helpers ───────────────────────────────────────────────────────

  Widget _chip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    const colors = {
      'planifiée': Color(0xFF1F3C88),
      'en cours': Color(0xFFF57C00),
      'terminée': Color(0xFF2E7D32),
      'annulée': Color(0xFFB71C1C),
    };
    final color = colors[status] ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status,
        style: TextStyle(
            color: color, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }

  Widget _statusChip(
      {required String label,
      required IconData icon,
      required bool active}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: active
            ? Colors.green.withValues(alpha: 0.12)
            : Colors.grey.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: active ? Colors.green.shade300 : Colors.grey.shade400),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _infoBox(String title, String value) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _billingLine(String label, String value, {bool bold = false}) {
    return Row(
      children: [
        Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.w600))),
        Text(value,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
      ],
    );
  }

  Widget _dl(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text('$label :',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // ── Utilitaires ───────────────────────────────────────────────────────────

  String _fmt(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  String _monthLabel(DateTime month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];
    return '${months[month.month - 1]} ${month.year}';
  }

  double _parseDouble(String value) =>
      double.tryParse(value.replaceAll(',', '.').trim()) ?? 0.0;

  void _msg(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

// ── Section camion (stateful pour les onglets) ────────────────────────────────

class _TruckSection extends ConsumerStatefulWidget {
  const _TruckSection({
    super.key,
    required this.plate,
    required this.tours,
    required this.onEdit,
    required this.onDelete,
    required this.onShowDetails,
    required this.handlingBilling,
    required this.extraKmBilling,
    required this.extraTourBilling,
    required this.onRefresh,
  });

  final String plate;
  final List<Tour> tours;
  final void Function(Tour) onEdit;
  final void Function(Tour) onDelete;
  final void Function(Tour) onShowDetails;
  final double Function(Tour) handlingBilling;
  final double Function(Tour) extraKmBilling;
  final double Function(Tour) extraTourBilling;
  final VoidCallback onRefresh;

  @override
  ConsumerState<_TruckSection> createState() => _TruckSectionState();
}

class _TruckSectionState extends ConsumerState<_TruckSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String? _pendingDriver;

  static const _statusColors = {
    'planifiée': Color(0xFF1565C0),
    'en cours': Color(0xFFE65100),
    'terminée': Color(0xFF2E7D32),
    'annulée': Color(0xFFB71C1C),
  };

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Truck? get _truck {
    try {
      return ref.read(appStateProvider).trucks.firstWhere((t) => t.plate == widget.plate);
    } catch (_) {
      return null;
    }
  }

  void _saveAffectation() {
    final truck = _truck;
    if (truck == null) return;
    ref.read(appStateProvider).updateTruck(
      truck.plate,
      truck.copyWith(assignedDriverName: _pendingDriver),
    );
    setState(() {});
    widget.onRefresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Affectation enregistrée')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final truck = _truck;
    final tours = widget.tours;

    final kmTotal = tours.fold(0.0, (s, t) => s + t.kmTotal);
    final poidsTotal =
        tours.fold(0.0, (s, t) => s + (t.weightKg ?? 0));
    final tourNumbers =
        tours.map((t) => t.tourNumber).toSet().toList()..sort();
    final companies =
        tours.map((t) => t.companyName).whereType<String>().toSet();
    final assignedDriver =
        truck?.assignedDriverName ?? '—';

    _pendingDriver ??= truck?.assignedDriverName;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: false,
        tilePadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.local_shipping_outlined,
                size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne 1 : modèle + plaque
                  Row(
                    children: [
                      Text(
                        truck != null
                            ? '${truck.brand} ${truck.model}'.trim()
                            : widget.plate,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.blueGrey
                              .withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.plate,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Ligne 2 : chauffeur + tournée(s) + entreprise
                  Wrap(
                    spacing: 12,
                    children: [
                      _infoTag(Icons.person_outline, assignedDriver),
                      if (tourNumbers.isNotEmpty)
                        _infoTag(Icons.route_outlined,
                            'T° ${tourNumbers.join(', ')}'),
                      if (companies.isNotEmpty)
                        _infoTag(Icons.business_outlined,
                            companies.join(', ')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Ligne 3 : km + poids
                  Wrap(
                    spacing: 16,
                    children: [
                      _infoTag(Icons.speed_outlined,
                          '${kmTotal.toStringAsFixed(0)} km'),
                      if (poidsTotal > 0)
                        _infoTag(Icons.scale_outlined,
                            '${poidsTotal.toStringAsFixed(0)} kg'),
                      _infoTag(Icons.event_note_outlined,
                          '${tours.length} tournées'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        children: [
          // TabBar
          TabBar(
            controller: _tabCtrl,
            tabs: const [
              Tab(text: 'Historique'),
              Tab(text: 'Affectation'),
            ],
          ),
          SizedBox(
            height: _tabHeight(),
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildHistorique(),
                _buildAffectation(truck),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _tabHeight() {
    final rows = widget.tours.length;
    // En-tête colonnes (48) + chaque ligne (~52) + padding bas (16)
    return 48.0 + (rows * 52.0).clamp(52.0, 400.0) + 16.0;
  }

  Widget _buildHistorique() {
    return Column(
      children: [
        // En-tête colonnes
        Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: const [
              SizedBox(
                  width: 56,
                  child: Text('Date',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey))),
              SizedBox(
                  width: 36,
                  child: Text('N°',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey))),
              Expanded(
                  child: Text('Chauffeur',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey))),
              SizedBox(
                  width: 70,
                  child: Text('Km',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey))),
              SizedBox(
                  width: 48,
                  child: Text('Poids',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey))),
              SizedBox(width: 110),
            ],
          ),
        ),
        const Divider(height: 1),
        ...widget.tours.map((t) => _buildDayRow(t)),
      ],
    );
  }

  Widget _buildDayRow(Tour tour) {
    final color = _statusColors[tour.status] ?? Colors.grey;
    final extras = [
      if (tour.hasHandling) 'Manut.',
      if (tour.extraTour) 'Extra T',
      if (tour.extraKm > 0) '+${tour.extraKm.toStringAsFixed(0)}km',
    ].join(' • ');

    return InkWell(
      onTap: () => widget.onShowDetails(tour),
      child: Container(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0x10000000))),
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 56,
                  child: Text(
                    '${tour.date.day.toString().padLeft(2, '0')}/${tour.date.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(tour.tourNumber,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600)),
                ),
                Expanded(
                  child: Text(tour.driverName,
                      style: const TextStyle(fontSize: 13),
                      overflow: TextOverflow.ellipsis),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                      '${tour.kmTotal.toStringAsFixed(0)} km',
                      style: const TextStyle(fontSize: 13)),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    tour.weightKg != null
                        ? '${tour.weightKg!.toStringAsFixed(0)} kg'
                        : '—',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tour.status,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 15),
                      onPressed: () => widget.onEdit(tour),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 15, color: Colors.red),
                      onPressed: () => widget.onDelete(tour),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
            if (extras.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2, left: 92),
                child: Text(extras,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAffectation(Truck? truck) {
    final drivers = ref.read(appStateProvider).drivers.map((d) => d.name).toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chauffeur assigné à ce camion',
              style:
                  TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (drivers.isEmpty)
            const Text('Aucun chauffeur enregistré.',
                style: TextStyle(color: Colors.grey))
          else
            DropdownButtonFormField<String>(
              value: drivers.contains(_pendingDriver)
                  ? _pendingDriver
                  : null,
              decoration: const InputDecoration(
                labelText: 'Chauffeur',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              items: [
                const DropdownMenuItem<String>(
                    value: null, child: Text('— Aucun —')),
                ...drivers.map((d) =>
                    DropdownMenuItem<String>(value: d, child: Text(d))),
              ],
              onChanged: (v) => setState(() => _pendingDriver = v),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saveAffectation,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Enregistrer l\'affectation'),
          ),
          if (truck?.assignedDriverName != null) ...[
            const SizedBox(height: 12),
            Text(
              'Actuel : ${truck!.assignedDriverName}',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoTag(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(label,
            style:
                TextStyle(fontSize: 12, color: Colors.grey.shade700)),
      ],
    );
  }
}

// ── Widgets ───────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard(
      {required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      child: Card(
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BillingCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool emphasized;

  const _BillingCard({
    required this.title,
    required this.value,
    required this.icon,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        elevation: emphasized ? 2 : 1,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: emphasized
                ? Border.all(color: Colors.green.shade300, width: 1.2)
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: emphasized
                        ? Colors.green.withValues(alpha: 0.10)
                        : Colors.blueGrey.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon,
                      color: emphasized ? Colors.green : null),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(value,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: emphasized
                                  ? Colors.green.shade700
                                  : null)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}