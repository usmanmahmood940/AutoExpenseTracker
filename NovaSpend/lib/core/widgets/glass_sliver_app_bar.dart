import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Pinned, translucent app bar for use inside a [CustomScrollView].
///
/// Renders the "10% glass" overlay from the design system: a blurred, 80%-opacity
/// surface with a hairline bottom border, so content scrolls underneath while
/// the header stays legible. Reusable on any sliver-based screen.
class GlassSliverAppBar extends StatelessWidget {
  const GlassSliverAppBar({
    required this.title,
    this.actions,
    this.height = 64,
    super.key,
  });

  final Widget title;
  final List<Widget>? actions;
  final double height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return SliverAppBar(
      pinned: true,
      floating: false,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: height,
      titleSpacing: 16,
      title: title,
      actions: actions,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.glassFill(brightness),
              border: Border(
                bottom: BorderSide(color: AppColors.glassBorder(brightness)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
