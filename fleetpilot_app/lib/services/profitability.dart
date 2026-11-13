import '../providers/app_state.dart';
import '../screens/add_truck.dart';
import '../screens/models/client_pricing.dart';
import '../screens/models/driver.dart';
import '../screens/models/expense.dart';
import '../screens/models/tour.dart';
import 'pdf_invoice_service.dart';

/// Un couple commissionnaire « au point » × chauffeur dont les points du
/// mois n'ont pas encore été saisis par le manager.
class PendingPoints {
  final String companyName, driverName;
  final int tours;

  /// Ancien comptage saisi par le chauffeur, utilisé en attendant.
  final int legacyPoints;
  const PendingPoints(
      this.companyName, this.driverName, this.tours, this.legacyPoints);
}

class TruckResult {
  final String plate;
  double revenue = 0, km = 0, expenses = 0, fixed = 0, salaries = 0;
  int tours = 0;
  TruckResult(this.plate);
  double get costs => expenses + fixed + salaries;
  double get result => revenue - costs;
  double get costPerKm => km > 0 ? costs / km : 0;
  double get revenuePerKm => km > 0 ? revenue / km : 0;
}

class DriverResult {
  final String name;
  double revenue = 0, km = 0, salary = 0;
  final Set<String> _days = {};
  DriverResult(this.name);
  int get days => _days.length;
}

class ClientResult {
  final String name;
  final BillingMode mode;

  /// Ce que les tarifs donnent pour le mois.
  double invoiced = 0;

  /// Ce que le relevé dit avoir payé ; null tant qu'il n'est pas saisi.
  double? paid;
  double penalties = 0;
  double km = 0;
  int tours = 0;
  ClientResult(this.name, this.mode);

  bool get confirmed => paid != null;
  double get revenue => paid ?? invoiced;

  /// Négatif quand le commissionnaire a payé moins que facturé.
  double get gap => confirmed ? paid! - invoiced : 0;
  double get revenuePerKm => km > 0 ? revenue / km : 0;
}

/// Une phrase qui dit quoi regarder, avec la destination où agir.
class Insight {
  final String text;
  final bool good;
  const Insight(this.text, {this.good = false});
}

/// Le compte de résultat d'un mois.
///
/// Tout est en HT : la TVA des dépenses est récupérée. Les salaires sont
/// comptés chargés (brut + charges patronales). Les coûts fixes (salaires,
/// détention et assurance des camions) sont au prorata des jours écoulés,
/// sinon le résultat serait faussement négatif en cours de mois.
class MonthResult {
  final DateTime month;
  final List<Tour> tours;
  final double revenue;
  final double expenses;
  final Map<ExpenseType, double> expensesByType;
  final double salariesFull, trucksFull;
  final double chargeRate;
  final double ratio;
  final int daysElapsed, daysInMonth;
  final double km;
  final int workDays;
  final List<TruckResult> trucks;
  final List<DriverResult> drivers;
  final List<ClientResult> clients;
  final List<Tour> untaxed;
  final List<PendingPoints> pendingPoints;
  final int finesWithoutDriver;

  const MonthResult({
    required this.month,
    required this.tours,
    required this.revenue,
    required this.expenses,
    required this.expensesByType,
    required this.salariesFull,
    required this.trucksFull,
    required this.chargeRate,
    required this.ratio,
    required this.daysElapsed,
    required this.daysInMonth,
    required this.km,
    required this.workDays,
    required this.trucks,
    required this.drivers,
    required this.clients,
    required this.untaxed,
    required this.pendingPoints,
    required this.finesWithoutDriver,
  });

  double get salaries => salariesFull * ratio;
  double get trucksFixed => trucksFull * ratio;
  double get costs => expenses + salaries + trucksFixed;
  double get result => revenue - costs;
  double get margin => revenue > 0 ? result / revenue * 100 : 0;
  double get revenuePerKm => km > 0 ? revenue / km : 0;
  double get costPerKm => km > 0 ? costs / km : 0;
  double get resultPerDay => workDays > 0 ? result / workDays : 0;
  double get revenuePerTour => tours.isEmpty ? 0 : revenue / tours.length;
  bool get isCurrent => ratio > 0 && ratio < 1;
  bool get isOver => ratio >= 1;

  double get penalties => clients.fold(0, (s, c) => s + c.penalties);
  double get gap => clients.fold(0, (s, c) => s + c.gap);

