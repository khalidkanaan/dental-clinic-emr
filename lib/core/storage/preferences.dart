import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's language and appearance choices, and the WhatsApp
/// message settings.
///
/// Uses the modern [SharedPreferencesAsync] API rather than the legacy
/// synchronous facade, as recommended for new applications.
class AppPreferences {
  AppPreferences([SharedPreferencesAsync? prefs])
      : _prefs = prefs ?? SharedPreferencesAsync();

  static const _themeKey = 'appearance_mode'; // 'light' | 'dark'
  static const _localeKey = 'language_code'; // 'en' | 'ar'
  static const _whatsappTemplateKey = 'whatsapp_template';
  static const _whatsappCountryCodeKey = 'whatsapp_country_code';
  static const _clinicNameKey = 'clinic_name';

  final SharedPreferencesAsync _prefs;

  Future<String?> readThemeMode() => _prefs.getString(_themeKey);
  Future<void> writeThemeMode(String value) =>
      _prefs.setString(_themeKey, value);

  Future<String?> readLanguageCode() => _prefs.getString(_localeKey);
  Future<void> writeLanguageCode(String value) =>
      _prefs.setString(_localeKey, value);

  /// The custom WhatsApp message, or null to use the built-in default.
  Future<String?> readWhatsAppTemplate() =>
      _prefs.getString(_whatsappTemplateKey);
  Future<void> writeWhatsAppTemplate(String? value) =>
      _writeOrRemove(_whatsappTemplateKey, value);

  /// Country code (digits only) added to local phone numbers.
  Future<String?> readWhatsAppCountryCode() =>
      _prefs.getString(_whatsappCountryCodeKey);
  Future<void> writeWhatsAppCountryCode(String value) =>
      _prefs.setString(_whatsappCountryCodeKey, value);

  /// The clinic name used by the {Clinic} placeholder, or null for default.
  Future<String?> readClinicName() => _prefs.getString(_clinicNameKey);
  Future<void> writeClinicName(String? value) =>
      _writeOrRemove(_clinicNameKey, value);

  Future<void> _writeOrRemove(String key, String? value) =>
      value == null ? _prefs.remove(key) : _prefs.setString(key, value);
}
