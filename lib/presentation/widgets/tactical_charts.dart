import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/constants/app_constants.dart';

// ============================================================================
// MILITARY TACTICAL VISUAL COMPONENTS
// ============================================================================

// 🎯 MILITARY RADIAL GAUGE - TACTICAL STYLE
class TacticalRadialGauge extends StatelessWidget {
  final double value;
  final double max;
  final double size;
  final String? label;
  final Color color;
  final bool showGlow;
  final bool critical;

  const TacticalRadialGauge({
    super.key,
    required this.value,
    required this.max,
    this.size = 90,
    this.label,
    required this.color,
    this.showGlow = false,
    this.critical = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background tactical rings
          CustomPaint(
            size: Size(size, size),
            painter: TacticalGaugeBackgroundPainter(),
          ),
          // Progress arc
          CustomPaint(
            size: Size(size, size),
            painter: TacticalGaugePainter(
              value: value,
              max: max,
              color: color,
              showGlow: showGlow || critical,
              critical: critical,
            ),
          ),
          // Center display
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${(value / max * 100).round()}',
                style: TextStyle(
                  color: critical ? AppConstants.neonPink : Colors.white,
                  fontSize: 14,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  shadows: critical
                      ? [
                          Shadow(
                            color: AppConstants.neonPink,
                            blurRadius: 8,
                            offset: const Offset(0, 0),
                          )
                        ]
                      : null,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontFamily: 'Rajdhani',
                ),
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 6,
                      fontFamily: 'Rajdhani',
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TacticalGaugeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer tactical ring
    final outerPaint = Paint()
      ..color = AppConstants.neonCyan.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius - 1, outerPaint);

    // Inner grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Vertical lines
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 10),
      Offset(center.dx, center.dy + radius - 10),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius + 10, center.dy),
      Offset(center.dx + radius - 10, center.dy),
      gridPaint,
    );

    // Diagonal cross
    canvas.drawLine(
      Offset(center.dx - radius + 15, center.dy - radius + 15),
      Offset(center.dx + radius - 15, center.dy + radius - 15),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx + radius - 15, center.dy - radius + 15),
      Offset(center.dx - radius + 15, center.dy + radius - 15),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(TacticalGaugeBackgroundPainter oldDelegate) => false;
}

class TacticalGaugePainter extends CustomPainter {
  final double value;
  final double max;
  final Color color;
  final bool showGlow;
  final bool critical;

  TacticalGaugePainter({
    required this.value,
    required this.max,
    required this.color,
    required this.showGlow,
    required this.critical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc (inactive)
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    if (showGlow) {
      progressPaint.maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
    }

    final sweepAngle = (value / max) * math.pi * 2;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, progressPaint);

    // Critical glow effect
    if (critical) {
      final glowPaint = Paint()
        ..color = AppConstants.neonPink.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);
    }

    // Tactical markers
    final markerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final startRadius = radius - 12;
      final endRadius = radius - 2;

      final startPoint = center +
          Offset(
            math.cos(angle) * startRadius,
            math.sin(angle) * startRadius,
          );
      final endPoint = center +
          Offset(
            math.cos(angle) * endRadius,
            math.sin(angle) * endRadius,
          );

      canvas.drawLine(startPoint, endPoint, markerPaint);
    }
  }

  @override
  bool shouldRepaint(TacticalGaugePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.showGlow != showGlow ||
        oldDelegate.critical != critical;
  }
}

// 📊 MILITARY SPARKLINE - TACTICAL TRENDS
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
    this.width = 120,
    this.height = 40,
    this.showFill = true,
    this.showGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CustomPaint(
          painter: TacticalSparklinePainter(
            data: data,
            lineColor: lineColor,
            showFill: showFill,
            showGrid: showGrid,
          ),
        ),
      ),
    );
  }
}

class TacticalSparklinePainter extends CustomPainter {
  final List<double> data;
  final Color lineColor;
  final bool showFill;
  final bool showGrid;

