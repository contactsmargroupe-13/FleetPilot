class AiLossAnalysis {
  final String severity;
  final String summary;
  final List<String> reasons;
  final List<String> actions;
  final int score;

  AiLossAnalysis({
    required this.severity,
    required this.summary,
    required this.reasons,
    required this.actions,
    required this.score,
  });
}

class ManagerAiService {
  static AiLossAnalysis analyzeTruckLoss({
    required String truckName,
    required double revenue,
    required double expenses,
    required double fuelExpenses,
    required double maintenanceExpenses,
    required double fixedCosts,
    required double profit,
    required double km,
    required double costPerKm,
    required double litersPer100,
  }) {
    final List<String> reasons = [];
    final List<String> actions = [];

    String severity = 'success';
    String summary = 'Le camion est rentable sur la période sélectionnée.';
    int score = 100;

    if (profit < 0) {
      severity = 'danger';
      summary = 'Le camion $truckName est en perte sur la période sélectionnée.';
      score -= 40;
    } else if (revenue > 0 && profit < revenue * 0.1) {
      severity = 'warning';
      summary =
          'Le camion $truckName a une rentabilité faible sur la période sélectionnée.';
      score -= 20;
    }

    if (revenue > 0) {
      final fuelRate = fuelExpenses / revenue;
      final maintenanceRate = maintenanceExpenses / revenue;
      final fixedRate = fixedCosts / revenue;

      if (fuelRate > 0.35) {
        reasons.add('Le carburant représente une part trop élevée du chiffre généré.');
        actions.add('Comparer les dépenses carburant avec les mois précédents.');
        score -= 15;
      }

      if (maintenanceRate > 0.15) {
        reasons.add('Les frais de réparation sont élevés sur cette période.');
        actions.add(
          'Vérifier si ce camion nécessite une révision ou une immobilisation préventive.',
        );
        score -= 12;
      }

      if (fixedRate > 0.25) {
        reasons.add('Les coûts fixes du camion pèsent fortement sur la rentabilité.');
        actions.add(
          'Vérifier si l’utilisation du camion est suffisante pour couvrir ses coûts fixes.',
        );
        score -= 12;
      }
    }

    if (expenses > revenue && revenue > 0) {
      reasons.add('Les dépenses variables dépassent le revenu estimé.');
      actions.add('Réduire les trajets peu rentables ou réaffecter le camion.');
      score -= 15;
    }

    if (km <= 0) {
      reasons.add('Aucun kilomètre n’a été saisi pour ce camion sur la période.');
      actions.add('Vérifier la saisie chauffeur pour fiabiliser les indicateurs.');
      score -= 10;
    }

    if (costPerKm > 1.2 && km > 0) {
      reasons.add('Le coût au kilomètre est élevé.');
      actions.add('Comparer ce camion aux autres véhicules de la flotte.');
      score -= 12;
    } else if (costPerKm > 0.8 && km > 0) {
      score -= 6;
    }

    if (litersPer100 > 0) {
      if (litersPer100 > 18) {
        reasons.add('La consommation carburant semble anormale.');
        actions.add('Contrôler l’état du véhicule et le style de conduite.');
        score -= 15;
      } else if (litersPer100 > 14) {
        reasons.add('La consommation carburant est assez élevée.');
        actions.add('Surveiller la consommation sur les prochains trajets.');
        score -= 8;
      }
    }

    if (score < 0) score = 0;
    if (score > 100) score = 100;

    if (score < 40) {
      severity = 'danger';
    } else if (score < 70 && severity == 'success') {
      severity = 'warning';
    }

    if (reasons.isEmpty) {
      reasons.add('Aucune anomalie majeure détectée sur la période.');
      actions.add('Continuer le suivi mensuel pour confirmer la tendance.');
    }

    return AiLossAnalysis(
      severity: severity,
      summary: summary,
      reasons: reasons,
      actions: actions,
      score: score,
    );
  }
}