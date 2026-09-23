import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/currency/app_currency_controller.dart';
import 'package:nova_spend/core/currency/app_currency_scope.dart';
import 'package:nova_spend/core/http/api_json.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/transactions/domain/entities/transaction_entity.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/settle_transactions_sheet.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeAuthProvider extends ChangeNotifier implements AuthProvider {
  @override
  String? get uid => 'user-1';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

TransactionEntity _testTx({
  required String id,
  required String merchant,
  required double amount,
  required String type,
  String category = 'General',
}) {
  return transactionFromApi({
    'id': id,
    'user_id': 'user-1',
    'amount': amount,
    'currency': 'PKR',
    'type': type,
    'merchant': merchant,
    'category': category,
    'category_source': 'rule',
    'payment_method': 'unknown',
    'bank': '',
    'account_id': '',
    'account_id_masked': '',
    'transaction_time': '08:24 PM',
    'transaction_date': '2026-09-21',
    'day': 'Monday',
    'external_id_type': 'unknown',
    'dedup_key': id,
    'sms_source': const {},
    'parse_confidence': 1,
    'is_auto_detected': false,
    'is_edited': false,
    'is_duplicate': false,
    'status': 'active',
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<Widget> buildTestWidget(List<TransactionEntity> selected) async {
    final prefs = await SharedPreferences.getInstance();
    final currencyController = AppCurrencyController(prefs);
    await currencyController.load();

    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => FakeAuthProvider(),
      child: AppCurrencyScope(
        controller: currencyController,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SettleTransactionsSheet(selected: selected),
          ),
        ),
      ),
    );
  }

  testWidgets(
      'calculates net 0 and enables button when debit and credit offset each other',
      (tester) async {
    final zoom = _testTx(
      id: 'zoom-1',
      merchant: 'ZOOM LAHORE',
      amount: 600,
      type: 'debit',
      category: 'Shopping',
    );
    final touseef = _testTx(
      id: 'touseef-1',
      merchant: 'M.Touseef',
      amount: 600,
      type: 'credit',
      category: 'Transfer',
    );

    await tester.pumpWidget(await buildTestWidget([zoom, touseef]));
    await tester.pumpAndSettle();

    // By default, debit (ZOOM LAHORE) is selected as primary.
    expect(find.text('Primary becomes PKR 0'), findsOneWidget);
    final buttonFinder = find.widgetWithText(FilledButton, 'Settle into primary');
    expect(buttonFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);

    // Now tap M.Touseef (credit) to make it primary.
    await tester.tap(find.text('M.Touseef'));
    await tester.pumpAndSettle();

    // Settle into M.Touseef should ALSO be PKR 0, NOT PKR 1,200!
    expect(find.text('Primary becomes PKR 0'), findsOneWidget);
    expect(find.text('Primary becomes PKR 1,200'), findsNothing);
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);
  });

  testWidgets('same-type credits increase the primary net', (tester) async {
    final payroll = _testTx(
      id: 'payroll-1',
      merchant: 'Payroll',
      amount: 1000,
      type: 'credit',
    );
    final bonus = _testTx(
      id: 'bonus-1',
      merchant: 'Bonus',
      amount: 200,
      type: 'credit',
    );

    await tester.pumpWidget(await buildTestWidget([payroll, bonus]));
    await tester.pumpAndSettle();

    expect(find.text('Primary becomes PKR 1,200'), findsOneWidget);
    final buttonFinder = find.widgetWithText(FilledButton, 'Settle into primary');
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNotNull);
  });

  testWidgets('disables button when preview net is negative', (tester) async {
    final debit = _testTx(
      id: 'debit-1',
      merchant: 'Small Spend',
      amount: 500,
      type: 'debit',
    );
    final credit = _testTx(
      id: 'credit-1',
      merchant: 'Large Transfer',
      amount: 700,
      type: 'credit',
    );

    await tester.pumpWidget(await buildTestWidget([debit, credit]));
    await tester.pumpAndSettle();

    // 500 - 700 = -200
    final buttonFinder = find.widgetWithText(FilledButton, 'Settle into primary');
    expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);
  });
}
