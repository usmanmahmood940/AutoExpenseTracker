import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/date_labels.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/features/transactions/presentation/provider/transaction_detail_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class EditTransactionSheet extends StatefulWidget {
  const EditTransactionSheet({required this.categories, super.key});

  final List<String> categories;

  /// Opens a near-full-height, scrollable edit sheet.
  /// Returns `true` when the transaction was saved successfully.
  static Future<bool?> show(
    BuildContext context, {
    required List<String> categories,
  }) {
    final provider = context.read<TransactionDetailProvider>();
    provider.resetDraftFromTransaction();

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ChangeNotifierProvider<TransactionDetailProvider>.value(
          value: provider,
          child: EditTransactionSheet(categories: categories),
        );
      },
    );
  }

  @override
  State<EditTransactionSheet> createState() => _EditTransactionSheetState();
}

class _EditTransactionSheetState extends State<EditTransactionSheet> {
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  late final TextEditingController _bank;
  late final TextEditingController _account;
  late final TextEditingController _paymentMethod;

  @override
  void initState() {
    super.initState();
    final provider = context.read<TransactionDetailProvider>();
    _merchant = TextEditingController(text: provider.merchant);
    _amount = TextEditingController(text: formatAmount(provider.amount));
    _bank = TextEditingController(text: provider.bank);
    _account = TextEditingController(text: provider.accountIdMasked);
    _paymentMethod = TextEditingController(text: provider.paymentMethod);
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    _bank.dispose();
    _account.dispose();
    _paymentMethod.dispose();
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
    provider.setAmount(double.tryParse(_amount.text) ?? provider.amount);
    provider.setBank(_bank.text);
    provider.setAccountIdMasked(_account.text);
    provider.setPaymentMethod(_paymentMethod.text);

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
                    _AmountField(
                      label: l10n.transactionAmountLabel,
                      controller: _amount,
                      currency: provider.transaction.currency,
                      muted: muted,
                      fieldFill: fieldFill,
                      border: border,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _LabeledField(
                      label: l10n.transactionMerchant,
                      muted: muted,
                      child: _FilledTextField(
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
                    _LabeledField(
                      label: l10n.transactionCategory,
                      muted: muted,
                      child: _CategoryDropdown(
                        categories: widget.categories,
                        value: provider.category,
                        fill: fieldFill,
                        ink: ink,
                        muted: muted,
                        border: border,
                        onChanged: provider.setCategory,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _LabeledField(
                      label: l10n.transactionType,
                      muted: muted,
                      child: _TypeSegmentedControl(
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
                    _LabeledField(
                      label: l10n.transactionBank,
                      muted: muted,
                      child: _FilledTextField(
                        controller: _bank,
                        fill: fieldFill,
                        ink: ink,
                        border: border,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _LabeledField(
                      label: l10n.transactionAccount,
                      muted: muted,
                      child: _FilledTextField(
                        controller: _account,
                        fill: fieldFill,
                        ink: ink,
                        border: border,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _LabeledField(
                      label: l10n.transactionPaymentMethod,
                      muted: muted,
                      child: _FilledTextField(
                        controller: _paymentMethod,
                        fill: fieldFill,
                        ink: ink,
                        border: border,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _LabeledField(
                      label: l10n.transactionDate,
                      muted: muted,
                      child: _PickerField(
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
                    _LabeledField(
                      label: l10n.transactionTime,
                      muted: muted,
                      child: _PickerField(
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
                    _RememberToggle(
                      enabled: provider.rememberForMerchant,
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
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
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

class _LabeledField extends StatelessWidget {
  const _LabeledField({
    required this.label,
    required this.muted,
    required this.child,
  });

  final String label;
  final Color muted;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.33,
              letterSpacing: 0.6,
              color: muted,
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.label,
    required this.controller,
    required this.currency,
    required this.muted,
    required this.fieldFill,
    required this.border,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String currency;
  final Color muted;
  final Color fieldFill;
  final Color border;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final symbol = currency.toUpperCase() == 'PKR' ? 'Rs.' : currency;

    return Column(
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.33,
            letterSpacing: 0.6,
            color: muted,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: fieldFill,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryStrong.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Text(
                  symbol,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.primaryStrong,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: -0.6,
                    color: AppColors.primaryStrong,
                  ),
                  cursorColor: AppColors.primaryStrong,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: '0.00',
                    contentPadding: EdgeInsets.fromLTRB(14, 6, 0, 6),
                  ),
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FilledTextField extends StatelessWidget {
  const _FilledTextField({
    required this.controller,
    required this.fill,
    required this.ink,
    required this.border,
    this.textStyle,
    this.onChanged,
  });

  final TextEditingController controller;
  final Color fill;
  final Color ink;
  final Color border;
  final TextStyle? textStyle;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style:
          textStyle ??
          TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: ink,
          ),
      onChanged: onChanged,
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sm),
          ),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sm),
          ),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sm),
          ),
          borderSide: const BorderSide(
            color: AppColors.primaryStrong,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({
    required this.categories,
    required this.value,
    required this.fill,
    required this.ink,
    required this.muted,
    required this.border,
    required this.onChanged,
  });

  final List<String> categories;
  final String value;
  final Color fill;
  final Color ink;
  final Color muted;
  final Color border;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final items = <String>{if (value.isNotEmpty) value, ...categories}.toList();

    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : null,
      isExpanded: true,
      menuMaxHeight: 240,
      icon: Icon(Icons.unfold_more, size: 18, color: muted),
      decoration: InputDecoration(
        filled: true,
        fillColor: fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sm),
          ),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sm),
          ),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.sm),
          ),
          borderSide: const BorderSide(
            color: AppColors.primaryStrong,
            width: 1.5,
          ),
        ),
      ),
      items: items
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(
                c,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                  color: ink,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

class _TypeSegmentedControl extends StatelessWidget {
  const _TypeSegmentedControl({
    required this.value,
    required this.fill,
    required this.muted,
    required this.border,
    required this.debitLabel,
    required this.creditLabel,
    required this.onChanged,
  });

  final String value;
  final Color fill;
  final Color muted;
  final Color border;
  final String debitLabel;
  final String creditLabel;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TypeSegment(
              label: debitLabel,
              selected: value == 'debit',
              muted: muted,
              onTap: () => onChanged('debit'),
            ),
          ),
          Expanded(
            child: _TypeSegment(
              label: creditLabel,
              selected: value == 'credit',
              muted: muted,
              onTap: () => onChanged('credit'),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({
    required this.label,
    required this.selected,
    required this.muted,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color muted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primaryStrong : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  height: 1.38,
                  letterSpacing: 0.13,
                  color: selected ? Colors.white : muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({
    required this.value,
    required this.fill,
    required this.ink,
    required this.muted,
    required this.border,
    required this.icon,
    required this.onTap,
  });

  final String value;
  final Color fill;
  final Color ink;
  final Color muted;
  final Color border;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sm),
        ),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.sm),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? '—' : value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: ink,
                  ),
                ),
              ),
              Icon(icon, size: 18, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _RememberToggle extends StatelessWidget {
  const _RememberToggle({
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.ink,
    required this.muted,
    required this.iconFill,
    required this.border,
    required this.onChanged,
  });

  final bool enabled;
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
            decoration: BoxDecoration(
              color: iconFill,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              size: 20,
              color: AppColors.primaryStrong,
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
