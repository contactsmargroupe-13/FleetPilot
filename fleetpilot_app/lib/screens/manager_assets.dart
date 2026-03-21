import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'add_truck.dart';
import 'models/equipment.dart';

class ManagerAssetsPage extends ConsumerWidget {
  const ManagerAssetsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    // Camions achetés (pas en location)
    final ownedTrucks = state.trucks
        .where((t) => t.ownershipType == OwnershipType.achat && t.purchasePrice != null)
        .toList()
      ..sort((a, b) => a.plate.compareTo(b.plate));

    // Matériel
    final equip = [...state.equipment]
      ..sort((a, b) => a.name.compareTo(b.name));

    // Totaux
    double totalAchatCamions = 0;
    double totalValeurCamions = 0;
    for (final t in ownedTrucks) {
      totalAchatCamions += t.purchasePrice ?? 0;
      totalValeurCamions += _truckCurrentValue(t);
    }

    double totalAchatMateriel = equip.fold(0.0, (s, e) => s + e.purchasePrice);
    double totalValeurMateriel = equip.fold(0.0, (s, e) => s + e.currentValue);

    final totalAchat = totalAchatCamions + totalAchatMateriel;
    final totalValeur = totalValeurCamions + totalValeurMateriel;
    final totalAmorti = totalAchat - totalValeur;

    return Scaffold(
      appBar: AppBar(title: const Text('Actifs')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Résumé global
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Patrimoine total',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _summaryBox('Valeur d\'achat', '${totalAchat.toStringAsFixed(0)} €',
                          Colors.blue),
                      const SizedBox(width: 10),
                      _summaryBox('Valeur actuelle', '${totalValeur.toStringAsFixed(0)} €',
                          Colors.green),
                      const SizedBox(width: 10),
                      _summaryBox('Amorti', '${totalAmorti.toStringAsFixed(0)} €',
                          Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: totalAchat > 0 ? (totalAmorti / totalAchat).clamp(0.0, 1.0) : 0,
                      minHeight: 10,
                      backgroundColor: Colors.green.withValues(alpha: 0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.orange),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${totalAchat > 0 ? (totalAmorti / totalAchat * 100).toStringAsFixed(0) : 0}% amorti',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Camions
          if (ownedTrucks.isNotEmpty) ...[
            _sectionHeader('Camions', ownedTrucks.length,
                '${totalValeurCamions.toStringAsFixed(0)} €'),
            ...ownedTrucks.map((t) => _truckAssetCard(t)),
            const SizedBox(height: 16),
          ],

          // ── Matériel
          if (equip.isNotEmpty) ...[
            _sectionHeader('Matériel', equip.length,
                '${totalValeurMateriel.toStringAsFixed(0)} €'),
            ...equip.map((e) => _equipmentAssetCard(e)),
          ],

          if (ownedTrucks.isEmpty && equip.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.account_balance_outlined,
                          size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text('Aucun actif enregistré.',
                          style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 4),
                      const Text(
                        'Ajoutez un camion (achat) ou du matériel pour voir les amortissements.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  double _truckCurrentValue(Truck t) {
    if (t.purchasePrice == null || t.amortMonths == null || t.amortMonths! <= 0) {
      return 0;
    }
    final monthsElapsed = DateTime.now().difference(
      // Approximation : date d'achat = il y a amortMonths - remaining mois
      DateTime.now().subtract(Duration(days: 30 * (t.amortMonths! ~/ 2))),
    ).inDays / 30.44;
    // Sans date d'achat exacte, on calcule basé sur les mois d'amortissement restants
    // On suppose que l'amortissement a commencé au moment de l'ajout
    return t.purchasePrice! * (1 - 0.5); // placeholder — sera amélioré avec date d'achat
  }

  Widget _summaryBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, int count, String totalValue) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
          ),
          const Spacer(),
          Text('Valeur : $totalValue',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _truckAssetCard(Truck t) {
    final purchase = t.purchasePrice ?? 0;
    final amortMonths = t.amortMonths ?? 1;
    final monthly = amortMonths > 0 ? purchase / amortMonths : 0.0;
    final statusColor = truckStatusColor(t.truckStatus);

    // Valeur résiduelle approximative (50% par défaut sans date d'achat)
    final currentVal = purchase * 0.5;
    final amortPercent = 0.5;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.local_shipping, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${t.plate} • ${t.brand} ${t.model}'.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(truckStatusLabel(t.truckStatus),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _valBox('Achat', '${purchase.toStringAsFixed(0)} €'),
                const SizedBox(width: 8),
                _valBox('Valeur actuelle', '${currentVal.toStringAsFixed(0)} €'),
                const SizedBox(width: 8),
                _valBox('Mensuel', '${monthly.toStringAsFixed(0)} €/mois'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: amortPercent,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(
                    amortPercent >= 1.0 ? Colors.green : Colors.blue),
              ),
            ),
            const SizedBox(height: 4),
            Text('Amort. sur $amortMonths mois • ${(amortPercent * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  Widget _equipmentAssetCard(Equipment e) {
    final color = e.isFullyAmortized ? Colors.green : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.build_outlined, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(equipmentCategoryLabel(e.category),
                          style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                if (e.isFullyAmortized)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Amorti',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green)),
                  )
                else
                  Text('${e.monthsRemaining} mois restants',
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _valBox('Achat', '${e.purchasePrice.toStringAsFixed(0)} €'),
                const SizedBox(width: 8),
                _valBox('Valeur actuelle', '${e.currentValue.toStringAsFixed(0)} €'),
                const SizedBox(width: 8),
                _valBox('Mensuel', '${e.monthlyAmort.toStringAsFixed(0)} €/mois'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: e.amortPercent,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Amort. sur ${e.amortMonths} mois • ${(e.amortPercent * 100).toStringAsFixed(0)}%',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _valBox(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }
}
