import 'package:flutter/material.dart';

import '../store/app_store.dart';
import '../services/manager_ai_service.dart';
import 'manager_admin.dart';
import 'manager_billing.dart';
import 'manager_drivers.dart';
import 'manager_expenses.dart';
import 'manager_planning.dart';
import 'manager_recruitment.dart';
import 'manager_settings.dart';
import 'manager_tours.dart';
import 'manager_vehicles.dart';
import 'models/driver.dart';
import 'models/expense.dart';

class ManagerShell extends StatefulWidget {
  const ManagerShell({super.key});

  @override
  State<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends State<ManagerShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ManagerDashboardPage(),
      const ManagerPlanningPage(),
      const ManagerDriversPage(),
      const ManagerVehiclesPage(),
      const ManagerTours(),
      const _FinancesMenuPage(),
      const _AdminMenuPage(),
      const ManagerSettingsPage(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text("FleetPilot Manager")),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: "Dashboard",
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: "Planning",
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            label: "Chauffeurs",
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            label: "Camions",
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            label: "Tournées",
          ),
          NavigationDestination(
            icon: Icon(Icons.euro_outlined),
            label: "Finances",
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            label: "Admin & RH",
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            label: "Paramètres",
          ),
        ],
      ),
    );
  }
}

class ManagerDashboardPage extends StatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  State<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends State<ManagerDashboardPage> {
  String? _selectedPlate;
  late DateTime _selectedMonth;

