import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/core/providers.dart';

/// Appearance (light/dark). Defaults to light until the stored value loads.
class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.light;
  }

  Future<void> _load() async {
    final stored = await ref.read(appPreferencesProvider).readThemeMode();
    if (stored == 'dark') state = ThemeMode.dark;
    if (stored == 'light') state = ThemeMode.light;
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(appPreferencesProvider)
        .writeThemeMode(mode == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeControllerProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);

/// Language (English / Arabic). Defaults to English until stored value loads.
class LocaleController extends Notifier<Locale> {
  static const english = Locale('en');
  static const arabic = Locale('ar');

  @override
  Locale build() {
    _load();
    return english;
  }

  Future<void> _load() async {
    final code = await ref.read(appPreferencesProvider).readLanguageCode();
    if (code == 'ar') state = arabic;
    if (code == 'en') state = english;
  }

  Future<void> set(Locale locale) async {
    state = locale;
    await ref
        .read(appPreferencesProvider)
        .writeLanguageCode(locale.languageCode);
  }
}

final localeControllerProvider =
    NotifierProvider<LocaleController, Locale>(LocaleController.new);

/// Whether the patients list shows each patient's last visit date. On by
/// default (and until the stored value loads).
class ShowLastVisitController extends Notifier<bool> {
  /// Set once the user flips the switch, so a slow initial load can't
  /// overwrite their choice.
  bool _changed = false;

  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final stored =
        await ref.read(appPreferencesProvider).readShowLastVisitInList();
    if (!_changed && stored != null) state = stored;
  }

  Future<void> set(bool value) async {
    _changed = true;
    state = value;
    await ref.read(appPreferencesProvider).writeShowLastVisitInList(value);
  }
}

final showLastVisitInListProvider =
    NotifierProvider<ShowLastVisitController, bool>(ShowLastVisitController.new);

/// Whether a patient is loaded from the server every time they're opened.
/// Off by default (and until the stored value loads): a patient is then kept
/// in memory after the first load, and refreshed on demand.
class AlwaysLoadLatestPatientController extends Notifier<bool> {
  bool _changed = false;

  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final stored =
        await ref.read(appPreferencesProvider).readAlwaysLoadLatestPatient();
    if (!_changed && stored != null) state = stored;
  }

  Future<void> set(bool value) async {
    _changed = true;
    state = value;
    await ref.read(appPreferencesProvider).writeAlwaysLoadLatestPatient(value);
  }
}

final alwaysLoadLatestPatientProvider =
    NotifierProvider<AlwaysLoadLatestPatientController, bool>(
  AlwaysLoadLatestPatientController.new,
);