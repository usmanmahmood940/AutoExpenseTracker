import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Text(
            l10n.askSuggestionsTitle,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            itemCount: suggestions.length,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (context, index) {
              final question = suggestions[index].question;
              return ActionChip(
                onPressed: enabled ? () => onSelected(question) : null,
                label: Text(question),
                labelStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.navActiveForeground(brightness),
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: AppColors.navActiveFill(brightness),
                side: BorderSide(
                  color: AppColors.border(brightness).withValues(alpha: 0.45),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              );
            },
          ),
        ),
      ],
    );
  }
}
