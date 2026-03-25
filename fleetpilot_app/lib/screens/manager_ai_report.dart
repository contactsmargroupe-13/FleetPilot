import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../services/ai_service.dart';
import '../services/pdf_invoice_service.dart';
import 'models/expense.dart';

class ManagerAiReportPage extends ConsumerStatefulWidget {
  const ManagerAiReportPage({super.key});

  @override
  ConsumerState<ManagerAiReportPage> createState() =>
      _ManagerAiReportPageState();
}

class _ManagerAiReportPageState extends ConsumerState<ManagerAiReportPage> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  String? _report;
  List<String> _alerts = [];
  bool _loadingReport = false;
  bool _loadingAlerts = false;

  static const List<String> _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  String _buildContext() {
    final state = ref.read(appStateProvider);
    final m = _selectedMonth;

    final tours = state.tours
        .where((t) => t.date.year == m.year && t.date.month == m.month)
        .toList();
    final expenses = state.expenses
        .where((e) => e.date.year == m.year && e.date.month == m.month)
        .toList();

    final totalKm = tours.fold(0.0, (s, t) => s + t.kmTotal);
    final totalClients = tours.fold(0, (s, t) => s + t.clientsCount);
    final totalExp = expenses.fold(0.0, (s, e) => s + e.amount);
    final fuelExp = expenses
        .where((e) => e.type == ExpenseType.fuel)
        .fold(0.0, (s, e) => s + e.amount);
    final repairExp = expenses
        .where((e) => e.type == ExpenseType.repair)
        .fold(0.0, (s, e) => s + e.amount);
    final totalSalaries =
        state.drivers.fold(0.0, (s, d) => s + d.totalSalary);

    final buf = StringBuffer();
    buf.writeln('PÉRIODE : $_monthLabel');
    buf.writeln('TOURNÉES : ${tours.length}');
    buf.writeln('KM TOTAL : ${totalKm.toStringAsFixed(0)}');
    buf.writeln('CLIENTS : $totalClients');
    buf.writeln('DÉPENSES TOTALES : ${totalExp.toStringAsFixed(0)} €');
    buf.writeln('  - Carburant : ${fuelExp.toStringAsFixed(0)} €');
    buf.writeln('  - Réparations : ${repairExp.toStringAsFixed(0)} €');
    buf.writeln('MASSE SALARIALE : ${totalSalaries.toStringAsFixed(0)} €');
    buf.writeln();

    buf.writeln('PAR CAMION :');
    for (final truck in state.trucks) {
      final tt = tours.where((t) => t.truckPlate == truck.plate);
      final tk = tt.fold(0.0, (s, t) => s + t.kmTotal);
      final te = expenses
          .where((e) => e.truckPlate == truck.plate)
          .fold(0.0, (s, e) => s + e.amount);
      // Revenu via tarifs commissionnaires des tournées réelles
      double revenue = 0;
      for (final tour in tt) {
        final pricing = state.getClientPricing(tour.companyName);
        if (pricing != null) revenue += pricing.dailyRate;
      }
      final profit = revenue - te -
          (truck.monthlyCost ?? 0) -
          (state.drivers.isEmpty ? 0 : totalSalaries / state.trucks.length);
      buf.writeln(
          '  ${truck.plate} (${truck.model}): ${tt.length} tournées, '
          '${tk.toStringAsFixed(0)} km, dépenses ${te.toStringAsFixed(0)} €, '
          'profit estimé ${profit.toStringAsFixed(0)} €');
    }
    buf.writeln();

    buf.writeln('PAR CHAUFFEUR :');
    for (final d in state.drivers) {
      final dt = tours.where(
          (t) => t.driverName.toLowerCase() == d.name.toLowerCase());
      buf.writeln(
          '  ${d.name}: ${dt.length} tournées, '
          '${dt.fold(0.0, (s, t) => s + t.kmTotal).toStringAsFixed(0)} km, '
          'salaire ${d.totalSalary.toStringAsFixed(0)} €');
    }

    return buf.toString();
  }

  Future<void> _generateReport() async {
    setState(() {
      _loadingReport = true;
      _report = null;
    });

    final result = await AiService.generateMonthlyReport(
      fleetContext: _buildContext(),
      monthLabel: _monthLabel,
    );

    if (mounted) {
      setState(() {
        _report = result;
        _loadingReport = false;
      });
    }
  }

  Future<void> _detectAlerts() async {
    setState(() {
      _loadingAlerts = true;
      _alerts = [];
    });

    final result = await AiService.detectAnomalies(
      fleetContext: _buildContext(),
    );

    if (mounted) {
      setState(() {
        _alerts = result;
        _loadingAlerts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.analytics_outlined, size: 22, color: Colors.blue),
            SizedBox(width: 8),
            Text('Rapport IA'),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mois
          Card(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month - 1);
                      _report = null;
                      _alerts = [];
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(_monthLabel,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month + 1);
                      _report = null;
                      _alerts = [];
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Boutons
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _loadingReport ? null : _generateReport,
                  icon: _loadingReport
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_loadingReport
                        ? 'Génération...'
                        : 'Générer le rapport'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loadingAlerts ? null : _detectAlerts,
                  icon: _loadingAlerts
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.warning_amber_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_loadingAlerts
                        ? 'Analyse...'
                        : 'Détecter anomalies'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Alertes prédictives
          if (_alerts.isNotEmpty) ...[
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Alertes prédictives',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ..._alerts.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle,
                                  size: 8, color: Colors.orange),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(a,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Rapport
          if (_report != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.analytics_outlined, size: 18, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Rapport $_monthLabel',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    SelectableText(
                      _report!,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

          if (_report == null && _alerts.isEmpty && !_loadingReport && !_loadingAlerts)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.smart_toy_outlined, size: 40, color: Colors.blue),
                    const SizedBox(height: 12),
                    const Text(
                      'Générez un rapport mensuel ou détectez les anomalies',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
