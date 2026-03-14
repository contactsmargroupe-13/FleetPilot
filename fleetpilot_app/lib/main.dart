import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app.dart';
import 'store/app_store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Disable network font fetching (codespace / offline environments)
  GoogleFonts.config.allowRuntimeFetching = false;
  await AppStore.init();
  runApp(const FleetPilotApp());
}
