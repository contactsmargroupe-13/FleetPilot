import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../services/manager_ai_service.dart';
import 'manager_admin.dart';
import 'manager_assignments.dart';
import 'manager_assets.dart';
import 'manager_billing.dart';
import 'manager_drivers.dart';
import 'manager_equipment.dart';
import 'manager_expenses.dart';
import 'manager_planning.dart';
import 'manager_recruitment.dart';
import 'manager_settings.dart';
import 'manager_tours.dart';
import 'manager_urssaf.dart';
import 'manager_vehicles.dart';
import 'models/driver.dart';
import 'models/expense.dart';
import 'models/manager_alert.dart';

class ManagerShell extends ConsumerStatefulWidget {
  const ManagerShell({super.key});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final alertCount = ref.watch(appStateProvider).unreadManagerAlertCount;

    final pages = [
      const ManagerDashboardPage(),
      const ManagerPlanningPage(),
      const ManagerTours(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("FleetPilot Manager"),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: alertCount > 0,
              label: Text('$alertCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Alertes',
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => _ManagerAlertsSheet(ref: ref),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.local_shipping,
                      size: 36,
                      color: Theme.of(context).colorScheme.onPrimaryContainer),
                  const SizedBox(height: 8),
                  Text('FleetPilot',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onPrimaryContainer)),
                  Text('Gestion de flotte',
                      style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7))),
                ],
              ),
            ),
            _drawerTile(Icons.assignment_ind_outlined, 'Affectations', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerAssignmentsPage()));
            }),
            _drawerTile(Icons.groups_outlined, 'Chauffeurs', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Chauffeurs')),
                    body: const ManagerDriversPage(),
                  )));
            }),
            _drawerTile(Icons.local_shipping_outlined, 'Camions', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Camions')),
                    body: const ManagerVehiclesPage(),
                  )));
            }),
            _drawerTile(Icons.build_outlined, 'Matériel', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerEquipmentPage()));
            }),
            const Divider(),
            _drawerTile(Icons.savings_outlined, 'Actifs', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerAssetsPage()));
            }),
            _drawerTile(Icons.receipt_long_outlined, 'Dépenses', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerExpensesPage()));
            }),
            _drawerTile(Icons.request_page_outlined, 'Facturation', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerBillingPage()));
            }),
            _drawerTile(Icons.account_balance_outlined, 'URSSAF & Charges', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerUrssafPage()));
            }),
            const Divider(),
            _drawerTile(Icons.folder_outlined, 'Administratif', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerAdminPage()));
            }),
            _drawerTile(Icons.badge_outlined, 'Recrutement', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerRecruitmentPage()));
            }),
            const Divider(),
            _drawerTile(Icons.settings_outlined, 'Paramètres', () {
              Navigator.pop(context);
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ManagerSettingsPage()));
            }),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Retour accueil',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(context); // fermer drawer
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          NavigationDestination(
            icon: Badge(
              isLabelVisible: alertCount > 0,
              label: Text('$alertCount'),
              child: const Icon(Icons.analytics_outlined),
            ),
            label: "Dashboard",
          ),
          const NavigationDestination(
            icon: Icon(Icons.today_outlined),
            label: "Suivi",
          ),
          const NavigationDestination(
            icon: Icon(Icons.route_outlined),
            label: "Tournées",
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: onTap,
    );
  }
}

class ManagerDashboardPage extends ConsumerStatefulWidget {
  const ManagerDashboardPage({super.key});

  @override
  ConsumerState<ManagerDashboardPage> createState() => _ManagerDashboardPageState();
}

class _ManagerDashboardPageState extends ConsumerState<ManagerDashboardPage> {
  String? _selectedPlate;
  late DateTime _selectedMonth;

