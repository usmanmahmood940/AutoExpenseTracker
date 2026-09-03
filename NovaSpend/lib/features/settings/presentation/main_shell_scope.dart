import 'package:flutter/material.dart';
import 'package:nova_spend/features/settings/presentation/pages/settings_page.dart';

/// Exposes bottom-tab navigation from [MainShellPage] to child tabs.
class MainShellScope extends InheritedWidget {
  const MainShellScope({
    required this.selectTab,
    required super.child,
    super.key,
  });

  final void Function(int index) selectTab;

  static MainShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellScope>();
  }

  /// Opens Settings as a full-screen route so it does not occupy a tab.
  static Future<void> openSettings(BuildContext context) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
  }

  static void selectTransactionsTab(BuildContext context) {
    maybeOf(context)?.selectTab(1);
  }

  static void selectInsightsTab(BuildContext context) {
    maybeOf(context)?.selectTab(2);
  }

  static void selectAskTab(BuildContext context) {
    maybeOf(context)?.selectTab(3);
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) => false;
}
