import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../services/accounting_export.dart';
import '../services/data_quality.dart';
import '../services/profitability.dart';
import '../utils/design_constants.dart';
import '../utils/theme_ctx.dart';
import 'depot/depot_page.dart' show ShellNav;
import 'manager_statements.dart';
import 'widgets/setup_checklist.dart';
import 'models/expense.dart';


/// ─────────────────────────────────────────────────────────────────────────
/// Résultat du mois : ce que le transport a rapporté, ce qu'il a coûté, et
/// ce qu'il reste. Les kilomètres servent de dénominateur commun — c'est
/// le coût au kilomètre qui dit si une tournée vaut d'être faite.
/// ─────────────────────────────────────────────────────────────────────────
class ManagerResultPage extends ConsumerStatefulWidget {
  final ShellNav onNavigate;

  /// Une chose « à traiter » ne s'affiche que si le rôle courant peut
  /// réellement l'ouvrir : sinon la ligne serait un cul-de-sac.
  final bool Function(String destination) canReach;

  /// Le taux de charges est un réglage de l'entreprise : manager seulement.
  final bool canEditCompany;

  const ManagerResultPage({
    super.key,
    required this.onNavigate,
    required this.canReach,
    this.canEditCompany = false,
  });

  @override
  ConsumerState<ManagerResultPage> createState() => _ManagerResultPageState();
}

