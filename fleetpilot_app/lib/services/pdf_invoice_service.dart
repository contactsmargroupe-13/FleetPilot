import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../screens/models/client_pricing.dart';
import 'company_settings.dart';

class ClientBillingData {
  final String companyName;
  final double dailyRate;
  final double? fuelIndexPercent;
  final String? siret;
  final String? tvaIntra;
  final String? address;
  final String? phone;
  final String? contactName;
  final BillingMode billingMode;
  final double pricePerPoint;
  int totalPoints = 0;

  int tours = 0;
  double baseAmount = 0;
  int handlingCount = 0;
  double handlingAmount = 0;
  double extraKm = 0;
  double extraKmAmount = 0;
  int extraTours = 0;
  double extraTourAmount = 0;
  String? invoiceNumber;

  double get fuelIndexAmount =>
      (fuelIndexPercent != null && fuelIndexPercent! > 0)
          ? baseAmount * fuelIndexPercent! / 100
          : 0.0;

  double get totalHT =>
      baseAmount +
      fuelIndexAmount +
      handlingAmount +
      extraKmAmount +
      extraTourAmount;

  ClientBillingData({
    required this.companyName,
    required this.dailyRate,
    this.fuelIndexPercent,
    this.siret,
    this.tvaIntra,
    this.address,
    this.phone,
    this.contactName,
    this.billingMode = BillingMode.aLaFiche,
    this.pricePerPoint = 0.0,
  });
}

class PdfInvoiceService {
  // ── Export global (toutes les factures) ──────────────────────────────────

  static Future<void> generateAndPrint({
    required String monthLabel,
    required List<ClientBillingData> clients,
    required double grandTotal,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildHeader(monthLabel, 'RÉCAPITULATIF'),
          pw.SizedBox(height: 24),

          // Tableau récapitulatif
          pw.Text('Récapitulatif par commissionnaire',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            cellHeight: 28,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
            headers: [
              'N° Facture',
              'Commissionnaire',
              'Tournées',
              'Base HT',
              'Extras HT',
              'Index. gasoil',
              'TOTAL HT',
            ],
            data: [
              ...clients.map((c) => [
                    c.invoiceNumber ?? '',
                    c.companyName,
                    '${c.tours}',
                    '${c.baseAmount.toStringAsFixed(2)} €',
                    '${(c.handlingAmount + c.extraKmAmount + c.extraTourAmount).toStringAsFixed(2)} €',
                    c.fuelIndexAmount > 0
                        ? '${c.fuelIndexAmount.toStringAsFixed(2)} €'
                        : '—',
                    '${c.totalHT.toStringAsFixed(2)} €',
                  ]),
              [
                '',
                'TOTAL',
                '${clients.fold(0, (s, c) => s + c.tours)}',
                '',
                '',
                '',
                '${grandTotal.toStringAsFixed(2)} €',
              ],
            ],
          ),

          pw.SizedBox(height: 24),

          // Détail par commissionnaire
          ...clients.map((c) => _buildClientDetail(c)),

          pw.SizedBox(height: 30),

          // Total final
          _buildGrandTotal(monthLabel, grandTotal),

          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Facturation_$monthLabel',
    );
  }

  // ── Export facture individuelle par commissionnaire ──────────────────────

