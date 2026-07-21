import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// New-password + confirm-password screen shown after a reset OTP is
/// verified.
class ChangePasswordForm extends StatelessWidget {
  const ChangePasswordForm({
    required this.newPasswordController,
    required this.confirmPasswordController,
    required this.obscureNewPassword,
    required this.isSubmitting,
    required this.onToggleNewPasswordVisibility,
    required this.onSubmit,
    required this.onBack,
    this.validationMessage,
    super.key,
  });

  final TextEditingController newPasswordController;
  final TextEditingController confirmPasswordController;
  final bool obscureNewPassword;
  final bool isSubmitting;
  final VoidCallback onToggleNewPasswordVisibility;
  final VoidCallback onSubmit;
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
          Text(
            l10n.authCreateNewPasswordTitle,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: AppSpacing.xl),
          TextFormField(
            controller: newPasswordController,
            obscureText: obscureNewPassword,
            decoration: InputDecoration(
              labelText: l10n.authNewPassword,
              suffixIcon: IconButton(
                onPressed: onToggleNewPasswordVisibility,
                icon: Icon(
                  obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: confirmPasswordController,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.authConfirmPassword),
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
            onPressed: isSubmitting ? null : onSubmit,
            child: Text(l10n.authChangePassword),
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
