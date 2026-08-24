import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Inline month calendar for picking an inclusive start/end day range.
///
/// Tapping a day starts a new range; the next tap closes it. Tapping a day
/// before the pending start restarts the range from that day.
class DateRangeCalendar extends StatefulWidget {
  const DateRangeCalendar({
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    this.start,
    this.end,
    super.key,
  });

  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? start;
  final DateTime? end;

  /// Called with the new range. [end] is null while the range is half-open.
  final void Function(DateTime start, DateTime? end) onChanged;

  @override
  State<DateRangeCalendar> createState() => _DateRangeCalendarState();
}

class _DateRangeCalendarState extends State<DateRangeCalendar> {
  late DateTime _month;
  late int _pickerYear;
  bool _pickingMonth = false;

  @override
  void initState() {
    super.initState();
    _month = _monthOf(widget.start ?? widget.lastDate);
    _pickerYear = _month.year;
  }

  @override
  void didUpdateWidget(DateRangeCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final start = widget.start;
    if (start != null && oldWidget.start != start && !_isInMonth(start)) {
      _month = _monthOf(start);
    }
  }

  bool _isInMonth(DateTime d) =>
      d.year == _month.year && d.month == _month.month;

  bool get _canGoBack => _monthOf(widget.firstDate).isBefore(_month);

  bool get _canGoForward => _month.isBefore(_monthOf(widget.lastDate));

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _toggleMonthPicker() {
    setState(() {
      _pickingMonth = !_pickingMonth;
      if (_pickingMonth) _pickerYear = _month.year;
    });
  }

  void _shiftPickerYear(int delta) {
    setState(() => _pickerYear += delta);
  }

  void _pickMonth(int month) {
    setState(() {
      _month = DateTime(_pickerYear, month);
      _pickingMonth = false;
    });
  }

