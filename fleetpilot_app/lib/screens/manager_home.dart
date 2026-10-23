import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import '../utils/theme_ctx.dart';
import 'add_truck.dart';
import 'depot/depot_page.dart' show ShellNav;
import 'models/client_pricing.dart';
import 'models/driver_document.dart';
import 'models/expense.dart';
import 'models/tour.dart';

/// Une chose à traiter, avec l'endroit où la traiter.
class _Todo {
  final IconData icon;
  final Color color;
  final String title, subtitle, destination;
  final int tab;
  const _Todo(this.icon, this.color, this.title, this.subtitle,
      this.destination, this.tab);
}

/// ─────────────────────────────────────────────────────────────────────────
/// Accueil : ce qui a bougé, et ce qu'il faut traiter. Rien d'autre.
/// L'analyse détaillée vit dans le second sous-onglet.
/// ─────────────────────────────────────────────────────────────────────────
class ManagerHomePage extends ConsumerWidget {
  final ShellNav onNavigate;

  /// Une chose « à traiter » ne s'affiche que si le rôle courant peut
  /// réellement l'ouvrir : sinon la ligne serait un cul-de-sac.
  final bool Function(String destination) canReach;

  const ManagerHomePage({
    super.key,
    required this.onNavigate,
    required this.canReach,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appStateProvider);
    final now = DateTime.now();
    final month = DateTime(now.year, now.month, 1);

    final monthTours = state.tours
        .where((t) => t.date.year == month.year && t.date.month == month.month)
        .toList();

    double revenue = 0;
    final untaxed = <Tour>[];
    for (final t in monthTours) {
      final pricing = state.getClientPricing(t.companyName);
      if (pricing == null) {
        untaxed.add(t);
        continue;
      }
      final assign = state.getAssignment(t.driverName);
      if (pricing.billingMode == BillingMode.auPoint) {
        final pp = assign?.customPricePerPoint ?? pricing.pricePerPoint ?? 0;
        revenue += t.clientsCount * pp;
      } else {
        revenue += assign?.customDailyRate ?? pricing.dailyRate;
      }
    }

    final spent = state.expenses
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .fold<double>(0, (s, e) => s + e.amount);

    final fixed = state.trucks
            .where((t) => t.truckStatus != TruckStatus.vendu)
            .fold<double>(0, (s, t) => s + t.totalMonthlyCost) +
        state.drivers.fold<double>(0, (s, d) => s + d.totalSalary);

    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final daysElapsed =
        (now.year == month.year && now.month == month.month) ? now.day : daysInMonth;
    final fixedSoFar = fixed * daysElapsed / daysInMonth;

    final result = revenue - spent - fixedSoFar;
    final margin = revenue > 0 ? (result / revenue) * 100 : 0.0;

    final fuel = state.expenses
        .where((e) =>
            e.type == ExpenseType.fuel &&
            e.date.year == month.year &&
            e.date.month == month.month)
        .fold<double>(0, (s, e) => s + e.amount);

    final todos = _todos(state, untaxed).where((t) => canReach(t.destination)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('Accueil', style: context.tTitle(23)),
            const Spacer(),
            Text(DC.monthLabel(month),
                style: context.tBody(11.5, color: context.cInk3)),
          ],
        ),
        const SizedBox(height: 12),

