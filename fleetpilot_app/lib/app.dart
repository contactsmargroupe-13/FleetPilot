import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'providers/app_state.dart';
import 'screens/driver_home.dart';
import 'screens/login_page.dart';
import 'screens/manager_dashboard.dart';
import 'screens/onboarding_page.dart';
import 'screens/role_selector.dart';
import 'screens/models/user_access.dart';
import 'services/auth_service.dart';
import 'services/company_settings.dart';
import 'services/firestore_service.dart';
import 'utils/design_constants.dart';

class FleetPilotApp extends StatelessWidget {
  const FleetPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetPilote',
      debugShowCheckedModeBanner: false,
      theme: DC.theme,
      themeMode: ThemeMode.light,
      home: const _AuthGate(),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          return LoginPage(onLoggedIn: () {});
        }

        return _PostLoginLoader(uid: snapshot.data!.uid);
      },
    );
  }
}

class _PostLoginLoader extends ConsumerStatefulWidget {
  final String uid;
  const _PostLoginLoader({required this.uid});

  @override
  ConsumerState<_PostLoginLoader> createState() => _PostLoginLoaderState();
}

class _PostLoginLoaderState extends ConsumerState<_PostLoginLoader> {
  bool _loading = true;
  bool _showOnboarding = false;
  String? _error;
  AppUser? _appUser;

  @override
  void initState() {
    super.initState();
    _initFirestore();
  }

  Future<void> _initFirestore() async {
    try {
      final appUser = await AuthService.getAppUser(widget.uid);
      final fs = FirestoreService(companyId: appUser.companyId);

      final appState = ref.read(appStateProvider);
      appState.connectFirestore(fs);

      // Connecter les settings company (clé API partagée)
      await CompanySettings.connectCompany(appUser.companyId);

      // Charger les données depuis Firestore (source de vérité)
      await appState.loadFromFirestore(asUser: appUser);

      final show = await OnboardingPage.shouldShow();
      if (mounted) {
        setState(() {
          _appUser = appUser;
          _showOnboarding = show;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48, color: DC.error),
                const SizedBox(height: 16),
                Text('Erreur de chargement', style: DC.title(18)),
                const SizedBox(height: 8),
                Text(_error!, style: DC.body(14, color: DC.textSecondary),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () async {
                    await AuthService.signOut();
                  },
                  child: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_showOnboarding) {
      return OnboardingPage(
        onDone: () => setState(() => _showOnboarding = false),
      );
    }

    // Routing par rôle Firebase
    if (_appUser != null) {
      switch (_appUser!.role) {
        case AccessRole.chauffeur:
          return DriverHomePage(
            firebaseEmail: _appUser!.email,
            firebaseName: _appUser!.name,
          );
        case AccessRole.comptable:
          return ManagerShell(role: AccessRole.comptable);
        case AccessRole.manager:
          return const RoleSelectorPage();
      }
    }

    return const RoleSelectorPage();
  }
}
