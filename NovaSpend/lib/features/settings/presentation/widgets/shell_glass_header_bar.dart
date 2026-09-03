import 'package:flutter/material.dart';
import 'package:nova_spend/core/widgets/glass_header_bar.dart';
import 'package:nova_spend/features/settings/presentation/widgets/header_settings_button.dart';

/// Brand header used on primary tabs, with Settings in the top-right.
class ShellGlassHeaderBar extends StatelessWidget {
  const ShellGlassHeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return const GlassHeaderBar.brand(actions: [HeaderSettingsButton()]);
  }
}
