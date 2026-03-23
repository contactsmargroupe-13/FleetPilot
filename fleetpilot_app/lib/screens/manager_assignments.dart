import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'models/daily_assignment.dart';
import 'models/driver.dart';

class ManagerAssignmentsPage extends ConsumerWidget {
  const ManagerAssignmentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);

    // Chauffeurs actifs uniquement
    final activeDrivers = state.drivers.where((d) =>
        d.status == DriverStatus.cdi ||
        d.status == DriverStatus.cdd ||
        d.status == DriverStatus.interim).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final trucks = state.trucks;
    final clients = state.clientPricings.map((c) => c.companyName).toList()
      ..sort();

    return Scaffold(
      appBar: AppBar(title: const Text('Affectations')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Affectez un camion et un commissionnaire par chauffeur.',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          const Text(
            'Ces affectations sont permanentes : elles restent valables tant que vous ne les modifiez pas.',
            style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 16),

          if (activeDrivers.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Aucun chauffeur actif.',
                    style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...activeDrivers.map((driver) {
              final assignment = state.getAssignment(driver.name);
              final hasTruck = assignment != null;
              final truckPlate = assignment?.truckPlate;
              final company = assignment?.companyName;

              // Trouver le camion pour afficher le modèle
              final truck = truckPlate != null
                  ? trucks.where((t) => t.plate == truckPlate).firstOrNull
                  : null;

              final Color statusColor;
              switch (driver.status) {
                case DriverStatus.cdi:
                  statusColor = Colors.green;
                  break;
                case DriverStatus.cdd:
                  statusColor = Colors.blue;
                  break;
                default:
                  statusColor = Colors.orange;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Chauffeur header
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: statusColor.withValues(alpha: 0.15),
                            child: Text(
                              driver.name[0].toUpperCase(),
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: statusColor),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(driver.name,
                                    style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700)),
                                Text(driverStatusLabel(driver.status),
                                    style: TextStyle(
                                        fontSize: 12, color: statusColor)),
                              ],
                            ),
                          ),
                          if (hasTruck)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      size: 14, color: Colors.green),
                                  SizedBox(width: 4),
                                  Text('Affecté',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.green)),
                                ],
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.orange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.warning_amber,
                                      size: 14, color: Colors.orange),
                                  SizedBox(width: 4),
                                  Text('Non affecté',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.orange)),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Affectation actuelle
                      if (hasTruck) ...[
                        Row(
                          children: [
                            _infoChip(
                              Icons.local_shipping,
                              '${truckPlate!}${truck != null ? ' • ${truck.model}' : ''}',
                              Colors.teal,
                            ),
                            const SizedBox(width: 8),
                            if (company != null && company.isNotEmpty)
                              _infoChip(
                                Icons.business,
                                company,
                                Colors.indigo,
                              ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],

                      // Boutons
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _editAssignment(
                                context,
                                ref,
                                driver,
                                trucks.map((t) => t).toList(),
                                clients,
                                assignment,
                              ),
                              icon: Icon(
                                hasTruck ? Icons.edit : Icons.add,
                                size: 18,
                              ),
                              label: Text(hasTruck ? 'Modifier' : 'Affecter'),
                            ),
                          ),
                          if (hasTruck) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () {
                                ref
                                    .read(appStateProvider)
                                    .removeAssignment(driver.name);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Retirer'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),

          // Résumé
          if (activeDrivers.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSummary(state, activeDrivers),
          ],
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color),
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(AppState state, List<Driver> activeDrivers) {
    final assigned = activeDrivers
        .where((d) => state.getAssignment(d.name) != null)
        .length;
    final total = activeDrivers.length;

    return Card(
      color: assigned == total
          ? Colors.green.withValues(alpha: 0.06)
          : Colors.orange.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Text(
              assigned == total ? '✅' : '⚠️',
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$assigned / $total chauffeurs affectés',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  if (assigned < total)
                    Text(
                      '${total - assigned} chauffeur${total - assigned > 1 ? 's' : ''} sans affectation',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.orange),
                    )
                  else
                    const Text(
                      'Tous les chauffeurs sont affectés',
                      style: TextStyle(fontSize: 12, color: Colors.green),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editAssignment(
    BuildContext context,
    WidgetRef ref,
    Driver driver,
    List<dynamic> trucks,
    List<String> clients,
    DriverAssignment? current,
  ) {
    String? selectedPlate = current?.truckPlate;
    String? selectedClient = current?.companyName;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Affectation — ${driver.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Camion
              DropdownButtonFormField<String>(
                value: selectedPlate,
                decoration: const InputDecoration(
                  labelText: 'Camion *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_shipping_outlined),
                ),
                items: trucks
                    .map((t) => DropdownMenuItem(
                          value: t.plate as String,
                          child: Text('${t.plate} • ${t.model}'),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setDialogState(() => selectedPlate = v),
              ),
              const SizedBox(height: 12),

              // Commissionnaire
              DropdownButtonFormField<String>(
                value: clients.contains(selectedClient)
                    ? selectedClient
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Commissionnaire (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('— Aucun —')),
                  ...clients.map((c) =>
                      DropdownMenuItem(value: c, child: Text(c))),
                ],
                onChanged: (v) =>
                    setDialogState(() => selectedClient = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selectedPlate == null
                  ? null
                  : () {
                      ref.read(appStateProvider).setAssignment(
                            DriverAssignment(
                              driverName: driver.name,
                              truckPlate: selectedPlate!,
                              companyName: selectedClient,
                            ),
                          );
                      Navigator.pop(ctx);
                    },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }
}
