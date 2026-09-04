import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:nova_spend/app.dart';
import 'package:nova_spend/core/bootstrap/app_bootstrap.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/theme/app_theme.dart';
import 'package:nova_spend/features/splash/presentation/pages/splash_page.dart';
import 'package:nova_spend/l10n/app_localizations.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Shows the branded splash immediately, runs startup there, then opens the app.
class BootstrapApp extends StatefulWidget {
  const BootstrapApp({super.key});

  @override
  State<BootstrapApp> createState() => _BootstrapAppState();
}

class _BootstrapAppState extends State<BootstrapApp> {
  AppStartupResult? _startup;
  Object? _startupError;
  late Future<AppStartupResult> _startupFuture;

  @override
  void initState() {
    super.initState();
    _startupFuture = AppBootstrap.instance.initialize();
  }

  void _onSplashFinished() {
    unawaited(
      _startupFuture.then((result) {
        if (!mounted) return;
        setState(() {
          _startup = result;
          _startupError = null;
        });
      }).catchError((Object e) {
        if (!mounted) return;
        setState(() => _startupError = e);
      }),
    );
  }

  void _retryStartup() {
    AppBootstrap.instance.reset();
    setState(() {
      _startup = null;
      _startupError = null;
      _startupFuture = AppBootstrap.instance.initialize();
    });
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
      home: _startupError != null
          ? _StartupErrorPage(onRetry: _retryStartup)
          : SplashPage(
              startupFuture: _startupFuture,
              onFinished: _onSplashFinished,
            ),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final brightness = theme.brightness;

    return Scaffold(
      backgroundColor: AppColors.surface(brightness),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.errorGeneric,
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.errorLoadFailedHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: onRetry,
                  child: Text(l10n.errorRetry),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
