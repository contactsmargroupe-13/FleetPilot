import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../screens/add_truck.dart';
import '../screens/models/admin_document.dart';
import '../screens/models/candidate.dart';
import '../screens/models/daily_assignment.dart';
import '../screens/models/client_pricing.dart';
import '../screens/models/driver.dart';
import '../screens/models/driver_day_entry.dart';
import '../screens/models/driver_document.dart';
import '../screens/models/driver_notification.dart';
import '../screens/models/expense.dart';
import '../screens/models/equipment.dart';
import '../screens/models/manager_alert.dart';
import '../screens/models/message.dart';
import '../screens/models/tour.dart';
import '../screens/models/user_access.dart';
import 'company_settings.dart';

class DatabaseService {
  final Database _db;

  DatabaseService._(this._db);

  /// Test-only constructor: wrap an already-opened Database.
  factory DatabaseService.fromDatabase(Database db) => DatabaseService._(db);

  static Future<DatabaseService> init() async {
    final String path;
    if (kIsWeb) {
      path = 'fleetpilot.db';
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, 'fleetpilot.db');
    }

    final db = await openDatabase(
      path,
      version: 6,
      onCreate: (db, version) async {
        await db.execute(
            'CREATE TABLE drivers (name TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE trucks (plate TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE tours (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE expenses (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE driver_day_entries (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE client_pricings (company_name TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE driver_documents (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE candidates (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE admin_documents (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE driver_notifications (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE manager_alerts (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE equipment (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE driver_assignments (name TEXT PRIMARY KEY, data TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE messages (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS driver_notifications (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        }
        if (oldVersion < 3) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS manager_alerts (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        }
        if (oldVersion < 4) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS equipment (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        }
        if (oldVersion < 5) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS driver_assignments (name TEXT PRIMARY KEY, data TEXT NOT NULL)');
        }
        if (oldVersion < 6) {
          await db.execute(
              'CREATE TABLE IF NOT EXISTS messages (id TEXT PRIMARY KEY, data TEXT NOT NULL)');
        }
      },
    );

    final service = DatabaseService._(db);

    // Initialize CompanySettings (still uses SharedPreferences for config)
    final prefs = await SharedPreferences.getInstance();
    await CompanySettings.init(prefs);

    // Migrate from SharedPreferences if first time
    await service._migrateFromSharedPreferences(prefs);

