import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_state.dart';
import '../utils/design_constants.dart';
import '../utils/page_help.dart';
import '../utils/theme_ctx.dart';
import 'manager_admin.dart';
import 'manager_alerts.dart';
import 'manager_client_pricing.dart';
import 'manager_drivers.dart';
import 'manager_expenses.dart';
import 'manager_messages.dart';
import 'manager_planning.dart';
import 'manager_qr_codes.dart';
import 'manager_result.dart';
import 'manager_settings.dart';
import 'manager_tabs.dart';
import 'depot/depot_page.dart' show ShellNav;
import 'manager_tours.dart';
import 'manager_urssaf.dart';
import 'models/user_access.dart';

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
/// La coquille manager : trois destinations, chacune avec ses sous-onglets.
///
/// Rentabilité — ce que rapporte le transport : résultat, tournées, dépenses,
///   factures. Gestion — le quotidien : aujourd'hui, chauffeurs, camions.
/// Paramètres — ce qu'on règle une fois : commissionnaires, QR, documents.
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
  //
  // Les index de sous-onglets sont ceux de ce catalogue : `_go` les
  // reprojette sur ce que le rôle voit. Toute navigation inter-pages
  // (dépôt, résultat) s'y réfère — les déplacer, c'est les mettre à jour.
  List<_Dest> _catalogue() => [
        _Dest('rentabilite', 'Rentabilité', Icons.trending_up, [
          _Sub('Résultat', 'dashboard',
              (nav) => ManagerResultPage(
                  onNavigate: nav,
                  canReach: _reaches,
                  canEditCompany: _can('parametres')),
              help: ('Résultat',
                  'Ce que le transport a rapporté, ce qu\'il a coûté, ce qu\'il reste.\n\n'
                  '• Tout est en HT, salaires comptés chargés\n'
                  '• Coûts fixes au prorata des jours écoulés\n'
                  '• « Ce qu\'il faut retenir » : les points qui coûtent le plus\n'
                  '• Export comptable en bas de page')),
          _Sub('Tournées', 'tournees', (_) => const ManagerTours()),
          _Sub('Dépenses', 'depenses', (_) => const ManagerExpensesPage(),
              help: ('Dépenses',
                  'Toutes les dépenses de la flotte, TVA comprise.\n\n'
                  '• Saisissez le montant TTC du ticket : le HT est calculé\n'
                  '• Amende : indiquez le chauffeur à désigner\n'
                  '• Un « Entretien » remet à zéro le compteur de vidange')),
          _Sub('Factures', 'facturation', (_) => const InvoicesTab(),
              help: ('Factures',
                  'Le geste de fin de mois, en deux temps.\n\n'
                  '• À facturer : factures calculées d\'après vos tarifs, export PDF\n'
                  '• Relevés reçus : ce que le commissionnaire a vraiment payé\n'
                  '• Au point : saisissez les points du relevé\n'
                  '• L\'écart et les pénalités apparaissent dans le résultat')),
        ]),
        _Dest('gestion', 'Gestion', Icons.local_shipping_outlined, [
          _Sub('Aujourd’hui', 'planning',
              (nav) => ManagerPlanningPage(onNavigate: nav, canReach: _reaches),
              help: ('Aujourd’hui',
                  'Qui roule, qui est absent, ce qui est à traiter.\n\n'
                  '• Un camion sans chauffeur ce jour-là est signalé\n'
                  '• Déclarez congés et arrêts, choisissez un remplaçant\n'
                  '• Changez de jour pour préparer la semaine')),
          _Sub('Chauffeurs', 'chauffeurs',
              (_) => const ManagerDriversPage(embedded: true),
              help: ('Chauffeurs',
                  'Vos chauffeurs, leur camion et leurs documents.\n\n'
                  '• Touchez la ligne camion pour changer l\'affectation\n'
                  '• Salaire brut : les charges sont ajoutées dans le résultat\n'
                  '• Alertes automatiques avant expiration des documents')),
          _Sub('Camions', 'camions', (nav) => TrucksTab(onNavigate: nav),
              help: ('Camions',
                  'Votre parc, en liste ou en plan.\n\n'
                  '• Liste : assurance, contrôle technique, entretien au km\n'
                  '• Plan : la cour vue d\'en haut, qui est parti, qui est à l\'atelier\n'
                  '• Matériel : transpalettes, diables, amortissement')),
        ]),
        _Dest('reglages', 'Paramètres', Icons.tune, [
          _Sub('Commissionnaires', 'commissionnaires',
              (_) => const ManagerClientPricingPage(embedded: true),
              help: ('Commissionnaires',
                  'Vos donneurs d\'ordre et leurs tarifs.\n\n'
                  '• À la fiche : forfait par jour\n'
                  '• Au point : tarif par point livré\n'
                  '• Options : gasoil, manutention, km sup.')),
          _Sub('QR codes', 'parametres', (_) => const ManagerQrCodesPage(),
              help: ('QR codes',
                  'Le démarrage de journée des chauffeurs.\n\n'
                  '• Imprimez un QR code par camion et collez-le en cabine\n'
                  '• Donnez un code PIN à chaque chauffeur\n'
                  '• Le chauffeur scanne, choisit son nom, tape son PIN\n'
                  '• Puis il saisit ses km ou lance le GPS')),
          _Sub('Documents', 'administratif',
              (_) => const ManagerAdminPage(embedded: true),
              help: ('Documents',
                  'Stockez et classez vos documents administratifs.\n\n'
                  '• Contrats chauffeurs, fiches de paie, assurances\n'
                  '• Factures prestataires, contrats de location')),
          _Sub('URSSAF', 'urssaf',
              (_) => const ManagerUrssafPage(embedded: true)),
          _Sub('Entreprise', 'parametres', (_) => const ManagerSettingsPage(),
              help: ('Entreprise',
                  'Votre entreprise et ses accès.\n\n'
                  '• Nom, SIRET, adresse\n'
                  '• Accès comptable\n'
                  '• Clé API pour la lecture des tickets carburant')),
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
        title: DC.logo(size: 20, light: context.isDark),
        actions: [
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
