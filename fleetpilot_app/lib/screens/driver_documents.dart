import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import 'models/driver_document.dart';
import 'models/driver_notification.dart';

class DriverDocumentsPage extends ConsumerStatefulWidget {
  final String driverName;
  const DriverDocumentsPage({super.key, required this.driverName});

  @override
  ConsumerState<DriverDocumentsPage> createState() =>
      _DriverDocumentsPageState();
}

class _DriverDocumentsPageState extends ConsumerState<DriverDocumentsPage> {
  String _filter = 'tous';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final docs = state.documentsForDriver(widget.driverName);
    final notifs = state.notificationsForDriver(widget.driverName);
    final amendes = notifs.where((n) => n.type == DriverNotifType.amende).toList();

    // Regrouper les documents par catégorie
    final Map<String, List<DriverDocument>> grouped = {};
    for (final doc in docs) {
      final cat = documentTypeCategory(doc.type);
      grouped.putIfAbsent(cat, () => []).add(doc);
    }

    // Filtrer les notifications par type
    List<DriverNotification> filteredNotifs;
    if (_filter == 'amendes') {
      filteredNotifs = amendes;
    } else if (_filter == 'fiches') {
      filteredNotifs = notifs
          .where((n) => n.type == DriverNotifType.fichePaie)
          .toList();
    } else if (_filter == 'contrats') {
      filteredNotifs = notifs
          .where((n) => n.type == DriverNotifType.contrat)
          .toList();
    } else {
      filteredNotifs = [];
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Mes documents',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),

        // ── Filtres rapides ──────────────────────────────────────────────
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _filterChip('tous', 'Tous'),
              const SizedBox(width: 8),
              _filterChip('amendes', 'Amendes',
                  count: amendes.length, color: Colors.red),
              const SizedBox(width: 8),
              _filterChip('fiches', 'Fiches de paie',
                  count: notifs
                      .where((n) => n.type == DriverNotifType.fichePaie)
                      .length),
              const SizedBox(width: 8),
              _filterChip('contrats', 'Contrats',
                  count: notifs
                      .where((n) => n.type == DriverNotifType.contrat)
                      .length),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Amendes / Fiches / Contrats (notifications) ──────────────────
        if (_filter != 'tous' && filteredNotifs.isNotEmpty) ...[
          ...filteredNotifs.map((n) => _notifCard(n)),
          const SizedBox(height: 20),
        ],

        if (_filter != 'tous' && filteredNotifs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                _filter == 'amendes'
                    ? 'Aucune amende.'
                    : _filter == 'fiches'
                        ? 'Aucune fiche de paie.'
                        : 'Aucun contrat.',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          ),

        // ── Documents administratifs (permis, FIMO, etc.) ────────────────
        if (_filter == 'tous') ...[
          if (amendes.isNotEmpty) ...[
            _sectionTitle('Amendes', icon: Icons.warning_amber, color: Colors.red),
            ...amendes.map((n) => _notifCard(n)),
            const SizedBox(height: 16),
          ],

          // Documents regroupés par catégorie
          if (docs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'Aucun document enregistré.\nDemande à ton manager d\'ajouter tes documents.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            for (final cat in grouped.keys) ...[
              _sectionTitle(cat),
              ...grouped[cat]!.map((doc) => _documentCard(doc)),
              const SizedBox(height: 12),
            ],

          // Notifications récentes (fiches de paie, contrats)
          if (notifs
              .where((n) =>
                  n.type == DriverNotifType.fichePaie ||
                  n.type == DriverNotifType.contrat)
              .isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle('Fiches de paie & Contrats',
                icon: Icons.description_outlined),
            ...notifs
                .where((n) =>
                    n.type == DriverNotifType.fichePaie ||
                    n.type == DriverNotifType.contrat)
                .take(10)
                .map((n) => _notifCard(n)),
          ],
        ],

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _filterChip(String key, String label, {int count = 0, Color? color}) {
    final selected = _filter == key;
    return FilterChip(
      selected: selected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color ?? Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
      onSelected: (_) => setState(() => _filter = key),
    );
  }

  Widget _sectionTitle(String title,
      {IconData? icon, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
          ],
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _documentCard(DriverDocument doc) {
    final level = doc.alertLevel;
    final Color borderColor;
    final Color bgColor;
    final String? statusLabel;
    final Color? statusColor;

    switch (level) {
      case 'expired':
        borderColor = Colors.red;
        bgColor = Colors.red.withValues(alpha: 0.06);
        statusLabel = 'Expiré';
        statusColor = Colors.red;
        break;
      case 'warning':
        borderColor = Colors.orange;
        bgColor = Colors.orange.withValues(alpha: 0.06);
        statusLabel = 'Expire dans ${doc.daysUntilExpiry}j';
        statusColor = Colors.orange;
        break;
      case 'ok':
        borderColor = Colors.green;
        bgColor = Colors.green.withValues(alpha: 0.04);
        statusLabel = 'Valide';
        statusColor = Colors.green;
        break;
      default:
        borderColor = Colors.black12;
        bgColor = Colors.transparent;
        statusLabel = null;
        statusColor = null;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documentTypeLabel(doc.type),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                if (doc.documentNumber != null)
                  Text('N° ${doc.documentNumber}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (doc.expiryDate != null)
                  Text(
                    'Expiration : ${_fmt(doc.expiryDate!)}',
                    style: const TextStyle(fontSize: 12),
                  ),
              ],
            ),
          ),
          if (statusLabel != null)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor!.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _notifCard(DriverNotification n) {
    final isAmende = n.type == DriverNotifType.amende;
    final color = isAmende ? Colors.red : Colors.blue;
    final icon = isAmende
        ? Icons.warning_amber
        : n.type == DriverNotifType.fichePaie
            ? Icons.receipt_long_outlined
            : Icons.description_outlined;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          n.title,
          style: TextStyle(
            fontWeight: n.read ? FontWeight.w500 : FontWeight.w700,
            fontSize: 14,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n.message != null)
              Text(n.message!, style: const TextStyle(fontSize: 12)),
            Text(
              _fmt(n.date),
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        trailing: isAmende && n.amount != null
            ? Text(
                '${n.amount!.toStringAsFixed(0)} €',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              )
            : n.read
                ? null
                : Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                  ),
        onTap: () {
          if (!n.read) {
            ref.read(appStateProvider).markNotificationRead(n.id);
          }
        },
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
