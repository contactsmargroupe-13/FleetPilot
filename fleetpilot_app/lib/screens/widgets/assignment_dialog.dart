import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_state.dart';
import '../../utils/theme_ctx.dart';
import '../models/client_pricing.dart';
import '../models/daily_assignment.dart';

/// Camion et commissionnaire habituels d'un chauffeur, avec un éventuel
/// tarif propre. C'est ce que le chauffeur retrouve préréglé le matin.
Future<void> showAssignmentDialog(
    BuildContext context, WidgetRef ref, String driverName) {
  return showDialog<void>(
    context: context,
    builder: (_) => _AssignmentDialog(driverName: driverName),
  );
}

class _AssignmentDialog extends ConsumerStatefulWidget {
  final String driverName;
  const _AssignmentDialog({required this.driverName});

  @override
  ConsumerState<_AssignmentDialog> createState() => _AssignmentDialogState();
}

double? _num(String s) {
  final t = s.replaceAll(',', '.').trim();
  return t.isEmpty ? null : double.tryParse(t);
}

class _AssignmentDialogState extends ConsumerState<_AssignmentDialog> {
  String? _plate;
  String? _company;
  bool _custom = false;
  final _daily = TextEditingController();
  final _point = TextEditingController();

  @override
  void initState() {
    super.initState();
    final a = ref.read(appStateProvider).getAssignment(widget.driverName);
    _plate = a?.truckPlate;
    _company = a?.companyName;
    _custom = a?.hasCustomRate ?? false;
    _daily.text = a?.customDailyRate?.toString() ?? '';
    _point.text = a?.customPricePerPoint?.toString() ?? '';
  }

  @override
  void dispose() {
    _daily.dispose();
    _point.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final existing = state.getAssignment(widget.driverName);
    final pricing = state.getClientPricing(_company);
    final plates = state.trucks.map((t) => t.plate).toSet();
    final companies = state.clientPricings.map((c) => c.companyName).toSet();

    return AlertDialog(
      title: Text('Affectation de ${widget.driverName}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              value: plates.contains(_plate) ? _plate : null,
              decoration: const InputDecoration(
                labelText: 'Camion habituel',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_shipping_outlined),
              ),
              items: [
                for (final t in state.trucks)
                  DropdownMenuItem(
                      value: t.plate, child: Text('${t.plate} • ${t.model}')),
              ],
              onChanged: (v) => setState(() => _plate = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: companies.contains(_company) ? _company : null,
              decoration: const InputDecoration(
                labelText: 'Commissionnaire',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.handshake_outlined),
              ),
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('Aucun')),
                for (final c in companies)
                  DropdownMenuItem(value: c, child: Text(c)),
              ],
              onChanged: (v) => setState(() => _company = v),
            ),
            if (pricing != null) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tarif propre à ce chauffeur'),
                subtitle: Text(
                  pricing.billingMode == BillingMode.auPoint
                      ? 'Sinon ${pricing.pricePerPoint ?? 0} € / point'
                      : 'Sinon ${pricing.dailyRate.toStringAsFixed(0)} € / jour',
                  style: context.tBody(12, color: context.cInk3),
                ),
                value: _custom,
                onChanged: (v) => setState(() => _custom = v),
              ),
              if (_custom)
                TextField(
                  controller: pricing.billingMode == BillingMode.auPoint
                      ? _point
                      : _daily,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: pricing.billingMode == BillingMode.auPoint
                        ? '€ par point'
                        : '€ par jour',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: () {
              state.removeAssignment(widget.driverName);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Retirer'),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _plate == null
              ? null
              : () {
                  final point = pricing?.billingMode == BillingMode.auPoint;
                  state.setAssignment(DriverAssignment(
                    driverName: widget.driverName,
                    truckPlate: _plate!,
                    companyName: _company,
                    customDailyRate: _custom && !point ? _num(_daily.text) : null,
                    customPricePerPoint:
                        _custom && point ? _num(_point.text) : null,
                  ));
                  Navigator.pop(context);
                },
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
