import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/features/transactions/presentation/widgets/settle_transactions_sheet.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpButton(
    WidgetTester tester, {
    required int selectedCount,
    required VoidCallback onSettle,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SettleActionButton(
            selectedCount: selectedCount,
            onSettle: onSettle,
          ),
        ),
      ),
    );
  }

  testWidgets('shows need-two dialog when Settle is tapped with one selected', (
    tester,
  ) async {
    var settled = false;
    await pumpButton(
      tester,
      selectedCount: 1,
      onSettle: () => settled = true,
    );

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

    await tester.tap(find.byType(SettleActionButton));
    await tester.pumpAndSettle();

    expect(find.text('Select more transactions'), findsOneWidget);
    expect(
      find.text('Select at least 2 transactions to settle.'),
      findsOneWidget,
    );
    expect(settled, isFalse);
  });

  testWidgets('calls onSettle when two transactions are selected', (
    tester,
  ) async {
    var settled = false;
    await pumpButton(
      tester,
      selectedCount: 2,
      onSettle: () => settled = true,
    );

    await tester.tap(find.text('Settle'));
    await tester.pump();

    expect(settled, isTrue);
    expect(find.text('Select more transactions'), findsNothing);
  });
}
