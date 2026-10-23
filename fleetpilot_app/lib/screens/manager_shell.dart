import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import '../utils/page_help.dart';
import '../utils/theme_ctx.dart';
import 'depot/depot_page.dart';
import 'manager_admin.dart';
import 'manager_ai_chat.dart';
import 'manager_ai_report.dart';
import 'manager_alerts.dart';
import 'manager_assets.dart';
import 'manager_assignments.dart';
import 'manager_billing.dart';
import 'manager_client_pricing.dart';
import 'manager_dashboard.dart';
import 'manager_drivers.dart';
import 'manager_equipment.dart';
import 'manager_expenses.dart';
import 'manager_home.dart';
import 'manager_messages.dart';
import 'manager_planning.dart';
import 'manager_recruitment.dart';
import 'manager_settings.dart';
import 'manager_tours.dart';
import 'manager_urssaf.dart';
import 'manager_vehicles.dart';
import 'models/user_access.dart';
import 'smart_scan_page.dart';

/// Un sous-onglet d'une destination. `page` est la clé de `rolePages` :
/// c'est elle qui décide si le rôle courant y a droit.
class _Sub {
  final String label;
  final String page;
  final Widget Function(ShellNav nav) build;
  final (String, String)? help;
  const _Sub(this.label, this.page, this.build, {this.help});
}

class _Dest {
  final String id, label;
  final IconData icon;
  final List<_Sub> subs;
  const _Dest(this.id, this.label, this.icon, this.subs);
}

/// ─────────────────────────────────────────────────────────────────────────
/// La coquille manager : cinq destinations, chacune avec ses sous-onglets.
///
/// Remplace le tiroir latéral de dix-sept entrées doublé d'une barre de trois
/// onglets. Aucune page n'a disparu : elles sont devenues des sous-onglets.
/// ─────────────────────────────────────────────────────────────────────────
class ManagerShell extends ConsumerStatefulWidget {
  final AccessRole role;
  const ManagerShell({super.key, this.role = AccessRole.manager});

  @override
  ConsumerState<ManagerShell> createState() => _ManagerShellState();
}

