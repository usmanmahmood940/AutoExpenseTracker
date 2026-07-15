import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_filter.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({
    required this.initial,
    required this.categories,
    required this.banks,
    super.key,
  });

  final TransactionFilter initial;
  final List<String> categories;
  final List<String> banks;

  static Future<TransactionFilter?> show(
    BuildContext context, {
    required TransactionFilter initial,
    required List<String> categories,
    required List<String> banks,
  }) {
    return showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFilterSheet(
        initial: initial,
        categories: categories,
        banks: banks,
      ),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late TextEditingController _merchant;
  late TextEditingController _min;
  late TextEditingController _max;
  String? _category;
  String? _bank;
  String? _type;
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    _merchant = TextEditingController(text: i.merchantQuery ?? '');
    _min = TextEditingController(
      text: i.amountMin?.toStringAsFixed(0) ?? '',
    );
    _max = TextEditingController(
      text: i.amountMax?.toStringAsFixed(0) ?? '',
    );
    _category = i.category;
    _bank = i.bank;
    _type = i.type;
    _from = i.dateFrom;
    _to = i.dateTo;
  }

  @override
  void dispose() {
    _merchant.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final initial = isFrom ? (_from ?? DateTime.now()) : (_to ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
      } else {
        _to = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.feedFilters, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _merchant,
              decoration: InputDecoration(labelText: l10n.feedSearchHint),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: _category,
              decoration: InputDecoration(labelText: l10n.feedFilterCategory),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.commonAll)),
                ...widget.categories.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c)),
                ),
              ],
              onChanged: (v) => setState(() => _category = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: _bank,
              decoration: InputDecoration(labelText: l10n.feedFilterBank),
              items: [
                DropdownMenuItem(value: null, child: Text(l10n.commonAll)),
                ...widget.banks.map(
                  (b) => DropdownMenuItem(value: b, child: Text(b)),
                ),
              ],
              onChanged: (v) => setState(() => _bank = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String?>(
              initialValue: _type,
              decoration: InputDecoration(labelText: l10n.feedFilterType),
              items: [
                DropdownMenuItem(
                  value: null,
                  child: Text(l10n.feedFilterTypeAll),
                ),
                DropdownMenuItem(
                  value: 'debit',
                  child: Text(l10n.feedFilterTypeDebit),
                ),
                DropdownMenuItem(
                  value: 'credit',
                  child: Text(l10n.feedFilterTypeCredit),
                ),
              ],
              onChanged: (v) => setState(() => _type = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _min,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: l10n.feedFilterAmountMin),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TextField(
                    controller: _max,
                    keyboardType: TextInputType.number,
                    decoration:
                        InputDecoration(labelText: l10n.feedFilterAmountMax),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isFrom: true),
                    child: Text(
                      _from == null
                          ? l10n.feedFilterDateFrom
                          : _from!.toIso8601String().split('T').first,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _pickDate(isFrom: false),
                    child: Text(
                      _to == null
                          ? l10n.feedFilterDateTo
                          : _to!.toIso8601String().split('T').first,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, TransactionFilter.empty);
                  },
                  child: Text(l10n.feedClearFilters),
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      TransactionFilter(
                        dateFrom: _from,
                        dateTo: _to,
                        category: _category,
                        bank: _bank,
                        merchantQuery: _merchant.text.trim().isEmpty
                            ? null
                            : _merchant.text.trim(),
                        amountMin: double.tryParse(_min.text),
                        amountMax: double.tryParse(_max.text),
                        type: _type,
                        accountIdMasked: widget.initial.accountIdMasked,
                      ),
                    );
                  },
                  child: Text(l10n.feedApplyFilters),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
