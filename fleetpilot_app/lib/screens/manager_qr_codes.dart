import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr/qr.dart';

import '../providers/app_state.dart';
import '../services/profitability.dart';
import '../services/qr_access_service.dart';
import '../utils/design_constants.dart';
import '../utils/theme_ctx.dart';
import 'add_truck.dart';
import 'models/driver.dart';
import 'widgets/setup_checklist.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// QR codes des camions et codes PIN des chauffeurs.
///
/// Un QR collé dans chaque camion ouvre l'application avec ce camion
/// présélectionné ; le chauffeur choisit son nom et tape son PIN.
/// ─────────────────────────────────────────────────────────────────────────
class ManagerQrCodesPage extends ConsumerStatefulWidget {
  const ManagerQrCodesPage({super.key});

  @override
  ConsumerState<ManagerQrCodesPage> createState() => _ManagerQrCodesPageState();
}

class _ManagerQrCodesPageState extends ConsumerState<ManagerQrCodesPage> {
  String? _key;
  String? _error;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  Future<void> _loadKey() async {
    final state = ref.read(appStateProvider);
    final fs = state.firestore;
    if (fs == null) {
      setState(() => _error =
          'Les QR codes demandent une connexion à votre compte en ligne.');
      return;
    }
    try {
      final key = await fs.ensureQrKey(state.drivers);
      if (mounted) setState(() => _key = key);
    } catch (e) {
      if (mounted) setState(() => _error = 'Impossible de préparer les QR codes : $e');
    }
  }

  List<Truck> get _trucks => ref
      .read(appStateProvider)
      .trucks
      .where((t) => t.truckStatus != TruckStatus.vendu)
      .toList();

  // ── PIN ─────────────────────────────────────────────────────────────

  Future<void> _setPin(Driver d) async {
    final pin = await showDialog<String>(
      context: context,
      builder: (_) => _PinDialog(driver: d),
    );
    if (pin == null || !mounted) return;

    final state = ref.read(appStateProvider);
    final fs = state.firestore;
    if (fs == null) return;

    setState(() => _busy.add(d.name));
    try {
      await QrAccessService.createPinAccount(
        companyId: fs.companyId,
        driver: d,
        pin: pin,
        linkToDriver: (email) => state.setDriverQrAccess(d.name, email),
      );
      _snack('PIN de ${d.fullName} enregistré. Communiquez-le-lui directement.');
    } on FirebaseAuthException catch (e) {
      _snack('Échec : ${e.message ?? e.code}');
    } catch (e) {
      _snack('Échec : $e');
    } finally {
      if (mounted) setState(() => _busy.remove(d.name));
    }
  }