  static Future<void> generateSingleInvoice({
    required String monthLabel,
    required ClientBillingData client,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          _buildHeader(monthLabel, 'FACTURE'),

          // Numéro de facture
          if (client.invoiceNumber != null) ...[
            pw.SizedBox(height: 8),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text('N° ${client.invoiceNumber}',
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
            ),
          ],

          pw.SizedBox(height: 20),

          // Destinataire
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Commissionnaire',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey600)),
                pw.SizedBox(height: 4),
                pw.Text(client.companyName,
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (client.siret != null && client.siret!.isNotEmpty)
                  pw.Text('SIRET : ${client.siret}',
                      style: const pw.TextStyle(fontSize: 10)),
                if (client.address != null && client.address!.isNotEmpty)
                  pw.Text(client.address!,
                      style: const pw.TextStyle(fontSize: 10)),
                if (client.tvaIntra != null && client.tvaIntra!.isNotEmpty)
                  pw.Text('TVA Intra : ${client.tvaIntra}',
                      style: const pw.TextStyle(fontSize: 10)),
                if (client.phone != null && client.phone!.isNotEmpty)
                  pw.Text('Tél : ${client.phone}',
                      style: const pw.TextStyle(fontSize: 10)),
                if (client.contactName != null && client.contactName!.isNotEmpty)
                  pw.Text('Contact : ${client.contactName}',
                      style: const pw.TextStyle(fontSize: 10)),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Tableau détaillé
          pw.Text('Détail de la facturation',
              style:
                  pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            cellHeight: 30,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.centerRight,
              3: pw.Alignment.centerRight,
            },
            headers: ['Désignation', 'Quantité', 'Prix unitaire HT', 'Total HT'],
            data: [
              if (client.billingMode == BillingMode.auPoint)
                [
                  'Points livraison',
                  '${client.totalPoints}',
                  '${client.pricePerPoint.toStringAsFixed(2)} €',
                  '${client.baseAmount.toStringAsFixed(2)} €',
                ]
              else
                [
                  'Tournées',
                  '${client.tours}',
                  '${client.dailyRate.toStringAsFixed(2)} €',
                  '${client.baseAmount.toStringAsFixed(2)} €',
                ],
              if (client.fuelIndexPercent != null &&
                  client.fuelIndexPercent! > 0)
                [
                  'Indexation gasoil (${client.fuelIndexPercent!.toStringAsFixed(1)}%)',
                  '',
                  '',
                  '${client.fuelIndexAmount.toStringAsFixed(2)} €',
                ],
              if (client.handlingCount > 0)
                [
                  'Manutentions',
                  '${client.handlingCount}',
                  client.handlingCount > 0
                      ? '${(client.handlingAmount / client.handlingCount).toStringAsFixed(2)} €'
                      : '—',
                  '${client.handlingAmount.toStringAsFixed(2)} €',
                ],
              if (client.extraKm > 0)
                [
                  'Km supplémentaires',
                  '${client.extraKm.toStringAsFixed(0)} km',
                  client.extraKm > 0
                      ? '${(client.extraKmAmount / client.extraKm).toStringAsFixed(2)} €/km'
                      : '—',
                  '${client.extraKmAmount.toStringAsFixed(2)} €',
                ],
              if (client.extraTours > 0)
                [
                  'Tours supplémentaires',
                  '${client.extraTours}',
                  client.extraTours > 0
                      ? '${(client.extraTourAmount / client.extraTours).toStringAsFixed(2)} €'
                      : '—',
                  '${client.extraTourAmount.toStringAsFixed(2)} €',
                ],
            ],
          ),

          pw.SizedBox(height: 16),

          // Totaux
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1.5),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              children: [
                _pdfLine('Total HT', '${client.totalHT.toStringAsFixed(2)} €',
                    bold: true, fontSize: 13),
                pw.SizedBox(height: 4),
                _pdfLine('TVA', 'Non applicable — art. 293 B du CGI',
                    fontSize: 9, color: PdfColors.grey600),
                pw.Divider(),
                _pdfLine('Net à payer',
                    '${client.totalHT.toStringAsFixed(2)} €',
                    bold: true, fontSize: 15),
              ],
            ),
          ),

          pw.SizedBox(height: 20),

          // Conditions de paiement
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Conditions de paiement',
                    style: pw.TextStyle(
                        fontSize: 10, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Date d\'échéance : ${_fmtDate(DateTime.now().add(const Duration(days: 30)))}',
                    style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                pw.Text(
                    'Paiement à 30 jours à compter de la date de facturation.',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                    'Escompte pour paiement anticipé : néant.',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                    'En cas de retard de paiement, une pénalité de 3 fois le taux d\'intérêt légal sera appliquée.',
                    style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                    'Indemnité forfaitaire de recouvrement : 40 €.',
                    style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),

          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Facture_${client.invoiceNumber ?? client.companyName}_$monthLabel',
    );
  }

  // ── Widgets PDF partagés ────────────────────────────────────────────────

  static pw.Widget _buildHeader(String monthLabel, String title) {
    final companyName = CompanySettings.name.isNotEmpty
        ? CompanySettings.name
        : 'FleetPilote';
    final companyAddress = CompanySettings.address;
    final companySiret = CompanySettings.siret;
    final companyTvaIntra = CompanySettings.tvaIntra;
    final companyPhone = CompanySettings.phone;
    final companyEmail = CompanySettings.email;

    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(companyName,
                      style: pw.TextStyle(
                          fontSize: 22, fontWeight: pw.FontWeight.bold)),
                  if (companyAddress.isNotEmpty)
                    pw.Text(companyAddress,
                        style: const pw.TextStyle(fontSize: 10)),
                  if (companySiret.isNotEmpty)
                    pw.Text('SIRET : $companySiret',
                        style: const pw.TextStyle(fontSize: 10)),
                  if (companyTvaIntra.isNotEmpty)
                    pw.Text('TVA Intra : $companyTvaIntra',
                        style: const pw.TextStyle(fontSize: 10)),
                  if (companyPhone.isNotEmpty)
                    pw.Text('Tél : $companyPhone',
                        style: const pw.TextStyle(fontSize: 10)),
                  if (companyEmail.isNotEmpty)
                    pw.Text(companyEmail,
                        style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(title,
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text(monthLabel,
                    style: const pw.TextStyle(fontSize: 14)),
                pw.SizedBox(height: 4),
                pw.Text(
                    'Date : ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                    style: const pw.TextStyle(
                        fontSize: 9, color: PdfColors.grey600)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Divider(),
      ],
    );
  }

  static pw.Widget _buildClientDetail(ClientBillingData c) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(height: 12),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(c.companyName,
                      style: pw.TextStyle(
                          fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  if (c.invoiceNumber != null)
                    pw.Text(c.invoiceNumber!,
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
              pw.SizedBox(height: 6),
              if (c.billingMode == BillingMode.auPoint)
                _pdfLine('Points livraison',
                    '${c.totalPoints} x ${c.pricePerPoint.toStringAsFixed(2)} € = ${c.baseAmount.toStringAsFixed(2)} € HT')
              else
                _pdfLine('Tournées',
                    '${c.tours} x ${c.dailyRate.toStringAsFixed(0)} € = ${c.baseAmount.toStringAsFixed(2)} € HT'),
              if (c.fuelIndexPercent != null && c.fuelIndexPercent! > 0)
                _pdfLine(
                    'Indexation gasoil (${c.fuelIndexPercent!.toStringAsFixed(1)}%)',
                    '${c.fuelIndexAmount.toStringAsFixed(2)} € HT'),
              if (c.handlingCount > 0)
                _pdfLine('Manutentions',
                    '${c.handlingCount} x = ${c.handlingAmount.toStringAsFixed(2)} € HT'),
              if (c.extraKm > 0)
                _pdfLine('Km supplémentaires',
                    '${c.extraKm.toStringAsFixed(0)} km = ${c.extraKmAmount.toStringAsFixed(2)} € HT'),
              if (c.extraTours > 0)
                _pdfLine('Tours supplémentaires',
                    '${c.extraTours} x = ${c.extraTourAmount.toStringAsFixed(2)} € HT'),
              pw.Divider(),
              _pdfLine(
                  'TOTAL HT', '${c.totalHT.toStringAsFixed(2)} € HT',
                  bold: true),
            ],
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildGrandTotal(String monthLabel, double grandTotal) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(width: 2),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TOTAL HT $monthLabel',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.Text('${grandTotal.toStringAsFixed(2)} €',
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('TVA',
                  style: const pw.TextStyle(fontSize: 10)),
              pw.Text('Non applicable — art. 293 B du CGI',
                  style: const pw.TextStyle(
                      fontSize: 10, color: PdfColors.grey600)),
            ],
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildFooter() {
    final companySiret = CompanySettings.siret;
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            'TVA non applicable — article 293 B du Code Général des Impôts',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            textAlign: pw.TextAlign.center,
          ),
          if (companySiret.isNotEmpty)
            pw.Text(
              'SIRET : $companySiret',
              style:
                  const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
              textAlign: pw.TextAlign.center,
            ),
          pw.Text(
            'En cas de retard de paiement, pénalité de 3x le taux d\'intérêt légal + indemnité forfaitaire de recouvrement de 40 €.',
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey400),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _pdfLine(String label, String value,
      {bool bold = false, double fontSize = 10, PdfColor? color}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: fontSize,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                    color: color)),
          ),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: fontSize,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: color)),
        ],
      ),
    );
  }

  static String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
