import 'package:flutter/material.dart';
import 'package:nova_spend/core/widgets/app_bottom_nav.dart';
import 'package:nova_spend/features/analytics/presentation/pages/insights_page.dart';
import 'package:nova_spend/features/search/presentation/pages/search_page.dart';
import 'package:nova_spend/features/settings/presentation/main_shell_scope.dart';
import 'package:nova_spend/features/settings/presentation/pages/settings_page.dart';
import 'package:nova_spend/features/transactions/presentation/pages/home_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';

class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key});

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _index = 0;

  static const _pages = [
    HomePage(),
    SearchPage(),
    InsightsPage(),
    SettingsPage(),
  ];

  void _selectTab(int index) {
    if (index < 0 || index >= _pages.length) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return MainShellScope(
      selectTab: _selectTab,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: _pages,
        ),
        bottomNavigationBar: AppBottomNav(
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          destinations: [
            AppBottomNavItem(
              iconAsset: 'assets/icons/icon_nav_home.svg',
              label: l10n.navHome,
            ),
            AppBottomNavItem(
              iconAsset: 'assets/icons/icon_nav_transactions.svg',
              label: l10n.navTransactions,
            ),
            AppBottomNavItem(
              iconAsset: 'assets/icons/icon_nav_insights.svg',
              label: l10n.navInsights,
            ),
            AppBottomNavItem(
              iconAsset: 'assets/icons/icon_nav_settings.svg',
              label: l10n.navSettings,
            ),
          ],
        ),
      ),
    );
  }
}
