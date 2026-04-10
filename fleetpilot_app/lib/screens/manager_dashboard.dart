import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/design_constants.dart';
import '../utils/shared_widgets.dart';
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
import 'manager_alerts.dart';
import 'manager_settings.dart';
import 'manager_tours.dart';
import 'manager_urssaf.dart';
import 'manager_vehicles.dart';
import 'models/client_pricing.dart';
import 'models/driver.dart';
import 'models/expense.dart';
import 'models/tour.dart';
import 'models/user_access.dart';

class ManagerShell extends ConsumerStatefulWidget {
  final AccessRole role;
  const ManagerShell({super.key, this.role = AccessRole.manager});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell> {
  int index = 0;

  /// Controller persistant pour le drawer — conserve la position de scroll
  /// entre les ouvertures successives du menu latéral.
  final ScrollController _drawerScrollCtrl = ScrollController();

  @override
  void dispose() {
    _drawerScrollCtrl.dispose();
    super.dispose();
  }

  bool _hasAccess(String page) =>
      rolePages[widget.role]?.contains(page) ?? false;

  @override
  Widget build(BuildContext context) {
    final alertCount = ref.watch(appStateProvider).pendingManagerAlertCount;
    final unreadMsgCount = ref.watch(appStateProvider).unreadManagerMessages;

    final pages = [
      const ManagerDashboardPage(),
      const ManagerPlanningPage(),
      const ManagerTours(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: DC.logo(size: 20),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ManagerAlertsPage()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          controller: _drawerScrollCtrl,
          padding: EdgeInsets.zero,
          children: [
            // ── Header épuré ──
            Container(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [DC.primary, DC.primaryDark],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DC.logo(size: 26, light: true),
                  const SizedBox(height: 4),
                  Text(
                    widget.role == AccessRole.manager
                        ? 'Manager'
                        : accessRoleLabel(widget.role),
                    style: DC.body(12, color: Colors.white.withValues(alpha: 0.7)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── FLOTTE ──
            _drawerSection('FLOTTE'),
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

            // ── FINANCES ──
            _drawerSection('FINANCES'),
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

            // ── GESTION ──
            _drawerSection('GESTION'),
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
              _drawerTile(Icons.chat_outlined, 'Messages', () {
                Navigator.pop(context);
                Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ManagerMessagesPage()));
              }, badge: unreadMsgCount),

            // ── INTELLIGENCE ──
            if (_hasAccess('ia_chat') || _hasAccess('scan') || _hasAccess('rapport_ia'))
              _drawerSection('INTELLIGENCE'),
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

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 4),

            // ── Paramètres + déconnexion ──
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
            ListTile(
              leading: const Icon(Icons.logout, color: DC.error, size: 20),
              title: Text('Retour accueil',
                  style: DC.body(14, color: DC.error, weight: FontWeight.w500)),
              dense: true,
              visualDensity: VisualDensity.compact,
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            const SizedBox(height: 16),
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

  Widget _drawerSection(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label,
        style: DC.mono(10, color: DC.textTertiary, weight: FontWeight.w600),
      ),
    );
  }

  Widget _drawerTile(IconData icon, String title, VoidCallback onTap, {int badge = 0}) {
    return ListTile(
      leading: Icon(icon, size: 20),
      title: Text(title, style: DC.body(14)),
      trailing: badge > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: DC.primary,
                borderRadius: BorderRadius.circular(DC.rBadge),
              ),
              child: Text('$badge',
                  style: DC.mono(11, color: Colors.white, weight: FontWeight.w600)),
            )
          : null,
      dense: true,
      visualDensity: VisualDensity.compact,
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
  late DateTime _selectedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
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
      // Assurance mensuelle — s'ajoute quel que soit le mode d'ownership
      final insurance =
          (t.insuranceMonthly as num?)?.toDouble() ?? 0.0;

      final ownership = t.ownershipType.toString().toLowerCase();

      if (ownership.contains("location") ||
          ownership.contains("leasing") ||
          ownership.contains("lease")) {
        final rent = (t.rentMonthly as num?)?.toDouble() ?? 0.0;
        return rent + insurance;
      }

      final purchase = (t.purchasePrice as num?)?.toDouble() ?? 0.0;
      final months = (t.amortMonths as num?)?.toDouble() ?? 0.0;
      final amort = months > 0 ? purchase / months : 0.0;
      return amort + insurance;
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

  @override
  Widget build(BuildContext context) {
    // Watch pour que le dashboard se rafraîchisse automatiquement quand
    // une tournée est ajoutée/modifiée (sinon il fallait changer d'onglet).
    final appState = ref.watch(appStateProvider);
    final allTrucks = appState.trucks;
    final trucks = allTrucks;
    final List<Driver> drivers = appState.drivers;

    final double totalSalaries =
        drivers.fold<double>(0.0, (sum, d) => sum + d.totalSalary);

    final double totalKmMonth = _sumKmForMonth(_selectedMonth);

    final double salarySharePerTruck =
        allTrucks.isEmpty ? 0.0 : totalSalaries / allTrucks.length;

    double totalRevenue = 0;
    double totalExpenses = 0;
    double totalFixed = 0;

    final List<_TruckComputedData> computedTrucks = [];

    for (final t in trucks) {
      // Revenu = somme des tarifs commissionnaire pour chaque tournée du camion
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
    }

    // Classement camions par profit (pour section ③)
    final sortedByProfit = [...computedTrucks]
      ..sort((a, b) => b.profit.compareTo(a.profit));

    final toursThisMonth = appState.tours
        .where((t) => t.date.year == _selectedMonth.year && t.date.month == _selectedMonth.month)
        .length;

    // ─── Nouvelles métriques pour le layout refondé ─────────────────────

    final now = DateTime.now();
    final isCurrentMonth =
        now.year == _selectedMonth.year && now.month == _selectedMonth.month;

    // Nombre de jours dans le mois sélectionné
    final daysInMonth =
        DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0).day;
    // Nombre de jours écoulés (cap à daysInMonth si on regarde un mois passé)
    final daysElapsed = isCurrentMonth ? now.day : daysInMonth;
    final monthRatio =
        daysInMonth > 0 ? (daysElapsed / daysInMonth).clamp(0.0, 1.0) : 0.0;

    // Coûts fixes au prorata temporis : ce qu'on « devrait » avoir dépensé
    // en fixes à ce stade du mois. C'est la référence pour juger si on est
    // en retard ou pas — bien plus parlant que comparer à un mois complet.
    final totalFixedProrata = (totalFixed + totalSalaries) * monthRatio;
    final profitProrata = totalRevenue - totalExpenses - totalFixedProrata;

    // Détection tournées sans tarif configuré
    final allToursThisMonth = appState.tours
        .where((t) =>
            t.date.year == _selectedMonth.year &&
            t.date.month == _selectedMonth.month)
        .toList();
    final toursWithoutPricing = allToursThisMonth.where((t) {
      if (t.companyName == null || t.companyName!.trim().isEmpty) {
        return true; // pas de commissionnaire → pas facturable
      }
      return appState.getClientPricing(t.companyName) == null;
    }).toList();

    // ── Aujourd'hui / hier / semaine ─────────────────────────────────────
    double todayRevenue = 0;
    int todayToursCount = 0;
    double yesterdayRevenue = 0;
    double weekRevenue = 0;

    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekStart = today.subtract(const Duration(days: 6)); // 7 derniers jours

    double tourRevenue(Tour tour) {
      final pricing = appState.getClientPricing(tour.companyName);
      if (pricing == null) return 0;
      final assign = appState.getAssignment(tour.driverName);
      if (pricing.billingMode == BillingMode.auPoint) {
        final pp = assign?.customPricePerPoint ?? pricing.pricePerPoint ?? 0;
        return tour.clientsCount * pp;
      }
      return assign?.customDailyRate ?? pricing.dailyRate;
    }

    for (final tour in appState.tours) {
      final d = DateTime(tour.date.year, tour.date.month, tour.date.day);
      if (d == today) {
        todayRevenue += tourRevenue(tour);
        todayToursCount++;
      } else if (d == yesterday) {
        yesterdayRevenue += tourRevenue(tour);
      }
      if (!d.isBefore(weekStart) && !d.isAfter(today)) {
        weekRevenue += tourRevenue(tour);
      }
    }

    // Coût fixe journalier pour calculer le profit du jour
    final dailyFixedCost =
        daysInMonth > 0 ? (totalFixed + totalSalaries) / daysInMonth : 0.0;
    // Approximation dépenses du jour (fuel/maintenance enregistrés today)
    final todayExpenses = appState.expenses
        .where((e) =>
            e.date.year == today.year &&
            e.date.month == today.month &&
            e.date.day == today.day)
        .fold<double>(0.0, (s, e) => s + e.amount);
    final todayProfit = todayRevenue - dailyFixedCost - todayExpenses;

    // ── CA par chauffeur sur le mois (pour classement) ───────────────────
    final Map<String, double> revenueByDriver = {};
    final Map<String, int> toursByDriver = {};
    for (final tour in allToursThisMonth) {
      final rev = tourRevenue(tour);
      revenueByDriver[tour.driverName] =
          (revenueByDriver[tour.driverName] ?? 0) + rev;
      toursByDriver[tour.driverName] =
          (toursByDriver[tour.driverName] ?? 0) + 1;
    }
    final topDrivers = revenueByDriver.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // ── Décomposition coûts fixes pour section ⑥ ─────────────────────────
    double totalInsurance = 0;
    double totalOwnership = 0; // amort + loyers
    for (final t in allTrucks) {
      totalInsurance += (t.insuranceMonthly ?? 0);
      totalOwnership += (t.ownershipMonthlyCost ?? 0);
    }
    final totalFixedAll = totalSalaries + totalOwnership + totalInsurance;

    // ── Alertes expiration (section ⑤) ───────────────────────────────────
    final trucksInsuranceWarn = allTrucks
        .where((t) => t.insuranceStatus >= 2) // <30j ou expiré
        .toList();
    final trucksCtWarn = allTrucks
        .where((t) => t.ctStatus >= 3) // <1 semaine ou expiré
        .toList();

    final unreadMessages = appState.unreadManagerMessages;

    if (allTrucks.isEmpty) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: DC.screenH, vertical: 20),
        children: [
          _monthPill(),
          const DCEmptyState(
            icon: Icons.local_shipping_outlined,
            title: 'Aucun camion enregistré',
            subtitle: 'Ajoute ton premier camion pour voir le dashboard.',
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: DC.screenH, vertical: 20),
      children: [
        // ── Sélecteur de mois ────────────────────────────────────────────
        _monthPill(),
        const SizedBox(height: 20),

        // ═══════════════════════════════════════════════════════════════
        // ①  AUJOURD'HUI
        // ═══════════════════════════════════════════════════════════════
        if (isCurrentMonth) ...[
          _sectionTodayCard(
            todayRevenue: todayRevenue,
            todayProfit: todayProfit,
            todayToursCount: todayToursCount,
            yesterdayRevenue: yesterdayRevenue,
            weekRevenue: weekRevenue,
          ),
          const SizedBox(height: 16),
        ],

        // ═══════════════════════════════════════════════════════════════
        // ②  CE MOIS — vue prorata (honnête, sans projection)
        // ═══════════════════════════════════════════════════════════════
        _sectionMonthCard(
          totalRevenue: totalRevenue,
          totalExpenses: totalExpenses,
          totalFixedProrata: totalFixedProrata,
          profitProrata: profitProrata,
          monthRatio: monthRatio,
          daysElapsed: daysElapsed,
          daysInMonth: daysInMonth,
          toursCount: toursThisMonth,
          totalKm: totalKmMonth,
        ),
        const SizedBox(height: 16),

        // ═══════════════════════════════════════════════════════════════
        // ③  TES CAMIONS (classement par profit)
        // ═══════════════════════════════════════════════════════════════
        if (computedTrucks.isNotEmpty) ...[
          _sectionTrucksCard(
            trucks: sortedByProfit,
            toursWithoutPricing: toursWithoutPricing,
          ),
          const SizedBox(height: 16),
        ],

        // ═══════════════════════════════════════════════════════════════
        // ④  TES CHAUFFEURS (top performeurs)
        // ═══════════════════════════════════════════════════════════════
        if (topDrivers.isNotEmpty) ...[
          _sectionDriversCard(
            topDrivers: topDrivers,
            toursByDriver: toursByDriver,
          ),
          const SizedBox(height: 16),
        ],

        // ═══════════════════════════════════════════════════════════════
        // ⑤  ACTIONS À FAIRE
        // ═══════════════════════════════════════════════════════════════
        _sectionActionsCard(
          toursWithoutPricing: toursWithoutPricing,
          trucksInsuranceWarn: trucksInsuranceWarn,
          trucksCtWarn: trucksCtWarn,
          unreadMessages: unreadMessages,
        ),
        const SizedBox(height: 16),

        // ═══════════════════════════════════════════════════════════════
        // ⑥  COÛTS FIXES DU MOIS (transparence)
        // ═══════════════════════════════════════════════════════════════
        _sectionFixedCostsCard(
          totalSalaries: totalSalaries,
          totalOwnership: totalOwnership,
          totalInsurance: totalInsurance,
          totalFixedAll: totalFixedAll,
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════
  //  SECTIONS DU DASHBOARD REFONDÉ
  // ══════════════════════════════════════════════════════════════════════

  Widget _sectionTodayCard({
    required double todayRevenue,
    required double todayProfit,
    required int todayToursCount,
    required double yesterdayRevenue,
    required double weekRevenue,
  }) {
    final profitPositive = todayProfit >= 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: profitPositive
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
              const Icon(Icons.today_rounded, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                "AUJOURD'HUI",
                style: DC.mono(11,
                    color: Colors.white.withValues(alpha: 0.85),
                    weight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '$todayToursCount tournée${todayToursCount > 1 ? 's' : ''}',
                style: DC.body(12, color: Colors.white.withValues(alpha: 0.9)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('CA du jour',
              style: DC.body(12, color: Colors.white.withValues(alpha: 0.8))),
          Text(
            '${todayRevenue.toStringAsFixed(0)} €',
            style: DC.title(30, color: Colors.white),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                profitPositive
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 4),
              Text(
                '${todayProfit >= 0 ? '+' : ''}${todayProfit.toStringAsFixed(0)} €',
                style: DC.mono(13,
                    color: Colors.white, weight: FontWeight.w700),
              ),
              const SizedBox(width: 6),
              Text('profit',
                  style:
                      DC.body(12, color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hier',
                        style: DC.body(11,
                            color: Colors.white.withValues(alpha: 0.7))),
                    Text('${yesterdayRevenue.toStringAsFixed(0)} €',
                        style: DC.mono(14, color: Colors.white)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('7 derniers jours',
                        style: DC.body(11,
                            color: Colors.white.withValues(alpha: 0.7))),
                    Text('${weekRevenue.toStringAsFixed(0)} €',
                        style: DC.mono(14, color: Colors.white)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionMonthCard({
    required double totalRevenue,
    required double totalExpenses,
    required double totalFixedProrata,
    required double profitProrata,
    required double monthRatio,
    required int daysElapsed,
    required int daysInMonth,
    required int toursCount,
    required double totalKm,
  }) {
    final onTrack = profitProrata >= 0;
    final statusColor = onTrack ? DC.success : DC.error;
    final statusLabel = onTrack ? 'DANS LES CLOUS' : 'EN RETARD';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DC.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  size: 18, color: DC.textSecondary),
              const SizedBox(width: 6),
              Text('CE MOIS',
                  style: DC.mono(11,
                      color: DC.textSecondary, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('(jour $daysElapsed/$daysInMonth)',
                  style: DC.body(11, color: DC.textTertiary)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: DC.mono(10,
                        color: statusColor, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barre de progression du mois
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: monthRatio,
              minHeight: 6,
              backgroundColor: DC.surface2,
              valueColor: AlwaysStoppedAnimation(DC.primary),
            ),
          ),
          const SizedBox(height: 14),

          // CA réalisé
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CA réalisé',
                  style: DC.body(13, color: DC.textSecondary)),
              Text('${totalRevenue.toStringAsFixed(0)} €',
                  style: DC.title(18, color: DC.primary)),
            ],
          ),
          const SizedBox(height: 8),

          // Coûts fixes au prorata
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Coûts fixes (prorata $daysElapsed j)',
                  style: DC.body(13, color: DC.textSecondary)),
              Text('− ${totalFixedProrata.toStringAsFixed(0)} €',
                  style: DC.mono(14, color: DC.textPrimary)),
            ],
          ),
          const SizedBox(height: 4),

          // Dépenses réelles
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Dépenses réelles',
                  style: DC.body(13, color: DC.textSecondary)),
              Text('− ${totalExpenses.toStringAsFixed(0)} €',
                  style: DC.mono(14, color: DC.textPrimary)),
            ],
          ),
          const Divider(height: 20),

          // Résultat
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Résultat au prorata',
                  style: DC.body(14, weight: FontWeight.w600)),
              Text(
                '${profitProrata >= 0 ? '+' : ''}${profitProrata.toStringAsFixed(0)} €',
                style: DC.title(20, color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Petits stats secondaires
          Row(
            children: [
              Expanded(
                child: _inlineMetric(
                    'Tournées', '$toursCount', Icons.local_shipping_outlined),
              ),
              Expanded(
                child: _inlineMetric('Km',
                    totalKm > 0 ? totalKm.toStringAsFixed(0) : '0', Icons.route_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _inlineMetric(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: DC.textTertiary),
        const SizedBox(width: 4),
        Text(label, style: DC.body(11, color: DC.textTertiary)),
        const SizedBox(width: 4),
        Text(value, style: DC.mono(12, weight: FontWeight.w600)),
      ],
    );
  }

  Widget _sectionTrucksCard({
    required List<_TruckComputedData> trucks,
    required List<Tour> toursWithoutPricing,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DC.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined,
                  size: 18, color: DC.textSecondary),
              const SizedBox(width: 6),
              Text('TES CAMIONS',
                  style: DC.mono(11,
                      color: DC.textSecondary, weight: FontWeight.w700)),
              const Spacer(),
              Text('classés par profit',
                  style: DC.body(11, color: DC.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          ...trucks.map((t) {
            final isPositive = t.profit >= 0;
            final color = isPositive ? DC.success : DC.error;
            // Tournées sans tarif pour CE camion
            final missing = toursWithoutPricing
                .where((tour) => tour.truckPlate == t.plate)
                .length;
            // Marge en %
            final margin = t.revenue > 0 ? (t.profit / t.revenue * 100) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(t.plate,
                            style: DC.mono(12, weight: FontWeight.w700),
                            overflow: TextOverflow.ellipsis),
                        if (t.model.isNotEmpty)
                          Text(t.model,
                              style: DC.body(11, color: DC.textTertiary),
                              overflow: TextOverflow.ellipsis),
                        if (missing > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '⚠ $missing tournée${missing > 1 ? 's' : ''} sans tarif',
                              style:
                                  DC.body(10, color: DC.warning),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${t.profit >= 0 ? '+' : ''}${t.profit.toStringAsFixed(0)} €',
                        style: DC.mono(13,
                            color: color, weight: FontWeight.w700),
                      ),
                      if (t.revenue > 0)
                        Text('${margin.toStringAsFixed(0)}% marge',
                            style: DC.body(10, color: DC.textTertiary)),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionDriversCard({
    required List<MapEntry<String, double>> topDrivers,
    required Map<String, int> toursByDriver,
  }) {
    final top3 = topDrivers.take(3).toList();
    final medals = ['🥇', '🥈', '🥉'];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DC.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_outlined,
                  size: 18, color: DC.textSecondary),
              const SizedBox(width: 6),
              Text('TES CHAUFFEURS',
                  style: DC.mono(11,
                      color: DC.textSecondary, weight: FontWeight.w700)),
              const Spacer(),
              Text('top du mois', style: DC.body(11, color: DC.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          ...List.generate(top3.length, (i) {
            final e = top3[i];
            final tours = toursByDriver[e.key] ?? 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Text(medals[i], style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(e.key,
                        style: DC.body(13, weight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('$tours tours',
                      style: DC.body(11, color: DC.textTertiary)),
                  const SizedBox(width: 10),
                  Text('${e.value.toStringAsFixed(0)} €',
                      style: DC.mono(13,
                          color: DC.primary, weight: FontWeight.w700)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _sectionActionsCard({
    required List<Tour> toursWithoutPricing,
    required List<dynamic> trucksInsuranceWarn,
    required List<dynamic> trucksCtWarn,
    required int unreadMessages,
  }) {
    final actions = <_ActionItem>[];

    if (toursWithoutPricing.isNotEmpty) {
      actions.add(_ActionItem(
        icon: Icons.warning_amber_rounded,
        color: DC.warning,
        title:
            '${toursWithoutPricing.length} tournée${toursWithoutPricing.length > 1 ? 's' : ''} sans tarif',
        subtitle: 'Configure le commissionnaire dans Tarifs clients',
      ));
    }
    for (final t in trucksInsuranceWarn) {
      actions.add(_ActionItem(
        icon: Icons.shield_outlined,
        color: DC.error,
        title: 'Assurance ${t.plate}',
        subtitle: t.insuranceStatus == 3
            ? 'Expirée — à renouveler'
            : 'Expire dans moins de 30 jours',
      ));
    }
    for (final t in trucksCtWarn) {
      actions.add(_ActionItem(
        icon: Icons.rule_folder_outlined,
        color: DC.error,
        title: 'Contrôle technique ${t.plate}',
        subtitle: t.ctStatus == 4
            ? 'Expiré — à refaire immédiatement'
            : 'Expire dans moins d\'une semaine',
      ));
    }
    if (unreadMessages > 0) {
      actions.add(_ActionItem(
        icon: Icons.chat_bubble_outline,
        color: DC.primary,
        title:
            '$unreadMessages message${unreadMessages > 1 ? 's' : ''} non lu${unreadMessages > 1 ? 's' : ''}',
        subtitle: 'Ouvre la messagerie',
      ));
    }

    if (actions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: DC.card,
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded,
                color: DC.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Aucune action à faire — tout est à jour',
                  style: DC.body(13, color: DC.textSecondary)),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DC.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.task_alt_rounded,
                  size: 18, color: DC.textSecondary),
              const SizedBox(width: 6),
              Text('ACTIONS À FAIRE',
                  style: DC.mono(11,
                      color: DC.textSecondary, weight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DC.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${actions.length}',
                    style: DC.mono(11,
                        color: DC.warning, weight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...actions.map((a) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(a.icon, size: 18, color: a.color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.title,
                              style: DC.body(13,
                                  weight: FontWeight.w600, color: a.color),
                              overflow: TextOverflow.ellipsis),
                          Text(a.subtitle,
                              style:
                                  DC.body(11, color: DC.textSecondary),
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _sectionFixedCostsCard({
    required double totalSalaries,
    required double totalOwnership,
    required double totalInsurance,
    required double totalFixedAll,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: DC.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.home_work_outlined,
                  size: 18, color: DC.textSecondary),
              const SizedBox(width: 6),
              Text('COÛTS FIXES MENSUELS',
                  style: DC.mono(11,
                      color: DC.textSecondary, weight: FontWeight.w700)),
              const Spacer(),
              Text('transparence',
                  style: DC.body(11, color: DC.textTertiary)),
            ],
          ),
          const SizedBox(height: 12),
          _fixedCostLine('Salaires chauffeurs', totalSalaries),
          _fixedCostLine('Amortissements / loyers', totalOwnership),
          _fixedCostLine('Assurances', totalInsurance),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('TOTAL FIXE', style: DC.body(14, weight: FontWeight.w700)),
              Text('${totalFixedAll.toStringAsFixed(0)} €',
                  style: DC.title(18, color: DC.textPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _fixedCostLine(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: DC.body(13, color: DC.textSecondary)),
          Text('${amount.toStringAsFixed(0)} €',
              style: DC.mono(13, weight: FontWeight.w600)),
        ],
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
            DC.monthLabel(_selectedMonth),
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
                overflow: TextOverflow.ellipsis,
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

class _ActionItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _ActionItem({
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