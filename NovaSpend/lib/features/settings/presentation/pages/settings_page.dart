import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/constants/currencies.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/locale/app_locale_scope.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/utils/open_external_url.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/core/widgets/app_dialogs.dart';
import 'package:nova_spend/core/widgets/app_loader.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/settings/presentation/pages/about_page.dart';
import 'package:nova_spend/features/settings/presentation/pages/currency_selection_page.dart';
import 'package:nova_spend/features/settings/presentation/pages/language_selection_page.dart';
import 'package:nova_spend/features/settings/presentation/pages/review_page.dart';
import 'package:nova_spend/features/settings/presentation/pages/shortcut_setup_page.dart';
import 'package:nova_spend/features/settings/presentation/provider/settings_provider.dart';
import 'package:nova_spend/features/settings/presentation/widgets/settings_nav_row.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().uid;
    if (uid == null) {
      return _SettingsChrome(
        body: AppPageLoader(label: context.l10n.authLoading),
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<SettingsProvider>();
    final currencyController = context.watch<AppCurrencyController>();
    final email = FirebaseAuth.instance.currentUser?.email;

    return _SettingsChrome(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              GlassHeaderBar.contentTopPadding(context),
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Text(
              l10n.settingsTitle,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.02 * 24,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              children: [
                SettingsSection(
                  title: l10n.settingsSectionAccount,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SettingsSectionCard(
                      children: [
                        if (email != null && email.isNotEmpty)
                          SettingsNavRow(
                            title: email,
                            leading: const Icon(Icons.email_outlined),
                            trailing: const SizedBox.shrink(),
                            onTap: null,
                          ),
                        SettingsNavRow(
                          title: l10n.settingsSignOut,
                          leading: const Icon(Icons.logout),
                          trailing: const SizedBox.shrink(),
                          onTap: provider.signOut,
                        ),
                        SettingsNavRow(
                          title: l10n.authSendPasswordResetLink,
                          leading: const Icon(Icons.lock_reset_outlined),
                          trailing: const SizedBox.shrink(),
                          onTap: () => _sendPasswordReset(context),
                        ),
                        SettingsNavRow(
                          title: l10n.authDeleteAccount,
                          leading: Icon(
                            Icons.delete_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          trailing: const SizedBox.shrink(),
                          onTap: () => _deleteAccount(context, provider),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SettingsSection(
                  title: l10n.settingsSectionPrivacy,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.settingsBiometric),
                      value: provider.biometricEnabled,
                      onChanged: provider.setBiometricEnabled,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SettingsSection(
                  title: l10n.settingsSectionSetup,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SettingsSectionCard(
                      children: [
                        SettingsNavRow(
                          title: l10n.settingsShortcutSetup,
                          subtitle: l10n.settingsShortcutSetupSubtitle,
                          leading: const Icon(Icons.phone_iphone_outlined),
                          onTap: () => _openShortcutSetup(context),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SettingsSection(
                  title: l10n.settingsSectionPreferences,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SettingsSectionCard(
                      children: [
                        SettingsNavRow(
                          title: l10n.settingsLanguage,
                          leading: const Icon(Icons.language_outlined),
                          onTap: () async {
                            final code = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const LanguageSelectionPage(),
                                  ),
                                );
                            if (code != null && context.mounted) {
                              await AppLocaleScope.of(
                                context,
                              ).setLocale(Locale(code));
                            }
                          },
                        ),
                        SettingsNavRow(
                          title: l10n.settingsCurrency,
                          subtitle: currencyDisplayLabel(
                            currencyController.currency,
                          ),
                          leading: const Icon(Icons.payments_outlined),
                          onTap: () async {
                            final code = await Navigator.of(context)
                                .push<String>(
                                  MaterialPageRoute(
                                    builder: (_) => CurrencySelectionPage(
                                      selected: currencyController.currency,
                                    ),
                                  ),
                                );
                            if (code != null && context.mounted) {
                              await currencyController.setCurrency(code);
                            }
                          },
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(l10n.settingsShowDecimals),
                          subtitle: Text(l10n.settingsShowDecimalsHint),
                          value: currencyController.showDecimals,
                          onChanged: currencyController.setShowDecimals,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SettingsSection(
                  title: l10n.settingsSectionAdvanced,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SettingsSectionCard(
                      children: [
                        SettingsNavRow(
                          title: l10n.settingsFixParsing,
                          leading: const Icon(Icons.rule_folder_outlined),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const ReviewPage(),
                              ),
                            );
                          },
                        ),
                        SettingsNavRow(
                          title: l10n.settingsExport,
                          leading: const Icon(Icons.download_outlined),
                          trailing: provider.isExporting
                              ? const AppLoader(size: AppLoaderSize.small)
                              : const Icon(Icons.chevron_right),
                          onTap: provider.isExporting
                              ? null
                              : () => _exportCsv(context, provider),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SettingsSection(
                  title: l10n.settingsSectionSupport,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SettingsSectionCard(
                      children: [
                        SettingsNavRow(
                          title: l10n.settingsFeedback,
                          leading: const Icon(Icons.feedback_outlined),
                          onTap: () => _openExternalLink(
                            context,
                            AppConstants.feedbackMailto,
                          ),
                        ),
                        SettingsNavRow(
                          title: l10n.settingsAbout,
                          leading: const Icon(Icons.info_outline),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AboutPage(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SettingsSection(
                  title: l10n.settingsSectionLegal,
                  child: AppCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                    ),
                    child: SettingsSectionCard(
                      children: [
                        SettingsNavRow(
                          title: l10n.settingsPrivacyPolicy,
                          leading: const Icon(Icons.privacy_tip_outlined),
                          onTap: () => _openExternalLink(
                            context,
                            AppConstants.privacyUrl,
                          ),
                        ),
                        SettingsNavRow(
                          title: l10n.settingsTermsAndConditions,
                          leading: const Icon(Icons.description_outlined),
                          onTap: () =>
                              _openExternalLink(context, AppConstants.termsUrl),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Center(
                  child: Text(
                    l10n.settingsVersion(AppConstants.appVersion),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openShortcutSetup(BuildContext context) {
    openShortcutSetupGuide(
      context,
      uid: uid,
      provider: context.read<SettingsProvider>(),
    );
  }

  Future<void> _openExternalLink(BuildContext context, String url) async {
    final ok = await openExternalUrl(url);
    if (!context.mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.settingsOpenLinkFailed)),
    );
  }

  Future<void> _exportCsv(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final l10n = context.l10n;
    final ok = await provider.exportCsv(uid);
    if (!context.mounted) return;
    if (ok) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.settingsExportDone)));
    } else {
      await AppDialogs.showError(context, message: l10n.errorGeneric);
    }
  }

  Future<void> _sendPasswordReset(BuildContext context) async {
    final l10n = context.l10n;
    final resetEmail = FirebaseAuth.instance.currentUser?.email;
    if (resetEmail == null || resetEmail.isEmpty) {
      await AppDialogs.showError(context, message: l10n.authUserNotFound);
      return;
    }
    try {
      await context.read<SettingsProvider>().sendPasswordResetEmail(resetEmail);
      if (!context.mounted) return;
      await AppDialogs.showSuccess(
        context,
        message: l10n.authPasswordResetLinkSent,
      );
    } catch (_) {
      if (!context.mounted) return;
      await AppDialogs.showError(context, message: l10n.errorGeneric);
    }
  }

  Future<void> _deleteAccount(
    BuildContext context,
    SettingsProvider provider,
  ) async {
    final l10n = context.l10n;
    final confirmed = await AppDialogs.showConfirm(
      context,
      message: l10n.authDeleteAccountConfirm,
      title: l10n.authDeleteAccount,
      confirmLabel: l10n.commonDelete,
    );
    if (!confirmed || !context.mounted) return;

    String? password;
    final providers =
        FirebaseAuth.instance.currentUser?.providerData
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
      await AppDialogs.showSuccess(context, message: l10n.authAccountDeleted);
    } catch (_) {
      if (!context.mounted) return;
      await AppDialogs.showError(context, message: l10n.errorGeneric);
    }
  }
}

/// Shared Settings chrome: glass brand header over [body].
class _SettingsChrome extends StatelessWidget {
  const _SettingsChrome({required this.body});

  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveScaffold(
      applySafeArea: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(child: body),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: GlassHeaderBar.totalHeight(context),
            child: const GlassHeaderBar.brand(),
          ),
        ],
      ),
    );
  }
}

/// Opens the shortcut setup guide from anywhere in the app.
void openShortcutSetupGuide(
  BuildContext context, {
  required String uid,
  SettingsProvider? provider,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) {
        if (provider != null) {
          return ChangeNotifierProvider.value(
            value: provider,
            child: ShortcutSetupPage(uid: uid),
          );
        }
        return ChangeNotifierProvider(
          create: (_) {
            final p = sl<SettingsProvider>();
            unawaited(p.start(uid));
            return p;
          },
          child: ShortcutSetupPage(uid: uid),
        );
      },
    ),
  );
}
