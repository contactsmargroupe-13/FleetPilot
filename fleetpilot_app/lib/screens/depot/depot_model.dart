import '../../providers/app_state.dart';
import '../add_truck.dart';
import '../models/driver.dart';
import '../models/tour.dart';

/// État d'un camion tel qu'il se lit dans la cour.
enum YardState { dispo, tournee, ct, panne }

String yardStateLabel(YardState s) {
  switch (s) {
    case YardState.dispo:   return 'Au dépôt, prêt';
    case YardState.tournee: return 'En tournée';
    case YardState.ct:      return 'Échéance à surveiller';
    case YardState.panne:   return 'Immobilisé';
  }
}

class YardTruck {
  final Truck truck;
  final YardState state;
  final Tour? tour;
  final String? driverName;

  /// Index de l'emplacement attribué dans la cour.
  final int bay;

  /// Détail de l'immobilisation, si immobilisé.
  final String? issue;

  const YardTruck({
    required this.truck,
    required this.state,
    required this.bay,
    this.tour,
    this.driverName,
    this.issue,
  });

  /// Les camions immobilisés sont garés devant l'atelier, pas sur leur place.
  bool get atWorkshop => state == YardState.panne;

  /// En tournée : la place est vide, on dessine une silhouette.
  bool get isGhost => state == YardState.tournee;
}

class YardPerson {
  final Driver driver;
  final bool alert;
  const YardPerson({required this.driver, this.alert = false});
}

/// Instantané de la cour à une date donnée, dérivé de l'état de l'app.
class YardData {
  final List<YardTruck> trucks;
  final List<YardPerson> people;
  final int extraPeople;
  final int bayCount;
  final DateTime day;

  const YardData({
    required this.trucks,
    required this.people,
    required this.extraPeople,
    required this.bayCount,
    required this.day,
  });

  int countOf(YardState s) => trucks.where((t) => t.state == s).length;
  int get freeBays => bayCount - trucks.length;

  bool get isEmpty => trucks.isEmpty;

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Au plus trois silhouettes de chauffeurs : au-delà la cour devient illisible.
  static const int maxPeople = 3;

  factory YardData.from(AppState state, {DateTime? day}) {
    final d = day ?? DateTime.now();

    final dayTours = state.tours.where((t) => _sameDay(t.date, d)).toList();
    Tour? tourFor(String plate) {
      for (final t in dayTours) {
        if (t.truckPlate == plate && t.status != 'terminée') return t;
      }
      return null;
    }

    final fleet = state.trucks
        .where((t) => t.truckStatus != TruckStatus.vendu)
        .toList()
      ..sort((a, b) => a.plate.compareTo(b.plate));

    final trucks = <YardTruck>[];
    for (var i = 0; i < fleet.length; i++) {
      final t = fleet[i];
      final tour = tourFor(t.plate);

      YardState st;
      String? issue;
      if (t.truckStatus == TruckStatus.enPanne ||
          t.truckStatus == TruckStatus.enReparation ||
          t.truckStatus == TruckStatus.hs) {
        st = YardState.panne;
        issue = truckStatusLabel(t.truckStatus);
      } else if (tour != null) {
        st = YardState.tournee;
      } else if (t.ctStatus >= 2 || t.insuranceStatus >= 2) {
        st = YardState.ct;
        issue = t.ctStatus >= 2
            ? 'Contrôle technique à échéance'
            : 'Assurance à échéance';
      } else {
        st = YardState.dispo;
      }

      trucks.add(YardTruck(
        truck: t,
        state: st,
        bay: i,
        tour: tour,
        driverName: tour?.driverName ?? t.assignedDriverName,
        issue: issue,
      ));
    }

    // Chauffeurs présents : en poste, et sans tournée en cours aujourd'hui.
    final out = dayTours.map((t) => t.driverName.toLowerCase()).toSet();
    final present = state.drivers.where((dr) {
      final gone = dr.status == DriverStatus.vire ||
          dr.status == DriverStatus.demission ||
          dr.status == DriverStatus.finDeMission;
      return !gone && !out.contains(dr.name.toLowerCase());
    }).toList();

    final alerting = state.alertDocuments
        .map((doc) => doc.driverName.toLowerCase())
        .toSet();

    // Ceux qui ont un document en alerte passent devant : ce sont eux qu'il
    // faut voir en arrivant sur l'écran.
    present.sort((a, b) {
      final aa = alerting.contains(a.name.toLowerCase()) ? 0 : 1;
      final bb = alerting.contains(b.name.toLowerCase()) ? 0 : 1;
      if (aa != bb) return aa - bb;
      return a.name.compareTo(b.name);
    });

    final shown = present.take(maxPeople).toList();

    // Au moins six emplacements : une cour à moitié vide dit quelque chose.
    var bays = trucks.length < 6 ? 6 : trucks.length;
    if (bays.isOdd) bays += 1;

    return YardData(
      trucks: trucks,
      people: shown
          .map((dr) => YardPerson(
                driver: dr,
                alert: alerting.contains(dr.name.toLowerCase()),
              ))
          .toList(),
      extraPeople: present.length - shown.length,
      bayCount: bays,
      day: d,
    );
  }
}
