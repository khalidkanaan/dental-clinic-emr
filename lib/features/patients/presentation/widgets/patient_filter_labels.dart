import 'package:intl/intl.dart' show DateFormat;

import 'package:dental_clinic/features/patients/domain/patient_filters.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// Display labels shared by the filter panel and the active-filters bar.
class PatientFilterLabels {
  const PatientFilterLabels._();

  static String preset(AppLocalizations l10n, LastVisitPreset preset) =>
      switch (preset) {
        LastVisitPreset.any => l10n.filterAnyTime,
        LastVisitPreset.pastMonth => l10n.filterPastMonth,
        LastVisitPreset.past3Months => l10n.filterPast3Months,
        LastVisitPreset.past6Months => l10n.filterPast6Months,
        LastVisitPreset.over6MonthsAgo => l10n.filterOver6MonthsAgo,
        LastVisitPreset.over1YearAgo => l10n.filterOver1YearAgo,
        LastVisitPreset.custom => l10n.filterCustomRange,
      };

  /// "Aug 1, 2026 – Sep 29, 2026" in the current locale, or just
  /// "Sep 29, 2026" when both dates are the same day.
  static String dateRange(
    AppLocalizations l10n,
    DateTime from,
    DateTime to,
    String locale,
  ) {
    final format = DateFormat.yMMMd(locale);
    final sameDay =
        from.year == to.year && from.month == to.month && from.day == to.day;
    if (sameDay) return format.format(from);
    return l10n.filterDateRange(format.format(from), format.format(to));
  }

  /// The value shown for the last-visit filter: the preset name, or the
  /// chosen dates for a custom range.
  static String lastVisitValue(
    AppLocalizations l10n,
    PatientFilters filters,
    String locale,
  ) {
    if (filters.lastVisit == LastVisitPreset.custom &&
        filters.customFrom != null &&
        filters.customTo != null) {
      return dateRange(l10n, filters.customFrom!, filters.customTo!, locale);
    }
    return preset(l10n, filters.lastVisit);
  }

  /// Label for one active filter's chip.
  static String chip(
    AppLocalizations l10n,
    PatientFilters filters,
    PatientFilterKind kind,
    String locale,
  ) =>
      switch (kind) {
        PatientFilterKind.lastVisit =>
          l10n.filterChipLastVisit(lastVisitValue(l10n, filters, locale)),
        PatientFilterKind.owesMoney => l10n.filterOwesMoney,
        PatientFilterKind.hasCredit => l10n.filterHasCredit,
        PatientFilterKind.includeArchived => l10n.filterChipArchived,
      };
}
