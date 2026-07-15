import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/categories/presentation/provider/categories_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class CategoriesPage extends StatelessWidget {
  const CategoriesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.categoriesTitle,
        body: Center(child: Text(context.l10n.authLoading)),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final p = sl<CategoriesProvider>();
        p.start(uid);
        return p;
      },
      child: _CategoriesView(uid: uid),
    );
  }
}

class _CategoriesView extends StatelessWidget {
  const _CategoriesView({required this.uid});

  final String uid;

  Future<void> _showAddDialog(BuildContext context) async {
    final l10n = context.l10n;
    final nameController = TextEditingController();
    var type = 'expense';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            return AlertDialog(
              title: Text(l10n.categoriesAdd),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(labelText: l10n.categoriesName),
                    autofocus: true,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: InputDecoration(labelText: l10n.categoriesType),
                    items: [
                      DropdownMenuItem(
                        value: 'expense',
                        child: Text(l10n.feedFilterTypeDebit),
                      ),
                      DropdownMenuItem(
                        value: 'income',
                        child: Text(l10n.feedFilterTypeCredit),
                      ),
                      DropdownMenuItem(
                        value: 'other',
                        child: Text(l10n.commonAll),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => type = v);
                    },
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
                  child: Text(l10n.categoriesSave),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved == true && nameController.text.trim().isNotEmpty && context.mounted) {
      await context.read<CategoriesProvider>().addCategory(
            uid: uid,
            name: nameController.text.trim(),
            type: type,
          );
    }
    nameController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<CategoriesProvider>();

    return AdaptiveScaffold(
      title: l10n.categoriesTitle,
      appBar: AppBar(
        title: Text(l10n.categoriesTitle),
        actions: [
          IconButton(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add),
            tooltip: l10n.categoriesAdd,
          ),
        ],
      ),
      body: provider.isLoading
          ? Center(child: Text(l10n.commonLoading))
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Text(
                  l10n.categoriesDefault,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                ...provider.defaults.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.name),
                        subtitle: Text(c.type),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.categoriesCustom,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (provider.custom.isEmpty)
                  Text(l10n.categoriesEmpty)
                else
                  ...provider.custom.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: AppCard(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(c.name),
                          subtitle: Text(c.type),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
