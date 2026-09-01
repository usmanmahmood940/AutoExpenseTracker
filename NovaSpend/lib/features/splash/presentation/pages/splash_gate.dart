import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/features/auth/presentation/pages/auth_gate.dart';
import 'package:nova_spend/features/splash/presentation/pages/splash_page.dart';

/// Shows [SplashPage] once per cold start, then hands off to [AuthGate].
class SplashGate extends StatefulWidget {
  const SplashGate({super.key});

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  bool _showSplash = true;

  void _onSplashFinished() {
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.normal,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: _showSplash
          ? SplashPage(
              key: const ValueKey('splash'),
              onFinished: _onSplashFinished,
            )
          : const AuthGate(key: ValueKey('auth_gate')),
    );
  }
}
