import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/locale/app_locale_scope.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/app_dialogs.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/budgets/presentation/pages/budgets_page.dart';
import 'package:nova_spend/features/categories/presentation/pages/categories_page.dart';
import 'package:nova_spend/features/settings/presentation/pages/language_selection_page.dart';
import 'package:nova_spend/features/settings/presentation/provider/settings_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return AdaptiveScaffold(
        title: context.l10n.settingsTitle,
        body: Center(child: Text(context.l10n.authLoading)),
      );
    }

    return ChangeNotifierProvider(
      create: (_) {
        final p = sl<SettingsProvider>();
        unawaited(p.start(uid));
        return p;
      },
      child: _SettingsView(uid: uid),
    );
  }
}

class _SettingsView extends StatelessWidget {
  const _SettingsView({required this.uid});

  final String uid;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<SettingsProvider>();
    final sync = provider.syncMeta;

    return AdaptiveScaffold(
      title: l10n.settingsTitle,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_isIos) ...[
            Text(
              l10n.settingsUserId,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.settingsUserIdHint,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.55),
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(child: SelectableText(uid)),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: uid));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.settingsUidCopied)),
                );
              },
              child: Text(l10n.settingsCopyUid),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.settingsWebhookUrl,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(child: SelectableText(AppConstants.ingestForUserUrl)),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonal(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: AppConstants.ingestForUserUrl),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.settingsWebhookCopied)),
                );
              },
              child: Text(l10n.settingsCopyWebhook),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            l10n.settingsSyncHealth,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sync?.lastSyncedAt == null
                      ? l10n.settingsNeverSynced
                      : '${l10n.settingsLastSynced}: ${DateFormat.yMMMd().add_jm().format(sync!.lastSyncedAt!)}',
                ),
                if (sync?.lastMerchant != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text('${l10n.settingsLastMerchant}: ${sync!.lastMerchant}'),
                ],
              ],
            ),
          ),
          if (_isIos) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.settingsOnboarding,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(child: Text(l10n.settingsOnboardingBody)),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.settingsSupportedBanks,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.settingsBankMeezan),
          ],
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.settingsLanguageSection,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsBiometric),
            value: provider.biometricEnabled,
            onChanged: provider.setBiometricEnabled,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsCategories),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const CategoriesPage(),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsBudgets),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const BudgetsPage(),
                ),
              );
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.settingsLanguage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final code = await Navigator.of(context).push<String>(
                MaterialPageRoute(
                  builder: (_) => const LanguageSelectionPage(),
                ),
              );
              if (code != null && context.mounted) {
                await AppLocaleScope.of(context).setLocale(Locale(code));
              }
            },
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: provider.isExporting
                ? null
                : () async {
                    await provider.exportCsv(uid);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.settingsExportDone)),
                    );
                  },
            child: Text(l10n.settingsExport),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => provider.signOut(),
            child: Text(l10n.settingsSignOut),
          ),
          TextButton(
            onPressed: () async {
              final email = FirebaseAuth.instance.currentUser?.email;
              if (email == null || email.isEmpty) {
                await AppDialogs.showError(
                  context,
                  message: l10n.authUserNotFound,
                );
                return;
              }
              try {
                await provider.sendPasswordResetEmail(email);
                if (!context.mounted) return;
                await AppDialogs.showSuccess(
                  context,
                  message: l10n.authPasswordResetLinkSent,
                );
              } catch (_) {
                if (!context.mounted) return;
                await AppDialogs.showError(
                  context,
                  message: l10n.errorGeneric,
                );
              }
            },
            child: Text(l10n.authSendPasswordResetLink),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              final confirmed = await AppDialogs.showConfirm(
                context,
                message: l10n.authDeleteAccountConfirm,
                title: l10n.authDeleteAccount,
                confirmLabel: l10n.commonDelete,
              );
              if (!confirmed || !context.mounted) return;

              String? password;
              final providers = FirebaseAuth.instance.currentUser?.providerData
                      .map((p) => p.providerId)
                      .toList() ??
                  const <String>[];
              if (providers.contains('password')) {
                password = await showDialog<String>(
                  context: context,
                  builder: (ctx) {
                    final ctrl = TextEditingController();
                    return AlertDialog(
                      title: Text(l10n.authDeleteAccount),
                      content: TextField(
                        controller: ctrl,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.authDeleteAccountPasswordHint,
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(l10n.commonCancel),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, ctrl.text),
                          child: Text(l10n.commonDelete),
                        ),
                      ],
                    );
                  },
                );
                if (password == null) return;
              }

              try {
                await provider.deleteAccount(password: password);
                if (!context.mounted) return;
                await AppDialogs.showSuccess(
                  context,
                  message: l10n.authAccountDeleted,
                );
              } catch (_) {
                if (!context.mounted) return;
                await AppDialogs.showError(
                  context,
                  message: l10n.errorGeneric,
                );
              }
            },
            child: Text(l10n.authDeleteAccount),
          ),
        ],
      ),
    );
  }
}
