import 'package:shared_preferences/shared_preferences.dart';

class CompanySettings {
  static const _keyName = 'company_name';
  static const _keyAddress = 'company_address';
  static const _keySiret = 'company_siret';
  static const _keyPhone = 'company_phone';
  static const _keyEmail = 'company_email';
  static const _keyClaudeApiKey = 'claude_api_key';
  static const _keyManagerPin = 'manager_pin';

  static SharedPreferences? _prefs;

  static Future<void> init(SharedPreferences prefs) async {
    _prefs = prefs;
  }

  static String get name => _prefs?.getString(_keyName) ?? '';
  static String get address => _prefs?.getString(_keyAddress) ?? '';
  static String get siret => _prefs?.getString(_keySiret) ?? '';
  static String get phone => _prefs?.getString(_keyPhone) ?? '';
  static String get email => _prefs?.getString(_keyEmail) ?? '';
  static String get claudeApiKey => _prefs?.getString(_keyClaudeApiKey) ?? '';
  static String get managerPin => _prefs?.getString(_keyManagerPin) ?? '';
  static bool get hasPinSet => managerPin.isNotEmpty;

  static Future<void> save({
    required String name,
    required String address,
    required String siret,
    required String phone,
    required String email,
  }) async {
    await _prefs!.setString(_keyName, name);
    await _prefs!.setString(_keyAddress, address);
    await _prefs!.setString(_keySiret, siret);
    await _prefs!.setString(_keyPhone, phone);
    await _prefs!.setString(_keyEmail, email);
  }

  static Future<void> saveClaudeApiKey(String key) async {
    await _prefs!.setString(_keyClaudeApiKey, key);
  }

  static Future<void> saveManagerPin(String pin) async {
    await _prefs!.setString(_keyManagerPin, pin);
  }

  static Future<void> removeManagerPin() async {
    await _prefs!.remove(_keyManagerPin);
  }

  static bool checkPin(String pin) => pin == managerPin;
}
