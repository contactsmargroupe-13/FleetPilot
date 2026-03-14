import 'package:flutter/material.dart';
import 'add_truck.dart';
import '../store/app_store.dart';

class ManagerVehiclesPage extends StatefulWidget {
  const ManagerVehiclesPage({super.key});

  @override
  State<ManagerVehiclesPage> createState() => _ManagerVehiclesPageState();
}

class _ManagerVehiclesPageState extends State<ManagerVehiclesPage> {

  Future<void> _addTruck() async {
    final result = await Navigator.push<Truck>(
      context,
      MaterialPageRoute(builder: (_) => const AddTruckPage()),
    );
    if (result != null) {
      setState(() => AppStore.addTruck(result));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camion ajouté : ${result.plate}')),
      );
    }
  }

  Future<void> _editTruck(Truck truck) async {
    final result = await Navigator.push<Truck>(
      context,
      MaterialPageRoute(builder: (_) => AddTruckPage(truck: truck)),
    );
    if (result != null) {
      setState(() => AppStore.updateTruck(truck.plate, result));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camion mis à jour : ${result.plate}')),
      );
    }
  }

  Future<void> _deleteTruck(Truck truck) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer le camion'),
        content: Text('Supprimer ${truck.plate} — ${truck.model} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() => AppStore.deleteTruck(truck.plate));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Camion supprimé : ${truck.plate}')),
      );
    }
  }

  void _showTruckDetail(Truck truck) {
    DateTime selectedMonth =
        DateTime(DateTime.now().year, DateTime.now().month, 1);

    const monthNames = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            final tours = AppStore.tours
                .where((t) =>
                    t.truckPlate == truck.plate &&
                    t.date.year == selectedMonth.year &&
                    t.date.month == selectedMonth.month)
                .toList()
              ..sort((a, b) => b.date.compareTo(a.date));

            final totalKm = tours.fold(0.0, (s, t) => s + t.kmTotal);
            final monthLabel =
                '${monthNames[selectedMonth.month - 1]} ${selectedMonth.year}';

            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              minChildSize: 0.5,
              expand: false,
              builder: (_, scrollCtrl) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
                  // En-tête
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${truck.plate}',
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(vehicleTypeLabel(truck.vehicleType),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                            )),
                      ),
                    ],
                  ),
                  if (truck.brand.isNotEmpty || truck.model.isNotEmpty)
                    Text(
                      '${truck.brand} ${truck.model}'
                          .trim()
                          + (truck.year != null ? ' • ${truck.year}' : ''),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 16),

                  // Assurance
                  if (truck.insurerName != null ||
                      truck.insuranceExpiry != null)
                    _InsuranceBadge(truck: truck),

                  const SizedBox(height: 16),

                  // Navigation mois
                  Row(
                    children: [
                      OutlinedButton(
                        onPressed: () => setSheet(() {
                          selectedMonth = DateTime(
                              selectedMonth.year, selectedMonth.month - 1);
                        }),
                        child: const Icon(Icons.chevron_left),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Center(
                          child: Text(monthLabel,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => setSheet(() {
                          selectedMonth = DateTime(
                              selectedMonth.year, selectedMonth.month + 1);
                        }),
                        child: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (tours.isNotEmpty)
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _chip(Icons.route_outlined,
                            '${tours.length} tournée(s)'),
                        _chip(Icons.speed_outlined,
                            '${totalKm.toStringAsFixed(0)} km'),
                      ],
                    ),
                  const SizedBox(height: 12),

                  ...tours.map((t) {
                    final d = t.date.day.toString().padLeft(2, '0');
                    final m = t.date.month.toString().padLeft(2, '0');
                    return Card(
                      child: ListTile(
                        title: Text('Tournée ${t.tourNumber} — $d/$m'),
                        subtitle: Text(
                          '${t.driverName}'
                          '${t.companyName != null ? ' • ${t.companyName}' : ''}'
                          '${t.sector != null ? ' • ${t.sector}' : ''}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${t.kmTotal.toStringAsFixed(0)} km',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            _statusDot(t.status),
                          ],
                        ),
                      ),
                    );
                  }),

                  if (tours.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                          child: Text('Aucune tournée ce mois-ci.')),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trucks = AppStore.trucks;

    // Alertes assurance
    final expiredCount = trucks
        .where((t) => t.insuranceStatus == 3)
        .length;
    final soonCount = trucks
        .where((t) => t.insuranceStatus == 2)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Camions',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700)),
              ),
              FilledButton.icon(
                onPressed: _addTruck,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),

        // Bandeaux alertes assurance
        if (expiredCount > 0)
          _AlertBanner(
            color: Colors.red,
            icon: Icons.warning_rounded,
            message:
                '$expiredCount assurance(s) expirée(s) — action requise',
          ),
        if (soonCount > 0)
          _AlertBanner(
            color: Colors.orange,
            icon: Icons.warning_amber_rounded,
            message:
                '$soonCount assurance(s) expire(nt) dans moins de 30 jours',
          ),

        const SizedBox(height: 12),

        Expanded(
          child: trucks.isEmpty
              ? const Center(
                  child: Text('Aucun camion. Clique sur Ajouter.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: trucks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final t = trucks[i];
                    return _buildTruckCard(t);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTruckCard(Truck t) {
    final monthTours = AppStore.tours.where((tour) {
      final now = DateTime.now();
      return tour.truckPlate == t.plate &&
          tour.date.year == now.year &&
          tour.date.month == now.month;
    }).toList();

    final monthKm = monthTours.fold(0.0, (s, tour) => s + tour.kmTotal);

    // Couleur alerte assurance
    Color? borderColor;
    if (t.insuranceStatus == 3) borderColor = Colors.red;
    if (t.insuranceStatus == 2) borderColor = Colors.orange;
    if (t.insuranceStatus == 1) borderColor = Colors.amber;

    return Card(
      shape: borderColor != null
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: borderColor, width: 1.5),
            )
          : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.plate,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      if (t.brand.isNotEmpty || t.model.isNotEmpty)
                        Text(
                          '${t.brand} ${t.model}'.trim() +
                              (t.year != null ? ' • ${t.year}' : ''),
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    vehicleTypeLabel(t.vehicleType),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Infos
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _infoBox('Forfait/jour',
                    '${t.dailyRate.toStringAsFixed(0)} €/j',
                    Icons.euro_outlined),
                if (t.monthlyCost != null)
                  _infoBox(
                    t.ownershipType == OwnershipType.achat
                        ? 'Amort/mois'
                        : 'Location/mois',
                    '${t.monthlyCost!.toStringAsFixed(0)} €',
                    t.ownershipType == OwnershipType.achat
                        ? Icons.trending_down_outlined
                        : Icons.receipt_outlined,
                  ),
                if (t.companyName != null)
                  _infoBox('Entreprise', t.companyName!,
                      Icons.business_outlined),
                if (t.rentCompany != null)
                  _infoBox('Sté location', t.rentCompany!,
                      Icons.apartment_outlined),
                _infoBox(
                  'Ce mois',
                  monthTours.isEmpty
                      ? 'Aucune tournée'
                      : '${monthTours.length} t. • ${monthKm.toStringAsFixed(0)} km',
                  Icons.route_outlined,
                ),
              ],
            ),

            // Badge assurance
            if (t.insuranceExpiry != null) ...[
              const SizedBox(height: 10),
              _InsuranceBadge(truck: t),
            ],

            // Badge seuil km
            if (t.monthlyKmThreshold != null) ...[
              const SizedBox(height: 8),
              _KmThresholdBadge(
                  monthKm: monthKm,
                  threshold: t.monthlyKmThreshold!),
            ],

            const SizedBox(height: 12),

            // Actions
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _showTruckDetail(t),
                  icon: const Icon(Icons.route_outlined),
                  label: const Text('Détails'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _editTruck(t),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Modifier'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _deleteTruck(t),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Supprimer'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoBox(String label, String value, IconData icon) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _statusDot(String status) {
    const colors = {
      'planifiée': Color(0xFF1F3C88),
      'en cours': Color(0xFFF57C00),
      'terminée': Color(0xFF2E7D32),
      'annulée': Color(0xFFB71C1C),
    };
    final color = colors[status] ?? Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(status, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }
}

// ── Badge assurance ───────────────────────────────────────────────────────────

class _InsuranceBadge extends StatelessWidget {
  const _InsuranceBadge({required this.truck});
  final Truck truck;

  @override
  Widget build(BuildContext context) {
    final status = truck.insuranceStatus;
    final expiry = truck.insuranceExpiry;

    Color color;
    IconData icon;
    String text;

    if (expiry == null) {
      color = Colors.grey;
      icon = Icons.shield_outlined;
      text = truck.insurerName ?? 'Assurance non renseignée';
    } else {
      final diff = expiry.difference(DateTime.now()).inDays;
      final dateStr =
          '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';

      switch (status) {
        case 3:
          color = Colors.red;
          icon = Icons.warning_rounded;
          text = 'Assurance expirée le $dateStr';
          break;
        case 2:
          color = Colors.orange;
          icon = Icons.warning_amber_rounded;
          text = 'Expire dans $diff j — $dateStr';
          break;
        case 1:
          color = Colors.amber;
          icon = Icons.shield_outlined;
          text = 'Expire dans $diff j — $dateStr';
          break;
        default:
          color = Colors.green;
          icon = Icons.verified_outlined;
          text = '${truck.insurerName != null ? '${truck.insurerName} • ' : ''}Valide jusqu\'au $dateStr';
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }
}

// ── Badge seuil km ────────────────────────────────────────────────────────────

class _KmThresholdBadge extends StatelessWidget {
  final double monthKm;
  final double threshold;

  const _KmThresholdBadge({
    required this.monthKm,
    required this.threshold,
  });

  @override
  Widget build(BuildContext context) {
    if (monthKm <= threshold * 0.9) {
      // En dessous de 90% — pas d'alerte
      return const SizedBox.shrink();
    }

    final bool exceeded = monthKm > threshold;
    final Color color = exceeded ? Colors.red : Colors.orange;
    final IconData icon = exceeded
        ? Icons.warning_rounded
        : Icons.warning_amber_rounded;
    final String text = exceeded
        ? 'Seuil km dépassé : ${monthKm.toStringAsFixed(0)} km / ${threshold.toStringAsFixed(0)} km — vérifier facturation'
        : 'Seuil km proche : ${monthKm.toStringAsFixed(0)} km / ${threshold.toStringAsFixed(0)} km';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bandeau alerte global ─────────────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  const _AlertBanner({
    required this.color,
    required this.icon,
    required this.message,
  });
  final Color color;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
