import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/features/categories/presentation/widgets/category_catalog_scope.dart';
import 'package:nova_spend/features/transactions/domain/usecases/create_transaction.dart';
import 'package:nova_spend/features/transactions/domain/usecases/parse_transaction_text.dart';
import 'package:nova_spend/features/transactions/presentation/provider/manual_log_provider.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/manual_log_sheet.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'manual_log_provider_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Read message is disabled until paste text is entered', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final currency = AppCurrencyController(prefs);
    await currency.load();

    final repo = FakeManualLogRepo();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AppCurrencyScope(
          controller: currency,
          child: CategoryCatalogScope(
            categories: const [],
            child: ChangeNotifierProvider(
              create: (_) => ManualLogProvider(
                parseTransactionText: ParseTransactionText(repo),
                createTransaction: CreateTransaction(repo),
              )..configure(uid: 'user-1', currency: 'PKR'),
              child: const Scaffold(body: ManualLogSheet()),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'spent 200 at KFC');
    await tester.pump();

    final enabled = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(enabled.onPressed, isNotNull);
  });
}
