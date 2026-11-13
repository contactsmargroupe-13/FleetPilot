import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../services/profitability.dart';
import '../utils/design_constants.dart';
import '../utils/theme_ctx.dart';
import 'manager_result.dart' show fmtEuros;
import 'models/client_pricing.dart';
import 'models/client_statement.dart';
import 'models/monthly_points.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Relevés du mois : ce que chaque commissionnaire a réellement payé.
///
/// Tant qu'un relevé n'est pas saisi, le chiffre d'affaires n'est qu'une
/// estimation tirée des tarifs. Le saisir fait apparaître l'écart — et les
/// pénalités, là où un sous-traitant perd de l'argent sans le voir.
/// Pour un commissionnaire payé au point, les points du relevé se saisissent
/// ici aussi, chauffeur par chauffeur.
/// ─────────────────────────────────────────────────────────────────────────
class ManagerStatementsPage extends ConsumerStatefulWidget {
  final DateTime? month;

  /// Commissionnaire à mettre en avant à l'ouverture.
  final String? company;

  /// Dans un onglet de la coquille : pas de Scaffold propre.
  final bool embedded;

  const ManagerStatementsPage(
      {super.key, this.month, this.company, this.embedded = false});

  @override
  ConsumerState<ManagerStatementsPage> createState() =>
      _ManagerStatementsPageState();
}

class _PointsRow {
  final String driver;
  final int tours, legacy;
  final double price;
  final TextEditingController ctrl;
  _PointsRow(this.driver, this.tours, this.legacy, this.price, this.ctrl);
}

class _ClientForm {
  final String name;
  final BillingMode mode;
  final int tours;
  final List<_PointsRow> points;
  final TextEditingController paid, penalties;
  _ClientForm(this.name, this.mode, this.tours, this.points, this.paid,
      this.penalties);

  void dispose() {
    paid.dispose();
    penalties.dispose();
    for (final p in points) {
      p.ctrl.dispose();
    }
  }
}

double? _num(String s) {
  final t = s.replaceAll(' ', '').replaceAll(' ', '').replaceAll(',', '.').trim();
  return t.isEmpty ? null : double.tryParse(t);
}

String _field(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2).replaceAll('.', ',');

