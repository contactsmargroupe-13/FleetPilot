import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_state.dart';
import '../services/auth_service.dart';
import '../services/company_settings.dart';
import '../services/firestore_service.dart';
import '../utils/design_constants.dart';
import '../utils/shared_widgets.dart';
import 'manager_client_pricing.dart';
import 'models/user_access.dart';

class ManagerSettingsPage extends ConsumerStatefulWidget {
  const ManagerSettingsPage({super.key});

  @override
  ConsumerState<ManagerSettingsPage> createState() => _ManagerSettingsPageState();
}

class _ManagerSettingsPageState extends ConsumerState<ManagerSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _siretCtrl;
  late final TextEditingController _tvaIntraCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _apiKeyCtrl;

  bool _saved = false;
  bool _apiKeySaved = false;
  bool _apiKeyObscured = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: CompanySettings.name);
    _addressCtrl = TextEditingController(text: CompanySettings.address);
    _siretCtrl = TextEditingController(text: CompanySettings.siret);
    _tvaIntraCtrl = TextEditingController(text: CompanySettings.tvaIntra);
    _phoneCtrl = TextEditingController(text: CompanySettings.phone);
    _emailCtrl = TextEditingController(text: CompanySettings.email);
    _apiKeyCtrl = TextEditingController(text: CompanySettings.claudeApiKey);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _siretCtrl.dispose();
    _tvaIntraCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    await CompanySettings.save(
      name: _nameCtrl.text.trim(),
      address: _addressCtrl.text.trim(),
      siret: _siretCtrl.text.trim(),
      tvaIntra: _tvaIntraCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );

    setState(() => _saved = true);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres enregistrés')),
    );
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyCtrl.text.trim();
    await CompanySettings.saveClaudeApiKey(key);
    setState(() => _apiKeySaved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Clé API enregistrée')),
    );
  }

  // ── Gestion des accès ─────────────────────────────────────────────────

  Widget _buildAccessList() {
    final accesses = ref.watch(appStateProvider).userAccesses;
    if (accesses.isEmpty) {
      return const DCEmptyState(
        icon: Icons.people_outline,
        title: 'Aucun accès configuré',
        subtitle: 'Invitez des membres pour leur donner accès',
      );
    }

    return Column(
      children: accesses.map((access) {
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: access.role == AccessRole.comptable
                  ? Colors.purple.withValues(alpha: 0.12)
                  : Colors.blue.withValues(alpha: 0.12),
              child: Icon(
                access.role == AccessRole.comptable
                    ? Icons.account_balance_outlined
                    : Icons.dashboard_outlined,
                size: 20,
                color: access.role == AccessRole.comptable
                    ? Colors.purple
                    : Colors.blue,
              ),
            ),
            title: Text(access.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(accessRoleLabel(access.role),
                style: const TextStyle(fontSize: 12)),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteAccess(access),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _addAccess() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    AccessRole selectedRole = AccessRole.comptable;
    String pin = '';
    String confirmPin = '';
    bool confirming = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          if (pin.length < 4 || confirming) {
            // Étape PIN
            final currentPin = confirming ? confirmPin : pin;
            return AlertDialog(
              title: Text(confirming
                  ? 'Confirmer le code PIN'
                  : nameCtrl.text.isEmpty
                      ? 'Nouvel accès'
                      : 'PIN pour ${nameCtrl.text}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!confirming && pin.isEmpty) ...[
                    // Nom
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Email
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (pour invitation)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email_outlined),
                        helperText: 'Optionnel — pour envoyer les identifiants',
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Rôle
                    DropdownButtonFormField<AccessRole>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'Rôle',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      items: AccessRole.values
                          .where((r) => r != AccessRole.manager)
                          .map((r) => DropdownMenuItem(
                                value: r,
                                child: Text(accessRoleLabel(r)),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) set(() => selectedRole = v);
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(accessRoleDescription(selectedRole),
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: nameCtrl.text.trim().isEmpty
                          ? null
                          : () => set(() {}), // Force rebuild pour passer au PIN
                      child: const Text('Définir le code PIN'),
                    ),
                  ] else ...[
                    Text(confirming
                        ? 'Saisissez à nouveau le code'
                        : 'Choisissez un code PIN (4 chiffres)'),
                    const SizedBox(height: 20),
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
                            color: filled ? Colors.purple : Colors.transparent,
                            border: Border.all(
                              color:
                                  filled ? Colors.purple : Colors.grey,
                              width: 2,
                            ),
                          ),
                        );
                      }),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(error!,
                          style: const TextStyle(
                              fontSize: 12, color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    // Mini numpad
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final d in [
                          '1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', '⌫'
                        ])
                          if (d.isEmpty)
                            const SizedBox(width: 48, height: 40)
                          else
                            SizedBox(
                              width: 48,
                              height: 40,
                              child: OutlinedButton(
                                onPressed: () {
                                  set(() {
                                    error = null;
                                    if (d == '⌫') {
                                      if (confirming && confirmPin.isNotEmpty) {
                                        confirmPin = confirmPin.substring(
                                            0, confirmPin.length - 1);
                                      } else if (!confirming &&
                                          pin.isNotEmpty) {
                                        pin = pin.substring(
                                            0, pin.length - 1);
                                      }
                                    } else {
                                      if (confirming &&
                                          confirmPin.length < 4) {
                                        confirmPin += d;
                                        if (confirmPin.length == 4) {
                                          if (pin == confirmPin) {
                                            // Succès
                                            final hash = sha256
                                                .convert(
                                                    utf8.encode(pin))
                                                .toString();
                                            final userName = nameCtrl.text.trim();
                                            final userEmail = emailCtrl.text.trim();
                                            final userPin = pin;
                                            ref
                                                .read(appStateProvider)
                                                .addUserAccess(UserAccess(
                                                  id: DateTime.now()
                                                      .millisecondsSinceEpoch
                                                      .toString(),
                                                  name: userName,
                                                  role: selectedRole,
                                                  pinHash: hash,
                                                ));
                                            nameCtrl.dispose();
                                            emailCtrl.dispose();
                                            Navigator.pop(ctx);
                                            // Proposer l'envoi par email
                                            if (userEmail.isNotEmpty) {
                                              _sendAccessEmail(
                                                  userEmail, userName, selectedRole, userPin);
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(SnackBar(
                                                      content: Text(
                                                          'Accès ${accessRoleLabel(selectedRole)} créé — PIN : $userPin')));
                                            }
                                          } else {
                                            confirmPin = '';
                                            confirming = false;
                                            pin = '';
                                            error =
                                                'Les codes ne correspondent pas';
                                          }
                                        }
                                      } else if (!confirming &&
                                          pin.length < 4) {
                                        pin += d;
                                        if (pin.length == 4) {
                                          confirming = true;
                                        }
                                      }
                                    }
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                ),
                                child: Text(d,
                                    style: const TextStyle(fontSize: 16)),
                              ),
                            ),
                      ],
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    nameCtrl.dispose();
                    Navigator.pop(ctx);
                  },
                  child: const Text('Annuler'),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _sendAccessEmail(
      String email, String name, AccessRole role, String pin) {
    final companyName = CompanySettings.name.isNotEmpty
        ? CompanySettings.name
        : 'FleetPilote';
    final message =
        'Bonjour $name,\n\n'
        'Vous avez été invité(e) à accéder à $companyName sur FleetPilote '
        'en tant que ${accessRoleLabel(role)}.\n\n'
        'Votre code PIN : $pin\n\n'
        'Ouvrez l\'application et sélectionnez votre accès sur la page d\'accueil.\n\n'
        'Cordialement,\n$companyName';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 8),
            const Expanded(child: Text('Accès créé')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$name — ${accessRoleLabel(role)}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Email : $email',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                message,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: message));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copié')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copier'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetData() async {
    final passwordCtrl = TextEditingController();
    String? error;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('Réinitialiser ?'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Toutes les données seront supprimées : chauffeurs, camions, tournées, dépenses, etc.\n\n'
                'Confirmez avec votre mot de passe :',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline),
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                passwordCtrl.dispose();
                Navigator.pop(ctx, false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () async {
                final password = passwordCtrl.text;
                if (password.isEmpty) {
                  set(() => error = 'Entrez votre mot de passe');
                  return;
                }
                // Vérifier le mot de passe via Firebase re-auth
                try {
                  final user = AuthService.currentFirebaseUser;
                  if (user == null || user.email == null) return;
                  final cred = EmailAuthProvider.credential(
                    email: user.email!,
                    password: password,
                  );
                  await user.reauthenticateWithCredential(cred);
                  passwordCtrl.dispose();
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  set(() => error = 'Mot de passe incorrect');
                }
              },
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Tout supprimer'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;

    final appState = ref.read(appStateProvider);

    // Vider toutes les listes en mémoire
    appState.trucks.clear();
    appState.drivers.clear();
    appState.tours.clear();
    appState.expenses.clear();
    appState.driverDayEntries.clear();
    appState.clientPricings.clear();
    appState.driverDocuments.clear();
    appState.candidates.clear();
    appState.adminDocuments.clear();
    appState.driverNotifications.clear();
    appState.managerAlerts.clear();
    appState.equipment.clear();
    appState.assignments.clear();
    appState.messages.clear();
    appState.userAccesses.clear();

    // Notifier l'UI
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    appState.notifyListeners();

    // Vider Firestore si connecté
    try {
      final currentUser = AuthService.currentFirebaseUser;
      if (currentUser != null) {
        final profile = await AuthService.getAppUser(currentUser.uid);
        final fs = FirestoreService(companyId: profile.companyId);
        // Upload empty data
        await fs.uploadLocalData(
          drivers: [], trucks: [], tours: [], expenses: [],
          dayEntries: [], clientPricings: [], driverDocuments: [],
          candidates: [], adminDocuments: [], driverNotifications: [],
          managerAlerts: [], equipment: [], assignments: [], messages: [],
        );
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Toutes les données ont été supprimées')),
      );
    }
  }

  void _inviteMember() {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    AccessRole selectedRole = AccessRole.chauffeur;
    bool loading = false;
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          return AlertDialog(
            title: const Text('Inviter un membre'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email_outlined),
                      helperText: 'Le membre créera son mot de passe lui-même',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<AccessRole>(
                    value: selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Rôle',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    items: [AccessRole.chauffeur, AccessRole.comptable]
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text(accessRoleLabel(r)),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) set(() => selectedRole = v);
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(error!,
                        style: const TextStyle(fontSize: 12, color: Colors.red)),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  nameCtrl.dispose();
                  emailCtrl.dispose();
                  Navigator.pop(ctx);
                },
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: loading
                    ? null
                    : () async {
                        final name = nameCtrl.text.trim();
                        final email = emailCtrl.text.trim();

                        if (name.isEmpty || email.isEmpty || !email.contains('@')) {
                          set(() => error = 'Remplissez le nom et un email valide');
                          return;
                        }

                        set(() {
                          loading = true;
                          error = null;
                        });

                        try {
                          final currentUser = AuthService.currentFirebaseUser;
                          if (currentUser == null) throw Exception('Non connecté');
                          final managerProfile =
                              await AuthService.getAppUser(currentUser.uid);

                          await AuthService.inviteMember(
                            email: email,
                            name: name,
                            role: selectedRole,
                            companyId: managerProfile.companyId,
                          );

                          nameCtrl.dispose();
                          emailCtrl.dispose();
                          if (ctx.mounted) Navigator.pop(ctx);

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Invitation envoyée à $name ($email)'),
                              ),
                            );
                          }
                        } catch (e) {
                          set(() {
                            loading = false;
                            error = e.toString();
                          });
                        }
                      },
                child: loading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Inviter'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _deleteAccess(UserAccess access) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer l\'accès'),
        content: Text(
            'Supprimer l\'accès "${access.name}" (${accessRoleLabel(access.role)}) ?'),
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
    if (confirm == true) {
      ref.read(appStateProvider).deleteUserAccess(access.id);
      if (mounted) {
        showUndoSnackBar(
          context,
          'Accès "${access.name}" supprimé',
          () => ref.read(appStateProvider).addUserAccess(access),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Identité entreprise ──────────────────────────────────────────
        const Text(
          "Identité de l'entreprise",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          onChanged: () => setState(() => _saved = false),
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom de la société',
                  prefixIcon: Icon(Icons.business_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Champ obligatoire' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Adresse',
                  prefixIcon: Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _siretCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'SIRET',
                  prefixIcon: Icon(Icons.numbers_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _tvaIntraCtrl,
                decoration: const InputDecoration(
                  labelText: 'N° TVA intracommunautaire',
                  prefixIcon: Icon(Icons.account_balance_outlined),
                  border: OutlineInputBorder(),
                  hintText: 'FR12345678901',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (v.trim().length < 10) return 'Numéro trop court';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  if (!v.contains('@') || !v.contains('.')) return 'Email invalide';
                  return null;
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: Icon(_saved ? Icons.check : Icons.save_outlined),
                  label: Text(_saved ? 'Enregistré' : 'Enregistrer'),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 32),

        // ── Gestion des accès ────────────────────────────────────────────
        const Text(
          'Gestion des accès',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text(
          'Invitez chauffeurs et comptables — chacun aura son propre compte',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 8),
        _buildAccessList(),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _inviteMember,
          icon: const Icon(Icons.person_add_outlined, size: 18),
          label: const Text('Inviter un membre'),
        ),

        const SizedBox(height: 32),

        // ── Commissionnaires ─────────────────────────────────────────────
        const Text(
          'Commissionnaires',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.handshake_outlined),
            title: const Text('Commissionnaires'),
            subtitle: const Text('Tarifs et conditions par commissionnaire'),
            trailing: FilledButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManagerClientPricingPage(),
                  ),
                );
              },
              child: const Text('Gérer'),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Intelligence artificielle ────────────────────────────────────
        const Text(
          'Intelligence artificielle',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.auto_awesome, color: Colors.purple, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('IA intégrée',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text(
                        'Assistant, scan intelligent et rapports IA disponibles pour toute l\'équipe.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: Colors.green, size: 24),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Réinitialiser les données ─────────────────────────────────
        const Text(
          'Données',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _resetData,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
            icon: const Icon(Icons.delete_sweep_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Réinitialiser toutes les données'),
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Déconnexion ──────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Se déconnecter ?'),
                  content: const Text(
                      'Vous serez redirigé vers l\'écran de connexion.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(context); // fermer dialog
                        await AuthService.signOut();
                        // Le StreamBuilder dans app.dart détecte le signOut
                        // et redirige automatiquement vers LoginPage
                      },
                      style: FilledButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text('Se déconnecter'),
                    ),
                  ],
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
            icon: const Icon(Icons.logout),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Se déconnecter'),
            ),
          ),
        ),

        const SizedBox(height: 20),
      ],
    );
  }
}