class _ManagerShellState extends ConsumerState<ManagerShell>
    with TickerProviderStateMixin {
  late final List<_Dest> _dests;
  late final List<List<int>> _tabMap; // index d'origine → index après filtrage
  late final List<TabController> _tabs;

  int _index = 0;
  final Set<int> _visited = {0};

  @override
  void initState() {
    super.initState();

    final allowed = rolePages[widget.role] ?? const <String>{};
    final full = _catalogue();

    _dests = [];
    _tabMap = [];
    for (final d in full) {
      final kept = <_Sub>[];
      final map = <int>[];
      for (final s in d.subs) {
        if (allowed.contains(s.page)) {
          map.add(kept.length);
          kept.add(s);
        } else {
          map.add(-1);
        }
      }
      if (kept.isEmpty) continue;
      _dests.add(_Dest(d.id, d.label, d.icon, kept));
      _tabMap.add(map);
    }

    _tabs = [
      for (final d in _dests) TabController(length: d.subs.length, vsync: this),
    ];
    for (final c in _tabs) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in _tabs) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Catalogue complet, avant filtrage par rôle ────────────────────────
  List<_Dest> _catalogue() => [
        _Dest('accueil', 'Accueil', Icons.home_outlined, [
          _Sub('Résumé', 'dashboard',
              (nav) => ManagerHomePage(onNavigate: nav, canReach: _reaches)),
          _Sub('Analyse', 'dashboard', (_) => const ManagerDashboardPage()),
        ]),
        _Dest('depot', 'Dépôt', Icons.warehouse_outlined, [
          _Sub('La cour', 'camions', (nav) => DepotPage(onNavigate: nav),
              help: ('La cour',
                  'Votre dépôt vu d\'en haut : chaque emplacement est une place réelle.\n\n'
                  '• Un camion en tournée est en pointillés — la place est vide\n'
                  '• Un immobilisé est rouge et garé devant l\'atelier\n'
                  '• Une échéance proche porte une épingle jaune\n'
                  '• Touchez un bâtiment pour ouvrir la rubrique correspondante')),
          _Sub('Camions', 'camions', (_) => const ManagerVehiclesPage(),
              help: ('Camions',
                  'Gérez votre parc de véhicules.\n\n'
                  '• Ajoutez vos camions avec immatriculation et modèle\n'
                  '• Suivez assurance et contrôle technique\n'
                  '• Affectez du matériel (transpalette, etc.)\n'
                  '• Consultez les tournées par camion')),
          _Sub('Matériel', 'materiel',
              (_) => const ManagerEquipmentPage(embedded: true),
              help: ('Matériel',
                  'Gérez le matériel et son amortissement.\n\n'
                  '• Ajoutez transpalettes, outils, informatique...\n'
                  '• Suivez l\'amortissement et la valeur résiduelle\n'
                  '• Affectez le matériel à un camion depuis l\'onglet Camions')),
        ]),
        _Dest('journee', 'Journée', Icons.today_outlined, [
          _Sub('Planning', 'planning', (_) => const ManagerPlanningPage()),
          _Sub('Tournées', 'tournees', (_) => const ManagerTours()),
          _Sub('Affectations', 'flotte',
              (_) => const ManagerAssignmentsPage(embedded: true),
              help: ('Affectations',
                  'Organisez votre flotte par commissionnaire.\n\n'
                  '• Chaque commissionnaire regroupe ses chauffeurs et camions\n'
                  '• Appuyez sur + pour ajouter un chauffeur\n'
                  '• Appuyez sur un chauffeur pour modifier son affectation\n'
                  '• Les tarifs du commissionnaire sont affichés sur chaque carte')),
        ]),
        _Dest('argent', 'Argent', Icons.euro_outlined, [
          _Sub('Dépenses', 'depenses', (_) => const ManagerExpensesPage(),
              help: ('Dépenses',
                  'Suivez toutes les dépenses de votre flotte.\n\n'
                  '• Carburant, péages, réparations, amendes\n'
                  '• Scan OCR pour saisir une facture en photo\n'
                  '• Filtrez par camion, type ou période')),
          _Sub('Facturation', 'facturation', (_) => const ManagerBillingPage(),
              help: ('Facturation',
                  'Générez vos factures automatiquement.\n\n'
                  '• Basé sur les tournées saisies par les chauffeurs\n'
                  '• Calcul automatique selon le tarif commissionnaire\n'
                  '• Export PDF pour envoi')),
          _Sub('URSSAF', 'urssaf',
              (_) => const ManagerUrssafPage(embedded: true)),
          _Sub('Actifs', 'actifs',
              (_) => const ManagerAssetsPage(embedded: true),
              help: ('Actifs',
                  'Vue d\'ensemble de vos actifs et amortissements.\n\n'
                  '• Valeur totale de vos camions et matériel\n'
                  '• Suivi de l\'amortissement mensuel\n'
                  '• Coût mensuel par véhicule (achat ou location)')),
          _Sub('Commissionnaires', 'commissionnaires',
              (_) => const ManagerClientPricingPage(embedded: true),
              help: ('Commissionnaires',
                  'Configurez vos commissionnaires et leurs tarifs.\n\n'
                  '• À la fiche : forfait journalier et/ou tarif par fiche\n'
                  '• Au point : forfait journalier et/ou tarif par colis\n'
                  '• Ajoutez les options : gasoil, manutention, km sup.\n'
                  '• Attribuez une couleur pour identifier rapidement')),
        ]),
        _Dest('equipe', 'Équipe', Icons.groups_outlined, [
          _Sub('Chauffeurs', 'chauffeurs',
              (_) => const ManagerDriversPage(embedded: true),
              help: ('Chauffeurs',
                  'Gérez vos chauffeurs et leurs documents.\n\n'
                  '• Ajoutez un chauffeur avec son statut (CDI, CDD, Intérim)\n'
                  '• Suivez les documents : permis, FIMO, FCO, carte conducteur\n'
                  '• Alertes automatiques avant expiration')),
          _Sub('Recrutement', 'recrutement',
              (_) => const ManagerRecruitmentPage(embedded: true),
              help: ('Recrutement',
                  'Suivez vos candidatures et embauches.\n\n'
                  '• Les candidats postulent depuis la page d\'accueil\n'
                  '• Faites avancer le statut : candidature → entretien → embauché\n'
                  '• Convertissez un candidat en chauffeur en un clic')),
          _Sub('Administratif', 'administratif',
              (_) => const ManagerAdminPage(embedded: true),
              help: ('Administratif',
                  'Stockez et classez vos documents administratifs.\n\n'
                  '• Contrats chauffeurs, fiches de paie, assurances\n'
                  '• Factures prestataires, contrats de location\n'
                  '• Filtrez par catégorie pour retrouver rapidement')),
        ]),
      ];

  // ── Navigation ────────────────────────────────────────────────────────
  void _go(String destination, {int tab = 0}) {
    if (destination == 'messages') {
      Navigator.push(context,
          MaterialPageRoute(builder: (_) => const ManagerMessagesPage()));
      return;
    }
    final i = _dests.indexWhere((d) => d.id == destination);
    if (i < 0) return;

    // `tab` désigne un sous-onglet du catalogue complet : on le reprojette
    // sur la liste effectivement visible pour le rôle courant.
    final map = _tabMap[i];
    final target = (tab >= 0 && tab < map.length && map[tab] >= 0) ? map[tab] : 0;

    setState(() {
      _index = i;
      _visited.add(i);
    });
    _tabs[i].animateTo(target);
  }

  bool _can(String page) => rolePages[widget.role]?.contains(page) ?? false;

  bool _reaches(String destination) =>
      destination == 'messages'
          ? _can('messages')
          : _dests.any((d) => d.id == destination);

  void _openAi() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.cSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.cSurface3,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 14),
            _aiTile(Icons.auto_awesome, 'Assistant',
                'Posez une question sur votre flotte',
                () => const ManagerAiChatPage()),
            _aiTile(Icons.document_scanner_outlined, 'Scan intelligent',
                'Photographiez une facture, les champs se remplissent',
                () => const SmartScanPage()),
            _aiTile(Icons.analytics_outlined, 'Rapport',
                'Synthèse du mois rédigée à partir de vos données',
                () => const ManagerAiReportPage()),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _aiTile(IconData icon, String title, String sub, Widget Function() page) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.cPrimaryBg,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 20, color: DC.primary),
      ),
      title: Text(title, style: context.tBody(15, w: FontWeight.w600)),
      subtitle: Text(sub, style: context.tBody(12.5, color: context.cInk2)),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => page()));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateProvider);
    final alerts = state.pendingManagerAlertCount;
    final unread = state.unreadManagerMessages;

    final dest = _dests[_index];
    final ctrl = _tabs[_index];
    final help = dest.subs[ctrl.index.clamp(0, dest.subs.length - 1)].help;

    return Scaffold(
      appBar: AppBar(
        title: DC.logo(size: 20),
        actions: [
          if (_can('ia_chat'))
            IconButton(
              icon: const Icon(Icons.auto_awesome),
              tooltip: 'Assistant IA',
              onPressed: _openAi,
            ),
          if (_can('messages'))
            IconButton(
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                child: const Icon(Icons.chat_outlined),
              ),
              tooltip: 'Messages',
              onPressed: () => _go('messages'),
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: alerts > 0,
              label: Text('$alerts'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Alertes',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ManagerAlertsPage())),
          ),
          PopupMenuButton<String>(
            tooltip: 'Plus',
            onSelected: (v) {
              if (v == 'aide' && help != null) {
                showPageHelp(context, help.$1, help.$2);
              } else if (v == 'reglages') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(
                        title: const Text('Paramètres'),
                        actions: [
                          Builder(
                            builder: (ctx) => helpButton(ctx, 'Paramètres',
                                'Configurez votre entreprise et vos accès.\n\n'
                                '• Infos entreprise : nom, SIRET, adresse\n'
                                '• Code PIN manager pour protéger l\'accès\n'
                                '• Créez des accès limités (ex: comptable)\n'
                                '• Clé API pour l\'assistant IA'),
                          ),
                        ],
                      ),
                      body: const ManagerSettingsPage(),
                    ),
                  ),
                );
              } else if (v == 'sortie') {
                Navigator.of(context).popUntil((r) => r.isFirst);
              }
            },
            itemBuilder: (_) => [
              if (help != null)
                PopupMenuItem(
                  value: 'aide',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_outline_rounded, size: 20),
                    title: Text('À quoi sert « ${help.$1} » ?'),
                  ),
                ),
              if (_can('parametres'))
                const PopupMenuItem(
                  value: 'reglages',
                  child: ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.settings_outlined, size: 20),
                    title: Text('Paramètres'),
                  ),
                ),
              const PopupMenuItem(
                value: 'sortie',
                child: ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.logout, size: 20, color: DC.error),
                  title: Text('Retour accueil'),
                ),
              ),
            ],
          ),
        ],
        bottom: dest.subs.length > 1
            ? TabBar(
                controller: ctrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                dividerColor: context.cBorder,
                tabs: [for (final s in dest.subs) Tab(text: s.label)],
              )
            : null,
      ),
      body: IndexedStack(
        index: _index,
        children: [
          for (var i = 0; i < _dests.length; i++)
            if (_visited.contains(i))
              TabBarView(
                controller: _tabs[i],
                children: [for (final s in _dests[i].subs) s.build(_go)],
              )
            else
              const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: [
          for (final d in _dests)
            NavigationDestination(icon: Icon(d.icon), label: d.label),
        ],
      ),
    );
  }
}
