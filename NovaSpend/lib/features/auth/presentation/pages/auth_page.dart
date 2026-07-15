import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/forms/validators.dart';
import 'package:nova_spend/core/http/cloud_functions_http_client.dart';
import 'package:nova_spend/core/locale/app_locale_scope.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/core/widgets/app_dialogs.dart';
import 'package:nova_spend/features/auth/presentation/auth_error_mapper.dart';
import 'package:nova_spend/features/auth/presentation/auth_service.dart';
import 'package:nova_spend/features/auth/presentation/auth_submit_flow.dart';
import 'package:nova_spend/features/auth/presentation/widgets/social_sign_in_buttons.dart';
import 'package:nova_spend/features/settings/presentation/pages/language_selection_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';

/// Single host for login, signup, OTP verification, and password reset.
class AuthPage extends StatefulWidget {
  const AuthPage({
    super.key,
    this.authService,
  });

  final AuthService? authService;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  late final AuthService _auth = widget.authService ?? AuthService();
  late final AuthSubmitFlow _submitFlow = AuthSubmitFlow(_auth);
  late final bool _ownsAuth = widget.authService == null;

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLogin = true;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureNewPassword = true;
  bool _acceptedTerms = false;
  bool _checkingEmail = false;
  bool _showVerificationScreen = false;
  bool _showForgotPasswordScreen = false;
  bool _showPasswordResetOtpScreen = false;
  bool _showChangePasswordScreen = false;

  String? _validationMessage;
  String? _infoText;
  String? _pendingSignupEmail;
  String? _pendingSignupPassword;
  String? _resetEmail;
  String? _resetToken;

  int _emailCheckRequestId = 0;
  int _otpResendSecondsRemaining = 0;
  Timer? _otpResendTimer;

  @override
  void dispose() {
    _otpResendTimer?.cancel();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    if (_ownsAuth) {
      _auth.dispose();
    }
    super.dispose();
  }

  void _clearAuthScreenState({bool keepInfo = false}) {
    _otpResendTimer?.cancel();
    setState(() {
      _showVerificationScreen = false;
      _showForgotPasswordScreen = false;
      _showPasswordResetOtpScreen = false;
      _showChangePasswordScreen = false;
      _otpCtrl.clear();
      _newPasswordCtrl.clear();
      _confirmPasswordCtrl.clear();
      _pendingSignupEmail = null;
      _pendingSignupPassword = null;
      _resetEmail = null;
      _resetToken = null;
      _otpResendSecondsRemaining = 0;
      _validationMessage = null;
      if (!keepInfo) _infoText = null;
      _isSubmitting = false;
      _checkingEmail = false;
    });
  }

