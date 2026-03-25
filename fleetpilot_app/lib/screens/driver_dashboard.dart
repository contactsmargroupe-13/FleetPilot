import 'package:flutter/material.dart';
import '../utils/design_constants.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'models/driver.dart';
import 'models/tour.dart';
import 'manager_urssaf.dart';

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

    // Stats du mois — source unique : tours
    final totalKm = monthTours.fold(0.0, (s, t) => s + t.kmTotal);
    final totalClients = monthTours.fold(0, (s, t) => s + t.clientsCount);
    final joursT = monthTours
        .map((t) => '${t.date.year}-${t.date.month}-${t.date.day}')
        .toSet()
        .length;
    final totalPickups = monthTours.fold(0, (s, t) => s + t.pickupCount);
    final handlingCount =
        monthTours.where((t) => t.hasHandling).length;

    // Stats année — source unique : tours
    final yearTours = state.tours
        .where((t) =>
            t.driverName.toLowerCase() == name &&
            t.date.year == _selectedMonth.year)
        .toList();
    final yearKm = yearTours.fold(0.0, (s, t) => s + t.kmTotal);
    final yearJours = yearTours
        .map((t) => '${t.date.year}-${t.date.month}-${t.date.day}')
        .toSet()
        .length;

    // Salaire — affiché en net (brut - charges salariales)
    final tauxSalarial = UrssafRates.totalSalarial / 100;
    final salaireBrutMois = driver.totalSalary;
    final salaireMois = salaireBrutMois * (1 - tauxSalarial);
    final salaireJour =
        joursT > 0 ? salaireMois / 22 : 0.0; // base 22j/mois
    final salaireAnnee = salaireMois * 12;
    final fixedNet = driver.fixedSalary * (1 - tauxSalarial);
    final bonusNet = driver.bonus * (1 - tauxSalarial);

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

        // ── Salaire (net) ──────────────────────────────────────────────
        _sectionTitle('Salaire net'),
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
                _detailLine('Salaire fixe net',
                    '${fixedNet.toStringAsFixed(0)} €'),
                _detailLine(
                    'Bonus net', '${bonusNet.toStringAsFixed(0)} €'),
                const Divider(),
                _detailLine('Total mensuel net',
                    '${salaireMois.toStringAsFixed(0)} €',
                    bold: true),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // ── Chronologie paie ──────────────────────────────────────────
        _sectionTitle('Ma paie net — $_monthLabel'),
        _buildSalaryProgress(joursT, driver, salaireMois),
        const SizedBox(height: 20),

        // ── Absences ──────────────────────────────────────────────────
        _sectionTitle('Absences — $_monthLabel'),
        _buildAbsences(joursT),
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
            _statCard('Colis / Fiches', '$totalClients',
                Icons.inventory_2_outlined, Colors.indigo),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _statCard('Ramasses', '$totalPickups',
                Icons.move_to_inbox_outlined, Colors.orange),
            const SizedBox(width: 10),
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

  Widget _buildSalaryProgress(int joursT, Driver driver, double salaireMois) {
    const joursBase = 22; // jours ouvrés par mois
    final progress = joursT / joursBase;
    final progressClamped = progress.clamp(0.0, 1.0);
    final salaireAccumule = salaireMois * progressClamped;
    final reste = (salaireMois - salaireAccumule).clamp(0.0, salaireMois);

    // Emoji ludique selon progression
    final String emoji;
    final String message;
    if (progress >= 1.0) {
      emoji = '🎉';
      message = 'Objectif atteint ! Salaire complet gagné.';
    } else if (progress >= 0.75) {
      emoji = '🔥';
      message = 'Presque ! Plus que ${joursBase - joursT} jours.';
    } else if (progress >= 0.5) {
      emoji = '💪';
      message = 'Mi-parcours passé, continue !';
    } else if (progress > 0) {
      emoji = '🚀';
      message = 'C\'est parti ! ${joursBase - joursT} jours restants.';
    } else {
      emoji = '⏳';
      message = 'Aucun jour travaillé ce mois.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec emoji
            Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${salaireAccumule.toStringAsFixed(0)} € / ${salaireMois.toStringAsFixed(0)} €',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        message,
                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progressClamped,
                minHeight: 16,
                backgroundColor: DC.surface2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1.0
                      ? Colors.green
                      : progress >= 0.75
                          ? Colors.orange
                          : Colors.blue,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Détail jours
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$joursT jours travaillés',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${(progressClamped * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: progress >= 1.0 ? Colors.green : Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Détails ligne par ligne
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DC.surface2,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _detailLine('Jours travaillés', '$joursT / $joursBase'),
                  _detailLine('Accumulé', '${salaireAccumule.toStringAsFixed(0)} €'),
                  _detailLine(
                    'Reste à gagner',
                    '${reste.toStringAsFixed(0)} €',
                  ),
                  _detailLine(
                    'Salaire / jour',
                    '${(salaireMois / joursBase).toStringAsFixed(0)} €',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAbsences(int joursT) {
    const joursBase = 22;
    final now = DateTime.now();
    final isCurrentMonth = _selectedMonth.year == now.year &&
        _selectedMonth.month == now.month;

    // Jours écoulés dans le mois (ouvrés approximatifs)
    int joursOuvresEcoules;
    if (isCurrentMonth) {
      // Compter les jours ouvrés écoulés (lundi-vendredi)
      int count = 0;
      for (int d = 1; d <= now.day; d++) {
        final date = DateTime(_selectedMonth.year, _selectedMonth.month, d);
        if (date.weekday <= 5) count++;
      }
      joursOuvresEcoules = count;
    } else {
      joursOuvresEcoules = joursBase;
    }

    final joursAbsents = (joursOuvresEcoules - joursT).clamp(0, joursBase);

    if (joursAbsents == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_outline, color: Colors.green),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Aucune absence ce mois. Présence parfaite !',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.event_busy, color: Colors.orange),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$joursAbsents jour${joursAbsents > 1 ? 's' : ''} d\'absence',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Sur $joursOuvresEcoules jours ouvrés écoulés',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _detailLine('Jours ouvrés écoulés', '$joursOuvresEcoules'),
                  _detailLine('Jours travaillés', '$joursT'),
                  _detailLine('Jours absents', '$joursAbsents'),
                  _detailLine(
                    'Taux de présence',
                    joursOuvresEcoules > 0
                        ? '${(joursT / joursOuvresEcoules * 100).toStringAsFixed(0)}%'
                        : '—',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Motif non renseigné — contacte ton manager pour justifier tes absences.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
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
            // Km + colis
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${t.kmTotal.toStringAsFixed(0)} km',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 13),
                ),
                Text(
                  '${t.clientsCount} cl.${t.pickupCount > 0 ? ' · ${t.pickupCount} ram.' : ''}',
                  style: TextStyle(fontSize: 10, color: DC.textSecondary),
                ),
              ],
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
