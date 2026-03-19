import 'package:flutter/material.dart';

import '../services/company_settings.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import 'driver_home.dart';
import 'manager_dashboard.dart';
import 'models/candidate.dart';

class RoleSelectorPage extends StatelessWidget {
  const RoleSelectorPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DC.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 48),

              // Logo / titre
              Text(
                'FleetPilot',
                textAlign: TextAlign.center,
                style: DC.title(36),
              ),
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
                onTap: () => _onManagerTap(context),
              ),

              const SizedBox(height: 16),

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

  Future<void> _onManagerTap(BuildContext context) async {
    if (!CompanySettings.hasPinSet) {
      // Pas de PIN défini → créer le PIN
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _PinDialog(mode: _PinMode.create),
      );
      return;
    }

    // PIN défini → vérifier
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PinDialog(mode: _PinMode.verify),
    );

    if (ok == true && context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ManagerShell()),
      );
    }
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

// ── Dialog PIN ───────────────────────────────────────────────────────────────

enum _PinMode { create, verify }

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.mode});
  final _PinMode mode;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  String _pin = '';
  String _confirmPin = '';
  bool _confirming = false;
  String? _error;

  void _onKey(String digit) {
    setState(() {
      _error = null;
      if (_confirming) {
        if (_confirmPin.length < 4) _confirmPin += digit;
        if (_confirmPin.length == 4) _validate();
      } else {
        if (_pin.length < 4) _pin += digit;
        if (widget.mode == _PinMode.verify && _pin.length == 4) _validate();
        if (widget.mode == _PinMode.create && _pin.length == 4) {
          _confirming = true;
        }
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      if (_confirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
    });
  }

  Future<void> _validate() async {
    if (widget.mode == _PinMode.verify) {
      if (CompanySettings.checkPin(_pin)) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _pin = '';
          _error = 'Code incorrect, réessayez';
        });
      }
    } else {
      // Création
      if (_pin == _confirmPin) {
        await CompanySettings.saveManagerPin(_pin);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Code PIN manager enregistré')),
          );
          Navigator.of(context).pop();
          // Naviguer directement vers le manager après création
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ManagerShell()),
          );
        }
      } else {
        setState(() {
          _confirmPin = '';
          _confirming = false;
          _pin = '';
          _error = 'Les codes ne correspondent pas, recommencez';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPin = _confirming ? _confirmPin : _pin;

    String title;
    String subtitle;
    if (widget.mode == _PinMode.verify) {
      title = 'Espace Manager';
      subtitle = 'Entrez votre code PIN';
    } else if (_confirming) {
      title = 'Confirmer le code';
      subtitle = 'Saisissez à nouveau le code';
    } else {
      title = 'Créer un code PIN';
      subtitle = 'Protège l\'accès manager (4 chiffres)';
    }

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
            // Icône
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: DC.primary.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline, color: DC.primary, size: 28),
            ),
            const SizedBox(height: 16),

            Text(title, style: DC.title(20)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: DC.body(13, color: DC.textSecondary),
                textAlign: TextAlign.center),

            const SizedBox(height: 28),

            // Indicateurs chiffres
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < currentPin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? DC.primary : Colors.transparent,
                    border: Border.all(
                      color: filled ? DC.primary : DC.textSecondary,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: DC.body(12, color: DC.error),
                textAlign: TextAlign.center,
              ),
            ],

            const SizedBox(height: 28),

            // Pavé numérique
            _NumPad(onKey: _onKey, onDelete: _onDelete),

            const SizedBox(height: 16),

            // Annuler
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Annuler',
                  style: DC.body(14, color: DC.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Pavé numérique ───────────────────────────────────────────────────────────

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