    return service;
  }

  // ── Migration ──────────────────────────────────────────────────────────────

  Future<void> _migrateFromSharedPreferences(SharedPreferences prefs) async {
    if (prefs.getBool('_migrated_to_sqlite') == true) return;

    if (!kIsWeb) {
      await _db.transaction((txn) async {
        _migrateJsonList(txn, prefs, 'drivers', 'drivers', 'name');
        _migrateJsonList(txn, prefs, 'trucks', 'trucks', 'plate');
        _migrateJsonList(txn, prefs, 'tours', 'tours', 'id');
        _migrateJsonList(txn, prefs, 'expenses', 'expenses', 'id');
        _migrateJsonList(
            txn, prefs, 'driverDayEntries', 'driver_day_entries', 'id');
        _migrateJsonList(txn, prefs, 'clientPricings', 'client_pricings',
            'company_name',
            jsonKeyField: 'companyName');
        _migrateJsonList(
            txn, prefs, 'driverDocuments', 'driver_documents', 'id');
        _migrateJsonList(txn, prefs, 'candidates', 'candidates', 'id');
        _migrateJsonList(
            txn, prefs, 'adminDocuments', 'admin_documents', 'id');
      });
    }

    // Seed default data if database is empty
    await _seedDefaults();

    await prefs.setBool('_migrated_to_sqlite', true);
  }

  void _migrateJsonList(
    Transaction txn,
    SharedPreferences prefs,
    String prefsKey,
    String tableName,
    String pkColumn, {
    String? jsonKeyField,
  }) {
    final raw = prefs.getString(prefsKey);
    if (raw == null) return;

    try {
      final list = jsonDecode(raw) as List;
      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final pk = map[jsonKeyField ?? pkColumn] as String;
        txn.insert(
          tableName,
          {pkColumn: pk, 'data': jsonEncode(map)},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
  }

  Future<void> _seedDefaults() async {
    // Plus de données de démo — l'app démarre vide
  }

  // ── Generic helpers ────────────────────────────────────────────────────────

  Future<List<T>> _loadAll<T>(
      String table, T Function(Map<String, dynamic>) fromJson) async {
    try {
      final rows = await _db.query(table);
      final List<T> result = [];
      for (final row in rows) {
        try {
          final map = jsonDecode(row['data'] as String) as Map<String, dynamic>;
          result.add(fromJson(map));
        } catch (e) {
          debugPrint('⚠️ Donnée corrompue ignorée dans $table: $e');
        }
      }
      return result;
    } catch (e) {
      debugPrint('❌ Erreur chargement $table: $e');
      return [];
    }
  }

  Future<void> _upsert(
      String table, String pkColumn, String pkValue, Map<String, dynamic> json) async {
    try {
      await _db.insert(
        table,
        {pkColumn: pkValue, 'data': jsonEncode(json)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde $table ($pkValue): $e');
    }
  }

  Future<void> _delete(String table, String pkColumn, String pkValue) async {
    try {
      await _db.delete(table, where: '$pkColumn = ?', whereArgs: [pkValue]);
    } catch (e) {
      debugPrint('❌ Erreur suppression $table ($pkValue): $e');
    }
  }

  // ── Drivers ────────────────────────────────────────────────────────────────

  Future<List<Driver>> loadDrivers() =>
      _loadAll('drivers', Driver.fromJson);

  Future<void> saveDriver(Driver d) =>
      _upsert('drivers', 'name', d.name, d.toJson());

  Future<void> deleteDriver(String name) =>
      _delete('drivers', 'name', name);

  // ── Trucks ─────────────────────────────────────────────────────────────────

  Future<List<Truck>> loadTrucks() =>
      _loadAll('trucks', Truck.fromJson);

  Future<void> saveTruck(Truck t) =>
      _upsert('trucks', 'plate', t.plate, t.toJson());

  Future<void> deleteTruck(String plate) =>
      _delete('trucks', 'plate', plate);

  // ── Tours ──────────────────────────────────────────────────────────────────

  Future<List<Tour>> loadTours() =>
      _loadAll('tours', Tour.fromJson);

  Future<void> saveTour(Tour t) =>
      _upsert('tours', 'id', t.id, t.toJson());

  Future<void> deleteTour(String id) =>
      _delete('tours', 'id', id);

  // ── Expenses ───────────────────────────────────────────────────────────────

  Future<List<Expense>> loadExpenses() =>
      _loadAll('expenses', Expense.fromJson);

  Future<void> saveExpense(Expense e) =>
      _upsert('expenses', 'id', e.id, e.toJson());

  Future<void> deleteExpense(String id) =>
      _delete('expenses', 'id', id);

  // ── Driver Day Entries ─────────────────────────────────────────────────────

  Future<List<DriverDayEntry>> loadDayEntries() =>
      _loadAll('driver_day_entries', DriverDayEntry.fromJson);

  Future<void> saveDayEntry(DriverDayEntry e) =>
      _upsert('driver_day_entries', 'id', e.id, e.toJson());

  Future<void> deleteDayEntry(String id) =>
      _delete('driver_day_entries', 'id', id);

  // ── Client Pricings ────────────────────────────────────────────────────────

  Future<List<ClientPricing>> loadClientPricings() =>
      _loadAll('client_pricings', ClientPricing.fromJson);

  Future<void> saveClientPricing(ClientPricing cp) =>
      _upsert('client_pricings', 'company_name', cp.companyName, cp.toJson());

  Future<void> deleteClientPricing(String companyName) =>
      _delete('client_pricings', 'company_name', companyName);

  // ── Driver Documents ───────────────────────────────────────────────────────

  Future<List<DriverDocument>> loadDriverDocuments() =>
      _loadAll('driver_documents', DriverDocument.fromJson);

  Future<void> saveDriverDocument(DriverDocument d) =>
      _upsert('driver_documents', 'id', d.id, d.toJson());

  Future<void> deleteDriverDocument(String id) =>
      _delete('driver_documents', 'id', id);

  // ── Candidates ─────────────────────────────────────────────────────────────

  Future<List<Candidate>> loadCandidates() =>
      _loadAll('candidates', Candidate.fromJson);

  Future<void> saveCandidate(Candidate c) =>
      _upsert('candidates', 'id', c.id, c.toJson());

  Future<void> deleteCandidate(String id) =>
      _delete('candidates', 'id', id);

  // ── Admin Documents ────────────────────────────────────────────────────────

  Future<List<AdminDocument>> loadAdminDocuments() =>
      _loadAll('admin_documents', AdminDocument.fromJson);

  Future<void> saveAdminDocument(AdminDocument d) =>
      _upsert('admin_documents', 'id', d.id, d.toJson());

  Future<void> deleteAdminDocument(String id) =>
      _delete('admin_documents', 'id', id);

  // ── Batch save (for cascading updates) ─────────────────────────────────────

  Future<void> saveAllTours(List<Tour> tours) async {
    try {
      await _db.transaction((txn) async {
        await txn.delete('tours');
        for (final t in tours) {
          await txn.insert('tours', {'id': t.id, 'data': jsonEncode(t.toJson())});
        }
      });
    } catch (e) {
      debugPrint('❌ Erreur saveAllTours: $e');
    }
  }

  Future<void> saveAllDayEntries(List<DriverDayEntry> entries) async {
    try {
      await _db.transaction((txn) async {
        await txn.delete('driver_day_entries');
        for (final e in entries) {
          await txn.insert(
              'driver_day_entries', {'id': e.id, 'data': jsonEncode(e.toJson())});
        }
      });
    } catch (e) {
      debugPrint('❌ Erreur saveAllDayEntries: $e');
    }
  }

  Future<void> saveAllDrivers(List<Driver> drivers) async {
    try {
      await _db.transaction((txn) async {
        await txn.delete('drivers');
        for (final d in drivers) {
          await txn.insert('drivers', {'name': d.name, 'data': jsonEncode(d.toJson())});
        }
      });
    } catch (e) {
      debugPrint('❌ Erreur saveAllDrivers: $e');
    }
  }

  // ── Driver Notifications ─────────────────────────────────────────────────

  Future<List<DriverNotification>> loadDriverNotifications() =>
      _loadAll('driver_notifications', DriverNotification.fromJson);

  Future<void> saveDriverNotification(DriverNotification n) =>
      _upsert('driver_notifications', 'id', n.id, n.toJson());

  Future<void> deleteDriverNotification(String id) =>
      _delete('driver_notifications', 'id', id);

  // ── Manager Alerts ──────────────────────────────────────────────────────

  Future<List<ManagerAlert>> loadManagerAlerts() =>
      _loadAll('manager_alerts', ManagerAlert.fromJson);

  Future<void> saveManagerAlert(ManagerAlert a) =>
      _upsert('manager_alerts', 'id', a.id, a.toJson());

  Future<void> deleteManagerAlert(String id) =>
      _delete('manager_alerts', 'id', id);

  // ── Equipment ───────────────────────────────────────────────────────

  Future<List<Equipment>> loadEquipment() =>
      _loadAll('equipment', Equipment.fromJson);

  Future<void> saveEquipment(Equipment e) =>
      _upsert('equipment', 'id', e.id, e.toJson());

  Future<void> deleteEquipment(String id) =>
      _delete('equipment', 'id', id);

  // ── Affectations chauffeur ──────────────────────────────────────────

  Future<List<DriverAssignment>> loadAssignments() =>
      _loadAll('driver_assignments', DriverAssignment.fromJson);

  Future<void> saveAssignment(DriverAssignment a) =>
      _upsert('driver_assignments', 'name', a.driverName, a.toJson());

  Future<void> deleteAssignment(String driverName) =>
      _delete('driver_assignments', 'name', driverName);

  // ── Messages ──────────────────────────────────────────────────────────

  Future<List<Message>> loadMessages() =>
      _loadAll('messages', Message.fromJson);

  Future<void> saveMessage(Message m) =>
      _upsert('messages', 'id', m.id, m.toJson());

  Future<void> deleteMessage(String id) =>
      _delete('messages', 'id', id);

  // ── Accès utilisateurs ──────────────────────────────────────────────

  Future<List<UserAccess>> loadUserAccesses() =>
      _loadAll('user_accesses', UserAccess.fromJson);

  Future<void> saveUserAccess(UserAccess u) =>
      _upsert('user_accesses', 'id', u.id, u.toJson());

  Future<void> deleteUserAccess(String id) =>
      _delete('user_accesses', 'id', id);
}
