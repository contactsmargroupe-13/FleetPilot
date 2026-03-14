import '../screens/add_truck.dart';
import '../screens/models/admin_document.dart';
import '../screens/models/candidate.dart';
import '../screens/models/client_pricing.dart';
import '../screens/models/driver.dart';
import '../screens/models/driver_day_entry.dart';
import '../screens/models/driver_document.dart';
import '../screens/models/expense.dart';
import '../screens/models/tour.dart';
import '../services/storage_service.dart';

class AppStore {
  static late List<Truck> trucks;
  static late List<Expense> expenses;
  static late List<Driver> drivers;
  static late List<DriverDayEntry> driverDayEntries;
  static late List<Tour> tours;
  static late List<ClientPricing> clientPricings;
  static late List<DriverDocument> driverDocuments;
  static late List<Candidate> candidates;
  static late List<AdminDocument> adminDocuments;

  /// À appeler une seule fois au démarrage de l'application.
  static Future<void> init() async {
    await StorageService.init();
    trucks = StorageService.loadTrucks();
    expenses = StorageService.loadExpenses();
    drivers = StorageService.loadDrivers();
    driverDayEntries = StorageService.loadDayEntries();
    tours = StorageService.loadTours();
    clientPricings = StorageService.loadClientPricings();
    driverDocuments = StorageService.loadDriverDocuments();
    candidates = StorageService.loadCandidates();
    adminDocuments = StorageService.loadAdminDocuments();
  }

  // ─── Camions ────────────────────────────────────────────────────────────────

  static void addTruck(Truck truck) {
    trucks.add(truck);
    StorageService.saveTrucks(trucks);
  }

  static void updateTruck(String originalPlate, Truck updated) {
    final index = trucks.indexWhere((t) => t.plate == originalPlate);
    if (index != -1) {
      trucks[index] = updated;
    }
    StorageService.saveTrucks(trucks);
  }

  static void deleteTruck(String plate) {
    trucks.removeWhere((t) => t.plate == plate);
    StorageService.saveTrucks(trucks);
  }

  // ─── Chauffeurs ─────────────────────────────────────────────────────────────

  static void addDriver(Driver driver) {
    drivers.add(driver);
    StorageService.saveDrivers(drivers);
  }

  static void updateDriver(String originalName, Driver updated) {
    final index = drivers.indexWhere(
      (item) => item.name.toLowerCase() == originalName.toLowerCase(),
    );

    if (index != -1) {
      drivers[index] = updated;
    }

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

    StorageService.saveDrivers(drivers);
    StorageService.saveDayEntries(driverDayEntries);
    StorageService.saveTours(tours);
  }

  static void deleteDriver(String name) {
    drivers.removeWhere(
      (item) => item.name.toLowerCase() == name.toLowerCase(),
    );
    StorageService.saveDrivers(drivers);
  }

  // ─── Entrées journalières ───────────────────────────────────────────────────

  static void addDriverDayEntry(DriverDayEntry entry) {
    driverDayEntries.add(entry);
    StorageService.saveDayEntries(driverDayEntries);
  }

