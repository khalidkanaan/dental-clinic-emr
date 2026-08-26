import 'package:intl/intl.dart';

/// JOD money handling.
///
/// The API stores every amount as a **non-negative integer** where one unit is
/// one hundredth of one JOD. This module converts between:
///   * the integer hundredths used by the API/domain layer, and
///   * the decimal strings the dentist types and reads.
///
/// Conversion is done purely with integer arithmetic and string parsing — never
/// floating-point multiplication — so amounts are always exact.
class JodMoney {
  const JodMoney._();

  /// Maps common non-ASCII digits/separators to ASCII so `٥٠٫٥` parses too.
  static String _normalizeInput(String raw) {
    final buffer = StringBuffer();
    for (final rune in raw.trim().runes) {
      if (rune >= 0x0660 && rune <= 0x0669) {
        // Arabic-Indic digits.
        buffer.writeCharCode(0x30 + (rune - 0x0660));
      } else if (rune >= 0x06F0 && rune <= 0x06F9) {
        // Extended (Persian) digits.
        buffer.writeCharCode(0x30 + (rune - 0x06F0));
      } else if (rune == 0x066B || rune == 0x060C || rune == 0x002C) {
        // Arabic decimal separator, Arabic comma, ASCII comma -> dot.
        buffer.write('.');
      } else {
        buffer.writeCharCode(rune);
      }
    }
    return buffer.toString();
  }

  /// Parses a user-entered amount into integer hundredths of JOD.
  ///
  /// Accepts `50`, `50.0`, `50.00`, `125.5`. Returns `null` for empty input,
  /// negatives, non-numeric input, or more than two decimal places.
  static int? tryParseToHundredths(String raw) {
    final s = _normalizeInput(raw);
    if (s.isEmpty) return null;
    // Whole number, optional dot, at most two fractional digits.
    if (!RegExp(r'^\d+(\.\d{0,2})?$').hasMatch(s)) return null;

    final dot = s.indexOf('.');
    final wholePart = dot == -1 ? s : s.substring(0, dot);
    final fracRaw = dot == -1 ? '' : s.substring(dot + 1);
    final fracPart = fracRaw.padRight(2, '0'); // '' -> '00', '5' -> '50'

    final whole = int.tryParse(wholePart);
    final frac = int.tryParse(fracPart.isEmpty ? '0' : fracPart);
    if (whole == null || frac == null) return null;
    return whole * 100 + frac;
  }

  /// The plain editable representation of hundredths, e.g. `12550` -> `125.50`.
  /// Used to pre-fill an edit form. No grouping and no currency label.
  static String toEditString(int hundredths) {
    final whole = hundredths ~/ 100;
    final frac = hundredths % 100;
    return '$whole.${frac.toString().padLeft(2, '0')}';
  }

  /// Formats hundredths for display, e.g. `12550` -> `125.50 JOD`.
  ///
  /// Uses Western digits and thousands grouping regardless of locale so money
  /// reads consistently and is never shown with mixed digit systems. The
  /// `locale` parameter is accepted for call-site symmetry but does not change
  /// the digits.
  static String format(int hundredths, {String locale = 'en'}) {
    final whole = hundredths ~/ 100;
    final frac = hundredths % 100;
    final grouped = NumberFormat('#,##0', 'en').format(whole);
    return '$grouped.${frac.toString().padLeft(2, '0')} JOD';
  }
}
