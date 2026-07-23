import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';

/// Header above a day's transaction group: a relative day [label] on the left
/// and an optional [totalLabel] (e.g. that day's spend) on the right.
class DayGroupHeader extends StatelessWidget {
  const DayGroupHeader({
    required this.label,
    this.totalLabel,
    super.key,
  });

  final String label;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: muted,
            ),
          ),
          if (totalLabel != null)
            Text(
              totalLabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.05 * 11,
                color: muted,
              ),
            ),
        ],
      ),
    );
  }
}
