import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/services/biometric_service.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/settings/presentation/pages/main_shell_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gates the main shell behind biometric unlock when enabled.
class LockGate extends StatefulWidget {
  const LockGate({super.key});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  late final bool _biometricRequired;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _biometricRequired = sl<SharedPreferences>().getBool(
          AppConstants.prefBiometricLock,
        ) ??
        false;
    if (!_biometricRequired) {
      _unlocked = true;
    } else {
      unawaited(_tryUnlock());
    }
  }

  Future<void> _tryUnlock() async {
    final ok = await sl<BiometricService>().authenticate(
      reason: context.l10n.authUnlockSubtitle,
    );
    if (!mounted) return;
    setState(() => _unlocked = ok);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isSignedIn) {
      // AuthGate should have already switched.
      return const SizedBox.shrink();
    }

    if (_biometricRequired && !_unlocked) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.authUnlockTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.authUnlockSubtitle,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _tryUnlock,
                  child: Text(context.l10n.authUnlockButton),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return const MainShellPage();
  }
}
