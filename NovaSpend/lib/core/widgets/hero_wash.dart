import 'package:flutter/material.dart';

import '../theme/app_gradients.dart';

/// Top-of-page emerald wash. Place behind scroll content on Home / Insights.
///
/// Ignore-pointer; not a card. Fades into the scaffold surface.
class HeroWash extends StatelessWidget {
  const HeroWash({this.height = AppGradients.heroWashHeight, super.key});

  final double height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppGradients.heroWash(brightness),
          ),
        ),
      ),
    );
  }
}
