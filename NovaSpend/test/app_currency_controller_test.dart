import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('applyFromServer overwrites local prefs without calling remoteSync', () async {
    var remoteCalls = 0;
    final prefs = await SharedPreferences.getInstance();
    final controller = AppCurrencyController(
      prefs,
      remoteSync: (_) async {
        remoteCalls += 1;
      },
    );
    await controller.load();
    expect(controller.currency, 'PKR');

    await controller.applyFromServer('usd');
    expect(controller.currency, 'USD');
    expect(remoteCalls, 0);
  });

  test('setCurrency PATCHes via remoteSync', () async {
    String? synced;
    final prefs = await SharedPreferences.getInstance();
    final controller = AppCurrencyController(
      prefs,
      remoteSync: (code) async {
        synced = code;
      },
    );
    await controller.load();
    await controller.setCurrency('EUR');
    expect(controller.currency, 'EUR');
    expect(synced, 'EUR');
    expect(controller.isSaving, isFalse);
  });

  test('setCurrency isSaving while remoteSync is in flight', () async {
    final inFlight = Completer<void>();
    final prefs = await SharedPreferences.getInstance();
    final controller = AppCurrencyController(
      prefs,
      remoteSync: (_) => inFlight.future,
    );
    await controller.load();

    final pending = controller.setCurrency('EUR');
    await Future<void>.delayed(Duration.zero);
    expect(controller.isSaving, isTrue);

    inFlight.complete();
    await pending;
    expect(controller.isSaving, isFalse);
  });
}
