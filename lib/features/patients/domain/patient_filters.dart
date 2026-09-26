import 'package:flutter/foundation.dart' show immutable;

import 'package:dental_clinic/core/formatting/date_formatter.dart';
import 'package:dental_clinic/features/patients/data/patient.dart';

/// Quick choices for the "last visit" filter.
///
/// Relative presets are stored by name (not as dates) so that "Past month"
/// still means the past month when the app is reopened next week.
enum LastVisitPreset {
  any,
  pastMonth,
  past3Months,
  past6Months,
  over6MonthsAgo,
  over1YearAgo,
  custom,
}

/// One filter that can be switched off on its own (e.g. from a chip).
enum PatientFilterKind { lastVisit, owesMoney, hasCredit, includeArchived }

/// An inclusive calendar-date range. Either end may be open (null).
@immutable
class DateOnlyRange {
  const DateOnlyRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;
}

/// The filters applied to the patient directory, on top of the search text.
///
/// Immutable; every filter is AND-ed with the others and with the search.
@immutable
class PatientFilters {
  const PatientFilters({
    this.lastVisit = LastVisitPreset.any,
    this.customFrom,
    this.customTo,
    this.owesMoney = false,
    this.hasCredit = false,
    this.includeArchived = false,
  });

  static const PatientFilters none = PatientFilters();

  final LastVisitPreset lastVisit;

  /// Only used when [lastVisit] is [LastVisitPreset.custom]. Date-only
  /// (the time part is ignored).
  final DateTime? customFrom;
  final DateTime? customTo;

  /// Patients whose most recent visit has an amount owed above zero (the
  /// clinic records the current outstanding balance on each visit).
  final bool owesMoney;

  /// Patients with a credit balance above zero.
  final bool hasCredit;

  /// Also show archived patients (hidden by default).
  final bool includeArchived;

  /// Whether the last-visit filter actually restricts results. A custom range
  /// without both dates is treated as "any time".
  bool get hasLastVisitFilter => switch (lastVisit) {
        LastVisitPreset.any => false,
        LastVisitPreset.custom => customFrom != null && customTo != null,
        _ => true,
      };

  /// Number of filters in effect, for the badge on the filter button.
  int get activeCount =>
      (hasLastVisitFilter ? 1 : 0) +
      (owesMoney ? 1 : 0) +
      (hasCredit ? 1 : 0) +
      (includeArchived ? 1 : 0);

  bool get isActive => activeCount > 0;

  /// The filters that are in effect, in display order.
  List<PatientFilterKind> get activeKinds => [
        if (hasLastVisitFilter) PatientFilterKind.lastVisit,
        if (owesMoney) PatientFilterKind.owesMoney,
        if (hasCredit) PatientFilterKind.hasCredit,
        if (includeArchived) PatientFilterKind.includeArchived,
      ];

  /// Resolves the last-visit filter to concrete dates relative to [today].
  ///
  /// "Past N months" includes the day exactly N months ago; "over N months
  /// ago" starts the day before, so the two presets never overlap.
  DateOnlyRange resolveLastVisit(DateTime today) {
    final day = _dateOnly(today);
    return switch (lastVisit) {
      LastVisitPreset.any => const DateOnlyRange(),
      LastVisitPreset.pastMonth => DateOnlyRange(from: _monthsBefore(day, 1)),
      LastVisitPreset.past3Months =>
        DateOnlyRange(from: _monthsBefore(day, 3)),
      LastVisitPreset.past6Months =>
        DateOnlyRange(from: _monthsBefore(day, 6)),
      LastVisitPreset.over6MonthsAgo =>
        DateOnlyRange(to: _dayBefore(_monthsBefore(day, 6))),
      LastVisitPreset.over1YearAgo =>
        DateOnlyRange(to: _dayBefore(_monthsBefore(day, 12))),
      LastVisitPreset.custom => hasLastVisitFilter
          ? DateOnlyRange(
              from: _dateOnly(customFrom!),
              to: _dateOnly(customTo!),
            )
          : const DateOnlyRange(),
    };
  }

  /// Query parameters understood by `GET /patients`.
  Map<String, String> toQueryParameters(DateTime today) {
    final range = resolveLastVisit(today);
    return {
      if (range.from != null) 'lastVisitFrom': VisitDate.toApiString(range.from!),
      if (range.to != null) 'lastVisitTo': VisitDate.toApiString(range.to!),
      if (owesMoney) 'owesMoney': 'true',
      if (hasCredit) 'hasCredit': 'true',
      if (includeArchived) 'includeArchived': 'true',
    };
  }