class _ManagerResultPageState extends ConsumerState<ManagerResultPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  ShellNav get onNavigate => widget.onNavigate;

  bool get _isFuture {
    final now = DateTime.now();
    return _month.isAfter(DateTime(now.year, now.month));
  }

  Future<void> _editChargeRate() async {
    final state = ref.read(appStateProvider);
    final ctrl = TextEditingController(
        text: (state.employerChargeRate * 100).round().toString());
    final v = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Charges patronales'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ce que l’entreprise paie en plus du salaire brut. Environ 42 % '
              'pour un chauffeur, moins avec la réduction générale sur les bas '
              'salaires. Ta fiche de paie ou ton comptable te donne le chiffre exact.',
              style: ctx.tBody(13, color: ctx.cInk2),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Taux de charges',
                suffixText: '%',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () {
              final p = double.tryParse(ctrl.text.replaceAll(',', '.').trim());
              if (p != null && p >= 0 && p <= 100) Navigator.pop(ctx, p / 100);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (v != null) state.setEmployerChargeRate(v);
  }

  Future<void> _export() async {
    try {
      await AccountingExport.share(ref.read(appStateProvider), _month);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export impossible : $e')));
    }
  }

  void _openStatements({String? company}) => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ManagerStatementsPage(month: _month, company: company),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final r = Profitability.month(state, _month);
    final prev = Profitability.month(
        state, DateTime(_month.year, _month.month - 1));
    final insights = Profitability.insights(r, previous: prev);
    final reliability = DataQuality.reliability(state, r);
    final positive = r.result >= 0;
    final missingStatements =
        r.isOver ? r.clients.where((c) => !c.confirmed).toList() : const [];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Mois précédent',
              onPressed: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Center(
                child: Text(DC.monthLabel(_month), style: context.tTitle(17)),
              ),
            ),
            IconButton(
              tooltip: 'Mois suivant',
              onPressed: _isFuture
                  ? null
                  : () => setState(
                      () => _month = DateTime(_month.year, _month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (widget.canEditCompany)
          SetupChecklist(onNavigate: onNavigate, onChargeRate: _editChargeRate),

        // ── Le résultat ───────────────────────────────────────────────
        _Kpi(
          wide: true,
          label: 'Résultat du mois',
          value: r.result,
          valueColor: positive ? DC.success : DC.error,
          sub: [
            if (r.revenue > 0)
              'marge ${r.margin.toStringAsFixed(1).replaceAll('.', ',')} %',
            if (r.isCurrent)
              'fixes au prorata ${r.daysElapsed}/${r.daysInMonth} j',
          ].join(' · '),
          extra: r.projection == null
              ? null
              : 'Fin de mois si le rythme se maintient : ${fmtEuros(r.projection!)}',
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                label: r.revenueConfirmed ? 'CA payé' : 'CA estimé',
                value: r.revenue,
                sub: '${r.tours.length} tournée${r.tours.length > 1 ? "s" : ""}',
                onTap: () => onNavigate('rentabilite', tab: 3),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _Kpi(
                label: 'Coûts HT',
                value: r.costs,
                sub: 'dont ${fmtEuros(r.expenses)} de dépenses',
                onTap: () => onNavigate('rentabilite', tab: 2),
              ),
            ),
          ],
        ),

        if (r.tours.isNotEmpty) ...[
          const SizedBox(height: 9),
          _ReliabilityCard(
            reliability: reliability,
            onIssue: (i) => onNavigate(i.destination, tab: i.tab),
            canReach: widget.canReach,
          ),
        ],

        // ── Ce qu'il faut retenir ─────────────────────────────────────
        if (insights.isNotEmpty) ...[
          _section(context, 'Ce qu’il faut retenir'),
          _InsightCard(insights: insights),
        ],

        // ── Ce qui manque pour un chiffre juste ──────────────────────
        if (missingStatements.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Banner(
            icon: Icons.receipt_long_outlined,
            color: DC.warning,
            title: 'Relevés à saisir',
            text: '${missingStatements.map((c) => c.name).join(', ')} : '
                'le chiffre d’affaires reste estimé tant que le relevé '
                'n’est pas recopié.',
            action: 'Saisir',
            onTap: () => _openStatements(),
          ),
        ],
        if (r.pendingPoints.isNotEmpty && missingStatements.isEmpty) ...[
          const SizedBox(height: 10),
          _Banner(
            icon: Icons.edit_note,
            color: DC.warning,
            title: 'Points à saisir',
            text: r.pendingPoints
                    .map((p) => '${p.companyName} · ${p.driverName}')
                    .take(3)
                    .join('\n') +
                (r.pendingPoints.length > 3
                    ? '\n+ ${r.pendingPoints.length - 3} autre(s)'
                    : ''),
            action: 'Saisir',
            onTap: () => _openStatements(company: r.pendingPoints.first.companyName),
          ),
        ],
        if (r.untaxed.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Banner(
            icon: Icons.request_quote_outlined,
            color: DC.error,
            title: '${r.untaxed.length} tournée${r.untaxed.length > 1 ? "s" : ""} sans tarif',
            text: 'Elles ne rapportent rien dans ce calcul : '
                'le commissionnaire n’est pas configuré.',
            action: 'Configurer',
            onTap: widget.canReach('reglages')
                ? () => onNavigate('reglages', tab: 0)
                : null,
          ),
        ],
        if (!state.chargeRateConfirmed && r.salariesFull > 0) ...[
          const SizedBox(height: 10),
          _Banner(
            icon: Icons.percent,
            color: DC.primary,
            title: 'Charges patronales : ${(state.employerChargeRate * 100).round()} % par défaut',
            text: 'Les salaires sont comptés bruts + charges. Ajuste le taux '
                'à celui de tes fiches de paie.',
            action: 'Ajuster',
            onTap: widget.canEditCompany ? _editChargeRate : null,
          ),
        ],

        // ── Transport ─────────────────────────────────────────────────
        _section(context, 'Transport'),
        Row(
          children: [
            Expanded(
                child: _Stat('Kilomètres', _int(r.km),
                    sub: r.workDays > 0
                        ? '${_int(r.km / r.workDays)} km / jour'
                        : null)),
            const SizedBox(width: 9),
            Expanded(
                child: _Stat('Jours travaillés', '${r.workDays}',
                    sub: '${r.tours.length} tournée${r.tours.length > 1 ? "s" : ""}')),
          ],
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
                child: _Stat('CA / km', _perKm(r.revenuePerKm),
                    sub: _trend(r.revenuePerKm, prev.revenuePerKm,
                            higherIsBetter: true) ??
                        'ce que rapporte 1 km',
                    subColor: _trendColor(r.revenuePerKm, prev.revenuePerKm,
                        higherIsBetter: true))),
            const SizedBox(width: 9),
            Expanded(
                child: _Stat('Coût / km', _perKm(r.costPerKm),
                    sub: _trend(r.costPerKm, prev.costPerKm,
                            higherIsBetter: false) ??
                        'ce que coûte 1 km',
                    subColor: _trendColor(r.costPerKm, prev.costPerKm,
                        higherIsBetter: false))),
          ],
        ),
        const SizedBox(height: 9),
        _Stat('Résultat par jour travaillé', fmtEuros(r.resultPerDay),
            valueColor: r.resultPerDay >= 0 ? null : DC.error,
            sub: _trend(r.resultPerDay, prev.resultPerDay, higherIsBetter: true),
            subColor: _trendColor(r.resultPerDay, prev.resultPerDay,
                higherIsBetter: true)),

        // ── Où part l'argent ─────────────────────────────────────────
        _section(context, 'Où part l’argent (HT)'),
        _CostBars(items: [
          ('Salaires chargés (+${(r.chargeRate * 100).round()} %)', r.salaries),
          ('Camions : loyer, crédit, assurance', r.trucksFixed),
          for (final t in expenseTypesOrdered)
            (expenseTypeLabel(t), r.expensesByType[t] ?? 0),
        ]),
        if (widget.canEditCompany)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _editChargeRate,
              child: const Text('Modifier le taux de charges'),
            ),
          ),

        // ── Par camion ───────────────────────────────────────────────
        if (r.trucks.isNotEmpty) ...[
          _section(context, 'Par camion'),
          _Table(
            headers: const ['Camion', 'Km', 'CA', 'Coût/km', 'Résultat'],
            rows: [
              for (final t in r.trucks)
                _TableRow([
                  t.plate,
                  _int(t.km),
                  fmtEuros(t.revenue),
                  t.km > 0 ? _perKm(t.costPerKm) : '—',
                  fmtEuros(t.result),
                ], highlight: t.result >= 0 ? DC.success : DC.error),
            ],
          ),
        ],

        // ── Par commissionnaire ──────────────────────────────────────
        if (r.clients.isNotEmpty) ...[
          _section(context, 'Par commissionnaire'),
          _Table(
            headers: const ['Commissionnaire', 'Tournées', 'CA / km', 'CA'],
            rows: [
              for (final c in r.clients)
                _TableRow([
                  c.confirmed ? c.name : '${c.name} (estimé)',
                  '${c.tours}',
                  c.km > 0 ? _perKm(c.revenuePerKm) : '—',
                  fmtEuros(c.revenue),
                ]),
            ],
          ),
        ],

        // ── Par chauffeur ────────────────────────────────────────────
        if (r.drivers.isNotEmpty) ...[
          _section(context, 'Par chauffeur'),
          _Table(
            headers: const ['Chauffeur', 'Jours', 'Km', 'CA', 'Coût'],
            rows: [
              for (final d in r.drivers)
                _TableRow([
                  d.name,
                  '${d.days}',
                  _int(d.km),
                  fmtEuros(d.revenue),
                  fmtEuros(d.salary),
                ]),
            ],
          ),
        ],

        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _export,
          icon: const Icon(Icons.download_outlined),
          label: Text('Export comptable — ${DC.monthLabel(_month)}'),
        ),
        const SizedBox(height: 4),
        Text('Ventes, achats et activité du mois, en CSV pour Excel.',
            textAlign: TextAlign.center,
            style: context.tBody(11.5, color: context.cInk3)),
      ],
    );
  }

  /// « +8 % vs octobre », ou null si la comparaison n'a pas de sens.
  String? _trend(double now, double before, {required bool higherIsBetter}) {
    final c = Profitability.change(now, before);
    if (c == null || c.abs() < 1) return null;
    final prevMonth = DC.monthNames[(_month.month + 10) % 12].toLowerCase();
    return '${c > 0 ? '+' : '−'}${c.abs().round()} % vs $prevMonth';
  }

  Color? _trendColor(double now, double before, {required bool higherIsBetter}) {
    final c = Profitability.change(now, before);
    if (c == null || c.abs() < 1) return null;
    return (c > 0) == higherIsBetter ? DC.success : DC.error;
  }

  static String _int(double v) => fmtEuros(v).replaceAll(' €', '');
  static String _perKm(double v) =>
      '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 22, 2, 9),
        child: Text(title.toUpperCase(),
            style: context.tMono(11, w: FontWeight.w600, color: context.cInk2)),
      );

}