  TacticalSparklinePainter({
    required this.data,
    required this.lineColor,
    required this.showFill,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Draw grid
    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      // Horizontal lines
      for (int i = 1; i < 4; i++) {
        final y = size.height * i / 4;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // Vertical lines
      for (int i = 1; i < data.length; i++) {
        final x = size.width * i / (data.length - 1);
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    final path = Path();
    final fillPath = Path();

    // Normalize data
    final minValue = data.reduce(math.min);
    final maxValue = data.reduce(math.max);
    final range = maxValue - minValue;
    final scaleY = size.height * 0.8 / (range == 0 ? 1 : range);
    final scaleX = size.width / (data.length - 1);
    final offsetY = size.height * 0.1;

    // Draw line
    for (int i = 0; i < data.length; i++) {
      final x = i * scaleX;
      final y = size.height - offsetY - ((data[i] - minValue) * scaleY);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Fill area
    if (showFill) {
      fillPath.lineTo(size.width, size.height);
      fillPath.lineTo(0, size.height);
      fillPath.close();

      final fillPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            lineColor.withValues(alpha: 0.3),
            lineColor.withValues(alpha: 0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.7, 1.0],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

      canvas.drawPath(fillPath, fillPaint);
    }

    // Draw line
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, linePaint);

    // Draw data points
    final pointPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;

    for (int i = 0; i < data.length; i++) {
      final x = i * scaleX;
      final y = size.height - offsetY - ((data[i] - minValue) * scaleY);

      canvas.drawCircle(Offset(x, y), 1.5, pointPaint);
    }
  }

  @override
  bool shouldRepaint(TacticalSparklinePainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

// 🎯 STATUS INDICATOR WITH PULSE
class TacticalStatusIndicator extends StatefulWidget {
  final String status;
  final Color color;
  final double size;
  final bool pulse;

  const TacticalStatusIndicator({
    super.key,
    required this.status,
    required this.color,
    this.size = 12,
    this.pulse = false,
  });

  @override
  State<TacticalStatusIndicator> createState() =>
      _TacticalStatusIndicatorState();
}

class _TacticalStatusIndicatorState extends State<TacticalStatusIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<Color?> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200), // Faster pulsing
      vsync: this,
    );

    // More dramatic scale animation (1.0 to 2.0 instead of 1.0 to 1.5)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Add opacity blinking effect
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.3).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Add color intensity pulsing
    _glowAnimation = ColorTween(
      begin: widget.color,
      end: widget.color.withValues(alpha: 0.3),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TacticalStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) {
      if (widget.pulse) {
        _controller.repeat(reverse: true);
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller]),
      builder: (context, child) {
        return Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.color,
            boxShadow: widget.pulse
                ? [
                    BoxShadow(
                      color: _glowAnimation.value!.withValues(alpha: 0.8),
                      blurRadius: _scaleAnimation.value * 12,
                      spreadRadius: _scaleAnimation.value * 3,
                    ),
                    BoxShadow(
                      color: _glowAnimation.value!.withValues(alpha: 0.6),
                      blurRadius: _scaleAnimation.value * 8,
                      spreadRadius: _scaleAnimation.value * 2,
                    ),
                  ]
                : null,
          ),
          child: widget.pulse
              ? Opacity(
                  opacity: _opacityAnimation.value,
                  child: Container(
                    margin: EdgeInsets.all(widget.size * 0.15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.9),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withValues(alpha: 0.5),
                          blurRadius: 4,
                        ),
                      ],
                    ),
                  ),
                )
              : Container(
                  margin: EdgeInsets.all(widget.size * 0.2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
        );
      },
    );
  }
}

// 📡 SIGNAL WAVEFORM - SPECTRUM ANALYZER STYLE
class TacticalWaveform extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double width;
  final double height;
  final bool showGrid;

  const TacticalWaveform({
    super.key,
    required this.data,
    required this.color,
    this.width = 100,
    this.height = 40,
    this.showGrid = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2),
        child: CustomPaint(
          painter: TacticalWaveformPainter(
            data: data,
            color: color,
            showGrid: showGrid,
          ),
        ),
      ),
    );
  }
}

class TacticalWaveformPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool showGrid;

  TacticalWaveformPainter({
    required this.data,
    required this.color,
    required this.showGrid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    // Draw grid
    if (showGrid) {
      final gridPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5;

      // Horizontal center line
      canvas.drawLine(
        Offset(0, size.height / 2),
        Offset(size.width, size.height / 2),
        gridPaint,
      );

      // Vertical divisions
      for (int i = 1; i < 4; i++) {
        final x = size.width * i / 4;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    final path = Path();
    final scaleX = size.width / (data.length - 1);
    final centerY = size.height / 2;

    for (int i = 0; i < data.length; i++) {
      final x = i * scaleX;
      final y = centerY - (data[i] * centerY * 0.8);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final wavePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, wavePaint);

    // Add glow effect
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);

    canvas.drawPath(path, glowPaint);
  }

  @override
  bool shouldRepaint(TacticalWaveformPainter oldDelegate) {
    return oldDelegate.data != data;
  }
}

// 🔋 BATTERY STRIP CHART
class TacticalBatteryStrip extends StatelessWidget {
  final List<BatteryLevel> batteries;
  final double width;
  final double height;

  const TacticalBatteryStrip({
    super.key,
    required this.batteries,
    this.width = 120,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: CustomPaint(
        painter: TacticalBatteryStripPainter(batteries: batteries),
      ),
    );
  }
}

class BatteryLevel {
  final String id;
  final double level;
  final bool charging;

  const BatteryLevel({
    required this.id,
    required this.level,
    this.charging = false,
  });
}

class TacticalBatteryStripPainter extends CustomPainter {
  final List<BatteryLevel> batteries;

  TacticalBatteryStripPainter({required this.batteries});

  @override
  void paint(Canvas canvas, Size size) {
    if (batteries.isEmpty) return;

    final barWidth = size.width / batteries.length;
    final barHeight = size.height * 0.8;
    final startY = size.height * 0.1;

    for (int i = 0; i < batteries.length; i++) {
      final battery = batteries[i];
      final x = i * barWidth;
      final barRect = Rect.fromLTWH(x + 2, startY, barWidth - 4, barHeight);

      // Background
      final bgPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill;

      canvas.drawRect(barRect, bgPaint);

      // Battery level
      final levelHeight = barHeight * (battery.level / 100);
      final levelRect = Rect.fromLTWH(
        x + 2,
        startY + barHeight - levelHeight,
        barWidth - 4,
        levelHeight,
      );

      Color levelColor;
      if (battery.level < 20) {
        levelColor = AppConstants.neonPink;
      } else if (battery.level < 50) {
        levelColor = Colors.orange;
      } else {
        levelColor = AppConstants.neonCyan;
      }

      final levelPaint = Paint()
        ..color = levelColor
        ..style = PaintingStyle.fill;

      canvas.drawRect(levelRect, levelPaint);

      // Charging indicator
      if (battery.charging) {
        final chargePaint = Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1;

        final centerX = x + barWidth / 2;
        final centerY = startY + barHeight / 2;

        // Lightning bolt
        final boltPath = Path();
        boltPath.moveTo(centerX, centerY - 8);
        boltPath.lineTo(centerX - 3, centerY - 2);
        boltPath.lineTo(centerX + 1, centerY - 2);
        boltPath.lineTo(centerX - 2, centerY + 6);
        boltPath.lineTo(centerX + 4, centerY - 4);
        boltPath.lineTo(centerX + 1, centerY - 4);
        boltPath.close();

        canvas.drawPath(boltPath, chargePaint);
      }

      // Level text
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${battery.level.round()}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 6,
            fontFamily: 'Orbitron',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
            x + barWidth / 2 - textPainter.width / 2, startY + barHeight + 2),
      );
    }
  }

  @override
  bool shouldRepaint(TacticalBatteryStripPainter oldDelegate) {
    return oldDelegate.batteries != batteries;
  }
}

// ============================================================================
// INVERTED RISK GAUGE (for AlertasCard - higher = worse)
// ============================================================================

class TacticalRiskGauge extends StatelessWidget {
  final double riskLevel; // 0-100, higher = worse
  final double size;
  final String? label;
  final bool critical;

