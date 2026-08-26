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
