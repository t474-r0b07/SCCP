import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class TacticalRadialGauge extends StatelessWidget {
  final double value;
  final double max;
  final double size;
  final String label;
  final Color color;
  final bool showGlow;
  final bool critical;

  const TacticalRadialGauge({
    super.key,
    required this.value,
    required this.max,
    required this.size,
    required this.label,
    required this.color,
    this.showGlow = false,
    this.critical = false,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = (value / max).clamp(0.0, 1.0);

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _TacticalRadialGaugePainter(
          percentage: percentage,
          color: color,
          showGlow: showGlow,
          critical: critical,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(percentage * 100).round()}%',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.15,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  shadows: showGlow
                      ? [
                          Shadow(
                            color: color.withValues(alpha: 0.8),
                            blurRadius: 8,
                          ),
                        ]
                      : null,
                ),
              ),
              SizedBox(height: size * 0.02),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: size * 0.08,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TacticalRadialGaugePainter extends CustomPainter {
  final double percentage;
  final Color color;
  final bool showGlow;
  final bool critical;

  _TacticalRadialGaugePainter({
    required this.percentage,
    required this.color,
    required this.showGlow,
    required this.critical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;

    // Background circle
    final bgPaint = Paint()
      ..color = AppConstants.darkBg.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = critical ? AppConstants.warningRed : color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    if (showGlow) {
      progressPaint
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3)
        ..color = color.withValues(alpha: 0.8);
    }

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -3.14159 / 2, // Start from top
      percentage * 2 * 3.14159, // Full circle
      false,
      progressPaint,
    );

    // Glow effect for critical state
    if (critical) {
      final glowPaint = Paint()
        ..color = AppConstants.warningRed.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -3.14159 / 2,
        percentage * 2 * 3.14159,
        false,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
