import 'package:flutter/material.dart';

import '../../providers/app_state.dart';
import '../../services/maintenance.dart';
import '../../utils/design_constants.dart';
import '../../utils/theme_ctx.dart';
import '../add_truck.dart';
import '../depot/depot_page.dart' show ShellNav;
import '../models/driver_document.dart';

/// Une chose à traiter, avec l'endroit où la traiter.
class Todo {
  final IconData icon;
  final Color color;
  final String title, subtitle, destination;
  final int tab;
  const Todo(this.icon, this.color, this.title, this.subtitle,
      this.destination, this.tab);
}

String _km(double v) {
  final digits = v.abs().toStringAsFixed(0);
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write('\u202F');
    out.write(digits[i]);
  }
  return out.toString();
}

/// Ce qui demande une action aujourd'hui, avec l'endroit où la faire.
List<Todo> buildTodos(AppState state) {
  final todos = <Todo>[];

  for (final t in state.trucks) {
    if (t.truckStatus == TruckStatus.enPanne ||
        t.truckStatus == TruckStatus.enReparation ||
        t.truckStatus == TruckStatus.hs) {
      todos.add(Todo(Icons.build_circle_outlined, DC.error,
          '${t.plate} immobilisé', truckStatusLabel(t.truckStatus), 'gestion', 2));
    }
  }
  for (final t in state.trucks) {
    if (t.truckStatus == TruckStatus.vendu) continue;
    if (t.ctStatus >= 2) {
      todos.add(Todo(Icons.rule_folder_outlined,
          t.ctStatus == 4 ? DC.error : DC.warning,
          'Contrôle technique ${t.plate}',
          t.ctStatus == 4 ? 'Expiré — à refaire' : 'Échéance proche',
          'gestion', 2));
    }
    if (t.insuranceStatus >= 2) {
      todos.add(Todo(Icons.shield_outlined,
          t.insuranceStatus == 3 ? DC.error : DC.warning,
          'Assurance ${t.plate}',
          t.insuranceStatus == 3 ? 'Expirée' : 'Expire sous 30 jours',
          'gestion', 2));
    }
  }
  for (final st in Maintenance.dueSoon(state)) {
    todos.add(Todo(Icons.oil_barrel_outlined,
        st.overdue ? DC.error : DC.warning,
        'Entretien ${st.truck.plate}',
        st.overdue
            ? 'Dépassé de ${_km(-st.remaining)} km'
            : 'Dans ${_km(st.remaining)} km',
        'gestion', 2));
  }
  final now = DateTime.now();
  for (final a in state.absencesOn(now)) {
    final plate = state.getAssignment(a.driverName)?.truckPlate;
    if (a.replacementName == null && plate != null) {
      todos.add(Todo(Icons.person_off_outlined, DC.error,
          '$plate sans chauffeur aujourd’hui',
          '${a.driverName} absent — choisir un remplaçant', 'gestion', 0));
    }
  }
  for (final doc in state.alertDocuments) {
    todos.add(Todo(Icons.badge_outlined, DC.error,
        'Document de ${doc.driverName}', documentTypeLabel(doc.type), 'gestion', 1));
  }
  final msgs = state.unreadManagerMessages;
  if (msgs > 0) {
    todos.add(Todo(Icons.chat_bubble_outline, DC.primary,
        '$msgs message${msgs > 1 ? "s" : ""} non lu${msgs > 1 ? "s" : ""}',
        'Ouvrir la messagerie', 'messages', 0));
  }
  return todos;
}

class TodoCard extends StatelessWidget {
  final List<Todo> todos;
  final ShellNav onNavigate;
  const TodoCard({super.key, required this.todos, required this.onNavigate});

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

/// Une valeur qui n'est pas un montant : km, jours, €/km.
