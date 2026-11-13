import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/app_state.dart';
import '../../utils/design_constants.dart';
import '../../utils/shared_widgets.dart';
import '../../utils/theme_ctx.dart';
import '../add_truck.dart';
import '../models/driver.dart';
import '../models/expense.dart';
import 'depot_model.dart';
import 'depot_painter.dart';

/// Destination de la coquille vers laquelle un élément de la cour renvoie.
typedef ShellNav = void Function(String destination, {int tab});

const _weekdays = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];

String shortDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

/// ─────────────────────────────────────────────────────────────────────────
/// La cour, vue d'en haut. On regarde la flotte au lieu de la lire.
/// ─────────────────────────────────────────────────────────────────────────
class DepotPage extends ConsumerStatefulWidget {
  final ShellNav onNavigate;
  const DepotPage({super.key, required this.onNavigate});

  @override
  ConsumerState<DepotPage> createState() => _DepotPageState();
}

class _DepotPageState extends ConsumerState<DepotPage> {
  final List<DepotHit> _hits = [];
  String? _selected;
  YardState? _highlight;

  void _tap(Offset local, YardData data) {
    // Les zones les plus proches de la caméra l'emportent.
    final sorted = [..._hits]..sort((a, b) => b.depth.compareTo(a.depth));
    for (final h in sorted) {
      if (h.path.contains(local)) {
        setState(() => _selected = h.id);
        _openSheet(h.id, data);
        return;
      }
    }
    setState(() {
      _selected = null;
      _highlight = null;
    });
  }

