import '../providers/app_state.dart';
import '../screens/models/odometer_reading.dart';
import '../screens/models/tour.dart';
import 'profitability.dart';

/// Une journée commencée au compteur et jamais terminée.
class OpenDay {
  final OdometerReading start;

  /// Relevé suivant du même camion, s'il existe : il donne les km.
  final OdometerReading? next;
  const OpenDay(this.start, this.next);

  int? get km => next == null ? null : next!.km - start.km;
  String get driverName => start.driverName ?? '—';
  DateTime get date => start.date;
  String get truckPlate => start.truckPlate;
}

/// Pour un camion : ce que dit le compteur contre ce qui a été déclaré.
class OdometerGap {
  final String plate;
  final int odometerKm;
  final double declaredKm;
  const OdometerGap(this.plate, this.odometerKm, this.declaredKm);
  double get ratio => odometerKm > 0 ? (declaredKm - odometerKm) / odometerKm : 0;
}

class Issue {
  final String text;

  /// Où corriger : destination de la coquille et sous-onglet.
  final String destination;
  final int tab;
  const Issue(this.text, this.destination, this.tab);
}

/// La part des chiffres du mois qui repose sur des données réelles.
class Reliability {
  final int score; // 0–100
  final int toursTotal, toursMeasured;
  final int silentDays, openDays;
  final List<Issue> issues;
  const Reliability({
    required this.score,
    required this.toursTotal,
    required this.toursMeasured,
    required this.silentDays,
    required this.openDays,
    required this.issues,
  });
}

class DataQuality {
  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool _hasTour(AppState s, String driver, DateTime day) => s.tours.any(
      (t) => t.driverName == driver && _sameDay(t.date, day));

  /// Journées commencées par une photo du compteur, sans tournée enregistrée.
  /// Le relevé suivant du camion — quel que soit le chauffeur — donne les km.
  static List<OpenDay> openDays(AppState s, {DateTime? month}) {
    final byTruck = <String, List<OdometerReading>>{};
    for (final r in s.odometer) {
      byTruck.putIfAbsent(r.truckPlate, () => []).add(r);
    }
    final today = DateTime.now();
    final out = <OpenDay>[];
    for (final list in byTruck.values) {
      list.sort((a, b) => a.date.compareTo(b.date));
      for (var i = 0; i < list.length; i++) {
        final r = list[i];
        if (!r.isStart || r.driverName == null) continue;
        if (month != null &&
            (r.date.year != month.year || r.date.month != month.month)) {
          continue;
        }
        // La journée du jour est peut-être encore en cours.
        if (_sameDay(r.date, today)) continue;
        if (_hasTour(s, r.driverName!, r.date)) continue;
        out.add(OpenDay(r, i + 1 < list.length ? list[i + 1] : null));
      }
    }
    out.sort((a, b) => b.date.compareTo(a.date));
    return out;
  }

  /// Tournée à enregistrer pour une journée ouverte : km du compteur, ou
  /// [km] saisis par le manager quand il n'y a pas encore de relevé suivant.
  static Tour reconstitute(AppState s, OpenDay d, {double? km}) {
    final assign = s.getAssignment(d.driverName);
    return Tour(
      id: '${d.start.id}_reconstitue',
      tourNumber: s.drivers
              .where((x) => x.name == d.driverName)
              .firstOrNull
              ?.assignedTourNumber ??
          '',
      date: d.date,
      driverName: d.driverName,
      truckPlate: d.truckPlate,
      companyName: assign?.companyName,
      kmTotal: km ?? d.km!.toDouble(),
      clientsCount: 0,
      hasHandling: false,
      status: 'terminée',
      kmSource: km == null ? 'reconstitue' : 'saisie',
    );
  }

  /// Écart entre le compteur et les km déclarés, par camion, sur le mois.
  /// Seuls les camions avec au moins deux relevés dans le mois comptent.
  static List<OdometerGap> gaps(AppState s, DateTime month) {
    final out = <OdometerGap>[];
    final byTruck = <String, List<OdometerReading>>{};
    for (final r in s.odometer) {
      if (r.date.year != month.year || r.date.month != month.month) continue;
      byTruck.putIfAbsent(r.truckPlate, () => []).add(r);
    }
    byTruck.forEach((plate, list) {
      if (list.length < 2) return;
      list.sort((a, b) => a.date.compareTo(b.date));
      final first = list.first, last = list.last;
      final odo = last.km - first.km;
      if (odo <= 0) return;
      // Tournées comprises entre les deux relevés : du jour du premier
      // inclus au jour du dernier, exclu s'il s'agit d'un départ.
      final declared = s.tours
          .where((t) =>
              t.truckPlate == plate &&
              !t.date.isBefore(DateTime(first.date.year, first.date.month, first.date.day)) &&
              (last.isStart
                  ? t.date.isBefore(DateTime(last.date.year, last.date.month, last.date.day))
                  : !t.date.isAfter(last.date)))
          .fold<double>(0, (a, t) => a + t.kmTotal);
      out.add(OdometerGap(plate, odo, declared));
    });
    return out;
  }

