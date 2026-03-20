import 'package:flutter_test/flutter_test.dart';

import 'package:fleetpilot_app/screens/models/tour.dart';
import 'package:fleetpilot_app/screens/models/client_pricing.dart';

/// Extracted billing logic from manager_billing.dart for testability.
/// Mirrors the calculation in ManagerBillingPage.build().
class ClientBilling {
  final String companyName;
  int tours = 0;
  int handlingCount = 0;
  double handlingAmount = 0;
  double extraKm = 0;
  double extraKmAmount = 0;
  int extraTours = 0;
  double extraTourAmount = 0;
  double get total => handlingAmount + extraKmAmount + extraTourAmount;
  ClientBilling({required this.companyName});
}

Map<String, ClientBilling> computeBilling({
  required List<Tour> tours,
  required ClientPricing? Function(String?) getPricing,
  required int year,
  required int month,
}) {
  final Map<String, ClientBilling> billing = {};

  for (final tour in tours) {
    if (tour.date.year != year || tour.date.month != month) continue;

    final company = tour.companyName ?? '—';
    final pricing = getPricing(company);

    billing.putIfAbsent(company, () => ClientBilling(companyName: company));
    final client = billing[company]!;

    client.tours++;

    if (tour.hasHandling && pricing != null && pricing.handlingEnabled) {
      client.handlingCount++;
      client.handlingAmount += pricing.handlingPrice ?? 0.0;
    }

    if (tour.extraKm > 0 && pricing != null && pricing.extraKmEnabled) {
      client.extraKm += tour.extraKm;
      client.extraKmAmount += tour.extraKm * (pricing.extraKmPrice ?? 0.0);
    }

    if (tour.extraTour && pricing != null && pricing.extraTourEnabled) {
      client.extraTours++;
      client.extraTourAmount += pricing.extraTourPrice ?? 0.0;
    }
  }

  return billing;
}