/// « 4 440 » plutôt que « 4440 » : les milliers se lisent d'un coup d'œil.
String fmtEuros(double v) {
  final neg = v < 0;
  final digits = v.abs().toStringAsFixed(0);
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('\u202F');
    out.write(digits[i]);
  }
  return '${neg ? '−' : ''}$out €';
}

class _Kpi extends StatelessWidget {
  final String label;
  final double value;
  final String? sub;
  final Color? valueColor;
  final String? extra;
  final bool wide;
  final VoidCallback? onTap;

  const _Kpi({
    required this.label,
    required this.value,
    this.sub,
    this.valueColor,
    this.extra,
    this.wide = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.cSurface,
      borderRadius: BorderRadius.circular(DC.rCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(DC.rCard),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(13, 12, 13, 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(DC.rCard),
            border: Border.all(color: context.cBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: context.tMono(10.5,
                      w: FontWeight.w600, color: context.cInk3)),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: fmtEuros(value).replaceAll(' €', ''),
                      style: DC.title(wide ? 30 : 22,
                          weight: FontWeight.w800,
                          color: valueColor ?? context.cInk),
                    ),
                    TextSpan(
                      text: ' €',
                      style: DC.body(wide ? 18 : 14,
                          weight: FontWeight.w600,
                          color: valueColor ?? context.cInk),
                    ),
                  ]),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              if (sub != null && sub!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(sub!,
                    style: context.tBody(11.5, color: context.cInk2)),
              ],
              if (extra != null) ...[
                const SizedBox(height: 8),
                Text(extra!,
                    style: context.tBody(12, w: FontWeight.w600,
                        color: context.cInk2)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final String? sub;
  final Color? subColor, valueColor;
  const _Stat(this.label, this.value,
      {this.sub, this.subColor, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 13, 12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: context.tMono(10.5, w: FontWeight.w600, color: context.cInk3)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                style: context.tTitle(20,
                    w: FontWeight.w800, color: valueColor ?? context.cInk)),
          ),
          if (sub != null) ...[
            const SizedBox(height: 1),
            Text(sub!,
                style: context.tBody(11.5, color: subColor ?? context.cInk2)),
          ],
        ],
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title, text, action;
  final VoidCallback? onTap;
  const _Banner({
    required this.icon,
    required this.color,
    required this.title,
    required this.text,
    required this.action,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 11, 8, 11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.tBody(14, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(text, style: context.tBody(12.5, color: context.cInk2)),
              ],
            ),
          ),
          if (onTap != null)
            TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

/// Répartition des coûts : une barre par poste, proportionnelle au total.
class _CostBars extends StatelessWidget {
  final List<(String, double)> items;
  const _CostBars({required this.items});

  @override
  Widget build(BuildContext context) {
    final shown = items.where((i) => i.$2 > 0).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final total = shown.fold<double>(0, (s, i) => s + i.$2);

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 6),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: context.cBorder),
      ),
      child: shown.isEmpty
          ? Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('Aucun coût sur ce mois.',
                  style: context.tBody(13, color: context.cInk2)),
            )
          : Column(
              children: [
                for (final i in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(i.$1,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.tBody(13, w: FontWeight.w500)),
                            ),
                            const SizedBox(width: 8),
                            Text(fmtEuros(i.$2),
                                style: context.tMono(12.5,
                                    w: FontWeight.w700, color: context.cInk)),
                            SizedBox(
                              width: 44,
                              child: Text(
                                '${(i.$2 / total * 100).round()} %',
                                textAlign: TextAlign.right,
                                style: context.tMono(11.5, color: context.cInk3),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: i.$2 / total,
                            minHeight: 6,
                            backgroundColor: context.cSurface2,
                            color: DC.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _TableRow {
  final List<String> cells;
  final Color? highlight; // couleur de la dernière colonne
  const _TableRow(this.cells, {this.highlight});
}

/// Tableau compact : première colonne en texte, les autres alignées à droite.
class _Table extends StatelessWidget {
  final List<String> headers;
  final List<_TableRow> rows;
  const _Table({required this.headers, required this.rows});

  @override
  Widget build(BuildContext context) {
    Widget cell(String text, int i, {TextStyle? style}) => Expanded(
          flex: i == 0 ? 5 : 3,
          child: Text(
            text,
            textAlign: i == 0 ? TextAlign.left : TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 8),
            child: Row(children: [
              for (var i = 0; i < headers.length; i++)
                cell(headers[i], i,
                    style: context.tMono(10, w: FontWeight.w600, color: context.cInk3)),
            ]),
          ),
          for (final r in rows)
            Container(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: context.cBorder)),
              ),
              child: Row(children: [
                for (var i = 0; i < r.cells.length; i++)
                  cell(
                    r.cells[i],
                    i,
                    style: i == 0
                        ? context.tBody(13, w: FontWeight.w600)
                        : context.tMono(12,
                            w: i == r.cells.length - 1
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: i == r.cells.length - 1 && r.highlight != null
                                ? r.highlight
                                : context.cInk),
                  ),
              ]),
            ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final List<Insight> insights;
  const _InsightCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        children: [
          for (final i in insights)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      i.good ? Icons.check_circle : Icons.arrow_right_alt,
                      size: 18,
                      color: i.good ? DC.success : DC.warning,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(i.text,
                        style: context.tBody(13.5, w: FontWeight.w500)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// À quel point les chiffres du mois reposent sur des données réelles, et
/// ce qu'il faut compléter pour qu'ils le soient.
class _ReliabilityCard extends StatefulWidget {
  final Reliability reliability;
  final void Function(Issue) onIssue;
  final bool Function(String destination) canReach;
  const _ReliabilityCard(
      {required this.reliability, required this.onIssue, required this.canReach});

  @override
  State<_ReliabilityCard> createState() => _ReliabilityCardState();
}

class _ReliabilityCardState extends State<_ReliabilityCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.reliability;
    final color = r.score >= 85
        ? DC.success
        : r.score >= 60
            ? DC.warning
            : DC.error;
    final label = r.score >= 85
        ? 'Chiffres fiables'
        : r.score >= 60
            ? 'Chiffres à compléter'
            : 'Chiffres peu fiables';

    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(DC.rCard),
            onTap: r.issues.isEmpty ? null : () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(13, 11, 10, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.verified_outlined, size: 18, color: color),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(label,
                            style: context.tBody(14, w: FontWeight.w700)),
                      ),
                      Text('${r.score} %',
                          style: context.tMono(14, w: FontWeight.w800, color: color)),
                      if (r.issues.isNotEmpty)
                        Icon(_open ? Icons.expand_less : Icons.expand_more,
                            size: 20, color: context.cInk3),
                    ],
                  ),
                  const SizedBox(height: 7),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: r.score / 100,
                      minHeight: 5,
                      backgroundColor: context.cSurface2,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${r.toursMeasured}/${r.toursTotal} journées aux km mesurés'
                    '${r.issues.isEmpty ? '' : ' · ${r.issues.length} point${r.issues.length > 1 ? "s" : ""} à compléter'}',
                    style: context.tBody(12, color: context.cInk2),
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            for (final i in r.issues)
              InkWell(
                onTap: widget.canReach(i.destination) ? () => widget.onIssue(i) : null,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(13, 10, 10, 10),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: context.cBorder)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 7, color: color),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(i.text, style: context.tBody(13)),
                      ),
                      if (widget.canReach(i.destination))
                        Icon(Icons.chevron_right, size: 18, color: context.cInk3),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
