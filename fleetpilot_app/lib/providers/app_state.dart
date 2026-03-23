import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/add_truck.dart';
import '../screens/models/admin_document.dart';
import '../screens/models/candidate.dart';
import '../screens/models/client_pricing.dart';
import '../screens/models/driver.dart';
import '../screens/models/driver_day_entry.dart';
import '../screens/models/driver_document.dart';
import '../screens/models/driver_notification.dart';
import '../screens/models/equipment.dart';
import '../screens/models/expense.dart';
import '../screens/models/manager_alert.dart';
import '../screens/models/tour.dart';
import '../services/database_service.dart';

/// Provider global pour le DatabaseService (overridden dans main.dart)
final databaseProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

/// Provider global pour l'état applicatif (overridden dans main.dart)
final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  throw UnimplementedError('appStateProvider must be overridden');
});

class AppState extends ChangeNotifier {
  final DatabaseService _db;

  List<Truck> trucks = [];
  List<Driver> drivers = [];
  List<Tour> tours = [];
  List<Expense> expenses = [];
  List<DriverDayEntry> driverDayEntries = [];
  List<ClientPricing> clientPricings = [];
  List<DriverDocument> driverDocuments = [];
  List<Candidate> candidates = [];
  List<AdminDocument> adminDocuments = [];
  List<DriverNotification> driverNotifications = [];
  List<ManagerAlert> managerAlerts = [];
  List<Equipment> equipment = [];

  AppState(this._db);

  Future<void> init() async {
    trucks = await _db.loadTrucks();
    drivers = await _db.loadDrivers();
    tours = await _db.loadTours();
    expenses = await _db.loadExpenses();
    driverDayEntries = await _db.loadDayEntries();
    clientPricings = await _db.loadClientPricings();
    driverDocuments = await _db.loadDriverDocuments();
    candidates = await _db.loadCandidates();
    adminDocuments = await _db.loadAdminDocuments();
    driverNotifications = await _db.loadDriverNotifications();
    managerAlerts = await _db.loadManagerAlerts();
    equipment = await _db.loadEquipment();
    notifyListeners();
  }

  // ─── Camions ──────────────────────────────────────────────────────────────

  void addTruck(Truck truck) {
    trucks.add(truck);
    _db.saveTruck(truck);
    notifyListeners();
  }

  void updateTruck(String originalPlate, Truck updated) {
    final index = trucks.indexWhere((t) => t.plate == originalPlate);
    if (index != -1) trucks[index] = updated;
    if (originalPlate != updated.plate) {
      _db.deleteTruck(originalPlate);
    }
    _db.saveTruck(updated);
    notifyListeners();
  }

  void deleteTruck(String plate) {
    trucks.removeWhere((t) => t.plate == plate);
    _db.deleteTruck(plate);
    notifyListeners();
  }

  // ─── Chauffeurs ───────────────────────────────────────────────────────────

  void addDriver(Driver driver) {
    drivers.add(driver);
    _db.saveDriver(driver);
    notifyListeners();
  }

  void updateDriver(String originalName, Driver updated) {
    final index = drivers.indexWhere(
      (item) => item.name.toLowerCase() == originalName.toLowerCase(),
    );
    if (index != -1) drivers[index] = updated;

    // Cascade: update driver name in day entries
    for (int i = 0; i < driverDayEntries.length; i++) {
      final entry = driverDayEntries[i];
      if (entry.driverName.toLowerCase() == originalName.toLowerCase()) {
        driverDayEntries[i] = DriverDayEntry(
          id: entry.id,
          date: entry.date,
          driverName: updated.name,
          truckPlate: entry.truckPlate,
          kmTotal: entry.kmTotal,
          clientsCount: entry.clientsCount,
        );
      }
    }

    // Cascade: update driver name in tours
    for (int i = 0; i < tours.length; i++) {
      final tour = tours[i];
      if (tour.driverName.toLowerCase() == originalName.toLowerCase()) {
        tours[i] = Tour(
          id: tour.id,
          tourNumber: tour.tourNumber,
          date: tour.date,
          driverName: updated.name,
          truckPlate: tour.truckPlate,
          companyName: tour.companyName,
          sector: tour.sector,
          startTime: tour.startTime,
          endTime: tour.endTime,
          breakTime: tour.breakTime,
          kmTotal: tour.kmTotal,
          clientsCount: tour.clientsCount,
          weightKg: tour.weightKg,
          hasHandling: tour.hasHandling,
          handlingClientName: tour.handlingClientName,
          handlingDate: tour.handlingDate,
          extraKm: tour.extraKm,
          extraTour: tour.extraTour,
        );
      }
    }

    if (originalName.toLowerCase() != updated.name.toLowerCase()) {
      _db.deleteDriver(originalName);
    }
    _db.saveDriver(updated);
    _db.saveAllDayEntries(driverDayEntries);
    _db.saveAllTours(tours);
    notifyListeners();
  }

