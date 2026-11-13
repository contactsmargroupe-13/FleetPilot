import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/driver_session.dart';
import '../services/qr_access_service.dart';
import '../utils/design_constants.dart';
import '../utils/theme_ctx.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// Ce que voit le chauffeur après avoir scanné le QR code de son camion :
/// son nom dans la liste, puis son PIN. Rien d'autre.
/// ─────────────────────────────────────────────────────────────────────────
class QrEntryPage extends StatefulWidget {
  final QrLink link;

  /// Appelé une fois le chauffeur connecté.
  final VoidCallback onDone;

  /// Le téléphone n'est pas celui d'un chauffeur : retour à la connexion
  /// email / mot de passe.
  final VoidCallback onManagerLogin;

  const QrEntryPage({
    super.key,
    required this.link,
    required this.onDone,
    required this.onManagerLogin,
  });

  @override
  State<QrEntryPage> createState() => _QrEntryPageState();
}

class _QrEntryPageState extends State<QrEntryPage> {
  QrRoster? _roster;
  bool _loading = true;
  String? _loadError;

  QrDriver? _selected;
  String _pin = '';
  bool _signingIn = false;
  String? _pinError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final roster = await QrAccessService.loadRoster(widget.link.key);
      if (!mounted) return;
      if (roster == null) {
        // Clé renouvelée par le manager : inutile de la reproposer.
        await DriverSession.setLastQrKey(null);
        setState(() {
          _loadError = 'Ce QR code n’est plus valable.\n'
              'Demande à ton manager le nouveau QR du camion.';
          _loading = false;
        });
        return;
      }
      await DriverSession.setLastQrKey(widget.link.key);
      setState(() {
        _roster = roster;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadError = 'Pas de connexion. Vérifie le réseau et réessaie.';
        _loading = false;
      });
    }
  }

  String? get _currentEmail =>
      FirebaseAuth.instance.currentUser?.email?.toLowerCase();

  Future<void> _pick(QrDriver d) async {
    if (_currentEmail == d.loginEmail.toLowerCase()) {
      await _finish();
      return;
    }
    setState(() {
      _selected = d;
      _pin = '';
      _pinError = null;
    });
  }

  Future<void> _submitPin() async {
    final d = _selected;
    if (d == null || _pin.length < 4 || _signingIn) return;
    setState(() {
      _signingIn = true;
      _pinError = null;
    });
    try {
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
      }
      await QrAccessService.signIn(d.loginEmail, _pin);
      await _finish();
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _signingIn = false;
        _pin = '';
        _pinError = switch (e.code) {
          'too-many-requests' =>
            'Trop d’essais. Patiente quelques minutes puis réessaie.',
          'network-request-failed' => 'Pas de connexion. Réessaie.',
          'user-disabled' => 'Accès désactivé. Contacte ton manager.',
          _ => 'PIN incorrect',
        };
      });
    }
  }

  Future<void> _finish() async {
    await DriverSession.setPendingTruck(widget.link.plate);
    // Le nom mémorisé appartient peut-être au chauffeur d'hier :
    // c'est le compte connecté qui fait foi.
    await DriverSession.clearDriverName();
    widget.onDone();
  }

  // ── Vue ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.cBg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? _error()
                : _selected == null
                    ? _list()
                    : _pinPad(),
      ),
    );
  }

  Widget _header({String? subtitle}) {
    final plate = widget.link.plate;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DC.logo(size: 20, light: context.isDark),
          const SizedBox(height: 22),
          if (plate != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: context.cSurface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.cInk, width: 1.6),
              ),
              child: Text(plate,
                  style: context.tMono(18, w: FontWeight.w800, color: context.cInk)),
            ),
          if (subtitle != null) ...[
            const SizedBox(height: 14),
            Text(subtitle, style: context.tTitle(24)),
          ],
        ],
      ),
    );
  }

  Widget _error() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(_loadError!,
              textAlign: TextAlign.center,
              style: context.tBody(16, color: context.cInk2)),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            label: const Text('Réessayer'),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: widget.onManagerLogin,
          child: const Text('Connexion avec email'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _list() {
    final roster = _roster!;
    final current = _currentEmail;
    final drivers = [...roster.drivers]
      // Le chauffeur déjà connecté sur ce téléphone en tête de liste.
      ..sort((a, b) {
        final ca = a.loginEmail.toLowerCase() == current ? 0 : 1;
        final cb = b.loginEmail.toLowerCase() == current ? 0 : 1;
        return ca != cb ? ca - cb : 0;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(subtitle: 'Qui conduit aujourd’hui ?'),
        if (roster.companyName.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(roster.companyName,
                style: context.tBody(14, color: context.cInk2)),
          ),
        Expanded(
          child: drivers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Aucun chauffeur n’a encore de code PIN.\n'
                      'Demande à ton manager de t’en créer un.',
                      textAlign: TextAlign.center,
                      style: context.tBody(15, color: context.cInk2),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: drivers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final d = drivers[i];
                    final isMe = d.loginEmail.toLowerCase() == current;
                    return Material(
                      color: context.cSurface,
                      borderRadius: BorderRadius.circular(DC.rCard),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(DC.rCard),
                        onTap: () => _pick(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(DC.rCard),
                            border: Border.all(
                                color: isMe ? DC.primary : context.cBorder,
                                width: isMe ? 1.6 : 1),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: context.cPrimaryBg,
                                child: Text(
                                  d.label.isEmpty ? '?' : d.label[0].toUpperCase(),
                                  style: context.tTitle(16, color: DC.primary),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(d.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: context.tBody(18,
                                            w: FontWeight.w600)),
                                    if (isMe)
                                      Text('Déjà connecté — touche pour continuer',
                                          style: context.tBody(12.5,
                                              color: DC.primary)),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right, color: context.cInk3),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
        TextButton(
          onPressed: widget.onManagerLogin,
          child: const Text('Je ne suis pas chauffeur'),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _pinPad() {
    final d = _selected!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: TextButton.icon(
              onPressed: _signingIn ? null : () => setState(() => _selected = null),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Changer de nom'),
            ),
          ),
        ),
        const Spacer(),
        Text(d.label, textAlign: TextAlign.center, style: context.tTitle(24)),
        const SizedBox(height: 6),
        Text('Ton code PIN',
            textAlign: TextAlign.center,
            style: context.tBody(15, color: context.cInk2)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < (_pin.length > 4 ? _pin.length : 4); i++)
              Container(
                width: 16,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _pin.length ? context.cInk : Colors.transparent,
                  border: Border.all(color: context.cInk2, width: 1.5),
                ),
              ),
          ],
        ),
        SizedBox(
          height: 34,
          child: Center(
            child: _signingIn
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : _pinError != null
                    ? Text(_pinError!,
                        textAlign: TextAlign.center,
                        style: context.tBody(14, w: FontWeight.w600, color: DC.error))
                    : null,
          ),
        ),
        _keys(),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: FilledButton(
            onPressed: _pin.length >= 4 && !_signingIn ? _submitPin : null,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Valider', style: TextStyle(fontSize: 17)),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _keys() {
    void tap(String k) {
      if (_signingIn) return;
      setState(() {
        _pinError = null;
        if (k == '⌫') {
          if (_pin.isNotEmpty) _pin = _pin.substring(0, _pin.length - 1);
        } else if (_pin.length < 6) {
          _pin += k;
        }
      });
    }

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '⌫'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in row)
                k.isEmpty
                    ? const SizedBox(width: 84, height: 64)
                    : Padding(
                        padding: const EdgeInsets.all(5),
                        child: Material(
                          color: k == '⌫' ? Colors.transparent : context.cSurface,
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => tap(k),
                            child: Container(
                              width: 74,
                              height: 54,
                              alignment: Alignment.center,
                              decoration: k == '⌫'
                                  ? null
                                  : BoxDecoration(
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: context.cBorder),
                                    ),
                              child: k == '⌫'
                                  ? Icon(Icons.backspace_outlined,
                                      color: context.cInk2, size: 22)
                                  : Text(k, style: context.tTitle(24)),
                            ),
                          ),
                        ),
                      ),
            ],
          ),
      ],
    );
  }
}
