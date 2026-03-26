import 'dart:async';
import 'dart:io';

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GpsTrackingService {
  // ── Filtres (optimisés livraison urbaine) ────────────────────────────────
  static const double _minSpeedMs = 0.56; // 2 km/h — inclut manoeuvres lentes, exclut marche à pied
  static const double _maxAccuracyM = 40.0; // ignorer si précision > 40m
  static const double _maxJumpM = 500.0; // ignorer les sauts GPS > 500m
  static const double _minDistanceM = 5.0; // ignorer micro-mouvements < 5m (bruit GPS à l'arrêt)

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

  // ── Settings cross-platform (optimisés batterie) ───────────────────────────

  LocationSettings _buildSettings() {
    if (Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10m — bon compromis livraison urbaine / batterie
        intervalDuration: const Duration(seconds: 5), // 5s pour capter les courts trajets
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'FleetPilote — Tournée en cours',
          notificationText: 'Suivi kilométrique actif',
          enableWakeLock: false, // pas de wakelock = économie batterie
        ),
      );
    } else if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: true, // iOS pause auto si immobile
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true, // flèche bleue iOS
      );
    } else {
      // Web / desktop fallback
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );
    }
  }

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

    // Démarrer le stream — compatible iOS + Android + Web
    _positionSub = Geolocator.getPositionStream(
      locationSettings: _buildSettings(),
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

    _positionSub = Geolocator.getPositionStream(
      locationSettings: _buildSettings(),
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

      // Filtre 4 : micro-mouvement (bruit GPS à l'arrêt)
      if (distanceM < _minDistanceM) return;

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
