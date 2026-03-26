import 'package:cloud_firestore/cloud_firestore.dart';

import '../screens/add_truck.dart';
import '../screens/models/admin_document.dart';
import '../screens/models/candidate.dart';
import '../screens/models/client_pricing.dart';
import '../screens/models/daily_assignment.dart';
import '../screens/models/driver.dart';
import '../screens/models/driver_day_entry.dart';
import '../screens/models/driver_document.dart';
import '../screens/models/driver_notification.dart';
import '../screens/models/equipment.dart';
import '../screens/models/expense.dart';
import '../screens/models/manager_alert.dart';
import '../screens/models/message.dart';
import '../screens/models/tour.dart';
import '../screens/models/user_access.dart';

/// Service Firestore — toutes les données sont sous companies/{companyId}/
class FirestoreService {
  final String companyId;
  final FirebaseFirestore _fs;

  FirestoreService({required this.companyId})
      : _fs = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String name) =>
      _fs.collection('companies').doc(companyId).collection(name);

  // ── Generic helpers ──────────────────────────────────────────────────────

  Future<void> _upsert(String collection, String docId, Map<String, dynamic> data) =>
      _col(collection).doc(docId).set(data);

  Future<void> _deleteDoc(String collection, String docId) =>
      _col(collection).doc(docId).delete();

  Future<List<T>> _loadAll<T>(
      String collection, T Function(Map<String, dynamic>) fromJson) async {
    final snap = await _col(collection).get();
    return snap.docs.map((d) => fromJson(d.data())).toList();
  }

  Stream<List<T>> _streamAll<T>(
      String collection, T Function(Map<String, dynamic>) fromJson) {
    return _col(collection).snapshots().map(
      (snap) => snap.docs.map((d) => fromJson(d.data())).toList(),
    );
  }

  // ── Drivers ──────────────────────────────────────────────────────────────

  Future<List<Driver>> loadDrivers() => _loadAll('drivers', Driver.fromJson);
  Stream<List<Driver>> streamDrivers() => _streamAll('drivers', Driver.fromJson);
  Future<void> saveDriver(Driver d) => _upsert('drivers', d.name, d.toJson());
  Future<void> deleteDriver(String name) => _deleteDoc('drivers', name);

  // ── Trucks ───────────────────────────────────────────────────────────────

  Future<List<Truck>> loadTrucks() => _loadAll('trucks', Truck.fromJson);
  Stream<List<Truck>> streamTrucks() => _streamAll('trucks', Truck.fromJson);
  Future<void> saveTruck(Truck t) => _upsert('trucks', t.plate, t.toJson());
  Future<void> deleteTruck(String plate) => _deleteDoc('trucks', plate);

  // ── Tours ────────────────────────────────────────────────────────────────

  Future<List<Tour>> loadTours() => _loadAll('tours', Tour.fromJson);
  Stream<List<Tour>> streamTours() => _streamAll('tours', Tour.fromJson);
  Future<void> saveTour(Tour t) => _upsert('tours', t.id, t.toJson());
  Future<void> deleteTour(String id) => _deleteDoc('tours', id);

  // ── Expenses ─────────────────────────────────────────────────────────────

  Future<List<Expense>> loadExpenses() => _loadAll('expenses', Expense.fromJson);
  Stream<List<Expense>> streamExpenses() => _streamAll('expenses', Expense.fromJson);
  Future<void> saveExpense(Expense e) => _upsert('expenses', e.id, e.toJson());
  Future<void> deleteExpense(String id) => _deleteDoc('expenses', id);

  // ── Driver Day Entries ───────────────────────────────────────────────────

  Future<List<DriverDayEntry>> loadDayEntries() =>
      _loadAll('driver_day_entries', DriverDayEntry.fromJson);
  Stream<List<DriverDayEntry>> streamDayEntries() =>
      _streamAll('driver_day_entries', DriverDayEntry.fromJson);
  Future<void> saveDayEntry(DriverDayEntry e) =>
      _upsert('driver_day_entries', e.id, e.toJson());
  Future<void> deleteDayEntry(String id) => _deleteDoc('driver_day_entries', id);

  // ── Client Pricings ─────────────────────────────────────────────────────

  Future<List<ClientPricing>> loadClientPricings() =>
      _loadAll('client_pricings', ClientPricing.fromJson);
  Stream<List<ClientPricing>> streamClientPricings() =>
      _streamAll('client_pricings', ClientPricing.fromJson);
  Future<void> saveClientPricing(ClientPricing cp) =>
      _upsert('client_pricings', cp.companyName, cp.toJson());
  Future<void> deleteClientPricing(String companyName) =>
      _deleteDoc('client_pricings', companyName);

  // ── Driver Documents ────────────────────────────────────────────────────

  Future<List<DriverDocument>> loadDriverDocuments() =>
      _loadAll('driver_documents', DriverDocument.fromJson);
  Stream<List<DriverDocument>> streamDriverDocuments() =>
      _streamAll('driver_documents', DriverDocument.fromJson);
  Future<void> saveDriverDocument(DriverDocument d) =>
      _upsert('driver_documents', d.id, d.toJson());
  Future<void> deleteDriverDocument(String id) =>
      _deleteDoc('driver_documents', id);

  // ── Candidates ──────────────────────────────────────────────────────────

  Future<List<Candidate>> loadCandidates() =>
      _loadAll('candidates', Candidate.fromJson);
  Stream<List<Candidate>> streamCandidates() =>
      _streamAll('candidates', Candidate.fromJson);
  Future<void> saveCandidate(Candidate c) =>
      _upsert('candidates', c.id, c.toJson());
  Future<void> deleteCandidate(String id) => _deleteDoc('candidates', id);

  // ── Admin Documents ─────────────────────────────────────────────────────

  Future<List<AdminDocument>> loadAdminDocuments() =>
      _loadAll('admin_documents', AdminDocument.fromJson);
  Stream<List<AdminDocument>> streamAdminDocuments() =>
      _streamAll('admin_documents', AdminDocument.fromJson);
  Future<void> saveAdminDocument(AdminDocument d) =>
      _upsert('admin_documents', d.id, d.toJson());
  Future<void> deleteAdminDocument(String id) =>
      _deleteDoc('admin_documents', id);

  // ── Driver Notifications ────────────────────────────────────────────────

  Future<List<DriverNotification>> loadDriverNotifications() =>
      _loadAll('driver_notifications', DriverNotification.fromJson);
  Stream<List<DriverNotification>> streamDriverNotifications() =>
      _streamAll('driver_notifications', DriverNotification.fromJson);
  Future<void> saveDriverNotification(DriverNotification n) =>
      _upsert('driver_notifications', n.id, n.toJson());
  Future<void> deleteDriverNotification(String id) =>
      _deleteDoc('driver_notifications', id);

  // ── Manager Alerts ──────────────────────────────────────────────────────

  Future<List<ManagerAlert>> loadManagerAlerts() =>
      _loadAll('manager_alerts', ManagerAlert.fromJson);
  Stream<List<ManagerAlert>> streamManagerAlerts() =>
      _streamAll('manager_alerts', ManagerAlert.fromJson);
  Future<void> saveManagerAlert(ManagerAlert a) =>
      _upsert('manager_alerts', a.id, a.toJson());
  Future<void> deleteManagerAlert(String id) =>
      _deleteDoc('manager_alerts', id);

  // ── Equipment ───────────────────────────────────────────────────────────

  Future<List<Equipment>> loadEquipment() =>
      _loadAll('equipment', Equipment.fromJson);
  Stream<List<Equipment>> streamEquipment() =>
      _streamAll('equipment', Equipment.fromJson);
  Future<void> saveEquipment(Equipment e) =>
      _upsert('equipment', e.id, e.toJson());
  Future<void> deleteEquipment(String id) => _deleteDoc('equipment', id);

  // ── Assignments ─────────────────────────────────────────────────────────

  Future<List<DriverAssignment>> loadAssignments() =>
      _loadAll('driver_assignments', DriverAssignment.fromJson);
  Stream<List<DriverAssignment>> streamAssignments() =>
      _streamAll('driver_assignments', DriverAssignment.fromJson);
  Future<void> saveAssignment(DriverAssignment a) =>
      _upsert('driver_assignments', a.driverName, a.toJson());
  Future<void> deleteAssignment(String driverName) =>
      _deleteDoc('driver_assignments', driverName);

  // ── Messages ────────────────────────────────────────────────────────────

  Future<List<Message>> loadMessages() => _loadAll('messages', Message.fromJson);
  Stream<List<Message>> streamMessages() => _streamAll('messages', Message.fromJson);
  Future<void> saveMessage(Message m) => _upsert('messages', m.id, m.toJson());
  Future<void> deleteMessage(String id) => _deleteDoc('messages', id);

  // ── User Accesses ───────────────────────────────────────────────────────

  Future<List<UserAccess>> loadUserAccesses() =>
      _loadAll('user_accesses', UserAccess.fromJson);
  Future<void> saveUserAccess(UserAccess u) =>
      _upsert('user_accesses', u.id, u.toJson());
  Future<void> deleteUserAccess(String id) => _deleteDoc('user_accesses', id);

  // ── Batch save helpers ──────────────────────────────────────────────────

  Future<void> saveAllTours(List<Tour> tours) async {
    final batch = _fs.batch();
    // Delete all then re-add
    final existing = await _col('tours').get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final t in tours) {
      batch.set(_col('tours').doc(t.id), t.toJson());
    }
    await batch.commit();
  }

  Future<void> saveAllDayEntries(List<DriverDayEntry> entries) async {
    final batch = _fs.batch();
    final existing = await _col('driver_day_entries').get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final e in entries) {
      batch.set(_col('driver_day_entries').doc(e.id), e.toJson());
    }
    await batch.commit();
  }

  Future<void> saveAllDrivers(List<Driver> drivers) async {
    final batch = _fs.batch();
    final existing = await _col('drivers').get();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (final d in drivers) {
      batch.set(_col('drivers').doc(d.name), d.toJson());
    }
    await batch.commit();
  }

  // ── Company settings ────────────────────────────────────────────────────

  Future<void> saveCompanySettings(Map<String, dynamic> settings) =>
      _fs.collection('companies').doc(companyId).update(settings);

  Future<Map<String, dynamic>?> loadCompanySettings() async {
    final doc = await _fs.collection('companies').doc(companyId).get();
    return doc.data();
  }

  // ── Migration: upload local data to Firestore ──────────────────────────

  Future<void> uploadLocalData({
    required List<Driver> drivers,
    required List<Truck> trucks,
    required List<Tour> tours,
    required List<Expense> expenses,
    required List<DriverDayEntry> dayEntries,
    required List<ClientPricing> clientPricings,
    required List<DriverDocument> driverDocuments,
    required List<Candidate> candidates,
    required List<AdminDocument> adminDocuments,
    required List<DriverNotification> driverNotifications,
    required List<ManagerAlert> managerAlerts,
    required List<Equipment> equipment,
    required List<DriverAssignment> assignments,
    required List<Message> messages,
  }) async {
    final batch = _fs.batch();

    for (final d in drivers) {
      batch.set(_col('drivers').doc(d.name), d.toJson());
    }
    for (final t in trucks) {
      batch.set(_col('trucks').doc(t.plate), t.toJson());
    }
    for (final t in tours) {
      batch.set(_col('tours').doc(t.id), t.toJson());
    }
    for (final e in expenses) {
      batch.set(_col('expenses').doc(e.id), e.toJson());
    }
    for (final e in dayEntries) {
      batch.set(_col('driver_day_entries').doc(e.id), e.toJson());
    }
    for (final cp in clientPricings) {
      batch.set(_col('client_pricings').doc(cp.companyName), cp.toJson());
    }
    for (final d in driverDocuments) {
      batch.set(_col('driver_documents').doc(d.id), d.toJson());
    }
    for (final c in candidates) {
      batch.set(_col('candidates').doc(c.id), c.toJson());
    }
    for (final d in adminDocuments) {
      batch.set(_col('admin_documents').doc(d.id), d.toJson());
    }
    for (final n in driverNotifications) {
      batch.set(_col('driver_notifications').doc(n.id), n.toJson());
    }
    for (final a in managerAlerts) {
      batch.set(_col('manager_alerts').doc(a.id), a.toJson());
    }
    for (final e in equipment) {
      batch.set(_col('equipment').doc(e.id), e.toJson());
    }
    for (final a in assignments) {
      batch.set(_col('driver_assignments').doc(a.driverName), a.toJson());
    }
    for (final m in messages) {
      batch.set(_col('messages').doc(m.id), m.toJson());
    }

    await batch.commit();
  }
}
