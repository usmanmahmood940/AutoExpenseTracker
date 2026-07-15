import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';

class DaySectionHeader extends StatelessWidget {
  const DaySectionHeader({required this.dateKey, super.key});

  final String dateKey;

  @override
  Widget build(BuildContext context) {
    final parsed = DateTime.tryParse(dateKey);
    final label = parsed == null
        ? dateKey
        : DateFormat.yMMMEd().format(parsed);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.55),
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}
