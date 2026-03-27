import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import 'models/manager_alert.dart';

/// Filtre affiché dans les chips
enum _AlertFilter { all, pending, validated }

class ManagerAlertsPage extends ConsumerStatefulWidget {
  const ManagerAlertsPage({super.key});

  @override
  ConsumerState<ManagerAlertsPage> createState() => _ManagerAlertsPageState();
}

class _ManagerAlertsPageState extends ConsumerState<ManagerAlertsPage> {
  _AlertFilter _filter = _AlertFilter.pending;
  ManagerAlertType? _typeFilter;

  @override
  Widget build(BuildContext context) {
    final allAlerts = ref.watch(appStateProvider).managerAlerts
      ..sort((a, b) => b.date.compareTo(a.date));

    final filtered = allAlerts.where((a) {
      if (_filter == _AlertFilter.pending && a.validated) return false;
      if (_filter == _AlertFilter.validated && !a.validated) return false;
      if (_typeFilter != null && a.type != _typeFilter) return false;
      return true;
    }).toList();

    final pendingCount =
        allAlerts.where((a) => !a.validated).length;
    final validatedCount =
        allAlerts.where((a) => a.validated).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alertes'),
        actions: [
          if (filtered.any((a) => !a.validated))
            TextButton.icon(
              onPressed: () {
                for (final a in filtered.where((a) => !a.validated)) {
                  ref.read(appStateProvider).validateManagerAlert(a.id);
                }
              },
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Tout valider'),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Filtres statut ──
          Padding(
            padding: const EdgeInsets.fromLTRB(DC.screenH, 12, DC.screenH, 0),
            child: Row(
              children: [
                _buildFilterChip(
                  'En attente',
                  pendingCount,
                  _AlertFilter.pending,
                  DC.warning,
                  DC.warningBg,
                ),
                const SizedBox(width: DC.chipGap),
                _buildFilterChip(
                  'Validees',
                  validatedCount,
                  _AlertFilter.validated,
                  DC.success,
                  DC.successBg,
                ),
                const SizedBox(width: DC.chipGap),
                _buildFilterChip(
                  'Toutes',
                  allAlerts.length,
                  _AlertFilter.all,
                  DC.primary,
                  DC.primaryBg,
                ),
              ],
            ),
          ),

          // ── Filtres type ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(DC.screenH, 10, DC.screenH, 6),
            child: Row(
              children: [
                _buildTypeChip(null, 'Tous types'),
                ...ManagerAlertType.values.map(
                  (t) => _buildTypeChip(t, managerAlertTypeLabel(t)),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Liste ──
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _filter == _AlertFilter.validated
                              ? Icons.check_circle_outline
                              : Icons.notifications_off_outlined,
                          size: 48,
                          color: DC.textTertiary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _filter == _AlertFilter.validated
                              ? 'Aucune alerte validee'
                              : 'Aucune alerte en attente',
                          style: DC.body(15, color: DC.textSecondary),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) =>
                        _AlertTile(alert: filtered[i], ref: ref),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label,
    int count,
    _AlertFilter value,
    Color color,
    Color bg,
  ) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? bg : DC.surface2,
          borderRadius: BorderRadius.circular(DC.rPill),
          border: Border.all(color: selected ? color : DC.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: DC.body(12,
                  weight: FontWeight.w600,
                  color: selected ? color : DC.textSecondary),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.15) : DC.surface3,
                borderRadius: BorderRadius.circular(DC.rBadge),
              ),
              child: Text(
                '$count',
                style: DC.mono(11, color: selected ? color : DC.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(ManagerAlertType? type, String label) {
    final selected = _typeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: DC.chipGap),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _typeFilter = type),
      ),
    );
  }
}

// ── Tuile d'alerte ────────────────────────────────────────────────────────────

class _AlertTile extends StatelessWidget {
  final ManagerAlert alert;
  final WidgetRef ref;

  const _AlertTile({required this.alert, required this.ref});

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(alert.type);
    final icon = _iconForType(alert.type);
    final dateStr = DateFormat('dd/MM/yy HH:mm').format(alert.date);

    return Container(
      color: alert.validated
          ? DC.successBg.withValues(alpha: 0.3)
          : (!alert.read ? color.withValues(alpha: 0.04) : null),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                alert.title,
                style: TextStyle(
                  fontWeight:
                      !alert.read ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (alert.validated)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: DC.successBg,
                  borderRadius: BorderRadius.circular(DC.rBadge),
                  border: Border.all(color: DC.successBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 12, color: DC.success),
                    const SizedBox(width: 3),
                    Text('Valide',
                        style: DC.mono(10, color: DC.success)),
                  ],
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (alert.message != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(alert.message!,
                    style: DC.body(13, color: DC.textSecondary)),
              ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  managerAlertTypeLabel(alert.type),
                  style: DC.mono(11, color: color),
                ),
                const SizedBox(width: 8),
                Text(dateStr, style: DC.mono(11)),
                if (alert.validatedAt != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Valide le ${DateFormat('dd/MM').format(alert.validatedAt!)}',
                    style: DC.mono(10, color: DC.success),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: alert.validated
            ? IconButton(
                icon: const Icon(Icons.undo, size: 18, color: DC.textTertiary),
                tooltip: 'Annuler validation',
                onPressed: () {
                  ref.read(appStateProvider).unvalidateManagerAlert(alert.id);
                },
              )
            : FilledButton.tonalIcon(
                onPressed: () {
                  ref.read(appStateProvider).validateManagerAlert(alert.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Alerte validee'),
                      duration: Duration(seconds: 1),
                    ),
                  );
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Valider'),
                style: FilledButton.styleFrom(
                  backgroundColor: DC.successBg,
                  foregroundColor: DC.success,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  textStyle: DC.body(12, weight: FontWeight.w600),
                ),
              ),
        isThreeLine: alert.message != null,
        onTap: () {
          if (!alert.read) {
            ref.read(appStateProvider).markManagerAlertRead(alert.id);
          }
        },
      ),
    );
  }

  static Color _colorForType(ManagerAlertType type) {
    switch (type) {
      case ManagerAlertType.truckChange:
        return DC.warning;
      case ManagerAlertType.documentExpire:
        return DC.error;
      case ManagerAlertType.fuelScan:
        return DC.primary;
      case ManagerAlertType.info:
        return DC.info;
    }
  }

  static IconData _iconForType(ManagerAlertType type) {
    switch (type) {
      case ManagerAlertType.truckChange:
        return Icons.swap_horiz;
      case ManagerAlertType.documentExpire:
        return Icons.warning_amber_rounded;
      case ManagerAlertType.fuelScan:
        return Icons.local_gas_station;
      case ManagerAlertType.info:
        return Icons.info_outline;
    }
  }
}
