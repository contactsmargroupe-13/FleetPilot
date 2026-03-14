import 'package:flutter/material.dart';

import '../store/app_store.dart';
import 'models/candidate.dart';
import 'models/driver.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const _statuses = ['candidature', 'entretien', 'embauché', 'refusé'];

const _statusLabels = {
  'candidature': 'Candidature',
  'entretien': 'Entretien',
  'embauché': 'Embauché',
  'refusé': 'Refusé',
};

const _statusIcons = {
  'candidature': Icons.inbox_outlined,
  'entretien': Icons.record_voice_over_outlined,
  'embauché': Icons.check_circle_outline,
  'refusé': Icons.cancel_outlined,
};

Color _statusColor(String status, {bool dark = false}) {
  switch (status) {
    case 'candidature':
      return dark ? Colors.blue.shade700 : Colors.blue.shade100;
    case 'entretien':
      return dark ? Colors.orange.shade700 : Colors.orange.shade100;
    case 'embauché':
      return dark ? Colors.green.shade700 : Colors.green.shade100;
    case 'refusé':
      return dark ? Colors.grey.shade600 : Colors.grey.shade200;
    default:
      return Colors.grey.shade200;
  }
}

const _licenses = ['B', 'C', 'CE', 'C1', 'D'];

// ── Page principale ───────────────────────────────────────────────────────────

class ManagerRecruitmentPage extends StatefulWidget {
  const ManagerRecruitmentPage({super.key});

  @override
  State<ManagerRecruitmentPage> createState() => _ManagerRecruitmentPageState();
}

class _ManagerRecruitmentPageState extends State<ManagerRecruitmentPage> {
  String? _filterStatus; // null = tous

  List<Candidate> get _filtered {
    final all = List<Candidate>.from(AppStore.candidates)
      ..sort((a, b) => b.applyDate.compareTo(a.applyDate));
    if (_filterStatus == null) return all;
    return all.where((c) => c.status == _filterStatus).toList();
  }

  // ── Stats ─────────────────────────────────────────────────────────────────

  int _count(String status) =>
      AppStore.candidates.where((c) => c.status == status).length;

  // ── Actions ───────────────────────────────────────────────────────────────

  void _openDialog({Candidate? candidate}) {
    showDialog(
      context: context,
      builder: (_) => _CandidateDialog(
        candidate: candidate,
        onSave: (c) {
          setState(() {
            if (candidate == null) {
              AppStore.addCandidate(c);
            } else {
              AppStore.updateCandidate(c.id, c);
            }
          });
        },
      ),
    );
  }

  void _changeStatus(Candidate c, String newStatus) {
    setState(() => AppStore.updateCandidate(c.id, c.copyWith(status: newStatus)));
  }