  void _startResendCooldown() {
    _otpResendTimer?.cancel();
    setState(() {
      _otpResendSecondsRemaining = AppConstants.otpResendCooldownSeconds;
    });
    _otpResendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_otpResendSecondsRemaining <= 1) {
        timer.cancel();
        setState(() => _otpResendSecondsRemaining = 0);
      } else {
        setState(() => _otpResendSecondsRemaining -= 1);
      }
    });
  }

  Future<void> _onEmailChanged(String value) async {
    if (_isLogin) return;
    final email = value.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _checkingEmail = false;
        _validationMessage = null;
      });
      return;
    }

    final requestId = ++_emailCheckRequestId;
    setState(() => _checkingEmail = true);
    try {
      final inUse = await _auth.isEmailAlreadyInUse(email);
      if (!mounted || requestId != _emailCheckRequestId) return;
      setState(() {
        _checkingEmail = false;
        _validationMessage = inUse ? context.l10n.authEmailInUse : null;
      });
    } catch (_) {
      if (!mounted || requestId != _emailCheckRequestId) return;
      setState(() => _checkingEmail = false);
    }
  }

  Future<void> _submitAuthForm() async {
    final l10n = context.l10n;
    setState(() {
      _validationMessage = null;
      _infoText = null;
    });

    if (!_formKey.currentState!.validate()) return;
    if (!_isLogin && !_acceptedTerms) {
      setState(() => _validationMessage = l10n.authAcceptTermsError);
      return;
    }

    setState(() => _isSubmitting = true);
    final outcome = await _submitFlow.submit(
      isLogin: _isLogin,
      email: _emailCtrl.text,
      password: _passwordCtrl.text,
      l10n: l10n,
      acceptedTerms: _acceptedTerms,
    );

    if (!mounted) return;

    if (outcome.errorText != null) {
      setState(() => _isSubmitting = false);
      await AppDialogs.showError(context, message: outcome.errorText!);
      return;
    }

    if (outcome.showVerificationScreen) {
      setState(() {
        _isSubmitting = false;
        _showVerificationScreen = true;
        _pendingSignupEmail = outcome.verificationEmail;
        _pendingSignupPassword = _passwordCtrl.text;
        if (outcome.forceLoginMode) _isLogin = true;
        _infoText = l10n.authOtpSentInstructions;
      });
      _startResendCooldown();
      return;
    }

    setState(() => _isSubmitting = false);
  }

  Future<void> _verifySignupOtp() async {
    final l10n = context.l10n;
    final email = _pendingSignupEmail;
    final password = _pendingSignupPassword;
    if (email == null || password == null) {
      setState(() => _validationMessage = l10n.authSignupSessionExpired);
      return;
    }
    final code = _otpCtrl.text.trim();
    final otpError = AppValidators.otp(code, l10n);
    if (otpError != null) {
      setState(() => _validationMessage = otpError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationMessage = null;
    });

    try {
      await _auth.completeEmailOtpSignup(
        email: email,
        password: password,
        code: code,
      );
      await _auth.signIn(email: email, password: password);
      await _auth.reloadCurrentUser();
      await _auth.currentUser?.getIdTokenResult(true);
      if (!mounted) return;
      _clearAuthScreenState();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      final message = _mapError(e);
      final isInUse = message.toLowerCase().contains('already in use') ||
          e.toString().toLowerCase().contains('already-exists');
      if (isInUse) {
        _clearAuthScreenState();
        setState(() {
          _isLogin = false;
          _validationMessage = l10n.authEmailInUse;
        });
        await AppDialogs.showError(context, message: l10n.authEmailInUse);
        return;
      }
      await AppDialogs.showError(
        context,
        message: message,
      );
    }
  }

  Future<void> _resendSignupOtp() async {
    final email = _pendingSignupEmail;
    if (email == null) return;
    setState(() => _isSubmitting = true);
    try {
      await _auth.sendEmailOtp(email: email);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _infoText = context.l10n.authOtpResentTo(email);
      });
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await AppDialogs.showError(context, message: _mapError(e));
    }
  }

  Future<void> _sendForgotPasswordOtp() async {
    final l10n = context.l10n;
    final emailError = AppValidators.email(_emailCtrl.text, l10n);
    if (emailError != null) {
      setState(() => _validationMessage = emailError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationMessage = null;
    });

    try {
      final email = _emailCtrl.text.trim();
      await _auth.sendPasswordResetOtp(email: email);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _resetEmail = email;
        _showForgotPasswordScreen = false;
        _showPasswordResetOtpScreen = true;
        _infoText = l10n.authResetCodeSent;
      });
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await AppDialogs.showError(context, message: _mapError(e));
    }
  }

  Future<void> _verifyResetOtp() async {
    final l10n = context.l10n;
    final email = _resetEmail;
    if (email == null) {
      setState(() => _validationMessage = l10n.authPasswordResetSessionExpired);
      return;
    }
    final code = _otpCtrl.text.trim();
    final otpError = AppValidators.otp(code, l10n);
    if (otpError != null) {
      setState(() => _validationMessage = otpError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationMessage = null;
    });

    try {
      final token = await _auth.verifyPasswordResetOtp(email: email, code: code);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _resetToken = token;
        _showPasswordResetOtpScreen = false;
        _showChangePasswordScreen = true;
        _otpCtrl.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await AppDialogs.showError(context, message: _mapError(e));
    }
  }

  Future<void> _resendResetOtp() async {
    final email = _resetEmail;
    if (email == null) return;
    setState(() => _isSubmitting = true);
    try {
      await _auth.sendPasswordResetOtp(email: email);
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _infoText = context.l10n.authOtpResentTo(email);
      });
      _startResendCooldown();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await AppDialogs.showError(context, message: _mapError(e));
    }
  }

  Future<void> _completePasswordChange() async {
    final l10n = context.l10n;
    final token = _resetToken;
    if (token == null) {
      setState(() => _validationMessage = l10n.authPasswordResetSessionExpired);
      return;
    }

    final pwdError = AppValidators.password(_newPasswordCtrl.text, l10n);
    if (pwdError != null) {
      setState(() => _validationMessage = pwdError);
      return;
    }
    final confirmError = AppValidators.confirmPassword(
      _confirmPasswordCtrl.text,
      _newPasswordCtrl.text,
      l10n,
    );
    if (confirmError != null) {
      setState(() => _validationMessage = confirmError);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _validationMessage = null;
    });

    try {
      await _auth.completePasswordReset(
        resetToken: token,
        newPassword: _newPasswordCtrl.text,
      );
      if (!mounted) return;
      _clearAuthScreenState(keepInfo: true);
      setState(() {
        _isLogin = true;
        _infoText = l10n.authPasswordChangedLogin;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      await AppDialogs.showError(context, message: _mapError(e));
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isSubmitting = true);
    try {
      await _auth.signInWithGoogle();
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (_isCancelCode(e.code)) return;
      final message = e.code == 'account-exists-with-different-credential'
          ? AuthErrorMapper.friendlyGoogleAccountExists(context.l10n)
          : AuthErrorMapper.friendlyAuthError(
              context.l10n,
              e.code,
              e.message,
            );
      await AppDialogs.showError(context, message: message);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (_isCancelCode(e.code)) return;
      await AppDialogs.showError(
        context,
        message: AuthErrorMapper.friendlyPlatformAuthError(
          context.l10n,
          e.code,
          e.message,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (_isCancelError(e)) return;
      await AppDialogs.showError(context, message: _mapError(e));
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isSubmitting = true);
    try {
      await _auth.signInWithApple();
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (_isCancelCode(e.code)) return;
      final message = e.code == 'account-exists-with-different-credential'
          ? AuthErrorMapper.friendlyAppleAccountExists(context.l10n)
          : AuthErrorMapper.friendlyAuthError(
              context.l10n,
              e.code,
              e.message,
            );
      await AppDialogs.showError(context, message: message);
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (_isCancelCode(e.code)) return;
      await AppDialogs.showError(
        context,
        message: AuthErrorMapper.friendlyPlatformAuthError(
          context.l10n,
          e.code,
          e.message,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      if (_isCancelError(e)) return;
      await AppDialogs.showError(context, message: _mapError(e));
    }
  }

  String _mapError(Object e) {
    final l10n = context.l10n;
    if (e is CloudFunctionsHttpException) return e.message;
    if (e is FirebaseAuthException) {
      return AuthErrorMapper.friendlyAuthError(l10n, e.code, e.message);
    }
    if (e is PlatformException) {
      return AuthErrorMapper.friendlyPlatformAuthError(
        l10n,
        e.code,
        e.message,
      );
    }
    return l10n.errorGeneric;
  }

  bool _isCancelCode(String? code) {
    final c = (code ?? '').toLowerCase();
    return c.contains('cancel') ||
        c.contains('canceled') ||
        c == '12501' ||
        c == 'sign_in_canceled';
  }

  bool _isCancelError(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('cancel') || text.contains('canceled');
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final body = _showChangePasswordScreen
        ? _buildChangePasswordScreen()
        : _showPasswordResetOtpScreen
            ? _buildPasswordResetOtpScreen()
            : _showForgotPasswordScreen
                ? _buildForgotPasswordScreen()
                : _showVerificationScreen
                    ? _buildVerificationScreen()
                    : _buildAuthForm();

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: KeyedSubtree(
                key: ValueKey(
                  '$_showChangePasswordScreen'
                  '$_showPasswordResetOtpScreen'
                  '$_showForgotPasswordScreen'
                  '$_showVerificationScreen'
                  '$_isLogin',
                ),
                child: body,
              ),
            ),
            if (_isSubmitting)
              const Positioned.fill(
                child: ColoredBox(
                  color: Color(0x66000000),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: l10n.settingsLanguage,
                onPressed: () async {
                  final code = await Navigator.of(context).push<String>(
                    MaterialPageRoute(
                      builder: (_) => const LanguageSelectionPage(),
                    ),
                  );
                  if (code != null && context.mounted) {
                    await AppLocaleScope.of(context).setLocale(Locale(code));
                  }
                },
                icon: const Icon(Icons.language),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              l10n.appTitle,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppColors.accent,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              _isLogin ? l10n.authWelcomeBack : l10n.authCreateAccount,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _isLogin ? l10n.authLoginSubtitle : l10n.authSignupSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: l10n.authEmail,
                suffixIcon: _checkingEmail
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              validator: (v) => AppValidators.email(v, l10n),
              onChanged: _onEmailChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              autofillHints: [
                if (_isLogin) AutofillHints.password else AutofillHints.newPassword,
              ],
              decoration: InputDecoration(
                labelText: l10n.authPassword,
                suffixIcon: IconButton(
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (v) => AppValidators.password(v, l10n),
            ),
            if (_isLogin) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () {
                          setState(() {
                            _showForgotPasswordScreen = true;
                            _validationMessage = null;
                            _infoText = null;
                          });
                        },
                  child: Text(l10n.authForgotPassword),
                ),
              ),
            ],
            if (!_isLogin) ...[
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _acceptedTerms,
                onChanged: (v) => setState(() => _acceptedTerms = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.authTermsConsent),
              ),
            ],
            if (_validationMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _validationMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_infoText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _infoText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _isSubmitting ? null : _submitAuthForm,
              child: Text(_isLogin ? l10n.authLogin : l10n.authSignUp),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: _isSubmitting
                  ? null
                  : () {
                      setState(() {
                        _isLogin = !_isLogin;
                        _validationMessage = null;
                        _infoText = null;
                        _acceptedTerms = false;
                      });
                    },
              child: Text(
                _isLogin ? l10n.authNeedAccount : l10n.authHaveAccount,
              ),
            ),
            if (_isLogin) ...[
              const SizedBox(height: AppSpacing.lg),
              _OrDivider(label: l10n.authOr),
              const SizedBox(height: AppSpacing.lg),
              SocialSignInButtons(
                enabled: !_isSubmitting,
                googleLabel: l10n.authContinueWithGoogle,
                appleLabel: l10n.authContinueWithApple,
                onGooglePressed: _signInWithGoogle,
                onApplePressed: _signInWithApple,
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.authLegalPrefix),
                TextButton(
                  onPressed: () => _openUrl(AppConstants.termsUrl),
                  child: Text(l10n.authTerms),
                ),
                Text(l10n.authAnd),
                TextButton(
                  onPressed: () => _openUrl(AppConstants.privacyUrl),
                  child: Text(l10n.authPrivacy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationScreen() {
    final l10n = context.l10n;
    final email = _pendingSignupEmail ?? '';
    return _OtpScaffold(
      title: l10n.authVerifyEmailTitle,
      body: l10n.authVerifyEmailBody(email),
      otpController: _otpCtrl,
      otpLabel: l10n.authOtpCodeLabel,
      validationMessage: _validationMessage,
      infoText: _infoText,
      onVerify: _verifySignupOtp,
      onResend: _resendSignupOtp,
      resendLabel: _otpResendSecondsRemaining > 0
          ? l10n.authResendOtpIn('$_otpResendSecondsRemaining')
          : l10n.authResendOtp,
      canResend: !_isSubmitting && _otpResendSecondsRemaining == 0,
      onBack: () {
        _clearAuthScreenState();
        setState(() => _validationMessage = l10n.authSignupSessionExpired);
      },
      backLabel: l10n.authBackToLogin,
      verifyLabel: l10n.authVerifyOtp,
    );
  }

  Widget _buildForgotPasswordScreen() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.authResetPasswordTitle, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(l10n.authResetPasswordSubtitle),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.authEmail),
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _validationMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isSubmitting ? null : _sendForgotPasswordOtp,
            child: Text(l10n.authSendResetCode),
          ),
          TextButton(
            onPressed: () => _clearAuthScreenState(),
            child: Text(l10n.authBackToLogin),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordResetOtpScreen() {
    final l10n = context.l10n;
    final email = _resetEmail ?? '';
    return _OtpScaffold(
      title: l10n.authResetPasswordTitle,
      body: l10n.authPasswordResetOtpInstructions(email),
      otpController: _otpCtrl,
      otpLabel: l10n.authOtpCodeLabel,
      validationMessage: _validationMessage,
      infoText: _infoText,
      onVerify: _verifyResetOtp,
      onResend: _resendResetOtp,
      resendLabel: _otpResendSecondsRemaining > 0
          ? l10n.authResendOtpIn('$_otpResendSecondsRemaining')
          : l10n.authResendOtp,
      canResend: !_isSubmitting && _otpResendSecondsRemaining == 0,
      onBack: () => _clearAuthScreenState(),
      backLabel: l10n.authBackToLogin,
      verifyLabel: l10n.authVerifyOtp,
    );
  }

  Widget _buildChangePasswordScreen() {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.authCreateNewPasswordTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: _newPasswordCtrl,
            obscureText: _obscureNewPassword,
            decoration: InputDecoration(
              labelText: l10n.authNewPassword,
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscureNewPassword = !_obscureNewPassword),
                icon: Icon(
                  _obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _confirmPasswordCtrl,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.authConfirmPassword),
          ),
          if (_validationMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _validationMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _isSubmitting ? null : _completePasswordChange,
            child: Text(l10n.authChangePassword),
          ),
          TextButton(
            onPressed: () => _clearAuthScreenState(),
            child: Text(l10n.authBackToLogin),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor;
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(label),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }
}

class _OtpScaffold extends StatelessWidget {
  const _OtpScaffold({
    required this.title,
    required this.body,
    required this.otpController,
    required this.otpLabel,
    required this.onVerify,
    required this.onResend,
    required this.resendLabel,
    required this.canResend,
    required this.onBack,
    required this.backLabel,
    required this.verifyLabel,
    this.validationMessage,
    this.infoText,
  });

  final String title;
  final String body;
  final TextEditingController otpController;
  final String otpLabel;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final String resendLabel;
  final bool canResend;
  final VoidCallback onBack;
  final String backLabel;
  final String verifyLabel;
  final String? validationMessage;
  final String? infoText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          Text(body),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: otpController,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: otpLabel,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
          if (validationMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              validationMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          if (infoText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              infoText!,
              style: const TextStyle(color: AppColors.accent),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(onPressed: onVerify, child: Text(verifyLabel)),
          TextButton(
            onPressed: canResend ? onResend : null,
            child: Text(resendLabel),
          ),
          TextButton(onPressed: onBack, child: Text(backLabel)),
        ],
      ),
    );
  }
}
