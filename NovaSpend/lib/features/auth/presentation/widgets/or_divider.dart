import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';

/// Horizontal "or" separator used between email and social sign-in.
class OrDivider extends StatelessWidget {
  const OrDivider({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(label),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}