  const TacticalRiskGauge({
    super.key,
    required this.riskLevel,
    this.size = 90,
    this.label,
    this.critical = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background tactical rings
          CustomPaint(
            size: Size(size, size),
            painter: TacticalRiskGaugeBackgroundPainter(),
          ),
          // Progress arc (inverted - higher = worse)
          CustomPaint(
            size: Size(size, size),
            painter: TacticalRiskGaugePainter(
              riskLevel: riskLevel,
              critical: critical,
            ),
          ),
          // Center display
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${riskLevel.round()}',
                style: TextStyle(
                  color: critical
                      ? AppConstants.neonPink
                      : _getRiskColor(riskLevel),
                  fontSize: 14,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                  shadows: critical
                      ? [
                          Shadow(
                            color: AppConstants.neonPink,
                            blurRadius: 8,
                            offset: const Offset(0, 0),
                          )
                        ]
                      : null,
                ),
              ),
              Text(
                '%',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 8,
                  fontFamily: 'Rajdhani',
                ),
              ),
              if (label != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    label!.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white30,
                      fontSize: 6,
                      fontFamily: 'Rajdhani',
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(double risk) {
    if (risk >= 70) return AppConstants.warningRed;
    if (risk >= 30) return AppConstants.alertOrange;
    return AppConstants.successGreen;
  }
}

class TacticalRiskGaugeBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer risk ring
    final outerPaint = Paint()
      ..color = AppConstants.neonPink.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius - 1, outerPaint);

    // Risk zones (green->yellow->red)
    final zonePaints = [
      Paint()
        ..color = AppConstants.successGreen.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = AppConstants.alertOrange.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = AppConstants.warningRed.withValues(alpha: 0.1)
        ..style = PaintingStyle.fill,
    ];

    final zoneAngles = [
      math.pi * 2 * 0.3,
      math.pi * 2 * 0.4,
      math.pi * 2 * 0.3
    ];
    double startAngle = -math.pi / 2;

    for (int i = 0; i < zonePaints.length; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - 5),
        startAngle,
        zoneAngles[i],
        true,
        zonePaints[i],
      );
      startAngle += zoneAngles[i];
    }

    // Inner grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Vertical lines
    canvas.drawLine(
      Offset(center.dx, center.dy - radius + 10),
      Offset(center.dx, center.dy + radius - 10),
      gridPaint,
    );
    canvas.drawLine(
      Offset(center.dx - radius + 10, center.dy),
      Offset(center.dx + radius - 10, center.dy),
      gridPaint,
    );
  }

  @override
  bool shouldRepaint(TacticalRiskGaugeBackgroundPainter oldDelegate) => false;
}

class TacticalRiskGaugePainter extends CustomPainter {
  final double riskLevel;
  final bool critical;

  TacticalRiskGaugePainter({
    required this.riskLevel,
    required this.critical,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    // Background arc (safe zone)
    final backgroundPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, backgroundPaint);

    // Risk arc (higher = worse, so we fill from the bottom)
    final riskPaint = Paint()
      ..color = _getRiskColor(riskLevel)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    if (critical || riskLevel > 70) {
      riskPaint.maskFilter = const MaskFilter.blur(BlurStyle.outer, 4);
    }

    final sweepAngle = (riskLevel / 100) * math.pi * 2;
    canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, riskPaint);

    // Critical glow effect
    if (critical) {
      final glowPaint = Paint()
        ..color = AppConstants.neonPink.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);

      canvas.drawArc(rect, -math.pi / 2, sweepAngle, false, glowPaint);
    }

    // Risk markers
    final markerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 8; i++) {
      final angle = (i * math.pi / 4) - math.pi / 2;
      final startRadius = radius - 12;
      final endRadius = radius - 2;

      final startPoint = center +
          Offset(
            math.cos(angle) * startRadius,
            math.sin(angle) * startRadius,
          );
      final endPoint = center +
          Offset(
            math.cos(angle) * endRadius,
            math.sin(angle) * endRadius,
          );

      canvas.drawLine(startPoint, endPoint, markerPaint);
    }
  }

  Color _getRiskColor(double risk) {
    if (risk >= 70) return AppConstants.warningRed;
    if (risk >= 30) return AppConstants.alertOrange;
    return AppConstants.successGreen;
  }

  @override
  bool shouldRepaint(TacticalRiskGaugePainter oldDelegate) {
    return oldDelegate.riskLevel != riskLevel ||
        oldDelegate.critical != critical;
  }
}

// ============================================================================
// WATERFALL CHART (for AlertasCard - contribution of problems)
// ============================================================================

class TacticalWaterfallChart extends StatelessWidget {
  final List<WaterfallSegment> segments;
  final double width;
  final double height;

  const TacticalWaterfallChart({
    super.key,
    required this.segments,
    this.width = 120,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: CustomPaint(
        painter: TacticalWaterfallPainter(segments: segments),
      ),
    );
  }
}

class WaterfallSegment {
  final String label;
  final double value;
  final Color color;

  const WaterfallSegment({
    required this.label,
    required this.value,
    required this.color,
  });
}

class TacticalWaterfallPainter extends CustomPainter {
  final List<WaterfallSegment> segments;

  TacticalWaterfallPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    if (segments.isEmpty) return;

    final barWidth = size.width / segments.length;
    final maxValue = segments.map((s) => s.value.abs()).reduce(math.max);
    final scaleY = (size.height * 0.8) / maxValue;

