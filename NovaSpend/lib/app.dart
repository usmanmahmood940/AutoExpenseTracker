import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'core/locale/app_locale_controller.dart';
import 'core/locale/app_locale_scope.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/pages/home_page.dart';
import 'l10n/app_localizations.dart';

class NovaSpendApp extends StatelessWidget {
  const NovaSpendApp({required this.localeController, super.key});

  final AppLocaleController localeController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppLocaleController>.value(
          value: localeController,
        ),
      ],
      child: AppLocaleScope(
        controller: localeController,
        child: ListenableBuilder(
          listenable: localeController,
          builder: (context, _) {
            return MaterialApp(
              title: 'NovaSpend',
              theme: AppTheme.light,
              darkTheme: AppTheme.dark,
              locale: localeController.locale,
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: const HomePage(),
            );
          },
        ),
      ),
    );
  }
}
