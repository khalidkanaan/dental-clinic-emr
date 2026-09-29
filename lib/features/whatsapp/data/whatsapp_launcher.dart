import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a WhatsApp chat with a phone number and a pre-filled message.
class WhatsAppLauncher {
  const WhatsAppLauncher._();

  /// Converts a stored phone number into the international digits-only form
  /// WhatsApp expects (no `+`, no leading zeros, no spaces or dashes).
  ///
  /// * `+962 79 123 4567` / `00962791234567` -> `962791234567`
  /// * `0791234567` (local, trunk 0)         -> `962791234567`
  /// * `791234567` (local, no trunk 0)       -> `962791234567`
  ///
  /// [defaultCountryCode] (digits only, e.g. `962`) is added to local
  /// numbers; pass an empty string to never add one. Arabic-Indic digits are
  /// accepted. Returns null when there aren't enough digits to be a number.
  static String? normalizePhone(
    String raw, {
    required String defaultCountryCode,
  }) {
    final ascii = _toAsciiDigits(raw).trim();
    final hasPlus = ascii.startsWith('+');
    var digits = ascii.replaceAll(RegExp(r'\D'), '');
    final countryCode = defaultCountryCode.replaceAll(RegExp(r'\D'), '');

    if (digits.isEmpty) return null;

    if (hasPlus) {
      // Already international.
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '$countryCode${digits.replaceFirst(RegExp(r'^0+'), '')}';
    } else if (countryCode.isNotEmpty &&
        digits.length <= 9 &&
        !digits.startsWith(countryCode)) {
      // Short local number typed without the trunk 0.
      digits = '$countryCode$digits';
    }

    digits = digits.replaceFirst(RegExp(r'^0+'), '');
    if (digits.length < 8 || digits.length > 15) return null;
    return digits;
  }

  /// Opens WhatsApp directly with [message] ready to send to [phone]
  /// (digits only, from [normalizePhone]).
  ///
  /// Tries the WhatsApp app first (`whatsapp://`), then falls back to the
  /// official `https://wa.me` link, which the phone hands to the WhatsApp app
  /// or, on a computer without the app, opens WhatsApp Web.
  ///
  /// Returns false when nothing could be opened.
  static Future<bool> open({
    required String phone,
    required String message,
  }) async {
    // Encode by hand: Uri.queryParameters turns spaces into "+", which
    // WhatsApp shows literally. encodeComponent uses %20 instead.
    final text = Uri.encodeComponent(message);
    final appUri = Uri.parse('whatsapp://send?phone=$phone&text=$text');
    final webUri = Uri.parse('https://wa.me/$phone?text=$text');

    if (await _tryOpenApp(appUri)) return true;

    try {
      return await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _tryOpenApp(Uri uri) async {
    if (kIsWeb) return false;
    try {
      final isDesktop = defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.linux;
      // On desktop, only try the app link when WhatsApp Desktop has
      // registered it; otherwise Windows shows a "find an app" prompt.
      // On phones, canLaunchUrl needs extra manifest entries to be reliable,
      // so just try and fall back if it fails.
      if (isDesktop && !await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static String _toAsciiDigits(String input) {
    final buffer = StringBuffer();
    for (final rune in input.runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        buffer.writeCharCode(0x30 + (rune - 0x0660)); // Arabic-Indic
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        buffer.writeCharCode(0x30 + (rune - 0x06F0)); // Persian
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }
}