  void _delete(Candidate c) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce candidat ?'),
        content: Text(c.name),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => AppStore.deleteCandidate(c.id));
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _convertToDriver(Candidate c) {
    final already = AppStore.drivers.any(
      (d) => d.name.toLowerCase() == c.name.toLowerCase(),
    );
    if (already) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${c.name} est déjà dans la liste des chauffeurs.')),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Ajouter comme chauffeur ?'),
        content: Text('${c.name} sera ajouté à la liste des chauffeurs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              AppStore.addDriver(
                Driver(name: c.name, fixedSalary: 0, bonus: 0),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${c.name} ajouté comme chauffeur.')),
              );
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openDialog(),
        child: const Icon(Icons.person_add_outlined),
      ),
      body: Column(
        children: [
          // ── Stats pipeline ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: _statuses.map((s) {
                final count = _count(s);
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(
                      () => _filterStatus = _filterStatus == s ? null : s,
                    ),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _filterStatus == s
                            ? _statusColor(s, dark: true)
                            : _statusColor(s),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '$count',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _filterStatus == s
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                          Text(
                            _statusLabels[s]!,
                            style: TextStyle(
                              fontSize: 10,
                              color: _filterStatus == s
                                  ? Colors.white70
                                  : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── Filtre label ─────────────────────────────────────────────
          if (_filterStatus != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Filtre : ${_statusLabels[_filterStatus]}',
                    style: const TextStyle(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _filterStatus = null),
                    child: const Text('Effacer'),
                  ),
                ],
              ),
            ),

          // ── Liste ────────────────────────────────────────────────────
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun candidat.\nAppuie sur + pour en ajouter.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) =>
                        _CandidateCard(
                          candidate: filtered[i],
                          onEdit: () => _openDialog(candidate: filtered[i]),
                          onDelete: () => _delete(filtered[i]),
                          onStatusChange: (s) =>
                              _changeStatus(filtered[i], s),
                          onConvert: () => _convertToDriver(filtered[i]),
                        ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Card candidat ─────────────────────────────────────────────────────────────

class _CandidateCard extends StatelessWidget {
  final Candidate candidate;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<String> onStatusChange;
  final VoidCallback onConvert;

  const _CandidateCard({
    required this.candidate,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
    required this.onConvert,
  });

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final c = candidate;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne nom + statut
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(c.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _statusIcons[c.status],
                        size: 13,
                        color: _statusColor(c.status, dark: true),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _statusLabels[c.status]!,
                        style: TextStyle(
                          fontSize: 12,
                          color: _statusColor(c.status, dark: true),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Infos contact
            if (c.phone != null)
              Text('${Icons.phone} ${c.phone}',
                  style: const TextStyle(fontSize: 13)),
            if (c.email != null)
              Text(c.email!, style: const TextStyle(fontSize: 13)),

            // Date candidature
            Text(
              'Candidature : ${_fmtDate(c.applyDate)}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),

            // Permis + FIMO/FCO
            if (c.licenseTypes.isNotEmpty || c.hasFimo || c.hasFco) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  ...c.licenseTypes.map(
                    (l) => Chip(
                      label: Text('Permis $l'),
                      labelStyle: const TextStyle(fontSize: 11),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                  if (c.hasFimo)
                    const Chip(
                      label: Text('FIMO'),
                      labelStyle: TextStyle(fontSize: 11),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                  if (c.hasFco)
                    const Chip(
                      label: Text('FCO'),
                      labelStyle: TextStyle(fontSize: 11),
                      padding: EdgeInsets.zero,
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],

            // Note
            if (c.note != null && c.note!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                c.note!,
                style:
                    const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // Actions
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Avancer statut
                if (c.status == 'candidature')
                  _ActionChip(
                    label: '→ Entretien',
                    color: Colors.orange,
                    onTap: () => onStatusChange('entretien'),
                  ),
                if (c.status == 'entretien') ...[
                  _ActionChip(
                    label: '→ Embauché',
                    color: Colors.green,
                    onTap: () => onStatusChange('embauché'),
                  ),
                  _ActionChip(
                    label: '→ Refusé',
                    color: Colors.grey,
                    onTap: () => onStatusChange('refusé'),
                  ),
                ],
                if (c.status == 'candidature' || c.status == 'entretien')
                  _ActionChip(
                    label: '→ Refusé',
                    color: Colors.grey,
                    onTap: () => onStatusChange('refusé'),
                  ),

                // Convertir en chauffeur
                if (c.status == 'embauché')
                  _ActionChip(
                    label: 'Ajouter chauffeur',
                    color: Colors.blue,
                    icon: Icons.person_add_outlined,
                    onTap: onConvert,
                  ),

                // Modifier
                _ActionChip(
                  label: 'Modifier',
                  color: Colors.indigo,
                  icon: Icons.edit_outlined,
                  onTap: onEdit,
                ),

                // Supprimer
                _ActionChip(
                  label: 'Supprimer',
                  color: Colors.red,
                  icon: Icons.delete_outline,
                  onTap: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData? icon;
  final VoidCallback onTap;

  const _ActionChip({
    required this.label,
    required this.color,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(20),
          color: color.withValues(alpha: 0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
            ],
            Text(label, style: TextStyle(fontSize: 12, color: color)),
          ],
        ),
      ),
    );
  }
}

// ── Dialog ajout / modification ───────────────────────────────────────────────

class _CandidateDialog extends StatefulWidget {
  final Candidate? candidate;
  final ValueChanged<Candidate> onSave;

  const _CandidateDialog({this.candidate, required this.onSave});

  @override
  State<_CandidateDialog> createState() => _CandidateDialogState();
}

class _CandidateDialogState extends State<_CandidateDialog> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _status = 'candidature';
  DateTime _applyDate = DateTime.now();
  final Set<String> _licenses = {};
  bool _hasFimo = false;
  bool _hasFco = false;

  @override
  void initState() {
    super.initState();
    final c = widget.candidate;
    if (c != null) {
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone ?? '';
      _emailCtrl.text = c.email ?? '';
      _noteCtrl.text = c.note ?? '';
      _status = c.status;
      _applyDate = c.applyDate;
      _licenses.addAll(c.licenseTypes);
      _hasFimo = c.hasFimo;
      _hasFco = c.hasFco;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _applyDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _applyDate = picked);
  }

  void _save() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nom obligatoire')),
      );
      return;
    }

    final c = Candidate(
      id: widget.candidate?.id ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      phone:
          _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      email:
          _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      applyDate: _applyDate,
      status: _status,
      licenseTypes: _licenses.toList()..sort(),
      hasFimo: _hasFimo,
      hasFco: _hasFco,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
    );

    widget.onSave(c);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.candidate != null;

    return AlertDialog(
      title: Text(isEdit ? 'Modifier le candidat' : 'Nouveau candidat'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),

              // Date candidature
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 16),
                label: Text('Candidature : ${_fmtDate(_applyDate)}'),
              ),
              const SizedBox(height: 10),

              // Statut
              DropdownButtonFormField<String>(
                value: _status,
                decoration: const InputDecoration(
                  labelText: 'Statut',
                  border: OutlineInputBorder(),
                ),
                items: _statuses
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(_statusLabels[s]!),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _status = v!),
              ),
              const SizedBox(height: 12),

              // Permis
              const Text('Permis',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: _licenses
                    .map((l) => FilterChip(
                          label: Text(l),
                          selected: true,
                          onSelected: (_) =>
                              setState(() => _licenses.remove(l)),
                        ))
                    .toList(),
              ),
              Wrap(
                spacing: 6,
                children: _licenses
                    .toSet()
                    .difference(_licenses)
                    .isEmpty
                    ? _licenses.isEmpty
                        ? _licenseChips()
                        : _licenseChips()
                    : [],
              ),
              _LicenseSelector(
                selected: _licenses,
                onChanged: (l, val) => setState(
                  () => val ? _licenses.add(l) : _licenses.remove(l),
                ),
              ),
              const SizedBox(height: 10),

              // FIMO / FCO
              CheckboxListTile(
                value: _hasFimo,
                title: const Text('FIMO'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _hasFimo = v ?? false),
              ),
              CheckboxListTile(
                value: _hasFco,
                title: const Text('FCO'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _hasFco = v ?? false),
              ),
              const SizedBox(height: 6),

              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  border: OutlineInputBorder(),
                ),
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
          onPressed: _save,
          child: Text(isEdit ? 'Mettre à jour' : 'Ajouter'),
        ),
      ],
    );
  }

  List<Widget> _licenseChips() => _licenses
      .isEmpty
      ? _licenses.toList().map((_) => const SizedBox.shrink()).toList()
      : [];
}

class _LicenseSelector extends StatelessWidget {
  final Set<String> selected;
  final void Function(String license, bool selected) onChanged;

  const _LicenseSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: _licenses
          .map((l) => FilterChip(
                label: Text(l),
                selected: selected.contains(l),
                onSelected: (v) => onChanged(l, v),
              ))
          .toList(),
    );
  }
}
