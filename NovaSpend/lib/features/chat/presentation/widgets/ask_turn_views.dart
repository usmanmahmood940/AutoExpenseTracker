import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/skeleton.dart';
import 'package:nova_spend/features/analytics/domain/insights_math.dart';
import 'package:nova_spend/features/chat/domain/entities/chat_citation_entity.dart';
import 'package:nova_spend/features/chat/presentation/ask_error_mapper.dart';
import 'package:nova_spend/features/chat/presentation/provider/ask_provider.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth * 0.82
              : 320.0;
          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
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
          );
        },
      ),
    );
  }
}

class AskAssistantCard extends StatelessWidget {
  const AskAssistantCard({
    required this.turn,
    required this.formatMoney,
    required this.periodLabel,
    this.onRetry,
    this.onOpenActivity,
    this.onCitationTap,
    super.key,
  });

  final AskTurn turn;
  final String Function(double amount) formatMoney;
  final String periodLabel;
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
      body = const _AskAnswerSkeleton();
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
          if (answer != null && answer.isLowConfidence) ...[
            Text(
              l10n.askLowConfidence,
              style: theme.textTheme.bodySmall?.copyWith(
                height: 1.4,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
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
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.askCitations,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < answer.citations.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  color: AppColors.border(brightness).withValues(alpha: 0.35),
                ),
              _CitationRow(
                citation: answer.citations[i],
                formatMoney: formatMoney,
                onTap: answer.citations[i].transactionId == null
                    ? null
                    : () => onCitationTap?.call(answer.citations[i]),
              ),
            ],
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    periodLabel,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  body,
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AskAnswerSkeleton extends StatelessWidget {
  const _AskAnswerSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SkeletonPulse(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: double.infinity, height: 11),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(width: double.infinity, height: 11),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(width: 180, height: 11),
        ],
      ),
    );
  }
}

class _CitationRow extends StatelessWidget {
  const _CitationRow({
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
    final cs = theme.colorScheme;
    final merchant = citation.merchant?.trim() ?? '';
    final date = citation.date?.trim();
    String? dateLabel;
    if (date != null && date.isNotEmpty) {
      final parsed = DateTime.tryParse(date);
      dateLabel = parsed == null ? date : DateFormat.MMMd().format(parsed);
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      merchant.isEmpty ? '—' : merchant,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface,
                      ),
                    ),
                    if (dateLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        dateLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (citation.amount != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  formatMoney(citation.amount!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ],
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.primaryInk(brightness),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String askPeriodLabel(
  AppLocalizations l10n, {
  String? windowFrom,
  String? windowTo,
}) {
  final from = DateTime.tryParse(windowFrom ?? '');
  final to = DateTime.tryParse(windowTo ?? '');
  if (from == null || to == null) return l10n.askLast12Months;
  final fromDay = dateOnly(from);
  final toDay = dateOnly(to);
  if (fromDay == toDay) return DateFormat.MMMd().format(fromDay);
  if (fromDay.year == toDay.year) {
    return '${DateFormat.MMMd().format(fromDay)} – ${DateFormat.MMMd().format(toDay)}';
  }
  return '${DateFormat.yMMMd().format(fromDay)} – ${DateFormat.yMMMd().format(toDay)}';
}
