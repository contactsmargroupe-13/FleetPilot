import 'package:flutter_test/flutter_test.dart';

import 'package:fleetpilot_app/screens/models/driver.dart';
import 'package:fleetpilot_app/screens/models/tour.dart';
import 'package:fleetpilot_app/screens/models/expense.dart';
import 'package:fleetpilot_app/screens/models/client_pricing.dart';
import 'package:fleetpilot_app/screens/models/driver_day_entry.dart';
import 'package:fleetpilot_app/screens/models/candidate.dart';
import 'package:fleetpilot_app/screens/models/admin_document.dart';
import 'package:fleetpilot_app/screens/models/driver_document.dart';
import 'package:fleetpilot_app/screens/add_truck.dart';

void main() {
  // ── Driver ──────────────────────────────────────────────────────────────────

  group('Driver', () {
    test('toJson/fromJson roundtrip', () {
      final driver = Driver(
        name: 'Karim',
        fixedSalary: 3000,
        bonus: 200,
        birthDate: DateTime(1990, 5, 15),
        socialSecurityNumber: '190051234567890',
        phone: '0612345678',
        hasPermisB: true,
        hasPermisC: true,
        hasPermisCE: false,
        assignedTourNumber: 'T42',
        pinHash: 'abc123hash',
      );

      final json = driver.toJson();
      final restored = Driver.fromJson(json);

      expect(restored.name, 'Karim');
      expect(restored.fixedSalary, 3000);
      expect(restored.bonus, 200);
      expect(restored.birthDate, DateTime(1990, 5, 15));
      expect(restored.socialSecurityNumber, '190051234567890');
      expect(restored.phone, '0612345678');
      expect(restored.hasPermisB, true);
      expect(restored.hasPermisC, true);
      expect(restored.hasPermisCE, false);
      expect(restored.assignedTourNumber, 'T42');
      expect(restored.pinHash, 'abc123hash');
    });

    test('fromJson handles null optional fields', () {
      final json = {'name': 'Sofia', 'fixedSalary': 3100, 'bonus': 0.0};
      final driver = Driver.fromJson(json);

      expect(driver.name, 'Sofia');
      expect(driver.birthDate, isNull);
      expect(driver.phone, isNull);
      expect(driver.pinHash, isNull);
      expect(driver.hasPermisB, false);
    });

    test('totalSalary', () {
      const driver = Driver(name: 'A', fixedSalary: 3000, bonus: 200);
      expect(driver.totalSalary, 3200);
    });

    test('permisLabel', () {
      const d1 = Driver(
          name: 'A', fixedSalary: 0, hasPermisB: true, hasPermisCE: true);
      expect(d1.permisLabel, 'B, CE');

      const d2 = Driver(name: 'B', fixedSalary: 0);
      expect(d2.permisLabel, 'Aucun');
    });

    test('PIN hash and check', () {
      const driver = Driver(name: 'Test', fixedSalary: 0);
      expect(driver.hasPinSet, false);

      final withPin = driver.withPin('1234');
      expect(withPin.hasPinSet, true);
      expect(withPin.checkPin('1234'), true);
      expect(withPin.checkPin('0000'), false);

      final withoutPin = withPin.withoutPin();
      expect(withoutPin.hasPinSet, false);
    });

    test('copyWith preserves fields', () {
      const driver = Driver(
        name: 'Karim',
        fixedSalary: 3000,
        bonus: 200,
        hasPermisC: true,
      );
      final updated = driver.copyWith(bonus: 300);
      expect(updated.name, 'Karim');
      expect(updated.bonus, 300);
      expect(updated.hasPermisC, true);
    });
  });

  // ── Tour ────────────────────────────────────────────────────────────────────

  group('Tour', () {
    test('toJson/fromJson roundtrip', () {
      final tour = Tour(
        id: 'tour_1',
        tourNumber: 'T001',
        date: DateTime(2026, 3, 15),
        driverName: 'Karim',
        truckPlate: 'AB-123-CD',
        companyName: 'Amazon',
        startTime: '08:00',
        endTime: '17:00',
        kmTotal: 250,
        clientsCount: 30,
        weightKg: 1500,
        hasHandling: true,
        handlingClientName: 'Carrefour',
        handlingDate: DateTime(2026, 3, 15),
        extraKm: 20,
        extraTour: true,
        status: 'terminée',
      );

      final json = tour.toJson();
      final restored = Tour.fromJson(json);

      expect(restored.id, 'tour_1');
      expect(restored.tourNumber, 'T001');
      expect(restored.driverName, 'Karim');
      expect(restored.truckPlate, 'AB-123-CD');
      expect(restored.companyName, 'Amazon');
      expect(restored.kmTotal, 250);
      expect(restored.clientsCount, 30);
      expect(restored.weightKg, 1500);
      expect(restored.hasHandling, true);
      expect(restored.handlingClientName, 'Carrefour');
      expect(restored.extraKm, 20);
      expect(restored.extraTour, true);
      expect(restored.status, 'terminée');
    });

    test('fromJson defaults', () {
      final json = {
        'id': 'x',
        'tourNumber': 'T1',
        'date': '2026-03-15T00:00:00.000',
        'driverName': 'A',
        'truckPlate': 'XX',
        'kmTotal': 100,
        'clientsCount': 10,
        'hasHandling': false,
        'extraKm': 0,
        'extraTour': false,
      };
      final tour = Tour.fromJson(json);
      expect(tour.status, 'planifiée');
      expect(tour.companyName, isNull);
      expect(tour.weightKg, isNull);
    });

    test('copyWith', () {
      final tour = Tour(
        id: '1',
        tourNumber: 'T1',
        date: DateTime(2026, 3, 1),
        driverName: 'A',
        truckPlate: 'XX',
        kmTotal: 100,
        clientsCount: 10,
        hasHandling: false,
      );
      final updated = tour.copyWith(driverName: 'B', status: 'terminée');
      expect(updated.driverName, 'B');
      expect(updated.status, 'terminée');
      expect(updated.kmTotal, 100);
    });
  });

  // ── Expense ─────────────────────────────────────────────────────────────────

  group('Expense', () {
    test('toJson/fromJson roundtrip', () {
      final expense = Expense(
        id: 'exp_1',
        date: DateTime(2026, 3, 10),
        truckPlate: 'AB-123-CD',
        type: ExpenseType.fuel,
        amount: 85.50,
        liters: 45.2,
        note: 'Total station',
      );

      final json = expense.toJson();
      final restored = Expense.fromJson(json);

      expect(restored.id, 'exp_1');
      expect(restored.truckPlate, 'AB-123-CD');
      expect(restored.type, ExpenseType.fuel);
      expect(restored.amount, 85.50);
      expect(restored.liters, 45.2);
      expect(restored.note, 'Total station');
    });

    test('fromJson handles null optionals', () {
      final json = {
        'id': 'x',
        'date': '2026-03-10T00:00:00.000',
        'truckPlate': 'XX',
        'type': 'repair',
        'amount': 200.0,
      };
      final expense = Expense.fromJson(json);
      expect(expense.type, ExpenseType.repair);
      expect(expense.liters, isNull);
      expect(expense.note, isNull);
    });
  });

  // ── ClientPricing ───────────────────────────────────────────────────────────

  group('ClientPricing', () {
    test('toJson/fromJson roundtrip', () {
      const pricing = ClientPricing(
        companyName: 'Amazon',
        dailyRate: 280,
        handlingEnabled: true,
        handlingPrice: 35,
        extraKmEnabled: true,
        extraKmPrice: 1.8,
        extraTourEnabled: true,
        extraTourPrice: 90,
        monthlyKmThreshold: 5000,
        overKmRate: 2.0,
        breakEvenAmount: 8000,
        notes: 'Contrat 2026',
      );

      final json = pricing.toJson();
      final restored = ClientPricing.fromJson(json);

      expect(restored.companyName, 'Amazon');
      expect(restored.dailyRate, 280);
      expect(restored.handlingEnabled, true);
      expect(restored.handlingPrice, 35);
      expect(restored.extraKmEnabled, true);
      expect(restored.extraKmPrice, 1.8);
      expect(restored.extraTourEnabled, true);
      expect(restored.extraTourPrice, 90);
      expect(restored.monthlyKmThreshold, 5000);
      expect(restored.overKmRate, 2.0);
      expect(restored.breakEvenAmount, 8000);
      expect(restored.notes, 'Contrat 2026');
    });

    test('fromJson with legacy format (no enabled flags)', () {
      final json = {
        'companyName': 'Legacy',
        'dailyRate': 200,
        'handlingPrice': 25.0,
        'extraKmPrice': 1.5,
        'extraTourPrice': 80.0,
      };
      final pricing = ClientPricing.fromJson(json);
      expect(pricing.handlingEnabled, true);
      expect(pricing.extraKmEnabled, true);
      expect(pricing.extraTourEnabled, true);
    });

    test('fromJson with zero legacy prices does not auto-enable', () {
      final json = {
        'companyName': 'Minimal',
        'dailyRate': 200,
      };
      final pricing = ClientPricing.fromJson(json);
      expect(pricing.handlingEnabled, false);
      expect(pricing.extraKmEnabled, false);
      expect(pricing.extraTourEnabled, false);
    });

    test('copyWith', () {
      const pricing = ClientPricing(companyName: 'A', dailyRate: 200);
      final updated = pricing.copyWith(dailyRate: 300);
      expect(updated.companyName, 'A');
      expect(updated.dailyRate, 300);
    });
  });

  // ── DriverDayEntry ──────────────────────────────────────────────────────────

  group('DriverDayEntry', () {
    test('toJson/fromJson roundtrip', () {
      final entry = DriverDayEntry(
        id: 'e1',
        date: DateTime(2026, 3, 15),
        driverName: 'Karim',
        truckPlate: 'AB-123-CD',
        kmTotal: 250,
        clientsCount: 30,
      );

      final json = entry.toJson();
      final restored = DriverDayEntry.fromJson(json);

      expect(restored.id, 'e1');
      expect(restored.driverName, 'Karim');
      expect(restored.truckPlate, 'AB-123-CD');
      expect(restored.kmTotal, 250);
      expect(restored.clientsCount, 30);
    });
  });

  // ── Candidate ───────────────────────────────────────────────────────────────

  group('Candidate', () {
    test('toJson/fromJson roundtrip', () {
      final candidate = Candidate(
        id: 'c1',
        name: 'Jean Dupont',
        phone: '0612345678',
        email: 'jean@test.fr',
        applyDate: DateTime(2026, 3, 1),
        status: 'entretien',
        licenseTypes: ['C', 'CE'],
        hasFimo: true,
        hasFco: false,
        note: 'Bon profil',
      );

      final json = candidate.toJson();
      final restored = Candidate.fromJson(json);

      expect(restored.id, 'c1');
      expect(restored.name, 'Jean Dupont');
      expect(restored.phone, '0612345678');
      expect(restored.email, 'jean@test.fr');
      expect(restored.status, 'entretien');
      expect(restored.licenseTypes, ['C', 'CE']);
      expect(restored.hasFimo, true);
      expect(restored.hasFco, false);
      expect(restored.note, 'Bon profil');
    });

    test('fromJson defaults', () {
      final json = {
        'id': 'x',
        'name': 'A',
        'applyDate': '2026-03-01T00:00:00.000',
      };
      final c = Candidate.fromJson(json);
      expect(c.status, 'candidature');
      expect(c.licenseTypes, isEmpty);
      expect(c.hasFimo, false);
    });
  });

  // ── AdminDocument ───────────────────────────────────────────────────────────

  group('AdminDocument', () {
    test('toJson/fromJson roundtrip', () {
      final doc = AdminDocument(
        id: 'ad1',
        title: 'Contrat Karim',
        category: AdminDocCategory.contratChauffeur,
        date: DateTime(2026, 1, 15),
        linkedDriverName: 'Karim',
        linkedTruckPlate: 'AB-123-CD',
        note: 'CDI',
        filePath: '/docs/contrat.pdf',
        fileName: 'contrat.pdf',
      );

      final json = doc.toJson();
      final restored = AdminDocument.fromJson(json);

      expect(restored.id, 'ad1');
      expect(restored.title, 'Contrat Karim');
      expect(restored.category, AdminDocCategory.contratChauffeur);
      expect(restored.linkedDriverName, 'Karim');
      expect(restored.linkedTruckPlate, 'AB-123-CD');
      expect(restored.note, 'CDI');
      expect(restored.filePath, '/docs/contrat.pdf');
      expect(restored.fileName, 'contrat.pdf');
    });

    test('fromJson unknown category falls back to other', () {
      final json = {
        'id': 'x',
        'title': 'Test',
        'category': 'unknown_cat',
        'date': '2026-01-01T00:00:00.000',
      };
      final doc = AdminDocument.fromJson(json);
      expect(doc.category, AdminDocCategory.other);
    });
  });

  // ── DriverDocument ──────────────────────────────────────────────────────────

  group('DriverDocument', () {
    test('toJson/fromJson roundtrip', () {
      final doc = DriverDocument(
        id: 'dd1',
        driverName: 'Karim',
        type: DocumentType.permisC,
        documentNumber: '12345',
        issueDate: DateTime(2020, 6, 1),
        expiryDate: DateTime(2025, 6, 1),
        note: 'Renouvelé',
      );

      final json = doc.toJson();
      final restored = DriverDocument.fromJson(json);

      expect(restored.id, 'dd1');
      expect(restored.driverName, 'Karim');
      expect(restored.type, DocumentType.permisC);
      expect(restored.documentNumber, '12345');
      expect(restored.issueDate, DateTime(2020, 6, 1));
      expect(restored.expiryDate, DateTime(2025, 6, 1));
      expect(restored.note, 'Renouvelé');
    });

    test('alertLevel expired', () {
      final doc = DriverDocument(
        id: 'x',
        driverName: 'A',
        type: DocumentType.fimo,
        expiryDate: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(doc.isExpired, true);
      expect(doc.alertLevel, 'expired');
    });

    test('alertLevel warning (within 30 days)', () {
      final doc = DriverDocument(
        id: 'x',
        driverName: 'A',
        type: DocumentType.fimo,
        expiryDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(doc.isExpiringSoon, true);
      expect(doc.alertLevel, 'warning');
    });

    test('alertLevel ok', () {
      final doc = DriverDocument(
        id: 'x',
        driverName: 'A',
        type: DocumentType.fimo,
        expiryDate: DateTime.now().add(const Duration(days: 90)),
      );
      expect(doc.alertLevel, 'ok');
    });

    test('alertLevel none when no expiry', () {
      const doc = DriverDocument(
        id: 'x',
        driverName: 'A',
        type: DocumentType.fimo,
      );
      expect(doc.alertLevel, 'none');
    });

    test('fromJson unknown type falls back to other', () {
      final json = {
        'id': 'x',
        'driverName': 'A',
        'type': 'unknown_type',
      };
      final doc = DriverDocument.fromJson(json);
      expect(doc.type, DocumentType.other);
    });
  });

  // ── Truck ───────────────────────────────────────────────────────────────────

  group('Truck', () {
    test('toJson/fromJson roundtrip', () {
      final truck = Truck(
        plate: 'AB-123-CD',
        brand: 'Mercedes',
        model: 'Sprinter',
        year: 2023,
        dailyRate: 230,
        ownershipType: OwnershipType.location,
        rentMonthly: 950,
        rentCompany: 'LeasePlan',
        vehicleType: VehicleType.vl12m3,
        companyName: 'FleetPilot',
        assignedDriverName: 'Karim',
      );

      final json = truck.toJson();
      final restored = Truck.fromJson(json);

      expect(restored.plate, 'AB-123-CD');
      expect(restored.brand, 'Mercedes');
      expect(restored.model, 'Sprinter');
      expect(restored.year, 2023);
      expect(restored.dailyRate, 230);
      expect(restored.ownershipType, OwnershipType.location);
      expect(restored.rentMonthly, 950);
      expect(restored.rentCompany, 'LeasePlan');
      expect(restored.vehicleType, VehicleType.vl12m3);
      expect(restored.companyName, 'FleetPilot');
      expect(restored.assignedDriverName, 'Karim');
    });

    test('monthlyCost for location', () {
      const truck = Truck(
        plate: 'XX',
        model: 'Test',
        dailyRate: 200,
        ownershipType: OwnershipType.location,
        rentMonthly: 900,
      );
      expect(truck.monthlyCost, 900);
    });

    test('monthlyCost for achat with amortization', () {
      const truck = Truck(
        plate: 'XX',
        model: 'Test',
        dailyRate: 200,
        ownershipType: OwnershipType.achat,
        purchasePrice: 60000,
        amortMonths: 60,
      );
      expect(truck.monthlyCost, 1000);
    });

    test('monthlyCost null when missing data', () {
      const truck = Truck(
        plate: 'XX',
        model: 'Test',
        dailyRate: 200,
        ownershipType: OwnershipType.achat,
      );
      expect(truck.monthlyCost, isNull);
    });

    test('ServiceEntry toJson/fromJson', () {
      final entry = ServiceEntry(
        id: 's1',
        date: DateTime(2026, 2, 1),
        description: 'Vidange',
        cost: 150,
      );

      final json = entry.toJson();
      final restored = ServiceEntry.fromJson(json);

      expect(restored.id, 's1');
      expect(restored.description, 'Vidange');
      expect(restored.cost, 150);
    });

    test('repairs and maintenances survive roundtrip', () {
      final truck = Truck(
        plate: 'XX',
        model: 'Test',
        dailyRate: 200,
        ownershipType: OwnershipType.location,
        repairs: [
          ServiceEntry(
              id: 'r1',
              date: DateTime(2026, 1, 1),
              description: 'Pneu',
              cost: 200),
        ],
        maintenances: [
          ServiceEntry(
              id: 'm1',
              date: DateTime(2026, 2, 1),
              description: 'Vidange',
              cost: 150),
        ],
      );

      final json = truck.toJson();
      final restored = Truck.fromJson(json);

      expect(restored.repairs.length, 1);
      expect(restored.repairs.first.description, 'Pneu');
      expect(restored.maintenances.length, 1);
      expect(restored.maintenances.first.description, 'Vidange');
    });
  });
}