void main() {
  const amazonPricing = ClientPricing(
    companyName: 'Amazon',
    dailyRate: 280,
    handlingEnabled: true,
    handlingPrice: 35,
    extraKmEnabled: true,
    extraKmPrice: 1.8,
    extraTourEnabled: true,
    extraTourPrice: 90,
    breakEvenAmount: 500,
  );

  const carrefourPricing = ClientPricing(
    companyName: 'Carrefour',
    dailyRate: 250,
    handlingEnabled: true,
    handlingPrice: 25,
    extraKmEnabled: false,
    extraTourEnabled: false,
  );

  ClientPricing? getPricing(String? name) {
    if (name == 'Amazon') return amazonPricing;
    if (name == 'Carrefour') return carrefourPricing;
    return null;
  }

  Tour makeTour({
    String company = 'Amazon',
    DateTime? date,
    bool hasHandling = false,
    double extraKm = 0,
    bool extraTour = false,
  }) {
    return Tour(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      tourNumber: 'T1',
      date: date ?? DateTime(2026, 3, 15),
      driverName: 'Karim',
      truckPlate: 'AB-123-CD',
      companyName: company,
      kmTotal: 200,
      clientsCount: 25,
      hasHandling: hasHandling,
      extraKm: extraKm,
      extraTour: extraTour,
    );
  }

  group('Billing calculation', () {
    test('empty tours → empty billing', () {
      final result = computeBilling(
        tours: [],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      expect(result, isEmpty);
    });

    test('tours outside month are excluded', () {
      final result = computeBilling(
        tours: [makeTour(date: DateTime(2026, 2, 15))],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      expect(result, isEmpty);
    });

    test('basic tour count without extras', () {
      final result = computeBilling(
        tours: [makeTour(), makeTour()],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      expect(result['Amazon']!.tours, 2);
      expect(result['Amazon']!.total, 0); // no extras
    });

    test('handling billing', () {
      final result = computeBilling(
        tours: [makeTour(hasHandling: true), makeTour(hasHandling: true)],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final amazon = result['Amazon']!;
      expect(amazon.handlingCount, 2);
      expect(amazon.handlingAmount, 70); // 2 × 35
    });

    test('extra km billing', () {
      final result = computeBilling(
        tours: [makeTour(extraKm: 50)],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final amazon = result['Amazon']!;
      expect(amazon.extraKm, 50);
      expect(amazon.extraKmAmount, 90); // 50 × 1.8
    });

    test('extra tour billing', () {
      final result = computeBilling(
        tours: [makeTour(extraTour: true)],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final amazon = result['Amazon']!;
      expect(amazon.extraTours, 1);
      expect(amazon.extraTourAmount, 90);
    });

    test('combined extras total', () {
      final result = computeBilling(
        tours: [
          makeTour(hasHandling: true, extraKm: 20, extraTour: true),
        ],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final amazon = result['Amazon']!;
      // handling: 35, extra km: 20×1.8=36, extra tour: 90
      expect(amazon.total, closeTo(161, 0.01));
    });

    test('disabled features are not billed', () {
      // Carrefour has extraKm and extraTour disabled
      final result = computeBilling(
        tours: [
          makeTour(
              company: 'Carrefour',
              hasHandling: true,
              extraKm: 50,
              extraTour: true),
        ],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final carrefour = result['Carrefour']!;
      expect(carrefour.handlingCount, 1);
      expect(carrefour.handlingAmount, 25);
      expect(carrefour.extraKmAmount, 0); // disabled
      expect(carrefour.extraTourAmount, 0); // disabled
      expect(carrefour.total, 25);
    });

    test('unknown company (no pricing) → no extras billed', () {
      final result = computeBilling(
        tours: [
          makeTour(
              company: 'Unknown',
              hasHandling: true,
              extraKm: 100,
              extraTour: true),
        ],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final unknown = result['Unknown']!;
      expect(unknown.tours, 1);
      expect(unknown.total, 0);
    });

    test('multiple clients billed separately', () {
      final result = computeBilling(
        tours: [
          makeTour(company: 'Amazon', hasHandling: true),
          makeTour(company: 'Carrefour', hasHandling: true),
          makeTour(company: 'Amazon', extraTour: true),
        ],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      expect(result.length, 2);
      expect(result['Amazon']!.tours, 2);
      expect(result['Amazon']!.total, 35 + 90); // handling + extra tour
      expect(result['Carrefour']!.tours, 1);
      expect(result['Carrefour']!.total, 25); // handling only
    });

    test('grand total across clients', () {
      final result = computeBilling(
        tours: [
          makeTour(company: 'Amazon', hasHandling: true, extraKm: 10),
          makeTour(company: 'Carrefour', hasHandling: true),
        ],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final grandTotal =
          result.values.fold(0.0, (sum, c) => sum + c.total);
      // Amazon: 35 + 10×1.8=18 = 53, Carrefour: 25
      expect(grandTotal, closeTo(78, 0.01));
    });
  });

  group('Break-even', () {
    test('above break-even', () {
      // Amazon break-even is 500€
      final result = computeBilling(
        tours: [
          // 6 handling × 35 = 210
          for (int i = 0; i < 6; i++) makeTour(hasHandling: true),
          // 5 extra tours × 90 = 450 → total 660 > 500
          for (int i = 0; i < 5; i++) makeTour(extraTour: true),
        ],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final amazon = result['Amazon']!;
      expect(amazon.total, 660);
      expect(amazon.total >= amazonPricing.breakEvenAmount!, true);
    });

    test('below break-even', () {
      final result = computeBilling(
        tours: [makeTour(hasHandling: true)],
        getPricing: getPricing,
        year: 2026,
        month: 3,
      );
      final amazon = result['Amazon']!;
      expect(amazon.total, 35);
      expect(amazon.total < amazonPricing.breakEvenAmount!, true);
    });
  });
}
