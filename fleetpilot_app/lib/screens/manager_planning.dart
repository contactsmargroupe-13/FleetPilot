import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../services/data_quality.dart';
import '../services/profitability.dart';
import '../utils/design_constants.dart';
import '../utils/theme_ctx.dart';
import 'models/absence.dart';
import 'models/driver.dart';
import 'depot/depot_page.dart' show ShellNav;
import 'models/tour.dart';
import 'widgets/todo_list.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Planning d'un jour : qui roule, qui est absent, et surtout quel camion
/// n'a personne — une tournée non assurée peut coûter le contrat.
/// ─────────────────────────────────────────────────────────────────────────
class ManagerPlanningPage extends ConsumerStatefulWidget {
  /// Pour ouvrir l'endroit où traiter une alerte du jour.
  final ShellNav? onNavigate;
  final bool Function(String destination)? canReach;

  const ManagerPlanningPage({super.key, this.onNavigate, this.canReach});

  @override
  ConsumerState<ManagerPlanningPage> createState() =>
      _ManagerPlanningPageState();
}

class _ManagerPlanningPageState extends ConsumerState<ManagerPlanningPage> {
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day);
  }

  bool get _isToday {
    final now = DateTime.now();
    return _day == DateTime(now.year, now.month, now.day);
  }

  bool get _isPast => _day.isBefore(
      DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day));

  String _fmt(DateTime d) =>
      '${d.day} ${DC.monthNames[d.month - 1].toLowerCase()}';

  static const _weekdays = [
    'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'
  ];

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _declareAbsence({String? driver}) async {
    final state = ref.read(appStateProvider);
    final a = await showDialog<Absence>(
      context: context,
      builder: (_) => _AbsenceDialog(
        drivers: state.drivers
            .where((d) => !Profitability.inactive.contains(d.status))
            .toList(),
        day: _day,
        driver: driver,
      ),
    );
    if (a != null) state.saveAbsence(a);
  }

  Future<void> _pickReplacement(Absence a, List<Driver> available) async {
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Qui remplace ${a.driverName} ?'),
        children: [
          if (available.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Aucun chauffeur disponible ce jour-là.',
                  style: ctx.tBody(14, color: ctx.cInk2)),
            ),
          for (final d in available)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d.name),
              child: Text(d.fullName, style: ctx.tBody(15)),
            ),
          if (a.replacementName != null)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, ''),
              child: Text('Retirer le remplaçant',
                  style: ctx.tBody(15, color: DC.error)),
            ),
        ],
      ),
    );
    if (name == null) return;
    ref.read(appStateProvider).saveAbsence(name.isEmpty
        ? a.copyWith(clearReplacement: true)
        : a.copyWith(replacementName: name));
  }

  /// Enregistre la journée oubliée : km du compteur, ou saisis s'il n'y a
  /// pas encore de relevé suivant.
  Future<void> _completeDay(OpenDay d) async {
    final state = ref.read(appStateProvider);
    if (d.km != null) {
      state.addTour(DataQuality.reconstitute(state, d));
      return;
    }
    final ctrl = TextEditingController();
    final km = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${d.driverName} · ${_fmt(d.date)}'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Km de la journée',
            suffixText: 'km',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, double.tryParse(ctrl.text.replaceAll(',', '.').trim())),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (km == null || km <= 0) return;
    state.addTour(DataQuality.reconstitute(state, d, km: km));
  }

  // ── Vue ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final active = state.drivers
        .where((d) => !Profitability.inactive.contains(d.status))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    final tours = state.tours
        .where((t) =>
            t.date.year == _day.year &&
            t.date.month == _day.month &&
            t.date.day == _day.day)
        .toList()
      ..sort((a, b) => a.driverName.compareTo(b.driverName));
    final working = tours.map((t) => t.driverName).toSet();

    final absences = state.absencesOn(_day);
    final absentNames = absences.map((a) => a.driverName).toSet();
    final replacing = absences
        .map((a) => a.replacementName)
        .whereType<String>()
        .toSet();

    // Disponibles : ni absents, ni déjà remplaçants ce jour-là.
    final available = active
        .where((d) =>
            !absentNames.contains(d.name) && !replacing.contains(d.name))
        .toList();

    // Camions à couvrir : celui d'un absent, sans remplaçant.
    final toCover = <(Absence, String)>[];
    for (final a in absences) {
      if (a.replacementName != null) continue;
      final plate = state.getAssignment(a.driverName)?.truckPlate;
      if (plate != null) toCover.add((a, plate));
    }

    // Ni absents déclarés, ni tournée saisie : oubli de saisie, ou absence
    // non déclarée.
    final silent = (_isPast || _isToday)
        ? active
            .where((d) =>
                !working.contains(d.name) &&
                !absentNames.contains(d.name) &&
                !replacing.contains(d.name))
            .toList()
        : <Driver>[];

    final km = tours.fold<double>(0, (s, t) => s + t.kmTotal);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'absence',
        onPressed: () => _declareAbsence(),
        icon: const Icon(Icons.event_busy_outlined),
        label: const Text('Déclarer une absence'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(
                    () => _day = _day.subtract(const Duration(days: 1))),
              ),
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _day,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _day = picked);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Text(
                          _isToday
                              ? 'Aujourd’hui'
                              : _weekdays[_day.weekday - 1][0].toUpperCase() +
                                  _weekdays[_day.weekday - 1].substring(1),
                          style: context.tTitle(17,
                              color: _isToday ? DC.primary : context.cInk),
                        ),
                        Text(_fmt(_day),
                            style: context.tBody(12.5, color: context.cInk2)),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () =>
                    setState(() => _day = _day.add(const Duration(days: 1))),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              _stat('Au travail', '${working.length}/${active.length}'),
              const SizedBox(width: 8),
              _stat('Absents', '${absences.length}'),
              const SizedBox(width: 8),
              _stat('Km', km.toStringAsFixed(0)),
            ],
          ),

          // ── À traiter (aujourd'hui seulement) ───────────────────────
          if (_isToday && widget.onNavigate != null)
            Builder(builder: (_) {
              final todos = buildTodos(state)
                  .where((t) => widget.canReach?.call(t.destination) ?? true)
                  // Les camions à couvrir ont déjà leur section juste dessous.
                  .where((t) => t.destination != 'gestion' || t.tab != 0)
                  .toList();
              if (todos.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TodoCard(todos: todos, onNavigate: widget.onNavigate!),
              );
            }),

          // ── Journées à compléter (toutes dates) ─────────────────────
          if (_isToday)
            Builder(builder: (_) {
              final open = DataQuality.openDays(state);
              if (open.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _title('Journées à compléter', DC.warning),
                  Text(
                    'Commencées au compteur, jamais terminées. Le relevé suivant '
                    'du camion donne les km : un geste pour les enregistrer.',
                    style: context.tBody(12.5, color: context.cInk2),
                  ),
                  const SizedBox(height: 8),
                  for (final d in open.take(6))
                    _card(
                      color: DC.warning,
                      icon: Icons.speed,
                      title: '${d.driverName} · ${_fmt(d.date)}',
                      subtitle: d.km != null
                          ? '${d.truckPlate} · ${d.km} km d’après le compteur'
                          : '${d.truckPlate} · en attente du prochain relevé',
                      action: d.km != null ? 'Enregistrer' : 'Saisir',
                      onAction: () => _completeDay(d),
                    ),
                ],
              );
            }),

          // ── À couvrir ─────────────────────────────────────────────────
          if (toCover.isNotEmpty) ...[
            _title('À couvrir', DC.error),
            for (final (a, plate) in toCover)
              _card(
                color: DC.error,
                icon: Icons.local_shipping_outlined,
                title: '$plate sans chauffeur',
                subtitle:
                    '${a.driverName} : ${absenceReasonLabel(a.reason).toLowerCase()}',
                action: 'Remplaçant',
                onAction: () => _pickReplacement(a, available),
              ),
          ],

          // ── Absents ──────────────────────────────────────────────────
          if (absences.isNotEmpty) ...[
            _title('Absents', DC.warning),
            for (final a in absences)
              _card(
                color: DC.warning,
                icon: Icons.event_busy_outlined,
                title: a.driverName,
                subtitle: [
                  absenceReasonLabel(a.reason),
                  a.days > 1
                      ? 'du ${_fmt(a.start)} au ${_fmt(a.end)}'
                      : 'le ${_fmt(a.start)}',
                  if (a.replacementName != null)
                    'remplacé par ${a.replacementName}',
                ].join(' · '),
                action: a.replacementName == null ? 'Remplaçant' : 'Changer',
                onAction: () => _pickReplacement(a, available),
                onDelete: () => state.deleteAbsence(a.id),
              ),
          ],

          // ── En tournée ───────────────────────────────────────────────
          if (tours.isNotEmpty) ...[
            _title('Tournées saisies', DC.success),
            for (final t in tours) _tour(t),
          ],

          // ── Silencieux ───────────────────────────────────────────────
          if (silent.isNotEmpty) ...[
            _title('Pas de tournée saisie', context.cInk3),
            Text(
              _isToday
                  ? 'Normal si la journée n’est pas finie. Sinon, une absence à déclarer ?'
                  : 'Un oubli de saisie, ou une absence à déclarer ?',
              style: context.tBody(12.5, color: context.cInk2),
            ),
            const SizedBox(height: 8),
            for (final d in silent)
              _card(
                color: context.cInk3,
                icon: Icons.person_outline,
                title: d.fullName,
                subtitle: driverStatusLabel(d.status),
                action: 'Absent',
                onAction: () => _declareAbsence(driver: d.name),
              ),
          ],

          if (tours.isEmpty && absences.isEmpty && silent.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: Text('Rien de prévu ce jour-là.',
                    style: context.tBody(14, color: context.cInk2)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: context.cSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.cBorder),
          ),
          child: Column(
            children: [
              Text(value, style: context.tTitle(18)),
              Text(label, style: context.tBody(11.5, color: context.cInk2)),
            ],
          ),
        ),
      );

  Widget _title(String t, Color color) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Row(
          children: [
            Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(t.toUpperCase(),
                style: context.tMono(11, w: FontWeight.w600, color: context.cInk2)),
          ],
        ),
      );

  Widget _card({
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
    String? action,
    VoidCallback? onAction,
    VoidCallback? onDelete,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: context.cBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.tBody(14.5, w: FontWeight.w600)),
                Text(subtitle, style: context.tBody(12.5, color: context.cInk2)),
              ],
            ),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action)),
          if (onDelete != null)
            IconButton(
              tooltip: 'Supprimer l’absence',
              icon: Icon(Icons.close, size: 18, color: context.cInk3),
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }

  Widget _tour(Tour t) => _card(
        color: DC.success,
        icon: Icons.route_outlined,
        title: t.driverName,
        subtitle: [
          t.truckPlate,
          '${t.kmTotal.toStringAsFixed(0)} km',
          if (t.companyName != null && t.companyName!.isNotEmpty) t.companyName!,
          if (t.startTime != null)
            '${t.startTime}${t.endTime != null ? ' → ${t.endTime}' : ''}',
        ].join(' · '),
      );
}

