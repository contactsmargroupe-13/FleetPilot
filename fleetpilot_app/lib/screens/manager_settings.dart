import 'package:flutter/material.dart';
import '../services/company_settings.dart';
import 'manager_client_pricing.dart';

class ManagerSettingsPage extends StatefulWidget {
  const ManagerSettingsPage({super.key});

  @override
  State<ManagerSettingsPage> createState() => _ManagerSettingsPageState();
}

class _ManagerSettingsPageState extends State<ManagerSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _siretCtrl;
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
    _phoneCtrl = TextEditingController(text: CompanySettings.phone);
    _emailCtrl = TextEditingController(text: CompanySettings.email);
    _apiKeyCtrl = TextEditingController(text: CompanySettings.claudeApiKey);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _siretCtrl.dispose();
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

  Future<void> _changePin() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _ChangePinDialog(),
    );
    setState(() {}); // Rafraîchir pour refléter l'état du PIN
  }

  Future<void> _removePin() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer le code PIN'),
        content: const Text(
            "L'espace manager ne sera plus protégé. Confirmer ?"),
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
      await CompanySettings.removeManagerPin();
      setState(() {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code PIN supprimé')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinSet = CompanySettings.hasPinSet;

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
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
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

        // ── Sécurité / Code PIN ──────────────────────────────────────────
        const Text(
          'Sécurité',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.lock_outline, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Code PIN manager',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: pinSet
                            ? Colors.green.withValues(alpha: 0.15)
                            : Colors.orange.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        pinSet ? 'Actif' : 'Non défini',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: pinSet ? Colors.green : Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Protège l\'accès à l\'espace manager contre les chauffeurs.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _changePin,
                        icon: const Icon(Icons.pin_outlined, size: 18),
                        label: Text(pinSet ? 'Modifier le PIN' : 'Créer un PIN'),
                      ),
                    ),
                    if (pinSet) ...[
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _removePin,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                        icon: const Icon(Icons.lock_open_outlined, size: 18),
                        label: const Text('Supprimer'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 32),

        // ── Contrats clients ─────────────────────────────────────────────
        const Text(
          'Contrats clients',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.handshake_outlined),
            title: const Text('Contrats clients'),
            subtitle: const Text('Tarifs et conditions par client'),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clé API Anthropic (Claude)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Utilisée pour lire automatiquement les tickets carburant. '
                  'Obtiens ta clé sur console.anthropic.com',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyCtrl,
                  obscureText: _apiKeyObscured,
                  onChanged: (_) => setState(() => _apiKeySaved = false),
                  decoration: InputDecoration(
                    labelText: 'sk-ant-...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.key_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _apiKeyObscured
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () =>
                          setState(() => _apiKeyObscured = !_apiKeyObscured),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _saveApiKey,
                    icon: Icon(
                        _apiKeySaved ? Icons.check : Icons.save_outlined),
                    label: Text(
                        _apiKeySaved ? 'Clé enregistrée' : 'Enregistrer la clé'),
                  ),
                ),
              ],
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
                  title: const Text('Retour à l\'accueil ?'),
                  content: const Text(
                      'Tu seras redirigé vers l\'écran de sélection Manager / Chauffeur.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                    FilledButton(
                      onPressed: () {
                        Navigator.pop(context); // fermer dialog
                        Navigator.of(context).popUntil((route) => route.isFirst);
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

// ── Dialog changement PIN ────────────────────────────────────────────────────

class _ChangePinDialog extends StatefulWidget {
  const _ChangePinDialog();

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  // Étapes : verify (si PIN existant) → enter → confirm
  late _Step _step;
  String _pin = '';
  String _newPin = '';
  String _confirmPin = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _step = CompanySettings.hasPinSet ? _Step.verify : _Step.enter;
  }

  void _onKey(String digit) {
    setState(() {
      _error = null;
      switch (_step) {
        case _Step.verify:
          if (_pin.length < 4) _pin += digit;
          if (_pin.length == 4) _checkCurrentPin();
          break;
        case _Step.enter:
          if (_newPin.length < 4) _newPin += digit;
          if (_newPin.length == 4) _step = _Step.confirm;
          break;
        case _Step.confirm:
          if (_confirmPin.length < 4) _confirmPin += digit;
          if (_confirmPin.length == 4) _saveNewPin();
          break;
      }
    });
  }

  void _onDelete() {
    setState(() {
      _error = null;
      switch (_step) {
        case _Step.verify:
          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
          break;
        case _Step.enter:
          if (_newPin.isNotEmpty) {
            _newPin = _newPin.substring(0, _newPin.length - 1);
          }
          break;
        case _Step.confirm:
          if (_confirmPin.isNotEmpty) {
            _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
          }
          break;
      }
    });
  }

  void _checkCurrentPin() {
    if (CompanySettings.checkPin(_pin)) {
      _step = _Step.enter;
      _pin = '';
    } else {
      _pin = '';
      _error = 'Code incorrect, réessayez';
    }
  }

  Future<void> _saveNewPin() async {
    if (_newPin == _confirmPin) {
      await CompanySettings.saveManagerPin(_newPin);
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code PIN mis à jour')),
        );
      }
    } else {
      setState(() {
        _newPin = '';
        _confirmPin = '';
        _step = _Step.enter;
        _error = 'Les codes ne correspondent pas, recommencez';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    String current;
    switch (_step) {
      case _Step.verify:
        current = _pin;
        break;
      case _Step.enter:
        current = _newPin;
        break;
      case _Step.confirm:
        current = _confirmPin;
        break;
    }

    final titles = {
      _Step.verify: ('Code actuel', 'Entrez votre code PIN actuel'),
      _Step.enter: ('Nouveau code', 'Choisissez un code à 4 chiffres'),
      _Step.confirm: ('Confirmer', 'Saisissez à nouveau le nouveau code'),
    };
    final (title, subtitle) = titles[_step]!;

    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),

            // Indicateurs
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < current.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? Colors.blue : Colors.transparent,
                    border: Border.all(
                      color: filled ? Colors.blue : Colors.grey,
                      width: 2,
                    ),
                  ),
                );
              }),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                  textAlign: TextAlign.center),
            ],

            const SizedBox(height: 24),

            // Pavé numérique inline simplifié
            for (final row in [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
              ['', '0', '⌫'],
            ])
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: row.map((k) {
                  if (k.isEmpty) return const SizedBox(width: 68, height: 52);
                  return GestureDetector(
                    onTap: () => k == '⌫' ? _onDelete() : _onKey(k),
                    child: Container(
                      width: 68,
                      height: 52,
                      margin: const EdgeInsets.all(5),
                      decoration: k == '⌫'
                          ? null
                          : BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: Theme.of(context).dividerColor),
                            ),
                      alignment: Alignment.center,
                      child: k == '⌫'
                          ? const Icon(Icons.backspace_outlined,
                              color: Colors.grey, size: 20)
                          : Text(k,
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold)),
                    ),
                  );
                }).toList(),
              ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child:
                  const Text('Annuler', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Step { verify, enter, confirm }
