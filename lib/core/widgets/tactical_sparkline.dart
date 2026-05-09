import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class TacticalSparkline extends StatelessWidget {
  final List<double> data;
  final Color lineColor;
  final double width;
  final double height;
  final bool showFill;
  final bool showGrid;

  const TacticalSparkline({
    super.key,
    required this.data,
    required this.lineColor,
    required this.width,
    required this.height,
    this.showFill = false,
    this.showGrid = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        painter: _TacticalSparklinePainter(
          data: data,
          lineColor: lineColor,
          showFill: showFill,
          showGrid: showGrid,
        ),
      ),
    );
  }
}

class _TacticalSparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final bool showFill;
  final bool showGrid;

  _TacticalSparklinePainter({
    required this.data,
    required this.lineColor,
    required this.showFill,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    // Draw grid if enabled
    if (showGrid) {
      final gridPaint = Paint()
        ..color = AppConstants.gridColor.withValues(alpha: 0.2)
        ..strokeWidth = 0.5;

      // Vertical lines
      for (int i = 0; i <= 4; i++) {
        final x = (i / 4) * size.width;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }

      // Horizontal lines
      for (int i = 0; i <= 3; i++) {
        final y = (i / 3) * size.height;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    // Calculate data bounds
    final maxValue = data.reduce((a, b) => a > b ? a : b);
    final minValue = data.reduce((a, b) => a < b ? a : b);
    final range = maxValue - minValue;

    if (range == 0) return;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = (i / (data.length - 1)) * size.width;
      final normalizedValue = (data[i] - minValue) / range;
      final y = size.height - (normalizedValue * size.height);

      if (i == 0) {
        path.moveTo(x, y);
        if (showFill) {
          fillPath.moveTo(x, size.height);
          fillPath.lineTo(x, y);
        }
      } else {
        path.lineTo(x, y);
        if (showFill) {
          fillPath.lineTo(x, y);
        }
      }
    }

    // Draw fill if enabled
    if (showFill) {
      fillPath.lineTo(size.width, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..color = lineColor.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;
      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    canvas.drawPath(path, paint);

    // Add glow effect
    final glowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.3)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
