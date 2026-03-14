import 'package:flutter/material.dart';
import 'models/expense.dart';
import '../store/app_store.dart';
import 'add_expense.dart';

class ManagerExpensesPage extends StatefulWidget {
  const ManagerExpensesPage({super.key});

  @override
  State<ManagerExpensesPage> createState() => _ManagerExpensesPageState();
}

class _ManagerExpensesPageState extends State<ManagerExpensesPage> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _truckFilter;
  ExpenseType? _typeFilter;

  static const List<String> _monthNames = [
    'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
    'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
  ];

  String get _monthLabel =>
      '${_monthNames[_selectedMonth.month - 1]} ${_selectedMonth.year}';

  Future<void> _addExpense() async {
    final exp = await Navigator.push<Expense>(
      context,
      MaterialPageRoute(builder: (_) => const AddExpensePage()),
    );
    if (exp != null) {
      setState(() => AppStore.addExpense(exp));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dépense ajoutée')),
      );
    }
  }

  void _deleteExpense(Expense e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer la dépense ?'),
        content: Text(
            '${expenseTypeLabel(e.type)} — ${e.amount.toStringAsFixed(2)} € — ${e.truckPlate}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => AppStore.deleteExpense(e.id));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Dépense supprimée')),
              );
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final trucks =
        AppStore.trucks.map((t) => t.plate).toSet().toList()..sort();

    final filtered = AppStore.expenses.where((e) {
      final sameMonth = e.date.year == _selectedMonth.year &&
          e.date.month == _selectedMonth.month;
      final matchTruck = _truckFilter == null || e.truckPlate == _truckFilter;
      final matchType = _typeFilter == null || e.type == _typeFilter;
      return sameMonth && matchTruck && matchType;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final totalAmount = filtered.fold(0.0, (s, e) => s + e.amount);
    final totalLiters = filtered
        .where((e) => e.liters != null)
        .fold(0.0, (s, e) => s + e.liters!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Row(
            children: [
              const Expanded(
                child: Text('Dépenses',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              FilledButton.icon(
                onPressed: _addExpense,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Filtres
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Navigation mois
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month - 1);
                    }),
                    icon: const Icon(Icons.chevron_left),
                    label: const Text('Mois −1'),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: null,
                    icon: const Icon(Icons.calendar_month, size: 18),
                    label: Text(_monthLabel),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month + 1);
                    }),
                    icon: const Icon(Icons.chevron_right),
                    label: const Text('Mois +1'),
                  ),

                  // Filtre camion
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _truckFilter,
                      decoration: const InputDecoration(
                        labelText: 'Camion',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                            value: null, child: Text('Tous')),
                        ...trucks.map((t) => DropdownMenuItem<String>(
                            value: t, child: Text(t))),
                      ],
                      onChanged: (v) =>
                          setState(() => _truckFilter = v),
                    ),
                  ),

                  // Filtre type
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<ExpenseType>(
                      value: _typeFilter,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<ExpenseType>(
                            value: null, child: Text('Tous')),
                        ...ExpenseType.values.map((t) =>
                            DropdownMenuItem<ExpenseType>(
                                value: t,
                                child: Text(expenseTypeLabel(t)))),
                      ],
                      onChanged: (v) =>
                          setState(() => _typeFilter = v),
                    ),
                  ),

                  OutlinedButton.icon(
                    onPressed: () => setState(() {
                      _truckFilter = null;
                      _typeFilter = null;
                    }),
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Effacer'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Stats
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _statChip(Icons.receipt_long_outlined,
                  '${filtered.length} dépense(s)'),
              _statChip(Icons.euro_outlined,
                  '${totalAmount.toStringAsFixed(2)} €'),
              if (totalLiters > 0)
                _statChip(Icons.local_gas_station_outlined,
                    '${totalLiters.toStringAsFixed(1)} L'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Liste
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('Aucune dépense pour cette période.'))
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = filtered[i];
                    final d = e.date.day.toString().padLeft(2, '0');
                    final m = e.date.month.toString().padLeft(2, '0');
                    return Card(
                      child: ListTile(
                        leading:
                            Icon(_typeIcon(e.type)),
                        title: Text(
                            '${expenseTypeLabel(e.type)} — ${e.amount.toStringAsFixed(2)} €'),
                        subtitle: Text(
                          '${e.truckPlate}'
                          '${e.liters != null ? ' • ${e.liters!.toStringAsFixed(1)} L' : ''}'
                          '${e.note != null ? ' • ${e.note}' : ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$d/$m',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              tooltip: 'Supprimer',
                              onPressed: () => _deleteExpense(e),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _statChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  IconData _typeIcon(ExpenseType type) {
    switch (type) {
      case ExpenseType.fuel:
        return Icons.local_gas_station_outlined;
      case ExpenseType.repair:
        return Icons.build_outlined;
      case ExpenseType.material:
        return Icons.inventory_2_outlined;
      case ExpenseType.other:
        return Icons.receipt_long_outlined;
    }
  }
}
