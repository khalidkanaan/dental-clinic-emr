import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';

/// A compact one-month calendar that highlights a selected date range.
///
/// Flutter's [CalendarDatePicker] can only mark a single day, so this draws
/// the range itself: the first and last days as filled circles joined by a
/// band across every day in between. Works right-to-left (Arabic) too: the
/// grid, the band and the arrows all follow the text direction, and the
/// weekday names / first day of the week come from the app's locale.
///
/// Stateless: the parent owns the shown [month] and the selection.
class MonthRangeCalendar extends StatelessWidget {
  const MonthRangeCalendar({
    super.key,
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.onMonthChanged,
    required this.onDayTapped,
    this.rangeStart,
    this.rangeEnd,
    this.minSelectable,
  });

  /// Any date in the month to show.
  final DateTime month;

  /// Earliest / latest selectable days (also bound month navigation).
  final DateTime firstDate;
  final DateTime lastDate;

  /// Selection. For a single day pass the same date for both (or only
  /// [rangeStart]).
  final DateTime? rangeStart;
  final DateTime? rangeEnd;

  /// Days before this are shown greyed out and can't be tapped (used while
  /// choosing the end of a range).
  final DateTime? minSelectable;

  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDayTapped;

  static const double _rowHeight = 40;

  DateTime get _shown => DateTime(month.year, month.month);

  bool _selectable(DateTime day) {
    if (day.isBefore(DateUtils.dateOnly(firstDate))) return false;
    if (day.isAfter(DateUtils.dateOnly(lastDate))) return false;
    if (minSelectable != null && day.isBefore(DateUtils.dateOnly(minSelectable!))) {
      return false;
    }
    return true;
  }

  void _goTo(DateTime target) {
    final first = DateTime(firstDate.year, firstDate.month);
    final last = DateTime(lastDate.year, lastDate.month);
    final m = DateTime(target.year, target.month);
    onMonthChanged(m.isBefore(first) ? first : (m.isAfter(last) ? last : m));
  }