  final Set<String> _visibleSections = {
    'profit', 'seuil', 'sante', 'classement', 'metrics', 'cartes',
  };

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
    return ref.read(appStateProvider).expenses
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
    return ref.read(appStateProvider).tours
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.kmTotal);
  }

  double _sumKmForTruckInMonth(String plate, DateTime month) {
    return ref.read(appStateProvider).tours
        .where((t) => t.truckPlate == plate)
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .fold(0.0, (sum, t) => sum + t.kmTotal);
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
    final allTrucks = ref.read(appStateProvider).trucks;
    final trucks = allTrucks;
    final List<Driver> drivers = ref.read(appStateProvider).drivers;

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

    // Seuil de rentabilité
    final totalCosts = totalExpenses + totalFixed + totalSalaries;
    final seuilAtteint = totalRevenue >= totalCosts;

    // Prev month trends
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    double prevRevenue = 0;
    double prevExpenses = 0;
    double prevFixed = 0;
    for (final t in allTrucks) {
      final days = _parseDays(_daysCtrlFor(t.plate, prevMonth).text);
      prevRevenue += (t.dailyRate as num).toDouble() * days;
      prevExpenses += _sumExpensesForTruckInMonth(t.plate, prevMonth);
      prevFixed += _truckFixedMonthlyCost(t);
    }
    final prevCosts = prevExpenses + prevFixed + totalSalaries;
    final prevProfit = prevRevenue - prevCosts;
    final profitTrend = totalProfit - prevProfit;

    // Sorted trucks for ranking
    final sortedByProfit = [...computedTrucks]
      ..sort((a, b) => b.profit.compareTo(a.profit));
    final maxAbsProfit = sortedByProfit.isEmpty
        ? 1.0
        : sortedByProfit.map((t) => t.profit.abs()).reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── 1. Header + month selector ──────────────────────────────────
        Row(
          children: [
            const Text("Dashboard",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.tune, size: 20),
              tooltip: 'Personnaliser',
              onPressed: _showCustomizeDialog,
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.chevron_left, size: 20),
              onPressed: () => setState(() {
                _selectedMonth = DateTime(
                    _selectedMonth.year, _selectedMonth.month - 1);
              }),
            ),
            Text(
              '${['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'][_selectedMonth.month - 1]} ${_selectedMonth.year}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right, size: 20),
              onPressed: () => setState(() {
                _selectedMonth = DateTime(
                    _selectedMonth.year, _selectedMonth.month + 1);
              }),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── 2. Big profit/loss card with trend + emoji ─────────────────
        if (_visibleSections.contains('profit')) Card(
          color: totalProfit >= 0
              ? Colors.green.withValues(alpha: 0.07)
              : Colors.red.withValues(alpha: 0.07),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      totalProfit >= 0
                          ? (totalProfit > 5000 ? '🚀' : '✅')
                          : (totalProfit < -3000 ? '🔴' : '⚠️'),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${totalProfit >= 0 ? '+' : ''}${totalProfit.toStringAsFixed(0)} €',
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.w900,
                              color: totalProfit >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                          Text(
                            totalProfit >= 0
                                ? (totalProfit > 5000 ? 'Excellent mois !' : 'Mois positif')
                                : (totalProfit < -3000 ? 'Attention, pertes élevées' : 'Mois déficitaire'),
                            style: TextStyle(
                              fontSize: 13,
                              color: totalProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Trend badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: profitTrend >= 0
                            ? Colors.green.withValues(alpha: 0.12)
                            : Colors.red.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            profitTrend >= 0 ? Icons.trending_up : Icons.trending_down,
                            size: 14,
                            color: profitTrend >= 0 ? Colors.green : Colors.red,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${profitTrend >= 0 ? '+' : ''}${profitTrend.toStringAsFixed(0)} €',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: profitTrend >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _kpiMini('CA', '${totalRevenue.toStringAsFixed(0)} €', Colors.blue),
                    _kpiMini('Coûts', '${totalCosts.toStringAsFixed(0)} €', Colors.orange),
                    _kpiMini('Camions', '${allTrucks.length}', Colors.teal),
                    _kpiMini('Chauffeurs', '${drivers.length}', Colors.indigo),
                  ],
                ),

                // Best & worst truck
                if (bestTruck != null && computedTrucks.length > 1) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Text('🏆', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  '${bestTruck!.plate} +${bestTruck!.profit.toStringAsFixed(0)} €',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (worstTruck != null && worstTruck!.profit < 0)
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                const Text('📉', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${worstTruck!.plate} ${worstTruck!.profit.toStringAsFixed(0)} €',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.red),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        if (_visibleSections.contains('profit')) const SizedBox(height: 10),

        // ── 3. Seuil de rentabilité (compact) ───────────────────────────
        if (_visibleSections.contains('seuil')) Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      seuilAtteint ? Icons.check_circle : Icons.flag_outlined,
                      color: seuilAtteint ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      seuilAtteint
                          ? 'Seuil atteint'
                          : '${(totalCosts - totalRevenue).toStringAsFixed(0)} € restants',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: seuilAtteint ? Colors.green : Colors.orange,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${totalCosts > 0 ? (totalRevenue / totalCosts * 100).toStringAsFixed(0) : 0}%',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: seuilAtteint ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalCosts > 0
                        ? (totalRevenue / totalCosts).clamp(0.0, 1.0)
                        : 0.0,
                    minHeight: 10,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: AlwaysStoppedAnimation(
                      seuilAtteint ? Colors.green : Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _costLine('Fixes', totalFixed),
                    const SizedBox(width: 12),
                    _costLine('Dépenses', totalExpenses),
                    const SizedBox(width: 12),
                    _costLine('Salaires', totalSalaries),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (_visibleSections.contains('seuil')) const SizedBox(height: 10),

        // ── 4. Health row: 3 chips ──────────────────────────────────────
        if (_visibleSections.contains('sante')) Row(
          children: [
            _healthChip('Rentables', profitableCount, Colors.green, '✅'),
            const SizedBox(width: 8),
            _healthChip('À surveiller', warningCount, Colors.orange, '⚠️'),
            const SizedBox(width: 8),
            _healthChip('En perte', lossCount, Colors.red, '🔴'),
          ],
        ),
        if (_visibleSections.contains('sante')) const SizedBox(height: 10),

        // ── 5. Classement camions (compact list with profit bars) ───────
        if (_visibleSections.contains('classement')) Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Classement camions',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                if (sortedByProfit.isEmpty)
                  const Text('Aucun camion',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ...sortedByProfit.map((t) {
                  final barRatio = (t.profit / maxAbsProfit).clamp(-1.0, 1.0);
                  final isPositive = t.profit >= 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(t.plate,
                              style: const TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: barRatio.abs(),
                                child: Container(
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: isPositive
                                        ? Colors.green.withValues(alpha: 0.6)
                                        : Colors.red.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 70,
                          child: Text(
                            '${t.profit >= 0 ? '+' : ''}${t.profit.toStringAsFixed(0)} €',
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        if (_visibleSections.contains('classement')) const SizedBox(height: 10),

        // ── 6. Coût/km + Consommation (side by side) ────────────────────
        if (_visibleSections.contains('metrics')) Row(
          children: [
            Expanded(
              child: _metricCard(
                'Coût / km',
                totalCostPerKm > 0
                    ? '${totalCostPerKm.toStringAsFixed(2)} €'
                    : '-',
                Icons.speed_outlined,
                Colors.blueGrey,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _metricCard(
                'Consommation',
                totalLitersPer100 > 0
                    ? '${totalLitersPer100.toStringAsFixed(1)} L/100'
                    : '-',
                Icons.local_gas_station_outlined,
                Colors.deepOrange,
              ),
            ),
          ],
        ),

        // ── 7. Km + tournées du mois ──────────────────────────────────
        if (_visibleSections.contains('metrics')) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _metricCard(
                  'Km total',
                  totalKmMonth > 0
                      ? '${totalKmMonth.toStringAsFixed(0)} km'
                      : '-',
                  Icons.route_outlined,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metricCard(
                  'Tournées',
                  '${ref.read(appStateProvider).tours.where((t) => t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month).length}',
                  Icons.local_shipping_outlined,
                  Colors.indigo,
                ),
              ),
            ],
          ),
        ],

        // ── 8. Cartes détail par camion ─────────────────────────────────
        if (_visibleSections.contains('cartes')) ...[
          const SizedBox(height: 10),
          const Text('Détail par camion',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...cards,
        ],

        // ── 9. Suggestions d'amélioration ──────────────────────────────
        const SizedBox(height: 16),
        _buildSuggestions(
          computedTrucks: computedTrucks,
          totalProfit: totalProfit,
          totalKmMonth: totalKmMonth,
          totalLitersPer100: totalLitersPer100,
          lossCount: lossCount,
          drivers: drivers,
        ),
      ],
    );
  }

  Widget _buildSuggestions({
    required List<_TruckComputedData> computedTrucks,
    required double totalProfit,
    required double totalKmMonth,
    required double totalLitersPer100,
    required int lossCount,
    required List<Driver> drivers,
  }) {
    final suggestions = <_Suggestion>[];

    // Camions en perte
    if (lossCount > 0) {
      suggestions.add(_Suggestion(
        icon: '🔧',
        title: '$lossCount camion${lossCount > 1 ? 's' : ''} en perte',
        subtitle: 'Vérifiez les dépenses et revenus de ces camions.',
        color: Colors.red,
      ));
    }

    // Consommation élevée
    if (totalLitersPer100 > 18) {
      suggestions.add(_Suggestion(
        icon: '⛽',
        title: 'Consommation élevée (${totalLitersPer100.toStringAsFixed(1)} L/100)',
        subtitle: 'Au-dessus de 18 L/100 km. Vérifiez l\'état des véhicules.',
        color: Colors.orange,
      ));
    }

    // Peu de km
    if (totalKmMonth > 0 && totalKmMonth < 1000 && computedTrucks.isNotEmpty) {
      suggestions.add(_Suggestion(
        icon: '📊',
        title: 'Activité faible ce mois',
        subtitle: 'Seulement ${totalKmMonth.toStringAsFixed(0)} km. Optimisez les plannings.',
        color: Colors.blue,
      ));
    }

    // Tous rentables
    if (lossCount == 0 && computedTrucks.isNotEmpty) {
      suggestions.add(_Suggestion(
        icon: '🎯',
        title: 'Tous les camions sont rentables !',
        subtitle: 'Continuez sur cette lancée.',
        color: Colors.green,
      ));
    }

    // Profit en hausse
    if (totalProfit > 0 && computedTrucks.isNotEmpty) {
      final marge = computedTrucks.isEmpty ? 0.0 :
          (totalProfit / computedTrucks.fold(0.0, (s, t) => s + t.revenue).clamp(1, double.infinity) * 100);
      if (marge > 20) {
        suggestions.add(_Suggestion(
          icon: '💰',
          title: 'Marge de ${marge.toStringAsFixed(0)}%',
          subtitle: 'Excellente rentabilité. Pensez à investir dans la flotte.',
          color: Colors.green,
        ));
      }
    }

    // Manque chauffeurs
    if (drivers.length < computedTrucks.length) {
      suggestions.add(_Suggestion(
        icon: '👤',
        title: 'Plus de camions que de chauffeurs',
        subtitle: '${computedTrucks.length} camions pour ${drivers.length} chauffeurs. Recrutez !',
        color: Colors.purple,
      ));
    }

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text('💡', style: TextStyle(fontSize: 18)),
                SizedBox(width: 8),
                Text('Suggestions',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            ...suggestions.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(s.title,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: s.color)),
                            Text(s.subtitle,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  void _showCustomizeDialog() {
    final sections = {
      'profit': 'Profit / Perte global',
      'seuil': 'Seuil de rentabilité',
      'sante': 'Santé de la flotte',
      'classement': 'Classement camions',
      'metrics': 'Coût/km & Consommation',
      'cartes': 'Cartes détail camions',
    };

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.tune, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Personnaliser',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
              TextButton(
                onPressed: () {
                  setDialogState(() {});
                  setState(() {
                    _visibleSections.addAll(sections.keys);
                  });
                },
                child: const Text('Tout afficher', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: sections.entries.map((e) {
              return SwitchListTile(
                dense: true,
                title: Text(e.value, style: const TextStyle(fontSize: 14)),
                value: _visibleSections.contains(e.key),
                onChanged: (val) {
                  setDialogState(() {});
                  setState(() {
                    if (val) {
                      _visibleSections.add(e.key);
                    } else {
                      _visibleSections.remove(e.key);
                    }
                  });
                },
              );
            }).toList(),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper widgets ──────────────────────────────────────────────────────

  Widget _kpiMini(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _healthChip(String label, int count, Color color, String emoji) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 4),
                Text('$count',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            Text(label,
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8))),
          ],
        ),
      ),
    );
  }

  Widget _costLine(String label, double amount) {
    return Expanded(
      child: Column(
        children: [
          Text('${amount.toStringAsFixed(0)} €',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
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

class _Suggestion {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  const _Suggestion({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });
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

// ── Sheet alertes manager ──────────────────────────────────────────────────────

class _ManagerAlertsSheet extends StatelessWidget {
  final WidgetRef ref;

  const _ManagerAlertsSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(appStateProvider).managerAlerts
      ..sort((a, b) => b.date.compareTo(a.date));

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.notifications_active, color: Colors.orange),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Alertes',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (alerts.any((a) => !a.read))
                  TextButton(
                    onPressed: () {
                      for (final a in alerts.where((a) => !a.read)) {
                        ref.read(appStateProvider).markManagerAlertRead(a.id);
                      }
                    },
                    child: const Text('Tout marquer lu'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: alerts.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Aucune alerte',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                : ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: alerts.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final alert = alerts[i];
                      return _ManagerAlertTile(alert: alert, ref: ref);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ManagerAlertTile extends StatelessWidget {
  final ManagerAlert alert;
  final WidgetRef ref;

  const _ManagerAlertTile({required this.alert, required this.ref});

  @override
  Widget build(BuildContext context) {
    final isUnread = !alert.read;
    final color = alert.type == ManagerAlertType.truckChange
        ? Colors.orange
        : alert.type == ManagerAlertType.documentExpire
            ? Colors.red
            : Colors.blue;
    final icon = alert.type == ManagerAlertType.truckChange
        ? Icons.swap_horiz
        : alert.type == ManagerAlertType.documentExpire
            ? Icons.warning_amber_rounded
            : Icons.info_outline;

    final timeAgo = _formatTimeAgo(alert.date);

    return Container(
      color: isUnread ? color.withOpacity(0.04) : null,
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                alert.title,
                style: TextStyle(
                  fontWeight: isUnread ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  alert.message!,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                timeAgo,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
        onTap: () {
          if (isUnread) {
            ref.read(appStateProvider).markManagerAlertRead(alert.id);
          }
        },
        trailing: IconButton(
          icon: const Icon(Icons.close, size: 18),
          onPressed: () {
            ref.read(appStateProvider).deleteManagerAlert(alert.id);
          },
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "Il y a ${diff.inMinutes} min";
    if (diff.inHours < 24) return "Il y a ${diff.inHours}h";
    if (diff.inDays < 7) return "Il y a ${diff.inDays}j";
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
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