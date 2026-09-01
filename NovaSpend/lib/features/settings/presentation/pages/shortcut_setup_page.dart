import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/app_card.dart';
import 'package:nova_spend/features/settings/presentation/provider/settings_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

class ShortcutSetupPage extends StatelessWidget {
  const ShortcutSetupPage({required this.uid, super.key});

  final String uid;

  static bool get _isIos =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final provider = context.watch<SettingsProvider>();
    final sync = provider.syncMeta;

    return AdaptiveScaffold(
      title: l10n.settingsShortcutSetupTitle,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (!_isIos)
            AppCard(
              child: Text(
                l10n.settingsShortcutNonIos,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          if (!_isIos) const SizedBox(height: AppSpacing.md),
          Text(
            l10n.settingsOnboarding,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(child: Text(l10n.settingsOnboardingBody)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.settingsUserId,
            style: Theme.of(context).textTheme.titleSmall,
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
            style: Theme.of(context).textTheme.titleSmall,
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
          Text(
            l10n.settingsSyncHealth,
            style: Theme.of(context).textTheme.titleSmall,
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
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.settingsSupportedBanks,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(child: Text(l10n.settingsBankMeezan)),
        ],
      ),
    );
  }
}