  Future<void> _editTruck(Truck truck) async {
    final result = await Navigator.push<Truck>(
      context,
      MaterialPageRoute(builder: (_) => AddTruckPage(truck: truck)),
    );
    if (result == null || !mounted) return;
    setState(() => ref.read(appStateProvider).updateTruck(truck.plate, result));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Camion mis à jour : ${result.plate}')),
    );
  }

  Future<void> _addTruck() async {
    final result = await Navigator.push<Truck>(
      context,
      MaterialPageRoute(builder: (_) => const AddTruckPage()),
    );
    if (result == null || !mounted) return;
    setState(() => ref.read(appStateProvider).addTruck(result));
  }

  void _openSheet(String id, YardData data) {
    final sheet = _describe(id, data);
    if (sheet == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _YardSheet(sheet),
    ).whenComplete(() {
      if (mounted) setState(() => _selected = null);
    });
  }

  _SheetData? _describe(String id, YardData data) {
    final state = ref.read(appStateProvider);

    if (id.startsWith('truck:')) {
      final plate = id.substring(6);
      final yt = data.trucks.firstWhere((t) => t.truck.plate == plate);
      final t = yt.truck;
      final facts = <(String, String)>[
        ('Véhicule', [t.brand, t.model].where((s) => s.isNotEmpty).join(' ')),
        ('Gabarit', vehicleTypeLabel(t.vehicleType)),
        if (yt.tour != null)
          ('Tournée', '${yt.tour!.tourNumber} · ${yt.tour!.sector ?? "secteur non précisé"}'),
        ('Chauffeur', yt.driverName ?? '— non affecté'),
        if (yt.issue != null) ('À traiter', yt.issue!),
        ('Contrôle technique', t.ctExpiry == null
            ? 'Non renseigné'
            : '${t.ctExpiry!.day}/${t.ctExpiry!.month}/${t.ctExpiry!.year}'),
      ];
      return _SheetData(
        title: plate,
        mono: true,
        badge: yardStateLabel(yt.state),
        badgeColor: yardStateColor(yt.state, YardPalette.of(context.isDark)),
        subtitle: yt.atWorkshop
            ? 'Garé devant l’atelier, hors emplacement'
            : yt.isGhost
                ? 'Emplacement libre jusqu’au retour'
                : 'Emplacement ${yt.bay + 1} sur ${data.bayCount}',
        facts: facts,
        actions: [
          _SheetAction('Ouvrir la fiche camion', primary: true,
              run: () => _editTruck(t)),
          _SheetAction('Ses dépenses',
              run: () => widget.onNavigate('rentabilite', tab: 2)),
        ],
      );
    }

    if (id.startsWith('driver:')) {
      final name = id.substring(7);
      final d = state.drivers.firstWhere((x) => x.name == name);
      final docs = state.alertDocuments.where((x) => x.driverName == name).toList();
      return _SheetData(
        title: d.name,
        badge: driverStatusLabel(d.status),
        badgeColor: docs.isEmpty ? DC.success : DC.error,
        subtitle: 'Au dépôt, sans tournée aujourd’hui',
        facts: [
          ('Permis', d.permisLabel),
          ('Salaire', DC.eurosInt(d.totalSalary)),
          if (d.phone != null && d.phone!.isNotEmpty) ('Téléphone', d.phone!),
          if (docs.isNotEmpty)
            ('Documents', '${docs.length} à renouveler')
          else
            ('Documents', 'À jour'),
        ],
        actions: [
          _SheetAction('Sa fiche', primary: true,
              run: () => widget.onNavigate('gestion', tab: 1)),
          _SheetAction('L’affecter',
              run: () => widget.onNavigate('gestion', tab: 1)),
        ],
      );
    }

    if (id.startsWith('bay:')) {
      return _SheetData(
        title: 'Emplacement libre',
        subtitle: 'Aucun véhicule affecté',
        facts: [
          ('Flotte', '${data.trucks.length} camion${data.trucks.length > 1 ? "s" : ""} '
              'pour ${data.bayCount} emplacements'),
          ('Ce que ça dit', 'Votre capacité d’accueil immédiate'),
        ],
        actions: [
          _SheetAction('Ajouter un camion', primary: true, run: _addTruck),
        ],
      );
    }

    switch (id) {
      case 'bld:bureau':
        final unbilled = state.tours.where((t) => t.status == 'terminée').length;
        return _SheetData(
          title: 'Bureau',
          subtitle: 'Tout ce qui entre et tout ce qui sort',
          facts: [
            ('Tournées clôturées', '$unbilled au total'),
            ('Commissionnaires', '${state.clientPricings.length} configurés'),
            ('Documents', '${state.adminDocuments.length} archivés'),
          ],
          actions: [
            _SheetAction('Facturation', primary: true,
                run: () => widget.onNavigate('rentabilite', tab: 3)),
            _SheetAction('Administratif',
                run: () => widget.onNavigate('reglages', tab: 2)),
          ],
        );
      case 'bld:atelier':
        final down = data.countOf(YardState.panne);
        return _SheetData(
          title: 'Atelier',
          subtitle: 'Réparations, entretien et matériel',
          badge: down > 0 ? '$down immobilisé${down > 1 ? "s" : ""}' : 'Rien en cours',
          badgeColor: down > 0 ? DC.error : DC.success,
          facts: [
            ('Matériel', '${state.equipment.length} références'),
            ('Valeur résiduelle', DC.eurosInt(
                state.equipment.fold<double>(0, (s, e) => s + e.currentValue))),
          ],
          actions: [
            _SheetAction('Voir le matériel', primary: true,
                run: () => widget.onNavigate('gestion', tab: 2)),
            _SheetAction('Coût des réparations',
                run: () => widget.onNavigate('rentabilite', tab: 2)),
          ],
        );
      case 'bld:pompe':
        final now = DateTime.now();
        final fuel = state.expenses.where((e) =>
            e.type == ExpenseType.fuel &&
            e.date.year == now.year &&
            e.date.month == now.month);
        final liters = fuel.fold<double>(0, (s, e) => s + (e.liters ?? 0));
        return _SheetData(
          title: 'Pompe',
          subtitle: 'Carburant · ${DC.monthLabel(now)}',
          facts: [
            ('Dépensé', DC.eurosInt(fuel.fold<double>(0, (s, e) => s + e.amount))),
            ('Volume', '${liters.toStringAsFixed(0)} L'),
            ('Pleins', '${fuel.length}'),
          ],
          actions: [
            _SheetAction('Dépenses carburant', primary: true,
                run: () => widget.onNavigate('rentabilite', tab: 2)),
          ],
        );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final data = YardData.from(state);
    final pal = YardPalette.of(context.isDark);

    if (data.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_outlined, size: 56, color: context.cInk3),
              const SizedBox(height: 16),
              Text('Votre cour est vide',
                  style: context.tBody(15, w: FontWeight.w500, color: context.cInk2)),
              const SizedBox(height: 8),
              Text(
                'Ajoutez un premier camion : il apparaîtra sur son emplacement, '
                'avec son état lisible d’un coup d’œil.',
                style: context.tBody(13, color: context.cInk3),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _addTruck,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un camion'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        // Le sous-onglet nomme déjà l'écran : pas de titre redondant.
        Align(
          alignment: Alignment.centerRight,
          child: Text(shortDate(data.day),
              style: context.tBody(11.5, color: context.cInk3)),
        ),
        const SizedBox(height: 6),

        // ── La cour ──
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: pal.sky,
              border: Border.all(color: context.cBorder),
              borderRadius: BorderRadius.circular(16),
            ),
            child: AspectRatio(
              aspectRatio: 1.18,
              child: LayoutBuilder(builder: (context, c) {
                final painter = DepotPainter(
                  data: data,
                  layout: DepotLayout.forBays(data.bayCount),
                  pal: pal,
                  hits: _hits,
                  selectedId: _selected,
                  highlight: _highlight,
                );
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapUp: (e) => _tap(e.localPosition, data),
                  child: CustomPaint(
                    painter: painter,
                    size: Size(c.maxWidth, c.maxHeight),
                  ),
                );
              }),
            ),
          ),
        ),

        const SizedBox(height: 11),
        _legend(data, pal),
        const SizedBox(height: 10),
        Center(
          child: Text(
            'Touchez un camion, un chauffeur ou un bâtiment.',
            style: context.tBody(11.5, color: context.cInk3),
          ),
        ),

        const SizedBox(height: 14),
        _movements(data),
      ],
    );
  }

  Widget _legend(YardData data, YardPalette pal) {
    final rows = <(YardState, String, int)>[
      (YardState.dispo, 'Au dépôt, prêt à partir', data.countOf(YardState.dispo)),
      (YardState.tournee, 'En tournée — place vide', data.countOf(YardState.tournee)),
      (YardState.ct, 'Échéance à surveiller', data.countOf(YardState.ct)),
      (YardState.panne, 'Immobilisé à l’atelier', data.countOf(YardState.panne)),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 3.0,
      mainAxisSpacing: 7,
      crossAxisSpacing: 7,
      children: [
        for (final (st, label, n) in rows)
          _LegendChip(
            color: yardStateColor(st, pal),
            label: label,
            count: n,
            active: _highlight == st,
            onTap: n == 0
                ? null
                : () => setState(() => _highlight = _highlight == st ? null : st),
          ),
      ],
    );
  }

  Widget _movements(YardData data) {
    final out = data.trucks.where((t) => t.state == YardState.tournee).toList();
    final down = data.trucks.where((t) => t.state == YardState.panne).toList();
    if (out.isEmpty && down.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: context.cBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 10, 13, 10),
            child: Text('MOUVEMENTS DU JOUR',
                style: context.tMono(11, w: FontWeight.w600, color: context.cInk2)),
          ),
          for (final t in out)
            _MoveRow(
              stripe: DC.primary,
              title: 'Sorti · ${t.truck.plate}',
              sub: '${t.driverName ?? "chauffeur non précisé"}'
                  '${t.tour?.startTime != null ? " · départ ${t.tour!.startTime}" : ""}',
              pill: 'En tournée',
              pillColor: DC.primary,
              onTap: () => widget.onNavigate('rentabilite', tab: 1),
            ),
          for (final t in down)
            _MoveRow(
              stripe: DC.error,
              title: 'À l’atelier · ${t.truck.plate}',
              sub: t.issue ?? 'Immobilisé',
              pill: 'Bloqué',
              pillColor: DC.error,
              onTap: () => _editTruck(t.truck),
            ),
        ],
      ),
    );
  }
}

