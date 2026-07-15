import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/money_format.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/budgets/domain/entities/budget_entity.dart';
import 'package:nova_spend/features/budgets/presentation/provider/budgets_provider.dart';
import 'package:nova_spend/features/categories/domain/repositories/category_repository.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class BudgetsPage extends StatelessWidget {
  const BudgetsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.budgetsTitle,
        body: Center(child: Text(context.l10n.authLoading)),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final p = sl<BudgetsProvider>();
        final l10n = context.l10n;
        p.alertTitle = l10n.budgetsAlertTitle;
        p.alertNearBuilder = (category, percent) =>
            l10n.budgetsAlertNear(category, percent);
        p.alertOverBuilder = (category) => l10n.budgetsAlertOver(category);
        p.start(uid);
        return p;
      },
      child: const _BudgetsView(),
    );
  }
}

class _BudgetsView extends StatelessWidget {
  const _BudgetsView();

  Future<void> _addBudget(BuildContext context) async {
    final l10n = context.l10n;
    final limitController = TextEditingController();
    String? category;
    final categories = await sl<CategoryRepository>().watchDefaults().first;
    final names = categories.map((c) => c.name).toList();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(l10n.budgetsAdd),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration:
                        InputDecoration(labelText: l10n.transactionCategory),
                    items: names
                        .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                        .toList(),
                    onChanged: (v) => setState(() => category = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: limitController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: l10n.budgetsLimit),
                  ),
                ],
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

    if (saved == true &&
        category != null &&
        context.mounted &&
        double.tryParse(limitController.text) != null) {
      await context.read<BudgetsProvider>().saveBudget(
            BudgetEntity(
              id: '',
              category: category!,
              limit: double.parse(limitController.text),
              period: 'monthly',
              currency: 'PKR',
            ),
          );
    }
    limitController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<BudgetsProvider>();

    return AdaptiveScaffold(
      title: l10n.budgetsTitle,
      appBar: AppBar(
        title: Text(l10n.budgetsTitle),
        actions: [
          IconButton(
            onPressed: () => _addBudget(context),
            icon: const Icon(Icons.add),
            tooltip: l10n.budgetsAdd,
          ),
        ],
      ),
      body: provider.isLoading
          ? Center(child: Text(l10n.commonLoading))
          : provider.budgets.isEmpty
              ? Center(child: Text(l10n.budgetsEmpty))
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: provider.budgets.length,
                  itemBuilder: (context, index) {
                    final budget = provider.budgets[index];
                    final spent = provider.spentFor(budget.category);
                    final progress =
                        budget.limit <= 0 ? 0.0 : (spent / budget.limit).clamp(0.0, 1.5);
                    final over = spent > budget.limit;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    budget.category,
                                    style:
                                        Theme.of(context).textTheme.titleMedium,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () =>
                                      provider.deleteBudget(budget.id),
                                  icon: const Icon(Icons.delete_outline),
                                  tooltip: l10n.commonDelete,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            LinearProgressIndicator(
                              value: progress > 1 ? 1 : progress,
                              color: over
                                  ? Theme.of(context).colorScheme.error
                                  : AppColors.accent,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.08),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              l10n.budgetsProgress(
                                formatMoney(spent, currency: budget.currency),
                                formatMoney(
                                  budget.limit,
                                  currency: budget.currency,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
