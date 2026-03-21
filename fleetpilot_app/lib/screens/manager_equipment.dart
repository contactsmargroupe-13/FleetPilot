import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'models/equipment.dart';

class ManagerEquipmentPage extends ConsumerStatefulWidget {
  const ManagerEquipmentPage({super.key});

  @override
  ConsumerState<ManagerEquipmentPage> createState() =>
      _ManagerEquipmentPageState();
}

class _ManagerEquipmentPageState extends ConsumerState<ManagerEquipmentPage> {
  @override
  Widget build(BuildContext context) {
    final items = [...ref.watch(appStateProvider).equipment]
      ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Matériel')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.build_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  const Text('Aucun matériel enregistré.',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length + 1,
              itemBuilder: (_, i) {
                if (i == items.length) return const SizedBox(height: 80);
                return _equipmentCard(items[i]);
              },
            ),
    );
  }

  Widget _equipmentCard(Equipment e) {
    final color = e.isFullyAmortized ? Colors.green : Colors.blue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.build_outlined, color: color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                      Row(
                        children: [
                          Text(equipmentCategoryLabel(e.category),
                              style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          if (e.assignedTruckPlate != null) ...[
                            const SizedBox(width: 6),
                            Icon(Icons.local_shipping, size: 12, color: Colors.grey.shade500),
                            const SizedBox(width: 3),
                            Text(e.assignedTruckPlate!,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Text('${e.currentValue.toStringAsFixed(0)} €',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _info('Achat', '${e.purchasePrice.toStringAsFixed(0)} €'),
                _info('Mensuel', '${e.monthlyAmort.toStringAsFixed(0)} €'),
                _info('Durée', '${e.amortMonths} mois'),
                _info('Restant', '${e.monthsRemaining} mois'),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: e.amortPercent,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text('${(e.amortPercent * 100).toStringAsFixed(0)}% amorti',
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
                if (e.note != null && e.note!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('• ${e.note}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => _openForm(e),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                  onPressed: () => _confirmDelete(e),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  void _openForm(Equipment? existing) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final priceCtrl = TextEditingController(
        text: existing != null ? existing.purchasePrice.toStringAsFixed(0) : '');
    final amortCtrl = TextEditingController(
        text: existing != null ? existing.amortMonths.toString() : '');
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var category = existing?.category ?? EquipmentCategory.autre;
    var purchaseDate = existing?.purchaseDate ?? DateTime.now();
    String? assignedTruck = existing?.assignedTruckPlate;
    final trucks = ref.read(appStateProvider).trucks;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(isEdit ? 'Modifier ${existing.name}' : 'Ajouter du matériel'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.build_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EquipmentCategory>(
                    value: category,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(),
                    ),
                    items: EquipmentCategory.values
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(equipmentCategoryLabel(c)),
                            ))
                        .toList(),
                    onChanged: (v) => setDialog(() => category = v ?? category),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Prix d\'achat (€) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.euro),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amortCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Durée amortissement (mois) *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: purchaseDate,
                        firstDate: DateTime(2010),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) setDialog(() => purchaseDate = picked);
                    },
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(
                        'Date d\'achat : ${purchaseDate.day.toString().padLeft(2, '0')}/${purchaseDate.month.toString().padLeft(2, '0')}/${purchaseDate.year}'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: assignedTruck,
                    decoration: const InputDecoration(
                      labelText: 'Affecté au camion',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.local_shipping_outlined),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('— Non affecté —'),
                      ),
                      ...trucks.map((t) => DropdownMenuItem(
                            value: t.plate,
                            child: Text('${t.plate} • ${t.model}'),
                          )),
                    ],
                    onChanged: (v) => setDialog(() => assignedTruck = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final price = double.tryParse(priceCtrl.text.replaceAll(',', '.').trim());
                final amort = int.tryParse(amortCtrl.text.trim());

                if (name.isEmpty || price == null || price <= 0 || amort == null || amort <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Remplis tous les champs obligatoires')),
                  );
                  return;
                }

                final item = Equipment(
                  id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  name: name,
                  category: category,
                  purchasePrice: price,
                  purchaseDate: purchaseDate,
                  amortMonths: amort,
                  note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                  assignedTruckPlate: assignedTruck,
                );

                setState(() {
                  if (isEdit) {
                    ref.read(appStateProvider).updateEquipment(existing.id, item);
                  } else {
                    ref.read(appStateProvider).addEquipment(item);
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(Equipment e) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer "${e.name}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => ref.read(appStateProvider).deleteEquipment(e.id));
              Navigator.pop(context);
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
