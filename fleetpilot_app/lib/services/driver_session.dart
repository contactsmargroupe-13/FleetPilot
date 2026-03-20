import 'package:shared_preferences/shared_preferences.dart';

class DriverSession {
  static const _keyDriverName = 'session_driver_name';
  static const _keyTourStart = 'session_tour_start_ms';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  // ── Profil chauffeur ────────────────────────────────────────────────────────

  static String? get driverName => _prefs?.getString(_keyDriverName);

  static Future<void> setDriverName(String name) async {
    await _prefs?.setString(_keyDriverName, name);
  }

  static Future<void> clearDriverName() async {
    await _prefs?.remove(_keyDriverName);
  }

  // ── Tournée en cours ────────────────────────────────────────────────────────

  static DateTime? get tourStartTime {
    final ms = _prefs?.getInt(_keyTourStart);
    return ms != null ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  static Future<void> startTour() async {
    await _prefs?.setInt(
        _keyTourStart, DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> endTour() async {
    await _prefs?.remove(_keyTourStart);
  }

  // ── GPS tracking ──────────────────────────────────────────────────────────

  static const _keyGpsEnabled = 'session_gps_enabled';

  /// True si le chauffeur a activé le suivi GPS
  static bool get isGpsEnabled => _prefs?.getBool(_keyGpsEnabled) ?? true;

  static Future<void> setGpsEnabled(bool enabled) async {
    await _prefs?.setBool(_keyGpsEnabled, enabled);
  }
}