  void _onDayTap(DateTime day) {
    final start = widget.start;
    final end = widget.end;
    if (start == null || end != null || day.isBefore(start)) {
      widget.onChanged(day, null);
      return;
    }
    widget.onChanged(start, day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _MonthYearButton(
              label: DateFormat.yMMMM(locale).format(_month),
              tooltip: l10n.dateRangeSelectMonthYear,
              expanded: _pickingMonth,
              onTap: _toggleMonthPicker,
            ),
            const Spacer(),
            if (!_pickingMonth) ...[
              _CalendarIconButton(
                icon: Icons.chevron_left_rounded,
                tooltip: l10n.dateRangePreviousMonth,
                onTap: _canGoBack ? () => _shiftMonth(-1) : null,
              ),
              const SizedBox(width: AppSpacing.xs),
              _CalendarIconButton(
                icon: Icons.chevron_right_rounded,
                tooltip: l10n.dateRangeNextMonth,
                onTap: _canGoForward ? () => _shiftMonth(1) : null,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_pickingMonth)
          _MonthYearPicker(
            year: _pickerYear,
            selectedMonth: _month,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            onYearShift: _shiftPickerYear,
            onMonthSelected: _pickMonth,
          )
        else ...[
          Row(
            children: [
              for (final label in _weekdayLabels(locale))
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          _MonthGrid(
            month: _month,
            firstDate: widget.firstDate,
            lastDate: widget.lastDate,
            start: widget.start,
            end: widget.end,
            brightness: brightness,
            onDayTap: _onDayTap,
          ),
        ],
      ],
    );
  }
}

/// Left-aligned "August 2026" pill that opens the month/year picker.
class _MonthYearButton extends StatelessWidget {
  const _MonthYearButton({
    required this.label,
    required this.tooltip,
    required this.expanded,
    required this.onTap,
  });

  final String label;
  final String tooltip;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = AppColors.primaryStrong;
    final foreground = expanded ? accent : theme.colorScheme.onSurface;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: expanded
            ? AppColors.navActiveFill(brightness)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.smPlus2,
              AppSpacing.xsMax,
              AppSpacing.sm,
              AppSpacing.xsMax,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: foreground,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedRotation(
                  turns: expanded ? 0.5 : 0,
                  duration: AppMotion.fast,
                  curve: AppMotion.standard,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: foreground,
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

/// Year stepper plus a 12-month grid, shown in place of the day grid.
class _MonthYearPicker extends StatelessWidget {
  const _MonthYearPicker({
    required this.year,
    required this.selectedMonth,
    required this.firstDate,
    required this.lastDate,
    required this.onYearShift,
    required this.onMonthSelected,
  });

  final int year;
  final DateTime selectedMonth;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<int> onYearShift;
  final ValueChanged<int> onMonthSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final accent = AppColors.primaryStrong;
    final firstMonth = _monthOf(firstDate);
    final lastMonth = _monthOf(lastDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _CalendarIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: l10n.dateRangePreviousYear,
              onTap: year > firstDate.year ? () => onYearShift(-1) : null,
            ),
            Expanded(
              child: Center(
                child: Text(
                  '$year',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            _CalendarIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: l10n.dateRangeNextYear,
              onTap: year < lastDate.year ? () => onYearShift(1) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        for (var row = 0; row < 4; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                for (final month in <int>[
                  row * 3 + 1,
                  row * 3 + 2,
                  row * 3 + 3,
                ])
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: month % 3 == 0 ? 0 : AppSpacing.sm,
                      ),
                      child: _MonthChip(
                        label: DateFormat.MMM(
                          locale,
                        ).format(DateTime(year, month)),
                        selected:
                            selectedMonth.year == year &&
                            selectedMonth.month == month,
                        enabled:
                            !DateTime(year, month).isBefore(firstMonth) &&
                            !DateTime(year, month).isAfter(lastMonth),
                        accent: accent,
                        brightness: brightness,
                        onTap: () => onMonthSelected(month),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MonthChip extends StatelessWidget {
  const _MonthChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.accent,
    required this.brightness,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final Color accent;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color foreground;
    if (selected) {
      foreground = Colors.white;
    } else if (!enabled) {
      foreground = theme.colorScheme.onSurface.withValues(alpha: 0.28);
    } else {
      foreground = theme.colorScheme.onSurface;
    }

    return Material(
      color: selected
          ? accent
          : AppColors.neutralFill(brightness).withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.smPlus),
          child: Center(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.firstDate,
    required this.lastDate,
    required this.start,
    required this.end,
    required this.brightness,
    required this.onDayTap,
  });

  final DateTime month;
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? start;
  final DateTime? end;
  final Brightness brightness;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first grid, matching the "This week" preset.
    final leadingBlanks = DateTime(month.year, month.month).weekday - 1;
    final cells = leadingBlanks + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(
      children: [
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: _buildCell(
                    row * 7 + col - leadingBlanks + 1,
                    daysInMonth,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(int dayOfMonth, int daysInMonth) {
    if (dayOfMonth < 1 || dayOfMonth > daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }
    final day = DateTime(month.year, month.month, dayOfMonth);
    final enabled =
        !day.isBefore(_dateOnly(firstDate)) &&
        !day.isAfter(_dateOnly(lastDate));
    final spansDays = start != null && end != null && start!.isBefore(end!);

    return _DayCell(
      day: day,
      enabled: enabled,
      isStart: start != null && _isSameDay(day, start!),
      isEnd: end != null && _isSameDay(day, end!),
      inRange: spansDays && day.isAfter(start!) && day.isBefore(end!),
      spansDays: spansDays,
      isToday: _isSameDay(day, _dateOnly(DateTime.now())),
      brightness: brightness,
      onTap: enabled ? () => onDayTap(day) : null,
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.enabled,
    required this.isStart,
    required this.isEnd,
    required this.inRange,
    required this.spansDays,
    required this.isToday,
    required this.brightness,
    required this.onTap,
  });

  final DateTime day;
  final bool enabled;
  final bool isStart;
  final bool isEnd;
  final bool inRange;

  /// Whether the committed range covers more than one day.
  final bool spansDays;
  final bool isToday;
  final Brightness brightness;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = AppColors.primaryStrong;
    final selected = isStart || isEnd;
    final banded = spansDays && (inRange || selected);

    final Color labelColor;
    if (selected) {
      labelColor = Colors.white;
    } else if (!enabled) {
      labelColor = theme.colorScheme.onSurface.withValues(alpha: 0.28);
    } else if (inRange || isToday) {
      labelColor = accent;
    } else {
      labelColor = theme.colorScheme.onSurface;
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (banded)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.navActiveFill(brightness),
                    borderRadius: BorderRadius.horizontal(
                      left: Radius.circular(isStart ? AppRadius.pill : 0),
                      right: Radius.circular(isEnd ? AppRadius.pill : 0),
                    ),
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !selected
                      ? Border.all(color: accent.withValues(alpha: 0.5))
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onTap,
                    child: Center(
                      child: Text(
                        '${day.day}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: labelColor,
                        ),
                      ),
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

class _CalendarIconButton extends StatelessWidget {
  const _CalendarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final enabled = onTap != null;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: AppColors.card(brightness),
        shape: CircleBorder(
          side: BorderSide(
            color: AppColors.border(
              brightness,
            ).withValues(alpha: enabled ? 0.7 : 0.3),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ),
      ),
    );
  }
}

List<String> _weekdayLabels(String locale) {
  // 2024-01-01 was a Monday — walk a full week from there.
  final monday = DateTime(2024, 1, 1);
  return List<String>.generate(
    7,
    (i) => DateFormat.E(locale).format(monday.add(Duration(days: i))),
  );
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _monthOf(DateTime d) => DateTime(d.year, d.month);

bool _isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
