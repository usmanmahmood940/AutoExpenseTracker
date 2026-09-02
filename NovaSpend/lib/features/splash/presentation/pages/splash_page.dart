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

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const _visibleDuration = Duration(seconds: 2);
  static const _entryDuration = Duration(milliseconds: 650);
  static const _iconAsset = 'assets/branding/app_icon.png';
  static const _iconLogicalSize = 168.0;
  static const _glowSize = _iconLogicalSize * 1.45;

  late final AnimationController _entryController;
  late final AnimationController _exitController;

  late final Animation<double> _iconFade;
  late final Animation<double> _iconScale;
  late final Animation<double> _glowScale;
  late final Animation<double> _glowOpacity;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _taglineFade;
  late final Animation<double> _exitFade;
  late final Animation<double> _exitScale;

  Timer? _dismissTimer;
  late final bool _reduceMotion;

  @override
  void initState() {
    super.initState();

    _reduceMotion = SchedulerBinding.instance.platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    _entryController = AnimationController(
      vsync: this,
      duration: _reduceMotion ? Duration.zero : _entryDuration,
    );
    _exitController = AnimationController(
      vsync: this,
      duration: _reduceMotion ? Duration.zero : AppMotion.fast,
    );

    _iconFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.55, curve: AppMotion.enter),
    );
    _iconScale = Tween<double>(begin: 0.92, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0, 0.55, curve: AppMotion.standard),
      ),
    );
    _glowScale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0, 0.5, curve: AppMotion.standard),
      ),
    );
    _glowOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.5, curve: AppMotion.enter),
    );
    _titleFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.2, 0.75, curve: AppMotion.enter),
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0.2, 0.75, curve: AppMotion.standard),
      ),
    );
    _taglineFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.4, 1, curve: AppMotion.enter),
    );

    _exitFade = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _exitController, curve: AppMotion.exit),
    );
    _exitScale = Tween<double>(begin: 1, end: 0.98).animate(
      CurvedAnimation(parent: _exitController, curve: AppMotion.exit),
    );

    if (_reduceMotion) {
      _entryController.value = 1;
    } else {
      unawaited(_entryController.forward());
    }

    _scheduleDismiss();
  }

  void _scheduleDismiss() {
    final holdBeforeExit = _reduceMotion
        ? _visibleDuration
        : _visibleDuration - AppMotion.fast;
    _dismissTimer = Timer(holdBeforeExit, () {
      if (!mounted) return;
      if (_reduceMotion) {
        _finish();
        return;
      }
      unawaited(
        _exitController.forward().then((_) {
          if (mounted) _finish();
        }),
      );
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entryController.dispose();
    _exitController.dispose();
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
          opacity: _exitFade,
          child: ScaleTransition(
            scale: _exitScale,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: _glowSize,
                    height: _glowSize,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        FadeTransition(
                          opacity: _glowOpacity,
                          child: ScaleTransition(
                            scale: _glowScale,
                            child: Container(
                              width: _glowSize,
                              height: _glowSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.accent.withValues(alpha: 0.14),
                                    AppColors.accent.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        FadeTransition(
                          opacity: _iconFade,
                          child: ScaleTransition(
                            scale: _iconScale,
                            child: Image.asset(
                              _iconAsset,
                              width: _iconLogicalSize,
                              height: _iconLogicalSize,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                              gaplessPlayback: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: Text(
                        l10n.appTitle,
                        style: theme.textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      l10n.splashTagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      textAlign: TextAlign.center,
                    ),
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
