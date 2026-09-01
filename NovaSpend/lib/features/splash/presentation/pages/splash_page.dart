import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/glass_surface.dart';
import 'package:nova_spend/features/splash/presentation/widgets/splash_logo_mark.dart';
import 'package:nova_spend/features/splash/presentation/widgets/splash_orbital_ring.dart';
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

  late final AnimationController _entryController;
  late final AnimationController _orbitController;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _lineProgress;

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
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
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
    _lineProgress = CurvedAnimation(
      parent: _entryController,
      curve: const Interval(0.15, 0.95, curve: AppMotion.standard),
    );

    if (reduceMotion) {
      _entryController.value = 1;
    } else {
      unawaited(_entryController.forward());
      unawaited(_orbitController.repeat());
    }

    _dismissTimer = Timer(_visibleDuration, _finish);
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _entryController.dispose();
    _orbitController.dispose();
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
    final brightness = theme.brightness;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface(brightness),
      body: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _fadeIn,
            child: SlideTransition(
              position: _slideUp,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: Listenable.merge([
                        _orbitController,
                        _lineProgress,
                      ]),
                      builder: (context, _) {
                        return SplashOrbitalRing(
                          rotation: reduceMotion ? 0 : _orbitController.value,
                          child: GlassSurface(
                            borderRadius: AppRadius.xl + 8,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: SplashLogoMark(
                              pulse: false,
                              lineProgress: _lineProgress.value,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      l10n.appTitle,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryStrong,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      l10n.splashTagline,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
