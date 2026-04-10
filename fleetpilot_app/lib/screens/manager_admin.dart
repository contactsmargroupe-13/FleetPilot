import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/page_help.dart';
import '../utils/shared_widgets.dart';
import 'models/admin_document.dart';

class ManagerAdminPage extends ConsumerStatefulWidget {
  const ManagerAdminPage({super.key});

  @override
  ConsumerState<ManagerAdminPage> createState() => _ManagerAdminPageState();
}

class _ManagerAdminPageState extends ConsumerState<ManagerAdminPage> {
  AdminDocCategory? _categoryFilter;

  static const _orderedCategories = [
    AdminDocCategory.contratChauffeur,
    AdminDocCategory.contratLocation,
    AdminDocCategory.fichePaie,
    AdminDocCategory.assurance,
    AdminDocCategory.facturePrestataire,
    AdminDocCategory.other,
  ];

  List<AdminDocument> get _filtered {
    final docs = [...ref.read(appStateProvider).adminDocuments];
    if (_categoryFilter != null) {
      return docs.where((d) => d.category == _categoryFilter).toList();
    }
    return docs;
  }

  // ── Ajout document ────────────────────────────────────────────────────────

  Future<void> _openAddDialog([AdminDocument? existing]) async {
    final result = await showDialog<AdminDocument>(
      context: context,
      builder: (_) => _AdminDocDialog(document: existing),
    );
    if (result == null) return;
    setState(() {
      if (existing == null) {
        ref.read(appStateProvider).addAdminDocument(result);
      } else {
        ref.read(appStateProvider).updateAdminDocument(existing.id, result);
      }
    });
  }

  Future<void> _deleteDoc(AdminDocument doc) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le document ?'),
        content: Text(doc.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    // Supprimer le fichier physique si présent
    if (doc.filePath != null) {
      try {
        final file = File(doc.filePath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    final removedDoc = doc;
    setState(() => ref.read(appStateProvider).deleteAdminDocument(doc.id));
    if (mounted) {
      showUndoSnackBar(context, 'Document supprimé', () {
        setState(() => ref.read(appStateProvider).addAdminDocument(removedDoc));
      });
    }
  }

  // ── Export JSON ──────────────────────────────────────────────────────────
  Future<void> _exportDocuments() async {
    final docs = ref.read(appStateProvider).adminDocuments;
    if (docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun document à exporter.')),
        );
      }
      return;
    }

    final jsonList = docs.map((d) => d.toJson()).toList();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(jsonList);

    final dir = await getTemporaryDirectory();
    final now = DateTime.now();
    final fileName = 'fleetpilot_docs_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.json';
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr);

    // Collecter les fichiers joints existants
    final files = <XFile>[XFile(file.path)];
    for (final doc in docs) {
      if (doc.filePath != null) {
        final f = File(doc.filePath!);
        if (await f.exists()) {
          files.add(XFile(doc.filePath!, name: doc.fileName));
        }
      }
    }

    await SharePlus.instance.share(
      ShareParams(
        files: files,
        subject: 'Export documents FleetPilote',
      ),
    );
  }

  // ── Import JSON ──────────────────────────────────────────────────────────
  Future<void> _importDocuments() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;

