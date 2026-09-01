import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';

/// Soft accent dots orbiting the splash logo.
class SplashOrbitalRing extends StatelessWidget {
  const SplashOrbitalRing({
    required this.rotation,
    required this.child,
    super.key,
  });

  final double rotation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final dotColor = AppColors.accent.withValues(
      alpha: brightness == Brightness.dark ? 0.75 : 0.55,
    );

    return SizedBox(
      width: 168,
      height: 168,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: rotation * math.pi * 2,
            child: CustomPaint(
              size: const Size(168, 168),
              painter: _OrbitDotPainter(color: dotColor),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _OrbitDotPainter extends CustomPainter {
  _OrbitDotPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    final paint = Paint()..color = color;

    for (var i = 0; i < 3; i++) {
      final angle = (i / 3) * math.pi * 2;
      final point = center + Offset(math.cos(angle), math.sin(angle)) * radius;
      canvas.drawCircle(point, i == 0 ? 5 : 3.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitDotPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
