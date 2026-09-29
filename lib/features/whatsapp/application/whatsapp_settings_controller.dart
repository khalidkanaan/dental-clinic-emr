import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dental_clinic/core/providers.dart';

/// The saved WhatsApp message settings.
class WhatsAppSettings {
  const WhatsAppSettings({
    this.template,
    this.countryCode = defaultCountryCode,
    this.clinicName,
  });

  /// Jordan. Added to local numbers such as `0791234567`.
  static const String defaultCountryCode = '962';

  /// The custom message, or null to use the default message for the app's
  /// current language.
  final String? template;

  /// Digits only. Empty means "never add a country code".
  final String countryCode;

  /// Used by the {Clinic} placeholder, or null to use the app title.
  final String? clinicName;

  String templateOr(String defaultTemplate) =>
      (template == null || template!.trim().isEmpty) ? defaultTemplate : template!;

  String clinicNameOr(String defaultName) =>
      (clinicName == null || clinicName!.trim().isEmpty)
          ? defaultName
          : clinicName!.trim();
}

class WhatsAppSettingsController extends Notifier<WhatsAppSettings> {
  late Future<void> _loading;

  /// Set once the user saves, so a slow initial read can't overwrite it.
  bool _savedThisSession = false;

  @override
  WhatsAppSettings build() {
    _loading = _load();
    return const WhatsAppSettings();
  }

  Future<void> _load() async {
    try {
      final prefs = ref.read(appPreferencesProvider);
      final template = await prefs.readWhatsAppTemplate();
      final countryCode = await prefs.readWhatsAppCountryCode();
      final clinicName = await prefs.readClinicName();
      if (_savedThisSession) return;
      state = WhatsAppSettings(
        template: template,
        countryCode: countryCode ?? WhatsAppSettings.defaultCountryCode,
        clinicName: clinicName,
      );
    } catch (_) {
      // Keep the defaults if storage can't be read.
    }
  }

  /// The settings once they have been read from storage.
  Future<WhatsAppSettings> ready() async {
    await _loading;
    return state;
  }

  /// Saves all three settings at once.
  ///
  /// Pass null for [template] or [clinicName] to go back to the defaults.
  Future<void> save({
    required String? template,
    required String countryCode,
    required String? clinicName,
  }) async {
    final cleanTemplate =
        (template == null || template.trim().isEmpty) ? null : template;
    final cleanClinic = (clinicName == null || clinicName.trim().isEmpty)
        ? null
        : clinicName.trim();
    final cleanCode = countryCode.replaceAll(RegExp(r'\D'), '');

    _savedThisSession = true;
    state = WhatsAppSettings(
      template: cleanTemplate,
      countryCode: cleanCode,
      clinicName: cleanClinic,
    );

    final prefs = ref.read(appPreferencesProvider);
    await prefs.writeWhatsAppTemplate(cleanTemplate);
    await prefs.writeWhatsAppCountryCode(cleanCode);
    await prefs.writeClinicName(cleanClinic);
  }
}

final whatsAppSettingsControllerProvider =
    NotifierProvider<WhatsAppSettingsController, WhatsAppSettings>(
  WhatsAppSettingsController.new,
);
