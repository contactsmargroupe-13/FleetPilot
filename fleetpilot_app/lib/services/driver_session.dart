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

  // ── Dernière tournée (persistance entre tournées) ─────────────────────

  static const _keyLastTourNumber = 'session_last_tour_number';
  static const _keyLastCompany = 'session_last_company';

  static String? get lastTourNumber => _prefs?.getString(_keyLastTourNumber);
  static String? get lastCompany => _prefs?.getString(_keyLastCompany);

  static Future<void> saveLastTour(String tourNumber, String company) async {
    await _prefs?.setString(_keyLastTourNumber, tourNumber);
    await _prefs?.setString(_keyLastCompany, company);
  }

  // ── QR code du camion ─────────────────────────────────────────────────

  static const _keyPendingTruck = 'session_pending_truck';
  static const _keyLastQr = 'session_last_qr_key';

  /// Camion du QR scanné, à présélectionner à l'ouverture de la journée.
  static String? get pendingTruck => _prefs?.getString(_keyPendingTruck);

  static Future<void> setPendingTruck(String? plate) async {
    if (plate == null) {
      await _prefs?.remove(_keyPendingTruck);
    } else {
      await _prefs?.setString(_keyPendingTruck, plate);
    }
  }

  /// Dernière clé QR scannée sur ce téléphone : après une déconnexion, on
  /// repropose la liste des chauffeurs plutôt que l'écran email / mot de passe.
  static String? get lastQrKey => _prefs?.getString(_keyLastQr);

  static Future<void> setLastQrKey(String? key) async {
    if (key == null) {
      await _prefs?.remove(_keyLastQr);
    } else {
      await _prefs?.setString(_keyLastQr, key);
    }
  }

  // ── Mode de la journée en cours ──────────────────────────────────────

  static const _keyDayMode = 'session_day_mode';
  static const _keyStartKm = 'session_start_km';

  /// 'gps' ou 'compteur' ; null hors journée.
  static String? get dayMode => _prefs?.getString(_keyDayMode);

  /// Compteur relevé au départ (mode 'compteur').
  static int? get startKm => _prefs?.getInt(_keyStartKm);

  static Future<void> setDay({required String mode, int? startKm}) async {
    await _prefs?.setString(_keyDayMode, mode);
    if (startKm != null) {
      await _prefs?.setInt(_keyStartKm, startKm);
    } else {
      await _prefs?.remove(_keyStartKm);
    }
  }

  static Future<void> clearDay() async {
    await _prefs?.remove(_keyDayMode);
    await _prefs?.remove(_keyStartKm);
  }
}
