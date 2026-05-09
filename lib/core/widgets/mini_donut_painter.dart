import 'package:flutter/material.dart';

class MiniDonutPainter extends CustomPainter {
  final List<DonutSegment> segments;

  const MiniDonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    double startAngle = -3.14159 / 2; // Start from top

    for (final segment in segments) {
      final sweepAngle = (segment.value / 100) * 2 * 3.14159;

      // Draw outer arc
      final outerPaint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius - 4),
        startAngle,
        sweepAngle,
        false,
        outerPaint,
      );

      // Draw inner arc for glow effect
      final glowPaint = Paint()
        ..color = segment.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius - 4),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DonutSegment {
  final double value;
  final Color color;
  final String label;

  const DonutSegment({
    required this.value,
    required this.color,
    required this.label,
  });
}
