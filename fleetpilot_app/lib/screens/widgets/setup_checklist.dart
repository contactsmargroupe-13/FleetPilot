import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/app_state.dart';
import '../../utils/design_constants.dart';
import '../../utils/theme_ctx.dart';
import '../depot/depot_page.dart' show ShellNav;

/// Ce que l'app ne peut pas déduire des données : mémorisé sur l'appareil.
class SetupProgress {
  static const _qrPrinted = 'setup_qr_printed';
  static const _dismissed = 'setup_dismissed';

  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<void> markQrPrinted() async =>
      (await _p).setBool(_qrPrinted, true);

  static Future<(bool, bool)> load() async {
    final p = await _p;
    return (p.getBool(_qrPrinted) ?? false, p.getBool(_dismissed) ?? false);
  }

  static Future<void> dismiss() async => (await _p).setBool(_dismissed, true);
}

class _Step {
  final String title, hint;
  final bool done;
  final VoidCallback onTap;
  const _Step(this.title, this.hint, this.done, this.onTap);
}

/// ─────────────────────────────────────────────────────────────────────────
/// Démarrage guidé : les sept réglages sans lesquels le résultat du mois
/// ne veut rien dire. Chaque ligne mène là où on la règle, et se coche
/// d'elle-même quand c'est fait. Disparaît une fois tout coché.
/// ─────────────────────────────────────────────────────────────────────────
class SetupChecklist extends ConsumerStatefulWidget {
  final ShellNav onNavigate;
  final VoidCallback onChargeRate;
  const SetupChecklist(
      {super.key, required this.onNavigate, required this.onChargeRate});

  @override
  ConsumerState<SetupChecklist> createState() => _SetupChecklistState();
}

class _SetupChecklistState extends ConsumerState<SetupChecklist> {
  bool _qrPrinted = false;
  bool _dismissed = false;
  bool _loaded = false;
  bool _expanded = true;

  @override
  void initState() {
    super.initState();
    SetupProgress.load().then((v) {
      if (!mounted) return;
      setState(() {
        _qrPrinted = v.$1;
        _dismissed = v.$2;
        _loaded = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _dismissed) return const SizedBox.shrink();
    final s = ref.watch(appStateProvider);
    final nav = widget.onNavigate;

    final steps = [
      _Step('Ajoute tes camions', 'Loyer ou crédit, assurance : ce sont tes coûts fixes',
          s.trucks.isNotEmpty, () => nav('gestion', tab: 2)),
      _Step('Ajoute tes chauffeurs', 'Avec leur salaire brut',
          s.drivers.isNotEmpty, () => nav('gestion', tab: 1)),
      _Step('Configure tes commissionnaires', 'Leurs tarifs font ton chiffre d’affaires',
          s.clientPricings.isNotEmpty, () => nav('reglages', tab: 0)),
      _Step('Affecte chaque chauffeur à un camion', 'Touche « affecter » sur sa fiche',
          s.assignments.isNotEmpty, () => nav('gestion', tab: 1)),
      _Step('Donne un code PIN à tes chauffeurs', 'Ils n’ont pas besoin d’email',
          s.drivers.any((d) => d.hasQrAccess), () => nav('reglages', tab: 1)),
      _Step('Imprime les QR codes', 'Un par camion, collé en cabine',
          _qrPrinted, () => nav('reglages', tab: 1)),
      _Step('Vérifie le taux de charges patronales', 'Pour un résultat juste',
          s.chargeRateConfirmed, widget.onChargeRate),
    ];
    final done = steps.where((x) => x.done).length;
    if (done == steps.length) return const SizedBox.shrink();
    final next = steps.indexWhere((x) => !x.done);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: context.cSurface,
        borderRadius: BorderRadius.circular(DC.rCard),
        border: Border.all(color: DC.primary.withValues(alpha: 0.45), width: 1.4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(DC.rCard),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.rocket_launch_outlined,
                          color: DC.primary, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Bien démarrer',
                            style: context.tTitle(16)),
                      ),
                      Text('$done / ${steps.length}',
                          style: context.tMono(13,
                              w: FontWeight.w700, color: DC.primary)),
                      Icon(_expanded ? Icons.expand_less : Icons.expand_more,
                          color: context.cInk3),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: done / steps.length,
                      minHeight: 6,
                      backgroundColor: context.cSurface2,
                      color: DC.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_expanded) ...[
            for (var i = 0; i < steps.length; i++)
              InkWell(
                onTap: steps[i].done ? null : steps[i].onTap,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                  decoration: BoxDecoration(
                    color: i == next ? context.cPrimaryBg : null,
                    border: Border(top: BorderSide(color: context.cBorder)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        steps[i].done
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        size: 20,
                        color: steps[i].done ? DC.success : context.cInk3,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              steps[i].title,
                              style: context.tBody(14,
                                  w: i == next ? FontWeight.w700 : FontWeight.w500,
                                  color: steps[i].done ? context.cInk3 : context.cInk),
                            ),
                            if (!steps[i].done)
                              Text(steps[i].hint,
                                  style: context.tBody(12, color: context.cInk2)),
                          ],
                        ),
                      ),
                      if (!steps[i].done)
                        Icon(Icons.chevron_right,
                            size: 18,
                            color: i == next ? DC.primary : context.cInk3),
                    ],
                  ),
                ),
              ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () async {
                  await SetupProgress.dismiss();
                  if (mounted) setState(() => _dismissed = true);
                },
                child: const Text('Masquer'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
