import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/widgets/app_bottom_nav.dart';
import 'package:nova_spend/features/analytics/presentation/pages/insights_page.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/search/presentation/pages/search_page.dart';
import 'package:nova_spend/features/search/presentation/provider/search_provider.dart';
import 'package:nova_spend/features/settings/presentation/main_shell_scope.dart';
import 'package:nova_spend/features/settings/presentation/pages/settings_page.dart';
import 'package:nova_spend/features/transactions/presentation/pages/home_page.dart';
import 'package:nova_spend/features/transactions/presentation/provider/home_provider.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

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

  void _onSelectTab(BuildContext context, int index) {
    if (index < 0 || index >= _pages.length || index == _index) return;
    if (index == 1) {
      context.read<SearchProvider>().ensureLoaded();
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uid = context.watch<AuthProvider>().uid;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final home = sl<HomeProvider>();
            if (uid != null) home.start(uid);
            return home;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final search = sl<SearchProvider>();
            if (uid != null) search.start(uid);
            return search;
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          return MainShellScope(
            selectTab: (index) => _onSelectTab(context, index),
            child: Scaffold(
              body: IndexedStack(
                index: _index,
                children: _pages,
              ),
              bottomNavigationBar: AppBottomNav(
                selectedIndex: _index,
                onDestinationSelected: (index) => _onSelectTab(context, index),
                destinations: [
                  AppBottomNavItem(
                    iconAsset: 'assets/icons/icon_nav_home.svg',
                    label: l10n.navHome,
                  ),
                  AppBottomNavItem(
                    iconAsset: 'assets/icons/icon_nav_transactions.svg',
                    label: l10n.navActivity,
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
        },
      ),
    );
  }
}