  static void updateDriverDayEntryTruck({
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
        driverDayEntries[i] = DriverDayEntry(
          id: entry.id,
          date: entry.date,
          driverName: entry.driverName,
          truckPlate: newTruckPlate,
          kmTotal: entry.kmTotal,
          clientsCount: entry.clientsCount,
        );
      }
    }
    StorageService.saveDayEntries(driverDayEntries);
  }

  // ─── Tournées ───────────────────────────────────────────────────────────────

  static void addTour(Tour tour) {
    tours.add(tour);
    StorageService.saveTours(tours);
  }

  static void updateTour(String id, Tour updated) {
    final index = tours.indexWhere((item) => item.id == id);

    if (index != -1) {
      tours[index] = updated;
    }

    for (int i = 0; i < driverDayEntries.length; i++) {
      final entry = driverDayEntries[i];

      if (entry.date.year == updated.date.year &&
          entry.date.month == updated.date.month &&
          entry.date.day == updated.date.day &&
          entry.driverName.toLowerCase() == updated.driverName.toLowerCase()) {
        driverDayEntries[i] = DriverDayEntry(
          id: entry.id,
          date: entry.date,
          driverName: updated.driverName,
          truckPlate: updated.truckPlate,
          kmTotal: updated.kmTotal,
          clientsCount: updated.clientsCount,
        );
      }
    }

    StorageService.saveTours(tours);
    StorageService.saveDayEntries(driverDayEntries);
  }

  static void deleteTour(String id) {
    tours.removeWhere((item) => item.id == id);
    StorageService.saveTours(tours);
  }

  // ─── Dépenses ───────────────────────────────────────────────────────────────

  static void addExpense(Expense expense) {
    expenses.add(expense);
    StorageService.saveExpenses(expenses);
  }

  static void deleteExpense(String id) {
    expenses.removeWhere((e) => e.id == id);
    StorageService.saveExpenses(expenses);
  }

  // ─── Documents administratifs ───────────────────────────────────────────────

  static List<DriverDocument> documentsForDriver(String driverName) {
    return driverDocuments
        .where((d) => d.driverName.toLowerCase() == driverName.toLowerCase())
        .toList();
  }

  static void addDriverDocument(DriverDocument doc) {
    driverDocuments.add(doc);
    StorageService.saveDriverDocuments(driverDocuments);
  }

  static void updateDriverDocument(String id, DriverDocument updated) {
    final index = driverDocuments.indexWhere((d) => d.id == id);
    if (index != -1) driverDocuments[index] = updated;
    StorageService.saveDriverDocuments(driverDocuments);
  }

  static void deleteDriverDocument(String id) {
    driverDocuments.removeWhere((d) => d.id == id);
    StorageService.saveDriverDocuments(driverDocuments);
  }

  /// Retourne tous les documents en alerte (expirés ou expirant bientôt)
  static List<DriverDocument> get alertDocuments {
    return driverDocuments
        .where((d) => d.alertLevel == 'expired' || d.alertLevel == 'warning')
        .toList()
      ..sort((a, b) {
        final da = a.daysUntilExpiry ?? 999;
        final db = b.daysUntilExpiry ?? 999;
        return da.compareTo(db);
      });
  }

  // ─── Candidats recrutement ──────────────────────────────────────────────────

  static void addCandidate(Candidate candidate) {
    candidates.add(candidate);
    StorageService.saveCandidates(candidates);
  }

  static void updateCandidate(String id, Candidate updated) {
    final index = candidates.indexWhere((c) => c.id == id);
    if (index != -1) candidates[index] = updated;
    StorageService.saveCandidates(candidates);
  }

  static void deleteCandidate(String id) {
    candidates.removeWhere((c) => c.id == id);
    StorageService.saveCandidates(candidates);
  }

  // ─── Documents administratifs entreprise ────────────────────────────────────

  static void addAdminDocument(AdminDocument doc) {
    adminDocuments.add(doc);
    StorageService.saveAdminDocuments(adminDocuments);
  }

  static void updateAdminDocument(String id, AdminDocument updated) {
    final i = adminDocuments.indexWhere((d) => d.id == id);
    if (i != -1) adminDocuments[i] = updated;
    StorageService.saveAdminDocuments(adminDocuments);
  }

  static void deleteAdminDocument(String id) {
    adminDocuments.removeWhere((d) => d.id == id);
    StorageService.saveAdminDocuments(adminDocuments);
  }

  // ─── Tarification clients ───────────────────────────────────────────────────

  static void addClientPricing(ClientPricing pricing) {
    clientPricings.add(pricing);
    StorageService.saveClientPricings(clientPricings);
  }

  static void updateClientPricing(String companyName, ClientPricing updated) {
    final index = clientPricings.indexWhere(
      (item) => item.companyName.toLowerCase() == companyName.toLowerCase(),
    );

    if (index != -1) {
      clientPricings[index] = updated;
    }
    StorageService.saveClientPricings(clientPricings);
  }

  static void deleteClientPricing(String companyName) {
    clientPricings.removeWhere(
      (item) => item.companyName.toLowerCase() == companyName.toLowerCase(),
    );
    StorageService.saveClientPricings(clientPricings);
  }

  static ClientPricing? getClientPricing(String? companyName) {
    if (companyName == null || companyName.trim().isEmpty) {
      return null;
    }

    try {
      return clientPricings.firstWhere(
        (item) => item.companyName.toLowerCase() == companyName.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
