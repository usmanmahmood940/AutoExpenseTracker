import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/features/auth/presentation/auth_service.dart';
import 'package:nova_spend/features/auth/presentation/pages/auth_page.dart';
import 'package:nova_spend/features/auth/presentation/pages/lock_gate.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Routes signed-out users to [AuthPage] and signed-in users to [LockGate].
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _authService = AuthService();
  bool _verifiedOnce = false;
  bool _profileKickoffDone = false;
  bool _forceAuthPage = false;

  @override
  void dispose() {
    _authService.dispose();
    super.dispose();
  }

  /// Call after account deletion while a stale Auth user may briefly remain.
  void forceLoginAfterAccountDeletion() {
    setState(() => _forceAuthPage = true);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, snapshot) {
        final waiting = snapshot.connectionState == ConnectionState.waiting;
        final user = snapshot.data;

        if (waiting && user == null) {
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

        if (_forceAuthPage || user == null) {
          if (user == null && _forceAuthPage) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) setState(() => _forceAuthPage = false);
            });
          }
          _verifiedOnce = false;
          _profileKickoffDone = false;
          return const AuthPage();
        }

        if (!_verifiedOnce && !AppConstants.kSkipEmailVerificationCheck) {
          _verifiedOnce = true;
          unawaited(_backgroundVerify(user));
        }

        if (!_profileKickoffDone) {
          _profileKickoffDone = true;
          unawaited(_ensureProfile());
        }

        return const LockGate();
      },
    );
  }

  Future<void> _backgroundVerify(User user) async {
    try {
      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;
      if (refreshed == null) return;
      final token = await refreshed.getIdTokenResult(true);
      final ok = AuthService.hasVerifiedPortfolioAccess(
        user: refreshed,
        token: token,
      );
      if (!ok) {
        await FirebaseAuth.instance.signOut();
      }
    } catch (_) {
      // Fail-open on transient errors.
    }
  }

  Future<void> _ensureProfile() async {
    try {
      await _authService.ensureUserProfile();
    } catch (_) {
      // Non-blocking.
    }
  }
}
