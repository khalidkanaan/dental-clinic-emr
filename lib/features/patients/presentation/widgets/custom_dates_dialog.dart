import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

import 'package:dental_clinic/features/patients/domain/patient_filters.dart';
import 'package:dental_clinic/features/patients/presentation/widgets/month_range_calendar.dart';
import 'package:dental_clinic/l10n/app_localizations.dart';

/// Opens a compact dialog for choosing the "last visit" custom dates: either a
/// single day or a From / To range, picked on one small calendar that
/// highlights every day in the chosen range.
///
/// Resolves to the chosen dates (for a single day `from == to`), or null if
/// the user cancelled.
Future<DateOnlyRange?> showCustomDatesDialog(
  BuildContext context, {
  DateTime? initialFrom,
  DateTime? initialTo,
}) {
  return showDialog<DateOnlyRange>(
    context: context,
    builder: (_) => CustomDatesDialog(
      initialFrom: initialFrom,
      initialTo: initialTo,
    ),
  );
}

enum _Mode { singleDay, range }

enum _Slot { from, to }

class CustomDatesDialog extends StatefulWidget {
  const CustomDatesDialog({super.key, this.initialFrom, this.initialTo});

  final DateTime? initialFrom;
  final DateTime? initialTo;

  @override
  State<CustomDatesDialog> createState() => _CustomDatesDialogState();
}

class _CustomDatesDialogState extends State<CustomDatesDialog> {
  static final DateTime _firstDate = DateTime(2000);
  // A last visit can't meaningfully be far in the future; this also keeps the
  // year drop-down short.
  static final DateTime _lastDate = DateTime(DateTime.now().year + 1, 12, 31);

  late DateTime? _from = _dateOnly(widget.initialFrom);
  late DateTime? _to = _dateOnly(widget.initialTo);

  /// A previously chosen single day (from == to) reopens in single-day mode;
  /// anything else opens as a range.
  late _Mode _mode = _from != null && _to != null && _from == _to
      ? _Mode.singleDay
      : _Mode.range;

  /// Which date the calendar is currently setting.
  late _Slot _active = _mode == _Mode.range && _from != null && _to == null
      ? _Slot.to
      : _Slot.from;

  /// The month the calendar shows: the chosen start, or today's month.
  late DateTime _month = _clamp(_from ?? _today());

  static DateTime? _dateOnly(DateTime? d) =>
      d == null ? null : DateTime(d.year, d.month, d.day);

  static DateTime _today() => _dateOnly(DateTime.now())!;

  static DateTime _clamp(DateTime d) =>
      d.isBefore(_firstDate) ? _firstDate : (d.isAfter(_lastDate) ? _lastDate : d);

  bool get _canApply =>
      _mode == _Mode.singleDay ? _from != null : _from != null && _to != null;

