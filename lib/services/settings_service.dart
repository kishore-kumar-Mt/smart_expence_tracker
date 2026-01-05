import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._init();
  factory SettingsService() => instance;
  SettingsService._init();

  late SharedPreferences _prefs;
  bool _isInitialized = false;

  // Keys
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyNotificationsEnabled = 'notifications_enabled';
  static const String _keyBudgetAlerts = 'budget_alerts';
  static const String _keyIncomeAlerts = 'income_alerts';
  static const String _keyScheduledAlerts = 'scheduled_alerts';

  // Default values
  ThemeMode _themeMode = ThemeMode.system;
  bool _notificationsEnabled = true;
  bool _budgetAlertsEnabled = true;
  bool _incomeAlertsEnabled = true;
  bool _scheduledAlertsEnabled = true;

  // Getters
  ThemeMode get themeMode => _themeMode;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get budgetAlertsEnabled => _budgetAlertsEnabled;
  bool get incomeAlertsEnabled => _incomeAlertsEnabled;
  bool get scheduledAlertsEnabled => _scheduledAlertsEnabled;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _prefs = await SharedPreferences.getInstance();

    // Load Token
    String? themeStr = _prefs.getString(_keyThemeMode);
    if (themeStr == 'dark')
      _themeMode = ThemeMode.dark;
    else if (themeStr == 'light')
      _themeMode = ThemeMode.light;
    else
      _themeMode = ThemeMode.system;

    _notificationsEnabled = _prefs.getBool(_keyNotificationsEnabled) ?? true;
    _budgetAlertsEnabled = _prefs.getBool(_keyBudgetAlerts) ?? true;
    _incomeAlertsEnabled = _prefs.getBool(_keyIncomeAlerts) ?? true;
    _scheduledAlertsEnabled = _prefs.getBool(_keyScheduledAlerts) ?? true;

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    String str = 'system';
    if (mode == ThemeMode.dark) str = 'dark';
    if (mode == ThemeMode.light) str = 'light';
    await _prefs.setString(_keyThemeMode, str);
    notifyListeners();
  }

  Future<void> toggleNotifications(bool value) async {
    _notificationsEnabled = value;
    await _prefs.setBool(_keyNotificationsEnabled, value);
    notifyListeners();
  }

  Future<void> toggleBudgetAlerts(bool value) async {
    _budgetAlertsEnabled = value;
    await _prefs.setBool(_keyBudgetAlerts, value);
    notifyListeners();
  }

  Future<void> toggleIncomeAlerts(bool value) async {
    _incomeAlertsEnabled = value;
    await _prefs.setBool(_keyIncomeAlerts, value);
    notifyListeners();
  }

  Future<void> toggleScheduledAlerts(bool value) async {
    _scheduledAlertsEnabled = value;
    await _prefs.setBool(_keyScheduledAlerts, value);
    notifyListeners();
  }
}
