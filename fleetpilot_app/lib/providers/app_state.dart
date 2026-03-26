import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/add_truck.dart';
import '../screens/models/admin_document.dart';
import '../screens/models/candidate.dart';
import '../screens/models/client_pricing.dart';
import '../screens/models/driver.dart';
import '../screens/models/daily_assignment.dart';
import '../screens/models/driver_day_entry.dart';
import '../screens/models/driver_document.dart';
import '../screens/models/driver_notification.dart';
import '../screens/models/equipment.dart';
import '../screens/models/expense.dart';
import '../screens/models/manager_alert.dart';
import '../screens/models/message.dart';
import '../screens/models/tour.dart';
import '../screens/models/user_access.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';

/// Provider global pour le DatabaseService (overridden dans main.dart)
final databaseProvider = Provider<DatabaseService>((ref) {
  throw UnimplementedError('databaseProvider must be overridden');
});

/// Provider global pour l'état applicatif (overridden dans main.dart)
final appStateProvider = ChangeNotifierProvider<AppState>((ref) {
  throw UnimplementedError('appStateProvider must be overridden');
});

/// Provider pour le FirestoreService (initialisé après login)
final firestoreProvider = Provider<FirestoreService?>((ref) => null);

/// Provider pour l'utilisateur connecté
final currentUserProvider = StateProvider<AppUser?>((ref) => null);

class AppState extends ChangeNotifier {
  final DatabaseService _db;
  FirestoreService? _fs;

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
  List<DriverAssignment> assignments = [];
  List<Message> messages = [];
  List<UserAccess> userAccesses = [];

  AppState(this._db);

  /// Connecte Firestore après le login
  void connectFirestore(FirestoreService fs) {
    _fs = fs;
  }

  /// Upload toutes les données locales vers Firestore
  Future<void> uploadToFirestore() async {
    if (_fs == null) return;
    await _fs!.uploadLocalData(
      drivers: drivers,
      trucks: trucks,
      tours: tours,
      expenses: expenses,
      dayEntries: driverDayEntries,
      clientPricings: clientPricings,
      driverDocuments: driverDocuments,
      candidates: candidates,
      adminDocuments: adminDocuments,
      driverNotifications: driverNotifications,
      managerAlerts: managerAlerts,
      equipment: equipment,
      assignments: assignments,
      messages: messages,
    );
  }