  Future<void> _rotateKey() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renouveler les QR codes ?'),
        content: const Text(
            'Tous les QR codes déjà imprimés cesseront de fonctionner. '
            'À faire si un QR a été photographié ou diffusé hors de l’entreprise.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: DC.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Renouveler'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final state = ref.read(appStateProvider);
    final key = await state.firestore!.rotateQrKey(state.drivers);
    if (mounted) setState(() => _key = key);
    _snack('Nouveaux QR codes générés — pensez à les réimprimer.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Impression ──────────────────────────────────────────────────────

  Future<void> _print(List<Truck> trucks) async {
    final key = _key!;
    final doc = pw.Document();
    const perPage = 6;
    for (var i = 0; i < trucks.length; i += perPage) {
      final page = trucks.skip(i).take(perPage).toList();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (_) => pw.Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            for (final t in page)
              pw.Container(
                width: 265,
                height: 245,
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey600, width: 1),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(t.plate,
                        style: pw.TextStyle(
                            fontSize: 22, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 8),
                    pw.BarcodeWidget(
                      barcode: pw.Barcode.qrCode(),
                      data: QrAccessService.truckUrl(key, t.plate),
                      width: 140,
                      height: 140,
                    ),
                    pw.SizedBox(height: 10),
                    pw.Text('Scannez avant de démarrer la journée',
                        style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('FleetPilote',
                        style: const pw.TextStyle(
                            fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
              ),
          ],
        ),
      ));
    }
    await SetupProgress.markQrPrinted();
    await Printing.layoutPdf(
      name: 'QR codes camions',
      onLayout: (_) => doc.save(),
    );
  }

  void _showQr(Truck t) {
    final url = QrAccessService.truckUrl(_key!, t.plate);
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.plate),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrView(data: url, size: 220),
            ),
            const SizedBox(height: 10),
            SelectableText(url, style: ctx.tMono(11, color: ctx.cInk2)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: url));
              Navigator.pop(ctx);
              _snack('Lien copié');
            },
            child: const Text('Copier le lien'),
          ),
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Fermer')),
        ],
      ),
    );
  }

  // ── Vue ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final drivers = state.drivers
        .where((d) => !Profitability.inactive.contains(d.status))
        .toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
    final trucks = _trucks;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
      children: [
        Text('Démarrage par QR code', style: context.tTitle(20)),
        const SizedBox(height: 6),
        Text(
          '1. Collez le QR code de chaque camion dans sa cabine.\n'
          '2. Donnez un code PIN à chaque chauffeur.\n'
          '3. Le matin, le chauffeur scanne, choisit son nom, tape son PIN, '
          'puis saisit ses km ou lance le GPS.',
          style: context.tBody(13, color: context.cInk2),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Text(_error!, style: context.tBody(13, color: DC.error)),
        ],

        // ── Chauffeurs ───────────────────────────────────────────────
        _title(context, 'Chauffeurs'),
        _card(
          context,
          drivers.isEmpty
              ? [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Text('Aucun chauffeur actif.',
                        style: context.tBody(13, color: context.cInk2)),
                  ),
                ]
              : [
                  for (final d in drivers)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            d.hasQrAccess ? context.cSuccessBg : context.cSurface2,
                        child: Icon(
                          d.hasQrAccess ? Icons.lock_open : Icons.lock_outline,
                          size: 18,
                          color: d.hasQrAccess ? DC.success : context.cInk3,
                        ),
                      ),
                      title: Text(d.fullName,
                          style: context.tBody(14.5, w: FontWeight.w600)),
                      subtitle: Text(
                        d.hasQrAccess ? 'PIN défini' : 'Pas encore de PIN',
                        style: context.tBody(12,
                            color: d.hasQrAccess ? DC.success : context.cInk3),
                      ),
                      trailing: _busy.contains(d.name)
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : TextButton(
                              onPressed:
                                  _key == null ? null : () => _setPin(d),
                              child: Text(d.hasQrAccess ? 'Changer' : 'Définir'),
                            ),
                    ),
                ],
        ),

        // ── Camions ──────────────────────────────────────────────────
        _title(context, 'Camions'),
        if (trucks.isEmpty)
          Text('Ajoutez d’abord vos camions.',
              style: context.tBody(13, color: context.cInk2))
        else ...[
          FilledButton.icon(
            onPressed: _key == null ? null : () => _print(trucks),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Imprimer les QR codes'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final t in trucks)
                InkWell(
                  onTap: _key == null ? null : () => _showQr(t),
                  borderRadius: BorderRadius.circular(DC.rCard),
                  child: Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.cSurface,
                      borderRadius: BorderRadius.circular(DC.rCard),
                      border: Border.all(color: context.cBorder),
                    ),
                    child: Column(
                      children: [
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.all(6),
                          child: _key == null
                              ? SizedBox(
                                  width: 110,
                                  height: 110,
                                  child: Center(
                                    child: _error != null
                                        ? const Icon(Icons.qr_code_2,
                                            size: 48, color: Colors.black26)
                                        : const CircularProgressIndicator(
                                            strokeWidth: 2),
                                  ))
                              : QrView(
                                  data: QrAccessService.truckUrl(_key!, t.plate),
                                  size: 110),
                        ),
                        const SizedBox(height: 8),
                        Text(t.plate,
                            style: context.tMono(13,
                                w: FontWeight.w700, color: context.cInk)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],

        if (_key != null) ...[
          const SizedBox(height: 26),
          OutlinedButton.icon(
            onPressed: _rotateKey,
            style: OutlinedButton.styleFrom(foregroundColor: DC.error),
            icon: const Icon(Icons.autorenew, size: 18),
            label: const Text('Renouveler tous les QR codes'),
          ),
        ],
      ],
    );
  }

  Widget _title(BuildContext context, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 24, 2, 9),
        child: Text(t.toUpperCase(),
            style: context.tMono(11, w: FontWeight.w600, color: context.cInk2)),
      );

  Widget _card(BuildContext context, List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: context.cSurface,
          borderRadius: BorderRadius.circular(DC.rCard),
          border: Border.all(color: context.cBorder),
        ),
        child: Column(children: children),
      );
}

class _PinDialog extends StatefulWidget {
  final Driver driver;
  const _PinDialog({required this.driver});

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pin.text.trim();
    if (!QrAccessService.isValidPin(pin)) {
      setState(() => _error = '4 à 6 chiffres');
      return;
    }
    if (pin != _confirm.text.trim()) {
      setState(() => _error = 'Les deux saisies ne correspondent pas');
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) {
    InputDecoration deco(String label) => InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          counterText: '',
        );
    return AlertDialog(
      title: Text('PIN de ${widget.driver.fullName}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.driver.hasQrAccess)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('L’ancien PIN ne fonctionnera plus.',
                  style: context.tBody(12.5, color: context.cInk2)),
            ),
          TextField(
            controller: _pin,
            autofocus: true,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: deco('Nouveau PIN (4 à 6 chiffres)'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _confirm,
            obscureText: true,
            maxLength: 6,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: deco('Confirmer le PIN'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: context.tBody(12.5, color: DC.error)),
            ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler')),
        FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
      ],
    );
  }
}

/// QR code dessiné module par module — noir sur blanc quel que soit le thème,
/// sinon certains lecteurs ne le reconnaissent pas.
class QrView extends StatelessWidget {
  final String data;
  final double size;
  const QrView({super.key, required this.data, required this.size});

  @override
  Widget build(BuildContext context) {
    final image = QrImage(
        QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M));
    return CustomPaint(size: Size.square(size), painter: _QrPainter(image));
  }
}

class _QrPainter extends CustomPainter {
  final QrImage image;
  _QrPainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    final n = image.moduleCount;
    final cell = size.width / n;
    final paint = Paint()..color = Colors.black;
    for (var r = 0; r < n; r++) {
      for (var c = 0; c < n; c++) {
        if (image.isDark(r, c)) {
          // +0.5 évite les fines lignes blanches entre modules voisins.
          canvas.drawRect(
              Rect.fromLTWH(c * cell, r * cell, cell + 0.5, cell + 0.5), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_QrPainter old) => old.image != image;
}