    double currentX = 0;
    double runningTotal = 0;

    for (final segment in segments) {
      final barHeight = segment.value * scaleY;
      final barRect = Rect.fromLTWH(
        currentX + 1,
        size.height - size.height * 0.1 - barHeight - runningTotal * scaleY,
        barWidth - 2,
        barHeight.abs(),
      );

      // Bar
      final barPaint = Paint()
        ..color = segment.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawRect(barRect, barPaint);

      // Glow
      final glowPaint = Paint()
        ..color = segment.color.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 2);

      canvas.drawRect(barRect, glowPaint);

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: segment.label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 5,
            fontFamily: 'Rajdhani',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
            currentX + barWidth / 2 - textPainter.width / 2, size.height - 10),
      );

      currentX += barWidth;
      runningTotal += segment.value;
    }

    // Total line
    final totalPaint = Paint()
      ..color = AppConstants.neonPink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final totalY = size.height - size.height * 0.1 - runningTotal * scaleY;
    canvas.drawLine(
      Offset(0, totalY),
      Offset(size.width, totalY),
      totalPaint,
    );

    // Total label
    final totalTextPainter = TextPainter(
      text: TextSpan(
        text: 'TOTAL: ${runningTotal.round()}',
        style: const TextStyle(
          color: AppConstants.neonPink,
          fontSize: 6,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    totalTextPainter.layout();
    totalTextPainter.paint(
      canvas,
      Offset(size.width / 2 - totalTextPainter.width / 2, totalY - 15),
    );
  }

  @override
  bool shouldRepaint(TacticalWaterfallPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

// ============================================================================
// SPECTRUM ANALYZER WIDGET
// ============================================================================

class TacticalSpectrumAnalyzer extends StatelessWidget {
  final Map<String, double> bands;
  final double width;
  final double height;

  const TacticalSpectrumAnalyzer({
    super.key,
    required this.bands,
    this.width = 150,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 0.5,
        ),
        borderRadius: BorderRadius.circular(2),
      ),
      child: CustomPaint(
        painter: TacticalSpectrumPainter(bands: bands),
      ),
    );
  }
}

class TacticalSpectrumPainter extends CustomPainter {
  final Map<String, double> bands;

  TacticalSpectrumPainter({required this.bands});

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final bandWidth = size.width / bands.length;
    final maxHeight = size.height * 0.8;

    int index = 0;
    for (final entry in bands.entries) {
      final x = index * bandWidth;
      final barHeight = maxHeight * entry.value;
      final barRect = Rect.fromLTWH(
        x + 2,
        size.height - barHeight - 5,
        bandWidth - 4,
        barHeight,
      );

      // Bar
      final barPaint = Paint()
        ..color = AppConstants.neonCyan.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      canvas.drawRect(barRect, barPaint);

      // Glow
      final glowPaint = Paint()
        ..color = AppConstants.neonCyan.withValues(alpha: 0.4)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3);

      canvas.drawRect(barRect, glowPaint);

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: entry.key,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 6,
            fontFamily: 'Rajdhani',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + bandWidth / 2 - textPainter.width / 2, size.height - 12),
      );

      index++;
    }

    // Frequency labels
    const freqLabels = ['GPS', '4G', '5G', 'WIFI'];
    for (int i = 0; i < freqLabels.length && i < bands.length; i++) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: freqLabels[i],
          style: const TextStyle(
            color: Colors.white30,
            fontSize: 5,
            fontFamily: 'Rajdhani',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final x = i * bandWidth + bandWidth / 2 - textPainter.width / 2;
      textPainter.paint(canvas, Offset(x, 2));
    }
  }

  @override
  bool shouldRepaint(TacticalSpectrumPainter oldDelegate) {
    return oldDelegate.bands != bands;
  }
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

class MiniDonutPainter extends CustomPainter {
  final List<DonutSegment> segments;

  MiniDonutPainter({required this.segments});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.6; // Donut hole
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;
    final total = segments.fold(0.0, (sum, segment) => sum + segment.value);

    for (final segment in segments) {
      final sweepAngle = (segment.value / total) * math.pi * 2;

      final paint = Paint()
        ..color = segment.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(rect, startAngle, sweepAngle, true, paint);
      startAngle += sweepAngle;
    }

    // Draw inner circle for donut effect
    final innerPaint = Paint()
      ..color = AppConstants.darkBg
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, innerRadius, innerPaint);
  }

  @override
  bool shouldRepaint(MiniDonutPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}
