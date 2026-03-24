import 'package:flutter/material.dart';
import 'add_truck.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'models/equipment.dart';

class ManagerVehiclesPage extends ConsumerStatefulWidget {
  const ManagerVehiclesPage({super.key});

  @override
  ConsumerState<ManagerVehiclesPage> createState() => _ManagerVehiclesPageState();
}

class _ManagerVehiclesPageState extends ConsumerState<ManagerVehiclesPage> {

  Future<void> _addTruck() async {
    final result = await Navigator.push<Truck>(
      context,
      MaterialPageRoute(builder: (_) => const AddTruckPage()),
    );
    if (result != null) {
      setState(() => ref.read(appStateProvider).addTruck(result));
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
      setState(() => ref.read(appStateProvider).updateTruck(truck.plate, result));
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
      setState(() => ref.read(appStateProvider).deleteTruck(truck.plate));
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
            final tours = ref.read(appStateProvider).tours
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

                  // Assurance + CT
                  _InsuranceBadge(truck: truck),
                  _CtBadge(truck: truck),

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
    final trucks = ref.read(appStateProvider).trucks;

    // Alertes assurance
    final expiredCount = trucks
        .where((t) => t.insuranceStatus == 3)
        .length;
    final soonCount = trucks
        .where((t) => t.insuranceStatus == 2)
        .length;

    // Alertes CT
    final ctExpiredCount = trucks
        .where((t) => t.ctStatus == 4)
        .length;
    final ctSoonCount = trucks
        .where((t) => t.ctStatus == 2 || t.ctStatus == 3)
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
        if (ctExpiredCount > 0)
          _AlertBanner(
            color: Colors.red,
            icon: Icons.warning_rounded,
            message:
                '$ctExpiredCount contrôle(s) technique(s) expiré(s) — action requise',
          ),
        if (ctSoonCount > 0)
          _AlertBanner(
            color: Colors.orange,
            icon: Icons.build_outlined,
            message:
                '$ctSoonCount contrôle(s) technique(s) expire(nt) bientôt',
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
    final monthTours = ref.read(appStateProvider).tours.where((tour) {
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
    if (t.ctStatus == 4 || t.ctStatus == 3) borderColor = Colors.red;
    if (t.ctStatus == 2 && borderColor == Colors.transparent) borderColor = Colors.orange;

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
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: truckStatusColor(t.truckStatus).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: truckStatusColor(t.truckStatus).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    truckStatusLabel(t.truckStatus),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      color: truckStatusColor(t.truckStatus),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
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

            // Affectation (chauffeur + commissionnaire)
            Builder(builder: (_) {
              final state = ref.read(appStateProvider);
              final assign = state.assignments
                  .where((a) => a.truckPlate == t.plate)
                  .firstOrNull;
              if (assign == null) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.person_off_outlined, size: 15, color: Colors.grey),
                      SizedBox(width: 6),
                      Text('Non affecté',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.indigo.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 15, color: Colors.indigo),
                    const SizedBox(width: 6),
                    Text(assign.driverName,
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: Colors.indigo)),
                    if (assign.companyName != null && assign.companyName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.handshake_outlined, size: 13, color: Colors.teal),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(assign.companyName!,
                            style: const TextStyle(fontSize: 12, color: Colors.teal),
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              );
            }),
            const SizedBox(height: 8),

            // Infos
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _infoBox(
                  t.ownershipType == OwnershipType.achat
                      ? 'Achat'
                      : 'Location',
                  t.monthlyCost != null
                      ? '${t.monthlyCost!.toStringAsFixed(0)} €/mois'
                      : '—',
                  t.ownershipType == OwnershipType.achat
                      ? Icons.shopping_cart_outlined
                      : Icons.receipt_outlined,
                ),
                if (t.rentCompany != null)
                  _infoBox('Loueur', t.rentCompany!,
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

            // Badges assurance + CT
            const SizedBox(height: 10),
            _InsuranceBadge(truck: t),
            _CtBadge(truck: t),

            const SizedBox(height: 12),

            // Matériel affecté
            Builder(builder: (_) {
              final equip = ref.read(appStateProvider).equipment
                  .where((e) => e.assignedTruckPlate == t.plate)
                  .toList();
              if (equip.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text('Matériel à bord (${equip.length})',
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: equip.map((e) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.build, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Text(e.name,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue)),
                        ],
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            }),

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

// ── Badge contrôle technique ──────────────────────────────────────────────────

class _CtBadge extends StatelessWidget {
  const _CtBadge({required this.truck});
  final Truck truck;

  @override
  Widget build(BuildContext context) {
    final status = truck.ctStatus;
    final expiry = truck.ctExpiry;

    if (expiry == null && status == 0) return const SizedBox.shrink();

    Color color;
    IconData icon;
    String text;

    if (expiry == null) {
      color = Colors.grey;
      icon = Icons.build_outlined;
      text = 'CT non renseigné';
    } else {
      final diff = expiry.difference(DateTime.now()).inDays;
      final dateStr =
          '${expiry.day.toString().padLeft(2, '0')}/${expiry.month.toString().padLeft(2, '0')}/${expiry.year}';

      switch (status) {
        case 4:
          color = Colors.red;
          icon = Icons.warning_rounded;
          text = 'CT expiré le $dateStr';
          break;
        case 3:
          color = Colors.red;
          icon = Icons.warning_amber_rounded;
          text = 'CT expire dans $diff j — $dateStr';
          break;
        case 2:
          color = Colors.orange;
          icon = Icons.warning_amber_rounded;
          text = 'CT expire dans $diff j — $dateStr';
          break;
        case 1:
          color = Colors.amber;
          icon = Icons.build_outlined;
          text = 'CT dans $diff j — $dateStr';
          break;
        default:
          color = Colors.green;
          icon = Icons.verified_outlined;
          text = 'CT valide jusqu\'au $dateStr';
      }
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
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
