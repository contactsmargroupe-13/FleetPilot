import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'add_truck.dart';
import 'models/client_pricing.dart';
import 'models/daily_assignment.dart';
import 'models/driver.dart';

class ManagerAssignmentsPage extends ConsumerStatefulWidget {
  const ManagerAssignmentsPage({super.key});

  @override
  ConsumerState<ManagerAssignmentsPage> createState() =>
      _ManagerAssignmentsPageState();
}

class _ManagerAssignmentsPageState
    extends ConsumerState<ManagerAssignmentsPage> {

  double? _parseDouble(String s) {
    final v = double.tryParse(s.replaceAll(',', '.').trim());
    return (v != null && v > 0) ? v : null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);

    final activeDrivers = state.drivers
        .where((d) =>
            d.status == DriverStatus.cdi ||
            d.status == DriverStatus.cdd ||
            d.status == DriverStatus.interim)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    final allTruckPlates = state.trucks.map((t) => t.plate).toSet();
    final assignedTruckPlates =
        state.assignments.map((a) => a.truckPlate).toSet();
    final unassignedTrucks = state.trucks
        .where((t) => !assignedTruckPlates.contains(t.plate))
        .toList();

    final assignedCount =
        activeDrivers.where((d) => state.getAssignment(d.name) != null).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Flotte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Résumé rapide ───────────────────────────────────────────
          _buildSummaryBar(state, activeDrivers.length, assignedCount,
              unassignedTrucks.length),
          const SizedBox(height: 16),

          // ── Affectations actives ────────────────────────────────────
          ...activeDrivers.map((driver) {
            final assign = state.getAssignment(driver.name);
            return _buildFleetCard(state, driver, assign);
          }),

          // ── Camions non affectés ────────────────────────────────────
          if (unassignedTrucks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(Icons.local_shipping_outlined,
                      size: 16, color: Colors.orange.shade700),
                  const SizedBox(width: 6),
                  Text(
                    '${unassignedTrucks.length} camion${unassignedTrucks.length > 1 ? 's' : ''} sans chauffeur',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange.shade700),
                  ),
                ],
              ),
            ),
            ...unassignedTrucks.map((t) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: Colors.orange.withValues(alpha: 0.04),
                  child: ListTile(
                    dense: true,
                    leading: const Icon(Icons.local_shipping_outlined,
                        color: Colors.orange),
                    title: Text('${t.plate} • ${t.model}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(truckStatusLabel(t.truckStatus),
                        style: const TextStyle(fontSize: 12)),
                  ),
                )),
          ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  RÉSUMÉ
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildSummaryBar(
      AppState state, int totalDrivers, int assigned, int freeTrucks) {
    final allOk = assigned == totalDrivers && freeTrucks == 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: allOk
            ? Colors.green.withValues(alpha: 0.06)
            : Colors.orange.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: allOk
              ? Colors.green.withValues(alpha: 0.2)
              : Colors.orange.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Text(allOk ? '✅' : '⚠️', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$assigned / $totalDrivers chauffeurs affectés',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                if (freeTrucks > 0)
                  Text('$freeTrucks camion${freeTrucks > 1 ? 's' : ''} disponible${freeTrucks > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 12, color: Colors.orange)),
                if (allOk)
                  const Text('Toute la flotte est opérationnelle',
                      style: TextStyle(fontSize: 12, color: Colors.green)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CARTE FLOTTE (1 par chauffeur)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildFleetCard(
      AppState state, Driver driver, DriverAssignment? assign) {
    final truck = assign != null
        ? state.trucks.where((t) => t.plate == assign.truckPlate).firstOrNull
        : null;
    final pricing = assign?.companyName != null
        ? state.getClientPricing(assign!.companyName)
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
      shape: assign == null
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.orange.withValues(alpha: 0.4)),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _editAssignment(state, driver, assign),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ligne 1 : Chauffeur
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    child: Text(driver.name[0].toUpperCase(),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: statusColor)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(driver.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  _miniTag(driverStatusLabel(driver.status), statusColor),
                ],
              ),

              const SizedBox(height: 10),

              // Ligne 2 : Camion + Commissionnaire
              if (assign != null) ...[
                Row(
                  children: [
                    // Camion
                    Expanded(
                      child: _slotChip(
                        Icons.local_shipping,
                        '${assign.truckPlate}${truck != null ? ' • ${truck.model}' : ''}',
                        Colors.teal,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Commissionnaire
                    Expanded(
                      child: assign.companyName != null &&
                              assign.companyName!.isNotEmpty
                          ? _slotChip(
                              Icons.handshake_outlined,
                              assign.companyName!,
                              Colors.indigo,
                            )
                          : _slotChip(
                              Icons.handshake_outlined,
                              'Aucun comm.',
                              Colors.grey,
                            ),
                    ),
                  ],
                ),

                // Ligne 3 : Tarif
                if (pricing != null || assign.hasCustomRate) ...[
                  const SizedBox(height: 6),
                  _tariffRow(pricing, assign),
                ],
              ] else ...[
                // Non affecté
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.2)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_circle_outline,
                          size: 16, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Tap pour affecter camion + commissionnaire',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _slotChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _miniTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }

  Widget _tariffRow(ClientPricing? pricing, DriverAssignment assign) {
    final mode = pricing?.billingMode ?? BillingMode.aLaFiche;
    final parts = <String>[];

    // Tarif effectif (custom > default)
    if (mode == BillingMode.aLaFiche) {
      final rate = assign.customDailyRate ?? pricing?.dailyRate ?? 0;
      if (rate > 0) parts.add('${rate.toStringAsFixed(0)} €/j');
    } else {
      final pp = assign.customPricePerPoint ?? pricing?.pricePerPoint ?? 0;
      if (pp > 0) parts.add('${pp.toStringAsFixed(2)} €/pt');
    }

    if (pricing != null &&
        pricing.fuelIndexEnabled &&
        pricing.fuelIndexPercent != null) {
      parts.add('+${pricing.fuelIndexPercent!.toStringAsFixed(1)}% gasoil');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          _miniTag(billingModeLabel(mode),
              mode == BillingMode.auPoint ? Colors.indigo : Colors.teal),
          const SizedBox(width: 8),
          Text(parts.join(' • '),
              style:
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          if (assign.hasCustomRate) ...[
            const SizedBox(width: 6),
            const Icon(Icons.tune, size: 12, color: Colors.purple),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DIALOG
  // ══════════════════════════════════════════════════════════════════════════

  void _editAssignment(
      AppState state, Driver driver, DriverAssignment? current) {
    final trucks = state.trucks;
    final clients =
        state.clientPricings.map((c) => c.companyName).toList()..sort();

    String? selectedPlate = current?.truckPlate;
    String? selectedClient = current?.companyName;
    final customDailyCtrl = TextEditingController(
        text: current?.customDailyRate?.toString() ?? '');
    final customPointCtrl = TextEditingController(
        text: current?.customPricePerPoint?.toString() ?? '');
    bool showCustom = current?.hasCustomRate ?? false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          final selectedPricing = selectedClient != null
              ? state.getClientPricing(selectedClient)
              : null;

          return AlertDialog(
            title: Text(driver.name),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                              value: t.plate,
                              child: Text('${t.plate} • ${t.model}'),
                            ))
                        .toList(),
                    onChanged: (v) => set(() => selectedPlate = v),
                  ),
                  const SizedBox(height: 12),

                  // Commissionnaire
                  DropdownButtonFormField<String>(
                    value:
                        clients.contains(selectedClient) ? selectedClient : null,
                    decoration: const InputDecoration(
                      labelText: 'Commissionnaire',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.handshake_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                          value: null, child: Text('— Aucun —')),
                      ...clients
                          .map((c) => DropdownMenuItem(value: c, child: Text(c))),
                    ],
                    onChanged: (v) => set(() => selectedClient = v),
                  ),

                  // Aperçu tarif par défaut
                  if (selectedPricing != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tarif ${billingModeLabel(selectedPricing.billingMode)}',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.indigo),
                          ),
                          const SizedBox(height: 2),
                          if (selectedPricing.dailyRate > 0)
                            Text(
                                '${selectedPricing.dailyRate.toStringAsFixed(0)} €/jour',
                                style: const TextStyle(fontSize: 12)),
                          if (selectedPricing.pricePerPoint != null &&
                              selectedPricing.pricePerPoint! > 0)
                            Text(
                                '${selectedPricing.pricePerPoint!.toStringAsFixed(2)} €/point',
                                style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),

                    // Toggle tarif spécifique
                    const SizedBox(height: 8),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tarif spécifique',
                          style: TextStyle(fontSize: 13)),
                      subtitle: const Text(
                          'Surcharge le tarif du commissionnaire',
                          style: TextStyle(fontSize: 11)),
                      value: showCustom,
                      onChanged: (v) => set(() => showCustom = v),
                    ),

                    if (showCustom) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: customDailyCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: '€/jour',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: customPointCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              decoration: const InputDecoration(
                                labelText: '€/point',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: () {
                    ref.read(appStateProvider).removeAssignment(driver.name);
                    customDailyCtrl.dispose();
                    customPointCtrl.dispose();
                    Navigator.pop(ctx);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Retirer'),
                ),
              TextButton(
                onPressed: () {
                  customDailyCtrl.dispose();
                  customPointCtrl.dispose();
                  Navigator.pop(ctx);
                },
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
                                customDailyRate: showCustom
                                    ? _parseDouble(customDailyCtrl.text)
                                    : null,
                                customPricePerPoint: showCustom
                                    ? _parseDouble(customPointCtrl.text)
                                    : null,
                              ),
                            );
                        customDailyCtrl.dispose();
                        customPointCtrl.dispose();
                        Navigator.pop(ctx);
                      },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
