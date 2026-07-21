import 'package:flutter/material.dart';
import 'package:nova_spend/core/constants/app_constants.dart';
import 'package:nova_spend/core/forms/validators.dart';
import 'package:nova_spend/core/locale/app_locale_scope.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/auth/presentation/widgets/or_divider.dart';
import 'package:nova_spend/features/auth/presentation/widgets/social_sign_in_buttons.dart';
import 'package:nova_spend/features/settings/presentation/pages/language_selection_page.dart';
import 'package:nova_spend/l10n/app_strings.dart';
import 'package:url_launcher/url_launcher.dart';

/// Combined login / signup form: email + password fields, terms
/// acceptance, and social sign-in entry points.
class LoginSignupForm extends StatelessWidget {
  const LoginSignupForm({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.isLogin,
    required this.obscurePassword,
    required this.acceptedTerms,
    required this.isSubmitting,
    required this.checkingEmail,
    required this.onEmailChanged,
    required this.onTogglePasswordVisibility,
    required this.onForgotPassword,
    required this.onAcceptedTermsChanged,
    required this.onSubmit,
    required this.onToggleMode,
    required this.onGoogleSignIn,
    required this.onAppleSignIn,
    this.validationMessage,
    this.infoText,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool isLogin;
  final bool obscurePassword;
  final bool acceptedTerms;
  final bool isSubmitting;
  final bool checkingEmail;
  final ValueChanged<String> onEmailChanged;
  final VoidCallback onTogglePasswordVisibility;
  final VoidCallback onForgotPassword;
  final ValueChanged<bool> onAcceptedTermsChanged;
  final VoidCallback onSubmit;
  final VoidCallback onToggleMode;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onAppleSignIn;
  final String? validationMessage;
  final String? infoText;

  Future<void> _openUrl(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Form(
        key: formKey,
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
              isLogin ? l10n.authWelcomeBack : l10n.authCreateAccount,
              style: theme.textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isLogin ? l10n.authLoginSubtitle : l10n.authSignupSubtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(
                labelText: l10n.authEmail,
                suffixIcon: checkingEmail
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
              onChanged: onEmailChanged,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: passwordController,
              obscureText: obscurePassword,
              autofillHints: [
                if (isLogin) AutofillHints.password else AutofillHints.newPassword,
              ],
              decoration: InputDecoration(
                labelText: l10n.authPassword,
                suffixIcon: IconButton(
                  onPressed: onTogglePasswordVisibility,
                  icon: Icon(
                    obscurePassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
              validator: (v) => AppValidators.password(v, l10n),
            ),
            if (isLogin) ...[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isSubmitting ? null : onForgotPassword,
                  child: Text(l10n.authForgotPassword),
                ),
              ),
            ],
            if (!isLogin) ...[
              const SizedBox(height: AppSpacing.sm),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: acceptedTerms,
                onChanged: (v) => onAcceptedTermsChanged(v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l10n.authTermsConsent),
              ),
            ],
            if (validationMessage != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                validationMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (infoText != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                infoText!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.accent,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: isSubmitting ? null : onSubmit,
              child: Text(isLogin ? l10n.authLogin : l10n.authSignUp),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: isSubmitting ? null : onToggleMode,
              child: Text(
                isLogin ? l10n.authNeedAccount : l10n.authHaveAccount,
              ),
            ),
            if (isLogin) ...[
              const SizedBox(height: AppSpacing.lg),
              OrDivider(label: l10n.authOr),
              const SizedBox(height: AppSpacing.lg),
              SocialSignInButtons(
                enabled: !isSubmitting,
                googleLabel: l10n.authContinueWithGoogle,
                appleLabel: l10n.authContinueWithApple,
                onGooglePressed: onGoogleSignIn,
                onApplePressed: onAppleSignIn,
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
}
