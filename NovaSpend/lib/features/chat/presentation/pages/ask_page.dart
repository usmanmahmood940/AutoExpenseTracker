import 'package:flutter/material.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/core/widgets/empty_state_view.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/features/settings/presentation/widgets/shell_glass_header_bar.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Placeholder tab for spending chat. RAG UI ships in a later phase.
class AskPage extends StatelessWidget {
  const AskPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return AdaptiveScaffold(
      applySafeArea: false,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                top: GlassHeaderBar.contentTopPadding(context),
              ),
              child: EmptyStateView(
                iconAsset: 'assets/icons/icon_nav_ask.svg',
                title: l10n.askPlaceholderTitle,
                message: l10n.askPlaceholderBody,
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: GlassHeaderBar.totalHeight(context),
            child: const ShellGlassHeaderBar(),
          ),
        ],
      ),
    );
  }
}
