import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import 'add_truck.dart';
import 'models/tour.dart';

class ManagerTours extends ConsumerStatefulWidget {
  const ManagerTours({super.key});

  @override
  ConsumerState<ManagerTours> createState() => _ManagerToursState();
}

class _ManagerToursState extends ConsumerState<ManagerTours> {
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  int _viewMode = 0; // 0 = par camion, 1 = par commissionnaire

  static const _months = [
    'Janvier','Février','Mars','Avril','Mai','Juin',
    'Juillet','Août','Septembre','Octobre','Novembre','Décembre',
  ];

  String _monthLabel(DateTime m) => '${_months[m.month - 1]} ${m.year}';
  String _fmtDay(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);

    // Tournées du mois
    final monthTours = state.tours
        .where((t) =>
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Grouper par camion
    final Map<String, List<Tour>> byTruck = {};
    for (final t in monthTours) {
      byTruck.putIfAbsent(t.truckPlate, () => []).add(t);
    }
    final sortedPlates = byTruck.keys.toList()..sort();

    // Grouper par commissionnaire (client)
    final Map<String, List<Tour>> byClient = {};
    for (final t in monthTours) {
      final client = t.companyName ?? 'Non renseigné';
      byClient.putIfAbsent(client, () => []).add(t);
    }
    final sortedClients = byClient.keys.toList()
      ..sort((a, b) {
        if (a == 'Non renseigné') return 1;
        if (b == 'Non renseigné') return -1;
        return a.compareTo(b);
      });

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Tournées',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        // Sélecteur mois
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month - 1);
                  }),
                ),
                Expanded(
                  child: Center(
                    child: Text(_monthLabel(_selectedMonth),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month + 1);
                  }),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── KPIs globaux du mois ─────────────────────────────────────
        if (monthTours.isNotEmpty) ...[
          Builder(builder: (_) {
            final totalKm = monthTours.fold(0.0, (s, t) => s + t.kmTotal);
            final totalClients = monthTours.fold(0, (s, t) => s + t.clientsCount);
            final handlingCount = monthTours.where((t) => t.hasHandling).length;
            final driverCount = monthTours.map((t) => t.driverName).toSet().length;
            final extraTourCount = monthTours.where((t) => t.extraTour).length;

            return Row(
              children: [
                _kpiChip('${monthTours.length}', 'tournées', Icons.route_outlined, Colors.blue),
                const SizedBox(width: 6),
                _kpiChip('${totalKm.toStringAsFixed(0)}', 'km', Icons.speed_outlined, Colors.teal),
                const SizedBox(width: 6),
                _kpiChip('$totalClients', 'clients', Icons.people_outline, Colors.indigo),
                const SizedBox(width: 6),
                _kpiChip('$handlingCount', 'manut.', Icons.pan_tool_outlined, Colors.deepOrange),
                if (extraTourCount > 0) ...[
                  const SizedBox(width: 6),
                  _kpiChip('$extraTourCount', 'supp.', Icons.add_road, Colors.purple),
                ],
              ],
            );
          }),
          const SizedBox(height: 6),
          Builder(builder: (_) {
            final driverCount = monthTours.map((t) => t.driverName).toSet().length;
            final truckCount = byTruck.keys.length;
            final clientCount = byClient.keys.where((c) => c != 'Non renseigné').length;
            return Row(
              children: [
                _kpiChip('$driverCount', 'chauffeurs', Icons.badge_outlined, Colors.brown),
                const SizedBox(width: 6),
                _kpiChip('$truckCount', 'camions', Icons.local_shipping_outlined, Colors.blueGrey),
                const SizedBox(width: 6),
                _kpiChip('$clientCount', 'commiss.', Icons.business_outlined, Colors.cyan),
              ],
            );
          }),
          const SizedBox(height: 12),
        ],

        // Toggle vue
        Material(
          type: MaterialType.transparency,
          child: Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_shipping, size: 16),
                      SizedBox(width: 6),
                      Text('Par camion'),
                    ],
                  ),
                  selected: _viewMode == 0,
                  onSelected: (_) => setState(() => _viewMode = 0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.business, size: 16),
                      SizedBox(width: 6),
                      Text('Par commissionnaire'),
                    ],
                  ),
                  selected: _viewMode == 1,
                  onSelected: (_) => setState(() => _viewMode = 1),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (monthTours.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Aucune tournée en ${_monthLabel(_selectedMonth)}.',
                    style: const TextStyle(color: Colors.grey, fontSize: 15)),
              ),
            ),
          )

        // ── Vue par commissionnaire
        else if (_viewMode == 1)
          ...sortedClients.map((client) {
            final tours = byClient[client]!;
            return _ClientDetailCard(
              clientName: client,
              tours: tours,
              allTrucks: state.trucks,
              fmtDay: _fmtDay,
              onShowDetail: _showDetail,
            );
          })

        // ── Vue par camion
        else
          ...sortedPlates.map((plate) {
            final tours = byTruck[plate]!;
            final truck = state.trucks
                .where((t) => t.plate == plate)
                .firstOrNull;
            return _TruckDetailCard(
              plate: plate,
              truck: truck,
              tours: tours,
              fmtDay: _fmtDay,
              onShowDetail: _showDetail,
            );
          }),

        const SizedBox(height: 80),
      ],
    );
  }

  void _showDetail(Tour t) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Tournée #${t.tourNumber}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _dl('Date', _fmtDay(t.date)),
              _dl('Chauffeur', t.driverName),
              _dl('Camion', t.truckPlate),
              _dl('Client', t.companyName ?? '—'),
              _dl('Horaires', '${t.startTime ?? '—'} → ${t.endTime ?? '—'}'),
              _dl('Km', '${t.kmTotal.toStringAsFixed(0)} km'),
              _dl('Colis / Fiches', '${t.clientsCount}'),
              if (t.pickupCount > 0)
                _dl('Ramasses', '${t.pickupCount}'),
              if (t.weightKg != null)
                _dl('Poids', '${t.weightKg!.toStringAsFixed(0)} kg'),
              _dl('Manutention',
                  t.hasHandling ? 'Oui — ${t.handlingClientName ?? ''}' : 'Non'),
              _dl('Tour supp.', t.extraTour ? 'Oui' : 'Non'),
            ],
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
              _confirmDelete(t);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Tour tour) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer la tournée #${tour.tourNumber} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => ref.read(appStateProvider).deleteTour(tour.id));
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Widget _kpiChip(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 9, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _dl(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

// ── Carte détail par camion ──────────────────────────────────────────────────

class _TruckDetailCard extends StatefulWidget {
  final String plate;
  final Truck? truck;
  final List<Tour> tours;
  final String Function(DateTime) fmtDay;
  final void Function(Tour) onShowDetail;

  const _TruckDetailCard({
    required this.plate,
    required this.truck,
    required this.tours,
    required this.fmtDay,
    required this.onShowDetail,
  });

  @override
  State<_TruckDetailCard> createState() => _TruckDetailCardState();
}

class _TruckDetailCardState extends State<_TruckDetailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tours = widget.tours;
    final totalKm = tours.fold(0.0, (s, t) => s + t.kmTotal);
    final totalClients = tours.fold(0, (s, t) => s + t.clientsCount);
    final handlingCount = tours.where((t) => t.hasHandling).length;
    final extraTourCount = tours.where((t) => t.extraTour).length;
    final drivers = tours.map((t) => t.driverName).toSet();
    final statusColor = widget.truck != null
        ? truckStatusColor(widget.truck!.truckStatus)
        : Colors.grey;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          // En-tête camion (cliquable pour expand)
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ligne 1 : plaque + modèle + statut
                  Row(
                    children: [
                      Icon(Icons.local_shipping, color: statusColor, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.plate,
                                style: const TextStyle(
                                    fontSize: 17, fontWeight: FontWeight.w800)),
                            if (widget.truck != null)
                              Text(
                                '${widget.truck!.brand} ${widget.truck!.model}'
                                    .trim(),
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      if (widget.truck != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            truckStatusLabel(widget.truck!.truckStatus),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats résumé
                  Row(
                    children: [
                      _miniStat(Icons.route_outlined, '${tours.length}',
                          'tournées', Colors.blue),
                      const SizedBox(width: 8),
                      _miniStat(Icons.speed_outlined,
                          totalKm.toStringAsFixed(0), 'km', Colors.teal),
                      const SizedBox(width: 8),
                      _miniStat(Icons.people_outline, '$totalClients',
                          'clients', Colors.indigo),
                      const SizedBox(width: 8),
                      _miniStat(Icons.pan_tool_outlined, '$handlingCount',
                          'manut.', Colors.deepOrange),
                      if (extraTourCount > 0) ...[
                        const SizedBox(width: 8),
                        _miniStat(Icons.add_road, '$extraTourCount',
                            'supp.', Colors.purple),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Chauffeurs
                  Wrap(
                    spacing: 6,
                    children: drivers
                        .map((d) => Chip(
                              label: Text(d, style: const TextStyle(fontSize: 11)),
                              avatar: CircleAvatar(
                                radius: 10,
                                child: Text(d[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 9)),
                              ),
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ))
                        .toList(),
                  ),
                ],
              ),
            ),
          ),

          // Liste des tournées (expanded)
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: tours.map((t) {
                  return InkWell(
                    onTap: () => widget.onShowDetail(t),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          // Date
                          SizedBox(
                            width: 42,
                            child: Text(widget.fmtDay(t.date),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                          // Chauffeur
                          CircleAvatar(
                            radius: 12,
                            child: Text(t.driverName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.driverName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  '#${t.tourNumber}${t.companyName != null ? ' • ${t.companyName}' : ''}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          // Stats
                          Text('${t.kmTotal.toStringAsFixed(0)} km',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Text('${t.clientsCount} cl.',
                              style: const TextStyle(
                                  fontSize: 11, color: DC.textSecondary)),
                          if (t.pickupCount > 0) ...[
                            const SizedBox(width: 4),
                            Text('${t.pickupCount} ram.',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange.shade700)),
                          ],
                          const SizedBox(width: 4),
                          if (t.hasHandling)
                            _badge('M', Colors.deepOrange),
                          if (t.extraTour)
                            _badge('+T', Colors.purple),
                          const Icon(Icons.chevron_right,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 9, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}

// ── Carte détail par commissionnaire ─────────────────────────────────────────

class _ClientDetailCard extends StatefulWidget {
  final String clientName;
  final List<Tour> tours;
  final List<Truck> allTrucks;
  final String Function(DateTime) fmtDay;
  final void Function(Tour) onShowDetail;

  const _ClientDetailCard({
    required this.clientName,
    required this.tours,
    required this.allTrucks,
    required this.fmtDay,
    required this.onShowDetail,
  });

  @override
  State<_ClientDetailCard> createState() => _ClientDetailCardState();
}

class _ClientDetailCardState extends State<_ClientDetailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final tours = widget.tours;
    final totalKm = tours.fold(0.0, (s, t) => s + t.kmTotal);
    final totalClients = tours.fold(0, (s, t) => s + t.clientsCount);
    final handlingCount = tours.where((t) => t.hasHandling).length;
    final trucks = tours.map((t) => t.truckPlate).toSet();
    final drivers = tours.map((t) => t.driverName).toSet();
    final isUnknown = widget.clientName == 'Non renseigné';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isUnknown
                              ? Colors.grey.withValues(alpha: 0.12)
                              : Colors.blue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.business,
                          color: isUnknown ? Colors.grey : Colors.blue,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.clientName,
                                style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: isUnknown ? Colors.grey : null)),
                            Text(
                              '${trucks.length} camion${trucks.length > 1 ? 's' : ''} • ${drivers.length} chauffeur${drivers.length > 1 ? 's' : ''}',
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      // Nombre de tournées
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${tours.length} tournée${tours.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.blue),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        _expanded ? Icons.expand_less : Icons.expand_more,
                        color: Colors.grey,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Stats
                  Row(
                    children: [
                      _miniStat(Icons.local_shipping, '${trucks.length}',
                          'camions', Colors.teal),
                      const SizedBox(width: 8),
                      _miniStat(Icons.speed_outlined,
                          totalKm.toStringAsFixed(0), 'km', Colors.purple),
                      const SizedBox(width: 8),
                      _miniStat(Icons.people_outline, '$totalClients',
                          'clients', Colors.indigo),
                      const SizedBox(width: 8),
                      _miniStat(Icons.pan_tool_outlined, '$handlingCount',
                          'manut.', Colors.deepOrange),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Camions utilisés
                  Wrap(
                    spacing: 6,
                    children: trucks.map((plate) {
                      final truck = widget.allTrucks
                          .where((t) => t.plate == plate)
                          .firstOrNull;
                      final truckTours =
                          tours.where((t) => t.truckPlate == plate).length;
                      return Chip(
                        label: Text(
                          '$plate ($truckTours t.)',
                          style: const TextStyle(fontSize: 11),
                        ),
                        avatar: const Icon(Icons.local_shipping, size: 14),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // Détail tournées
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: tours.map((t) {
                  return InkWell(
                    onTap: () => widget.onShowDetail(t),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 42,
                            child: Text(widget.fmtDay(t.date),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ),
                          CircleAvatar(
                            radius: 12,
                            child: Text(t.driverName[0].toUpperCase(),
                                style: const TextStyle(fontSize: 10)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(t.driverName,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600)),
                                Text(
                                  '#${t.tourNumber} • ${t.truckPlate}',
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Text('${t.kmTotal.toStringAsFixed(0)} km',
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Text('${t.clientsCount} cl.',
                              style: const TextStyle(
                                  fontSize: 11, color: DC.textSecondary)),
                          if (t.pickupCount > 0) ...[
                            const SizedBox(width: 4),
                            Text('${t.pickupCount} ram.',
                                style: TextStyle(
                                    fontSize: 11, color: Colors.orange.shade700)),
                          ],
                          const SizedBox(width: 4),
                          if (t.hasHandling)
                            _badge('M', Colors.deepOrange),
                          if (t.extraTour)
                            _badge('+T', Colors.purple),
                          const Icon(Icons.chevron_right,
                              size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 9, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
