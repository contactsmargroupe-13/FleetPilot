import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/design_constants.dart';
import '../utils/page_help.dart';
import '../providers/app_state.dart';
import '../services/manager_ai_service.dart';
import 'manager_admin.dart';
import 'manager_ai_chat.dart';
import 'manager_messages.dart';
import 'manager_ai_report.dart';
import 'manager_assignments.dart';
import 'smart_scan_page.dart';
import 'manager_assets.dart';
import 'manager_billing.dart';
import 'manager_drivers.dart';
import 'manager_client_pricing.dart';
import 'manager_equipment.dart';
import 'manager_expenses.dart';
import 'manager_planning.dart';
import 'manager_recruitment.dart';
import 'manager_settings.dart';
import 'manager_tours.dart';
import 'manager_urssaf.dart';
import 'manager_vehicles.dart';
import 'models/client_pricing.dart';
import 'models/driver.dart';
import 'models/expense.dart';
import 'models/manager_alert.dart';
import 'models/user_access.dart';

class ManagerShell extends ConsumerStatefulWidget {
  final AccessRole role;
  const ManagerShell({super.key, this.role = AccessRole.manager});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int index = 0;

  bool _hasAccess(String page) =>
      rolePages[widget.role]?.contains(page) ?? false;

  @override
  Widget build(BuildContext context) {
    final alertCount = ref.watch(appStateProvider).unreadManagerAlertCount;
    final unreadMsgCount = ref.watch(appStateProvider).unreadManagerMessages;

    final pages = [
      const ManagerDashboardPage(),
      const ManagerPlanningPage(),
      const ManagerTours(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.role == AccessRole.manager
            ? 'FleetPilote Manager'
            : 'FleetPilote ${accessRoleLabel(widget.role)}'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: unreadMsgCount > 0,
              label: Text('$unreadMsgCount'),
              child: const Icon(Icons.chat_outlined),
            ),
            tooltip: 'Messages',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManagerMessagesPage()),
              );
            },
          ),
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
                  Text('FleetPilote',
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
            if (_hasAccess('flotte'))
              _drawerTile(Icons.hub_outlined, 'Flotte', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerAssignmentsPage()));
              }),
            if (_hasAccess('chauffeurs'))
              _drawerTile(Icons.groups_outlined, 'Chauffeurs', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerDriversPage()));
              }),
            if (_hasAccess('camions'))
              _drawerTile(Icons.local_shipping_outlined, 'Camions', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Camions'),
                        actions: [
                          Builder(builder: (ctx) => helpButton(ctx, 'Camions',
                            'Gérez votre parc de véhicules.\n\n'
                            '• Ajoutez vos camions avec immatriculation et modèle\n'
                            '• Suivez assurance et contrôle technique\n'
                            '• Affectez du matériel (transpalette, etc.)\n'
                            '• Consultez les tournées par camion')),
                        ],
                      ),
                      body: const ManagerVehiclesPage(),
                    )));
              }),
            if (_hasAccess('materiel'))
              _drawerTile(Icons.build_outlined, 'Matériel', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerEquipmentPage()));
              }),
            if (_hasAccess('commissionnaires'))
              _drawerTile(Icons.handshake_outlined, 'Commissionnaires', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerClientPricingPage()));
              }),
            const Divider(),
            if (_hasAccess('actifs'))
              _drawerTile(Icons.savings_outlined, 'Actifs', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerAssetsPage()));
              }),
            if (_hasAccess('depenses'))
              _drawerTile(Icons.receipt_long_outlined, 'Dépenses', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Dépenses'),
                        actions: [
                          Builder(builder: (ctx) => helpButton(ctx, 'Dépenses',
                            'Suivez toutes les dépenses de votre flotte.\n\n'
                            '• Carburant, péages, réparations, amendes\n'
                            '• Scan OCR pour saisir une facture en photo\n'
                            '• Filtrez par camion, type ou période')),
                        ],
                      ),
                      body: const ManagerExpensesPage(),
                    )));
              }),
            if (_hasAccess('facturation'))
              _drawerTile(Icons.request_page_outlined, 'Facturation', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Facturation'),
                        actions: [
                          Builder(builder: (ctx) => helpButton(ctx, 'Facturation',
                            'Générez vos factures automatiquement.\n\n'
                            '• Basé sur les tournées saisies par les chauffeurs\n'
                            '• Calcul automatique selon le tarif commissionnaire\n'
                            '• Export PDF pour envoi')),
                        ],
                      ),
                      body: const ManagerBillingPage(),
                    )));
              }),
            if (_hasAccess('urssaf'))
              _drawerTile(Icons.account_balance_outlined, 'URSSAF & Charges', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerUrssafPage()));
              }),
            const Divider(),
            if (_hasAccess('administratif'))
              _drawerTile(Icons.folder_outlined, 'Administratif', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerAdminPage()));
              }),
            if (_hasAccess('recrutement'))
              _drawerTile(Icons.badge_outlined, 'Recrutement', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerRecruitmentPage()));
              }),
            if (_hasAccess('messages'))
              _drawerTile(Icons.chat_outlined, 'Messages${unreadMsgCount > 0 ? ' ($unreadMsgCount)' : ''}', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerMessagesPage()));
              }),
            if (_hasAccess('ia_chat') || _hasAccess('scan') || _hasAccess('rapport_ia'))
              const Divider(),
            if (_hasAccess('ia_chat'))
              _drawerTile(Icons.auto_awesome, 'Assistant IA', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerAiChatPage()));
              }),
            if (_hasAccess('scan'))
              _drawerTile(Icons.document_scanner_outlined, 'Scan intelligent', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SmartScanPage()));
              }),
            if (_hasAccess('rapport_ia'))
              _drawerTile(Icons.analytics_outlined, 'Rapport IA', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerAiReportPage()));
              }),
            if (_hasAccess('parametres'))
              const Divider(),
            if (_hasAccess('parametres'))
              _drawerTile(Icons.settings_outlined, 'Paramètres', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Paramètres'),
                        actions: [
                          Builder(builder: (ctx) => helpButton(ctx, 'Paramètres',
                            'Configurez votre entreprise et vos accès.\n\n'
                            '• Infos entreprise : nom, SIRET, adresse\n'
                            '• Code PIN manager pour protéger l\'accès\n'
                            '• Créez des accès limités (ex: comptable)\n'
                            '• Clé API pour l\'assistant IA')),
                        ],
                      ),
                      body: const ManagerSettingsPage(),
                    )));
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
    'profit', 'sante', 'metrics', 'seuil', 'classement',
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

      // Revenu = somme des tarifs commissionnaire pour chaque tournée du camion
      final appState = ref.read(appStateProvider);
      final truckTours = appState.tours.where((tour) =>
          tour.truckPlate == t.plate &&
          tour.date.year == _selectedMonth.year &&
          tour.date.month == _selectedMonth.month).toList();
      double revenue = 0;
      for (final tour in truckTours) {
        final pricing = appState.getClientPricing(tour.companyName);
        final assign = appState.getAssignment(tour.driverName);
        if (pricing != null) {
          if (pricing.billingMode == BillingMode.auPoint) {
            final pp = assign?.customPricePerPoint ?? pricing.pricePerPoint ?? 0;
            revenue += tour.clientsCount * pp;
          } else {
            revenue += assign?.customDailyRate ?? pricing.dailyRate;
          }
        }
      }

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

      final Color profitC = profitTruck >= 0 ? DC.success : DC.error;
      final severity = _analysisSeverity(analysis);

      cards.add(
        Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: DC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: DC.border),
          ),
          child: Column(
            children: [
              // Header camion
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: profitC.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: profitC.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.local_shipping_rounded, color: profitC, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.plate, style: DC.mono(13, weight: FontWeight.w700, color: DC.textPrimary)),
                          if (t.model.isNotEmpty)
                            Text(t.model, style: DC.body(11, color: DC.textSecondary)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${profitTruck >= 0 ? '+' : ''}${profitTruck.toStringAsFixed(0)} €',
                          style: DC.title(16, color: profitC),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _severityColor(severity).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Score ${analysis.score}',
                            style: DC.mono(10, color: _severityColor(severity)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Données compactes en grille
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _miniStat('CA', '${revenue.toStringAsFixed(0)} €', Icons.payments_outlined, DC.primary),
                        _miniStat('Dépenses', '${expenses.toStringAsFixed(0)} €', Icons.receipt_long_outlined, DC.error),
                        _miniStat('Fixe', '${fixed.toStringAsFixed(0)} €', Icons.home_work_outlined, DC.textSecondary),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _miniStat('Km', '${kmTruckMonth.toStringAsFixed(0)}', Icons.route_rounded, const Color(0xFF0D9488)),
                        _miniStat('Coût/km', kmTruckMonth > 0 ? '${costPerKm.toStringAsFixed(2)} €' : '-', Icons.speed_rounded, const Color(0xFF64748B)),
                        _miniStat('L/100', litersPer100 > 0 ? litersPer100.toStringAsFixed(1) : '-', Icons.local_gas_station_rounded, const Color(0xFFF59E0B)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
      // Revenu mois précédent via tournées réelles
      final prevAppState = ref.read(appStateProvider);
      final prevTours = prevAppState.tours.where((tour) =>
          tour.truckPlate == t.plate &&
          tour.date.year == prevMonth.year &&
          tour.date.month == prevMonth.month).toList();
      for (final tour in prevTours) {
        final pricing = prevAppState.getClientPricing(tour.companyName);
        final assign = prevAppState.getAssignment(tour.driverName);
        if (pricing != null) {
          if (pricing.billingMode == BillingMode.auPoint) {
            final pp = assign?.customPricePerPoint ?? pricing.pricePerPoint ?? 0;
            prevRevenue += tour.clientsCount * pp;
          } else {
            prevRevenue += assign?.customDailyRate ?? pricing.dailyRate;
          }
        }
      }
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

    final toursThisMonth = ref.read(appStateProvider).tours
        .where((t) => t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month)
        .length;

    final profitColor = totalProfit >= 0 ? DC.success : DC.error;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: DC.screenH, vertical: 20),
      children: [
        // ── Header ──────────────────────────────────────────────────────
        Row(
          children: [
            Expanded(child: DC.logo(size: 24)),
            _monthPill(),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showCustomizeDialog,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: DC.surface2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, size: 18, color: DC.textSecondary),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Profit hero ─────────────────────────────────────────────────
        if (_visibleSections.contains('profit')) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: totalProfit >= 0
                    ? [const Color(0xFF059669), const Color(0xFF10B981)]
                    : [const Color(0xFFDC2626), const Color(0xFFEF4444)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      totalProfit >= 0 ? 'Bénéfice du mois' : 'Perte du mois',
                      style: DC.body(13, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            profitTrend >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                            size: 14, color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${profitTrend >= 0 ? '+' : ''}${profitTrend.toStringAsFixed(0)} €',
                            style: DC.mono(11, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${totalProfit >= 0 ? '+' : ''}${totalProfit.toStringAsFixed(0)} €',
                  style: DC.title(34, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _heroKpi('CA', '${totalRevenue.toStringAsFixed(0)} €'),
                    _heroKpi('Coûts', '${totalCosts.toStringAsFixed(0)} €'),
                    _heroKpi('Camions', '${allTrucks.length}'),
                    _heroKpi('Chauffeurs', '${drivers.length}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Santé flotte ────────────────────────────────────────────────
        if (_visibleSections.contains('sante')) ...[
          Row(
            children: [
              _healthPill('Rentables', profitableCount, DC.success, Icons.check_circle_rounded),
              const SizedBox(width: 8),
              _healthPill('À surveiller', warningCount, DC.warning, Icons.warning_amber_rounded),
              const SizedBox(width: 8),
              _healthPill('En perte', lossCount, DC.error, Icons.error_rounded),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Metrics grid ────────────────────────────────────────────────
        if (_visibleSections.contains('metrics')) ...[
          Row(
            children: [
              Expanded(child: _metricTile(
                'Km total',
                totalKmMonth > 0 ? '${totalKmMonth.toStringAsFixed(0)}' : '-',
                'km',
                Icons.route_rounded,
                DC.primary,
              )),
              const SizedBox(width: 10),
              Expanded(child: _metricTile(
                'Tournées',
                '$toursThisMonth',
                'ce mois',
                Icons.local_shipping_rounded,
                const Color(0xFF6366F1),
              )),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _metricTile(
                'Coût / km',
                totalCostPerKm > 0 ? totalCostPerKm.toStringAsFixed(2) : '-',
                '€/km',
                Icons.speed_rounded,
                const Color(0xFF64748B),
              )),
              const SizedBox(width: 10),
              Expanded(child: _metricTile(
                'Carburant',
                totalLitersPer100 > 0 ? totalLitersPer100.toStringAsFixed(1) : '-',
                'L/100km',
                Icons.local_gas_station_rounded,
                const Color(0xFFF59E0B),
              )),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // ── Seuil de rentabilité ────────────────────────────────────────
        if (_visibleSections.contains('seuil')) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: DC.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      seuilAtteint ? Icons.check_circle_rounded : Icons.flag_rounded,
                      color: seuilAtteint ? DC.success : DC.warning,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text('Seuil de rentabilité', style: DC.body(14, weight: FontWeight.w600)),
                    const Spacer(),
                    Text(
                      '${totalCosts > 0 ? (totalRevenue / totalCosts * 100).toStringAsFixed(0) : 0}%',
                      style: DC.title(16, color: seuilAtteint ? DC.success : DC.warning),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: totalCosts > 0 ? (totalRevenue / totalCosts).clamp(0.0, 1.0) : 0.0,
                    minHeight: 8,
                    backgroundColor: DC.surface2,
                    valueColor: AlwaysStoppedAnimation(seuilAtteint ? DC.success : DC.warning),
                  ),
                ),
                const SizedBox(height: 12),
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
          const SizedBox(height: 16),
        ],

        // ── Classement camions ──────────────────────────────────────────
        if (_visibleSections.contains('classement')) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: DC.card,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Classement camions', style: DC.body(14, weight: FontWeight.w600)),
                const SizedBox(height: 12),
                if (sortedByProfit.isEmpty)
                  Text('Aucun camion', style: DC.body(13, color: DC.textSecondary)),
                ...sortedByProfit.map((t) {
                  final barRatio = (t.profit / maxAbsProfit).clamp(-1.0, 1.0);
                  final isPositive = t.profit >= 0;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80,
                          child: Text(t.plate, style: DC.mono(11)),
                        ),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              children: [
                                Container(height: 20, color: DC.surface2),
                                FractionallySizedBox(
                                  widthFactor: barRatio.abs(),
                                  child: Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: isPositive
                                          ? DC.success.withValues(alpha: 0.5)
                                          : DC.error.withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: Text(
                            '${t.profit >= 0 ? '+' : ''}${t.profit.toStringAsFixed(0)} €',
                            textAlign: TextAlign.right,
                            style: DC.mono(11, color: isPositive ? DC.success : DC.error),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Cartes détail par camion ────────────────────────────────────
        if (_visibleSections.contains('cartes')) ...[
          Text('Détail par camion', style: DC.body(14, weight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...cards,
        ],

        // ── Suggestions ─────────────────────────────────────────────────
        _buildSuggestions(
          computedTrucks: computedTrucks,
          totalProfit: totalProfit,
          totalKmMonth: totalKmMonth,
          totalLitersPer100: totalLitersPer100,
          lossCount: lossCount,
          drivers: drivers,
        ),
        const SizedBox(height: 20),
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
        icon: Icons.build_outlined,
        title: '$lossCount camion${lossCount > 1 ? 's' : ''} en perte',
        subtitle: 'Vérifiez les dépenses et revenus de ces camions.',
        color: Colors.red,
      ));
    }

    // Consommation élevée
    if (totalLitersPer100 > 18) {
      suggestions.add(_Suggestion(
        icon: Icons.local_gas_station_outlined,
        title: 'Consommation élevée (${totalLitersPer100.toStringAsFixed(1)} L/100)',
        subtitle: 'Au-dessus de 18 L/100 km. Vérifiez l\'état des véhicules.',
        color: Colors.orange,
      ));
    }

    // Peu de km
    if (totalKmMonth > 0 && totalKmMonth < 1000 && computedTrucks.isNotEmpty) {
      suggestions.add(_Suggestion(
        icon: Icons.bar_chart_rounded,
        title: 'Activité faible ce mois',
        subtitle: 'Seulement ${totalKmMonth.toStringAsFixed(0)} km. Optimisez les plannings.',
        color: Colors.blue,
      ));
    }

    // Tous rentables
    if (lossCount == 0 && computedTrucks.isNotEmpty) {
      suggestions.add(_Suggestion(
        icon: Icons.track_changes_rounded,
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
          icon: Icons.savings_outlined,
          title: 'Marge de ${marge.toStringAsFixed(0)}%',
          subtitle: 'Excellente rentabilité. Pensez à investir dans la flotte.',
          color: Colors.green,
        ));
      }
    }

    // Manque chauffeurs
    if (drivers.length < computedTrucks.length) {
      suggestions.add(_Suggestion(
        icon: Icons.person_outline,
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
                      Icon(s.icon, size: 20, color: s.color),
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
                                    fontSize: 12, color: DC.textSecondary)),
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

  Widget _monthPill() {
    return Container(
      decoration: BoxDecoration(
        color: DC.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DC.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
            }),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_left_rounded, size: 18, color: DC.textSecondary),
            ),
          ),
          Text(
            '${['Jan','Fév','Mar','Avr','Mai','Jun','Jul','Aoû','Sep','Oct','Nov','Déc'][_selectedMonth.month - 1]} ${_selectedMonth.year}',
            style: DC.mono(12),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
            }),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.chevron_right_rounded, size: 18, color: DC.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroKpi(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: DC.mono(12, color: Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: DC.body(10, color: Colors.white.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _healthPill(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text('$count', style: DC.title(18, color: color)),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: DC.body(10, color: color),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value, String unit, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DC.card,
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DC.body(11, color: DC.textSecondary)),
                const SizedBox(height: 2),
                RichText(
                  text: TextSpan(children: [
                    TextSpan(text: value, style: DC.title(18, color: DC.textPrimary)),
                    TextSpan(text: ' $unit', style: DC.body(11, color: DC.textTertiary)),
                  ]),
                ),
              ],
            ),
          ),
        ],
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
              style: const TextStyle(fontSize: 10, color: DC.textSecondary)),
        ],
      ),
    );
  }

  Widget _kpiMini(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: DC.mono(12, color: color)),
          Text(label, style: DC.body(10, color: DC.textSecondary)),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: DC.mono(11, weight: FontWeight.w600, color: DC.textPrimary)),
                Text(label, style: DC.body(9, color: DC.textTertiary)),
              ],
            ),
          ),
        ],
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
  final IconData icon;
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
              color: DC.textSecondary,
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
                        style: TextStyle(color: DC.textSecondary, fontSize: 16),
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
                style: TextStyle(fontSize: 11, color: DC.textSecondary),
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
                            fontSize: 13, color: DC.textSecondary)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: DC.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}