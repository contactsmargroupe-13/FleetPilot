import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GpsTrackingService {
  // ── Filtres ────────────────────────────────────────────────────────────────
  static const double _minSpeedMs = 1.39; // 5 km/h en m/s
  static const double _maxAccuracyM = 50.0; // ignorer si précision > 50m
  static const double _maxJumpM = 500.0; // ignorer les sauts GPS > 500m

  // ── Persistance (crash recovery) ───────────────────────────────────────────
  static const _keyCumulativeKm = 'gps_cumulative_km';
  static const _keyTrackingActive = 'gps_tracking_active';

  // ── État ────────────────────────────────────────────────────────────────────
  double _cumulativeKm = 0.0;
  Position? _lastValidPosition;
  StreamSubscription<Position>? _positionSub;
  bool _isTracking = false;

  // Callback pour notifier l'UI du km mis à jour
  void Function(double km)? onKmUpdate;

  double get currentKm => _cumulativeKm;
  bool get isTracking => _isTracking;

  // ── Singleton ──────────────────────────────────────────────────────────────
  static final GpsTrackingService _instance = GpsTrackingService._();
  factory GpsTrackingService() => _instance;
  GpsTrackingService._();

  // ── Démarrer le tracking ───────────────────────────────────────────────────

  Future<bool> startTracking() async {
    if (_isTracking) return true;

    // Vérifier que le GPS est activé
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    // Vérifier les permissions
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    // Reset
    _cumulativeKm = 0.0;
    _lastValidPosition = null;

    // Persister l'état "tracking actif"
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyTrackingActive, true);
    await prefs.setDouble(_keyCumulativeKm, 0.0);

    // Configurer le stream de positions
    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // callback seulement si déplacement > 10m
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'FleetPilot — Tournée en cours',
        notificationText: 'Suivi kilométrique actif',
        enableWakeLock: false,
      ),
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPosition);

    _isTracking = true;
    return true;
  }

  // ── Reprendre après crash/restart ──────────────────────────────────────────

  Future<bool> resumeIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final wasActive = prefs.getBool(_keyTrackingActive) ?? false;
    if (!wasActive) return false;

    _cumulativeKm = prefs.getDouble(_keyCumulativeKm) ?? 0.0;
    _lastValidPosition = null;

    final locationSettings = AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
      intervalDuration: const Duration(seconds: 5),
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'FleetPilot — Tournée en cours',
        notificationText: 'Suivi kilométrique actif',
        enableWakeLock: false,
      ),
    );

    _positionSub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(_onPosition);

    _isTracking = true;
    onKmUpdate?.call(_cumulativeKm);
    return true;
  }

  // ── Arrêter le tracking ────────────────────────────────────────────────────

  Future<double> stopTracking() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _isTracking = false;
    _lastValidPosition = null;

    final totalKm = _cumulativeKm;

    // Nettoyer la persistance
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCumulativeKm);
    await prefs.remove(_keyTrackingActive);

    _cumulativeKm = 0.0;
    return totalKm;
  }

  // ── Traitement de chaque position GPS ──────────────────────────────────────

  void _onPosition(Position position) {
    // Filtre 1 : précision trop faible
    if (position.accuracy > _maxAccuracyM) return;

    // Filtre 2 : vitesse trop basse (arrêt livraison, marche, bruit GPS)
    if (position.speed >= 0 && position.speed < _minSpeedMs) return;

    if (_lastValidPosition != null) {
      // Calculer la distance depuis le dernier point valide
      final distanceM = Geolocator.distanceBetween(
        _lastValidPosition!.latitude,
        _lastValidPosition!.longitude,
        position.latitude,
        position.longitude,
      );

      // Filtre 3 : saut GPS aberrant
      if (distanceM > _maxJumpM) {
        _lastValidPosition = position;
        return;
      }

      // Accumuler
      _cumulativeKm += distanceM / 1000.0;

      // Persister (fire & forget pour ne pas bloquer)
      _persistKm();

      // Notifier l'UI
      onKmUpdate?.call(_cumulativeKm);
    }

    _lastValidPosition = position;
  }

  // ── Persistance km ─────────────────────────────────────────────────────────

  Future<void> _persistKm() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyCumulativeKm, _cumulativeKm);
  }
}
