import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';

/// Shared 6-digit OTP entry screen used for signup verification and
/// password-reset codes.
class OtpVerificationForm extends StatelessWidget {
  const OtpVerificationForm({
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
    super.key,
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