  void deleteDriver(String name) {
    drivers.removeWhere(
      (item) => item.name.toLowerCase() == name.toLowerCase(),
    );
    _db.deleteDriver(name);

    // Cascade : supprimer les day entries orphelines
    final orphanEntries = driverDayEntries
        .where((e) => e.driverName.toLowerCase() == name.toLowerCase())
        .toList();
    for (final e in orphanEntries) {
      driverDayEntries.remove(e);
      _db.deleteDayEntry(e.id);
    }

    // Cascade : supprimer les notifications orphelines
    final orphanNotifs = driverNotifications
        .where((n) => n.driverName.toLowerCase() == name.toLowerCase())
        .toList();
    for (final n in orphanNotifs) {
      driverNotifications.remove(n);
      _db.deleteDriverNotification(n.id);
    }

    // Cascade : supprimer les documents orphelins
    final orphanDocs = driverDocuments
        .where((d) => d.driverName.toLowerCase() == name.toLowerCase())
        .toList();
    for (final d in orphanDocs) {
      driverDocuments.remove(d);
      _db.deleteDriverDocument(d.id);
    }

    notifyListeners();
  }

  // ─── Entrées journalières ─────────────────────────────────────────────────

  void addDriverDayEntry(DriverDayEntry entry) {
    driverDayEntries.add(entry);
    _db.saveDayEntry(entry);
    notifyListeners();
  }

  void updateDriverDayEntryTruck({
    required String driverName,
    required DateTime date,
    required String newTruckPlate,
  }) {
    for (int i = 0; i < driverDayEntries.length; i++) {
      final entry = driverDayEntries[i];
      if (entry.driverName == driverName &&
          entry.date.year == date.year &&
          entry.date.month == date.month &&
          entry.date.day == date.day) {
        final updated = DriverDayEntry(
          id: entry.id,
          date: entry.date,
          driverName: entry.driverName,
          truckPlate: newTruckPlate,
          kmTotal: entry.kmTotal,
          clientsCount: entry.clientsCount,
        );
        driverDayEntries[i] = updated;
        _db.saveDayEntry(updated);
      }
    }
    notifyListeners();
  }

  // ─── Tournées ─────────────────────────────────────────────────────────────

  void addTour(Tour tour) {
    tours.add(tour);
    _db.saveTour(tour);
    notifyListeners();
  }

  void updateTour(String id, Tour updated) {
    final index = tours.indexWhere((item) => item.id == id);
    if (index != -1) tours[index] = updated;
    _db.saveTour(updated);

    // Recalculer le day entry à partir de toutes les tours du jour
    _recalcDayEntry(updated.driverName, updated.date);
    notifyListeners();
  }

  void deleteTour(String id) {
    final tour = tours.where((item) => item.id == id).firstOrNull;
    tours.removeWhere((item) => item.id == id);
    _db.deleteTour(id);

    // Recalculer les day entries pour ce chauffeur/jour
    if (tour != null) {
      _recalcDayEntry(tour.driverName, tour.date);
    }
    notifyListeners();
  }

