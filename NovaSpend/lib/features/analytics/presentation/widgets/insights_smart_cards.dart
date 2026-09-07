import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/analytics/domain/entities/smart_card_entity.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class InsightsSmartCards extends StatelessWidget {
  const InsightsSmartCards({
    required this.cards,
    required this.onAsk,
    super.key,
  });

  final List<SmartCardEntity> cards;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.smPlus2),
            _SmartCardTile(card: cards[i], onAsk: onAsk),
          ],
        ],
      ),
    );
  }
}

class _SmartCardTile extends StatelessWidget {
  const _SmartCardTile({required this.card, required this.onAsk});

  final SmartCardEntity card;
  final ValueChanged<String> onAsk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final l10n = context.l10n;
    final question = card.askQuestion;

    return AppCard(
      onTap: question.trim().isEmpty ? null : () => onAsk(question),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            card.title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.navActiveForeground(brightness),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            card.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppSpacing.smPlus2),
          Text(
            l10n.insightsAskThis,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.primaryInk(brightness),
            ),
          ),
        ],
      ),
    );
  }
}
