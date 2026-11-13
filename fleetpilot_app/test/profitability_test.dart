import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fleetpilot_app/providers/app_state.dart';
import 'package:fleetpilot_app/screens/add_truck.dart';
import 'package:fleetpilot_app/screens/models/absence.dart';
import 'package:fleetpilot_app/screens/models/client_pricing.dart';
import 'package:fleetpilot_app/screens/models/client_statement.dart';
import 'package:fleetpilot_app/screens/models/daily_assignment.dart';
import 'package:fleetpilot_app/screens/models/driver.dart';
import 'package:fleetpilot_app/screens/models/expense.dart';
import 'package:fleetpilot_app/screens/models/monthly_points.dart';
import 'package:fleetpilot_app/screens/models/tour.dart';
import 'package:fleetpilot_app/services/accounting_export.dart';
import 'package:fleetpilot_app/services/data_quality.dart';
import 'package:fleetpilot_app/services/database_service.dart';
import 'package:fleetpilot_app/screens/models/odometer_reading.dart';
import 'package:fleetpilot_app/services/maintenance.dart';
import 'package:fleetpilot_app/services/profitability.dart';

int _n = 0;

Future<AppState> _state() async {
  sqfliteFfiInit();
  _n++;
  final db = await databaseFactoryFfi
      .openDatabase('file:profit_$_n?mode=memory&cache=shared');
  return AppState(DatabaseService.fromDatabase(db));
}

Tour _tour(String id, DateTime date,
        {String driver = 'Karim',
        String truck = 'AA-111-AA',
        String? company,
        double km = 100,
        int clients = 0,
        bool handling = false}) =>
    Tour(
      id: id,
      tourNumber: '1',
      date: date,
      driverName: driver,
      truckPlate: truck,
      companyName: company,
      kmTotal: km,
      clientsCount: clients,
      hasHandling: handling,
    );

