import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app.dart';
import 'providers/app_state.dart';
import 'services/database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final db = await DatabaseService.init();
  final appState = AppState(db);
  await appState.init();

  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        appStateProvider.overrideWith((_) => appState),
      ],
      child: const FleetPilotApp(),
    ),
  );
}