  /// Recalcule le DriverDayEntry pour un chauffeur/jour à partir des tours restantes
  void _recalcDayEntry(String driverName, DateTime date) {
    final dayTours = tours.where((t) =>
        t.driverName.toLowerCase() == driverName.toLowerCase() &&
        t.date.year == date.year &&
        t.date.month == date.month &&
        t.date.day == date.day).toList();

    // Trouver l'entrée existante
    final entryIdx = driverDayEntries.indexWhere((e) =>
        e.driverName.toLowerCase() == driverName.toLowerCase() &&
        e.date.year == date.year &&
        e.date.month == date.month &&
        e.date.day == date.day);

    if (dayTours.isEmpty) {
      // Plus de tournées ce jour → supprimer l'entrée
      if (entryIdx != -1) {
        final entryId = driverDayEntries[entryIdx].id;
        driverDayEntries.removeAt(entryIdx);
        _db.deleteDayEntry(entryId);
      }
    } else if (entryIdx != -1) {
      // Mettre à jour avec les totaux agrégés
      final totalKm = dayTours.fold(0.0, (s, t) => s + t.kmTotal);
      final totalClients = dayTours.fold(0, (s, t) => s + t.clientsCount);
      final updated = DriverDayEntry(
        id: driverDayEntries[entryIdx].id,
        date: driverDayEntries[entryIdx].date,
        driverName: dayTours.first.driverName,
        truckPlate: dayTours.last.truckPlate,
        kmTotal: totalKm,
        clientsCount: totalClients,
      );
      driverDayEntries[entryIdx] = updated;
      _db.saveDayEntry(updated);
    }
  }

  // ─── Dépenses ─────────────────────────────────────────────────────────────

  void addExpense(Expense expense) {
    expenses.add(expense);
    _db.saveExpense(expense);
    notifyListeners();
  }

  void updateExpense(String id, Expense updated) {
    final index = expenses.indexWhere((e) => e.id == id);
    if (index != -1) expenses[index] = updated;
    _db.saveExpense(updated);
    notifyListeners();
  }

  void deleteExpense(String id) {
    expenses.removeWhere((e) => e.id == id);
    _db.deleteExpense(id);
    notifyListeners();
  }

  // ─── Documents chauffeurs ─────────────────────────────────────────────────

  List<DriverDocument> documentsForDriver(String driverName) {
    return driverDocuments
        .where((d) => d.driverName.toLowerCase() == driverName.toLowerCase())
        .toList();
  }

  void addDriverDocument(DriverDocument doc) {
    driverDocuments.add(doc);
    _db.saveDriverDocument(doc);
    notifyListeners();
  }

  void updateDriverDocument(String id, DriverDocument updated) {
    final index = driverDocuments.indexWhere((d) => d.id == id);
    if (index != -1) driverDocuments[index] = updated;
    _db.saveDriverDocument(updated);
    notifyListeners();
  }

  void deleteDriverDocument(String id) {
    driverDocuments.removeWhere((d) => d.id == id);
    _db.deleteDriverDocument(id);
    notifyListeners();
  }

  List<DriverDocument> get alertDocuments {
    return driverDocuments
        .where((d) => d.alertLevel == 'expired' || d.alertLevel == 'warning')
        .toList()
      ..sort((a, b) {
        final da = a.daysUntilExpiry ?? 999;
        final db = b.daysUntilExpiry ?? 999;
        return da.compareTo(db);
      });
  }

  // ─── Candidats ────────────────────────────────────────────────────────────

  void addCandidate(Candidate candidate) {
    candidates.add(candidate);
    _db.saveCandidate(candidate);
    notifyListeners();
  }

  void updateCandidate(String id, Candidate updated) {
    final index = candidates.indexWhere((c) => c.id == id);
    if (index != -1) candidates[index] = updated;
    _db.saveCandidate(updated);
    notifyListeners();
  }

  void deleteCandidate(String id) {
    candidates.removeWhere((c) => c.id == id);
    _db.deleteCandidate(id);
    notifyListeners();
  }

  // ─── Documents administratifs entreprise ──────────────────────────────────

  void addAdminDocument(AdminDocument doc) {
    adminDocuments.add(doc);
    _db.saveAdminDocument(doc);
    notifyListeners();
  }

