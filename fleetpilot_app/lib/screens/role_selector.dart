import 'package:flutter/material.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import 'driver_home.dart';
import 'manager_dashboard.dart';
import 'onboarding_page.dart';
import 'models/candidate.dart';
import 'models/user_access.dart';

class RoleSelectorPage extends ConsumerWidget {
  const RoleSelectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accesses = ref.watch(appStateProvider).userAccesses;

    return Scaffold(
      backgroundColor: DC.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Bouton aide en haut à droite
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  onPressed: () => _showHelp(context),
                  icon: const Icon(Icons.help_outline_rounded),
                  tooltip: 'Guide d\'utilisation',
                  color: DC.textSecondary,
                ),
              ),
              const SizedBox(height: 16),

              // Logo / titre
              Center(child: DC.logo(size: 36)),
              const SizedBox(height: 8),
              Text(
                'Gestion de flotte transport',
                textAlign: TextAlign.center,
                style: DC.body(14, color: DC.textSecondary),
              ),

              const SizedBox(height: 64),

              Text(
                'Choisir votre espace',
                textAlign: TextAlign.center,
                style: DC.body(16, color: DC.textSecondary),
              ),
              const SizedBox(height: 24),

              // Bouton Chauffeur
              _RoleCard(
                icon: Icons.local_shipping_outlined,
                label: 'Chauffeur',
                subtitle: 'Saisie de tournée',
                color: DC.success,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DriverHomePage()),
                ),
              ),

              const SizedBox(height: 16),

              // Bouton Manager
              _RoleCard(
                icon: Icons.dashboard_outlined,
                label: 'Manager',
                subtitle: 'Tableau de bord & gestion',
                color: DC.primary,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ManagerShell()),
                ),
              ),

              const SizedBox(height: 16),

              // Accès supplémentaires (comptable, etc.)
              ...accesses.map((access) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _RoleCard(
                      icon: access.role == AccessRole.comptable
                          ? Icons.account_balance_outlined
                          : Icons.dashboard_outlined,
                      label: access.name,
                      subtitle: accessRoleLabel(access.role),
                      color: access.role == AccessRole.comptable
                          ? Colors.purple
                          : DC.primary,
                      onTap: () => _onExtraRoleTap(context, ref, access),
                    ),
                  )),

              // Bouton Postuler
              _RoleCard(
                icon: Icons.work_outline,
                label: 'Postuler',
                subtitle: 'Déposer une candidature',
                color: DC.warning,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const _PublicCandidatePage()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHelp(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OnboardingPage(
          onDone: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _onExtraRoleTap(
      BuildContext context, WidgetRef ref, UserAccess access) {
    String pin = '';
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (ctx, set) {
          return Dialog(
            backgroundColor: DC.surface2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(DC.rCard),
              side: const BorderSide(color: DC.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_outline,
                        color: Colors.purple, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(access.name, style: DC.title(20)),
                  const SizedBox(height: 4),
                  Text('Entrez le code PIN',
                      style: DC.body(13, color: DC.textSecondary)),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? Colors.purple : Colors.transparent,
                          border: Border.all(
                            color: filled ? Colors.purple : DC.textSecondary,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: DC.body(12, color: DC.error),
                        textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 28),
                  _NumPad(
                    onKey: (digit) {
                      set(() {
                        error = null;
                        if (pin.length < 4) pin += digit;
                        if (pin.length == 4) {
                          final hash = sha256
                              .convert(utf8.encode(pin))
                              .toString();
                          if (hash == access.pinHash) {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      ManagerShell(role: access.role)),
                            );
                          } else {
                            pin = '';
                            error = 'Code incorrect';
                          }
                        }
                      });
                    },
                    onDelete: () {
                      set(() {
                        error = null;
                        if (pin.isNotEmpty) {
                          pin = pin.substring(0, pin.length - 1);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text('Annuler',
                        style: DC.body(14, color: DC.textSecondary)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

}

// ── Carte de rôle ────────────────────────────────────────────────────────────

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: DC.surface,
          borderRadius: BorderRadius.circular(DC.rCard),
          border: Border.all(color: DC.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: DC.title(18)),
                Text(subtitle, style: DC.body(13, color: DC.textSecondary)),
              ],
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, color: DC.textSecondary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Page candidature publique ─────────────────────────────────────────────────

class _PublicCandidatePage extends ConsumerStatefulWidget {
  const _PublicCandidatePage();

  @override
  ConsumerState<_PublicCandidatePage> createState() => _PublicCandidatePageState();
}

class _PublicCandidatePageState extends ConsumerState<_PublicCandidatePage> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();

  // Permis
  bool _hasB = false;
  bool _hasC = false;
  bool _hasCE = false;

  // Qualifications
  bool _hasFimo = false;
  bool _hasFco = false;
  bool _hasAdr = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final fullName = '$firstName $lastName'.trim();

    final List<String> licenses = [];
    if (_hasB) licenses.add('B');
    if (_hasC) licenses.add('C');
    if (_hasCE) licenses.add('CE');

    // ADR est une qualification, on l'ajoute dans la note si cochée
    final List<String> qualifs = [];
    if (_hasFimo) qualifs.add('FIMO');
    if (_hasFco) qualifs.add('FCO');
    if (_hasAdr) qualifs.add('ADR');

    final note = [
      if (_messageCtrl.text.trim().isNotEmpty) _messageCtrl.text.trim(),
      if (qualifs.isNotEmpty) 'Qualifications : ${qualifs.join(', ')}',
    ].join('\n\n');

    final candidate = Candidate(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: fullName,
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      applyDate: DateTime.now(),
      status: 'candidature',
      licenseTypes: licenses,
      hasFimo: _hasFimo,
      hasFco: _hasFco,
      note: note.isEmpty ? null : note,
    );

    ref.read(appStateProvider).addCandidate(candidate);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Candidature envoyée !'),
        content: Text(
          'Merci $firstName, votre candidature a bien été enregistrée. '
          'Nous vous contacterons dans les meilleurs délais.',
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop(); // ferme dialog
              Navigator.of(context).pop(); // retour role selector
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Déposer une candidature'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Identité ──────────────────────────────────────────────────
            _sectionTitle('Vos coordonnées'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Prénom *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Obligatoire' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastNameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        (v ?? '').trim().isEmpty ? 'Obligatoire' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message / motivation',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Permis ────────────────────────────────────────────────────
            _sectionTitle('Permis de conduire'),
            Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Permis B'),
                    value: _hasB,
                    onChanged: (v) => setState(() => _hasB = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Permis C'),
                    value: _hasC,
                    onChanged: (v) => setState(() => _hasC = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('Permis CE'),
                    value: _hasCE,
                    onChanged: (v) => setState(() => _hasCE = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Qualifications ────────────────────────────────────────────
            _sectionTitle('Qualifications'),
            Card(
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('FIMO'),
                    subtitle: const Text(
                        'Formation initiale minimale obligatoire'),
                    value: _hasFimo,
                    onChanged: (v) =>
                        setState(() => _hasFimo = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('FCO'),
                    subtitle:
                        const Text('Formation continue obligatoire'),
                    value: _hasFco,
                    onChanged: (v) =>
                        setState(() => _hasFco = v ?? false),
                  ),
                  CheckboxListTile(
                    title: const Text('ADR'),
                    subtitle:
                        const Text('Transport de matières dangereuses'),
                    value: _hasAdr,
                    onChanged: (v) =>
                        setState(() => _hasAdr = v ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send_outlined),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text('Envoyer ma candidature'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          title,
          style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700),
        ),
      );
}

// ── Pavé numérique (accès supplémentaires) ───────────────────────────────────

class _NumPad extends StatelessWidget {
  const _NumPad({required this.onKey, required this.onDelete});
  final void Function(String) onKey;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final row in [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((k) {
              if (k.isEmpty) return const SizedBox(width: 72, height: 56);
              return _NumKey(
                label: k,
                onTap: () => k == '⌫' ? onDelete() : onKey(k),
                isDelete: k == '⌫',
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({
    required this.label,
    required this.onTap,
    this.isDelete = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool isDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 56,
        margin: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDelete ? Colors.transparent : DC.surface,
          borderRadius: BorderRadius.circular(12),
          border: isDelete ? null : Border.all(color: DC.border),
        ),
        alignment: Alignment.center,
        child: isDelete
            ? Icon(Icons.backspace_outlined,
                color: DC.textSecondary, size: 20)
            : Text(label, style: DC.title(22)),
      ),
    );
  }
}
