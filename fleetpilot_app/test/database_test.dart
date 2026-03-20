import 'dart:convert';

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

int _dbCounter = 0;

/// Helper to create a test DatabaseService with in-memory SQLite (via ffi).
Future<DatabaseService> createTestDb() async {
  sqfliteFfiInit();
  _dbCounter++;
  final db = await databaseFactoryFfi.openDatabase(
    'file:test_db_$_dbCounter?mode=memory&cache=shared',
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

  setUp(() async {
    db = await createTestDb();
  });

  // ── Drivers ─────────────────────────────────────────────────────────────

  group('DatabaseService — Drivers', () {
    test('save and load driver', () async {
      const driver = Driver(name: 'Karim', fixedSalary: 3000, bonus: 200);
      await db.saveDriver(driver);

      final loaded = await db.loadDrivers();
      expect(loaded.length, 1);
      expect(loaded.first.name, 'Karim');
      expect(loaded.first.fixedSalary, 3000);
      expect(loaded.first.bonus, 200);
    });

    test('upsert overwrites existing driver', () async {
      const driver1 = Driver(name: 'Karim', fixedSalary: 3000);
      await db.saveDriver(driver1);

      const driver2 = Driver(name: 'Karim', fixedSalary: 3500);
      await db.saveDriver(driver2);

      final loaded = await db.loadDrivers();
      expect(loaded.length, 1);
      expect(loaded.first.fixedSalary, 3500);
    });

    test('delete driver', () async {
      const driver = Driver(name: 'Karim', fixedSalary: 3000);
      await db.saveDriver(driver);
      await db.deleteDriver('Karim');

      final loaded = await db.loadDrivers();
      expect(loaded, isEmpty);
    });

    test('saveAllDrivers replaces entire table', () async {
      await db.saveDriver(const Driver(name: 'A', fixedSalary: 1000));
      await db.saveDriver(const Driver(name: 'B', fixedSalary: 2000));

      await db.saveAllDrivers([
        const Driver(name: 'C', fixedSalary: 3000),
      ]);

      final loaded = await db.loadDrivers();
      expect(loaded.length, 1);
      expect(loaded.first.name, 'C');
    });
  });

  // ── Trucks ──────────────────────────────────────────────────────────────

  group('DatabaseService — Trucks', () {
    test('save and load truck', () async {
      const truck = Truck(
        plate: 'AB-123-CD',
        model: 'Sprinter',
        dailyRate: 230,
        ownershipType: OwnershipType.location,
        rentMonthly: 950,
      );
      await db.saveTruck(truck);

      final loaded = await db.loadTrucks();
      expect(loaded.length, 1);
      expect(loaded.first.plate, 'AB-123-CD');
      expect(loaded.first.model, 'Sprinter');
      expect(loaded.first.rentMonthly, 950);
    });

    test('delete truck', () async {
      const truck = Truck(
        plate: 'XX',
        model: 'Test',
        dailyRate: 200,
        ownershipType: OwnershipType.achat,
      );
      await db.saveTruck(truck);
      await db.deleteTruck('XX');

      final loaded = await db.loadTrucks();
      expect(loaded, isEmpty);
    });
  });

  // ── Tours ───────────────────────────────────────────────────────────────

  group('DatabaseService — Tours', () {
    test('save, load, delete tour', () async {
      final tour = Tour(
        id: 't1',
        tourNumber: 'T001',
        date: DateTime(2026, 3, 15),
        driverName: 'Karim',
        truckPlate: 'AB-123-CD',
        kmTotal: 250,
        clientsCount: 30,
        hasHandling: true,
      );
      await db.saveTour(tour);

      final loaded = await db.loadTours();
      expect(loaded.length, 1);
      expect(loaded.first.id, 't1');
      expect(loaded.first.kmTotal, 250);

      await db.deleteTour('t1');
      expect(await db.loadTours(), isEmpty);
    });

    test('saveAllTours replaces entire table', () async {
      final t1 = Tour(
        id: 't1',
        tourNumber: 'T1',
        date: DateTime(2026, 3, 1),
        driverName: 'A',
        truckPlate: 'XX',
        kmTotal: 100,
        clientsCount: 10,
        hasHandling: false,
      );
      final t2 = Tour(
        id: 't2',
        tourNumber: 'T2',
        date: DateTime(2026, 3, 2),
        driverName: 'B',
        truckPlate: 'YY',
        kmTotal: 200,
        clientsCount: 20,
        hasHandling: false,
      );
      await db.saveTour(t1);

      await db.saveAllTours([t2]);

      final loaded = await db.loadTours();
      expect(loaded.length, 1);
      expect(loaded.first.id, 't2');
    });
  });

  // ── Expenses ────────────────────────────────────────────────────────────

  group('DatabaseService — Expenses', () {
    test('save and load expense', () async {
      final expense = Expense(
        id: 'e1',
        date: DateTime(2026, 3, 10),
        truckPlate: 'AB-123-CD',
        type: ExpenseType.fuel,
        amount: 85.50,
        liters: 45.2,
      );
      await db.saveExpense(expense);

      final loaded = await db.loadExpenses();
      expect(loaded.length, 1);
      expect(loaded.first.amount, 85.50);
      expect(loaded.first.liters, 45.2);
    });
  });

  // ── Day Entries ─────────────────────────────────────────────────────────

  group('DatabaseService — DayEntries', () {
    test('save, load, delete, saveAll', () async {
      final entry = DriverDayEntry(
        id: 'de1',
        date: DateTime(2026, 3, 15),
        driverName: 'Karim',
        truckPlate: 'XX',
        kmTotal: 250,
        clientsCount: 30,
      );
      await db.saveDayEntry(entry);

      var loaded = await db.loadDayEntries();
      expect(loaded.length, 1);

      await db.deleteDayEntry('de1');
      loaded = await db.loadDayEntries();
      expect(loaded, isEmpty);

      await db.saveDayEntry(entry);
      final entry2 = DriverDayEntry(
        id: 'de2',
        date: DateTime(2026, 3, 16),
        driverName: 'Sofia',
        truckPlate: 'YY',
        kmTotal: 180,
        clientsCount: 20,
      );
      await db.saveAllDayEntries([entry2]);

      loaded = await db.loadDayEntries();
      expect(loaded.length, 1);
      expect(loaded.first.id, 'de2');
    });
  });

  // ── ClientPricings ──────────────────────────────────────────────────────

  group('DatabaseService — ClientPricings', () {
    test('save and load', () async {
      const pricing = ClientPricing(
        companyName: 'Amazon',
        dailyRate: 280,
        handlingEnabled: true,
        handlingPrice: 35,
      );
      await db.saveClientPricing(pricing);

      final loaded = await db.loadClientPricings();
      expect(loaded.length, 1);
      expect(loaded.first.companyName, 'Amazon');
      expect(loaded.first.handlingPrice, 35);
    });

    test('delete', () async {
      const pricing = ClientPricing(companyName: 'X', dailyRate: 100);
      await db.saveClientPricing(pricing);
      await db.deleteClientPricing('X');

      expect(await db.loadClientPricings(), isEmpty);
    });
  });

  // ── DriverDocuments ─────────────────────────────────────────────────────

  group('DatabaseService — DriverDocuments', () {
    test('save, load, delete', () async {
      const doc = DriverDocument(
        id: 'dd1',
        driverName: 'Karim',
        type: DocumentType.permisC,
        documentNumber: '12345',
      );
      await db.saveDriverDocument(doc);

      final loaded = await db.loadDriverDocuments();
      expect(loaded.length, 1);
      expect(loaded.first.documentNumber, '12345');

      await db.deleteDriverDocument('dd1');
      expect(await db.loadDriverDocuments(), isEmpty);
    });
  });

  // ── Candidates ──────────────────────────────────────────────────────────

  group('DatabaseService — Candidates', () {
    test('save, load, delete', () async {
      final c = Candidate(
        id: 'c1',
        name: 'Jean',
        applyDate: DateTime(2026, 3, 1),
        status: 'candidature',
      );
      await db.saveCandidate(c);

      final loaded = await db.loadCandidates();
      expect(loaded.length, 1);
      expect(loaded.first.name, 'Jean');

      await db.deleteCandidate('c1');
      expect(await db.loadCandidates(), isEmpty);
    });
  });

  // ── AdminDocuments ──────────────────────────────────────────────────────

  group('DatabaseService — AdminDocuments', () {
    test('save, load, delete', () async {
      final doc = AdminDocument(
        id: 'ad1',
        title: 'Contrat',
        category: AdminDocCategory.contratChauffeur,
        date: DateTime(2026, 1, 1),
      );
      await db.saveAdminDocument(doc);

      final loaded = await db.loadAdminDocuments();
      expect(loaded.length, 1);
      expect(loaded.first.title, 'Contrat');

      await db.deleteAdminDocument('ad1');
      expect(await db.loadAdminDocuments(), isEmpty);
    });
  });
}
