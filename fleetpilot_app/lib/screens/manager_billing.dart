import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import 'models/tour.dart';

class ManagerBillingPage extends ConsumerStatefulWidget {
  const ManagerBillingPage({super.key});

  @override
  ConsumerState<ManagerBillingPage> createState() => _ManagerBillingPageState();
}

class _ManagerBillingPageState extends ConsumerState<ManagerBillingPage> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  static const List<String> _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  @override
  Widget build(BuildContext context) {
    final Map<String, _ClientBilling> billing = {};

    for (final Tour tour in ref.read(appStateProvider).tours) {
      if (tour.date.year != _selectedMonth.year ||
          tour.date.month != _selectedMonth.month) {
        continue;
      }

      final company = tour.companyName ?? '—';
      final pricing = ref.read(appStateProvider).getClientPricing(company);

      billing.putIfAbsent(company, () => _ClientBilling(companyName: company));
      final client = billing[company]!;

      client.tours++;

      if (tour.hasHandling && pricing != null && pricing.handlingEnabled) {
        client.handlingCount++;
        client.handlingAmount += pricing.handlingPrice ?? 0.0;
      }

      if (tour.extraKm > 0 && pricing != null && pricing.extraKmEnabled) {
        client.extraKm += tour.extraKm;
        client.extraKmAmount += tour.extraKm * (pricing.extraKmPrice ?? 0.0);
      }

      if (tour.extraTour && pricing != null && pricing.extraTourEnabled) {
        client.extraTours++;
        client.extraTourAmount += pricing.extraTourPrice ?? 0.0;
      }
    }

    final clients = billing.values.toList()
      ..sort((a, b) => b.total.compareTo(a.total));

    final grandTotal = clients.fold(0.0, (s, c) => s + c.total);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Facturation clients',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        // Sélecteur de mois
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month - 1);
                  }),
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Mois −1'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month + 1);
                  }),
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('Mois +1'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    _selectedMonth = DateTime(now.year, now.month);
                  }),
                  icon: const Icon(Icons.today, size: 18),
                  label: const Text('Ce mois'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        if (clients.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucune tournée sur cette période.'),
            ),
          )
        else ...[
          // Total global
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.euro_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Total facturable $_monthLabel',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${grandTotal.toStringAsFixed(2)} €',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...clients.map((c) => _clientCard(c)),
        ],
      ],
    );
  }

  Widget _clientCard(_ClientBilling c) {
    final pricing = ref.read(appStateProvider).getClientPricing(c.companyName);
    final breakEven = pricing?.breakEvenAmount;
    final isAboveBreakEven = breakEven != null && c.total >= breakEven;
    final isBelowBreakEven = breakEven != null && c.total < breakEven;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              c.companyName,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _line('Tournées', '${c.tours}'),
            _line('Manutentions', '${c.handlingCount}'),
            _line('Extra km', '${c.extraKm.toStringAsFixed(0)} km'),
            _line('Tours supplémentaires', '${c.extraTours}'),
            const Divider(),
            _line('Facturation manutention',
                '${c.handlingAmount.toStringAsFixed(2)} €'),
            _line('Facturation extra km',
                '${c.extraKmAmount.toStringAsFixed(2)} €'),
            _line('Facturation extra tour',
                '${c.extraTourAmount.toStringAsFixed(2)} €'),
            const Divider(),
            _line('TOTAL FACTURABLE', '${c.total.toStringAsFixed(2)} €',
                bold: true),
            if (breakEven != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isAboveBreakEven
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isAboveBreakEven
                        ? Colors.green.withValues(alpha: 0.4)
                        : Colors.red.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAboveBreakEven
                          ? Icons.check_circle_outline
                          : Icons.warning_amber_outlined,
                      size: 16,
                      color: isAboveBreakEven ? Colors.green : Colors.red,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Seuil rentabilité : ${breakEven.toStringAsFixed(0)} €',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isAboveBreakEven ? Colors.green : Colors.red,
                        ),
                      ),
                    ),
                    if (isBelowBreakEven)
                      Text(
                        '−${(breakEven - c.total).toStringAsFixed(0)} €',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    if (isAboveBreakEven)
                      Text(
                        '+${(c.total - breakEven).toStringAsFixed(0)} €',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.green,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _line(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.w500)),
          ),
          Text(value,
              style: TextStyle(
                  fontWeight:
                      bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _ClientBilling {
  final String companyName;
  int tours = 0;
  int handlingCount = 0;
  double handlingAmount = 0;
  double extraKm = 0;
  double extraKmAmount = 0;
  int extraTours = 0;
  double extraTourAmount = 0;
  double get total => handlingAmount + extraKmAmount + extraTourAmount;
  _ClientBilling({required this.companyName});
}
