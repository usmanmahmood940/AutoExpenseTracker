import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nova_spend/features/splash/presentation/pages/splash_page.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

void main() {
  testWidgets('splash skip dismisses after startup', (tester) async {
    var finished = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SplashPage(
          startupFuture: Future<void>.value(),
          onFinished: () => finished = true,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(
      tester.getTopLeft(find.byType(Scaffold)) + const Offset(24, 48),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(finished, isTrue);
  });
}
