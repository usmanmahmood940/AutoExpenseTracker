import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/adaptive_scaffold.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../l10n/app_strings.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AdaptiveScaffold(
      title: context.l10n.appTitle,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: AppCard(
          child: Text(
            context.l10n.homeWelcome,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
    );
  }
}
