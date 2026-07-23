import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/category_avatar.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// A single transaction row: category avatar, merchant + category, and a
/// right-aligned amount + time.
///
/// Card-less by design — wrap groups of tiles in a `TransactionGroupCard`
/// (Home / Merchant) or an `AppCard` to give them a surface.
class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    required this.transaction,
    this.onTap,
    this.onMerchantTap,
    this.showTime = true,
    super.key,
  });

  final TransactionEntity transaction;
  final VoidCallback? onTap;
  final VoidCallback? onMerchantTap;
  final bool showTime;

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
    final time = showTime ? formatClockTime(transaction.transactionTime) : '';

    final merchantStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.01 * 15,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CategoryAvatar(category: transaction.category),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    onMerchantTap == null
                        ? Text(
                            merchantLabel,
                            style: merchantStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          )
                        : GestureDetector(
                            onTap: onMerchantTap,
                            child: Text(
                              merchantLabel,
                              style: merchantStyle?.copyWith(
                                color: AppColors.accent,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    const SizedBox(height: 2),
                    Text(
                      transaction.category.isEmpty
                          ? transaction.bank
                          : transaction.category,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.85),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$sign${formatMoney(transaction.amount, currency: transaction.currency)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.01 * 15,
                      color: amountColor,
                    ),
                  ),
                  if (time.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      time,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
