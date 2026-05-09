import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/constants/app_constants.dart';

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        color: Colors.transparent,
        child: CustomPaint(
          size: Size.infinite,
          painter: ScannerLinePainter(),
        )
            .animate(
              onPlay: (controller) => controller.repeat(),
            )
            .custom(
              duration: AppConstants.scannerDuration,
              builder: (context, value, child) => CustomPaint(
                size: Size.infinite,
                painter: ScannerLinePainter(progress: value),
              ),
            ),
      ),
    );
  }
}

class ScannerLinePainter extends CustomPainter {
  final double progress;

  ScannerLinePainter({this.progress = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;

    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          AppConstants.neonCyan.withValues(alpha: 0.0),
          AppConstants.neonCyan.withValues(alpha: 0.3),
          AppConstants.neonCyan.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 2, size.width, 4))
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(0, y - 2, size.width, 4),
      paint,
    );
  }

  @override
  bool shouldRepaint(ScannerLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
