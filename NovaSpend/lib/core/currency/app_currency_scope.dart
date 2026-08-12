import 'package:flutter/material.dart';

import 'app_currency_controller.dart';

/// Exposes [AppCurrencyController] to the widget tree.
class AppCurrencyScope extends InheritedNotifier<AppCurrencyController> {
  const AppCurrencyScope({
    required AppCurrencyController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  static AppCurrencyController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppCurrencyScope>();
    assert(scope != null, 'AppCurrencyScope not found in widget tree');
    return scope!.notifier!;
  }
}
