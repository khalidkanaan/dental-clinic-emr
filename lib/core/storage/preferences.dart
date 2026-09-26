import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's language and appearance choices and the patient directory filters.
///
/// Uses the modern [SharedPreferencesAsync] API rather than the legacy
/// synchronous facade, as recommended for new applications.
class AppPreferences {
  AppPreferences([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const _themeKey = 'appearance_mode'; // 'light' | 'dark'
  static const _localeKey = 'language_code'; // 'en' | 'ar'
  static const _patientFiltersKey = 'patient_filters'; // JSON object
  static const _showLastVisitKey = 'show_last_visit_in_list'; // bool
  static const _alwaysLoadLatestKey = 'always_load_latest_patient'; // bool

  final SharedPreferencesAsync _prefs;

  Future<String?> readThemeMode() => _prefs.getString(_themeKey);
  Future<void> writeThemeMode(String value) =>
      _prefs.setString(_themeKey, value);

  Future<String?> readLanguageCode() => _prefs.getString(_localeKey);
  Future<void> writeLanguageCode(String value) =>
      _prefs.setString(_localeKey, value);

  /// The patient directory filters as a JSON string, or null when none are
  /// saved. Kept across launches so the app reopens with the same filters.
  Future<String?> readPatientFilters() => _prefs.getString(_patientFiltersKey);
  Future<void> writePatientFilters(String? json) =>
      _writeOrRemove(_patientFiltersKey, json);

  /// Whether the patients list shows each patient's last visit date, or null
  /// if never changed (the app then shows it).
  Future<bool?> readShowLastVisitInList() => _prefs.getBool(_showLastVisitKey);
  Future<void> writeShowLastVisitInList(bool value) =>
      _prefs.setBool(_showLastVisitKey, value);

  /// Whether a patient is loaded from the server every time they're opened,
  /// or null if never changed (the app then keeps them in memory).
  Future<bool?> readAlwaysLoadLatestPatient() =>
      _prefs.getBool(_alwaysLoadLatestKey);
  Future<void> writeAlwaysLoadLatestPatient(bool value) =>
      _prefs.setBool(_alwaysLoadLatestKey, value);

  Future<void> _writeOrRemove(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}
