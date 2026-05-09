import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/monitoreo_reporte_model.dart';
import '../../core/constants/app_constants.dart';

class TacticalMarker extends StatelessWidget {
  final MonitoreoReporte reporte;
  final VoidCallback onTap;

  const TacticalMarker({
    super.key,
    required this.reporte,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.grupoColors[reporte.grupo ?? 'ALFA'] ??
        AppConstants.neonCyan;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ONDAS CONCÉNTRICAS PULSANTES
          CustomPaint(
            size: const Size(60, 60),
            painter: RadarPulse(color: color),
          )
              .animate(
                onPlay: (controller) => controller.repeat(),
              )
              .custom(
                duration: AppConstants.pulseDuration,
                builder: (context, value, child) => CustomPaint(
                  size: const Size(60, 60),
                  painter: RadarPulse(
                    color: color,
                    progress: value,
                  ),
                ),
              ),

          // NÚCLEO DEL MARCADOR
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.8),
                  blurRadius: 12,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: Center(
              child: Text(
                reporte.grupo == 'ALFA' ? '⍺' : 'β',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // NOMBRE OFICIAL DEBAJO
          Positioned(
            bottom: -16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(4),
                border:
                    Border.all(color: color.withValues(alpha: 0.5), width: 1),
              ),
              child: Text(
                reporte.nombreOficial?.split(' ').last ?? '',
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RadarPulse extends CustomPainter {
  final Color color;
  final double progress;

  RadarPulse({
    required this.color,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;

    // Dibujar 3 ondas concéntricas
    for (int i = 0; i < 3; i++) {
      final delay = i * 0.3;
      final adjustedProgress = (progress - delay).clamp(0.0, 1.0);

      if (adjustedProgress > 0) {
        final radius = maxRadius * adjustedProgress;
        final opacity = (1.0 - adjustedProgress) * 0.6;

        final paint = Paint()
          ..color = color.withValues(alpha: opacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;

        canvas.drawCircle(center, radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(RadarPulse oldDelegate) =>
      oldDelegate.progress != progress;
}