class _AbsenceDialog extends StatefulWidget {
  final List<Driver> drivers;
  final DateTime day;
  final String? driver;
  const _AbsenceDialog({required this.drivers, required this.day, this.driver});

  @override
  State<_AbsenceDialog> createState() => _AbsenceDialogState();
}

class _AbsenceDialogState extends State<_AbsenceDialog> {
  late String? _driver = widget.driver;
  late DateTime _start = widget.day;
  late DateTime _end = widget.day;
  AbsenceReason _reason = AbsenceReason.conge;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        if (_end.isBefore(d)) _end = d;
      } else {
        _end = d.isBefore(_start) ? _start : d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Déclarer une absence'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _driver,
            decoration: const InputDecoration(
                labelText: 'Chauffeur', border: OutlineInputBorder()),
            items: [
              for (final d in widget.drivers)
                DropdownMenuItem(value: d.name, child: Text(d.fullName)),
            ],
            onChanged: (v) => setState(() => _driver = v),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            children: [
              for (final r in AbsenceReason.values)
                ChoiceChip(
                  label: Text(absenceReasonLabel(r)),
                  selected: _reason == r,
                  onSelected: (_) => setState(() => _reason = r),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(true),
                  child: Text('Du ${_fmt(_start)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pick(false),
                  child: Text('Au ${_fmt(_end)}'),
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(
          onPressed: _driver == null
              ? null
              : () => Navigator.pop(
                    context,
                    Absence(
                      id: DateTime.now().microsecondsSinceEpoch.toString(),
                      driverName: _driver!,
                      start: _start,
                      end: _end,
                      reason: _reason,
                    ),
                  ),
          child: const Text('Enregistrer'),
        ),
      ],
    );
  }
}
