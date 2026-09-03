import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/features/categories/presentation/widgets/category_catalog_scope.dart';
import 'package:nova_spend/features/transactions/presentation/provider/transaction_detail_provider.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/transaction_form_fields.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class EditTransactionSheet extends StatefulWidget {
  const EditTransactionSheet({super.key});

  /// Opens a near-full-height, scrollable edit sheet.
  /// Returns `true` when the transaction was saved successfully.
  static Future<bool?> show(BuildContext context) {
    final provider = context.read<TransactionDetailProvider>();
    provider.resetDraftFromTransaction();
    unawaited(provider.loadMerchantRememberState());

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider<TransactionDetailProvider>.value(
          value: provider,
          child: const EditTransactionSheet(),
        );
      },
    );
  }

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  late final TextEditingController _merchant;
  late final TextEditingController _merchantDetails;
  late final TextEditingController _amount;
  late final TextEditingController _bank;
  late final TextEditingController _account;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionDetailProvider>();
    _merchant = TextEditingController(text: provider.merchant);
    _merchantDetails = TextEditingController(text: provider.merchantDetails);
    _amount = TextEditingController(text: formatAmount(provider.amount));
    _bank = TextEditingController(text: provider.bank);
    _account = TextEditingController(text: provider.accountIdMasked);
  }

  @override
  void dispose() {
    _merchant.dispose();
    _merchantDetails.dispose();
    _amount.dispose();
    _bank.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final provider = context.read<TransactionDetailProvider>();
    final parsed =
        DateTime.tryParse(provider.transactionDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: parsed,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null || !mounted) return;
    provider.setTransactionDate(DateFormat('yyyy-MM-dd').format(picked));
  }

  Future<void> _pickTime() async {
    final provider = context.read<TransactionDetailProvider>();
    final initial =
        _parseTimeOfDay(provider.transactionTime) ?? TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null || !mounted) return;
    provider.setTransactionTime(
      '${picked.hour.toString().padLeft(2, '0')}:'
      '${picked.minute.toString().padLeft(2, '0')}',
    );
  }

  TimeOfDay? _parseTimeOfDay(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;

    final iso = DateTime.tryParse(value);
    if (iso != null) {
      final local = iso.isUtc ? iso.toLocal() : iso;
      return TimeOfDay(hour: local.hour, minute: local.minute);
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(value);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final provider = context.read<TransactionDetailProvider>();
    provider.setMerchant(_merchant.text);
    provider.setMerchantDetails(_merchantDetails.text);
    provider.setAmount(double.tryParse(_amount.text) ?? provider.amount);
    provider.setBank(_bank.text);
    provider.setAccountIdMasked(_account.text);

    final ok = await provider.save();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.errorGeneric)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<TransactionDetailProvider>();
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final colorScheme = theme.colorScheme;
    final sheetBg = AppColors.surface(brightness);
    final ink = colorScheme.onSurface;
    final muted = colorScheme.onSurfaceVariant;
    final fieldFill = AppColors.neutralFill(brightness);
    final border = AppColors.border(brightness);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenH = MediaQuery.sizeOf(context).height;
    final sheetHeight = (screenH * 0.94 - bottomInset).clamp(280.0, screenH);
    final merchantHint = _merchant.text.trim().isEmpty
        ? l10n.transactionMerchant
        : _merchant.text.trim();
    final categories = CategoryCatalogScope.of(
      context,
    ).map((c) => c.name).toSet().toList()..sort();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Material(
          color: sheetBg,
          elevation: 0,
          shadowColor: Colors.black26,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _DragHandle(color: border),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: [
                    _SheetHeader(
                      title: l10n.transactionEditSheetTitle,
                      ink: ink,
                      closeFill: fieldFill,
                      onClose: () => Navigator.of(context).maybePop(false),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionAmountField(
                      label: l10n.transactionAmountLabel,
                      controller: _amount,
                      currency: AppCurrencyScope.of(context).currency,
                      muted: muted,
                      fieldFill: fieldFill,
                      border: border,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionMerchant,
                      muted: muted,
                      child: TransactionFilledTextField(
                        controller: _merchant,
                        fill: fieldFill,
                        ink: ink,
                        border: border,
                        textStyle: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: ink,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionCategory,
                      muted: muted,
                      child: TransactionCategoryDropdown(
                        categories: categories,
                        value: provider.category,
                        fill: fieldFill,
                        ink: ink,
                        muted: muted,
                        border: border,
                        onChanged: provider.setCategory,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionType,
                      muted: muted,
                      child: TransactionTypeSegmentedControl(
                        value: provider.type,
                        fill: fieldFill,
                        muted: muted,
                        border: border,
                        debitLabel: l10n.feedFilterTypeDebit,
                        creditLabel: l10n.feedFilterTypeCredit,
                        onChanged: provider.setType,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionDate,
                      muted: muted,
                      child: TransactionPickerField(
                        value: _formatDateDisplay(provider.transactionDate),
                        fill: fieldFill,
                        ink: ink,
                        muted: muted,
                        border: border,
                        icon: Icons.calendar_today_outlined,
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionPaymentMethod,
                      muted: muted,
                      child: TransactionPaymentMethodDropdown(
                        value: provider.paymentMethod,
                        fill: fieldFill,
                        ink: ink,
                        muted: muted,
                        border: border,
                        onChanged: provider.setPaymentMethod,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionTime,
                      muted: muted,
                      child: TransactionPickerField(
                        value: formatClockTime(provider.transactionTime).isEmpty
                            ? provider.transactionTime
                            : formatClockTime(provider.transactionTime),
                        fill: fieldFill,
                        ink: ink,
                        muted: muted,
                        border: border,
                        icon: Icons.schedule_outlined,
                        onTap: _pickTime,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionBank,
                      muted: muted,
                      child: TransactionFilledTextField(
                        controller: _bank,
                        fill: fieldFill,
                        ink: ink,
                        border: border,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionAccount,
                      muted: muted,
                      child: TransactionFilledTextField(
                        controller: _account,
                        fill: fieldFill,
                        ink: ink,
                        border: border,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TransactionFormLabeledField(
                      label: l10n.transactionMerchantDetails,
                      muted: muted,
                      child: TransactionFilledTextField(
                        controller: _merchantDetails,
                        fill: fieldFill,
                        ink: ink,
                        border: border,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _RememberToggle(
                      enabled: provider.rememberForMerchant,
                      isLoading: provider.isLoadingRememberState,
                      title: l10n.transactionRememberMerchant,
                      subtitle: l10n.transactionAutoCategorizeHint(
                        merchantHint,
                      ),
                      ink: ink,
                      muted: muted,
                      iconFill: fieldFill,
                      border: border,
                      onChanged: provider.setRememberForMerchant,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    FilledButton(
                      onPressed: provider.isSaving ? null : _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryStrong,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.primaryStrong
                            .withValues(alpha: 0.5),
                        minimumSize: const Size.fromHeight(56),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      child: provider.isSaving
                          ? const AppLoader(
                              size: AppLoaderSize.small,
                              color: Colors.white,
                            )
                          : Text(l10n.transactionSave),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextButton(
                      onPressed: provider.isSaving
                          ? null
                          : () => Navigator.of(context).maybePop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: muted,
                        minimumSize: const Size.fromHeight(48),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      child: Text(l10n.transactionCancel),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateDisplay(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return DateFormat.yMMMd().format(parsed);
  }
}

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 8),
      child: Center(
        child: Container(
          width: 48,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        ),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({
    required this.title,
    required this.ink,
    required this.closeFill,
    required this.onClose,
  });

  final String title;
  final Color ink;
  final Color closeFill;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.33,
              letterSpacing: -0.18,
              color: ink,
            ),
          ),
        ),
        Material(
          color: closeFill,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onClose,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.close, size: 18, color: ink),
            ),
          ),
        ),
      ],
    );
  }
}

class _RememberToggle extends StatelessWidget {
  const _RememberToggle({
    required this.enabled,
    required this.isLoading,
    required this.title,
    required this.subtitle,
    required this.ink,
    required this.muted,
    required this.iconFill,
    required this.border,
    required this.onChanged,
  });

  final bool enabled;
  final bool isLoading;
  final String title;
  final String subtitle;
  final Color ink;
  final Color muted;
  final Color iconFill;
  final Color border;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconFill, shape: BoxShape.circle),
            child: Icon(
              Icons.auto_awesome,
              size: 20,
              color: AppColors.primaryInk(Theme.of(context).brightness),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.38,
                    letterSpacing: 0.13,
                    color: ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: AppLoader(size: AppLoaderSize.small),
            )
          else
            Switch.adaptive(
              value: enabled,
              activeTrackColor: AppColors.primaryStrong,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