  /// Tant qu'un commissionnaire n'a pas de relevé, le CA reste une estimation.
  bool get revenueConfirmed =>
      clients.isNotEmpty && clients.every((c) => c.confirmed);

  /// Fin de mois si le rythme actuel se maintient. Null tant que le mois
  /// est trop peu entamé pour que la projection veuille dire quelque chose.
  double? get projection {
    if (!isCurrent || ratio < 0.2) return null;
    return (revenue - expenses) / ratio - salariesFull - trucksFull;
  }

  /// Chiffre d'affaires qu'il faudrait sur le mois entier pour couvrir
  /// tous les coûts, au rythme actuel des dépenses.
  double get breakEvenRevenue {
    if (ratio <= 0) return salariesFull + trucksFull;
    return expenses / ratio + salariesFull + trucksFull;
  }
}

class Profitability {
  static const inactive = {
    DriverStatus.finDeMission,
    DriverStatus.vire,
    DriverStatus.demission,
  };

  static bool _inMonth(DateTime d, DateTime m) =>
      d.year == m.year && d.month == m.month;

  static String _day(DateTime d) => '${d.year}-${d.month}-${d.day}';

  static String _monthKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}';

  /// Revenu de chaque tournée du mois, d'après les tarifs : options et
  /// indexation gasoil comprises — la somme est égale à la facturation.
  ///
  /// Pour un commissionnaire au point, le montant du couple
  /// commissionnaire × chauffeur (points du mois × prix) est réparti à
  /// parts égales sur ses tournées.
  static Map<String, double> tourRevenues(AppState s, DateTime month,
      {List<PendingPoints>? pending}) {
    final out = <String, double>{};
    final groups = <String, List<Tour>>{};

    for (final t in s.tours) {
      if (!_inMonth(t.date, month)) continue;
      final pricing = s.getClientPricing(t.companyName);
      if (pricing == null) {
        out[t.id] = 0;
        continue;
      }
      final assign = s.getAssignment(t.driverName);
      final fuel = 1 + (pricing.fuelIndexPercent ?? 0) / 100;

      var options = 0.0;
      if (t.hasHandling && pricing.handlingEnabled) {
        options += pricing.handlingPrice ?? 0;
      }
      if (t.extraKm > 0 && pricing.extraKmEnabled) {
        options += t.extraKm * (pricing.extraKmPrice ?? 0);
      }
      if (t.extraTour && pricing.extraTourEnabled) {
        options += pricing.extraTourPrice ?? 0;
      }

      if (pricing.billingMode == BillingMode.auPoint) {
        out[t.id] = options;
        groups
            .putIfAbsent('${pricing.companyName}\u0000${t.driverName}', () => [])
            .add(t);
      } else {
        out[t.id] =
            (assign?.customDailyRate ?? pricing.dailyRate) * fuel + options;
      }
    }

    for (final list in groups.values) {
      final first = list.first;
      final pricing = s.getClientPricing(first.companyName)!;
      final assign = s.getAssignment(first.driverName);
      final price = assign?.customPricePerPoint ?? pricing.pricePerPoint ?? 0;
      final fuel = 1 + (pricing.fuelIndexPercent ?? 0) / 100;

      final manual =
          s.getMonthlyPoints(month, pricing.companyName, first.driverName);
      final legacy = list.fold<int>(0, (n, t) => n + t.clientsCount);
      if (manual == null) {
        pending?.add(PendingPoints(
            pricing.companyName, first.driverName, list.length, legacy));
      }
      final points = manual?.points ?? legacy;
      final share = points * price * fuel / list.length;
      for (final t in list) {
        out[t.id] = out[t.id]! + share;
      }
    }
    return out;
  }

  /// Revenu réel de chaque tournée : pour un commissionnaire dont le
  /// relevé est saisi, le montant payé est réparti au prorata du facturé.
  static Map<String, double> realTourRevenues(AppState s, DateTime month,
      {List<PendingPoints>? pending}) {
    final estimated = tourRevenues(s, month, pending: pending);
    final byClient = <String, List<Tour>>{};
    for (final t in s.tours) {
      if (!_inMonth(t.date, month)) continue;
      final pricing = s.getClientPricing(t.companyName);
      if (pricing == null) continue;
      byClient.putIfAbsent(pricing.companyName, () => []).add(t);
    }
    final out = Map<String, double>.from(estimated);
    byClient.forEach((client, list) {
      final st = s.getStatement(month, client);
      if (st == null) return;
      final invoiced = list.fold<double>(0, (a, t) => a + (estimated[t.id] ?? 0));
      for (final t in list) {
        out[t.id] = invoiced > 0
            ? st.paidAmount * (estimated[t.id] ?? 0) / invoiced
            : st.paidAmount / list.length;
      }
    });
    return out;
  }

  /// Lignes de facturation du mois, une par commissionnaire.
  static List<ClientBillingData> billing(AppState s, DateTime month) {
    final billing = <String, ClientBillingData>{};
    final pointGroups = <String, List<Tour>>{};

    for (final tour in s.tours) {
      if (!_inMonth(tour.date, month)) continue;

      final pricing = s.getClientPricing(tour.companyName);
      final company = pricing?.companyName ?? tour.companyName ?? '—';
      final assignment = s.getAssignment(tour.driverName);
      final dailyRate =
          assignment?.customDailyRate ?? pricing?.dailyRate ?? 0.0;
      final pricePerPoint =
          assignment?.customPricePerPoint ?? pricing?.pricePerPoint ?? 0.0;
      final mode = pricing?.billingMode ?? BillingMode.aLaFiche;

      final client = billing.putIfAbsent(
          company,
          () => ClientBillingData(
                companyName: company,
                dailyRate: dailyRate,
                fuelIndexPercent: pricing?.fuelIndexPercent,
                siret: pricing?.siret,
                tvaIntra: pricing?.tvaIntra,
                address: pricing?.address,
                phone: pricing?.phone,
                contactName: pricing?.contactName,
                billingMode: mode,
                pricePerPoint: pricePerPoint,
              ));

      client.tours++;
      if (mode == BillingMode.auPoint) {
        pointGroups
            .putIfAbsent('$company\u0000${tour.driverName}', () => [])
            .add(tour);
      } else if (pricing != null) {
        client.baseAmount += dailyRate;
      }

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

    for (final list in pointGroups.values) {
      final first = list.first;
      final pricing = s.getClientPricing(first.companyName)!;
      final client = billing[pricing.companyName]!;
      final assign = s.getAssignment(first.driverName);
      final price = assign?.customPricePerPoint ?? pricing.pricePerPoint ?? 0;
      final points = s
              .getMonthlyPoints(month, pricing.companyName, first.driverName)
              ?.points ??
          list.fold<int>(0, (n, t) => n + t.clientsCount);
      client.totalPoints += points;
      client.baseAmount += points * price;
    }

    return billing.values.toList()
      ..sort((a, b) => b.totalHT.compareTo(a.totalHT));
  }

  static MonthResult month(AppState s, DateTime month, {DateTime? now}) {
    now ??= DateTime.now();
    final m = DateTime(month.year, month.month);
    final daysInMonth = DateTime(m.year, m.month + 1, 0).day;
    final int daysElapsed;
    if (m.isAfter(DateTime(now.year, now.month))) {
      daysElapsed = 0;
    } else if (_inMonth(now, m)) {
      daysElapsed = now.day;
    } else {
      daysElapsed = daysInMonth;
    }
    final ratio = daysElapsed / daysInMonth;
    final charge = 1 + s.employerChargeRate;

    final pending = <PendingPoints>[];
    final estimated = tourRevenues(s, m, pending: pending);
    final revenues = realTourRevenues(s, m);
    final tours = s.tours.where((t) => _inMonth(t.date, m)).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final trucks = <String, TruckResult>{};
    TruckResult truck(String plate) =>
        trucks.putIfAbsent(plate, () => TruckResult(plate));
    final drivers = <String, DriverResult>{};
    final clients = <String, ClientResult>{};
    final untaxed = <Tour>[];
    final workDays = <String>{};

    // Combien de tournées chaque chauffeur a faites sur chaque camion :
    // son salaire est réparti sur ses camions dans la même proportion.
    final toursByDriverTruck = <String, Map<String, int>>{};

    for (final t in tours) {
      final r = revenues[t.id] ?? 0;
      final pricing = s.getClientPricing(t.companyName);
      if (pricing == null) untaxed.add(t);

      truck(t.truckPlate)
        ..revenue += r
        ..km += t.kmTotal
        ..tours += 1;

      final d = drivers.putIfAbsent(t.driverName, () => DriverResult(t.driverName))
        ..revenue += r
        ..km += t.kmTotal;
      d._days.add(_day(t.date));
      workDays.add('${t.driverName}|${_day(t.date)}');

      if (pricing != null) {
        clients.putIfAbsent(
            pricing.companyName,
            () => ClientResult(pricing.companyName, pricing.billingMode))
          ..invoiced += estimated[t.id] ?? 0
          ..km += t.kmTotal
          ..tours += 1;
      }

      final byTruck = toursByDriverTruck.putIfAbsent(t.driverName, () => {});
      byTruck[t.truckPlate] = (byTruck[t.truckPlate] ?? 0) + 1;
    }

    for (final c in clients.values) {
      final st = s.getStatement(m, c.name);
      if (st != null) {
        c.paid = st.paidAmount;
        c.penalties = st.penalties;
      }
    }

    final expensesByType = <ExpenseType, double>{};
    var expenses = 0.0;
    var finesWithoutDriver = 0;
    for (final e in s.expenses) {
      if (!_inMonth(e.date, m)) continue;
      final ht = e.amountHT;
      expenses += ht;
      expensesByType[e.type] = (expensesByType[e.type] ?? 0) + ht;
      truck(e.truckPlate).expenses += ht;
      if (e.type == ExpenseType.fine && e.driverName == null) {
        finesWithoutDriver++;
      }
    }

    var trucksFull = 0.0;
    for (final t in s.trucks) {
      if (t.truckStatus == TruckStatus.vendu) continue;
      trucksFull += t.totalMonthlyCost;
      truck(t.plate).fixed = t.totalMonthlyCost * ratio;
    }

    var salariesFull = 0.0;
    for (final d in s.drivers) {
      if (inactive.contains(d.status)) continue;
      final cost = d.totalSalary * charge;
      salariesFull += cost;
      final prorata = cost * ratio;
      drivers.putIfAbsent(d.name, () => DriverResult(d.name)).salary = prorata;

      final byTruck = toursByDriverTruck[d.name];
      if (byTruck == null || byTruck.isEmpty) continue;
      final total = byTruck.values.fold<int>(0, (a, b) => a + b);
      byTruck.forEach((plate, n) => truck(plate).salaries += prorata * n / total);
    }

    final km = tours.fold<double>(0, (a, t) => a + t.kmTotal);

    return MonthResult(
      month: m,
      tours: tours,
      revenue: revenues.values.fold(0, (a, b) => a + b),
      expenses: expenses,
      expensesByType: expensesByType,
      salariesFull: salariesFull,
      trucksFull: trucksFull,
      chargeRate: s.employerChargeRate,
      ratio: ratio,
      daysElapsed: daysElapsed,
      daysInMonth: daysInMonth,
      km: km,
      workDays: workDays.length,
      trucks: trucks.values.where((t) => t.tours > 0 || t.costs > 0).toList()
        ..sort((a, b) => b.result.compareTo(a.result)),
      drivers: drivers.values.where((d) => d.km > 0 || d.salary > 0).toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue)),
      clients: clients.values.toList()
        ..sort((a, b) => b.revenue.compareTo(a.revenue)),
      untaxed: untaxed,
      pendingPoints: pending,
      finesWithoutDriver: finesWithoutDriver,
    );
  }

  // ── Ce qu'il faut retenir ─────────────────────────────────────────────

  static String _eur(double v) {
    final neg = v < 0;
    final digits = v.abs().toStringAsFixed(0);
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write(' ');
      out.write(digits[i]);
    }
    return '${neg ? '−' : ''}$out €';
  }

  static String _perKm(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} €/km';

  /// Les trois ou quatre constats qui méritent une action, du plus coûteux
  /// au moins coûteux. Rien d'affiché quand il n'y a rien à dire.
  static List<Insight> insights(MonthResult r, {MonthResult? previous}) {
    final out = <(double, Insight)>[]; // (poids en €, constat)

    // Camion qui ne roule pas mais coûte.
    for (final t in r.trucks) {
      if (t.tours == 0 && t.costs > 0) {
        out.add((t.costs, Insight(
            '${t.plate} n’a fait aucune tournée : ${_eur(t.costs)} de coûts sans recette.')));
      }
    }

    // Camion qui roule à perte.
    final losing = r.trucks.where((t) => t.tours > 0 && t.result < 0).toList()
      ..sort((a, b) => a.result.compareTo(b.result));
    if (losing.isNotEmpty) {
      final t = losing.first;
      out.add((-t.result, Insight(
          '${t.plate} perd ${_eur(-t.result)} : il coûte ${_perKm(t.costPerKm)} '
          'et rapporte ${_perKm(t.revenuePerKm)}.')));
    }

    // Écart entre commissionnaires.
    // Un commissionnaire dont les points ne sont pas saisis affiche 0 €/km :
    // le comparer n'apprendrait rien.
    final pendingNames = r.pendingPoints.map((p) => p.companyName).toSet();
    final ranked = r.clients
        .where((c) => c.km > 0 && c.revenue > 0 && !pendingNames.contains(c.name))
        .toList()
      ..sort((a, b) => b.revenuePerKm.compareTo(a.revenuePerKm));
    if (ranked.length >= 2 &&
        ranked.first.revenuePerKm > ranked.last.revenuePerKm * 1.15) {
      final best = ranked.first, worst = ranked.last;
      out.add((
        (best.revenuePerKm - worst.revenuePerKm) * worst.km,
        Insight('${best.name} rapporte ${_perKm(best.revenuePerKm)}, '
            '${worst.name} seulement ${_perKm(worst.revenuePerKm)}. '
            'À renégocier, ou à réaffecter.')
      ));
    }

    // Ce que les commissionnaires ont retenu.
    for (final c in r.clients) {
      if (c.penalties > 0) {
        final pct = c.revenue > 0 ? c.penalties / (c.revenue + c.penalties) * 100 : 0;
        out.add((c.penalties, Insight(
            '${c.name} a retenu ${_eur(c.penalties)} de pénalités '
            '(${pct.toStringAsFixed(1).replaceAll('.', ',')} % du mois).')));
      }
      if (c.confirmed && c.gap < -1) {
        out.add((-c.gap, Insight(
            '${c.name} a payé ${_eur(-c.gap)} de moins que tes tarifs. '
            'Vérifie le relevé.')));
      }
    }

    // Carburant qui dérape d'un mois sur l'autre.
    final fuel = r.expensesByType[ExpenseType.fuel] ?? 0;
    final prevFuel = previous?.expensesByType[ExpenseType.fuel] ?? 0;
    if (previous != null && r.km > 0 && previous.km > 0 && prevFuel > 0) {
      final now = fuel / r.km, before = prevFuel / previous.km;
      if (now > before * 1.10) {
        out.add(((now - before) * r.km, Insight(
            'Carburant : ${_perKm(now)} contre ${_perKm(before)} le mois dernier '
            '(+${((now / before - 1) * 100).round()} %).')));
      }
    }

    // Amendes à désigner.
    if (r.finesWithoutDriver > 0) {
      out.add((0, Insight(
          '${r.finesWithoutDriver} amende${r.finesWithoutDriver > 1 ? "s" : ""} '
          'sans chauffeur : à désigner, sinon l’entreprise paie la majoration.')));
    }

    // Combien manque-t-il pour l'équilibre ?
    if (r.ratio > 0 && r.tours.isNotEmpty) {
      final fullRevenue = r.isCurrent ? r.revenue / r.ratio : r.revenue;
      final missing = r.breakEvenRevenue - fullRevenue;
      if (missing > 0 && r.revenuePerTour > 0) {
        final n = (missing / r.revenuePerTour).ceil();
        out.add((missing, Insight(
            'Il manque ${_eur(missing)} de chiffre d’affaires pour être à '
            'l’équilibre ce mois-ci, soit environ $n tournée${n > 1 ? "s" : ""} de plus.')));
      } else if (missing <= 0) {
        out.add((0, Insight(
            r.isCurrent
                ? 'Au rythme actuel, le mois finit bénéficiaire.'
                : 'Mois bénéficiaire : tous les coûts sont couverts.',
            good: true)));
      }
    }

    out.sort((a, b) => b.$1.compareTo(a.$1));
    return out.map((e) => e.$2).take(4).toList();
  }

  /// Variation en %, null si la comparaison n'a pas de sens.
  static double? change(double now, double before) {
    if (before.abs() < 1) return null;
    return (now - before) / before.abs() * 100;
  }

  static String monthKey(DateTime d) => _monthKey(d);
}