void main() {
  final june = DateTime(2026, 6);
  // Mois terminé : coûts fixes comptés en entier.
  final after = DateTime(2026, 7, 10);

  const fiche = ClientPricing(
    companyName: 'Fiche Co',
    dailyRate: 200,
    handlingEnabled: true,
    handlingPrice: 30,
  );
  const point = ClientPricing(
    companyName: 'Point Co',
    billingMode: BillingMode.auPoint,
    pricePerPoint: 2,
  );

  late AppState s;
  setUp(() async {
    s = await _state();
    s.clientPricings = [fiche, point];
    // Les tests de base raisonnent sans charges : un test dédié les couvre.
    s.employerChargeRate = 0;
  });

  test('à la fiche : forfait par tournée + options', () {
    s.tours = [
      _tour('a', DateTime(2026, 6, 2), company: 'Fiche Co'),
      _tour('b', DateTime(2026, 6, 3), company: 'fiche co', handling: true),
    ];
    final r = Profitability.month(s, june, now: after);
    expect(r.revenue, 430);
    expect(Profitability.billing(s, june).single.totalHT, 430);
  });

  test('au point : les points saisis remplacent le comptage chauffeur', () {
    s.tours = [
      _tour('a', DateTime(2026, 6, 2), company: 'Point Co', clients: 50),
      _tour('b', DateTime(2026, 6, 3), company: 'Point Co', clients: 50),
    ];

    // Sans saisie : ancien comptage, et la saisie est signalée.
    var r = Profitability.month(s, june, now: after);
    expect(r.revenue, 200);
    expect(r.pendingPoints.single.legacyPoints, 100);

    s.monthlyPoints = [
      const MonthlyPoints(
          month: '2026-06',
          companyName: 'Point Co',
          driverName: 'Karim',
          points: 300),
    ];
    r = Profitability.month(s, june, now: after);
    expect(r.revenue, 600);
    expect(r.pendingPoints, isEmpty);
    // Réparti à parts égales sur les tournées du chauffeur.
    expect(Profitability.tourRevenues(s, june)['a'], 300);

    final bill = Profitability.billing(s, june).single;
    expect(bill.totalPoints, 300);
    expect(bill.totalHT, 600);
  });

  test('tarif spécifique de l’affectation appliqué aux points', () {
    s.assignments = [
      const DriverAssignment(
          driverName: 'Karim', truckPlate: 'AA-111-AA', customPricePerPoint: 3),
    ];
    s.tours = [_tour('a', DateTime(2026, 6, 2), company: 'Point Co')];
    s.monthlyPoints = [
      const MonthlyPoints(
          month: '2026-06', companyName: 'Point Co', driverName: 'Karim', points: 10),
    ];
    expect(Profitability.month(s, june, now: after).revenue, 30);
  });

  test('résultat, coût au km et prorata des coûts fixes', () {
    s.drivers = [
      const Driver(name: 'Karim', fixedSalary: 3000),
      const Driver(name: 'Parti', fixedSalary: 2000, status: DriverStatus.demission),
    ];
    s.trucks = [
      const Truck(
        plate: 'AA-111-AA',
        model: 'Sprinter',
        dailyRate: 0,
        ownershipType: OwnershipType.location,
        rentMonthly: 900,
        insuranceMonthly: 100,
      ),
    ];
    s.expenses = [
      Expense(
          id: 'e',
          date: DateTime(2026, 6, 5),
          truckPlate: 'AA-111-AA',
          type: ExpenseType.fuel,
          amount: 500,
          vatRate: 0),
    ];
    s.tours = [
      for (var d = 1; d <= 20; d++)
        _tour('t$d', DateTime(2026, 6, d), company: 'Fiche Co', km: 150),
    ];

    final full = Profitability.month(s, june, now: after);
    expect(full.revenue, 4000);
    expect(full.costs, 500 + 3000 + 1000); // le démissionnaire ne compte pas
    expect(full.result, -500);
    expect(full.km, 3000);
    expect(full.workDays, 20);
    expect(full.costPerKm, closeTo(1.5, 1e-9));
    expect(full.trucks.single.salaries, 3000);

    // Au 15 juin (30 jours) : moitié des fixes, projection disponible.
    final mid = Profitability.month(s, june, now: DateTime(2026, 6, 15));
    expect(mid.ratio, 0.5);
    expect(mid.salaries + mid.trucksFixed, 2000);
    expect(mid.projection, isNotNull);
  });

  test('tournée sans tarif : signalée, aucun revenu', () {
    s.tours = [_tour('a', DateTime(2026, 6, 2), company: 'Inconnu')];
    final r = Profitability.month(s, june, now: after);
    expect(r.revenue, 0);
    expect(r.untaxed.length, 1);
  });

  test('charges patronales et dépenses en HT', () {
    s.employerChargeRate = 0.42;
    s.drivers = [const Driver(name: 'Karim', fixedSalary: 2000, bonus: 100)];
    s.expenses = [
      Expense(id: 'f', date: DateTime(2026, 6, 5), truckPlate: 'AA-111-AA',
          type: ExpenseType.fuel, amount: 120),
      Expense(id: 'pv', date: DateTime(2026, 6, 6), truckPlate: 'AA-111-AA',
          type: ExpenseType.fine, amount: 135),
    ];
    final r = Profitability.month(s, june, now: after);
    expect(r.salaries, closeTo(2100 * 1.42, 1e-9));
    // 120 TTC à 20 % → 100 HT ; une amende n'a pas de TVA.
    expect(r.expenses, closeTo(100 + 135, 1e-9));
    expect(r.finesWithoutDriver, 1);
  });

  test('le relevé remplace l’estimation et révèle l’écart', () {
    s.tours = [
      _tour('a', DateTime(2026, 6, 2), company: 'Fiche Co', truck: 'T1'),
      _tour('b', DateTime(2026, 6, 3), company: 'Fiche Co', truck: 'T2'),
    ];
    var r = Profitability.month(s, june, now: after);
    expect(r.revenueConfirmed, isFalse);
    expect(r.revenue, 400);

    s.statements = [
      const ClientStatement(
          month: '2026-06', companyName: 'Fiche Co', paidAmount: 340, penalties: 60),
    ];
    r = Profitability.month(s, june, now: after);
    expect(r.revenueConfirmed, isTrue);
    expect(r.revenue, 340);
    expect(r.gap, -60);
    expect(r.penalties, 60);
    // Le payé est réparti sur les camions au prorata du facturé.
    expect(r.trucks.firstWhere((t) => t.plate == 'T1').revenue, 170);

    final texts = Profitability.insights(r).map((i) => i.text).join('\n');
    expect(texts, contains('pénalités'));
    expect(texts, contains('de moins que tes tarifs'));
  });

  test('constat : camion qui coûte sans rouler', () {
    s.trucks = [
      const Truck(plate: 'IDLE', model: 'X', dailyRate: 0,
          ownershipType: OwnershipType.location, rentMonthly: 800),
    ];
    s.tours = [_tour('a', DateTime(2026, 6, 2), company: 'Fiche Co')];
    final r = Profitability.month(s, june, now: after);
    expect(Profitability.insights(r).first.text, startsWith('IDLE n’a fait aucune tournée'));
  });

  test('entretien au km : compté depuis le dernier entretien saisi', () {
    final truck = Truck(
      plate: 'AA-111-AA', model: 'X', dailyRate: 0,
      ownershipType: OwnershipType.location,
      serviceIntervalKm: 1000,
      maintenances: [
        ServiceEntry(id: 'm1', date: DateTime(2026, 6, 1), description: 'Vidange'),
        // Ancienne pollution : un plein rangé dans l'entretien, ignoré.
        ServiceEntry(id: 'exp_f', date: DateTime(2026, 6, 20), description: 'Carburant'),
      ],
    );
    s.trucks = [truck];
    s.expenses = [
      Expense(id: 'f', date: DateTime(2026, 6, 20), truckPlate: 'AA-111-AA',
          type: ExpenseType.fuel, amount: 50),
    ];
    s.tours = [
      _tour('old', DateTime(2026, 5, 30), km: 500),
      for (var d = 2; d <= 10; d++) _tour('t$d', DateTime(2026, 6, d), km: 100),
    ];
    final st = Maintenance.status(s, truck)!;
    expect(st.kmSince, 900);
    expect(st.soon, isTrue);
    expect(Maintenance.dueSoon(s).single.truck.plate, 'AA-111-AA');
  });

  test('absence : couvre ses jours, bornes comprises', () {
    final a = Absence(id: '1', driverName: 'Karim',
        start: DateTime(2026, 6, 10), end: DateTime(2026, 6, 12));
    expect(a.covers(DateTime(2026, 6, 10, 18)), isTrue);
    expect(a.covers(DateTime(2026, 6, 12)), isTrue);
    expect(a.covers(DateTime(2026, 6, 13)), isFalse);
    expect(a.days, 3);
  });

  test('export comptable : ventes, achats HT/TVA, activité', () {
    s.tours = [_tour('a', DateTime(2026, 6, 2), company: 'Fiche Co')];
    s.expenses = [
      Expense(id: 'f', date: DateTime(2026, 6, 5), truckPlate: 'AA-111-AA',
          type: ExpenseType.fuel, amount: 120, note: 'Total; Lyon'),
    ];
    final files = AccountingExport.build(s, june);
    expect(files.map((f) => f.name),
        ['ventes_2026-06.csv', 'achats_2026-06.csv', 'activite_2026-06.csv']);
    expect(files[0].content, contains('Fiche Co;1;200,00;40,00;240,00'));
    expect(files[1].content, contains('05/06/2026;AA-111-AA;Carburant;;"Total; Lyon";100,00;20,00;120,00'));
  });

  OdometerReading odo(String id, DateTime d, int km,
          {bool start = true, String driver = 'Karim'}) =>
      OdometerReading(id: id, truckPlate: 'AA-111-AA', date: d, km: km,
          driverName: driver, isStart: start);

  test('compteur : journée oubliée complétée par le relevé suivant', () {
    s.odometer = [
      odo('a', DateTime(2026, 6, 2, 6), 10000),            // Karim part, oublie le soir
      odo('b', DateTime(2026, 6, 3, 6), 10184, driver: 'Luc'), // Luc repart le lendemain
    ];
    final open = DataQuality.openDays(s);
    // Luc n'a pas de tournée le 3 non plus : sa journée est ouverte, sans km.
    final karim = open.firstWhere((d) => d.driverName == 'Karim');
    expect(karim.km, 184);
    final t = DataQuality.reconstitute(s, karim);
    expect(t.kmTotal, 184);
    expect(t.kmSource, 'reconstitue');
    expect(t.kmMeasured, isTrue);

    s.tours = [t];
    expect(DataQuality.openDays(s).any((d) => d.driverName == 'Karim'), isFalse);
  });

  test('compteur contre déclaré : l’écart est signalé', () {
    s.odometer = [
      odo('a', DateTime(2026, 6, 1, 6), 10000),
      odo('b', DateTime(2026, 6, 11, 6), 11000),
    ];
    s.tours = [
      for (var d = 1; d <= 10; d++)
        _tour('t$d', DateTime(2026, 6, d), km: 80), // 800 déclarés pour 1000 roulés
    ];
    final g = DataQuality.gaps(s, june).single;
    expect(g.odometerKm, 1000);
    expect(g.declaredKm, 800);
    expect(g.ratio, closeTo(-0.2, 1e-9));
  });

  test('fiabilité : km mesurés, jours sans saisie, relevés', () {
    s.drivers = const [
      Driver(name: 'Karim', fixedSalary: 0),
      Driver(name: 'Luc', fixedSalary: 0),
    ];
    s.tours = [
      Tour(id: 'a', tourNumber: '1', date: DateTime(2026, 6, 2), driverName: 'Karim',
          truckPlate: 'AA-111-AA', companyName: 'Fiche Co', kmTotal: 100,
          clientsCount: 0, hasHandling: false, kmSource: 'compteur'),
      Tour(id: 'b', tourNumber: '1', date: DateTime(2026, 6, 2), driverName: 'Luc',
          truckPlate: 'BB', companyName: 'Fiche Co', kmTotal: 100,
          clientsCount: 0, hasHandling: false, kmSource: 'saisie'),
      Tour(id: 'c', tourNumber: '1', date: DateTime(2026, 6, 3), driverName: 'Karim',
          truckPlate: 'AA-111-AA', companyName: 'Fiche Co', kmTotal: 100,
          clientsCount: 0, hasHandling: false, kmSource: 'gps'),
    ];
    // Le 3 juin, Luc n'a rien saisi et n'est pas déclaré absent.
    expect(DataQuality.silentDays(s, june), 1);

    var rel = DataQuality.reliability(s, Profitability.month(s, june, now: after));
    // km : 2/3 mesurés ; jours : 3/(3+1) ; relevé manquant : 0.
    expect(rel.score, ((2 / 3) * 35 + 0.75 * 35 + 0 * 30).round());
    expect(rel.issues.map((i) => i.text).join('\n'), contains('relevé'));

    s.absences = [
      Absence(id: 'x', driverName: 'Luc',
          start: DateTime(2026, 6, 3), end: DateTime(2026, 6, 3)),
    ];
    s.statements = [
      const ClientStatement(month: '2026-06', companyName: 'Fiche Co', paidAmount: 600),
    ];
    rel = DataQuality.reliability(s, Profitability.month(s, june, now: after));
    expect(rel.silentDays, 0);
    expect(rel.score, ((2 / 3) * 35 + 35 + 30).round());
  });

  test('Tour : kmSource conservé en JSON', () {
    final t = Tour(id: 'a', tourNumber: '1', date: DateTime(2026, 6, 2),
        driverName: 'K', truckPlate: 'P', kmTotal: 1, clientsCount: 0,
        hasHandling: false, kmSource: 'gps-auto');
    expect(Tour.fromJson(t.toJson()).kmSource, 'gps-auto');
  });
}