  /// Client-side mirror of the server filter, used to keep the visible list
  /// consistent after a local edit (so an edited patient that no longer
  /// matches disappears instead of lingering until the next refresh).
  ///
  /// Like the server, a patient whose visit summary is unknown
  /// ([Patient.visitSummaryCurrent] is false) never matches the last-visit or
  /// owes-money filters: unknown is neither "owes" nor "visited in range".
  bool matches(Patient patient, DateTime today) {
    if (!includeArchived && patient.isArchived) return false;
    if (hasCredit && patient.credit <= 0) return false;
    if ((owesMoney || hasLastVisitFilter) && !patient.visitSummaryCurrent) {
      return false;
    }
    if (owesMoney) {
      final owed = patient.lastVisitOwed;
      if (owed == null || owed <= 0) return false;
    }
    if (hasLastVisitFilter) {
      final last = patient.lastVisitDate;
      if (last == null) return false;
      final range = resolveLastVisit(today);
      // YYYY-MM-DD strings compare chronologically.
      if (range.from != null &&
          last.compareTo(VisitDate.toApiString(range.from!)) < 0) {
        return false;
      }
      if (range.to != null &&
          last.compareTo(VisitDate.toApiString(range.to!)) > 0) {
        return false;
      }
    }
    return true;
  }

  /// A copy with the given filter switched off.
  PatientFilters without(PatientFilterKind kind) => switch (kind) {
        PatientFilterKind.lastVisit => withLastVisit(LastVisitPreset.any),
        PatientFilterKind.owesMoney => copyWith(owesMoney: false),
        PatientFilterKind.hasCredit => copyWith(hasCredit: false),
        PatientFilterKind.includeArchived =>
          copyWith(includeArchived: false),
      };

  /// A copy with a new last-visit choice. Custom dates are kept only for
  /// [LastVisitPreset.custom].
  PatientFilters withLastVisit(
    LastVisitPreset preset, {
    DateTime? customFrom,
    DateTime? customTo,
  }) {
    final isCustom = preset == LastVisitPreset.custom;
    final from = customFrom ?? this.customFrom;
    final to = customTo ?? this.customTo;
    return PatientFilters(
      lastVisit: preset,
      customFrom: isCustom && from != null ? _dateOnly(from) : null,
      customTo: isCustom && to != null ? _dateOnly(to) : null,
      owesMoney: owesMoney,
      hasCredit: hasCredit,
      includeArchived: includeArchived,
    );
  }

  PatientFilters copyWith({
    bool? owesMoney,
    bool? hasCredit,
    bool? includeArchived,
  }) {
    return PatientFilters(
      lastVisit: lastVisit,
      customFrom: customFrom,
      customTo: customTo,
      owesMoney: owesMoney ?? this.owesMoney,
      hasCredit: hasCredit ?? this.hasCredit,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  // ---- persistence --------------------------------------------------------

  static const _schemaVersion = 1;

  Map<String, Object?> toJson() => {
        'v': _schemaVersion,
        'lastVisit': lastVisit.name,
        if (customFrom != null) 'customFrom': VisitDate.toApiString(customFrom!),
        if (customTo != null) 'customTo': VisitDate.toApiString(customTo!),
        'owesMoney': owesMoney,
        'hasCredit': hasCredit,
        'includeArchived': includeArchived,
      };

  /// Tolerant parser: unknown or malformed values fall back to "no filter"
  /// rather than throwing, so a bad stored value can never break the app.
  factory PatientFilters.fromJson(Map<String, Object?> json) {
    DateTime? date(Object? value) =>
        value is String ? VisitDate.tryParseApi(value) : null;

    final presetName = json['lastVisit'];
    final preset = LastVisitPreset.values.firstWhere(
      (p) => p.name == presetName,
      orElse: () => LastVisitPreset.any,
    );

    var from = date(json['customFrom']);
    var to = date(json['customTo']);
    if (from != null && to != null && from.isAfter(to)) {
      (from, to) = (to, from);
    }

    return PatientFilters(
      lastVisit: preset,
      customFrom: preset == LastVisitPreset.custom ? from : null,
      customTo: preset == LastVisitPreset.custom ? to : null,
      owesMoney: json['owesMoney'] == true,
      hasCredit: json['hasCredit'] == true,
      includeArchived: json['includeArchived'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PatientFilters &&
      other.lastVisit == lastVisit &&
      other.customFrom == customFrom &&
      other.customTo == customTo &&
      other.owesMoney == owesMoney &&
      other.hasCredit == hasCredit &&
      other.includeArchived == includeArchived;

  @override
  int get hashCode => Object.hash(
        lastVisit,
        customFrom,
        customTo,
        owesMoney,
        hasCredit,
        includeArchived,
      );

  // ---- date helpers -------------------------------------------------------

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _dayBefore(DateTime d) => DateTime(d.year, d.month, d.day - 1);

  /// [months] calendar months before [date], clamping the day to the target
  /// month's length (e.g. 31 May minus 3 months is 28/29 February).
  static DateTime _monthsBefore(DateTime date, int months) {
    final firstOfTarget = DateTime(date.year, date.month - months);
    final lastDay =
        DateTime(firstOfTarget.year, firstOfTarget.month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime(firstOfTarget.year, firstOfTarget.month, day);
  }
}