  /// Charge les données depuis Firestore (remplace le local)
  Future<void> loadFromFirestore() async {
    if (_fs == null) return;
    trucks = await _fs!.loadTrucks();
    drivers = await _fs!.loadDrivers();
    tours = await _fs!.loadTours();
    expenses = await _fs!.loadExpenses();
    driverDayEntries = await _fs!.loadDayEntries();
    clientPricings = await _fs!.loadClientPricings();
    driverDocuments = await _fs!.loadDriverDocuments();
    candidates = await _fs!.loadCandidates();
    adminDocuments = await _fs!.loadAdminDocuments();
    driverNotifications = await _fs!.loadDriverNotifications();
    managerAlerts = await _fs!.loadManagerAlerts();
    equipment = await _fs!.loadEquipment();
    assignments = await _fs!.loadAssignments();
    messages = await _fs!.loadMessages();
    userAccesses = await _fs!.loadUserAccesses();
    notifyListeners();
  }

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
    assignments = await _db.loadAssignments();
    messages = await _db.loadMessages();
    userAccesses = await _db.loadUserAccesses();
    notifyListeners();
  }

  // ─── Camions ──────────────────────────────────────────────────────────────

  void addTruck(Truck truck) {
    trucks.add(truck);
    _db.saveTruck(truck);
    _fs?.saveTruck(truck);
    notifyListeners();
  }

  void updateTruck(String originalPlate, Truck updated) {
    final index = trucks.indexWhere((t) => t.plate == originalPlate);
    if (index != -1) trucks[index] = updated;
    if (originalPlate != updated.plate) {
      _db.deleteTruck(originalPlate);
      _fs?.deleteTruck(originalPlate);
    }
    _db.saveTruck(updated);
    _fs?.saveTruck(updated);
    notifyListeners();
  }

  void deleteTruck(String plate) {
    trucks.removeWhere((t) => t.plate == plate);
    _db.deleteTruck(plate);
    _fs?.deleteTruck(plate);
    notifyListeners();
  }

  // ─── Chauffeurs ───────────────────────────────────────────────────────────

  void addDriver(Driver driver) {
    drivers.add(driver);
    _db.saveDriver(driver);
    _fs?.saveDriver(driver);
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
      _fs?.deleteDriver(originalName);
    }
    _db.saveDriver(updated);
    _fs?.saveDriver(updated);
    _db.saveAllDayEntries(driverDayEntries);
    _fs?.saveAllDayEntries(driverDayEntries);
    _db.saveAllTours(tours);
    _fs?.saveAllTours(tours);
    notifyListeners();
  }

  void deleteDriver(String name) {
    drivers.removeWhere(
      (item) => item.name.toLowerCase() == name.toLowerCase(),
    );
    _db.deleteDriver(name);
    _fs?.deleteDriver(name);

    // Cascade : supprimer les day entries orphelines
    final orphanEntries = driverDayEntries
        .where((e) => e.driverName.toLowerCase() == name.toLowerCase())
        .toList();
    for (final e in orphanEntries) {
      driverDayEntries.remove(e);
      _db.deleteDayEntry(e.id);
      _fs?.deleteDayEntry(e.id);
    }

    // Cascade : supprimer les notifications orphelines
    final orphanNotifs = driverNotifications
        .where((n) => n.driverName.toLowerCase() == name.toLowerCase())
        .toList();
    for (final n in orphanNotifs) {
      driverNotifications.remove(n);
      _db.deleteDriverNotification(n.id);
      _fs?.deleteDriverNotification(n.id);
    }

    // Cascade : supprimer les documents orphelins
    final orphanDocs = driverDocuments
        .where((d) => d.driverName.toLowerCase() == name.toLowerCase())
        .toList();
    for (final d in orphanDocs) {
      driverDocuments.remove(d);
      _db.deleteDriverDocument(d.id);
      _fs?.deleteDriverDocument(d.id);
    }

    notifyListeners();
  }

  // ─── Entrées journalières ─────────────────────────────────────────────────

  void addDriverDayEntry(DriverDayEntry entry) {
    driverDayEntries.add(entry);
    _db.saveDayEntry(entry);
    _fs?.saveDayEntry(entry);
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
        _fs?.saveDayEntry(updated);
      }
    }
    notifyListeners();
  }

  // ─── Tournées ─────────────────────────────────────────────────────────────

  void addTour(Tour tour) {
    tours.add(tour);
    _db.saveTour(tour);
    _fs?.saveTour(tour);
    notifyListeners();
  }

  void updateTour(String id, Tour updated) {
    final index = tours.indexWhere((item) => item.id == id);
    if (index != -1) tours[index] = updated;
    _db.saveTour(updated);
    _fs?.saveTour(updated);

    // Recalculer le day entry à partir de toutes les tours du jour
    _recalcDayEntry(updated.driverName, updated.date);
    notifyListeners();
  }

  void deleteTour(String id) {
    final tour = tours.where((item) => item.id == id).firstOrNull;
    tours.removeWhere((item) => item.id == id);
    _db.deleteTour(id);
    _fs?.deleteTour(id);

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
        _fs?.deleteDayEntry(entryId);
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
      _fs?.saveDayEntry(updated);
    }
  }

  // ─── Dépenses ─────────────────────────────────────────────────────────────

  void addExpense(Expense expense) {
    expenses.add(expense);
    _db.saveExpense(expense);
    _fs?.saveExpense(expense);
    _syncExpenseToTruckHistory(expense);
    notifyListeners();
  }

  void updateExpense(String id, Expense updated) {
    final index = expenses.indexWhere((e) => e.id == id);
    if (index != -1) expenses[index] = updated;
    _db.saveExpense(updated);
    _fs?.saveExpense(updated);
    // Supprimer l'ancienne entrée et re-sync
    _removeServiceEntryFromTruck(id);
    _syncExpenseToTruckHistory(updated);
    notifyListeners();
  }

  void deleteExpense(String id) {
    expenses.removeWhere((e) => e.id == id);
    _db.deleteExpense(id);
    _fs?.deleteExpense(id);
    _removeServiceEntryFromTruck(id);
    notifyListeners();
  }

  /// Ajoute automatiquement une dépense dans l'historique du camion
  void _syncExpenseToTruckHistory(Expense expense) {
    final truckIdx = trucks.indexWhere((t) => t.plate == expense.truckPlate);
    if (truckIdx == -1) return;

    final truck = trucks[truckIdx];
    final entry = ServiceEntry(
      id: 'exp_${expense.id}',
      date: expense.date,
      description: expense.note ?? expenseTypeLabel(expense.type),
      cost: expense.amount,
    );

    // Réparations → historique réparations
    if (expense.type == ExpenseType.repair) {
      trucks[truckIdx] = truck.copyWith(
        repairs: [...truck.repairs, entry],
      );
    } else {
      // Carburant, matériel, autre → historique entretiens
      trucks[truckIdx] = truck.copyWith(
        maintenances: [...truck.maintenances, entry],
      );
    }
    _db.saveTruck(trucks[truckIdx]);
    _fs?.saveTruck(trucks[truckIdx]);
  }

  /// Supprime une entrée liée à une dépense de l'historique camion
  void _removeServiceEntryFromTruck(String expenseId) {
    final serviceId = 'exp_$expenseId';
    for (int i = 0; i < trucks.length; i++) {
      final truck = trucks[i];
      final hadRepair = truck.repairs.any((e) => e.id == serviceId);
      final hadMaint = truck.maintenances.any((e) => e.id == serviceId);
      if (hadRepair || hadMaint) {
        trucks[i] = truck.copyWith(
          repairs: truck.repairs.where((e) => e.id != serviceId).toList(),
          maintenances: truck.maintenances.where((e) => e.id != serviceId).toList(),
        );
        _db.saveTruck(trucks[i]);
        break;
      }
    }
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
    _fs?.saveDriverDocument(doc);
    notifyListeners();
  }

  void updateDriverDocument(String id, DriverDocument updated) {
    final index = driverDocuments.indexWhere((d) => d.id == id);
    if (index != -1) driverDocuments[index] = updated;
    _db.saveDriverDocument(updated);
    _fs?.saveDriverDocument(updated);
    notifyListeners();
  }

  void deleteDriverDocument(String id) {
    driverDocuments.removeWhere((d) => d.id == id);
    _db.deleteDriverDocument(id);
    _fs?.deleteDriverDocument(id);
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
    _fs?.saveCandidate(candidate);
    notifyListeners();
  }

  void updateCandidate(String id, Candidate updated) {
    final index = candidates.indexWhere((c) => c.id == id);
    if (index != -1) candidates[index] = updated;
    _db.saveCandidate(updated);
    _fs?.saveCandidate(updated);
    notifyListeners();
  }

  void deleteCandidate(String id) {
    candidates.removeWhere((c) => c.id == id);
    _db.deleteCandidate(id);
    _fs?.deleteCandidate(id);
    notifyListeners();
  }

  // ─── Documents administratifs entreprise ──────────────────────────────────

  void addAdminDocument(AdminDocument doc) {
    adminDocuments.add(doc);
    _db.saveAdminDocument(doc);
    _fs?.saveAdminDocument(doc);
    _syncAdminDocToTruck(doc);
    notifyListeners();
  }

  void updateAdminDocument(String id, AdminDocument updated) {
    final i = adminDocuments.indexWhere((d) => d.id == id);
    if (i != -1) adminDocuments[i] = updated;
    _db.saveAdminDocument(updated);
    _fs?.saveAdminDocument(updated);
    _syncAdminDocToTruck(updated);
    notifyListeners();
  }

  void deleteAdminDocument(String id) {
    adminDocuments.removeWhere((d) => d.id == id);
    _db.deleteAdminDocument(id);
    _fs?.deleteAdminDocument(id);
    notifyListeners();
  }

  /// Synchronise un document admin avec le camion lié
  void _syncAdminDocToTruck(AdminDocument doc) {
    if (doc.linkedTruckPlate == null || doc.linkedTruckPlate!.isEmpty) return;

    final truckIdx = trucks.indexWhere((t) => t.plate == doc.linkedTruckPlate);
    if (truckIdx == -1) return;

    final truck = trucks[truckIdx];

    // Assurance → met à jour les infos assurance du camion
    if (doc.category == AdminDocCategory.assurance) {
      trucks[truckIdx] = truck.copyWith(
        insurerName: doc.title,
        insuranceStart: doc.date,
      );
      _db.saveTruck(trucks[truckIdx]);
    _fs?.saveTruck(trucks[truckIdx]);
    }

    // Contrat location → met à jour le loueur
    if (doc.category == AdminDocCategory.contratLocation) {
      trucks[truckIdx] = truck.copyWith(
        rentCompany: doc.title,
      );
      _db.saveTruck(trucks[truckIdx]);
      _fs?.saveTruck(trucks[truckIdx]);
    }

    // Facture prestataire → ajoute dans l'historique entretiens/réparations
    if (doc.category == AdminDocCategory.facturePrestataire) {
      final entry = ServiceEntry(
        id: 'doc_${doc.id}',
        date: doc.date,
        description: doc.title + (doc.note != null ? ' — ${doc.note}' : ''),
      );
      trucks[truckIdx] = truck.copyWith(
        maintenances: [...truck.maintenances, entry],
      );
      _db.saveTruck(trucks[truckIdx]);
      _fs?.saveTruck(trucks[truckIdx]);
    }
  }

  // ─── Tarification clients ─────────────────────────────────────────────────

  void addClientPricing(ClientPricing pricing) {
    clientPricings.add(pricing);
    _db.saveClientPricing(pricing);
    _fs?.saveClientPricing(pricing);
    notifyListeners();
  }

  void updateClientPricing(String companyName, ClientPricing updated) {
    final index = clientPricings.indexWhere(
      (item) => item.companyName.toLowerCase() == companyName.toLowerCase(),
    );
    if (index != -1) clientPricings[index] = updated;
    if (companyName.toLowerCase() != updated.companyName.toLowerCase()) {
      _db.deleteClientPricing(companyName);
      _fs?.deleteClientPricing(companyName);
    }
    _db.saveClientPricing(updated);
    _fs?.saveClientPricing(updated);
    notifyListeners();
  }

  void deleteClientPricing(String companyName) {
    clientPricings.removeWhere(
      (item) => item.companyName.toLowerCase() == companyName.toLowerCase(),
    );
    _db.deleteClientPricing(companyName);
    _fs?.deleteClientPricing(companyName);
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
    _fs?.saveDriverNotification(n);
    notifyListeners();
  }

  void markNotificationRead(String id) {
    final i = driverNotifications.indexWhere((n) => n.id == id);
    if (i != -1) {
      driverNotifications[i] = driverNotifications[i].copyWith(read: true);
      _db.saveDriverNotification(driverNotifications[i]);
      _fs?.saveDriverNotification(driverNotifications[i]);
      notifyListeners();
    }
  }

  void deleteDriverNotification(String id) {
    driverNotifications.removeWhere((n) => n.id == id);
    _db.deleteDriverNotification(id);
    _fs?.deleteDriverNotification(id);
    notifyListeners();
  }

  // ─── Alertes manager ──────────────────────────────────────────────────

  int get unreadManagerAlertCount =>
      managerAlerts.where((a) => !a.read).length;

  void addManagerAlert(ManagerAlert alert) {
    managerAlerts.add(alert);
    _db.saveManagerAlert(alert);
    _fs?.saveManagerAlert(alert);
    notifyListeners();
  }

  void markManagerAlertRead(String id) {
    final i = managerAlerts.indexWhere((a) => a.id == id);
    if (i != -1) {
      managerAlerts[i] = managerAlerts[i].copyWith(read: true);
      _db.saveManagerAlert(managerAlerts[i]);
      _fs?.saveManagerAlert(managerAlerts[i]);
      notifyListeners();
    }
  }

  void deleteManagerAlert(String id) {
    managerAlerts.removeWhere((a) => a.id == id);
    _db.deleteManagerAlert(id);
    _fs?.deleteManagerAlert(id);
    notifyListeners();
  }

  // ─── Messagerie ─────────────────────────────────────────────────────────

  /// Messages d'une conversation (chauffeur ↔ manager)
  List<Message> messagesForDriver(String driverName) {
    return messages
        .where((m) => m.conversationId.toLowerCase() == driverName.toLowerCase())
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  /// Conversations distinctes (liste des chauffeurs avec messages)
  List<String> get conversationDriverNames {
    final names = <String>{};
    for (final m in messages) {
      names.add(m.conversationId);
    }
    return names.toList()..sort();
  }

  /// Nombre de messages non lus pour un chauffeur
  int unreadMessagesForDriver(String driverName) {
    return messages
        .where((m) =>
            m.conversationId.toLowerCase() == driverName.toLowerCase() &&
            !m.read &&
            m.isFromManager)
        .length;
  }

  /// Nombre de messages non lus côté manager (envoyés par les chauffeurs)
  int get unreadManagerMessages {
    return messages.where((m) => !m.read && !m.isFromManager).length;
  }

  /// Nombre de messages non lus pour une conversation côté manager
  int unreadManagerMessagesFor(String driverName) {
    return messages
        .where((m) =>
            m.conversationId.toLowerCase() == driverName.toLowerCase() &&
            !m.read &&
            !m.isFromManager)
        .length;
  }

  void addMessage(Message m) {
    messages.add(m);
    _db.saveMessage(m);
    _fs?.saveMessage(m);
    notifyListeners();
  }

  void markMessageRead(String id) {
    final i = messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      messages[i] = messages[i].copyWith(read: true);
      _db.saveMessage(messages[i]);
      _fs?.saveMessage(messages[i]);
      notifyListeners();
    }
  }

  void markConversationRead(String driverName, {required bool asManager}) {
    for (int i = 0; i < messages.length; i++) {
      final m = messages[i];
      if (m.conversationId.toLowerCase() == driverName.toLowerCase() &&
          !m.read &&
          (asManager ? !m.isFromManager : m.isFromManager)) {
        messages[i] = m.copyWith(read: true);
        _db.saveMessage(messages[i]);
        _fs?.saveMessage(messages[i]);
      }
    }
    notifyListeners();
  }

  void deleteMessage(String id) {
    messages.removeWhere((m) => m.id == id);
    _db.deleteMessage(id);
    _fs?.deleteMessage(id);
    notifyListeners();
  }

  // ─── Matériel ─────────────────────────────────────────────────────────

  void addEquipment(Equipment e) {
    equipment.add(e);
    _db.saveEquipment(e);
    _fs?.saveEquipment(e);
    notifyListeners();
  }

  void updateEquipment(String id, Equipment updated) {
    final i = equipment.indexWhere((e) => e.id == id);
    if (i != -1) equipment[i] = updated;
    _db.saveEquipment(updated);
    _fs?.saveEquipment(updated);
    notifyListeners();
  }

  void deleteEquipment(String id) {
    equipment.removeWhere((e) => e.id == id);
    _db.deleteEquipment(id);
    _fs?.deleteEquipment(id);
    notifyListeners();
  }

  // ─── Affectations chauffeur → camion + commissionnaire ─────────────

  DriverAssignment? getAssignment(String driverName) {
    try {
      return assignments.firstWhere(
        (a) => a.driverName.toLowerCase() == driverName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void setAssignment(DriverAssignment assignment) {
    final index = assignments.indexWhere(
      (a) => a.driverName.toLowerCase() == assignment.driverName.toLowerCase(),
    );
    if (index != -1) {
      assignments[index] = assignment;
    } else {
      assignments.add(assignment);
    }
    _db.saveAssignment(assignment);
    _fs?.saveAssignment(assignment);
    notifyListeners();
  }

  void removeAssignment(String driverName) {
    assignments.removeWhere(
      (a) => a.driverName.toLowerCase() == driverName.toLowerCase(),
    );
    _db.deleteAssignment(driverName);
    _fs?.deleteAssignment(driverName);
    notifyListeners();
  }

  // ─── Accès utilisateurs ──────────────────────────────────────────────

  void addUserAccess(UserAccess u) {
    userAccesses.add(u);
    _db.saveUserAccess(u);
    _fs?.saveUserAccess(u);
    notifyListeners();
  }

  void updateUserAccess(String id, UserAccess updated) {
    final i = userAccesses.indexWhere((u) => u.id == id);
    if (i != -1) userAccesses[i] = updated;
    _db.saveUserAccess(updated);
    _fs?.saveUserAccess(updated);
    notifyListeners();
  }

  void deleteUserAccess(String id) {
    userAccesses.removeWhere((u) => u.id == id);
    _db.deleteUserAccess(id);
    _fs?.deleteUserAccess(id);
    notifyListeners();
  }
}
