import 'package:flutter/material.dart';
import 'package:nova_spend/core/theme/app_colors.dart';
import 'package:nova_spend/core/theme/app_motion.dart';
import 'package:nova_spend/core/theme/app_radius.dart';

/// Animated NovaSpend mark — rounded tile with a rising trend line.
class SplashLogoMark extends StatefulWidget {
  const SplashLogoMark({
    required this.pulse,
    required this.lineProgress,
    super.key,
  });

  final bool pulse;
  final double lineProgress;

  @override
  State<SplashLogoMark> createState() => _SplashLogoMarkState();
}

class _SplashLogoMarkState extends State<SplashLogoMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseScale;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
    _pulseScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 55),
    ]).animate(
      CurvedAnimation(parent: _pulseController, curve: AppMotion.standard),
    );
  }

  @override
  void didUpdateWidget(SplashLogoMark oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse && !oldWidget.pulse) {
      _pulseController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return ScaleTransition(
      scale: _pulseScale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    AppColors.primaryStrong.withValues(alpha: 0.35),
                    AppColors.accent.withValues(alpha: 0.2),
                  ]
                : [
                    AppColors.navActiveFillLight,
                    AppColors.accent.withValues(alpha: 0.12),
                  ],
          ),
          border: Border.all(
            color: AppColors.border(brightness).withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: isDark ? 0.18 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: SizedBox(
          width: 96,
          height: 96,
          child: CustomPaint(
            painter: _TrendLinePainter(
              progress: widget.lineProgress,
              color: isDark ? AppColors.navActiveForegroundDark : AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}

class _TrendLinePainter extends CustomPainter {
  _TrendLinePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _points = [
    Offset(22, 62),
    Offset(38, 48),
    Offset(52, 54),
    Offset(74, 30),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()..moveTo(_points.first.dx, _points.first.dy);
    for (var i = 1; i < _points.length; i++) {
      path.lineTo(_points[i].dx, _points[i].dy);
    }

    final metrics = path.computeMetrics().first;
    final drawLength = metrics.length * progress.clamp(0, 1);
    final partial = metrics.extractPath(0, drawLength);
    canvas.drawPath(partial, linePaint);

    for (final point in _points) {
      final dist = _distanceAlongPath(point);
      if (dist <= drawLength + 0.5) {
        canvas.drawCircle(point, 3.2, dotPaint);
      }
    }
  }

  double _distanceAlongPath(Offset target) {
    var total = 0.0;
    for (var i = 1; i < _points.length; i++) {
      final start = _points[i - 1];
      final end = _points[i];
      final segment = end - start;
      final len = segment.distance;
      final t = _projectOnSegment(target, start, end);
      if (t >= 0 && t <= 1) {
        return total + len * t;
      }
      total += len;
    }
    return total;
  }

  double _projectOnSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return 0;
    return ((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2;
  }

  @override
  bool shouldRepaint(covariant _TrendLinePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
