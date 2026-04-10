import 'package:flutter/material.dart';
import '../utils/design_constants.dart';
import '../utils/shared_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_state.dart';
import 'models/driver.dart';

/// Taux URSSAF par défaut pour le transport routier (régime général 2024-2025)
class UrssafRates {
  // ── Charges patronales ────────────────────────────────────────
  static const double maladie = 7.0; // Assurance maladie (taux réduit < 2.5 SMIC)
  static const double vieillesse = 8.55; // Vieillesse plafonnée + déplafonnée
  static const double allocFamiliales = 3.45; // Alloc. familiales (taux réduit)
  static const double accidentTravail = 3.5; // AT/MP transport routier
  static const double chomagePatronal = 4.05; // Assurance chômage
  static const double retraitePatronal = 4.72; // Agirc-Arrco
  static const double fnal = 0.50; // FNAL
  static const double csa = 0.30; // Contribution solidarité autonomie
  static const double formationPro = 1.0; // Formation professionnelle

  static double get totalPatronal =>
      maladie + vieillesse + allocFamiliales + accidentTravail +
      chomagePatronal + retraitePatronal + fnal + csa + formationPro;

  // ── Charges salariales ────────────────────────────────────────
  static const double vieillesseSal = 6.90; // Vieillesse
  static const double chomageSal = 0.0; // Plus de cotisation salariale chômage
  static const double retraiteSal = 3.15; // Agirc-Arrco
  static const double csgCrds = 9.70; // CSG + CRDS

  static double get totalSalarial =>
      vieillesseSal + chomageSal + retraiteSal + csgCrds;
}

class ManagerUrssafPage extends ConsumerStatefulWidget {
  const ManagerUrssafPage({super.key});

  @override
  ConsumerState<ManagerUrssafPage> createState() => _ManagerUrssafPageState();
}

class _ManagerUrssafPageState extends ConsumerState<ManagerUrssafPage> {
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Taux personnalisables
  double _tauxPatronal = UrssafRates.totalPatronal;
  double _tauxSalarial = UrssafRates.totalSalarial;

  static const _keyTauxPatronal = 'urssaf_taux_patronal';
  static const _keyTauxSalarial = 'urssaf_taux_salarial';

  String get _monthLabel => DC.monthLabel(_selectedMonth);

  @override
  void initState() {
    super.initState();
    _loadRates();
  }

