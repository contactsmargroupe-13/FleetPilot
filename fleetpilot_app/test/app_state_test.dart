import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fleetpilot_app/screens/models/driver.dart';
import 'package:fleetpilot_app/screens/models/tour.dart';
import 'package:fleetpilot_app/screens/models/expense.dart';
import 'package:fleetpilot_app/screens/models/client_pricing.dart';
import 'package:fleetpilot_app/screens/models/driver_day_entry.dart';
import 'package:fleetpilot_app/screens/models/candidate.dart';
import 'package:fleetpilot_app/screens/models/admin_document.dart';
import 'package:fleetpilot_app/screens/models/driver_document.dart';
import 'package:fleetpilot_app/screens/add_truck.dart';
import 'package:fleetpilot_app/services/database_service.dart';
import 'package:fleetpilot_app/providers/app_state.dart';

int _dbCounter = 0;

/// Test-only factory that creates a DatabaseService with an in-memory database.
Future<DatabaseService> createTestDb() async {
  sqfliteFfiInit();
  _dbCounter++;
  final db = await databaseFactoryFfi.openDatabase(
    'file:appstate_db_$_dbCounter?mode=memory&cache=shared',
    options: OpenDatabaseOptions(
      version: 1,
      onCreate: (db, version) async {
        final batch = db.batch();
        batch.execute(
            'CREATE TABLE drivers (name TEXT PRIMARY KEY, data TEXT NOT NULL)');
        batch.execute(
            'CREATE TABLE trucks (plate TEXT PRIMARY KEY, data TEXT NOT NULL)');
        batch.execute(
            'CREATE TABLE tours (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        batch.execute(
            'CREATE TABLE expenses (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        batch.execute(
            'CREATE TABLE driver_day_entries (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        batch.execute(
            'CREATE TABLE client_pricings (company_name TEXT PRIMARY KEY, data TEXT NOT NULL)');
        batch.execute(
            'CREATE TABLE driver_documents (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        batch.execute(
            'CREATE TABLE candidates (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        batch.execute(
            'CREATE TABLE admin_documents (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await batch.commit();
      },
    ),
  );

  return DatabaseService.fromDatabase(db);
}

void main() {
  late DatabaseService db;
  late AppState state;

  setUp(() async {
    db = await createTestDb();
    state = AppState(db);
  });

  // ── Drivers CRUD ──────────────────────────────────────────────────────────

  group('AppState — Drivers', () {
    test('addDriver adds to list and persists', () async {
      const driver = Driver(name: 'Karim', fixedSalary: 3000);
      state.addDriver(driver);

      expect(state.drivers.length, 1);
      expect(state.drivers.first.name, 'Karim');

      // Verify persistence
      final loaded = await db.loadDrivers();
      expect(loaded.length, 1);
      expect(loaded.first.name, 'Karim');
    });

    test('updateDriver updates in-place', () {
      const driver = Driver(name: 'Karim', fixedSalary: 3000);
      state.addDriver(driver);
      state.updateDriver('Karim', driver.copyWith(fixedSalary: 3500));

      expect(state.drivers.first.fixedSalary, 3500);
    });

    test('deleteDriver removes from list', () async {
      const driver = Driver(name: 'Karim', fixedSalary: 3000);
      state.addDriver(driver);
      state.deleteDriver('Karim');

      expect(state.drivers, isEmpty);

      final loaded = await db.loadDrivers();
      expect(loaded, isEmpty);
    });

    test('updateDriver cascades to tours and day entries', () {
      state.addDriver(const Driver(name: 'Karim', fixedSalary: 3000));

      final tour = Tour(
        id: 't1',
        tourNumber: 'T1',
        date: DateTime(2026, 3, 15),
        driverName: 'Karim',
        truckPlate: 'XX',
        kmTotal: 100,
        clientsCount: 10,
        hasHandling: false,
      );
      state.addTour(tour);

      final entry = DriverDayEntry(
        id: 'e1',
        date: DateTime(2026, 3, 15),
        driverName: 'Karim',
        truckPlate: 'XX',
        kmTotal: 100,
        clientsCount: 10,
      );
      state.addDriverDayEntry(entry);

      // Rename driver
      state.updateDriver(
        'Karim',
        const Driver(name: 'Karim Benali', fixedSalary: 3000),
      );

      expect(state.tours.first.driverName, 'Karim Benali');
      expect(state.driverDayEntries.first.driverName, 'Karim Benali');
    });
  });

  // ── Trucks CRUD ───────────────────────────────────────────────────────────

  group('AppState — Trucks', () {
    test('addTruck and deleteTruck', () async {
      const truck = Truck(
        plate: 'AB-123-CD',
        model: 'Sprinter',
        dailyRate: 230,
        ownershipType: OwnershipType.location,
      );
      state.addTruck(truck);
      expect(state.trucks.length, 1);

      state.deleteTruck('AB-123-CD');
      expect(state.trucks, isEmpty);

      final loaded = await db.loadTrucks();
      expect(loaded, isEmpty);
    });

    test('updateTruck with plate change', () async {
      const truck = Truck(
        plate: 'OLD',
        model: 'Sprinter',
        dailyRate: 230,
        ownershipType: OwnershipType.location,
      );
      state.addTruck(truck);
      state.updateTruck('OLD', truck.copyWith(plate: 'NEW'));

      expect(state.trucks.first.plate, 'NEW');

      // Old plate should be deleted
      final loaded = await db.loadTrucks();
      expect(loaded.length, 1);
      expect(loaded.first.plate, 'NEW');
    });
  });

  // ── Tours CRUD ────────────────────────────────────────────────────────────

  group('AppState — Tours', () {
    test('addTour, updateTour, deleteTour', () {
      final tour = Tour(
        id: 't1',
        tourNumber: 'T1',
        date: DateTime(2026, 3, 15),
        driverName: 'Karim',
        truckPlate: 'XX',
        kmTotal: 100,
        clientsCount: 10,
        hasHandling: false,
      );
      state.addTour(tour);
      expect(state.tours.length, 1);

      final updated = Tour(
        id: 't1',
        tourNumber: 'T1',
        date: DateTime(2026, 3, 15),
        driverName: 'Karim',
        truckPlate: 'XX',
        kmTotal: 200,
        clientsCount: 15,
        hasHandling: true,
      );
      state.updateTour('t1', updated);
      expect(state.tours.first.kmTotal, 200);
      expect(state.tours.first.hasHandling, true);

      state.deleteTour('t1');
      expect(state.tours, isEmpty);
    });
  });

  // ── Expenses CRUD ─────────────────────────────────────────────────────────

  group('AppState — Expenses', () {
    test('addExpense and deleteExpense', () {
      final expense = Expense(
        id: 'e1',
        date: DateTime(2026, 3, 10),
        truckPlate: 'XX',
        type: ExpenseType.fuel,
        amount: 85,
      );
      state.addExpense(expense);
      expect(state.expenses.length, 1);

      state.deleteExpense('e1');
      expect(state.expenses, isEmpty);
    });
  });

  // ── ClientPricings CRUD ───────────────────────────────────────────────────

  group('AppState — ClientPricings', () {
    test('add, update, delete, getClientPricing', () {
      const pricing = ClientPricing(companyName: 'Amazon', dailyRate: 280);
      state.addClientPricing(pricing);
      expect(state.clientPricings.length, 1);

      state.updateClientPricing(
          'Amazon', pricing.copyWith(dailyRate: 300));
      expect(state.clientPricings.first.dailyRate, 300);

      expect(state.getClientPricing('Amazon')?.dailyRate, 300);
      expect(state.getClientPricing('NonExistent'), isNull);
      expect(state.getClientPricing(null), isNull);

      state.deleteClientPricing('Amazon');
      expect(state.clientPricings, isEmpty);
    });

    test('updateClientPricing with name change deletes old', () async {
      const pricing = ClientPricing(companyName: 'Old', dailyRate: 200);
      state.addClientPricing(pricing);

      state.updateClientPricing(
          'Old', pricing.copyWith(companyName: 'New'));
      expect(state.clientPricings.length, 1);
      expect(state.clientPricings.first.companyName, 'New');
    });
  });

  // ── Candidates CRUD ───────────────────────────────────────────────────────

  group('AppState — Candidates', () {
    test('add, update, delete', () {
      final c = Candidate(
        id: 'c1',
        name: 'Jean',
        applyDate: DateTime(2026, 3, 1),
      );
      state.addCandidate(c);
      expect(state.candidates.length, 1);

      state.updateCandidate('c1', c.copyWith(status: 'entretien'));
      expect(state.candidates.first.status, 'entretien');

      state.deleteCandidate('c1');
      expect(state.candidates, isEmpty);
    });
  });

  // ── DriverDocuments ───────────────────────────────────────────────────────

  group('AppState — DriverDocuments', () {
    test('add, update, delete, documentsForDriver', () {
      const doc = DriverDocument(
        id: 'dd1',
        driverName: 'Karim',
        type: DocumentType.permisC,
      );
      state.addDriverDocument(doc);
      expect(state.driverDocuments.length, 1);
      expect(state.documentsForDriver('Karim').length, 1);
      expect(state.documentsForDriver('Sofia'), isEmpty);

      const updated = DriverDocument(
        id: 'dd1',
        driverName: 'Karim',
        type: DocumentType.permisC,
        documentNumber: '12345',
      );
      state.updateDriverDocument('dd1', updated);
      expect(state.driverDocuments.first.documentNumber, '12345');

      state.deleteDriverDocument('dd1');
      expect(state.driverDocuments, isEmpty);
    });

    test('alertDocuments returns expired and warning docs', () {
      final expired = DriverDocument(
        id: 'dd1',
        driverName: 'Karim',
        type: DocumentType.fimo,
        expiryDate: DateTime.now().subtract(const Duration(days: 10)),
      );
      final warning = DriverDocument(
        id: 'dd2',
        driverName: 'Karim',
        type: DocumentType.fco,
        expiryDate: DateTime.now().add(const Duration(days: 15)),
      );
      final ok = DriverDocument(
        id: 'dd3',
        driverName: 'Karim',
        type: DocumentType.permisC,
        expiryDate: DateTime.now().add(const Duration(days: 365)),
      );

      state.addDriverDocument(expired);
      state.addDriverDocument(warning);
      state.addDriverDocument(ok);

      final alerts = state.alertDocuments;
      expect(alerts.length, 2);
      // Expired should come first (most urgent)
      expect(alerts.first.id, 'dd1');
    });
  });

  // ── AdminDocuments ────────────────────────────────────────────────────────

  group('AppState — AdminDocuments', () {
    test('add, update, delete', () {
      final doc = AdminDocument(
        id: 'ad1',
        title: 'Contrat',
        category: AdminDocCategory.contratChauffeur,
        date: DateTime(2026, 1, 1),
      );
      state.addAdminDocument(doc);
      expect(state.adminDocuments.length, 1);

      final updated = AdminDocument(
        id: 'ad1',
        title: 'Contrat CDI',
        category: AdminDocCategory.contratChauffeur,
        date: DateTime(2026, 1, 1),
      );
      state.updateAdminDocument('ad1', updated);
      expect(state.adminDocuments.first.title, 'Contrat CDI');

      state.deleteAdminDocument('ad1');
      expect(state.adminDocuments, isEmpty);
    });
  });

  // ── Case-insensitive lookups ──────────────────────────────────────────────

  group('AppState — case insensitivity', () {
    test('driver update is case-insensitive', () {
      state.addDriver(const Driver(name: 'Karim', fixedSalary: 3000));
      state.updateDriver(
          'karim', const Driver(name: 'Karim B', fixedSalary: 3000));
      expect(state.drivers.first.name, 'Karim B');
    });

    test('driver delete is case-insensitive', () {
      state.addDriver(const Driver(name: 'Karim', fixedSalary: 3000));
      state.deleteDriver('KARIM');
      expect(state.drivers, isEmpty);
    });

    test('getClientPricing is case-insensitive', () {
      const pricing = ClientPricing(companyName: 'Amazon', dailyRate: 280);
      state.addClientPricing(pricing);
      expect(state.getClientPricing('amazon')?.dailyRate, 280);
      expect(state.getClientPricing('AMAZON')?.dailyRate, 280);
    });
  });
}
