import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'models/driver.dart';
import 'models/tour.dart';

class DriverDashboardPage extends ConsumerStatefulWidget {
  final String driverName;
  const DriverDashboardPage({super.key, required this.driverName});

  @override
  ConsumerState<DriverDashboardPage> createState() =>
      _DriverDashboardPageState();
}

class _DriverDashboardPageState extends ConsumerState<DriverDashboardPage> {
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  static const List<String> _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final name = widget.driverName.toLowerCase();

    // Trouver le profil chauffeur
    final driver = state.drivers.firstWhere(
      (d) => d.name.toLowerCase() == name,
      orElse: () => Driver(name: widget.driverName, fixedSalary: 0),
    );

    // Tournées du mois sélectionné
    final monthTours = state.tours
        .where((t) =>
            t.driverName.toLowerCase() == name &&
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    // Day entries du mois
    final monthEntries = state.driverDayEntries
        .where((e) =>
            e.driverName.toLowerCase() == name &&
            e.date.year == _selectedMonth.year &&
            e.date.month == _selectedMonth.month)
        .toList();

    // Stats du mois
    final totalKm = monthEntries.fold(0.0, (s, e) => s + e.kmTotal);
    final totalClients = monthEntries.fold(0, (s, e) => s + e.clientsCount);
    final joursT = monthEntries
        .map((e) => '${e.date.year}-${e.date.month}-${e.date.day}')
        .toSet()
        .length;
    final handlingCount =
        monthTours.where((t) => t.hasHandling).length;

    // Stats année
    final yearTours = state.tours
        .where((t) =>
            t.driverName.toLowerCase() == name &&
            t.date.year == _selectedMonth.year)
        .toList();
    final yearEntries = state.driverDayEntries
        .where((e) =>
            e.driverName.toLowerCase() == name &&
            e.date.year == _selectedMonth.year)
        .toList();
    final yearKm = yearEntries.fold(0.0, (s, e) => s + e.kmTotal);
    final yearJours = yearEntries
        .map((e) => '${e.date.year}-${e.date.month}-${e.date.day}')
        .toSet()
        .length;

    // Salaire
    final salaireJour =
        joursT > 0 ? driver.fixedSalary / 22 : 0.0; // base 22j/mois
    final salaireMois = driver.totalSalary;
    final salaireAnnee = driver.totalSalary * 12;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Mon tableau de bord',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),

        // ── Sélecteur mois ──────────────────────────────────────────────
        Card(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                    child: Text(
                      _monthLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
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
        const SizedBox(height: 16),

        // ── Salaire ─────────────────────────────────────────────────────
        _sectionTitle('Salaire'),
        Row(
          children: [
            _statCard('Jour', '${salaireJour.toStringAsFixed(0)} €',
                Icons.today_outlined, Colors.blue),
            const SizedBox(width: 10),
            _statCard('Mois', '${salaireMois.toStringAsFixed(0)} €',
                Icons.calendar_month_outlined, Colors.green),
            const SizedBox(width: 10),
            _statCard('Année', '${salaireAnnee.toStringAsFixed(0)} €',
                Icons.date_range_outlined, Colors.purple),
          ],
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _detailLine('Salaire fixe',
                    '${driver.fixedSalary.toStringAsFixed(0)} €'),
                _detailLine(
                    'Bonus', '${driver.bonus.toStringAsFixed(0)} €'),
                const Divider(),
                _detailLine('Total mensuel',
                    '${salaireMois.toStringAsFixed(0)} €',
                    bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Activité du mois ────────────────────────────────────────────
        _sectionTitle('Activité — $_monthLabel'),
        Row(
          children: [
            _statCard('Jours', '$joursT', Icons.work_outline, Colors.orange),
            const SizedBox(width: 10),
            _statCard('Tournées', '${monthTours.length}',
                Icons.route_outlined, Colors.blue),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard('Km total', '${totalKm.toStringAsFixed(0)}',
                Icons.speed_outlined, Colors.teal),
            const SizedBox(width: 10),
            _statCard('Clients', '$totalClients',
                Icons.people_outline, Colors.indigo),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard('Manutentions', '$handlingCount',
                Icons.pan_tool_outlined, Colors.deepOrange),
            const SizedBox(width: 10),
            _statCard(
                'Km/jour',
                joursT > 0
                    ? '${(totalKm / joursT).toStringAsFixed(0)}'
                    : '—',
                Icons.analytics_outlined,
                Colors.cyan),
          ],
        ),
        const SizedBox(height: 20),

        // ── Stats année ─────────────────────────────────────────────────
        _sectionTitle('Année ${_selectedMonth.year}'),
        Row(
          children: [
            _statCard('Tournées', '${yearTours.length}',
                Icons.route_outlined, Colors.blue),
            const SizedBox(width: 10),
            _statCard('Km total', '${yearKm.toStringAsFixed(0)}',
                Icons.speed_outlined, Colors.teal),
            const SizedBox(width: 10),
            _statCard('Jours', '$yearJours', Icons.work_outline, Colors.orange),
          ],
        ),
        const SizedBox(height: 20),

        // ── Détail tournées du mois ─────────────────────────────────────
        _sectionTitle('Détail des tournées'),
        if (monthTours.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucune tournée ce mois.',
                  style: TextStyle(color: Colors.grey)),
            ),
          )
        else
          ...monthTours.map((t) => _tourCard(t)),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _statCard(
      String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLine(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          ),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _tourCard(Tour t) {
    final day =
        '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Date
            SizedBox(
              width: 50,
              child: Text(
                day,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
            // N° tournée
            SizedBox(
              width: 50,
              child: Text(
                '#${t.tourNumber}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            // Client
            Expanded(
              child: Text(
                t.companyName ?? '—',
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Km
            Text(
              '${t.kmTotal.toStringAsFixed(0)} km',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(width: 10),
            // Badges
            if (t.hasHandling)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'M',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
            if (t.extraTour)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+T',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
