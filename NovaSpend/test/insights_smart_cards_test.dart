import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/features/analytics/domain/entities/smart_card_entity.dart';
import 'package:nova_spend/features/analytics/presentation/widgets/insights_smart_cards.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cards = [
    SmartCardEntity(
      title: 'Card 1',
      body: 'Body 1',
      signalType: 'spike',
      suggestedQuestion: 'Question 1',
    ),
    SmartCardEntity(
      title: 'Card 2',
      body: 'Body 2',
      signalType: 'spike',
      suggestedQuestion: 'Question 2',
    ),
    SmartCardEntity(
      title: 'Card 3',
      body: 'Body 3',
      signalType: 'spike',
      suggestedQuestion: 'Question 3',
    ),
  ];

  testWidgets('InsightsSmartCards limits cards when maxCards is specified', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InsightsSmartCards(
            cards: cards,
            maxCards: 2,
            onAsk: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Card 1'), findsOneWidget);
    expect(find.text('Card 2'), findsOneWidget);
    expect(find.text('Card 3'), findsNothing);
  });

  testWidgets('InsightsSmartCards shows every card when maxCards is omitted', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InsightsSmartCards(
            cards: cards,
            onAsk: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Card 1'), findsOneWidget);
    expect(find.text('Card 2'), findsOneWidget);
    expect(find.text('Card 3'), findsOneWidget);
  });
}
