import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_citation_entity.dart';
import 'package:nova_spend/features/chat/presentation/ask_error_mapper.dart';
import 'package:nova_spend/features/chat/presentation/provider/ask_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class AskUserBubble extends StatelessWidget {
  const AskUserBubble({required this.question, super.key});

  final String question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.neutralFill(brightness),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.smPlus2,
            ),
            child: Text(
              question,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.4,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AskAssistantCard extends StatelessWidget {
  const AskAssistantCard({
    required this.turn,
    required this.formatMoney,
    this.onRetry,
    this.onOpenActivity,
    this.onCitationTap,
    super.key,
  });

  final AskTurn turn;
  final String Function(double amount) formatMoney;
  final VoidCallback? onRetry;
  final VoidCallback? onOpenActivity;
  final ValueChanged<ChatCitationEntity>? onCitationTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final l10n = context.l10n;
    final ink = AppColors.navActiveForeground(brightness);

    Widget body;
    if (turn.isLoading) {
      body = Text(
        l10n.askThinking,
        style: theme.textTheme.bodyMedium?.copyWith(
          height: 1.45,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      );
    } else if (turn.error != null) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AskErrorMapper.message(l10n, turn.error!),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: AppSpacing.sm),
            TextButton(onPressed: onRetry, child: Text(l10n.errorRetry)),
          ],
        ],
      );
    } else {
      final answer = turn.answer;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            answer?.answer ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (answer != null &&
              answer.isNavigation &&
              onOpenActivity != null) ...[
            const SizedBox(height: AppSpacing.smPlus2),
            FilledButton(
              onPressed: onOpenActivity,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryStrong,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: Text(l10n.askOpenActivity),
            ),
          ],
          if (answer != null && answer.citations.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.smPlus2),
            Text(
              l10n.askCitations,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final citation in answer.citations)
                  _CitationChip(
                    citation: citation,
                    formatMoney: formatMoney,
                    onTap: citation.transactionId == null
                        ? null
                        : () => onCitationTap?.call(citation),
                  ),
              ],
            ),
          ],
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.navActiveFill(brightness),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border(brightness).withValues(alpha: 0.45),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.card(brightness),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: SvgPicture.asset(
                'assets/icons/icon_nav_ask.svg',
                width: 20,
                height: 20,
                colorFilter: ColorFilter.mode(ink, BlendMode.srcIn),
              ),
            ),
            const SizedBox(width: AppSpacing.smPlus2),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}

class _CitationChip extends StatelessWidget {
  const _CitationChip({
    required this.citation,
    required this.formatMoney,
    this.onTap,
  });

  final ChatCitationEntity citation;
  final String Function(double amount) formatMoney;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final parts = <String>[];
    final merchant = citation.merchant?.trim();
    if (merchant != null && merchant.isNotEmpty) parts.add(merchant);
    if (citation.amount != null) parts.add(formatMoney(citation.amount!));
    final date = citation.date?.trim();
    if (date != null && date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      parts.add(parsed == null ? date : DateFormat.MMMd().format(parsed));
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    return Material(
      color: AppColors.card(brightness),
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.smPlus2,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            parts.join(' · '),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
