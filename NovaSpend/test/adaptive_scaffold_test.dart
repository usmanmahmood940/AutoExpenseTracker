import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/core/widgets/adaptive_scaffold.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

void main() {
  testWidgets('iOS titled scaffold has a Material back icon and no extra top gap',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.iOS, useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdaptiveScaffold(
                      title: 'Settings',
                      body: Text('Account'),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
    expect(find.byType(CupertinoNavigationBar), findsOneWidget);

    final navBottom = tester.getBottomLeft(find.byType(CupertinoNavigationBar)).dy;
    final bodyTop = tester.getTopLeft(find.text('Account')).dy;
    expect(
      bodyTop - navBottom,
      lessThan(8),
      reason: 'SafeArea must not add a sticky band under the nav bar',
    );
  });

  testWidgets('Android titled scaffold uses a Material back icon', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.android, useMaterial3: true),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            return TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AdaptiveScaffold(
                      title: 'Settings',
                      body: Text('Account'),
                    ),
                  ),
                );
              },
              child: const Text('open'),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);
  });
}