// ── Pièces d'interface ─────────────────────────────────────────────────────

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  final int count;
  final bool active;
  final VoidCallback? onTap;

  const _LegendChip({
    required this.color,
    required this.label,
    required this.count,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? color.withValues(alpha: 0.10) : context.cSurface,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: active ? color : context.cBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: count == 0 ? context.cInk3 : color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: context.tBody(11.5, color: context.cInk2),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              Text('$count',
                  style: DC.mono(16,
                      weight: FontWeight.w600,
                      color: count == 0 ? context.cInk3 : color)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  final Color stripe, pillColor;
  final String title, sub, pill;
  final VoidCallback onTap;

  const _MoveRow({
    required this.stripe,
    required this.title,
    required this.sub,
    required this.pill,
    required this.pillColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.cBorder)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 3, color: stripe),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: context.tBody(14, w: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Text(sub, style: context.tBody(12, color: context.cInk2)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: pillColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: pillColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(pill,
                      style: context.tBody(11, w: FontWeight.w600, color: pillColor)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction {
  final String label;
  final bool primary;
  final VoidCallback run;
  const _SheetAction(this.label, {required this.run, this.primary = false});
}

class _SheetData {
  final String title;
  final String? subtitle, badge;
  final Color? badgeColor;
  final bool mono;
  final List<(String, String)> facts;
  final List<_SheetAction> actions;

  const _SheetData({
    required this.title,
    required this.facts,
    required this.actions,
    this.subtitle,
    this.badge,
    this.badgeColor,
    this.mono = false,
  });
}

class _YardSheet extends StatelessWidget {
  final _SheetData d;
  const _YardSheet(this.d);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: context.cSurface3,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            Wrap(
              spacing: 9,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(d.title,
                    style: d.mono
                        ? context.tMono(20, w: FontWeight.w600, color: context.cInk)
                        : context.tTitle(20)),
                if (d.badge != null)
                  DCStatusBadge(
                    label: d.badge!,
                    color: d.badgeColor ?? DC.primary,
                  ),
              ],
            ),
            if (d.subtitle != null) ...[
              const SizedBox(height: 3),
              Text(d.subtitle!, style: context.tBody(12.5, color: context.cInk2)),
            ],
            const SizedBox(height: 14),
            for (final (k, v) in d.facts)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.cBorder)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(k, style: context.tBody(12.5, color: context.cInk3)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(v, style: context.tBody(13, w: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                for (var i = 0; i < d.actions.length; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: d.actions[i].primary
                        ? FilledButton(
                            onPressed: () {
                              Navigator.pop(context);
                              d.actions[i].run();
                            },
                            child: Text(d.actions[i].label,
                                textAlign: TextAlign.center),
                          )
                        : OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              d.actions[i].run();
                            },
                            child: Text(d.actions[i].label,
                                textAlign: TextAlign.center),
                          ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
