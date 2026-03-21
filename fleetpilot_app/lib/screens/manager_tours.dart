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
  String _selectedDriver = 'Tous';
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  static const _months = [
    'Janvier','Février','Mars','Avril','Mai','Juin',
    'Juillet','Août','Septembre','Octobre','Novembre','Décembre',
  ];

  String _monthLabel(DateTime m) => '${_months[m.month - 1]} ${m.year}';
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final allTours = [...state.tours]..sort((a, b) => b.date.compareTo(a.date));

    // Filtres
    final filtered = allTours.where((t) {
      final sameMonth = t.date.year == _selectedMonth.year &&
          t.date.month == _selectedMonth.month;
      final matchesDriver =
          _selectedDriver == 'Tous' || t.driverName == _selectedDriver;
      return sameMonth && matchesDriver;
    }).toList();

    final driverNames = allTours.map((t) => t.driverName).toSet().toList()..sort();

    // Stats
    final totalKm = filtered.fold(0.0, (s, t) => s + t.kmTotal);
    final totalClients = filtered.fold(0, (s, t) => s + t.clientsCount);
    final handlingCount = filtered.where((t) => t.hasHandling).length;

    // Grouper par jour
    final Map<String, List<Tour>> byDay = {};
    for (final t in filtered) {
      final key = _fmt(t.date);
      byDay.putIfAbsent(key, () => []).add(t);
    }
    final sortedDays = byDay.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Tournées',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),

        // ── Filtres simples
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Mois
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
                const SizedBox(width: 8),
                // Chauffeur
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: ['Tous', ...driverNames].contains(_selectedDriver)
                        ? _selectedDriver : 'Tous',
                    decoration: const InputDecoration(
                      labelText: 'Chauffeur',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: ['Tous', ...driverNames]
                        .map((d) => DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedDriver = v ?? 'Tous'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // ── Stats résumé
        Row(
          children: [
            _stat('Tournées', '${filtered.length}', Colors.blue),
            const SizedBox(width: 8),
            _stat('Km', totalKm.toStringAsFixed(0), Colors.teal),
            const SizedBox(width: 8),
            _stat('Clients', '$totalClients', Colors.indigo),
            const SizedBox(width: 8),
            _stat('Manut.', '$handlingCount', Colors.deepOrange),
          ],
        ),
        const SizedBox(height: 16),

        // ── Liste par jour
        if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text('Aucune tournée en ${_monthLabel(_selectedMonth)}.',
                    style: const TextStyle(color: Colors.grey)),
              ),
            ),
          )
        else
          for (final day in sortedDays) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6, top: 8),
              child: Text(day,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: Colors.grey)),
            ),
            ...byDay[day]!.map((t) => _tourCard(t, state)),
          ],

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _tourCard(Tour t, AppState state) {
    final truck = state.trucks.where((tr) => tr.plate == t.truckPlate).firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showDetail(t),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Chauffeur avatar
              CircleAvatar(
                radius: 16,
                child: Text(t.driverName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 10),
              // Info principale
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.driverName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      '#${t.tourNumber} • ${t.truckPlate}${t.companyName != null ? ' • ${t.companyName}' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Stats
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${t.kmTotal.toStringAsFixed(0)} km',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  Text('${t.clientsCount} cl.',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
              const SizedBox(width: 6),
              // Badges
              if (t.hasHandling || t.extraTour)
                Column(
                  children: [
                    if (t.hasHandling) _badge('M', Colors.deepOrange),
                    if (t.extraTour) _badge('+T', Colors.purple),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
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
              _dl('Date', _fmt(t.date)),
              _dl('Chauffeur', t.driverName),
              _dl('Camion', t.truckPlate),
              _dl('Client', t.companyName ?? '—'),
              _dl('Horaires', '${t.startTime ?? '—'} → ${t.endTime ?? '—'}'),
              _dl('Km', '${t.kmTotal.toStringAsFixed(0)} km'),
              _dl('Clients', '${t.clientsCount}'),
              if (t.weightKg != null)
                _dl('Poids', '${t.weightKg!.toStringAsFixed(0)} kg'),
              _dl('Manutention', t.hasHandling ? 'Oui — ${t.handlingClientName ?? ''}' : 'Non'),
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

  Widget _dl(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}
