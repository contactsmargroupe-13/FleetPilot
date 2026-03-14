import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../screens/add_truck.dart';
import '../screens/models/client_pricing.dart';
import '../screens/models/driver.dart';
import '../screens/models/driver_day_entry.dart';
import '../screens/models/candidate.dart';
import '../screens/models/admin_document.dart';
import '../screens/models/driver_document.dart';
import '../screens/models/expense.dart';
import '../screens/models/tour.dart';
import 'company_settings.dart';

class StorageService {
  static const _keyTrucks = 'trucks';
  static const _keyDrivers = 'drivers';
  static const _keyDayEntries = 'driverDayEntries';
  static const _keyTours = 'tours';
  static const _keyExpenses = 'expenses';
  static const _keyClientPricings = 'clientPricings';
  static const _keyDriverDocuments = 'driverDocuments';
  static const _keyCandidates = 'candidates';
  static const _keyAdminDocuments = 'adminDocuments';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await CompanySettings.init(_prefs!);
  }

  // ─── Save ───────────────────────────────────────────────────────────────────

  static Future<void> saveTrucks(List<Truck> trucks) async {
    await _prefs!.setString(_keyTrucks, jsonEncode(trucks.map((t) => t.toJson()).toList()));
  }

  static Future<void> saveDrivers(List<Driver> drivers) async {
    await _prefs!.setString(_keyDrivers, jsonEncode(drivers.map((d) => d.toJson()).toList()));
  }

  static Future<void> saveDayEntries(List<DriverDayEntry> entries) async {
    await _prefs!.setString(_keyDayEntries, jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  static Future<void> saveTours(List<Tour> tours) async {
    await _prefs!.setString(_keyTours, jsonEncode(tours.map((t) => t.toJson()).toList()));
  }

  static Future<void> saveExpenses(List<Expense> expenses) async {
    await _prefs!.setString(_keyExpenses, jsonEncode(expenses.map((e) => e.toJson()).toList()));
  }

  static Future<void> saveClientPricings(List<ClientPricing> pricings) async {
    await _prefs!.setString(_keyClientPricings, jsonEncode(pricings.map((p) => p.toJson()).toList()));
  }

  static Future<void> saveDriverDocuments(List<DriverDocument> docs) async {
    await _prefs!.setString(_keyDriverDocuments, jsonEncode(docs.map((d) => d.toJson()).toList()));
  }

  static Future<void> saveCandidates(List<Candidate> candidates) async {
    await _prefs!.setString(_keyCandidates, jsonEncode(candidates.map((c) => c.toJson()).toList()));
  }

  static Future<void> saveAdminDocuments(
      List<AdminDocument> docs) async {
    await _prefs!.setString(
        _keyAdminDocuments,
        jsonEncode(docs.map((d) => d.toJson()).toList()));
  }

  // ─── Load ───────────────────────────────────────────────────────────────────

  static List<Truck> loadTrucks() {
    final raw = _prefs!.getString(_keyTrucks);
    if (raw == null) return _defaultTrucks();
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Truck.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultTrucks();
    }
  }

  static List<Driver> loadDrivers() {
    final raw = _prefs!.getString(_keyDrivers);
    if (raw == null) return _defaultDrivers();
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Driver.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultDrivers();
    }
  }

  static List<DriverDayEntry> loadDayEntries() {
    final raw = _prefs!.getString(_keyDayEntries);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => DriverDayEntry.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<Tour> loadTours() {
    final raw = _prefs!.getString(_keyTours);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Tour.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<Expense> loadExpenses() {
    final raw = _prefs!.getString(_keyExpenses);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Expense.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<ClientPricing> loadClientPricings() {
    final raw = _prefs!.getString(_keyClientPricings);
    if (raw == null) return _defaultClientPricings();
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => ClientPricing.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return _defaultClientPricings();
    }
  }

  static List<DriverDocument> loadDriverDocuments() {
    final raw = _prefs!.getString(_keyDriverDocuments);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => DriverDocument.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<AdminDocument> loadAdminDocuments() {
    final raw = _prefs!.getString(_keyAdminDocuments);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) =>
              AdminDocument.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static List<Candidate> loadCandidates() {
    final raw = _prefs!.getString(_keyCandidates);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Candidate.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  // ─── Données par défaut (premier lancement) ─────────────────────────────────

  static List<Truck> _defaultTrucks() => [
    const Truck(
      plate: "AB-123-CD",
      model: "Sprinter",
      dailyRate: 230,
      ownershipType: OwnershipType.location,
      rentMonthly: 950,
    ),
  ];

  static List<Driver> _defaultDrivers() => [
    const Driver(name: "Karim", fixedSalary: 3000, bonus: 200),
    const Driver(name: "Sofia", fixedSalary: 3100, bonus: 100),
  ];

  static List<ClientPricing> _defaultClientPricings() => [
    const ClientPricing(
      companyName: 'Amazon',
      dailyRate: 280,
      handlingEnabled: true,
      handlingPrice: 35,
      extraKmEnabled: true,
      extraKmPrice: 1.8,
      extraTourEnabled: true,
      extraTourPrice: 90,
    ),
    const ClientPricing(
      companyName: 'Carrefour',
      dailyRate: 250,
      handlingEnabled: true,
      handlingPrice: 25,
      extraKmEnabled: true,
      extraKmPrice: 1.4,
      extraTourEnabled: true,
      extraTourPrice: 75,
    ),
    const ClientPricing(
      companyName: 'DHL',
      dailyRate: 260,
      handlingEnabled: true,
      handlingPrice: 30,
      extraKmEnabled: true,
      extraKmPrice: 1.6,
      extraTourEnabled: true,
      extraTourPrice: 85,
    ),
  ];
}
