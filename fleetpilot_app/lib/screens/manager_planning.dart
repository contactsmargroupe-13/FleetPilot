import 'package:flutter/material.dart';
import '../utils/design_constants.dart';
import '../utils/shared_widgets.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'models/driver.dart';
import 'models/tour.dart';

class ManagerPlanningPage extends ConsumerStatefulWidget {
  const ManagerPlanningPage({super.key});

  @override
  ConsumerState<ManagerPlanningPage> createState() =>
      _ManagerPlanningPageState();
}

class _ManagerPlanningPageState extends ConsumerState<ManagerPlanningPage> {
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} ${DC.monthNames[d.month - 1]} ${d.year}';

  bool _isToday(DateTime d) {
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);

    // Tournées du jour sélectionné
    final dayTours = state.tours
        .where((t) =>
            t.date.year == _selectedDate.year &&
            t.date.month == _selectedDate.month &&
            t.date.day == _selectedDate.day)
        .toList()
      ..sort((a, b) => a.driverName.compareTo(b.driverName));

    // Chauffeurs actifs (qui ont une tournée ce jour)
    final activeDriverNames =
        dayTours.map((t) => t.driverName.toLowerCase()).toSet();

    // Tous les chauffeurs
    final allDrivers = state.drivers
        .where((d) =>
            d.status != DriverStatus.vire &&
            d.status != DriverStatus.demission &&
            d.status != DriverStatus.finDeMission)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    // Chauffeurs absents
    final absentDrivers = allDrivers
        .where((d) => !activeDriverNames.contains(d.name.toLowerCase()))
        .toList();

    // Stats rapides
    final totalKm = dayTours.fold(0.0, (s, t) => s + t.kmTotal);
    final totalClients = dayTours.fold(0, (s, t) => s + t.clientsCount);
    final totalHandling = dayTours.where((t) => t.hasHandling).length;

    // Camions utilisés
    final trucksUsed = dayTours.map((t) => t.truckPlate).toSet();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Titre
        Text(
          _isToday(_selectedDate) ? "Suivi du jour" : "Suivi opérationnel",
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        // ── Sélecteur date
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _selectedDate = _selectedDate
                        .subtract(const Duration(days: 1));
                  }),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (picked != null) setState(() => _selectedDate = picked);
                    },
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            _isToday(_selectedDate)
                                ? "Aujourd'hui — ${_fmtDate(_selectedDate)}"
                                : _fmtDate(_selectedDate),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _isToday(_selectedDate) ? Colors.green : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _selectedDate =
                        _selectedDate.add(const Duration(days: 1));
                  }),
                ),
              ],
            ),
          ),
        ),
        if (!_isToday(_selectedDate))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() {
                  final now = DateTime.now();
                  _selectedDate = DateTime(now.year, now.month, now.day);
                }),
                icon: const Icon(Icons.today, size: 16),
                label: const Text("Revenir à aujourd'hui"),
              ),
            ),
          ),
        const SizedBox(height: 16),

        // ── Stats rapides
        Row(
          children: [
            _quickStat('Chauffeurs', '${activeDriverNames.length}',
                Icons.groups_outlined, Colors.blue),
            const SizedBox(width: 8),
            _quickStat('Camions', '${trucksUsed.length}',
                Icons.local_shipping_outlined, Colors.teal),
            const SizedBox(width: 8),
            _quickStat('Tournées', '${dayTours.length}',
                Icons.route_outlined, Colors.orange),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _quickStat('Km total', totalKm.toStringAsFixed(0),
                Icons.speed_outlined, Colors.purple),
            const SizedBox(width: 8),
            _quickStat('Clients', '$totalClients',
                Icons.people_outline, Colors.indigo),
            const SizedBox(width: 8),
            _quickStat('Manut.', '$totalHandling',
                Icons.pan_tool_outlined, Colors.deepOrange),
          ],
        ),
        const SizedBox(height: 20),

        // ── Chauffeurs en activité
        if (dayTours.isNotEmpty) ...[
          _sectionTitle('En activité', count: activeDriverNames.length,
              color: Colors.green),
          ...dayTours.map((t) => _tourCard(t, state)),
          const SizedBox(height: 16),
        ],

        // ── Chauffeurs absents
        if (absentDrivers.isNotEmpty) ...[
          _sectionTitle('Absents', count: absentDrivers.length,
              color: Colors.orange),
          Card(
            child: Column(
              children: absentDrivers.map((d) {
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.orange.withValues(alpha: 0.12),
                    child: Text(
                      d.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: Colors.orange, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(d.fullName,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(driverStatusLabel(d.status),
                      style: const TextStyle(fontSize: 12)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Absent',
                        style: TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w700)),
                  ),
                );
              }).toList(),
            ),
          ),
        ],

        // ── Aucune activité
        if (dayTours.isEmpty && absentDrivers.isEmpty)
          const DCEmptyState(
            icon: Icons.event_busy_outlined,
            title: 'Aucune donnée pour cette date.',
          ),

        if (dayTours.isEmpty && absentDrivers.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: DC.textTertiary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Aucune tournée enregistrée ce jour.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _quickStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color)),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, {int count = 0, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700)),
          if (count > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (color ?? Colors.grey).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('$count',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: color)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _tourCard(Tour tour, AppState state) {
    final truck = state.trucks
        .where((t) => t.plate == tour.truckPlate)
        .firstOrNull;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : chauffeur + camion
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green.withValues(alpha: 0.12),
                  child: Text(
                    tour.driverName[0].toUpperCase(),
                    style: const TextStyle(
                        color: Colors.green, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tour.driverName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${tour.truckPlate}${truck != null ? ' • ${truck.model}' : ''}',
                        style: const TextStyle(
                            fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                // Horaires
                if (tour.startTime != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${tour.startTime ?? ''}${tour.endTime != null ? ' → ${tour.endTime}' : ''}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Ligne 2 : stats
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _chip('#${tour.tourNumber}', Colors.grey),
                if (tour.companyName != null && tour.companyName!.isNotEmpty)
                  _chip(tour.companyName!, Colors.blue),
                _chip('${tour.kmTotal.toStringAsFixed(0)} km', Colors.teal),
                _chip('${tour.clientsCount} clients', Colors.indigo),
                if (tour.hasHandling)
                  _chip('Manutention', Colors.deepOrange),
                if (tour.extraTour)
                  _chip('Tour supp.', Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}
