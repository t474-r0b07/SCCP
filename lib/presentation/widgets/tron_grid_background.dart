import 'package:flutter/material.dart';
import 'dart:math' as math;

class TronGrid extends StatefulWidget {
  const TronGrid({super.key});

  @override
  State<TronGrid> createState() => _TronGridState();
}

class _TronGridState extends State<TronGrid>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Animación continua para el flujo de la rejilla
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2), // Velocidad de crucero táctica
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: TronGridPainter(
            animationValue: _controller.value,
          ),
          child: Container(),
        );
      },
    );
  }
}

class TronGridPainter extends CustomPainter {
  final double animationValue;

  TronGridPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final centerX = size.width / 2;
    final vanishingY = size.height * 0.45; // Punto de fuga (Horizonte)
    const int verticalLines = 40; // Densidad de líneas
    const double baseSpacing = 60.0;

    // --- 1. LÍNEAS VERTICALES (Perspectiva al infinito) ---
    for (int i = -verticalLines ~/ 2; i <= verticalLines ~/ 2; i++) {
      // Opacidad basada en la distancia al centro para efecto túnel
      final double opacity =
          (1.0 - (i.abs() / (verticalLines / 2))).clamp(0.0, 0.4);
      paint.color = const Color(0xFF00F3FF).withValues(alpha: opacity);

      // Las líneas nacen en el punto de fuga y se expanden hacia abajo
      canvas.drawLine(
        Offset(centerX + (i * 4), vanishingY), // Inicio en horizonte
        Offset(centerX + (i * baseSpacing * 4), size.height), // Fin en base
        paint,
      );
    }

    // --- 2. LÍNEAS HORIZONTALES (Movimiento logarítmico) ---
    // Usamos una función exponencial para que las líneas se separen al acercarse
    for (int i = 0; i < 25; i++) {
      // Sumamos la animación para el movimiento
      double currentI = i + animationValue;

      // Función de profundidad: la posición Y crece exponencialmente
      double yPos = vanishingY + math.pow(currentI, 2.2) * 0.5;

      if (yPos > size.height) continue;

      // Opacidad: las líneas cerca del horizonte son casi invisibles
      final double fadeOpacity =
          ((yPos - vanishingY) / (size.height - vanishingY)).clamp(0.0, 0.3);
      paint.color = const Color(0xFF00F3FF).withValues(alpha: fadeOpacity);

      canvas.drawLine(
        Offset(0, yPos),
        Offset(size.width, yPos),
        paint,
      );
    }

    // --- 3. BRILLO DEL HORIZONTE (Efecto Tron) ---
    final glowPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00F3FF).withValues(alpha: 0.2),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, vanishingY, size.width, 50));

    canvas.drawRect(Rect.fromLTWH(0, vanishingY, size.width, 50), glowPaint);
  }

  @override
  bool shouldRepaint(TronGridPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue;
}
