import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../services/pdf_invoice_service.dart';
import 'models/client_pricing.dart';
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

  /// Numéro de facture : FP-YYYYMM-XXX
  String _invoiceNumber(int index) {
    final m = _selectedMonth;
    return 'FP-${m.year}${m.month.toString().padLeft(2, '0')}-${(index + 1).toString().padLeft(3, '0')}';
  }

  List<ClientBillingData> _computeBilling() {
    final Map<String, ClientBillingData> billing = {};

    for (final Tour tour in ref.read(appStateProvider).tours) {
      if (tour.date.year != _selectedMonth.year ||
          tour.date.month != _selectedMonth.month) {
        continue;
      }

      final company = tour.companyName ?? '—';
      final pricing = ref.read(appStateProvider).getClientPricing(company);
      final dailyRate = pricing?.dailyRate ?? 0.0;

      final mode = pricing?.billingMode ?? BillingMode.aLaFiche;
      final pricePerPoint = pricing?.pricePerPoint ?? 0.0;

      billing.putIfAbsent(
          company,
          () => ClientBillingData(
                companyName: company,
                dailyRate: dailyRate,
                fuelIndexPercent: pricing?.fuelIndexPercent,
                siret: pricing?.siret,
                tvaIntra: pricing?.tvaIntra,
                address: pricing?.address,
                phone: pricing?.phone,
                contactName: pricing?.contactName,
                billingMode: mode,
                pricePerPoint: pricePerPoint,
              ));
      final client = billing[company]!;

      client.tours++;
      if (mode == BillingMode.auPoint) {
        client.totalPoints += tour.clientsCount;
        client.baseAmount += tour.clientsCount * pricePerPoint;
      } else {
        client.baseAmount += dailyRate;
      }

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
      ..sort((a, b) => b.totalHT.compareTo(a.totalHT));

    // Assign invoice numbers
    for (int i = 0; i < clients.length; i++) {
      clients[i].invoiceNumber = _invoiceNumber(i);
    }

    return clients;
  }

  Future<void> _exportAllPdf(
      List<ClientBillingData> clients, double grandTotal) async {
    await PdfInvoiceService.generateAndPrint(
      monthLabel: _monthLabel,
      clients: clients,
      grandTotal: grandTotal,
    );
  }

  Future<void> _exportSinglePdf(ClientBillingData client) async {
    await PdfInvoiceService.generateSingleInvoice(
      monthLabel: _monthLabel,
      client: client,
    );
  }

  @override
  Widget build(BuildContext context) {
    final clients = _computeBilling();
    final grandTotalHT = clients.fold(0.0, (s, c) => s + c.totalHT);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (clients.isNotEmpty)
          Row(
            children: [
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _exportAllPdf(clients, grandTotalHT),
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Export PDF global'),
              ),
            ],
          ),
        const SizedBox(height: 12),

        // Sélecteur de mois
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month - 1);
                  }),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      _monthLabel,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() {
                    _selectedMonth = DateTime(
                        _selectedMonth.year, _selectedMonth.month + 1);
                  }),
                ),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => setState(() {
                    final now = DateTime.now();
                    _selectedMonth = DateTime(now.year, now.month);
                  }),
                  child: const Text('Auj.'),
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
              child: Column(
                children: [
                  Row(
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
                        '${grandTotalHT.toStringAsFixed(2)} € HT',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${clients.length} commissionnaire${clients.length > 1 ? 's' : ''} — ${clients.fold(0, (s, c) => s + c.tours)} tournées',
                        style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer
                                .withValues(alpha: 0.7)),
                      ),
                    ],
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

  Widget _clientCard(ClientBillingData c) {
    final pricing = ref.read(appStateProvider).getClientPricing(c.companyName);
    final breakEven = pricing?.breakEvenAmount;
    final isAboveBreakEven = breakEven != null && c.totalHT >= breakEven;
    final isBelowBreakEven = breakEven != null && c.totalHT < breakEven;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        c.companyName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (c.invoiceNumber != null)
                        Text(
                          'N° ${c.invoiceNumber}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20),
                  tooltip: 'Facture PDF individuelle',
                  onPressed: () => _exportSinglePdf(c),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Base
            if (c.billingMode == BillingMode.auPoint)
              _line('Points livrés',
                  '${c.totalPoints} x ${c.pricePerPoint.toStringAsFixed(2)} € = ${c.baseAmount.toStringAsFixed(2)} € HT')
            else
              _line('Tournées',
                  '${c.tours} x ${c.dailyRate.toStringAsFixed(0)} € = ${c.baseAmount.toStringAsFixed(2)} € HT'),

            // Indexation gasoil
            if (c.fuelIndexPercent != null && c.fuelIndexPercent! > 0)
              _line('Indexation gasoil (${c.fuelIndexPercent!.toStringAsFixed(1)}%)',
                  '${c.fuelIndexAmount.toStringAsFixed(2)} € HT'),

            // Manutentions
            if (c.handlingCount > 0)
              _line('Manutentions',
                  '${c.handlingCount} x = ${c.handlingAmount.toStringAsFixed(2)} € HT'),

            // Extra km
            if (c.extraKm > 0)
              _line('Km supplémentaires',
                  '${c.extraKm.toStringAsFixed(0)} km = ${c.extraKmAmount.toStringAsFixed(2)} € HT'),

            // Extra tours
            if (c.extraTours > 0)
              _line('Tours supplémentaires',
                  '${c.extraTours} x = ${c.extraTourAmount.toStringAsFixed(2)} € HT'),

            const Divider(),
            _line('TOTAL HT', '${c.totalHT.toStringAsFixed(2)} € HT',
                bold: true),

            if (breakEven != null) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                        '−${(breakEven - c.totalHT).toStringAsFixed(0)} €',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Colors.red,
                        ),
                      ),
                    if (isAboveBreakEven)
                      Text(
                        '+${(c.totalHT - breakEven).toStringAsFixed(0)} €',
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
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500)),
          ),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }
}
