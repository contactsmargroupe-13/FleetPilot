import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/design_constants.dart';

class OnboardingPage extends StatefulWidget {
  final VoidCallback onDone;
  const OnboardingPage({super.key, required this.onDone});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();

  /// Vérifie si l'onboarding a déjà été vu
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('onboarding_done') ?? false);
  }

  /// Marque l'onboarding comme vu
  static Future<void> markDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_done', true);
  }
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _pages = <_OnboardingStep>[
    _OnboardingStep(
      icon: Icons.local_shipping_rounded,
      color: Color(0xFF10B981),
      title: 'Espace Chauffeur',
      points: [
        'Sélectionnez votre profil avec votre code PIN',
        'Démarrez votre tournée — le GPS compte les km automatiquement',
        'Saisissez vos colis/fiches et ramasses en fin de journée',
        'Votre camion et commissionnaire sont pré-remplis par le manager',
      ],
    ),
    _OnboardingStep(
      icon: Icons.dashboard_rounded,
      color: Color(0xFF3B82F6),
      title: 'Espace Manager',
      points: [
        'Dashboard : vue globale des revenus, dépenses et rentabilité',
        'Flotte : affectez chauffeurs et camions par commissionnaire',
        'Tournées : suivez l\'activité de chaque chauffeur en temps réel',
        'Planning : organisez les tournées de la semaine',
      ],
    ),
    _OnboardingStep(
      icon: Icons.handshake_rounded,
      color: Color(0xFF8B5CF6),
      title: 'Commissionnaires',
      points: [
        'Ajoutez vos commissionnaires avec leurs tarifs',
        'Mode "À la fiche" : forfait journalier et/ou tarif par fiche',
        'Mode "Au point" : forfait journalier et/ou tarif par colis',
        'Chaque commissionnaire a sa couleur pour s\'y retrouver',
      ],
    ),
    _OnboardingStep(
      icon: Icons.local_shipping_outlined,
      color: Color(0xFF0EA5E9),
      title: 'Camions & Matériel',
      points: [
        'Gérez votre flotte : immatriculation, modèle, assurance, CT',
        'Affectez du matériel à chaque camion (transpalette, etc.)',
        'Alertes automatiques quand l\'assurance ou le CT expire',
        'Suivi des km et tournées par véhicule',
      ],
    ),
    _OnboardingStep(
      icon: Icons.receipt_long_rounded,
      color: Color(0xFFF59E0B),
      title: 'Finances',
      points: [
        'Dépenses : carburant, péages, réparations, avec scan OCR',
        'Facturation : génération automatique selon les tournées',
        'URSSAF & Charges : suivi des cotisations et charges',
        'Actifs : amortissement de vos véhicules et matériel',
      ],
    ),
    _OnboardingStep(
      icon: Icons.people_rounded,
      color: Color(0xFFEC4899),
      title: 'Équipe & Accès',
      points: [
        'Chauffeurs : profils, documents, permis, FIMO/FCO',
        'Recrutement : recevez les candidatures directement',
        'Accès : invitez un comptable avec des droits limités',
        'Messages : communiquez avec vos chauffeurs',
      ],
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    OnboardingPage.markDone();
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DC.background,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: TextButton(
                  onPressed: _finish,
                  child: Text('Passer',
                      style: DC.body(14, color: DC.textSecondary)),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),

            // Indicateurs + bouton
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Column(
                children: [
                  // Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_pages.length, (i) {
                      final active = i == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: active ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: active
                              ? _pages[_currentPage].color
                              : DC.surface3,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),

                  // Bouton
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: _pages[_currentPage].color,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(DC.rButton),
                        ),
                      ),
                      child: Text(
                        _currentPage < _pages.length - 1
                            ? 'Suivant'
                            : 'C\'est parti !',
                        style: DC.body(16, weight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardingStep step) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icône
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: step.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(step.icon, size: 40, color: step.color),
          ),
          const SizedBox(height: 24),

          // Titre
          Text(
            step.title,
            style: DC.title(24, color: step.color),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Points
          ...step.points.map((point) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: step.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        point,
                        style: DC.body(14, color: DC.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _OnboardingStep {
  final IconData icon;
  final Color color;
  final String title;
  final List<String> points;

  const _OnboardingStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.points,
  });
}
