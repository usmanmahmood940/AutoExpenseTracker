import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nova_spend/app.dart';
import 'package:nova_spend/core/locale/app_locale_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('NovaSpend home page renders welcome message', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final localeController = AppLocaleController(prefs);
    await localeController.load();

    await tester.pumpWidget(NovaSpendApp(localeController: localeController));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to NovaSpend'), findsOneWidget);
  });
}
