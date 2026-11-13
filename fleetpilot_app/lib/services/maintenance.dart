import '../providers/app_state.dart';
import '../screens/add_truck.dart';
import '../screens/models/expense.dart';

/// Où en est un camion de son prochain entretien.
class ServiceStatus {
  final Truck truck;
  final double kmSince;
  final DateTime? lastService;
  const ServiceStatus(this.truck, this.kmSince, this.lastService);

  int get interval => truck.serviceIntervalKm!;
  double get remaining => interval - kmSince;
  bool get overdue => remaining <= 0;

  /// À signaler : dépassé, ou moins de 10 % de l'intervalle restant.
  bool get soon => remaining <= interval * 0.10;
}

class Maintenance {
  /// Km roulés depuis le dernier entretien, d'après les tournées saisies.
  ///
  /// Les anciennes versions rangeaient chaque dépense (plein, péage…) dans
  /// l'historique d'entretien : seules comptent les entrées saisies à la
  /// main ou issues d'une dépense de type « Entretien ».
  static ServiceStatus? status(AppState s, Truck t) {
    if (t.serviceIntervalKm == null || t.serviceIntervalKm! <= 0) return null;
    final byId = {for (final e in s.expenses) 'exp_${e.id}': e};
    DateTime? last;
    for (final m in t.maintenances) {
      final linked = byId[m.id];
      if (m.id.startsWith('exp_') &&
          (linked == null || linked.type != ExpenseType.maintenance)) {
        continue;
      }
      if (last == null || m.date.isAfter(last)) last = m.date;
    }
    final km = s.tours
        .where((tour) =>
            tour.truckPlate == t.plate && (last == null || tour.date.isAfter(last)))
        .fold<double>(0, (a, tour) => a + tour.kmTotal);
    return ServiceStatus(t, km, last);
  }

  static List<ServiceStatus> dueSoon(AppState s) => [
        for (final t in s.trucks)
          if (t.truckStatus != TruckStatus.vendu)
            if (status(s, t) case final st? when st.soon) st,
      ];
}
