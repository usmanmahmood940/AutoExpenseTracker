import 'package:flutter/material.dart';

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

  static void selectSettingsTab(BuildContext context) {
    maybeOf(context)?.selectTab(3);
  }

  static void selectSearchTab(BuildContext context) {
    maybeOf(context)?.selectTab(1);
  }

  @override
  bool updateShouldNotify(MainShellScope oldWidget) => false;
}
