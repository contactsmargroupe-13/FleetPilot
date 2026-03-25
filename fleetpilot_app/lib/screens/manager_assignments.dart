import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import '../utils/page_help.dart';
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

    final assignedTruckPlates =
        state.assignments.map((a) => a.truckPlate).toSet();
    final unassignedTrucks = state.trucks
        .where((t) => !assignedTruckPlates.contains(t.plate))
        .toList();

    final assignedCount =
        activeDrivers.where((d) => state.getAssignment(d.name) != null).length;

    // Regrouper les affectations par commissionnaire
    final Map<String, List<DriverAssignment>> byComm = {};
    for (final assign in state.assignments) {
      if (assign.companyName != null && assign.companyName!.isNotEmpty) {
        byComm.putIfAbsent(assign.companyName!, () => []).add(assign);
      }
    }

    // Commissionnaires sans affectation (existent mais pas de chauffeurs)
    for (final cp in state.clientPricings) {
      byComm.putIfAbsent(cp.companyName, () => []);
    }

    final sortedComms = byComm.keys.toList()..sort();

    // Chauffeurs sans commissionnaire
    final driversWithoutComm = activeDrivers.where((d) {
      final a = state.getAssignment(d.name);
      return a == null || a.companyName == null || a.companyName!.isEmpty;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flotte'),
        actions: [
          helpButton(context, 'Flotte',
            'Organisez votre flotte par commissionnaire.\n\n'
            '• Chaque commissionnaire regroupe ses chauffeurs et camions\n'
            '• Appuyez sur + pour ajouter un chauffeur\n'
            '• Appuyez sur un chauffeur pour modifier son affectation\n'
            '• Les tarifs du commissionnaire sont affichés sur chaque carte'),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Résumé
          _buildSummaryBar(state, activeDrivers.length, assignedCount,
              unassignedTrucks.length),
          const SizedBox(height: 16),

          // Liste des commissionnaires
          ...sortedComms.map((commName) {
            final assigns = byComm[commName]!;
            final pricing = state.getClientPricing(commName);
            return _buildCommissionnaireCard(state, commName, pricing, assigns);
          }),

          // Chauffeurs sans commissionnaire
          if (driversWithoutComm.isNotEmpty) ...[
            const SizedBox(height: 12),
            _sectionHeader(
              Icons.person_off_outlined,
              '${driversWithoutComm.length} chauffeur${driversWithoutComm.length > 1 ? 's' : ''} sans commissionnaire',
              Colors.orange.shade700,
            ),
            ...driversWithoutComm.map((driver) {
              final assign = state.getAssignment(driver.name);
              return _buildOrphanDriverTile(state, driver, assign);
            }),
          ],

          // Camions non affectés
          if (unassignedTrucks.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeader(
              Icons.local_shipping_outlined,
              '${unassignedTrucks.length} camion${unassignedTrucks.length > 1 ? 's' : ''} disponible${unassignedTrucks.length > 1 ? 's' : ''}',
              Colors.orange.shade700,
            ),
            ...unassignedTrucks.map((t) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
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
          Icon(
            allOk ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
            size: 28,
            color: allOk ? DC.success : DC.warning,
          ),
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
                  Text(
                      '$freeTrucks camion${freeTrucks > 1 ? 's' : ''} disponible${freeTrucks > 1 ? 's' : ''}',
                      style:
                          const TextStyle(fontSize: 12, color: Colors.orange)),
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
  //  CARTE COMMISSIONNAIRE (entrée principale)
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildCommissionnaireCard(
    AppState state,
    String commName,
    ClientPricing? pricing,
    List<DriverAssignment> assigns,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête commissionnaire
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: (pricing?.colorValue != null
                          ? Color(pricing!.colorValue!)
                          : Colors.indigo)
                      .withValues(alpha: 0.12),
                  child: Icon(Icons.handshake_outlined,
                      size: 18,
                      color: pricing?.colorValue != null
                          ? Color(pricing!.colorValue!)
                          : Colors.indigo),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(commName,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      Text(
                        assigns.isEmpty
                            ? 'Aucune affectation'
                            : '${assigns.length} chauffeur${assigns.length > 1 ? 's' : ''}',
                        style: TextStyle(
                            fontSize: 12, color: DC.textSecondary),
                      ),
                    ],
                  ),
                ),
                // Bouton ajouter chauffeur+camion
                IconButton(
                  onPressed: () =>
                      _addAssignmentToComm(state, commName),
                  icon: const Icon(Icons.person_add_outlined),
                  tooltip: 'Ajouter un chauffeur',
                  color: Colors.indigo,
                ),
              ],
            ),

            // Contrat / Tarif
            if (pricing != null) ...[
              const SizedBox(height: 10),
              _buildContractInfo(pricing),
            ],

            // Liste chauffeurs + camions
            if (assigns.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 6),
              ...assigns.map((assign) => _buildDriverBullet(state, assign)),
            ],
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  INFO CONTRAT
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildContractInfo(ClientPricing pricing) {
    final mode = pricing.billingMode;
    final parts = <Widget>[];

    parts.add(_miniTag(
      billingModeLabel(mode),
      mode == BillingMode.auPoint ? Colors.indigo : Colors.teal,
    ));

    final tarifs = <String>[];
    if (pricing.dailyRate > 0) {
      tarifs.add('${pricing.dailyRate.toStringAsFixed(0)} €/jour');
    }
    if (pricing.pricePerPoint != null && pricing.pricePerPoint! > 0) {
      final unitLabel = mode == BillingMode.aLaFiche ? '€/fiche' : '€/colis';
      tarifs.add('${pricing.pricePerPoint!.toStringAsFixed(2)} $unitLabel');
    }
    if (tarifs.isNotEmpty) {
      parts.add(const SizedBox(width: 8));
      parts.add(Flexible(
        child: Text(
          tarifs.join(' + '),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ));
    }

    final options = <String>[];
    if (pricing.fuelIndexEnabled && pricing.fuelIndexPercent != null) {
      options.add('+${pricing.fuelIndexPercent!.toStringAsFixed(1)}% gasoil');
    }
    if (pricing.handlingEnabled && pricing.handlingPrice != null) {
      options.add('Manu. ${pricing.handlingPrice!.toStringAsFixed(0)} €');
    }
    if (pricing.extraKmEnabled && pricing.extraKmPrice != null) {
      options.add('Km sup. ${pricing.extraKmPrice!.toStringAsFixed(2)} €/km');
    }
    if (pricing.extraTourEnabled && pricing.extraTourPrice != null) {
      options.add('Tour sup. ${pricing.extraTourPrice!.toStringAsFixed(0)} €');
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: parts),
          if (options.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              options.join(' • '),
              style: TextStyle(fontSize: 11, color: DC.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PUCE CHAUFFEUR+CAMION
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildDriverBullet(AppState state, DriverAssignment assign) {
    final driver = state.drivers
        .where((d) => d.name == assign.driverName)
        .firstOrNull;
    final truck = state.trucks
        .where((t) => t.plate == assign.truckPlate)
        .firstOrNull;

    final Color statusColor;
    if (driver == null) {
      statusColor = Colors.grey;
    } else {
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
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _editAssignmentForComm(
          state, assign.companyName!, assign),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            // Puce
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            // Chauffeur
            Expanded(
              flex: 3,
              child: Text(
                assign.driverName,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (driver != null)
              _miniTag(driverStatusLabel(driver.status), statusColor),
            const SizedBox(width: 8),
            // Camion
            if (truck != null)
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Icon(Icons.local_shipping,
                        size: 14, color: Colors.teal.shade600),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${truck.plate} • ${truck.model}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.teal.shade700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            if (assign.hasCustomRate)
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child:
                    Icon(Icons.tune, size: 14, color: Colors.purple.shade400),
              ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  CHAUFFEUR SANS COMMISSIONNAIRE
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildOrphanDriverTile(
      AppState state, Driver driver, DriverAssignment? assign) {
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
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _assignToComm(state, driver, assign),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: statusColor.withValues(alpha: 0.15),
                child: Text(driver.name[0].toUpperCase(),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: statusColor)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(driver.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
              _miniTag(driverStatusLabel(driver.status), statusColor),
              const SizedBox(width: 8),
              if (assign != null) ...[
                Icon(Icons.local_shipping,
                    size: 14, color: Colors.teal.shade400),
                const SizedBox(width: 4),
                Text(assign.truckPlate,
                    style: TextStyle(
                        fontSize: 11, color: Colors.teal.shade600)),
              ] else
                const Icon(Icons.add_circle_outline,
                    size: 16, color: Colors.orange),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  WIDGETS
  // ══════════════════════════════════════════════════════════════════════════

  Widget _sectionHeader(IconData icon, String label, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700, color: color)),
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

  // ══════════════════════════════════════════════════════════════════════════
  //  DIALOG : Ajouter chauffeur+camion à un commissionnaire
  // ══════════════════════════════════════════════════════════════════════════

  void _addAssignmentToComm(AppState state, String commName) {
    // Camions déjà affectés
    final assignedPlates = state.assignments.map((a) => a.truckPlate).toSet();
    final availableTrucks = state.trucks
        .where((t) => !assignedPlates.contains(t.plate))
        .toList();
    // Chauffeurs actifs non encore affectés
    final availableDrivers = state.drivers
        .where((d) =>
            (d.status == DriverStatus.cdi ||
                d.status == DriverStatus.cdd ||
                d.status == DriverStatus.interim) &&
            state.getAssignment(d.name) == null)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    String? selectedDriver;
    String? selectedPlate;
    final customDailyCtrl = TextEditingController();
    final customPointCtrl = TextEditingController();
    bool showCustom = false;

    final pricing = state.getClientPricing(commName);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          return AlertDialog(
            title: Text('Ajouter à $commName'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Chauffeur
                  DropdownButtonFormField<String>(
                    value: selectedDriver,
                    decoration: InputDecoration(
                      labelText: 'Chauffeur *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.person_outline),
                      helperText: availableDrivers.isEmpty
                          ? 'Tous les chauffeurs sont déjà affectés'
                          : null,
                    ),
                    items: availableDrivers
                        .map((d) => DropdownMenuItem(
                              value: d.name,
                              child: Text(d.name),
                            ))
                        .toList(),
                    onChanged: (v) => set(() => selectedDriver = v),
                  ),
                  const SizedBox(height: 12),

                  // Camion (seulement les disponibles)
                  DropdownButtonFormField<String>(
                    value: selectedPlate,
                    decoration: InputDecoration(
                      labelText: 'Camion *',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.local_shipping_outlined),
                      helperText: availableTrucks.isEmpty
                          ? 'Aucun camion disponible'
                          : '${availableTrucks.length} disponible${availableTrucks.length > 1 ? 's' : ''}',
                    ),
                    items: availableTrucks
                        .map((t) => DropdownMenuItem(
                              value: t.plate,
                              child: Text('${t.plate} • ${t.model}'),
                            ))
                        .toList(),
                    onChanged: (v) => set(() => selectedPlate = v),
                  ),

                  // Tarif commissionnaire
                  if (pricing != null) ...[
                    const SizedBox(height: 12),
                    _buildContractInfo(pricing),
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
                    if (showCustom)
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
                              decoration: InputDecoration(
                                labelText: pricing.billingMode ==
                                        BillingMode.aLaFiche
                                    ? '€/fiche'
                                    : '€/colis',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  customDailyCtrl.dispose();
                  customPointCtrl.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: (selectedDriver == null || selectedPlate == null)
                    ? null
                    : () {
                        ref.read(appStateProvider).setAssignment(
                              DriverAssignment(
                                driverName: selectedDriver!,
                                truckPlate: selectedPlate!,
                                companyName: commName,
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
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  DIALOG : Modifier/retirer un chauffeur d'un commissionnaire
  // ══════════════════════════════════════════════════════════════════════════

  void _editAssignmentForComm(
      AppState state, String commName, DriverAssignment current) {
    final trucks = state.trucks;

    String selectedPlate = current.truckPlate;
    final customDailyCtrl = TextEditingController(
        text: current.customDailyRate?.toString() ?? '');
    final customPointCtrl = TextEditingController(
        text: current.customPricePerPoint?.toString() ?? '');
    bool showCustom = current.hasCustomRate;

    final pricing = state.getClientPricing(commName);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          return AlertDialog(
            title: Text(current.driverName),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Commissionnaire (lecture seule)
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.handshake_outlined,
                            size: 16, color: Colors.indigo),
                        const SizedBox(width: 8),
                        Text(commName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.indigo)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

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
                    onChanged: (v) {
                      if (v != null) set(() => selectedPlate = v);
                    },
                  ),

                  if (pricing != null) ...[
                    const SizedBox(height: 12),
                    _buildContractInfo(pricing),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Tarif spécifique',
                          style: TextStyle(fontSize: 13)),
                      value: showCustom,
                      onChanged: (v) => set(() => showCustom = v),
                    ),
                    if (showCustom)
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
                              decoration: InputDecoration(
                                labelText: pricing.billingMode ==
                                        BillingMode.aLaFiche
                                    ? '€/fiche'
                                    : '€/colis',
                                border: const OutlineInputBorder(),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref
                      .read(appStateProvider)
                      .removeAssignment(current.driverName);
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
                onPressed: () {
                  ref.read(appStateProvider).setAssignment(
                        DriverAssignment(
                          driverName: current.driverName,
                          truckPlate: selectedPlate,
                          companyName: commName,
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

  // ══════════════════════════════════════════════════════════════════════════
  //  DIALOG : Affecter un chauffeur orphelin à un commissionnaire
  // ══════════════════════════════════════════════════════════════════════════

  void _assignToComm(
      AppState state, Driver driver, DriverAssignment? current) {
    final assignedPlates = state.assignments.map((a) => a.truckPlate).toSet();
    final trucks = state.trucks
        .where((t) => !assignedPlates.contains(t.plate) || t.plate == current?.truckPlate)
        .toList();
    final clients =
        state.clientPricings.map((c) => c.companyName).toList()..sort();

    String? selectedPlate = current?.truckPlate;
    String? selectedClient;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          return AlertDialog(
            title: Text('Affecter ${driver.name}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Commissionnaire
                  DropdownButtonFormField<String>(
                    value: selectedClient,
                    decoration: const InputDecoration(
                      labelText: 'Commissionnaire *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.handshake_outlined),
                    ),
                    items: clients
                        .map((c) =>
                            DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => set(() => selectedClient = v),
                  ),
                  const SizedBox(height: 12),

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
                ],
              ),
            ),
            actions: [
              if (current != null)
                TextButton(
                  onPressed: () {
                    ref
                        .read(appStateProvider)
                        .removeAssignment(driver.name);
                    Navigator.pop(ctx);
                  },
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Retirer'),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed:
                    (selectedClient == null || selectedPlate == null)
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
                child: const Text('Affecter'),
              ),
            ],
          );
        },
      ),
    );
  }
}
