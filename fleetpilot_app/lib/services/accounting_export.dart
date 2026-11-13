import 'dart:convert';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../providers/app_state.dart';
import '../screens/models/expense.dart';
import 'profitability.dart';

/// Un fichier prêt à partager.
class ExportFile {
  final String name;
  final String content;
  const ExportFile(this.name, this.content);
}

/// ─────────────────────────────────────────────────────────────────────────
/// Export du mois pour l'expert-comptable : trois CSV lisibles dans Excel
/// (séparateur « ; », virgule décimale, BOM UTF-8 pour les accents).
/// ─────────────────────────────────────────────────────────────────────────
class AccountingExport {
  static String _n(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  static String _cell(Object? v) {
    final s = v?.toString() ?? '';
    return s.contains(';') || s.contains('"') || s.contains('\n')
        ? '"${s.replaceAll('"', '""')}"'
        : s;
  }

  static String _csv(List<List<Object?>> rows) =>
      rows.map((r) => r.map(_cell).join(';')).join('\r\n');

  static String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  static List<ExportFile> build(AppState s, DateTime month) {
    final key = Profitability.monthKey(month);
    final r = Profitability.month(s, month);
    final billing = Profitability.billing(s, month);

    // ── Ventes ──
    final sales = <List<Object?>>[
      [
        'Commissionnaire', 'Tournées', 'Facturé HT (tarifs)', 'TVA 20 %',
        'Facturé TTC', 'Payé HT (relevé)', 'Pénalités HT', 'Écart HT',
      ],
    ];
    for (final b in billing) {
      final c = r.clients.where((c) => c.name == b.companyName).firstOrNull;
      sales.add([
        b.companyName,
        b.tours,
        _n(b.totalHT),
        _n(b.totalHT * 0.2),
        _n(b.totalHT * 1.2),
        c?.paid == null ? '' : _n(c!.paid!),
        c == null || c.penalties == 0 ? '' : _n(c.penalties),
        c?.paid == null ? '' : _n(c!.gap),
      ]);
    }

    // ── Achats ──
    final purchases = <List<Object?>>[
      ['Date', 'Camion', 'Catégorie', 'Chauffeur', 'Libellé', 'HT', 'TVA',
        'TTC', 'Taux TVA'],
    ];
    final expenses = s.expenses
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    for (final e in expenses) {
      purchases.add([
        _date(e.date),
        e.truckPlate,
        expenseTypeLabel(e.type),
        e.driverName ?? '',
        e.note ?? '',
        _n(e.amountHT),
        _n(e.vat),
        _n(e.amount),
        vatLabel(e.effectiveVatRate),
      ]);
    }

    // ── Activité ──
    final activity = <List<Object?>>[
      ['Camion', 'Tournées', 'Km', 'CA HT', 'Dépenses HT', 'Coûts fixes',
        'Salaires chargés', 'Résultat'],
      for (final t in r.trucks)
        [t.plate, t.tours, t.km.toStringAsFixed(0), _n(t.revenue),
          _n(t.expenses), _n(t.fixed), _n(t.salaries), _n(t.result)],
      [],
      ['Total', r.tours.length, r.km.toStringAsFixed(0), _n(r.revenue),
        _n(r.expenses), _n(r.trucksFixed), _n(r.salaries), _n(r.result)],
      [],
      ['Charges patronales appliquées',
        '${(r.chargeRate * 100).round()} %'],
      ['Chiffre d’affaires',
        r.revenueConfirmed ? 'confirmé par les relevés' : 'estimé d’après les tarifs'],
    ];

    return [
      ExportFile('ventes_$key.csv', _csv(sales)),
      ExportFile('achats_$key.csv', _csv(purchases)),
      ExportFile('activite_$key.csv', _csv(activity)),
    ];
  }

  static Future<void> share(AppState s, DateTime month) async {
    final files = build(s, month);
    const bom = [0xEF, 0xBB, 0xBF];
    await SharePlus.instance.share(ShareParams(
      subject: 'Export comptable ${Profitability.monthKey(month)}',
      files: [
        for (final f in files)
          XFile.fromData(
            Uint8List.fromList([...bom, ...utf8.encode(f.content)]),
            name: f.name,
            mimeType: 'text/csv',
          ),
      ],
      fileNameOverrides: [for (final f in files) f.name],
    ));
  }
}
