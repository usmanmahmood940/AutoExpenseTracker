import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_suggestion_entity.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class AskSuggestionChips extends StatelessWidget {
  const AskSuggestionChips({
    required this.suggestions,
    required this.enabled,
    required this.onSelected,
    super.key,
  });

  final List<ChatSuggestionEntity> suggestions;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final l10n = context.l10n;
    final ink = AppColors.navActiveForeground(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.askSuggestionsTitle,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final item in suggestions)
              Material(
                color: AppColors.navActiveFill(brightness),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                child: InkWell(
                  onTap: enabled ? () => onSelected(item.question) : null,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    child: Text(
                      item.question,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: enabled
                            ? ink
                            : theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class AskSuggestionChipsSkeleton extends StatelessWidget {
  const AskSuggestionChipsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 148, height: 14),
          SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              SkeletonBox(width: 168, height: 36, radius: AppRadius.pill),
              SkeletonBox(width: 132, height: 36, radius: AppRadius.pill),
              SkeletonBox(width: 188, height: 36, radius: AppRadius.pill),
              SkeletonBox(width: 120, height: 36, radius: AppRadius.pill),
            ],
          ),
        ],
      ),
    );
  }
}
