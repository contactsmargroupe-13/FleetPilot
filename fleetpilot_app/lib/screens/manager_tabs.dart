import 'package:flutter/material.dart';

import '../utils/theme_ctx.dart';
import 'depot/depot_page.dart';
import 'manager_billing.dart';
import 'manager_equipment.dart';
import 'manager_statements.dart';
import 'manager_vehicles.dart';

/// Un sélecteur à deux positions en tête d'onglet : deux vues du même sujet,
/// plutôt que deux onglets de plus.
class _Switch extends StatelessWidget {
  final List<(String, IconData)> options;
  final int index;
  final ValueChanged<int> onChanged;
  final Widget? trailing;
  const _Switch({
    required this.options,
    required this.index,
    required this.onChanged,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 6),
      color: context.cBg,
      child: Row(
        children: [
          SegmentedButton<int>(
            showSelectedIcon: false,
            style: const ButtonStyle(visualDensity: VisualDensity.compact),
            segments: [
              for (var i = 0; i < options.length; i++)
                ButtonSegment(
                  value: i,
                  label: Text(options[i].$1),
                  icon: Icon(options[i].$2, size: 18),
                ),
            ],
            selected: {index},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Camions : la liste pour gérer, le plan de la cour pour voir d'un coup
/// d'œil qui est parti, qui est à l'atelier. Le matériel est rangé ici.
class TrucksTab extends StatefulWidget {
  final ShellNav onNavigate;
  const TrucksTab({super.key, required this.onNavigate});

  @override
  State<TrucksTab> createState() => _TrucksTabState();
}

class _TrucksTabState extends State<TrucksTab> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Switch(
          options: const [
            ('Liste', Icons.view_list_outlined),
            ('Plan', Icons.map_outlined),
          ],
          index: _view,
          onChanged: (i) => setState(() => _view = i),
          trailing: TextButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ManagerEquipmentPage()),
            ),
            icon: const Icon(Icons.handyman_outlined, size: 18),
            label: const Text('Matériel'),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _view,
            children: [
              const ManagerVehiclesPage(),
              DepotPage(onNavigate: widget.onNavigate),
            ],
          ),
        ),
      ],
    );
  }
}

/// Factures : ce que tu envoies aux commissionnaires, puis ce qu'ils t'ont
/// réellement payé. Le même geste mensuel, en deux temps.
class InvoicesTab extends StatefulWidget {
  const InvoicesTab({super.key});

  @override
  State<InvoicesTab> createState() => _InvoicesTabState();
}

class _InvoicesTabState extends State<InvoicesTab> {
  int _view = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Switch(
          options: const [
            ('À facturer', Icons.request_quote_outlined),
            ('Relevés reçus', Icons.receipt_long_outlined),
          ],
          index: _view,
          onChanged: (i) => setState(() => _view = i),
        ),
        Expanded(
          child: IndexedStack(
            index: _view,
            children: const [
              ManagerBillingPage(),
              ManagerStatementsPage(embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}