    try {
      final content = await File(result.files.first.path!).readAsString();
      final List<dynamic> jsonList = jsonDecode(content) as List<dynamic>;

      final existing = ref.read(appStateProvider).adminDocuments.map((d) => d.id).toSet();
      int imported = 0;
      int skipped = 0;

      for (final item in jsonList) {
        final doc = AdminDocument.fromJson(item as Map<String, dynamic>);
        if (existing.contains(doc.id)) {
          skipped++;
        } else {
          ref.read(appStateProvider).addAdminDocument(doc);
          imported++;
        }
      }

      setState(() {});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$imported document(s) importé(s)${skipped > 0 ? ', $skipped doublon(s) ignoré(s)' : ''}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur d\'import : $e')),
        );
      }
    }
  }

  // ── Partage fichier individuel ──────────────────────────────────────────
  Future<void> _shareDoc(AdminDocument doc) async {
    if (doc.filePath != null) {
      final f = File(doc.filePath!);
      if (await f.exists()) {
        await SharePlus.instance.share(
          ShareParams(
            files: [XFile(doc.filePath!, name: doc.fileName)],
            subject: doc.title,
          ),
        );
        return;
      }
    }
    // Pas de fichier → partager les infos texte
    final lines = <String>[
      doc.title,
      'Catégorie : ${adminDocCategoryLabel(doc.category)}',
      'Date : ${_fmtDate(doc.date)}',
      if (doc.linkedDriverName != null) 'Chauffeur : ${doc.linkedDriverName}',
      if (doc.linkedTruckPlate != null) 'Camion : ${doc.linkedTruckPlate}',
      if (doc.note != null && doc.note!.isNotEmpty) 'Note : ${doc.note}',
    ];
    await SharePlus.instance.share(
      ShareParams(text: lines.join('\n'), subject: doc.title),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final docs = _filtered;

    // Grouper par catégorie
    final Map<AdminDocCategory, List<AdminDocument>> grouped = {};
    for (final doc in docs) {
      grouped.putIfAbsent(doc.category, () => []).add(doc);
    }
    // Trier chaque groupe par date décroissante
    for (final list in grouped.values) {
      list.sort((a, b) => b.date.compareTo(a.date));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administratif'),
        actions: [
          helpButton(context, 'Administratif',
            'Stockez et classez vos documents administratifs.\n\n'
            '• Contrats chauffeurs, fiches de paie, assurances\n'
            '• Factures prestataires, contrats de location\n'
            '• Filtrez par catégorie pour retrouver rapidement'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Row(
            children: [
              const Expanded(
                child: Text('Administratif',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              IconButton(
                icon: const Icon(Icons.file_download_outlined),
                tooltip: 'Importer (JSON)',
                onPressed: _importDocuments,
              ),
              IconButton(
                icon: const Icon(Icons.ios_share_outlined),
                tooltip: 'Exporter tout',
                onPressed: _exportDocuments,
              ),
              Text('${docs.length} doc(s)',
                  style: const TextStyle(color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),

          // Filtre catégorie
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _FilterChip(
                  label: 'Tous',
                  selected: _categoryFilter == null,
                  onTap: () =>
                      setState(() => _categoryFilter = null),
                ),
                const SizedBox(width: 8),
                ..._orderedCategories.map((cat) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: adminDocCategoryLabel(cat),
                        selected: _categoryFilter == cat,
                        onTap: () =>
                            setState(() => _categoryFilter = cat),
                      ),
                    )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (docs.isEmpty)
            const DCEmptyState(
              icon: Icons.folder_open_outlined,
              title: 'Aucun document.',
              subtitle: 'Ajoutez des contrats, fiches de paie, assurances…',
            )
          else
            for (final cat in _orderedCategories)
              if (grouped.containsKey(cat)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(_categoryIcon(cat),
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        adminDocCategoryLabel(cat),
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey),
                      ),
                      const SizedBox(width: 8),
                      Text('(${grouped[cat]!.length})',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                ...grouped[cat]!.map((doc) => _DocCard(
                      doc: doc,
                      onEdit: () => _openAddDialog(doc),
                      onDelete: () => _deleteDoc(doc),
                      onShare: () => _shareDoc(doc),
                    )),
                const SizedBox(height: 8),
              ],

          const SizedBox(height: 80),
        ],
      ),
    );
  }

  IconData _categoryIcon(AdminDocCategory cat) {
    switch (cat) {
      case AdminDocCategory.contratChauffeur:
        return Icons.person_outline;
      case AdminDocCategory.contratLocation:
        return Icons.local_shipping_outlined;
      case AdminDocCategory.fichePaie:
        return Icons.payments_outlined;
      case AdminDocCategory.assurance:
        return Icons.shield_outlined;
      case AdminDocCategory.facturePrestataire:
        return Icons.receipt_long_outlined;
      case AdminDocCategory.other:
        return Icons.folder_outlined;
    }
  }
}

// ── Carte document ────────────────────────────────────────────────────────────

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
    required this.onShare,
  });

  final AdminDocument doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onShare;

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final hasFile = doc.filePath != null && doc.fileName != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    doc.title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  onPressed: onShare,
                  tooltip: 'Partager',
                ),
                IconButton(
                  icon:
                      const Icon(Icons.edit_outlined, size: 18),
                  onPressed: onEdit,
                  tooltip: 'Modifier',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: Colors.red),
                  onPressed: onDelete,
                  tooltip: 'Supprimer',
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _infoRow(Icons.calendar_today_outlined, _fmt(doc.date)),
                if (doc.linkedDriverName != null)
                  _infoRow(Icons.person_outline, doc.linkedDriverName!),
                if (doc.linkedTruckPlate != null)
                  _infoRow(Icons.local_shipping_outlined,
                      doc.linkedTruckPlate!),
                if (hasFile)
                  _infoRow(Icons.attach_file, doc.fileName!,
                      color: Colors.blue),
                if (!hasFile)
                  _infoRow(Icons.attach_file_outlined, 'Sans fichier',
                      color: Colors.grey),
              ],
            ),
            if (doc.note != null && doc.note!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(doc.note!,
                  style: const TextStyle(
                      fontSize: 12, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, {Color? color}) =>
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? Colors.grey),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color ?? Colors.grey)),
        ],
      );
}

// ── Dialog ajout / modification ───────────────────────────────────────────────

