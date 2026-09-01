import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Branded splash — visible for 2 seconds, then auto-dismisses.
class SplashPage extends StatefulWidget {
  const SplashPage({required this.onFinished, super.key});

  final VoidCallback onFinished;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  static const _visibleDuration = Duration(seconds: 2);
  static const _iconAsset = 'assets/branding/app_icon_splash.png';
  static const _iconLogicalSize = 168.0;

  late final AnimationController _entryController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();

    final reduceMotion = SchedulerBinding.instance.platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    _entryController = AnimationController(
      vsync: this,
      duration: reduceMotion ? Duration.zero : AppMotion.slow,
    );

    _fadeIn = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.65, curve: AppMotion.enter),
    );
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.1, 1, curve: AppMotion.standard),
      ),
    );

    if (reduceMotion) {
      _entryController.value = 1;
    } else {
      unawaited(_entryController.forward());
    }

    _dismissTimer = Timer(_visibleDuration, _finish);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entryController.dispose();
    super.dispose();
  }

  void _finish() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    _iconAsset,
                    width: _iconLogicalSize,
                    height: _iconLogicalSize,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    gaplessPlayback: true,
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.appTitle,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.splashTagline,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
