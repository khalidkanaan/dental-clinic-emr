/// Placeholders that can be used inside the WhatsApp message template.
///
/// Each placeholder has an English name and an Arabic name, and both work in
/// any template. Matching ignores case, spaces, underscores and hyphens, so
/// `{Patient}`, `{patient}`, `{First Name}` and `{first_name}` all resolve.
enum MessagePlaceholder {
  patient('Patient', 'المريض'),
  firstName('FirstName', 'الاسم_الأول'),
  phone('Phone', 'الهاتف'),
  clinic('Clinic', 'العيادة'),
  today('Today', 'اليوم'),
  lastVisit('LastVisit', 'آخر_زيارة'),
  lastTreatment('LastTreatment', 'آخر_علاج'),
  lastPaid('LastPaid', 'آخر_مدفوع'),
  lastOwed('LastOwed', 'آخر_مستحق'),
  credit('Credit', 'الرصيد');

  const MessagePlaceholder(this.englishName, this.arabicName);

  final String englishName;
  final String arabicName;

  String get englishToken => '{$englishName}';
  String get arabicToken => '{$arabicName}';

  /// The token to show and insert for the given app language.
  String tokenFor(String languageCode) =>
      languageCode == 'ar' ? arabicToken : englishToken;

  /// The token in the other language, shown as an alternative in the help.
  String alternateTokenFor(String languageCode) =>
      languageCode == 'ar' ? englishToken : arabicToken;
}

/// Renders message templates by swapping placeholders for real values.
class MessageTemplate {
  const MessageTemplate._();

  /// `{anything}` on a single line, up to 40 characters inside the braces.
  /// Double braces (`{{Patient}}`), as used by other tools, work too.
  static final RegExp _tokenPattern = RegExp(r'\{\{?([^{}\n]{1,40})\}\}?');

  static final Map<String, MessagePlaceholder> _index = {
    for (final p in MessagePlaceholder.values) ...{
      _normalize(p.englishName): p,
      _normalize(p.arabicName): p,
    },
  };

  /// Lower-cases and removes separators and Arabic diacritics/tatweel, and
  /// unifies the alef forms, so small spelling differences still match.
  static String _normalize(String raw) {
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-]'), '')
        .replaceAll(RegExp('[ً-ْـ]'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا');
  }

  /// The placeholder a token's inner text refers to, or null if unknown.
  static MessagePlaceholder? lookup(String name) => _index[_normalize(name)];

  /// Replaces every known placeholder in [template] with its value.
  ///
  /// Unknown placeholders are left untouched so typos are easy to spot.
  /// Placeholders without a value (e.g. {LastVisit} for a patient with no
  /// visits) become empty, and the leftover double spaces are tidied.
  static String render(
    String template,
    Map<MessagePlaceholder, String> values,
  ) {
    var usedEmptyValue = false;
    final rendered = template.replaceAllMapped(_tokenPattern, (match) {
      final placeholder = lookup(match.group(1)!);
      if (placeholder == null) return match.group(0)!;
      final value = (values[placeholder] ?? '').trim();
      if (value.isEmpty) usedEmptyValue = true;
      return value;
    });

    if (!usedEmptyValue) return rendered.trim();

    return rendered
        // Collapse runs of spaces left behind by an empty value.
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        // Remove a space stranded before punctuation: "on ." -> "on."
        .replaceAllMapped(RegExp(r' +([,.!?،؛])'), (m) => m.group(1)!)
        .trim();
  }

  /// Tokens in [template] that don't match any placeholder, without
  /// duplicates, in the order they first appear.
  static List<String> unknownTokens(String template) {
    final seen = <String>{};
    for (final match in _tokenPattern.allMatches(template)) {
      if (lookup(match.group(1)!) == null) seen.add(match.group(0)!);
    }
    return seen.toList();
  }
}
