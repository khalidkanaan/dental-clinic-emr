import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's language and appearance choices.
///
/// Uses the modern [SharedPreferencesAsync] API rather than the legacy
/// synchronous facade, as recommended for new applications.
class AppPreferences {
  AppPreferences([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const _themeKey = 'appearance_mode'; // 'light' | 'dark'
  static const _localeKey = 'language_code'; // 'en' | 'ar'

  final SharedPreferencesAsync _prefs;

  Future<String?> readThemeMode() => _prefs.getString(_themeKey);
  Future<void> writeThemeMode(String value) =>
      _prefs.setString(_themeKey, value);

  Future<String?> readLanguageCode() => _prefs.getString(_localeKey);
  Future<void> writeLanguageCode(String value) =>
      _prefs.setString(_localeKey, value);
}
