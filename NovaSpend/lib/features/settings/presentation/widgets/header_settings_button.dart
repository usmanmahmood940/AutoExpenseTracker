import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_spacing.dart';
import 'package:nova_spend/features/settings/presentation/main_shell_scope.dart';
import 'package:nova_spend/l10n/app_strings.dart';

/// Compact gear control for [GlassHeaderBar] — opens Settings as a pushed route.
class HeaderSettingsButton extends StatelessWidget {
  const HeaderSettingsButton({super.key});

  static const double _iconSize = 20;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = AppColors.primaryInk(Theme.of(context).brightness);

    return Semantics(
      button: true,
      label: l10n.settingsTitle,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          MainShellScope.openSettings(context);
        },
        child: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.sm),
          child: SvgPicture.asset(
            'assets/icons/icon_nav_settings.svg',
            width: _iconSize,
            height: _iconSize,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
