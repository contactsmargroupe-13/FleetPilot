// Point d'entrée de prévisualisation — ne fait pas partie de l'application.
// Permet de voir la coquille et la cour avec un jeu d'essai, sans Firebase :
//   flutter run -d chrome -t lib/demo/depot_preview.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

import '../providers/app_state.dart';
import '../screens/add_truck.dart';
import '../screens/manager_shell.dart';
import '../screens/models/client_pricing.dart';
import '../screens/models/driver.dart';
import '../screens/models/equipment.dart';
import '../screens/models/expense.dart';
import '../screens/models/tour.dart';
import '../screens/models/user_access.dart';
import '../services/database_service.dart';
import '../utils/design_constants.dart';

DateTime get _today => DateTime.now();
DateTime _d(int daysAgo) => _today.subtract(Duration(days: daysAgo));

void _seed(AppState s) {
  final ctSoon = _today.add(const Duration(days: 12));
  final ctFar = _today.add(const Duration(days: 420));

  s.trucks = [
    Truck(
      plate: 'AB-123-CD', brand: 'Renault', model: 'Master', dailyRate: 265,
      ownershipType: OwnershipType.achat, purchasePrice: 38000, amortMonths: 60,
      vehicleType: VehicleType.vl12m3, insuranceMonthly: 185,
      insuranceExpiry: ctFar, ctExpiry: ctFar, assignedDriverName: 'Karim Benali',
    ),
    Truck(
      plate: 'CD-456-EF', brand: 'Iveco', model: 'Daily', dailyRate: 290,
      ownershipType: OwnershipType.location, rentMonthly: 760,
      vehicleType: VehicleType.vl20m3, insuranceMonthly: 205,
      insuranceExpiry: ctFar, ctExpiry: ctFar,
    ),
    Truck(
      plate: 'EF-789-GH', brand: 'Renault', model: 'D 7.5T', dailyRate: 320,
      ownershipType: OwnershipType.achat, purchasePrice: 52000, amortMonths: 72,
      vehicleType: VehicleType.t75, insuranceMonthly: 240,
      insuranceExpiry: ctFar, ctExpiry: ctSoon, assignedDriverName: 'Luc Mercier',
    ),
    Truck(
      plate: 'GH-012-IJ', brand: 'Mercedes', model: 'Sprinter', dailyRate: 275,
      ownershipType: OwnershipType.location, rentMonthly: 690,
      vehicleType: VehicleType.vl16m3, insuranceMonthly: 195,
      insuranceExpiry: ctFar, ctExpiry: ctFar, assignedDriverName: 'Sofiane Amrani',
    ),
    Truck(
      plate: 'IJ-345-KL', brand: 'Volvo', model: 'FL', dailyRate: 380,
      ownershipType: OwnershipType.achat, purchasePrice: 74000, amortMonths: 84,
      vehicleType: VehicleType.t19, insuranceMonthly: 310,
      insuranceExpiry: ctFar, ctExpiry: ctFar,
      truckStatus: TruckStatus.enReparation,
    ),
  ];

  s.drivers = const [
    Driver(name: 'Karim Benali', fixedSalary: 2340, bonus: 180),
    Driver(name: 'Sofiane Amrani', fixedSalary: 2280, bonus: 120),
    Driver(name: 'Luc Mercier', fixedSalary: 2100, status: DriverStatus.cdd),
    Driver(name: 'Nadia Fourcade', fixedSalary: 2050, status: DriverStatus.interim),
  ];

  s.clientPricings = const [
    ClientPricing(companyName: 'Transalpe', dailyRate: 265, extraKmEnabled: true,
        extraKmPrice: 0.45),
    ClientPricing(companyName: 'Rhône Express', dailyRate: 290),
  ];

  s.tours = [
    Tour(id: 't1', tourNumber: 'T-2418', date: _today, driverName: 'Karim Benali',
        truckPlate: 'AB-123-CD', companyName: 'Transalpe', sector: 'Secteur Nord',
        startTime: '06:10', kmTotal: 184, clientsCount: 18, hasHandling: false,
        status: 'en cours'),
    Tour(id: 't2', tourNumber: 'T-2419', date: _today, driverName: 'Sofiane Amrani',
        truckPlate: 'GH-012-IJ', companyName: 'Rhône Express', sector: 'Secteur Est',
        startTime: '06:25', kmTotal: 96, clientsCount: 11, hasHandling: false,
        status: 'en cours'),
    for (var i = 1; i <= 14; i++)
      Tour(id: 'p$i', tourNumber: 'T-24${i.toString().padLeft(2, '0')}',
          date: _d(i), driverName: i.isEven ? 'Karim Benali' : 'Sofiane Amrani',
          truckPlate: i.isEven ? 'AB-123-CD' : 'GH-012-IJ',
          companyName: i.isEven ? 'Transalpe' : 'Rhône Express',
          sector: 'Secteur Nord', kmTotal: 150 + i * 4.0,
          clientsCount: 12 + i % 6, hasHandling: false, status: 'terminée'),
  ];

  s.expenses = [
    Expense(id: 'e1', date: _d(1), truckPlate: 'AB-123-CD',
        type: ExpenseType.fuel, amount: 184.20, liters: 118),
    Expense(id: 'e2', date: _d(1), truckPlate: 'GH-012-IJ',
        type: ExpenseType.other, amount: 47.60, note: 'Péage APRR'),
    Expense(id: 'e3', date: _d(2), truckPlate: 'IJ-345-KL',
        type: ExpenseType.repair, amount: 1840, note: 'Embrayage'),
    Expense(id: 'e4', date: _d(5), truckPlate: 'CD-456-EF',
        type: ExpenseType.fuel, amount: 162.90, liters: 104),
  ];

  s.equipment = [
    Equipment(id: 'q1', name: 'Transpalette électrique',
        category: EquipmentCategory.manutention, purchasePrice: 2400,
        purchaseDate: _d(300), amortMonths: 60, assignedTruckPlate: 'AB-123-CD'),
    Equipment(id: 'q2', name: 'Diable aluminium',
        category: EquipmentCategory.manutention, purchasePrice: 180,
        purchaseDate: _d(120), amortMonths: 36),
  ];
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;
  if (kIsWeb) databaseFactory = databaseFactoryFfiWeb;

  final db = await DatabaseService.init();
  final appState = AppState(db);
  _seed(appState);

  runApp(ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      appStateProvider.overrideWith((_) => appState),
    ],
    child: const _PreviewApp(),
  ));
}

class _PreviewApp extends StatelessWidget {
  const _PreviewApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetPilote — prévisualisation',
      debugShowCheckedModeBanner: false,
      theme: DC.theme,
      darkTheme: DC.darkTheme,
      themeMode: ThemeMode.system,
      // ?role=comptable pour vérifier le filtrage par rôle
      home: ManagerShell(
        role: Uri.base.queryParameters['role'] == 'comptable'
            ? AccessRole.comptable
            : AccessRole.manager,
      ),
    );
  }
}