  @override
  Widget build(BuildContext context) {
    final loc = MaterialLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final shown = _shown;

    final canPrev = shown.isAfter(DateTime(firstDate.year, firstDate.month));
    final canNext = shown.isBefore(DateTime(lastDate.year, lastDate.month));

    // Icons are drawn with an explicit LTR direction so the manual choice
    // below is the only mirroring (earlier months are to the right in RTL).
    Icon arrow(bool back) => Icon(
          (back != isRtl) ? Icons.chevron_left : Icons.chevron_right,
          textDirection: TextDirection.ltr,
        );

    final monthNames = DateFormat.MMMM(locale);
    final start = rangeStart == null ? null : DateUtils.dateOnly(rangeStart!);
    final end = rangeEnd == null ? null : DateUtils.dateOnly(rangeEnd!);
    final hasBand = start != null && end != null && end.isAfter(start);
    final today = DateUtils.dateOnly(DateTime.now());

    // Grid layout for this month, starting on the locale's first weekday.
    final firstWeekday = loc.firstDayOfWeekIndex; // 0 = Sunday
    final leading =
        (DateTime(shown.year, shown.month, 1).weekday % 7 - firstWeekday + 7) % 7;
    final daysInMonth = DateUtils.getDaysInMonth(shown.year, shown.month);
    final rows = ((leading + daysInMonth) / 7).ceil();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---- header: ‹  [Month ▾] [Year ▾]  › ---------------------------
        Row(
          children: [
            IconButton(
              tooltip: loc.previousMonthTooltip,
              onPressed: canPrev
                  ? () => _goTo(DateUtils.addMonthsToMonthDate(shown, -1))
                  : null,
              icon: arrow(true),
            ),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: DropdownButton<int>(
                      value: shown.month,
                      isDense: true,
                      underline: const SizedBox.shrink(),
                      borderRadius: BorderRadius.circular(12),
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      items: [
                        for (var m = 1; m <= 12; m++)
                          DropdownMenuItem(
                            value: m,
                            child: Text(monthNames.format(DateTime(2000, m))),
                          ),
                      ],
                      onChanged: (m) {
                        if (m != null) _goTo(DateTime(shown.year, m));
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  DropdownButton<int>(
                    value: shown.year,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    borderRadius: BorderRadius.circular(12),
                    menuMaxHeight: 320,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                    items: [
                      for (var y = lastDate.year; y >= firstDate.year; y--)
                        DropdownMenuItem(
                          value: y,
                          child: Text(loc.formatYear(DateTime(y))),
                        ),
                    ],
                    onChanged: (y) {
                      if (y != null) _goTo(DateTime(y, shown.month));
                    },
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: loc.nextMonthTooltip,
              onPressed: canNext
                  ? () => _goTo(DateUtils.addMonthsToMonthDate(shown, 1))
                  : null,
              icon: arrow(false),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // ---- weekday initials ---------------------------------------------
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      loc.narrowWeekdays[(firstWeekday + i) % 7],
                      style: theme.textTheme.labelMedium
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        // ---- day grid -------------------------------------------------------
        for (var r = 0; r < rows; r++)
          SizedBox(
            height: _rowHeight,
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(builder: (context) {
                      final dayNumber = r * 7 + c - leading + 1;
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        return const SizedBox.shrink();
                      }
                      final day = DateTime(shown.year, shown.month, dayNumber);
                      final isStart = DateUtils.isSameDay(day, start);
                      final isEnd = DateUtils.isSameDay(day, end);
                      // hasBand guarantees both ends are set.
                      final between =
                          hasBand && day.isAfter(start) && day.isBefore(end);
                      return _DayCell(
                        day: day,
                        label: loc.formatDecimal(dayNumber),
                        isEdge: isStart || isEnd,
                        bandToStart: hasBand && (isEnd || between),
                        bandToEnd: hasBand && (isStart || between),
                        inRange: between,
                        isToday: DateUtils.isSameDay(day, today),
                        enabled: _selectable(day),
                        semanticsLabel: loc.formatFullDate(day),
                        onTap: () => onDayTapped(day),
                      );
                    }),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.label,
    required this.isEdge,
    required this.bandToStart,
    required this.bandToEnd,
    required this.inRange,
    required this.isToday,
    required this.enabled,
    required this.semanticsLabel,
    required this.onTap,
  });

  final DateTime day;
  final String label;

  /// First or last selected day (filled circle).
  final bool isEdge;

  /// Draw the range band on the start-side / end-side half of the cell
  /// (start = left in English, right in Arabic), so neighbouring days join
  /// into one continuous band.
  final bool bandToStart;
  final bool bandToEnd;

  /// Strictly between the first and last day.
  final bool inRange;

  final bool isToday;
  final bool enabled;
  final String semanticsLabel;
  final VoidCallback onTap;

  static const double _circle = 36;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final band = scheme.primaryContainer;

    final Color textColor;
    if (isEdge) {
      textColor = scheme.onPrimary;
    } else if (!enabled) {
      textColor = scheme.onSurface.withValues(alpha: 0.38);
    } else if (inRange) {
      textColor = scheme.onPrimaryContainer;
    } else if (isToday) {
      textColor = scheme.primary;
    } else {
      textColor = scheme.onSurface;
    }

    return Semantics(
      button: true,
      enabled: enabled,
      selected: isEdge || inRange,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The band, as two halves so the first/last days only extend it
          // inwards. The Row mirrors itself in right-to-left.
          if (bandToStart || bandToEnd)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  // Stretch is required: a ColoredBox without a child takes
                  // the smallest size it's allowed, which in a Row is zero
                  // height, so the band would be invisible.
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: ColoredBox(
                        color: bandToStart ? band : Colors.transparent,
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: bandToEnd ? band : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          SizedBox.square(
            dimension: _circle,
            child: Material(
              color: isEdge ? scheme.primary : Colors.transparent,
              shape: isToday && !isEdge
                  ? CircleBorder(side: BorderSide(color: scheme.primary))
                  : const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: enabled ? onTap : null,
                customBorder: const CircleBorder(),
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight:
                          isEdge || isToday ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}