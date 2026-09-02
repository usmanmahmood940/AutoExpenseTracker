import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nova_spend/app.dart';
import 'package:nova_spend/core/bootstrap/app_bootstrap.dart';
import 'package:nova_spend/core/theme/app_theme.dart';
import 'package:nova_spend/features/splash/presentation/pages/splash_page.dart';
import 'package:nova_spend/l10n/app_localizations.dart';

/// Shows the branded splash immediately, runs startup there, then opens the app.
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  AppStartupResult? _startup;
  late final Future<AppStartupResult> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = AppBootstrap.instance.initialize();
  }

  void _onSplashFinished() {
    unawaited(
      _startupFuture.then((result) {
        if (!mounted) return;
        setState(() => _startup = result);
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_startup != null) {
      return NovaSpendApp(
        localeController: _startup!.localeController,
        currencyController: _startup!.currencyController,
      );
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SplashPage(
        startupFuture: _startupFuture,
        onFinished: _onSplashFinished,
      ),
    );
  }
}
