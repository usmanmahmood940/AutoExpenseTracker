import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/category_visuals.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/widgets/category_avatar.dart';
import 'package:nova_spend/core/widgets/category_color_scope.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// A single transaction row: category avatar, merchant + category + time,
/// and a right-aligned amount.
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
    final money = AppCurrencyScope.of(context);
    final isCredit = transaction.type == 'credit';
    final amountColor =
        isCredit ? AppColors.accent : theme.colorScheme.onSurface;
    final sign = isCredit ? '+' : '−';
    final merchantLabel = transaction.displayMerchant.isEmpty
        ? context.l10n.transactionMerchant
        : transaction.displayMerchant;
    final time = showTime ? formatClockTime(transaction.transactionTime) : '';

    final merchantStyle = theme.textTheme.titleMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.01 * 15,
      color: theme.colorScheme.onSurface,
    );
    final categoryLabel = transaction.category.isEmpty
        ? transaction.bank
        : transaction.category;
    final categoryStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: transaction.category.isEmpty
          ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85)
          : categoryColor(
              transaction.category,
              storedHex: CategoryColorScope.maybeOf(context)
                  ?.hexFor(transaction.category),
            ),
    );

    final timeStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: 10,
      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55),
    );
    final timeIconColor =
        theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.55);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal:AppSpacing.md, vertical: AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CategoryAvatar(category: transaction.category),
              const SizedBox(width: AppSpacing.smPlus),
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
                              style: merchantStyle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    const SizedBox(height: 1),
                    Text(
                      categoryLabel,
                      style: categoryStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (time.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'assets/icons/icon_clock.svg',
                            width: 12,
                            height: 12,
                            colorFilter: ColorFilter.mode(
                              timeIconColor,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            time,
                            style: timeStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$sign${money.formatMoney(transaction.amount)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.01 * 15,
                  color: amountColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
