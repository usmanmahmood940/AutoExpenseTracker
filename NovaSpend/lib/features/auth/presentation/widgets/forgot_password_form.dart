import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Email entry screen that kicks off the password-reset OTP flow.
class ForgotPasswordForm extends StatelessWidget {
  const ForgotPasswordForm({
    required this.emailController,
    required this.isSubmitting,
    required this.onSendResetCode,
    required this.onBack,
    this.validationMessage,
    super.key,
  });

  final TextEditingController emailController;
  final bool isSubmitting;
  final VoidCallback onSendResetCode;
  final VoidCallback onBack;
  final String? validationMessage;

  @override
  Widget build(BuildContext context) {
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
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: l10n.authEmail),
          ),
          if (validationMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              validationMessage!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: isSubmitting ? null : onSendResetCode,
            child: Text(l10n.authSendResetCode),
          ),
          TextButton(
            onPressed: onBack,
            child: Text(l10n.authBackToLogin),
          ),
        ],
      ),
    );
  }
}