  void _setMode(_Mode mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      if (mode == _Mode.singleDay) {
        _to = null; // the single day is kept in _from
      } else if (_from != null) {
        _to = null; // keep the day as the start; ask for the end next
      }
      _active = mode == _Mode.range && _from != null ? _Slot.to : _Slot.from;
    });
  }

  /// Switches which date the calendar sets, and shows that date's month.
  void _activate(_Slot slot) {
    setState(() {
      _active = slot;
      final date = slot == _Slot.from ? _from : (_to ?? _from);
      if (date != null) _month = date;
    });
  }

  void _onDatePicked(DateTime picked) {
    final day = _dateOnly(picked)!;
    setState(() {
      // Tapping a day that's already selected unselects it.
      if (_mode == _Mode.singleDay) {
        _from = day == _from ? null : day;
        return;
      }
      if (day == _from) {
        // Unselecting the start also clears the end, which depends on it,
        // and goes back to choosing the start.
        _from = null;
        _to = null;
        _active = _Slot.from;
        return;
      }
      if (day == _to) {
        _to = null;
        _active = _Slot.to;
        return;
      }
      if (_active == _Slot.from) {
        _from = day;
        // An end date before the new start is no longer valid.
        if (_to != null && _to!.isBefore(day)) _to = null;
        _active = _Slot.to; // move straight on to the end date
      } else {
        _to = day;
      }
    });
  }

  void _apply() {
    if (!_canApply) return;
    final from = _from!;
    final to = _mode == _Mode.singleDay ? from : _to!;
    Navigator.of(context).pop(DateOnlyRange(from: from, to: to));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final narrow = MediaQuery.sizeOf(context).width < 480;
    final pad = narrow ? 16.0 : 24.0;

    final editingTo = _mode == _Mode.range && _active == _Slot.to;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: EdgeInsets.symmetric(horizontal: narrow ? 12 : 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, pad, pad, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.date_range_rounded, color: scheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      l10n.filterCustomRange,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<_Mode>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(
                    value: _Mode.singleDay,
                    icon: const Icon(Icons.today_rounded, size: 18),
                    label: Text(l10n.filterSingleDay),
                  ),
                  ButtonSegment(
                    value: _Mode.range,
                    icon: const Icon(Icons.date_range_rounded, size: 18),
                    label: Text(l10n.filterDateRangeMode),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => _setMode(s.first),
              ),
              const SizedBox(height: 14),
              if (_mode == _Mode.range)
                Row(
                  children: [
                    Expanded(
                      child: _DateSlot(
                        label: l10n.filterFrom,
                        date: _from,
                        locale: locale,
                        active: _active == _Slot.from,
                        onTap: () => _activate(_Slot.from),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _DateSlot(
                        label: l10n.filterTo,
                        date: _to,
                        locale: locale,
                        active: _active == _Slot.to,
                        // The end date can only be set once there's a start.
                        onTap: _from == null ? null : () => _activate(_Slot.to),
                      ),
                    ),
                  ],
                )
              else
                _DateSlot(
                  label: l10n.filterOnDate,
                  date: _from,
                  locale: locale,
                  active: true,
                  onTap: () {},
                ),
              const SizedBox(height: 8),
              MonthRangeCalendar(
                month: _month,
                firstDate: _firstDate,
                lastDate: _lastDate,
                rangeStart: _from,
                // Single day: just that day. Range: the band appears once the end date is chosen.
                rangeEnd: _mode == _Mode.singleDay ? _from : _to,
                // When setting the end date, days before the start are greyed out.
                minSelectable: editingTo ? _from : null,
                onMonthChanged: (m) => setState(() => _month = m),
                onDayTapped: _onDatePicked,
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.actionCancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(112, 44),
                    ),
                    onPressed: _canApply ? _apply : null,
                    child: Text(l10n.actionApply),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One of the From / To (or Date) boxes above the calendar. The active box is
/// the one the calendar is currently setting.
class _DateSlot extends StatelessWidget {
  const _DateSlot({
    required this.label,
    required this.date,
    required this.locale,
    required this.active,
    required this.onTap,
  });

  final String label;
  final DateTime? date;
  final String locale;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final enabled = onTap != null;
    final text = date == null
        ? l10n.filterSelectDate
        : DateFormat.yMMMd(locale).format(date!);

    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(
        color: active ? scheme.primary : scheme.outlineVariant,
        width: active ? 1.6 : 1,
      ),
    );

    return Semantics(
      button: true,
      selected: active,
      enabled: enabled,
      label: '$label, $text',
      excludeSemantics: true,
      child: Material(
        color: active
            ? scheme.primaryContainer.withValues(alpha: 0.55)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          customBorder: shape,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: active ? scheme.primary : scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    text,
                    maxLines: 1,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: date == null ? FontWeight.w400 : FontWeight.w600,
                      color: date == null
                          ? scheme.onSurfaceVariant.withValues(alpha: enabled ? 1 : 0.5)
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