        _Kpi(
          wide: true,
          label: 'Chiffre d’affaires du mois',
          value: revenue,
          sub: '${monthTours.length} tournée${monthTours.length > 1 ? "s" : ""}'
              '${revenue > 0 ? " · marge ${margin.toStringAsFixed(1)} %" : ""}',
          subColor: result >= 0 ? DC.success : DC.error,
          onTap: () => onNavigate('argent', tab: 1),
        ),
        const SizedBox(height: 9),
        Row(
          children: [
            Expanded(
              child: _Kpi(
                label: 'Résultat',
                value: result,
                sub: 'fixe $daysElapsed/$daysInMonth j : ${fmtEuros(fixedSoFar)}',
                subColor: result >= 0 ? DC.success : DC.error,
                onTap: () => onNavigate('argent', tab: 2),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _Kpi(
                label: 'Dépenses',
                value: spent,
                sub: fuel > 0 ? 'dont ${fmtEuros(fuel)} carburant' : 'ce mois',
                onTap: () => onNavigate('argent', tab: 0),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        _TodoCard(todos: todos, onNavigate: onNavigate),
      ],
    );
  }

  List<_Todo> _todos(AppState state, List<Tour> untaxed) {
    final todos = <_Todo>[];

    for (final t in state.trucks) {
      if (t.truckStatus == TruckStatus.enPanne ||
          t.truckStatus == TruckStatus.enReparation ||
          t.truckStatus == TruckStatus.hs) {
        todos.add(_Todo(Icons.build_circle_outlined, DC.error,
            '${t.plate} immobilisé', truckStatusLabel(t.truckStatus), 'depot', 0));
      }
    }
    for (final t in state.trucks) {
      if (t.truckStatus == TruckStatus.vendu) continue;
      if (t.ctStatus >= 2) {
        todos.add(_Todo(Icons.rule_folder_outlined,
            t.ctStatus == 4 ? DC.error : DC.warning,
            'Contrôle technique ${t.plate}',
            t.ctStatus == 4 ? 'Expiré — à refaire' : 'Échéance proche',
            'depot', 1));
      }
      if (t.insuranceStatus >= 2) {
        todos.add(_Todo(Icons.shield_outlined,
            t.insuranceStatus == 3 ? DC.error : DC.warning,
            'Assurance ${t.plate}',
            t.insuranceStatus == 3 ? 'Expirée' : 'Expire sous 30 jours',
            'depot', 1));
      }
    }
    for (final doc in state.alertDocuments) {
      todos.add(_Todo(Icons.badge_outlined, DC.error,
          'Document de ${doc.driverName}', documentTypeLabel(doc.type), 'equipe', 0));
    }
    if (untaxed.isNotEmpty) {
      todos.add(_Todo(Icons.request_quote_outlined, DC.warning,
          '${untaxed.length} tournée${untaxed.length > 1 ? "s" : ""} sans tarif',
          'Le commissionnaire n’est pas configuré', 'argent', 4));
    }
    final msgs = state.unreadManagerMessages;
    if (msgs > 0) {
      todos.add(_Todo(Icons.chat_bubble_outline, DC.primary,
          '$msgs message${msgs > 1 ? "s" : ""} non lu${msgs > 1 ? "s" : ""}',
          'Ouvrir la messagerie', 'messages', 0));
    }
    return todos;
  }
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
  final Color? subColor;
  final bool wide;
  final VoidCallback? onTap;

  const _Kpi({
    required this.label,
    required this.value,
    this.sub,
    this.subColor,
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
                      style: DC.title(wide ? 28 : 23,
                          weight: FontWeight.w800, color: context.cInk),
                    ),
                    TextSpan(
                      text: ' €',
                      style: DC.body(wide ? 17 : 14,
                          weight: FontWeight.w600, color: context.cInk),
                    ),
                  ]),
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(sub!,
                    style: context.tBody(11.5, color: subColor ?? context.cInk2)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TodoCard extends StatelessWidget {
  final List<_Todo> todos;
  final ShellNav onNavigate;
  const _TodoCard({required this.todos, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    if (todos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cSuccessBg,
          borderRadius: BorderRadius.circular(DC.rCard),
          border: Border.all(color: DC.success.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: DC.success, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text('Rien à traiter — tout est à jour.',
                  style: context.tBody(13, color: context.cInk2)),
            ),
          ],
        ),
      );
    }

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
            padding: const EdgeInsets.fromLTRB(13, 11, 13, 11),
            child: Row(
              children: [
                Text('À TRAITER',
                    style: context.tMono(11,
                        w: FontWeight.w600, color: context.cInk2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: DC.warning.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${todos.length}',
                      style: DC.mono(11,
                          weight: FontWeight.w700, color: DC.warning)),
                ),
              ],
            ),
          ),
          for (final t in todos)
            InkWell(
              onTap: () => onNavigate(t.destination, tab: t.tab),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: context.cBorder)),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      Container(width: 3, color: t.color),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(11, 11, 9, 11),
                        child: Icon(t.icon, size: 18, color: t.color),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.title,
                                  style: context.tBody(14, w: FontWeight.w600)),
                              const SizedBox(height: 1),
                              Text(t.subtitle,
                                  style: context.tBody(12, color: context.cInk2)),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 11),
                        child: Icon(Icons.chevron_right,
                            size: 18, color: context.cInk3),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
