import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/search/domain/entities/date_range_preset.dart';
import 'package:nova_spend/features/search/presentation/widgets/date_range_calendar.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Outcome of [DateRangeSheet.show]. `null` means the sheet was dismissed.
class DateRangeSheetResult {
  const DateRangeSheetResult.applied(this.range) : cleared = false;
  const DateRangeSheetResult.cleared() : range = null, cleared = true;

  final DateRangeValue? range;
  final bool cleared;
}

/// Bottom sheet for picking a date-range preset (or custom range).
class DateRangeSheet extends StatefulWidget {
  const DateRangeSheet({this.initial, super.key});

  final DateRangeValue? initial;

  static Future<DateRangeSheetResult?> show(
    BuildContext context, {
    DateRangeValue? initial,
  }) {
    return showModalBottomSheet<DateRangeSheetResult>(
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
  final _scrollController = ScrollController();

  DateRangePreset? _preset;
  DateTime? _customFrom;
  DateTime? _customTo;
  int _revealToken = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _preset = initial?.preset;
    if (initial?.preset == DateRangePreset.custom) {
      _customFrom = initial?.from;
      _customTo = initial?.to;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  DateTime get _lastSelectableDate => DateTime.now();

  DateTime get _firstSelectableDate => DateTime(2020);

  bool get _isCustom => _preset == DateRangePreset.custom;

  bool get _customComplete => _customFrom != null && _customTo != null;

  bool get _canApply => _preset != null && (!_isCustom || _customComplete);

  bool get _canClear => widget.initial != null;

  DateRangeValue get _current =>
      resolveDateRange(_preset!, customFrom: _customFrom, customTo: _customTo);

  void _select(DateRangePreset preset) {
    if (_preset == preset) {
      setState(() => _preset = null);
      return;
    }
    if (preset == DateRangePreset.custom) {
      _revealToken++;
      setState(() => _preset = preset);
      _revealCalendar();
      return;
    }
    setState(() => _preset = preset);
  }

  /// Scrolls the custom calendar into view in sync with the entrance animation.
  void _revealCalendar() {
    final token = _revealToken;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != _revealToken) return;
      if (!_scrollController.hasClients) return;
      final extent = _scrollController.position.maxScrollExtent;
      if (extent <= 0) return;
      unawaited(
        _scrollController.animateTo(
          extent,
          duration: AppMotion.slow,
          curve: AppMotion.standard,
        ),
      );
    });
  }

  void _onRangeChanged(DateTime start, DateTime? end) {
    setState(() {
      _customFrom = start;
      _customTo = end;
    });
  }

  void _resetCustomRange() {
    setState(() {
      _customFrom = null;
      _customTo = null;
    });
  }

  void _clearCustomEnd() {
    setState(() => _customTo = null);
  }

  void _apply() {
    if (!_canApply) return;
    Navigator.of(context).pop(DateRangeSheetResult.applied(_current));
  }

