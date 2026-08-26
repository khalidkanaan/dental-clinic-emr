import 'package:intl/intl.dart';

/// Visit dates are exchanged with the API as `YYYY-MM-DD` strings.
class VisitDate {
  const VisitDate._();

  /// Converts a picked [DateTime] to the `YYYY-MM-DD` string the API expects.
  static String toApiString(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses an API `YYYY-MM-DD` string. Returns `null` if malformed.
  static DateTime? tryParseApi(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final date = DateTime(y, m, d);
    if (date.year != y || date.month != m || date.day != d) return null;
    return date;
  }

  /// Formats an API date string for display in the given [locale],
  /// e.g. `2026-08-26` -> `Aug 26, 2026`. Falls back to the raw string.
  static String formatForDisplay(String apiValue, {String locale = 'en'}) {
    final parsed = tryParseApi(apiValue);
    if (parsed == null) return apiValue;
    return DateFormat.yMMMd(locale).format(parsed);
  }
}