class _ManagerStatementsPageState extends ConsumerState<ManagerStatementsPage> {
  late DateTime _month;
  List<_ClientForm> _forms = [];
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Par défaut, le mois dernier : c'est celui dont le relevé vient d'arriver.
    _month = widget.month != null
        ? DateTime(widget.month!.year, widget.month!.month)
        : DateTime(now.year, now.month - 1);
    _load();
  }

  @override
  void dispose() {
    for (final f in _forms) {
      f.dispose();
    }
    super.dispose();
  }

  void _load() {
    for (final f in _forms) {
      f.dispose();
    }
    final s = ref.read(appStateProvider);
    final tours = <String, int>{};
    final pointGroups = <String, Map<String, (int, int)>>{}; // client → driver → (tours, legacy)

    for (final t in s.tours) {
      if (t.date.year != _month.year || t.date.month != _month.month) continue;
      final pricing = s.getClientPricing(t.companyName);
      if (pricing == null) continue;
      tours[pricing.companyName] = (tours[pricing.companyName] ?? 0) + 1;
      if (pricing.billingMode == BillingMode.auPoint) {
        final g = pointGroups.putIfAbsent(pricing.companyName, () => {});
        final cur = g[t.driverName] ?? (0, 0);
        g[t.driverName] = (cur.$1 + 1, cur.$2 + t.clientsCount);
      }
    }

    final forms = <_ClientForm>[];
    for (final name in tours.keys) {
      final pricing = s.getClientPricing(name)!;
      final st = s.getStatement(_month, name);
      final rows = <_PointsRow>[];
      (pointGroups[name] ?? {}).forEach((driver, v) {
        final price = s.getAssignment(driver)?.customPricePerPoint ??
            pricing.pricePerPoint ??
            0;
        final saved = s.getMonthlyPoints(_month, name, driver);
        rows.add(_PointsRow(driver, v.$1, v.$2, price,
            TextEditingController(text: saved?.points.toString() ?? '')));
      });
      rows.sort((a, b) => a.driver.compareTo(b.driver));
      forms.add(_ClientForm(
        name,
        pricing.billingMode,
        tours[name]!,
        rows,
        TextEditingController(text: st == null ? '' : _field(st.paidAmount)),
        TextEditingController(
            text: st == null || st.penalties == 0 ? '' : _field(st.penalties)),
      ));
    }
    forms.sort((a, b) {
      if (widget.company != null) {
        if (a.name == widget.company) return -1;
        if (b.name == widget.company) return 1;
      }
      return a.name.compareTo(b.name);
    });
    setState(() {
      _forms = forms;
      _dirty = false;
    });
  }

  Future<void> _changeMonth(int delta) async {
    if (_dirty && !await _confirmDiscard()) return;
    _month = DateTime(_month.year, _month.month + delta);
    _load();
  }

  Future<bool> _confirmDiscard() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Abandonner la saisie ?'),
        content: const Text('Les montants non enregistrés seront perdus.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Rester')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Abandonner')),
        ],
      ),
    );
    return ok == true;
  }

  void _save() {
    final s = ref.read(appStateProvider);
    for (final f in _forms) {
      for (final r in f.points) {
        final v = int.tryParse(r.ctrl.text.trim());
        final cur = s.getMonthlyPoints(_month, f.name, r.driver)?.points;
        if (v != cur) s.setMonthlyPoints(_month, f.name, r.driver, v);
      }
      final paid = _num(f.paid.text);
      s.setStatement(
        _month,
        f.name,
        paid == null
            ? null
            : ClientStatement(
                month: MonthlyPoints.monthKey(_month),
                companyName: f.name,
                paidAmount: paid,
                penalties: _num(f.penalties.text) ?? 0,
              ),
      );
    }
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Relevés enregistrés')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    // Le facturé dépend des points en cours de saisie : on le recalcule à
    // partir des tarifs, en remplaçant les points par ce qui est tapé.
    final estimates = {
      for (final c in Profitability.billing(state, _month)) c.companyName: c,
    };

    final body = ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
      children: [
        Row(
          children: [
            IconButton(
                onPressed: () => _changeMonth(-1),
                icon: const Icon(Icons.chevron_left)),
            Expanded(
              child: Center(
                child: Text(DC.monthLabel(_month), style: context.tTitle(16)),
              ),
            ),
            IconButton(
                onPressed: () => _changeMonth(1),
                icon: const Icon(Icons.chevron_right)),
          ],
        ),
        Text(
          'Recopie le relevé de chaque commissionnaire : le résultat du mois '
          'passe d’une estimation à un chiffre réel, et tu vois ce qu’il a retenu.',
          style: context.tBody(12.5, color: context.cInk2),
        ),
        const SizedBox(height: 14),
        if (_forms.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: context.cSurface,
              borderRadius: BorderRadius.circular(DC.rCard),
              border: Border.all(color: context.cBorder),
            ),
            child: Text('Aucune tournée facturable ce mois-ci.',
                style: context.tBody(13.5, color: context.cInk2)),
          ),
        for (final f in _forms) _card(f, estimates[f.name]?.totalHT ?? 0),
      ],
    );

    final saveBar = _forms.isEmpty
        ? null
        : SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: FilledButton.icon(
                onPressed: _dirty ? _save : null,
                icon: const Icon(Icons.check),
                label: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Enregistrer'),
                ),
              ),
            ),
          );

    if (widget.embedded) {
      return Column(
        children: [
          Expanded(child: body),
          if (saveBar != null)
            Container(
              decoration: BoxDecoration(
                color: context.cSurface,
                border: Border(top: BorderSide(color: context.cBorder)),
              ),
              child: saveBar,
            ),
        ],
      );
    }

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Relevés du mois')),
        body: body,
        bottomNavigationBar: saveBar,
      ),
    );
  }

  Widget _card(_ClientForm f, double savedEstimate) {
    // Estimation à jour des points tapés (au point), sinon celle des tarifs.
    var estimate = savedEstimate;
    if (f.mode == BillingMode.auPoint && f.points.isNotEmpty) {
      final s = ref.read(appStateProvider);
      var savedPoints = 0.0, typedPoints = 0.0;
      for (final r in f.points) {
        final saved = s.getMonthlyPoints(_month, f.name, r.driver)?.points ?? r.legacy;
        final typed = int.tryParse(r.ctrl.text.trim()) ?? r.legacy;
        savedPoints += saved * r.price;
        typedPoints += typed * r.price;
      }
      final fuel = 1 + (s.getClientPricing(f.name)?.fuelIndexPercent ?? 0) / 100;
      estimate += (typedPoints - savedPoints) * fuel;
    }
    final paid = _num(f.paid.text);
    final gap = paid == null ? null : paid - estimate;

    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
          suffixText: '€',
          border: const OutlineInputBorder(),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(
            color: widget.company == f.name
                ? DC.primary.withValues(alpha: 0.5)
                : context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(f.name, style: context.tBody(16, w: FontWeight.w700)),
              ),
              _pill(paid == null ? 'À saisir' : 'Saisi',
                  paid == null ? DC.warning : DC.success),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${f.tours} tournée${f.tours > 1 ? "s" : ""} · '
            '${billingModeLabel(f.mode).toLowerCase()} · '
            'selon tes tarifs : ${fmtEuros(estimate)} HT',
            style: context.tBody(12.5, color: context.cInk2),
          ),

          if (f.points.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('POINTS LIVRÉS',
                style: context.tMono(10.5, w: FontWeight.w600, color: context.cInk3)),
            for (final r in f.points)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.driver,
                              style: context.tBody(14, w: FontWeight.w600)),
                          Text(
                            '${r.tours} tournée${r.tours > 1 ? "s" : ""} · '
                            '${r.price.toStringAsFixed(2).replaceAll('.', ',')} € / point',
                            style: context.tBody(12, color: context.cInk3),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 104,
                      child: TextField(
                        controller: r.ctrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textAlign: TextAlign.right,
                        onChanged: (_) => setState(() => _dirty = true),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: r.legacy > 0 ? '${r.legacy}' : 'points',
                          suffixText: 'pts',
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],

          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: f.paid,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: deco('Payé HT'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: f.penalties,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() => _dirty = true),
                  decoration: deco('dont pénalités', hint: '0'),
                ),
              ),
            ],
          ),
          if (gap != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  gap.abs() < 1
                      ? Icons.check_circle
                      : (gap < 0 ? Icons.trending_down : Icons.trending_up),
                  size: 18,
                  color: gap < -1 ? DC.error : DC.success,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    gap.abs() < 1
                        ? 'Conforme à tes tarifs'
                        : gap < 0
                            ? '${fmtEuros(-gap)} de moins que tes tarifs'
                            : '${fmtEuros(gap)} de plus que tes tarifs',
                    style: context.tBody(13,
                        w: FontWeight.w600,
                        color: gap < -1 ? DC.error : DC.success),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(DC.rPill),
        ),
        child: Text(text,
            style: DC.body(11.5, weight: FontWeight.w700, color: color)),
      );
}