  void _clear() {
    Navigator.of(context).pop(const DateRangeSheetResult.cleared());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final sheetBg = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    String labelFor(DateRangePreset preset) {
      return switch (preset) {
        DateRangePreset.today => l10n.homePeriodToday,
        DateRangePreset.yesterday => l10n.commonYesterday,
        DateRangePreset.thisWeek => l10n.homePeriodThisWeek,
        DateRangePreset.lastWeek => l10n.dateRangeLastWeek,
        DateRangePreset.thisMonth => l10n.homePeriodThisMonth,
        DateRangePreset.lastMonth => l10n.dateRangeLastMonth,
        DateRangePreset.last3Months => l10n.dateRangeLast3Months,
        DateRangePreset.thisYear => l10n.dateRangeThisYear,
        DateRangePreset.custom => l10n.dateRangeCustom,
      };
    }

    String? subtitleFor(DateRangePreset preset) {
      if (preset == DateRangePreset.custom) {
        if (_preset == DateRangePreset.custom && _customComplete) {
          return resolveDateRange(
            DateRangePreset.custom,
            customFrom: _customFrom,
            customTo: _customTo,
          ).formatSubtitle();
        }
        if (_preset == DateRangePreset.custom && _customFrom != null) {
          return l10n.dateRangePickEndHint;
        }
        return _isCustom ? l10n.dateRangePickStartHint : null;
      }
      return resolveDateRange(preset).formatSubtitle();
    }

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
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.dateRangeSheetTitle,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.02 * 20,
                          ),
                        ),
                      ),
                      Material(
                        color: AppColors.neutralFill(brightness),
                        shape: const CircleBorder(),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => Navigator.of(context).pop(),
                          child: SizedBox(
                            width: 30,
                            height: 30,
                            child: Icon(
                              Icons.close_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.smPlus2),
                  Flexible(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final preset in DateRangePreset.values)
                            _DateRangeOption(
                              label: labelFor(preset),
                              subtitle: subtitleFor(preset),
                              selected: _preset == preset,
                              onTap: () => _select(preset),
                            ),
                          if (_isCustom)
                            _CustomRangeEntrance(
                              key: ValueKey<int>(_revealToken),
                              child: _CustomRangePanel(
                                from: _customFrom,
                                to: _customTo,
                                firstDate: _firstSelectableDate,
                                lastDate: _lastSelectableDate,
                                onChanged: _onRangeChanged,
                                onEditStart: _resetCustomRange,
                                onEditEnd: _clearCustomEnd,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      if (_canClear) ...[
                        TextButton(
                          onPressed: _clear,
                          style: TextButton.styleFrom(
                            foregroundColor: theme.colorScheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.smPlus2,
                            ),
                          ),
                          child: Text(
                            l10n.feedClearFilters,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: _canApply ? _apply : null,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryStrong,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: AppColors.neutralFill(
                              brightness,
                            ),
                            disabledForegroundColor: theme.colorScheme.onSurface
                                .withValues(alpha: 0.4),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            minimumSize: const Size.fromHeight(52),
                            maximumSize: const Size.fromHeight(52),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          child: Text(
                            l10n.dateRangeApply,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: _canApply
                                  ? Colors.white
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: 0.4,
                                    ),
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft fade + slide entrance for the custom range calendar panel.
class _CustomRangeEntrance extends StatefulWidget {
  const _CustomRangeEntrance({required this.child, super.key});

  final Widget child;

  @override
  State<_CustomRangeEntrance> createState() => _CustomRangeEntranceState();
}

class _CustomRangeEntranceState extends State<_CustomRangeEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.slow,
  )..forward();

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.standard,
  );

  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.06),
    end: Offset.zero,
  ).animate(_fade);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.97,
    end: 1,
  ).animate(_fade);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleTransition(
          scale: _scale,
          alignment: Alignment.topCenter,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Expandable custom-range editor: start/end summary tiles plus a calendar.
class _CustomRangePanel extends StatelessWidget {
  const _CustomRangePanel({
    required this.from,
    required this.to,
    required this.firstDate,
    required this.lastDate,
    required this.onChanged,
    required this.onEditStart,
    required this.onEditEnd,
  });

  final DateTime? from;
  final DateTime? to;
  final DateTime firstDate;
  final DateTime lastDate;
  final void Function(DateTime start, DateTime? end) onChanged;
  final VoidCallback onEditStart;
  final VoidCallback onEditEnd;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final format = DateFormat.MMMd(locale);
    final awaitingStart = from == null;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm, bottom: AppSpacing.xs),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.smPlus2),
        decoration: BoxDecoration(
          color: AppColors.card(brightness),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.cardBorder(brightness)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _EndpointTile(
                    label: l10n.dateRangeStartLabel,
                    value: from == null ? null : format.format(from!),
                    active: awaitingStart,
                    onTap: onEditStart,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Expanded(
                  child: _EndpointTile(
                    label: l10n.dateRangeEndLabel,
                    value: to == null ? null : format.format(to!),
                    active: !awaitingStart && to == null,
                    onTap: onEditEnd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.smPlus2),
            Divider(
              height: 1,
              thickness: 1,
              color: AppColors.border(brightness).withValues(alpha: 0.35),
            ),
            const SizedBox(height: AppSpacing.sm),
            DateRangeCalendar(
              firstDate: firstDate,
              lastDate: lastDate,
              start: from,
              end: to,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _EndpointTile extends StatelessWidget {
  const _EndpointTile({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String? value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final accent = AppColors.primaryStrong;

    return Material(
      color: active
          ? AppColors.navActiveFill(brightness)
          : AppColors.neutralFill(brightness).withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smPlus2,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active
                  ? accent.withValues(alpha: 0.4)
                  : Colors.transparent,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? accent : theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xsMini),
              Text(
                value ?? '—',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: value == null
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                      : theme.colorScheme.onSurface,
                ),
              ),
            ],
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
              vertical: AppSpacing.smPlus,
            ),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected
                        ? AppColors.navActiveFill(brightness)
                        : AppColors.neutralFill(
                            brightness,
                          ).withValues(alpha: 0.45),
                    border: Border.all(
                      color: selected
                          ? accent
                          : AppColors.border(brightness).withValues(alpha: 0.7),
                    ),
                  ),
                  child: SvgPicture.asset(
                    'assets/icons/icon_calendar.svg',
                    width: 16,
                    height: 16,
                    colorFilter: ColorFilter.mode(
                      selected ? accent : ink,
                      BlendMode.srcIn,
                    ),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: selected ? accent : ink,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: Colors.white,
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
