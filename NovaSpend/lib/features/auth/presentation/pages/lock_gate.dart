import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nova_spend/core/di/injection.dart';
import 'package:nova_spend/core/services/biometric_service.dart';
import 'package:nova_spend/features/auth/presentation/provider/auth_provider.dart';
import 'package:nova_spend/features/settings/domain/repositories/settings_repository.dart';
import 'package:nova_spend/features/settings/presentation/pages/main_shell_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:provider/provider.dart';

/// Gates the main shell behind biometric unlock when enabled.
class LockGate extends StatefulWidget {
  const LockGate({super.key});

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> {
  bool _checking = true;
  bool _unlocked = false;
  bool _biometricRequired = false;

  @override
  void initState() {
    super.initState();
    unawaited(_bootstrap());
  }

  Future<void> _bootstrap() async {
    final settings = sl<SettingsRepository>();
    final required = await settings.isBiometricEnabled();
    if (!mounted) return;

    if (!required) {
      setState(() {
        _biometricRequired = false;
        _unlocked = true;
        _checking = false;
      });
      return;
    }

    setState(() {
      _biometricRequired = true;
      _checking = false;
    });
    await _tryUnlock();
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

    if (auth.isLoading || _checking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.l10n.commonLoading),
            ],
          ),
        ),
      );
    }

    if (!auth.isSignedIn) {
      // AuthGate should have already switched; keep a brief spinner.
      return Scaffold(
        body: Center(child: Text(context.l10n.commonLoading)),
      );
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