class _AdminDocDialog extends ConsumerStatefulWidget {
  const _AdminDocDialog({this.document});
  final AdminDocument? document;

  @override
  ConsumerState<_AdminDocDialog> createState() => _AdminDocDialogState();
}

class _AdminDocDialogState extends ConsumerState<_AdminDocDialog> {
  final _titleCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late AdminDocCategory _category;
  String? _linkedDriver;
  String? _linkedTruck;
  DateTime _date = DateTime.now();

  String? _filePath;
  String? _fileName;
  bool _pickingFile = false;

  @override
  void initState() {
    super.initState();
    final d = widget.document;
    _titleCtrl.text = d?.title ?? '';
    _noteCtrl.text = d?.note ?? '';
    _category = d?.category ?? AdminDocCategory.contratChauffeur;
    _linkedDriver = d?.linkedDriverName;
    _linkedTruck = d?.linkedTruckPlate;
    _date = d?.date ?? DateTime.now();
    _filePath = d?.filePath;
    _fileName = d?.fileName;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickFile() async {
    setState(() => _pickingFile = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx', 'xlsx'],
        withData: false,
        withReadStream: false,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _pickingFile = false);
        return;
      }

      final picked = result.files.first;
      if (picked.path == null) {
        setState(() => _pickingFile = false);
        return;
      }

      // Copier dans le répertoire documents de l'app
      final appDir = await getApplicationDocumentsDirectory();
      final adminDir = Directory('${appDir.path}/fleetpilot_admin');
      await adminDir.create(recursive: true);

      final ext = picked.name.split('.').last;
      final destName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      final destPath = '${adminDir.path}/$destName';

      await File(picked.path!).copy(destPath);

      setState(() {
        _filePath = destPath;
        _fileName = picked.name;
        _pickingFile = false;
      });
    } catch (e) {
      setState(() => _pickingFile = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  void _removeFile() {
    setState(() {
      _filePath = null;
      _fileName = null;
    });
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le titre est obligatoire')),
      );
      return;
    }

    Navigator.pop(
      context,
      AdminDocument(
        id: widget.document?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: title,
        category: _category,
        date: _date,
        linkedDriverName: _linkedDriver,
        linkedTruckPlate: _linkedTruck,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
        filePath: _filePath,
        fileName: _fileName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final drivers =
        ref.read(appStateProvider).drivers.map((d) => d.name).toList()..sort();
    final trucks =
        ref.read(appStateProvider).trucks.map((t) => t.plate).toList()..sort();

    return Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.document == null
                    ? 'Ajouter un document'
                    : 'Modifier le document',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              // Titre
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Titre *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Catégorie
              DropdownButtonFormField<AdminDocCategory>(
                value: _category,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Catégorie',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: AdminDocCategory.values
                    .map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(adminDocCategoryLabel(c)),
                        ))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _category = v ?? _category),
              ),
              const SizedBox(height: 12),

              // Date
              InkWell(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (d != null) setState(() => _date = d);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(
                        color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date du document',
                              style: TextStyle(
                                  fontSize: 12, color: Colors.grey)),
                          Text(_fmt(_date),
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Chauffeur lié
              DropdownButtonFormField<String>(
                value: _linkedDriver,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Chauffeur lié (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('Aucun')),
                  ...drivers.map((d) => DropdownMenuItem<String>(
                        value: d,
                        child: Text(d),
                      )),
                ],
                onChanged: (v) =>
                    setState(() => _linkedDriver = v),
              ),
              const SizedBox(height: 12),

              // Camion lié
              DropdownButtonFormField<String>(
                value: _linkedTruck,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Camion lié (optionnel)',
                  border: OutlineInputBorder(),
                  prefixIcon:
                      Icon(Icons.local_shipping_outlined),
                ),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('Aucun')),
                  ...trucks.map((t) => DropdownMenuItem<String>(
                        value: t,
                        child: Text(t),
                      )),
                ],
                onChanged: (v) =>
                    setState(() => _linkedTruck = v),
              ),
              const SizedBox(height: 12),

              // Note
              TextField(
                controller: _noteCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note (optionnel)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Fichier
              const Text('Fichier joint',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),

              if (_fileName != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color:
                            Colors.green.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.attach_file,
                          color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _fileName!,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: Colors.red),
                        onPressed: _removeFile,
                        tooltip: 'Retirer le fichier',
                      ),
                    ],
                  ),
                )
              else
                OutlinedButton.icon(
                  onPressed: _pickingFile ? null : _pickFile,
                  icon: _pickingFile
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_file_outlined),
                  label: Text(_pickingFile
                      ? 'Import en cours…'
                      : 'Choisir un fichier'),
                ),

              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _save,
                    child: const Text('Enregistrer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Chip filtre ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context)
                  .colorScheme
                  .surface
                  .withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}
