import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/settings/presentation/provider/review_provider.dart';
import 'package:nova_spend/features/transactions/domain/entities/raw_ingestion_entity.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/pages/transaction_detail_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class ReviewPage extends StatelessWidget {
  const ReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.reviewTitle,
        body: Center(child: Text(context.l10n.authLoading)),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final p = sl<ReviewProvider>();
        p.start(uid);
        return p;
      },
      child: const _ReviewView(),
    );
  }
}

class _ReviewView extends StatelessWidget {
  const _ReviewView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<ReviewProvider>();
    final empty = provider.lowConfidence.isEmpty &&
        provider.needsParse.isEmpty &&
        provider.duplicates.isEmpty;

    return AdaptiveScaffold(
      title: l10n.reviewTitle,
      body: provider.isLoading
          ? Center(child: Text(l10n.commonLoading))
          : empty
              ? Center(child: Text(l10n.reviewEmpty))
              : ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  children: [
                    if (provider.lowConfidence.isNotEmpty) ...[
                      Text(
                        l10n.reviewConfidenceSection,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...provider.lowConfidence.map(
                        (tx) => _ConfidenceCard(transaction: tx),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (provider.needsParse.isNotEmpty) ...[
                      Text(
                        l10n.reviewParseSection,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...provider.needsParse.map(
                        (ing) => _IngestionCard(
                          ingestion: ing,
                          showComplete: true,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    if (provider.duplicates.isNotEmpty) ...[
                      Text(
                        l10n.reviewDuplicatesSection,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...provider.duplicates.map(
                        (ing) => _IngestionCard(ingestion: ing),
                      ),
                    ],
                  ],
                ),
    );
  }
}

class _ConfidenceCard extends StatelessWidget {
  const _ConfidenceCard({required this.transaction});

  final TransactionEntity transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.read<ReviewProvider>();
    final percent = (transaction.parseConfidence * 100).round().toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(transaction.merchant, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              formatMoney(
                transaction.amount,
                currency: transaction.currency,
              ),
            ),
            Text(l10n.reviewConfidence(percent)),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                TextButton(
                  onPressed: () => provider.confirm(transaction),
                  child: Text(l10n.reviewConfirm),
                ),
                TextButton(
                  onPressed: () => provider.dismiss(transaction),
                  child: Text(l10n.reviewDismiss),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            TransactionDetailPage(transaction: transaction),
                      ),
                    );
                  },
                  child: Text(l10n.transactionEdit),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IngestionCard extends StatelessWidget {
  const _IngestionCard({
    required this.ingestion,
    this.showComplete = false,
  });

  final RawIngestionEntity ingestion;
  final bool showComplete;

  Future<void> _completeManually(BuildContext context) async {
    final l10n = context.l10n;
    final merchant = TextEditingController();
    final amount = TextEditingController();
    var type = 'debit';
    var category = 'Uncategorized';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(l10n.reviewCompleteManually),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: merchant,
                      decoration:
                          InputDecoration(labelText: l10n.transactionMerchant),
                    ),
                    TextField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          InputDecoration(labelText: l10n.transactionAmount),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration:
                          InputDecoration(labelText: l10n.transactionType),
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
                        if (v != null) setState(() => type = v);
                      },
                    ),
                    TextField(
                      onChanged: (v) => category = v,
                      decoration:
                          InputDecoration(labelText: l10n.transactionCategory),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.commonCancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(l10n.commonSave),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true && context.mounted) {
      final parsedAmount = double.tryParse(amount.text) ?? 0;
      final now = DateTime.now();
      final date =
          '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      await context.read<ReviewProvider>().completeManually(
            ingestionId: ingestion.id,
            fields: {
              'merchant': merchant.text.trim(),
              'amount': parsedAmount,
              'type': type,
              'category': category.trim().isEmpty ? 'Uncategorized' : category.trim(),
              'transactionDate': date,
              'currency': 'PKR',
            },
          );
    }
    merchant.dispose();
    amount.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ingestion.raw,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            if (ingestion.error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                ingestion.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (showComplete) ...[
              const SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: () => _completeManually(context),
                child: Text(l10n.reviewCompleteManually),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
