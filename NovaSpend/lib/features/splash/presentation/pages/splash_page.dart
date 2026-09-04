import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Branded splash — runs startup in parallel, then auto-dismisses.
class SplashPage extends StatefulWidget {
  const SplashPage({
    required this.onFinished,
    required this.startupFuture,
    super.key,
  });

  final VoidCallback onFinished;
  final Future<void> startupFuture;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  static const _visibleDuration = Duration(milliseconds: 2400);
  static const _entryDuration = Duration(milliseconds: 700);
  static const _idleDuration = Duration(milliseconds: 2200);
  static const _iconAsset = 'assets/branding/app_icon.png';
  static const _iconLogicalSize = 172.0;
  static const _glowSize = _iconLogicalSize * 1.45;

  late final AnimationController _entryController;
  late final AnimationController _idleController;
  late final AnimationController _exitController;
  late final AnimationController _hintController;

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
  var _startupComplete = false;
  var _minTimeElapsed = false;
  var _exitStarted = false;

  @override
  void initState() {
    super.initState();

    unawaited(() async {
      try {
        await widget.startupFuture;
      } catch (e, st) {
        // Never leave the splash hung — parent handles the error UI.
        debugPrint('Splash startup failed: $e\n$st');
      } finally {
        _onStartupSettled();
      }
    }());

    _reduceMotion = SchedulerBinding
        .instance
        .platformDispatcher
        .accessibilityFeatures
        .disableAnimations;

    _entryController = AnimationController(
      vsync: this,
      duration: _reduceMotion ? Duration.zero : _entryDuration,
    );
    _idleController = AnimationController(vsync: this, duration: _idleDuration);
    _exitController = AnimationController(
      vsync: this,
      duration: _reduceMotion ? Duration.zero : AppMotion.fast,
    );
    _hintController = AnimationController(
      vsync: this,
      duration: _reduceMotion ? Duration.zero : AppMotion.slow,
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
    _glowScale = Tween<double>(begin: 0.65, end: 1).animate(
      CurvedAnimation(
        parent: _entryController,
        curve: const Interval(0, 0.55, curve: AppMotion.standard),
      ),
    );
    _glowOpacity = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0, 0.55, curve: AppMotion.enter),
    );
    _titleFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.22, 0.78, curve: AppMotion.enter),
    );
    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entryController,
            curve: const Interval(0.22, 0.78, curve: AppMotion.standard),
          ),
        );
    _taglineFade = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.42, 1, curve: AppMotion.enter),
    );

    _exitFade = Tween<double>(
      begin: 1,
      end: 0,
    ).animate(CurvedAnimation(parent: _exitController, curve: AppMotion.exit));
    _exitScale = Tween<double>(
      begin: 1,
      end: 0.98,
    ).animate(CurvedAnimation(parent: _exitController, curve: AppMotion.exit));

    _entryController.addStatusListener((status) {
      if (status != AnimationStatus.completed || !mounted) return;
      if (_startupComplete) unawaited(_hintController.forward());
      if (!_reduceMotion && !_exitStarted) {
        unawaited(_idleController.repeat());
      }
    });

    if (_reduceMotion) {
      _entryController.value = 1;
    } else {
      unawaited(_entryController.forward());
    }

    _scheduleDismiss();
  }

  void _onStartupSettled() {
    _startupComplete = true;
    _maybeDismiss();
    if (mounted && _entryController.isCompleted) {
      unawaited(_hintController.forward());
    }
  }

  void _scheduleDismiss() {
    final holdBeforeExit = _reduceMotion
        ? _visibleDuration
        : _visibleDuration - AppMotion.fast;
    _dismissTimer = Timer(holdBeforeExit, () {
      _minTimeElapsed = true;
      _maybeDismiss();
    });
  }

  void _maybeDismiss() {
    if (!mounted || _exitStarted) return;
    if (!_startupComplete || !_minTimeElapsed) return;

    _exitStarted = true;
    _idleController.stop();
    if (_reduceMotion) {
      _finish();
      return;
    }
    unawaited(
      _exitController.forward().then((_) {
        if (mounted) _finish();
      }),
    );
  }

  void _onSkip() {
    if (_exitStarted) return;
    HapticFeedback.selectionClick();
    if (!_entryController.isCompleted) {
      _entryController.value = 1;
    }
    _minTimeElapsed = true;
    _maybeDismiss();
  }

  void _onIconTap() {
    if (_exitStarted) return;
    HapticFeedback.lightImpact();
    if (_reduceMotion) return;
    _idleController
      ..stop()
      ..value = 0;
    _hintController.value = _startupComplete ? 1 : 0;
    unawaited(_entryController.forward(from: 0));
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entryController.dispose();
    _idleController.dispose();
    _exitController.dispose();
    _hintController.dispose();
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
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onSkip,
        child: FadeTransition(
          opacity: _exitFade,
          child: ScaleTransition(
            scale: _exitScale,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _entryController,
                    _idleController,
                    _hintController,
                  ]),
                  builder: (context, _) {
                    return Column(
                      children: [
                        const Spacer(flex: 3),
                        Center(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: _onIconTap,
                            child: Semantics(
                              button: true,
                              label: l10n.splashLogoSemantics,
                              child: SizedBox(
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
                                                AppColors.accent.withValues(
                                                  alpha: 0.16,
                                                ),
                                                AppColors.accent.withValues(
                                                  alpha: 0,
                                                ),
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
                                        child: _IdleIcon(
                                          progress: _idleController.value,
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
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
                        const Spacer(flex: 2),
                        FadeTransition(
                          opacity: _hintController,
                          child: Semantics(
                            button: true,
                            label: l10n.splashSkipSemantics,
                            child: Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.xl,
                              ),
                              child: Text(
                                l10n.splashTapToContinue,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.55),
                                  letterSpacing: 0.2,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IdleIcon extends StatelessWidget {
  const _IdleIcon({required this.progress, required this.child});

  final double progress;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final wave = math.sin(progress * math.pi * 2);
    return Transform.translate(
      offset: Offset(0, wave * -4),
      child: Transform.scale(scale: 1 + (wave.abs() * 0.012), child: child),
    );
  }
}
