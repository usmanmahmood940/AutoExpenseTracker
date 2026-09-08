import 'package:flutter/material.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

/// Bottom sheet: pick primary among [selected], then settle the rest into it.
class SettleTransactionsSheet extends StatefulWidget {
  const SettleTransactionsSheet({required this.selected, super.key});

  final List<TransactionEntity> selected;

  static Future<bool?> show(
    BuildContext context, {
    required List<TransactionEntity> selected,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SettleTransactionsSheet(selected: selected),
    );
  }

  @override
  State<SettleTransactionsSheet> createState() =>
      _SettleTransactionsSheetState();
}

class _SettleTransactionsSheetState extends State<SettleTransactionsSheet> {
  String? _primaryId;
  bool _saving = false;
  String? _error;

  List<TransactionEntity> get _eligible => widget.selected
      .where((tx) => tx.status == 'active' || tx.status == 'settled')
      .toList();

  @override
  void initState() {
    super.initState();
    final debit = _eligible.where((tx) => tx.type == 'debit').toList();
    _primaryId = (debit.isNotEmpty ? debit.first : _eligible.firstOrNull)?.id;
  }

  double? _previewNet(TransactionEntity primary) {
    final sources = widget.selected.where((tx) => tx.id != primary.id);
    var net = primary.amount;
    for (final source in sources) {
      if (source.type == 'credit') {
        net -= source.amount;
      } else {
        net += source.amount;
      }
    }
    return net;
  }

  Future<void> _confirm() async {
    final primaryId = _primaryId;
    if (primaryId == null) return;
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) return;

    final sourceIds = widget.selected
        .where((tx) => tx.id != primaryId)
        .map((tx) => tx.id)
        .toList();
    if (sourceIds.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await sl<TransactionRepository>().settle(
        uid: uid,
        primaryId: primaryId,
        sourceIds: sourceIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final money = AppCurrencyScope.of(context);
    final primary = _eligible.where((tx) => tx.id == _primaryId).firstOrNull;
    final preview = primary == null ? null : _previewNet(primary);

    return AnimatedPadding(
      duration: AppMotion.fast,
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border(brightness).withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.transactionSettleTitle,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.neutralFill(brightness),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l10n.transactionSettlePickPrimary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.4,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final tx in _eligible)
                        ListTile(
                          selected: tx.id == _primaryId,
                          selectedTileColor: AppColors.navActiveFill(brightness),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          title: Text(tx.displayMerchant),
                          subtitle: Text(
                            '${tx.category} · ${money.formatMoney(tx.amount)}',
                          ),
                          trailing: tx.id == _primaryId
                              ? Icon(
                                  Icons.check_circle,
                                  color: AppColors.primaryStrong,
                                )
                              : null,
                          onTap: _saving
                              ? null
                              : () => setState(() => _primaryId = tx.id),
                        ),
                    ],
                  ),
                ),
                if (preview != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.transactionSettlePreview(money.formatMoney(preview)),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.errorGeneric,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ||
                            _primaryId == null ||
                            (preview != null && preview <= 0)
                        ? null
                        : _confirm,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryStrong,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.transactionSettleConfirm),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
