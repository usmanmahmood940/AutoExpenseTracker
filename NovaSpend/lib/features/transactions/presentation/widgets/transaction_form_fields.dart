import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nova_spend/core/constants/payment_methods.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class TransactionFormLabeledField extends StatelessWidget {
  const TransactionFormLabeledField({
    required this.label,
    required this.muted,
    required this.child,
    super.key,
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

class TransactionAmountField extends StatelessWidget {
  const TransactionAmountField({
    required this.label,
    required this.controller,
    required this.currency,
    required this.muted,
    required this.fieldFill,
    required this.border,
    required this.onChanged,
    this.hintText,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String currency;
  final Color muted;
  final Color fieldFill;
  final Color border;
  final ValueChanged<String> onChanged;
  final String? hintText;

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
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.primaryInk(Theme.of(context).brightness),
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
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    letterSpacing: -0.6,
                    color: AppColors.primaryInk(Theme.of(context).brightness),
                  ),
                  cursorColor: AppColors.primaryInk(
                    Theme.of(context).brightness,
                  ),
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: hintText ?? '0.00',
                    hintStyle: TextStyle(
                      fontSize: hintText == null ? 30 : 22,
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                      letterSpacing: -0.4,
                      color: muted,
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(14, 6, 0, 6),
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

class TransactionFilledTextField extends StatelessWidget {
  const TransactionFilledTextField({
    required this.controller,
    required this.fill,
    required this.ink,
    required this.border,
    this.textStyle,
    this.onChanged,
    this.minLines,
    this.maxLines = 1,
    this.hintText,
    super.key,
  });

  final TextEditingController controller;
  final Color fill;
  final Color ink;
  final Color border;
  final TextStyle? textStyle;
  final ValueChanged<String>? onChanged;
  final int? minLines;
  final int maxLines;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      style:
          textStyle ??
          TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
            color: ink,
          ),
      onChanged: onChanged,
      onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      decoration: InputDecoration(
        hintText: hintText,
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

class TransactionCategoryDropdown extends StatelessWidget {
  const TransactionCategoryDropdown({
    required this.categories,
    required this.value,
    required this.fill,
    required this.ink,
    required this.muted,
    required this.border,
    required this.onChanged,
    this.hintText,
    super.key,
  });

  final List<String> categories;
  final String value;
  final Color fill;
  final Color ink;
  final Color muted;
  final Color border;
  final ValueChanged<String> onChanged;
  final String? hintText;

  @override
  Widget build(BuildContext context) {
    final items = <String>{if (value.isNotEmpty) value, ...categories}.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    final selected = items.contains(value) ? value : null;

    return DropdownButtonFormField<String>(
      key: ValueKey(selected ?? hintText ?? 'category'),
      initialValue: selected,
      isExpanded: true,
      menuMaxHeight: 240,
      icon: Icon(Icons.unfold_more, size: 18, color: muted),
      hint: hintText == null
          ? null
          : Text(
              hintText!,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: muted,
              ),
            ),
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

class TransactionPaymentMethodDropdown extends StatelessWidget {
  const TransactionPaymentMethodDropdown({
    required this.value,
    required this.fill,
    required this.ink,
    required this.muted,
    required this.border,
    required this.onChanged,
    super.key,
  });

  final String value;
  final Color fill;
  final Color ink;
  final Color muted;
  final Color border;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = normalizePaymentMethod(value);

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      menuMaxHeight: 280,
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
      items: kPaymentMethods
          .map(
            (method) => DropdownMenuItem(
              value: method,
              child: Text(
                paymentMethodLabel(l10n, method),
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

class TransactionTypeSegmentedControl extends StatelessWidget {
  const TransactionTypeSegmentedControl({
    required this.value,
    required this.fill,
    required this.muted,
    required this.border,
    required this.debitLabel,
    required this.creditLabel,
    required this.onChanged,
    super.key,
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

class TransactionPickerField extends StatelessWidget {
  const TransactionPickerField({
    required this.value,
    required this.fill,
    required this.ink,
    required this.muted,
    required this.border,
    required this.icon,
    required this.onTap,
    super.key,
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
