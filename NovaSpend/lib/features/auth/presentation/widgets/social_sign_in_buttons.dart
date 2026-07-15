import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_radius.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Official-feeling Google + Apple sign-in buttons (brand guidelines).
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    required this.onGooglePressed,
    required this.onApplePressed,
    required this.googleLabel,
    required this.appleLabel,
    this.enabled = true,
    super.key,
  });

  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;
  final String googleLabel;
  final String appleLabel;
  final bool enabled;

  static bool get showAppleButton =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _GoogleSignInButton(
          label: googleLabel,
          onPressed: enabled ? onGooglePressed : null,
        ),
        if (showAppleButton) ...[
          const SizedBox(height: AppSpacing.sm),
          _AppleSignInButton(
            label: appleLabel,
            onPressed: enabled ? onApplePressed : null,
          ),
        ],
      ],
    );
  }
}

/// Google Identity-style button: white/dark surface, border, multicolor G.
class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  static const _borderLight = Color(0xFF747775);
  static const _borderDark = Color(0xFF8E918F);
  static const _labelLight = Color(0xFF1F1F1F);
  static const _fillDark = Color(0xFF131314);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabled = onPressed != null;

    return SizedBox(
      height: 48,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: isDark ? _fillDark : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            side: BorderSide(
              color: isDark ? _borderDark : _borderLight,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/google_g.png',
                    width: 20,
                    height: 20,
                    filterQuality: FilterQuality.high,
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.15,
                        height: 1.2,
                        color: isDark ? Colors.white : _labelLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// System [SignInWithAppleButton] on iOS for maximum familiarity.
class _AppleSignInButton extends StatelessWidget {
  const _AppleSignInButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 48,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: IgnorePointer(
          ignoring: !enabled,
          child: SignInWithAppleButton(
            onPressed: onPressed ?? () {},
            text: label,
            height: 48,
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.sm)),
            style: isDark
                ? SignInWithAppleButtonStyle.white
                : SignInWithAppleButtonStyle.black,
          ),
        ),
      ),
    );
  }
}
