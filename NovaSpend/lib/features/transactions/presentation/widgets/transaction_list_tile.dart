import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    required this.transaction,
    this.onTap,
    this.onMerchantTap,
    super.key,
  });

  final TransactionEntity transaction;
  final VoidCallback? onTap;
  final VoidCallback? onMerchantTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCredit = transaction.type == 'credit';
    final amountColor =
        isCredit ? AppColors.accent : theme.colorScheme.onSurface;
    final sign = isCredit ? '+' : '−';
    final merchantLabel = transaction.merchant.isEmpty
        ? context.l10n.transactionMerchant
        : transaction.merchant;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm + 4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                onMerchantTap == null
                    ? Text(
                        merchantLabel,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : InkWell(
                        onTap: onMerchantTap,
                        borderRadius: BorderRadius.circular(4),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            merchantLabel,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: AppColors.accent,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  [
                    transaction.category,
                    if (transaction.accountIdMasked.isNotEmpty)
                      transaction.accountIdMasked,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$sign${formatMoney(transaction.amount, currency: transaction.currency)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