  /// Chauffeur-jours sans aucune saisie : un jour où l'équipe a roulé, un
  /// chauffeur actif, non absent, n'a rien enregistré.
  static int silentDays(AppState s, DateTime month) {
    final today = DateTime.now();
    final workedDays = <DateTime>{};
    for (final t in s.tours) {
      if (t.date.year == month.year && t.date.month == month.month) {
        workedDays.add(DateTime(t.date.year, t.date.month, t.date.day));
      }
    }
    final active = s.drivers
        .where((d) => !Profitability.inactive.contains(d.status))
        .toList();
    var n = 0;
    for (final day in workedDays) {
      if (_sameDay(day, today)) continue;
      for (final d in active) {
        if (d.hireDate != null && d.hireDate!.isAfter(day)) continue;
        if (_hasTour(s, d.name, day)) continue;
        if (s.absences.any((a) =>
            a.covers(day) && (a.driverName == d.name || a.replacementName == d.name))) {
          continue;
        }
        n++;
      }
    }
    return n;
  }

  static Reliability reliability(AppState s, MonthResult r) {
    final tours = r.tours;
    final measured = tours.where((t) => t.kmMeasured).length;
    final open = openDays(s, month: r.month);
    final silent = silentDays(s, r.month);
    final issues = <Issue>[];

    // 1. Km mesurés plutôt que déclarés (35 %)
    final kmScore = tours.isEmpty ? 1.0 : measured / tours.length;
    final declared = tours.length - measured;
    if (declared > 0) {
      issues.add(Issue(
          '$declared journée${declared > 1 ? "s" : ""} aux km tapés à la main '
          '— la photo du compteur est plus sûre',
          'reglages', 1));
    }

    // 2. Journées complètes (35 %)
    final done = r.workDays;
    final daysScore =
        done + silent + open.length == 0 ? 1.0 : done / (done + silent + open.length);
    if (open.isNotEmpty) {
      issues.add(Issue(
          '${open.length} journée${open.length > 1 ? "s" : ""} commencée'
          '${open.length > 1 ? "s" : ""} mais jamais terminée'
          '${open.length > 1 ? "s" : ""}',
          'gestion', 0));
    }
    if (silent > 0) {
      issues.add(Issue(
          '$silent jour${silent > 1 ? "s" : ""}-chauffeur sans aucune saisie '
          '(oubli ou absence non déclarée)',
          'gestion', 0));
    }

    // 3. Chiffre d'affaires confirmé par les relevés (30 %), une fois le
    //    mois terminé — avant, c'est normal qu'il soit estimé.
    double? caScore;
    if (r.isOver && r.revenue > 0) {
      final confirmed = r.clients
          .where((c) => c.confirmed)
          .fold<double>(0, (a, c) => a + c.revenue);
      caScore = confirmed / r.revenue;
      final missing = r.clients.where((c) => !c.confirmed).length;
      if (missing > 0) {
        issues.add(Issue(
            '$missing relevé${missing > 1 ? "s" : ""} commissionnaire à recopier',
            'rentabilite', 3));
      }
    }
    if (r.pendingPoints.isNotEmpty) {
      issues.add(Issue(
          '${r.pendingPoints.length} saisie${r.pendingPoints.length > 1 ? "s" : ""} '
          'de points manquante${r.pendingPoints.length > 1 ? "s" : ""}',
          'rentabilite', 3));
    }
    if (r.untaxed.isNotEmpty) {
      issues.add(Issue(
          '${r.untaxed.length} tournée${r.untaxed.length > 1 ? "s" : ""} sans tarif',
          'reglages', 0));
    }

    for (final g in gaps(s, r.month)) {
      if (g.ratio.abs() >= 0.05) {
        issues.add(Issue(
            '${g.plate} : ${g.odometerKm} km au compteur, '
            '${g.declaredKm.toStringAsFixed(0)} déclarés '
            '(${g.ratio > 0 ? "+" : "−"}${(g.ratio.abs() * 100).round()} %)',
            'rentabilite', 1));
      }
    }

    final score = caScore == null
        ? (kmScore * 0.5 + daysScore * 0.5)
        : (kmScore * 0.35 + daysScore * 0.35 + caScore * 0.30);

    return Reliability(
      score: (score * 100).round().clamp(0, 100),
      toursTotal: tours.length,
      toursMeasured: measured,
      silentDays: silent,
      openDays: open.length,
      issues: issues,
    );
  }
}
