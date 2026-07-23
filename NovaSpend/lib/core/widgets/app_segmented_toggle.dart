import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

/// A single option in an [AppSegmentedToggle].
class AppSegment<T> {
  const AppSegment({required this.value, required this.label});

  final T value;
  final String label;
}

/// Pill-shaped segmented control with an emerald active state (Figma).
///
/// Segments share width equally. Selection updates **immediately** (optimistic
/// local state) so the pill feels instant even when the parent rebuild is heavy.
class AppSegmentedToggle<T> extends StatefulWidget {
  const AppSegmentedToggle({
    required this.segments,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  State<AppSegmentedToggle<T>> createState() => _AppSegmentedToggleState<T>();
}

class _AppSegmentedToggleState<T> extends State<AppSegmentedToggle<T>> {
  /// Local selection shown instantly on tap; cleared when [widget.value] catches up.
  T? _optimistic;

  T get _displayed => _optimistic ?? widget.value;

  @override
  void didUpdateWidget(covariant AppSegmentedToggle<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == _optimistic) {
      _optimistic = null;
    }
  }

  void _select(T next) {
    if (next == _displayed) return;
    setState(() => _optimistic = next);
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = _displayed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          for (final segment in widget.segments)
            Expanded(
              child: _SegmentButton(
                key: ValueKey(segment.value),
                label: segment.label,
                selected: segment.value == selected,
                onTap: () => _select(segment.value),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _anim = Duration(milliseconds: 100);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: _anim,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: selected ? AppColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.onAccent
                : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
