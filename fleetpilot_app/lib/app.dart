import 'package:flutter/material.dart';
import 'screens/onboarding_page.dart';
import 'screens/role_selector.dart';
import 'utils/design_constants.dart';

class FleetPilotApp extends StatelessWidget {
  const FleetPilotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FleetPilot',
      debugShowCheckedModeBanner: false,
      theme: DC.theme,
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  bool _loading = true;
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final show = await OnboardingPage.shouldShow();
    if (mounted) {
      setState(() {
        _showOnboarding = show;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_showOnboarding) {
      return OnboardingPage(
        onDone: () => setState(() => _showOnboarding = false),
      );
    }

    return const RoleSelectorPage();
  }
}
