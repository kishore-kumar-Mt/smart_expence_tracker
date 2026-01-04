import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

enum AuthMethod { none, pin, biometric }

class AuthService extends ChangeNotifier {
  static final AuthService instance = AuthService._init();
  factory AuthService() => instance;
  AuthService._init();

  static const String _keyIsSetupComplete = 'is_auth_setup_complete';
  static const String _keyAuthMethod = 'auth_method';
  static const String _keyAppPin = 'app_pin';

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  bool get isSetupComplete => _prefs.getBool(_keyIsSetupComplete) ?? false;

  AuthMethod get authMethod {
    final method = _prefs.getString(_keyAuthMethod);
    if (method == 'biometric') return AuthMethod.biometric;
    if (method == 'pin') return AuthMethod.pin;
    return AuthMethod.none;
  }

  String? get _storedPin => _prefs.getString(_keyAppPin);

  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();
    _isInitialized = true;
  }

  Future<void> setBiometricEnabled() async {
    await _prefs.setBool(_keyIsSetupComplete, true);
    await _prefs.setString(_keyAuthMethod, 'biometric');
    await _prefs.remove(_keyAppPin);
    notifyListeners();
  }

  Future<void> setAppPin(String pin) async {
    await _prefs.setBool(_keyIsSetupComplete, true);
    await _prefs.setString(_keyAuthMethod, 'pin');
    await _prefs.setString(_keyAppPin, pin);
    notifyListeners();
  }

  bool verifyPin(String enteredPin) {
    if (authMethod != AuthMethod.pin) return false;
    return _storedPin == enteredPin;
  }

  Future<void> reset() async {
    await _prefs.clear();
    _isInitialized = false;
    await initialize();
    notifyListeners();
  }
}
