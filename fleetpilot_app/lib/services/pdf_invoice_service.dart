import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'company_settings.dart';

class ClientBillingData {
  final String companyName;
  final int tours;
  final int handlingCount;
  final double handlingAmount;
  final double extraKm;
  final double extraKmAmount;
  final int extraTours;
  final double extraTourAmount;
  double get total => handlingAmount + extraKmAmount + extraTourAmount;

  const ClientBillingData({
    required this.companyName,
    required this.tours,
    required this.handlingCount,
    required this.handlingAmount,
    required this.extraKm,
    required this.extraKmAmount,
    required this.extraTours,
    required this.extraTourAmount,
  });
}

class PdfInvoiceService {
  static Future<void> generateAndPrint({
    required String monthLabel,
    required List<ClientBillingData> clients,
    required double grandTotal,
  }) async {
    final pdf = pw.Document();

    final companyName = CompanySettings.name.isNotEmpty
        ? CompanySettings.name
        : 'FleetPilot';
    final companyAddress = CompanySettings.address;
    final companySiret = CompanySettings.siret;
    final companyPhone = CompanySettings.phone;
    final companyEmail = CompanySettings.email;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // En-tête entreprise
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
                  pw.Text('FACTURATION',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Text(monthLabel,
                      style: const pw.TextStyle(fontSize: 14)),
                  pw.SizedBox(height: 4),
                  pw.Text(
                      'Edité le ${DateTime.now().day.toString().padLeft(2, '0')}/${DateTime.now().month.toString().padLeft(2, '0')}/${DateTime.now().year}',
                      style: const pw.TextStyle(
                          fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 16),

          // Tableau récapitulatif
          pw.Text('Récapitulatif par client',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),

          pw.TableHelper.fromTextArray(
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            cellHeight: 28,
            cellAlignments: {
              0: pw.Alignment.centerLeft,
              1: pw.Alignment.center,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.center,
              5: pw.Alignment.centerRight,
              6: pw.Alignment.centerRight,
            },
            headers: [
              'Client',
              'Tournées',
              'Manut.',
              'Manut. €',
              'Extra km',
              'Extra km €',
              'TOTAL €',
            ],
            data: [
              ...clients.map((c) => [
                    c.companyName,
                    '${c.tours}',
                    '${c.handlingCount}',
                    '${c.handlingAmount.toStringAsFixed(2)}',
                    '${c.extraKm.toStringAsFixed(0)}',
                    '${c.extraKmAmount.toStringAsFixed(2)}',
                    c.total.toStringAsFixed(2),
                  ]),
              // Ligne total
              [
                'TOTAL',
                '',
                '',
                '',
                '',
                '',
                '${grandTotal.toStringAsFixed(2)} €',
              ],
            ],
          ),

          pw.SizedBox(height: 24),

          // Détail par client
          ...clients.map((c) => pw.Column(
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
                        pw.Text(c.companyName,
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold)),
                        pw.SizedBox(height: 6),
                        _pdfLine('Tournées effectuées', '${c.tours}'),
                        _pdfLine('Manutentions', '${c.handlingCount} x = ${c.handlingAmount.toStringAsFixed(2)} €'),
                        _pdfLine('Km supplémentaires', '${c.extraKm.toStringAsFixed(0)} km = ${c.extraKmAmount.toStringAsFixed(2)} €'),
                        _pdfLine('Tours supplémentaires', '${c.extraTours} x = ${c.extraTourAmount.toStringAsFixed(2)} €'),
                        pw.Divider(),
                        _pdfLine('TOTAL FACTURABLE', '${c.total.toStringAsFixed(2)} €',
                            bold: true),
                      ],
                    ),
                  ),
                ],
              )),

          pw.SizedBox(height: 30),

          // Total final
          pw.Container(
            padding: const pw.EdgeInsets.all(14),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 2),
              borderRadius: pw.BorderRadius.circular(4),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('TOTAL FACTURABLE $monthLabel',
                    style: pw.TextStyle(
                        fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('${grandTotal.toStringAsFixed(2)} €',
                    style: pw.TextStyle(
                        fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) => pdf.save(),
      name: 'Facturation_$monthLabel',
    );
  }

  static pw.Widget _pdfLine(String label, String value,
      {bool bold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 3),
      child: pw.Row(
        children: [
          pw.Expanded(
            child: pw.Text(label,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ),
          pw.Text(value,
              style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }
}
