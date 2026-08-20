import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Bottom sheet for picking a date-range preset (or custom range).
class DateRangeSheet extends StatefulWidget {
  const DateRangeSheet({this.initial, super.key});

  final DateRangeValue? initial;

  static Future<DateRangeValue?> show(
    BuildContext context, {
    DateRangeValue? initial,
  }) {
    return showModalBottomSheet<DateRangeValue>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DateRangeSheet(initial: initial),
    );
  }

  @override
  State<DateRangeSheet> createState() => _DateRangeSheetState();
}

class _DateRangeSheetState extends State<DateRangeSheet> {
  late DateRangePreset _preset;
  DateTime? _customFrom;
  DateTime? _customTo;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _preset = initial?.preset ?? DateRangePreset.thisMonth;
    if (initial?.preset == DateRangePreset.custom) {
      _customFrom = initial?.from;
      _customTo = initial?.to;
    }
  }

  DateRangeValue get _current =>
      resolveDateRange(_preset, customFrom: _customFrom, customTo: _customTo);

  Future<void> _select(DateRangePreset preset) async {
    if (preset == DateRangePreset.custom) {
      final from = await showDatePicker(
        context: context,
        initialDate: _customFrom ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (from == null || !mounted) return;
      final to = await showDatePicker(
        context: context,
        initialDate: _customTo ?? from,
        firstDate: from,
        lastDate: DateTime.now().add(const Duration(days: 1)),
      );
      if (to == null || !mounted) return;
      setState(() {
        _preset = DateRangePreset.custom;
        _customFrom = from;
        _customTo = to;
      });
      return;
    }

    setState(() => _preset = preset);
  }

  void _apply() {
    Navigator.of(context).pop(_current);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final sheetBg = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    String labelFor(DateRangePreset preset) {
      return switch (preset) {
        DateRangePreset.today => l10n.homePeriodToday,
        DateRangePreset.yesterday => l10n.commonYesterday,
        DateRangePreset.thisWeek => l10n.homePeriodThisWeek,
        DateRangePreset.thisMonth => l10n.homePeriodThisMonth,
        DateRangePreset.lastMonth => l10n.dateRangeLastMonth,
        DateRangePreset.custom => l10n.dateRangeCustom,
      };
    }

    String? subtitleFor(DateRangePreset preset) {
      if (preset == DateRangePreset.today ||
          preset == DateRangePreset.yesterday ||
          preset == DateRangePreset.custom) {
        if (preset == DateRangePreset.custom &&
            _preset == DateRangePreset.custom &&
            _customFrom != null &&
            _customTo != null) {
          return _current.formatSubtitle();
        }
        return null;
      }
      return resolveDateRange(preset).formatSubtitle();
    }

    final options = DateRangePreset.values;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Material(
        color: sheetBg,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  l10n.dateRangeSheetTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.02 * 20,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final preset in options)
                  _DateRangeOption(
                    label: labelFor(preset),
                    subtitle: subtitleFor(preset),
                    selected: _preset == preset,
                    onTap: () => _select(preset),
                  ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: Text(
                      l10n.dateRangeApply,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
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

class _DateRangeOption extends StatelessWidget {
  const _DateRangeOption({
    required this.label,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  final String label;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final ink = theme.colorScheme.onSurface;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);
    final accent = AppColors.primaryStrong;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: selected
            ? AppColors.navActiveFill(brightness)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.smPlus2,
              vertical: AppSpacing.smPlus2,
            ),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/icon_calendar.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(
                    selected ? accent : ink,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: AppSpacing.smPlus2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: selected ? accent : ink,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Icon(Icons.check_rounded, size: 22, color: accent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
