import 'dart:convert';
import 'dart:developer' as dev;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CompanySettings {
  static const _keyName = 'company_name';
  static const _keyAddress = 'company_address';
  static const _keySiret = 'company_siret';
  static const _keyPhone = 'company_phone';
  static const _keyEmail = 'company_email';
  static const _keyTvaIntra = 'company_tva_intra';
  static const _keyManagerPinHash = 'manager_pin_hash';

  // Secure storage for API key (local fallback)
  static const _secureKeyClaudeApiKey = 'claude_api_key';
  static const _secureStorage = FlutterSecureStorage();

  static SharedPreferences? _prefs;

  // Cached API key (loaded once at init)
  static String _claudeApiKey = '';

  // Company ID for Firestore (set after login)
  static String? _companyId;

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;

    // Migrate plaintext API key from SharedPreferences to secure storage
    await _migrateApiKey(prefs);

    // Migrate plaintext PIN to hashed PIN
    _migratePinToHash(prefs);

    // Load API key from secure storage (local fallback)
    _claudeApiKey = await _secureStorage.read(key: _secureKeyClaudeApiKey) ?? '';
    dev.log('[CompanySettings] init: local key=${_claudeApiKey.isEmpty ? "VIDE" : "sk-...${_claudeApiKey.substring(_claudeApiKey.length - 4)}"}');
  }

  /// Connecte les settings à la company Firestore (appelé après login)
  static Future<void> connectCompany(String companyId) async {
    _companyId = companyId;

    // 1. Clé globale du fondateur (partagée avec tous les utilisateurs)
    try {
      final globalDoc = await FirebaseFirestore.instance
          .collection('config')
          .doc('global')
          .get();
      dev.log('[CompanySettings] Firestore config/global exists=${globalDoc.exists}');
      if (globalDoc.exists) {
        final globalData = globalDoc.data() ?? {};
        dev.log('[CompanySettings] config/global fields: ${globalData.keys.toList()}');
        // Cherche le champ clé API (insensible à la casse du champ)
        for (final entry in globalData.entries) {
          if (entry.key.toLowerCase().contains('apikey') ||
              entry.key.toLowerCase().contains('api_key') ||
              entry.key.toLowerCase().contains('claude')) {
            final val = entry.value?.toString() ?? '';
            dev.log('[CompanySettings] Found key field "${entry.key}" → starts with sk-: ${val.startsWith("sk-")}');
            if (val.startsWith('sk-')) {
              _claudeApiKey = val;
              dev.log('[CompanySettings] ✓ API key loaded from config/global');
              return;
            }
          }
        }
        dev.log('[CompanySettings] ✗ No valid API key in config/global');
      }
    } catch (e) {
      dev.log('[CompanySettings] Error reading config/global: $e');
    }

    // 2. Fallback : clé API spécifique à la company
    try {
      final doc = await FirebaseFirestore.instance
          .collection('companies')
          .doc(companyId)
          .get();
      if (doc.exists) {
        final data = doc.data() ?? {};
        for (final entry in data.entries) {
          if (entry.key.toLowerCase().contains('apikey') ||
              entry.key.toLowerCase().contains('api_key') ||
              entry.key.toLowerCase().contains('claude')) {
            final val = entry.value?.toString() ?? '';
            if (val.startsWith('sk-')) {
              _claudeApiKey = val;
              return;
            }
          }
        }
      }
    } catch (_) {}
  }

  /// Migrate plaintext API key → FlutterSecureStorage (one-time)
  static Future<void> _migrateApiKey(SharedPreferences prefs) async {
    final oldKey = prefs.getString('claude_api_key');
    if (oldKey != null && oldKey.isNotEmpty) {
      await _secureStorage.write(key: _secureKeyClaudeApiKey, value: oldKey);
      await prefs.remove('claude_api_key');
    }
  }

  /// Migrate plaintext PIN → SHA-256 hash (one-time)
  static void _migratePinToHash(SharedPreferences prefs) {
    final oldPin = prefs.getString('manager_pin');
    if (oldPin != null && oldPin.isNotEmpty) {
      final hash = _hashPin(oldPin);
      prefs.setString(_keyManagerPinHash, hash);
      prefs.remove('manager_pin');
    }
  }

  static String get name => _prefs?.getString(_keyName) ?? '';
  static String get address => _prefs?.getString(_keyAddress) ?? '';
  static String get siret => _prefs?.getString(_keySiret) ?? '';
  static String get phone => _prefs?.getString(_keyPhone) ?? '';
  static String get email => _prefs?.getString(_keyEmail) ?? '';
  static String get tvaIntra => _prefs?.getString(_keyTvaIntra) ?? '';
  static String get claudeApiKey => _claudeApiKey;
  static bool get hasPinSet =>
      (_prefs?.getString(_keyManagerPinHash) ?? '').isNotEmpty;

  static Future<void> save({
    required String name,
    required String address,
    required String siret,
    required String phone,
    required String email,
    required String tvaIntra,
  }) async {
    await _prefs!.setString(_keyName, name);
    await _prefs!.setString(_keyAddress, address);
    await _prefs!.setString(_keySiret, siret);
    await _prefs!.setString(_keyPhone, phone);
    await _prefs!.setString(_keyEmail, email);
    await _prefs!.setString(_keyTvaIntra, tvaIntra);
  }

  static Future<void> saveClaudeApiKey(String key) async {
    await _secureStorage.write(key: _secureKeyClaudeApiKey, value: key);
    _claudeApiKey = key;

    // Sauver dans Firestore pour toute l'équipe
    if (_companyId != null) {
      try {
        await FirebaseFirestore.instance
            .collection('companies')
            .doc(_companyId)
            .update({'claudeApiKey': key});
      } catch (_) {}
    }
  }

  static Future<void> saveManagerPin(String pin) async {
    await _prefs!.setString(_keyManagerPinHash, _hashPin(pin));
  }

  static Future<void> removeManagerPin() async {
    await _prefs!.remove(_keyManagerPinHash);
  }

  static bool checkPin(String pin) {
    final storedHash = _prefs?.getString(_keyManagerPinHash) ?? '';
    if (storedHash.isEmpty) return false;
    return _hashPin(pin) == storedHash;
  }

  /// SHA-256 hash of the PIN
  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }
}