  Future<void> _loadRates() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _tauxPatronal =
          prefs.getDouble(_keyTauxPatronal) ?? UrssafRates.totalPatronal;
      _tauxSalarial =
          prefs.getDouble(_keyTauxSalarial) ?? UrssafRates.totalSalarial;
    });
  }

  Future<void> _saveRates() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyTauxPatronal, _tauxPatronal);
    await prefs.setDouble(_keyTauxSalarial, _tauxSalarial);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);

    // Filtrer les chauffeurs actifs (CDI, CDD, intérim)
    final activeDrivers = state.drivers.where((d) =>
        d.status == DriverStatus.cdi ||
        d.status == DriverStatus.cdd ||
        d.status == DriverStatus.interim).toList();

    final totalBrut =
        activeDrivers.fold(0.0, (s, d) => s + d.totalSalary);
    final totalPatronal = totalBrut * _tauxPatronal / 100;
    final totalSalarial = totalBrut * _tauxSalarial / 100;
    final totalCharges = totalPatronal + totalSalarial;
    final coutTotal = totalBrut + totalPatronal; // Coût employeur
    final netApproximatif = totalBrut - totalSalarial;

    // Calcul annuel
    final annuelBrut = totalBrut * 12;
    final annuelCharges = totalCharges * 12;

    return Scaffold(
      appBar: AppBar(
        title: const Text('URSSAF & Charges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Configurer les taux',
            onPressed: _showRatesDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mois
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setState(() {
                      _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month - 1);
                    }),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(_monthLabel,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setState(() {
                      _selectedMonth = DateTime(
                          _selectedMonth.year, _selectedMonth.month + 1);
                    }),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Résumé mensuel ──────────────────────────────────────────
          Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance, color: Colors.blue),
                      const SizedBox(width: 10),
                      const Text('Charges du mois',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${activeDrivers.length} chauffeur${activeDrivers.length > 1 ? 's' : ''}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _summaryLine('Masse salariale brute',
                      '${totalBrut.toStringAsFixed(0)} €'),
                  _summaryLine(
                      'Charges patronales (${_tauxPatronal.toStringAsFixed(1)}%)',
                      '${totalPatronal.toStringAsFixed(0)} €',
                      color: Colors.red),
                  _summaryLine(
                      'Charges salariales (${_tauxSalarial.toStringAsFixed(1)}%)',
                      '${totalSalarial.toStringAsFixed(0)} €',
                      color: Colors.orange),
                  const Divider(height: 20),
                  _summaryLine('Total charges URSSAF',
                      '${totalCharges.toStringAsFixed(0)} €',
                      bold: true, color: Colors.red.shade700),
                  const SizedBox(height: 8),
                  _summaryLine('Coût employeur total',
                      '${coutTotal.toStringAsFixed(0)} €',
                      bold: true),
                  _summaryLine('Net approximatif versé',
                      '${netApproximatif.toStringAsFixed(0)} €',
                      color: Colors.green.shade700),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Projection annuelle ─────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Projection annuelle',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _summaryLine('Masse salariale annuelle',
                      '${annuelBrut.toStringAsFixed(0)} €'),
                  _summaryLine('Charges annuelles',
                      '${annuelCharges.toStringAsFixed(0)} €',
                      color: Colors.red),
                  _summaryLine('Coût employeur annuel',
                      '${(coutTotal * 12).toStringAsFixed(0)} €',
                      bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Taux appliqués ──────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.percent, size: 20),
                      const SizedBox(width: 8),
                      const Text('Taux appliqués',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      TextButton(
                        onPressed: _showRatesDialog,
                        child: const Text('Modifier'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _rateLine('Charges patronales',
                      '${_tauxPatronal.toStringAsFixed(2)}%'),
                  _rateDetail('Maladie', UrssafRates.maladie),
                  _rateDetail('Vieillesse', UrssafRates.vieillesse),
                  _rateDetail('Alloc. familiales', UrssafRates.allocFamiliales),
                  _rateDetail('AT/MP transport', UrssafRates.accidentTravail),
                  _rateDetail('Chômage', UrssafRates.chomagePatronal),
                  _rateDetail('Retraite complémentaire', UrssafRates.retraitePatronal),
                  _rateDetail('FNAL', UrssafRates.fnal),
                  _rateDetail('CSA', UrssafRates.csa),
                  _rateDetail('Formation pro.', UrssafRates.formationPro),
                  const Divider(height: 16),
                  _rateLine('Charges salariales',
                      '${_tauxSalarial.toStringAsFixed(2)}%'),
                  _rateDetail('Vieillesse', UrssafRates.vieillesseSal),
                  _rateDetail('Retraite complémentaire', UrssafRates.retraiteSal),
                  _rateDetail('CSG + CRDS', UrssafRates.csgCrds),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Détail par chauffeur ────────────────────────────────────
          const Text('Détail par chauffeur',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),

          if (activeDrivers.isEmpty)
            const DCEmptyState(
              icon: Icons.person_off_outlined,
              title: 'Aucun chauffeur actif',
              subtitle: 'Ajoutez des chauffeurs en CDI, CDD ou intérim',
            )
          else
            ...activeDrivers.map((d) => _driverCard(d)),

          // Chauffeurs inactifs
          if (state.drivers.any((d) =>
              d.status != DriverStatus.cdi &&
              d.status != DriverStatus.cdd &&
              d.status != DriverStatus.interim)) ...[
            const SizedBox(height: 16),
            Text(
              'Chauffeurs inactifs (non inclus)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: DC.textSecondary),
            ),
            const SizedBox(height: 4),
            ...state.drivers
                .where((d) =>
                    d.status != DriverStatus.cdi &&
                    d.status != DriverStatus.cdd &&
                    d.status != DriverStatus.interim)
                .map((d) => Card(
                      margin: const EdgeInsets.only(bottom: 6),
                      child: ListTile(
                        dense: true,
                        leading: const Icon(Icons.person_off_outlined,
                            color: Colors.grey),
                        title: Text(d.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.grey)),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(driverStatusLabel(d.status),
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey)),
                        ),
                      ),
                    )),
          ],
          const SizedBox(height: 16),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.amber, size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Estimations basées sur les taux configurés. '
                    'Consultez votre comptable pour les montants exacts. '
                    'Les taux varient selon la convention collective et la taille de l\'entreprise.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _driverCard(Driver d) {
    final brut = d.totalSalary;
    final patronal = brut * _tauxPatronal / 100;
    final salarial = brut * _tauxSalarial / 100;
    final coutEmployeur = brut + patronal;
    final netApprox = brut - salarial;

    final Color statusColor;
    switch (d.status) {
      case DriverStatus.cdi:
        statusColor = Colors.green;
        break;
      case DriverStatus.cdd:
        statusColor = Colors.blue;
        break;
      case DriverStatus.interim:
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  child: Text(d.name[0].toUpperCase(),
                      style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(d.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(driverStatusLabel(d.status),
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _miniStat('Brut', '${brut.toStringAsFixed(0)} €', Colors.blue),
                const SizedBox(width: 8),
                _miniStat('Patronales', '${patronal.toStringAsFixed(0)} €',
                    Colors.red),
                const SizedBox(width: 8),
                _miniStat('Salariales', '${salarial.toStringAsFixed(0)} €',
                    Colors.orange),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _miniStat('Coût employeur', '${coutEmployeur.toStringAsFixed(0)} €',
                    Colors.purple),
                const SizedBox(width: 8),
                _miniStat(
                    'Net approx.', '${netApprox.toStringAsFixed(0)} €', Colors.green),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.bold, color: color)),
            Text(label,
                style:
                    TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }

  Widget _summaryLine(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14)),
          ),
          Text(value,
              style: TextStyle(
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  fontSize: bold ? 16 : 14,
                  color: color)),
        ],
      ),
    );
  }

  Widget _rateLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _rateDetail(String label, double rate) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          Text('${rate.toStringAsFixed(2)}%',
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }

  void _showRatesDialog() {
    final patronalCtrl =
        TextEditingController(text: _tauxPatronal.toStringAsFixed(2));
    final salarialCtrl =
        TextEditingController(text: _tauxSalarial.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Taux de charges'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: patronalCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Charges patronales (%)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: salarialCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Charges salariales (%)',
                border: OutlineInputBorder(),
                suffixText: '%',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                patronalCtrl.text =
                    UrssafRates.totalPatronal.toStringAsFixed(2);
                salarialCtrl.text =
                    UrssafRates.totalSalarial.toStringAsFixed(2);
              },
              child: const Text('Réinitialiser (défaut transport)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              patronalCtrl.dispose();
              salarialCtrl.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final p = double.tryParse(
                  patronalCtrl.text.replaceAll(',', '.').trim());
              final s = double.tryParse(
                  salarialCtrl.text.replaceAll(',', '.').trim());
              if (p != null && p >= 0 && s != null && s >= 0) {
                setState(() {
                  _tauxPatronal = p;
                  _tauxSalarial = s;
                });
                _saveRates();
              }
              patronalCtrl.dispose();
              salarialCtrl.dispose();
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}
