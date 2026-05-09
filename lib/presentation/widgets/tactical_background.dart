import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/constants/app_constants.dart';

class TacticalBackground extends StatefulWidget {
  final Widget child;

  const TacticalBackground({super.key, required this.child});

  @override
  State<TacticalBackground> createState() => _TacticalBackgroundState();
}

class _TacticalBackgroundState extends State<TacticalBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Controlador para el movimiento infinito de la rejilla
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3), // Velocidad táctica
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 1. Fondo base degradado (Respetando su AppConstants)
        Container(
          decoration: const BoxDecoration(
            gradient: AppConstants.gridGradient,
          ),
        ),

        // 2. Rejilla Táctica Animada en Perspectiva
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: TacticalGridPainter(animationValue: _controller.value),
              size: Size.infinite,
            );
          },
        ),

        // 3. Efecto de Scanlines (Líneas de escaneo estéticas)
        CustomPaint(
          painter: ScanlinePainter(),
          size: Size.infinite,
        ),

        // 4. Contenido de la Aplicación
        widget.child,
      ],
    );
  }
}

class TacticalGridPainter extends CustomPainter {
  final double animationValue;

  TacticalGridPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final vanishingY = size.height * 0.42; // Punto de fuga táctico
    const spacing = 80.0;
    const verticalLines = 36;

    // --- LÍNEAS VERTICALES (Perspectiva) ---
    for (int i = -verticalLines ~/ 2; i <= verticalLines ~/ 2; i++) {
      final double opacity =
          (1.0 - (i.abs() / (verticalLines / 2))).clamp(0.0, 0.4);
      paint.color = AppConstants.gridColor.withValues(alpha: opacity);

      canvas.drawLine(
        Offset(centerX + (i * 2), vanishingY),
        Offset(centerX + (i * spacing * 4), size.height),
        paint,
      );
    }

    // --- LÍNEAS HORIZONTALES (Movimiento Logarítmico hacia el Infinito) ---
    for (int i = 0; i < 20; i++) {
      double currentI = i + animationValue;

      // Cálculo de profundidad para ilusión de velocidad y distancia
      double yPos = vanishingY + math.pow(currentI, 2.5) * 0.35;

      if (yPos > size.height) continue;

      // Desvanecimiento cerca del horizonte
      final double fadeOpacity =
          ((yPos - vanishingY) / (size.height - vanishingY)).clamp(0.0, 0.3);
      paint.color = AppConstants.gridColor.withValues(alpha: fadeOpacity);

      canvas.drawLine(
        Offset(0, yPos),
        Offset(size.width, yPos),
        paint,
      );
    }

    // Brillo en el horizonte
    final horizonPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppConstants.gridColor.withValues(alpha: 0.15),
          Colors.transparent
        ],
      ).createShader(Rect.fromLTWH(0, vanishingY, size.width, 40));

    canvas.drawRect(Rect.fromLTWH(0, vanishingY, size.width, 40), horizonPaint);
  }

  @override
  bool shouldRepaint(TacticalGridPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}

class ScanlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1.0;

    for (double i = 0; i < size.height; i += 4) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(ScanlinePainter oldDelegate) => false;
}
