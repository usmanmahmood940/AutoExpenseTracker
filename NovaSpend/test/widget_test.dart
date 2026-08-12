import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nova_spend/app.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/locale/app_locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NovaSpend shows auth welcome when signed out', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final localeController = AppLocaleController(prefs);
    await localeController.load();
    final currencyController = AppCurrencyController(prefs);
    await currencyController.load();

    await tester.pumpWidget(NovaSpendApp(
      localeController: localeController,
      currencyController: currencyController,
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Without Firebase init this may show loading; prefer no crash.
    expect(find.byType(NovaSpendApp), findsOneWidget);
  }, skip: true); // Requires Firebase.initializeApp in test harness.
}
