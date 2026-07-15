import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:nova_spend/features/transactions/domain/usecases/update_transaction.dart';
import 'package:nova_spend/features/transactions/presentation/provider/transaction_detail_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class TransactionDetailPage extends StatelessWidget {
  const TransactionDetailPage({required this.transaction, super.key});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.transactionDetail,
        body: Center(child: Text(context.l10n.errorGeneric)),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => TransactionDetailProvider(
        uid: uid,
        transaction: transaction,
        updateTransaction: sl<UpdateTransaction>(),
        repository: sl<TransactionRepository>(),
      ),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatefulWidget {
  const _DetailView();

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  late final TextEditingController _merchant;
  late final TextEditingController _amount;
  List<String> _categories = const [];

  @override
  void initState() {
    super.initState();
    final tx = context.read<TransactionDetailProvider>().transaction;
    _merchant = TextEditingController(text: tx.merchant);
    _amount = TextEditingController(text: formatAmount(tx.amount));
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final repo = sl<CategoryRepository>();
    final defaults = await repo.watchDefaults().first;
    final uid = context.read<AuthProvider>().uid;
    if (!mounted) return;
    final custom =
        uid == null ? <dynamic>[] : await repo.watchUserCategories(uid).first;
    if (!mounted) return;
    final names = <String>{
      ...defaults.map((c) => c.name),
      ...custom.map((c) => c.name),
    }.toList()
      ..sort();
    setState(() => _categories = names);
  }

  @override
  void dispose() {
    _merchant.dispose();
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<TransactionDetailProvider>();
    final tx = provider.transaction;

    return AdaptiveScaffold(
      title: l10n.transactionDetail,
      appBar: AppBar(
        title: Text(l10n.transactionDetail),
        actions: [
          TextButton(
            onPressed: provider.isSaving
                ? null
                : () async {
                    provider.setMerchant(_merchant.text);
                    provider.setAmount(
                      double.tryParse(_amount.text) ?? provider.amount,
                    );
                    final ok = await provider.save();
                    if (!context.mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.transactionSaved)),
                      );
                      Navigator.of(context).pop();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.errorGeneric)),
                      );
                    }
                  },
            child: Text(l10n.transactionSave),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          TextField(
            controller: _merchant,
            decoration: InputDecoration(labelText: l10n.transactionMerchant),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l10n.transactionAmount),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _categories.contains(provider.category)
                ? provider.category
                : null,
            decoration: InputDecoration(labelText: l10n.transactionCategory),
            items: [
              if (!_categories.contains(provider.category))
                DropdownMenuItem(
                  value: provider.category,
                  child: Text(provider.category),
                ),
              ..._categories.map(
                (c) => DropdownMenuItem(value: c, child: Text(c)),
              ),
            ],
            onChanged: (v) {
              if (v != null) provider.setCategory(v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: provider.type,
            decoration: InputDecoration(labelText: l10n.transactionType),
            items: [
              DropdownMenuItem(
                value: 'debit',
                child: Text(l10n.feedFilterTypeDebit),
              ),
              DropdownMenuItem(
                value: 'credit',
                child: Text(l10n.feedFilterTypeCredit),
              ),
            ],
            onChanged: (v) {
              if (v != null) provider.setType(v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.transactionAlsoOverride),
            value: provider.rememberForMerchant,
            onChanged: provider.setRememberForMerchant,
          ),
          const SizedBox(height: AppSpacing.lg),
          _MetaRow(label: l10n.transactionBank, value: tx.bank),
          _MetaRow(label: l10n.transactionAccount, value: tx.accountIdMasked),
          _MetaRow(label: l10n.transactionDate, value: tx.transactionDate),
          _MetaRow(
            label: l10n.transactionConfidence,
            value: '${(tx.parseConfidence * 100).round()}%',
          ),
          const SizedBox(height: AppSpacing.md),
          Text(l10n.transactionRawSms, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            tx.smsSource.raw,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
          ),
          Text(value),
        ],
      ),
    );
  }
}