  void updateAdminDocument(String id, AdminDocument updated) {
    final i = adminDocuments.indexWhere((d) => d.id == id);
    if (i != -1) adminDocuments[i] = updated;
    _db.saveAdminDocument(updated);
    notifyListeners();
  }

  void deleteAdminDocument(String id) {
    adminDocuments.removeWhere((d) => d.id == id);
    _db.deleteAdminDocument(id);
    notifyListeners();
  }

  // ─── Tarification clients ─────────────────────────────────────────────────

  void addClientPricing(ClientPricing pricing) {
    clientPricings.add(pricing);
    _db.saveClientPricing(pricing);
    notifyListeners();
  }

  void updateClientPricing(String companyName, ClientPricing updated) {
    final index = clientPricings.indexWhere(
      (item) => item.companyName.toLowerCase() == companyName.toLowerCase(),
    );
    if (index != -1) clientPricings[index] = updated;
    if (companyName.toLowerCase() != updated.companyName.toLowerCase()) {
      _db.deleteClientPricing(companyName);
    }
    _db.saveClientPricing(updated);
    notifyListeners();
  }

  void deleteClientPricing(String companyName) {
    clientPricings.removeWhere(
      (item) => item.companyName.toLowerCase() == companyName.toLowerCase(),
    );
    _db.deleteClientPricing(companyName);
    notifyListeners();
  }

  ClientPricing? getClientPricing(String? companyName) {
    if (companyName == null || companyName.trim().isEmpty) return null;
    try {
      return clientPricings.firstWhere(
        (item) => item.companyName.toLowerCase() == companyName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  // ─── Notifications chauffeur ────────────────────────────────────────────

  List<DriverNotification> notificationsForDriver(String driverName) {
    return driverNotifications
        .where((n) => n.driverName.toLowerCase() == driverName.toLowerCase())
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  int unreadCountForDriver(String driverName) {
    return driverNotifications
        .where((n) =>
            n.driverName.toLowerCase() == driverName.toLowerCase() && !n.read)
        .length;
  }

  void addDriverNotification(DriverNotification n) {
    driverNotifications.add(n);
    _db.saveDriverNotification(n);
    notifyListeners();
  }

  void markNotificationRead(String id) {
    final i = driverNotifications.indexWhere((n) => n.id == id);
    if (i != -1) {
      driverNotifications[i] = driverNotifications[i].copyWith(read: true);
      _db.saveDriverNotification(driverNotifications[i]);
      notifyListeners();
    }
  }

  void deleteDriverNotification(String id) {
    driverNotifications.removeWhere((n) => n.id == id);
    _db.deleteDriverNotification(id);
    notifyListeners();
  }

  // ─── Alertes manager ──────────────────────────────────────────────────

  int get unreadManagerAlertCount =>
      managerAlerts.where((a) => !a.read).length;

  void addManagerAlert(ManagerAlert alert) {
    managerAlerts.add(alert);
    _db.saveManagerAlert(alert);
    notifyListeners();
  }

  void markManagerAlertRead(String id) {
    final i = managerAlerts.indexWhere((a) => a.id == id);
    if (i != -1) {
      managerAlerts[i] = managerAlerts[i].copyWith(read: true);
      _db.saveManagerAlert(managerAlerts[i]);
      notifyListeners();
    }
  }

  void deleteManagerAlert(String id) {
    managerAlerts.removeWhere((a) => a.id == id);
    _db.deleteManagerAlert(id);
    notifyListeners();
  }

  // ─── Matériel ─────────────────────────────────────────────────────────

  void addEquipment(Equipment e) {
    equipment.add(e);
    _db.saveEquipment(e);
    notifyListeners();
  }

  void updateEquipment(String id, Equipment updated) {
    final i = equipment.indexWhere((e) => e.id == id);
    if (i != -1) equipment[i] = updated;
    _db.saveEquipment(updated);
    notifyListeners();
  }

  void deleteEquipment(String id) {
    equipment.removeWhere((e) => e.id == id);
    _db.deleteEquipment(id);
    notifyListeners();
  }
}
