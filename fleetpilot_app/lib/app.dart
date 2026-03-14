import 'package:flutter/material.dart';
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
      home: const RoleSelectorPage(),
    );
  }
}