  final Map<String, TextEditingController> _daysCtrls = {};

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
  }

  String _monthKey(DateTime m) => "${m.year}-${m.month.toString().padLeft(2, '0')}";

  String _daysKey(String plate, DateTime m) => "$plate|${_monthKey(m)}";

  TextEditingController _daysCtrlFor(String plate, DateTime month) {
    final key = _daysKey(plate, month);
    return _daysCtrls.putIfAbsent(
      key,
      () => TextEditingController(text: "22"),
    );
  }

  int _parseDays(String s) {
    final v = int.tryParse(s.trim());
    return (v == null || v < 0) ? 0 : v;
  }

  Iterable<Expense> _truckExpensesForMonth(String plate, DateTime month) {
    return AppStore.expenses
        .where((e) => e.truckPlate == plate)
        .where((e) => e.date.year == month.year && e.date.month == month.month);
  }

  double _sumExpensesForTruckInMonth(String plate, DateTime month) {
    return _truckExpensesForMonth(plate, month)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _sumFuelExpensesForTruckInMonth(String plate, DateTime month) {
    return _truckExpensesForMonth(plate, month)
        .where((e) => e.type == ExpenseType.fuel)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _sumFuelLitersForTruckInMonth(String plate, DateTime month) {
    return _truckExpensesForMonth(plate, month)
        .where((e) => e.type == ExpenseType.fuel)
        .fold(0.0, (sum, e) => sum + (e.liters ?? 0.0));
  }

  double _sumMaintenanceExpensesForTruckInMonth(String plate, DateTime month) {
    return _truckExpensesForMonth(plate, month)
        .where((e) => e.type == ExpenseType.repair)
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  double _sumKmForMonth(DateTime month) {
    return AppStore.driverDayEntries
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .fold(0.0, (sum, e) => sum + e.kmTotal);
  }

  double _sumKmForTruckInMonth(String plate, DateTime month) {
    return AppStore.driverDayEntries
        .where((e) => e.truckPlate == plate)
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .fold(0.0, (sum, e) => sum + e.kmTotal);
  }

  double _truckFixedMonthlyCost(dynamic t) {
    try {
      final ownership = t.ownershipType.toString().toLowerCase();

      if (ownership.contains("location") ||
          ownership.contains("leasing") ||
          ownership.contains("lease")) {
        return (t.rentMonthly as num?)?.toDouble() ?? 0.0;
      }

      final purchase = (t.purchasePrice as num?)?.toDouble() ?? 0.0;
      final months = (t.amortMonths as num?)?.toDouble() ?? 0.0;
      if (months <= 0) return 0.0;
      return purchase / months;
    } catch (_) {
      return 0.0;
    }
  }

  double _costPerKm({
    required double expenses,
    required double fixed,
    required double salaryShare,
    required double km,
  }) {
    if (km <= 0) return 0.0;
    return (expenses + fixed + salaryShare) / km;
  }

  double _litersPer100({
    required double liters,
    required double km,
  }) {
    if (km <= 0 || liters <= 0) return 0.0;
    return (liters / km) * 100;
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'danger':
        return Colors.red;
      case 'warning':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  IconData _severityIcon(String severity) {
    switch (severity) {
      case 'danger':
        return Icons.warning_amber_rounded;
      case 'warning':
        return Icons.error_outline;
      default:
        return Icons.check_circle_outline;
    }
  }

  String _severityLabel(String severity) {
    switch (severity) {
      case 'danger':
        return 'Critique';
      case 'warning':
        return 'À surveiller';
      default:
        return 'Correct';
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTrucks = AppStore.trucks;

    final trucks = _selectedPlate == null
        ? allTrucks
        : allTrucks.where((t) => t.plate == _selectedPlate).toList();

    final List<Driver> drivers = AppStore.drivers;

    final double totalSalaries =
        drivers.fold<double>(0.0, (sum, d) => sum + d.totalSalary);

    final double totalKmMonth = _sumKmForMonth(_selectedMonth);

    final double salarySharePerTruck =
        allTrucks.isEmpty ? 0.0 : totalSalaries / allTrucks.length;

    double totalRevenue = 0;
    double totalExpenses = 0;
    double totalFixed = 0;
    double totalFuelLiters = 0;

    final List<_TruckProfitData> chartData = [];
    final List<Widget> cards = [];
    final List<_TruckComputedData> computedTrucks = [];

    for (final t in trucks) {
      final daysCtrl = _daysCtrlFor(t.plate, _selectedMonth);
      final days = _parseDays(daysCtrl.text);

      final revenue = (t.dailyRate as num).toDouble() * days;

      final expenses = _sumExpensesForTruckInMonth(t.plate, _selectedMonth);

      final fuelExpenses =
          _sumFuelExpensesForTruckInMonth(t.plate, _selectedMonth);

      final fuelLiters =
          _sumFuelLitersForTruckInMonth(t.plate, _selectedMonth);

      final maintenanceExpenses =
          _sumMaintenanceExpensesForTruckInMonth(t.plate, _selectedMonth);

      final kmTruckMonth = _sumKmForTruckInMonth(t.plate, _selectedMonth);

      final fixed = _truckFixedMonthlyCost(t);

      final profitTruck = revenue - expenses - fixed;

      final costPerKm = _costPerKm(
        expenses: expenses,
        fixed: fixed,
        salaryShare: salarySharePerTruck,
        km: kmTruckMonth,
      );

      final litersPer100 = _litersPer100(
        liters: fuelLiters,
        km: kmTruckMonth,
      );

      totalRevenue += revenue;
      totalExpenses += expenses;
      totalFixed += fixed;
      totalFuelLiters += fuelLiters;

      final analysis = ManagerAiService.analyzeTruckLoss(
        truckName: t.plate,
        revenue: revenue,
        expenses: expenses,
        fuelExpenses: fuelExpenses,
        maintenanceExpenses: maintenanceExpenses,
        fixedCosts: fixed,
        profit: profitTruck,
        km: kmTruckMonth,
        costPerKm: costPerKm,
        litersPer100: litersPer100,
      );

      computedTrucks.add(
        _TruckComputedData(
          plate: t.plate,
          model: t.model,
          revenue: revenue,
          expenses: expenses,
          fuelExpenses: fuelExpenses,
          maintenanceExpenses: maintenanceExpenses,
          fixedCosts: fixed,
          profit: profitTruck,
          km: kmTruckMonth,
          fuelLiters: fuelLiters,
          costPerKm: costPerKm,
          litersPer100: litersPer100,
          score: analysis.score,
          analysis: analysis,
        ),
      );

      if (_selectedPlate == null) {
        chartData.add(
          _TruckProfitData(
            plate: t.plate,
            profit: profitTruck,
          ),
        );
      }

      final Color truckBarColor = profitTruck >= 0 ? Colors.green : Colors.red;

      cards.add(
        Card(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: truckBarColor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: daysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: "Jours travaillés (mois)",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: "Revenus",
                        value: "${revenue.toStringAsFixed(0)} €",
                        icon: Icons.payments_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: "Dépenses",
                        value: "${expenses.toStringAsFixed(0)} €",
                        icon: Icons.receipt_long,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: "Fixe camion",
                        value: "${fixed.toStringAsFixed(0)} €",
                        icon: Icons.home_work_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: "Carburant",
                        value: "${fuelExpenses.toStringAsFixed(0)} €",
                        icon: Icons.local_gas_station_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: "Réparations",
                        value: "${maintenanceExpenses.toStringAsFixed(0)} €",
                        icon: Icons.build_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: "Km camion",
                        value: "${kmTruckMonth.toStringAsFixed(0)} km",
                        icon: Icons.route_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: "Profit camion",
                        value: "${profitTruck.toStringAsFixed(0)} €",
                        icon: Icons.trending_up,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _StatBox(
                        label: "Coût / km",
                        value: kmTruckMonth > 0
                            ? "${costPerKm.toStringAsFixed(2)} €"
                            : "-",
                        icon: Icons.speed_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        label: "L / 100 km",
                        value: litersPer100 > 0
                            ? litersPer100.toStringAsFixed(1)
                            : "-",
                        icon: Icons.local_gas_station,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _ScoreCard(score: analysis.score),
                const SizedBox(height: 12),
                _AiAnalysisCard(
                  analysis: analysis,
                  severityColor: _severityColor(_analysisSeverity(analysis)),
                  severityIcon: _severityIcon(_analysisSeverity(analysis)),
                  severityLabel: _severityLabel(_analysisSeverity(analysis)),
                  reasons: _analysisReasons(analysis),
                  actions: _analysisActions(analysis),
                ),
              ],
            ),
          ),
          // close Expanded
          ),
          // close Row children
          ],
        ),
        // close IntrinsicHeight
        ),
        // close ClipRRect
        ),
      ),
      // close Card
      );
    }

    final totalProfit =
        totalRevenue - totalExpenses - totalFixed - totalSalaries;

    final totalCostPerKm = totalKmMonth > 0
        ? (totalExpenses + totalFixed + totalSalaries) / totalKmMonth
        : 0.0;

    final totalLitersPer100 = totalKmMonth > 0 && totalFuelLiters > 0
        ? (totalFuelLiters / totalKmMonth) * 100
        : 0.0;

    int profitableCount = 0;
    int warningCount = 0;
    int lossCount = 0;

    for (final truck in computedTrucks) {
      if (truck.profit < 0 || truck.score < 40) {
        lossCount++;
      } else if (truck.score < 70) {
        warningCount++;
      } else {
        profitableCount++;
      }
    }

    final profitableTrucks = [...computedTrucks]
      ..sort((a, b) => b.profit.compareTo(a.profit));
    final warningTrucks = computedTrucks
        .where((t) => !(t.profit < 0 || t.score < 40) && t.score < 70)
        .toList()
      ..sort((a, b) => a.score.compareTo(b.score));
    final lossTrucks = computedTrucks
        .where((t) => t.profit < 0 || t.score < 40)
        .toList()
      ..sort((a, b) => a.profit.compareTo(b.profit));

    final bestTruck = computedTrucks.isEmpty
        ? null
        : ([...computedTrucks]..sort((a, b) => b.profit.compareTo(a.profit))).first;

    final worstTruck = computedTrucks.isEmpty
        ? null
        : ([...computedTrucks]..sort((a, b) => a.profit.compareTo(b.profit))).first;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          "Dashboard",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        // ── KPI globaux ──────────────────────────────────────────────────
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _KpiCard(
                label: "CA mois",
                value: "${totalRevenue.toStringAsFixed(0)} €",
                icon: Icons.payments_outlined,
                color: Colors.blue,
              ),
              _KpiCard(
                label: "Dépenses mois",
                value: "${totalExpenses.toStringAsFixed(0)} €",
                icon: Icons.receipt_long_outlined,
                color: Colors.orange,
              ),
              _KpiCard(
                label: "Profit global",
                value: "${totalProfit.toStringAsFixed(0)} €",
                icon: Icons.account_balance_wallet_outlined,
                color: totalProfit >= 0 ? Colors.green : Colors.red,
              ),
              _KpiCard(
                label: "Km mois",
                value: "${totalKmMonth.toStringAsFixed(0)} km",
                icon: Icons.route_outlined,
                color: Colors.blueGrey,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: _HealthBox(
                    label: "Rentables",
                    value: profitableCount.toString(),
                    icon: Icons.check_circle_outline,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HealthBox(
                    label: "À surveiller",
                    value: warningCount.toString(),
                    icon: Icons.visibility_outlined,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _HealthBox(
                    label: "En perte",
                    value: lossCount.toString(),
                    icon: Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Icon(Icons.calendar_month_outlined),
                const Text(
                  "Nouveau : Planning exploitation V2 disponible",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ManagerPlanningPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Ouvrir le planning"),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _DashboardSummaryBox(
                  label: "Revenus flotte",
                  value: "${totalRevenue.toStringAsFixed(0)} €",
                  icon: Icons.payments_outlined,
                ),
                _DashboardSummaryBox(
                  label: "Dépenses flotte",
                  value: "${totalExpenses.toStringAsFixed(0)} €",
                  icon: Icons.receipt_long_outlined,
                ),
                _DashboardSummaryBox(
                  label: "Profit global",
                  value: "${totalProfit.toStringAsFixed(0)} €",
                  icon: Icons.account_balance_wallet_outlined,
                ),
                _DashboardSummaryBox(
                  label: "Coût/km flotte",
                  value: totalCostPerKm > 0
                      ? "${totalCostPerKm.toStringAsFixed(2)} €"
                      : "-",
                  icon: Icons.speed_outlined,
                ),
                _DashboardSummaryBox(
                  label: "Conso flotte",
                  value: totalLitersPer100 > 0
                      ? "${totalLitersPer100.toStringAsFixed(1)} L/100"
                      : "-",
                  icon: Icons.local_gas_station_outlined,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          "Classement flotte",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _RankingSummaryCard(
              title: "Meilleur camion",
              value: bestTruck == null
                  ? "-"
                  : "${bestTruck.plate} • ${bestTruck.profit.toStringAsFixed(0)} €",
              color: Colors.green,
              icon: Icons.emoji_events_outlined,
            ),
            _RankingSummaryCard(
              title: "Pire camion",
              value: worstTruck == null
                  ? "-"
                  : "${worstTruck.plate} • ${worstTruck.profit.toStringAsFixed(0)} €",
              color: Colors.red,
              icon: Icons.report_problem_outlined,
            ),
            _RankingSummaryCard(
              title: "Camions analysés",
              value: computedTrucks.length.toString(),
              color: Colors.blueGrey,
              icon: Icons.local_shipping_outlined,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _FleetRankingSection(
          title: "Top rentables",
          color: Colors.green,
          icon: Icons.trending_up,
          items: profitableTrucks.take(5).toList(),
          severityColorBuilder: _severityColor,
          severityLabelBuilder: _severityLabel,
          severityGetter: _analysisSeverity,
          reasonsGetter: _analysisReasons,
          actionsGetter: _analysisActions,
        ),
        const SizedBox(height: 12),
        _FleetRankingSection(
          title: "À surveiller",
          color: Colors.orange,
          icon: Icons.visibility_outlined,
          items: warningTrucks.take(5).toList(),
          severityColorBuilder: _severityColor,
          severityLabelBuilder: _severityLabel,
          severityGetter: _analysisSeverity,
          reasonsGetter: _analysisReasons,
          actionsGetter: _analysisActions,
        ),
        const SizedBox(height: 12),
        _FleetRankingSection(
          title: "En perte",
          color: Colors.red,
          icon: Icons.warning_amber_rounded,
          items: lossTrucks.take(5).toList(),
          severityColorBuilder: _severityColor,
          severityLabelBuilder: _severityLabel,
          severityGetter: _analysisSeverity,
          reasonsGetter: _analysisReasons,
          actionsGetter: _analysisActions,
        ),
        const SizedBox(height: 12),
        Text(
          "Cartes profits camion",
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: computedTrucks
              .map(
                (truck) => _ProfitTruckCard(
                  truck: truck,
                  severity: _analysisSeverity(truck.analysis),
                  severityColor: _severityColor(_analysisSeverity(truck.analysis)),
                  severityLabel: _severityLabel(_analysisSeverity(truck.analysis)),
                  reasons: _analysisReasons(truck.analysis),
                  actions: _analysisActions(truck.analysis),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 12),
        ...cards,
      ],
    );
  }

  String _analysisSeverity(AiLossAnalysis analysis) {
    try {
      final dynamic a = analysis;
      final value = a.severity;
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    } catch (_) {}

    if (analysis.score < 40) {
      return 'danger';
    }
    if (analysis.score < 70) {
      return 'warning';
    }
    return 'ok';
  }

  List<String> _analysisReasons(AiLossAnalysis analysis) {
    try {
      final dynamic a = analysis;
      final dynamic reasons = a.reasons;
      if (reasons is List) {
        return reasons.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }

  List<String> _analysisActions(AiLossAnalysis analysis) {
    try {
      final dynamic a = analysis;
      final dynamic actions = a.actions;
      if (actions is List) {
        return actions.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
      }
    } catch (_) {}
    return const [];
  }
}

class _HealthBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _HealthBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.35)),
        color: color.withOpacity(0.06),
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final int score;

  const _ScoreCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "Score rentabilité IA : $score / 100",
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _AiAnalysisCard extends StatelessWidget {
  final AiLossAnalysis analysis;
  final Color severityColor;
  final IconData severityIcon;
  final String severityLabel;
  final List<String> reasons;
  final List<String> actions;

  const _AiAnalysisCard({
    required this.analysis,
    required this.severityColor,
    required this.severityIcon,
    required this.severityLabel,
    required this.reasons,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: severityColor.withOpacity(0.35)),
        color: severityColor.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(severityIcon, color: severityColor),
              const SizedBox(width: 8),
              Text(
                "Analyse IA • $severityLabel",
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: severityColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(analysis.summary),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              "Erreurs possibles",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...reasons.map(
              (reason) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• "),
                    Expanded(child: Text(reason)),
                  ],
                ),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              "Recommandations",
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            ...actions.map(
              (action) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("• "),
                    Expanded(child: Text(action)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardSummaryBox extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _DashboardSummaryBox({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingSummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _RankingSummaryCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FleetRankingSection extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;
  final List<_TruckComputedData> items;
  final Color Function(String severity) severityColorBuilder;
  final String Function(String severity) severityLabelBuilder;
  final String Function(AiLossAnalysis analysis) severityGetter;
  final List<String> Function(AiLossAnalysis analysis) reasonsGetter;
  final List<String> Function(AiLossAnalysis analysis) actionsGetter;

  const _FleetRankingSection({
    required this.title,
    required this.color,
    required this.icon,
    required this.items,
    required this.severityColorBuilder,
    required this.severityLabelBuilder,
    required this.severityGetter,
    required this.reasonsGetter,
    required this.actionsGetter,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text("Aucun camion dans cette catégorie.")
            else
              ...items.map((truck) {
                final severity = severityGetter(truck.analysis);
                final reasons = reasonsGetter(truck.analysis);
                final actions = actionsGetter(truck.analysis);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: severityColorBuilder(severity).withOpacity(0.35)),
                    color: severityColorBuilder(severity).withOpacity(0.05),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "${truck.plate} • ${truck.model}",
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          _MiniBadge(
                            text: "Profit ${truck.profit.toStringAsFixed(0)} €",
                            color: truck.profit >= 0 ? Colors.green : Colors.red,
                          ),
                          _MiniBadge(
                            text: "Score ${truck.score}/100",
                            color: severityColorBuilder(severity),
                          ),
                          _MiniBadge(
                            text: severityLabelBuilder(severity),
                            color: severityColorBuilder(severity),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Coût/km : ${truck.km > 0 ? truck.costPerKm.toStringAsFixed(2) : '-'} € • "
                        "Conso : ${truck.litersPer100 > 0 ? truck.litersPer100.toStringAsFixed(1) : '-'} L/100",
                      ),
                      if (reasons.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Erreurs possibles",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        ...reasons.take(2).map(
                          (reason) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text("• $reason"),
                          ),
                        ),
                      ],
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          "Recommandations",
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        ...actions.take(2).map(
                          (action) => Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text("• $action"),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _ProfitTruckCard extends StatelessWidget {
  final _TruckComputedData truck;
  final String severity;
  final Color severityColor;
  final String severityLabel;
  final List<String> reasons;
  final List<String> actions;

  const _ProfitTruckCard({
    required this.truck,
    required this.severity,
    required this.severityColor,
    required this.severityLabel,
    required this.reasons,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final Color profitColor = truck.profit >= 0 ? Colors.green : Colors.red;

    return SizedBox(
      width: 320,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${truck.plate} • ${truck.model}",
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: "Profit",
                      value: "${truck.profit.toStringAsFixed(0)} €",
                      color: profitColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      label: "Score IA",
                      value: "${truck.score}/100",
                      color: severityColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: "Coût/km",
                      value: truck.km > 0
                          ? "${truck.costPerKm.toStringAsFixed(2)} €"
                          : "-",
                      color: Colors.blueGrey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MiniMetric(
                      label: "L/100",
                      value: truck.litersPer100 > 0
                          ? truck.litersPer100.toStringAsFixed(1)
                          : "-",
                      color: Colors.blueGrey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _MiniBadge(
                text: severityLabel,
                color: severityColor,
              ),
              if (reasons.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  "Erreurs possibles",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                ...reasons.take(2).map((r) => Text("• $r")),
              ],
              if (actions.isNotEmpty) ...[
                const SizedBox(height: 10),
                const Text(
                  "Recommandations",
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                ...actions.take(2).map((a) => Text("• $a")),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
        color: color.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  final String text;
  final Color color;

  const _MiniBadge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withOpacity(0.08),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3)),
        color: color.withOpacity(0.07),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TruckProfitData {
  final String plate;
  final double profit;

  const _TruckProfitData({
    required this.plate,
    required this.profit,
  });
}

class _TruckComputedData {
  final String plate;
  final String model;
  final double revenue;
  final double expenses;
  final double fuelExpenses;
  final double maintenanceExpenses;
  final double fixedCosts;
  final double profit;
  final double km;
  final double fuelLiters;
  final double costPerKm;
  final double litersPer100;
  final int score;
  final AiLossAnalysis analysis;

  const _TruckComputedData({
    required this.plate,
    required this.model,
    required this.revenue,
    required this.expenses,
    required this.fuelExpenses,
    required this.maintenanceExpenses,
    required this.fixedCosts,
    required this.profit,
    required this.km,
    required this.fuelLiters,
    required this.costPerKm,
    required this.litersPer100,
    required this.score,
    required this.analysis,
  });
}

// ── Page hub Finances ─────────────────────────────────────────────────────────

class _FinancesMenuPage extends StatelessWidget {
  const _FinancesMenuPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Finances',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        _MenuTile(
          icon: Icons.receipt_long_outlined,
          title: 'Dépenses',
          subtitle: 'Carburant, entretien, frais divers',
          color: Colors.orange,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManagerExpensesPage())),
        ),
        const SizedBox(height: 14),
        _MenuTile(
          icon: Icons.request_page_outlined,
          title: 'Facturation',
          subtitle: 'Extras manutention, km, tours supplémentaires',
          color: Colors.green,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManagerBillingPage())),
        ),
      ],
    );
  }
}

// ── Page hub Admin & RH ───────────────────────────────────────────────────────

class _AdminMenuPage extends StatelessWidget {
  const _AdminMenuPage();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text('Admin & RH',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        _MenuTile(
          icon: Icons.folder_outlined,
          title: 'Administratif',
          subtitle: 'Documents entreprise, conformité',
          color: Colors.blue,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ManagerAdminPage())),
        ),
        const SizedBox(height: 14),
        _MenuTile(
          icon: Icons.badge_outlined,
          title: 'Recrutement',
          subtitle: 'Candidatures, offres chauffeur',
          color: Colors.purple,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(
                  builder: (_) => const ManagerRecruitmentPage())),
        ),
      ],
    );
  }
}

// ── Tuile de menu ─────────────────────────────────────────────────────────────

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}