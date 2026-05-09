import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../presentation/controllers/dashboard_controller.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/grado_assets.dart';
import '../../../core/widgets/tactical_sparkline.dart';

// === DETALLADO PERFIL OFICIAL DIALOG ===

// Particle painter for floating light effects
class ParticlePainter extends CustomPainter {
  final double animation;
  final Color color;

  ParticlePainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    // Create floating particles
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * 3.14159 + animation * 2 * 3.14159;
      final radius = 80.0 + (i * 20.0);
      final x = size.width / 2 + radius * cos(angle);
      final y = size.height / 2 + radius * sin(angle);

      final particleSize = 2.0 + sin(animation * 4 + i) * 1.0;

      canvas.drawCircle(
        Offset(x, y),
        particleSize,
        paint
          ..color = color.withValues(
              alpha: (0.1 + sin(animation * 2 + i) * 0.1).clamp(0.0, 0.3)),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Hist2D painter for activity visualization
class SpectrumPainter extends CustomPainter {
  final double animation;
  final Color color;

  SpectrumPainter({required this.animation, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 26;
    const rows = 10;
    final cellW = size.width / cols;
    final cellH = size.height / rows;

    for (int y = 0; y < rows; y++) {
      for (int x = 0; x < cols; x++) {
        final seed =
            sin((x * 12.9898 + y * 78.233) + (animation * 12.0)) * 43758.5453;
        final noise = seed - seed.floorToDouble();
        final burst =
            sin((animation * 9.0) + (x * 0.7) - (y * 0.35)) * 0.5 + 0.5;
        final intensity = (noise * 0.55 + burst * 0.45).clamp(0.0, 1.0);
        if (intensity < 0.25) continue;

        final rect = Rect.fromLTWH(
          x * cellW + 1,
          y * cellH + 1,
          cellW - 2,
          cellH - 2,
        );
        final paint = Paint()
          ..color = color.withValues(
              alpha: (0.08 + intensity * 0.75).clamp(0.0, 0.85))
          ..style = PaintingStyle.fill;
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(1.8)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class DetalladoPerfilOficialDialog extends StatefulWidget {
  final dynamic oficial;
  final DashboardController controller;

  const DetalladoPerfilOficialDialog({
    super.key,
    required this.oficial,
    required this.controller,
  });

  @override
  State<DetalladoPerfilOficialDialog> createState() =>
      _DetalladoPerfilOficialDialogState();
}

class _DetalladoPerfilOficialDialogState
    extends State<DetalladoPerfilOficialDialog> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;
  late AnimationController _floatController;
  late AnimationController _particleController;
  late AnimationController _spectrumController;

  @override
  void initState() {
    super.initState();

    // Pulsing light animation for critical alerts
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    // Glowing border animation
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    )..repeat(reverse: true);

    // Floating particle animation
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat();

    // Particle system animation
    _particleController = AnimationController(
      duration: const Duration(milliseconds: 6000),
      vsync: this,
    )..repeat();

    // Spectrum animation
    _spectrumController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _glowController.dispose();
    _floatController.dispose();
    _particleController.dispose();
    _spectrumController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _calculatePerformanceRating(
      List reportes, List partes, int alertas, int inconsistencias) {
    int score = 0;

    int activityScore = 0;
    if (reportes.length >= 10) {
      activityScore = 40;
    } else if (reportes.length >= 5) {
      activityScore = 25;
    } else if (reportes.length >= 2) {
      activityScore = 10;
    }

    int alertPenalty = alertas * 10;
    if (alertPenalty > 30) {
      alertPenalty = 30;
    }

    int inconsistencyPenalty = inconsistencias * 5;
    if (inconsistencyPenalty > 20) {
      inconsistencyPenalty = 20;
    }

    int partesBonus = partes.length >= 3
        ? 10
        : partes.isNotEmpty
            ? 5
            : 0;

    score = activityScore + partesBonus - alertPenalty - inconsistencyPenalty;
    score = score.clamp(0, 100);

    String rating;
    Color color;

    if (score >= 80) {
      rating = 'EXCELENTE';
      color = Colors.greenAccent;
    } else if (score >= 60) {
      rating = 'BUENO';
      color = Colors.blueAccent;
    } else if (score >= 40) {
      rating = 'REGULAR';
      color = Colors.yellowAccent;
    } else if (score >= 20) {
      rating = 'DEFICIENTE';
      color = Colors.orangeAccent;
    } else {
      rating = 'CRÍTICO';
      color = Colors.redAccent;
    }

    return {
      'rating': rating,
      'color': color,
      'score': score,
    };
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day.toString().padLeft(2, '0')}/'
        '${dateTime.month.toString().padLeft(2, '0')}/'
        '${dateTime.year} '
        '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.oficial == null) {
      return const Dialog(
        backgroundColor: Colors.black87,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
              SizedBox(height: 16),
              Text(
                'Error: No se pudieron cargar los datos del oficial',
                style: TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Por favor, intenta nuevamente',
                style: TextStyle(color: Colors.white70, fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final reportesOficial = widget.controller.reportes
        .where((r) => r.idOficialRef == widget.oficial!.idOficial)
        .toList();

    final partesOficial = widget.controller.partes
        .where((p) => p.idOficial == widget.oficial!.idOficial)
        .toList();

    final alertasOficial = widget.controller.alertasOperativasDelTurno
        .where((a) =>
            (a['id_oficial_ref'] ?? a['id_oficial'] ?? '').toString() ==
            widget.oficial!.idOficial)
        .length;

    final inconsistenciasOficial = widget.controller.inconsistencias
        .where((inc) => inc['id_oficial'] == widget.oficial!.idOficial)
        .toList();

    final ultimoReporte = reportesOficial.isNotEmpty
        ? reportesOficial
            .reduce((a, b) => a.fechaHora.isAfter(b.fechaHora) ? a : b)
        : null;

    final complianceHistory =
        _calculateComplianceHistory(reportesOficial, partesOficial);
    final rendimiento = _calculatePerformanceRating(reportesOficial,
        partesOficial, alertasOficial, inconsistenciasOficial.length);

    final reportesHoy =
        reportesOficial.where((r) => _isToday(r.fechaHora)).length;
    final partesHoy = partesOficial.where((p) => _isToday(p.timestamp)).length;

    // Status card data
    final ultimoReporteValue = ultimoReporte != null
        ? _formatDateTime(ultimoReporte.fechaHora).split(' ')[0]
        : "SIN REPORTES";

    final ultimoReporteSubtitle = ultimoReporte?.estadoAlerta ?? "NORMAL";

    final ultimoReporteColor = ultimoReporte != null
        ? (ultimoReporte.estadoAlerta == 'CRITICO'
            ? Colors.redAccent
            : ultimoReporte.estadoAlerta == 'ALERTA'
                ? Colors.orangeAccent
                : Colors.greenAccent)
        : Colors.grey;

    final estadoActualValue = widget.oficial!.activo ? "OPERATIVO" : "INACTIVO";

    final estadoActualSubtitle =
        widget.oficial!.activo ? "EN SERVICIO" : "FUERA DE SERVICIO";

    final estadoActualColor =
        widget.oficial!.activo ? Colors.greenAccent : Colors.orangeAccent;

    final estadoActualIcon =
        widget.oficial!.activo ? Icons.check_circle : Icons.pause_circle;
    final reoNombre = _getReoDisplayName(widget.oficial!.reoAsignado);
    final controlPoint = _controlPointForReo(widget.oficial!.reoAsignado);
    final controlCoords =
        '${controlPoint.dx.toStringAsFixed(4)}, ${controlPoint.dy.toStringAsFixed(4)}';
    final equipoId = widget.oficial!.imei ?? ultimoReporte?.imei ?? 'N/D';
    final telefono = _getReoTelefono(widget.oficial!.reoAsignado);
    final jurisdiccion = (widget.oficial!.jurisdiccion ?? '').toString().trim();
    final jurisdiccionLabel = jurisdiccion.isEmpty ? 'N/D' : jurisdiccion;
    final idOficial = widget.oficial!.idOficial;
    final media = MediaQuery.of(context);
    final mobileDialog = kIsWeb
        ? media.size.width < 760
        : media.size.width < 760 || media.size.height < 760;
    final dialogWidth = mobileDialog ? media.size.width * 0.96 : 550.0;
    final dialogHeight = mobileDialog ? media.size.height * 0.92 : 650.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: dialogHeight,
          minWidth: mobileDialog ? 0 : 550,
          minHeight: mobileDialog ? 0 : 650,
        ),
        decoration: BoxDecoration(
          color: AppConstants.darkBg.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConstants.neonPink, width: 2),
          boxShadow: [
            BoxShadow(
              color: AppConstants.neonPink.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Enhanced Profile Header
                      Center(
                        child: AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: 1.0 + (_pulseController.value * 0.05),
                              child: _buildGradeIcon(
                                  widget.oficial!.grado,
                                  widget.oficial!.activo,
                                  widget.oficial!.activo
                                      ? const Color(0xFF00CFFF)
                                      : const Color(0xFFFF8C00)),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Officer Name with Glow Effect
                      AnimatedBuilder(
                        animation: _glowController,
                        builder: (context, child) {
                          return ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: [
                                Colors.white,
                                (widget.oficial!.activo
                                        ? const Color(0xFF00CFFF)
                                        : const Color(0xFFFF8C00))
                                    .withValues(alpha: 0.9),
                                Colors.white,
                              ],
                              stops: [
                                0.0,
                                0.5 + (_glowController.value * 0.3),
                                1.0,
                              ],
                            ).createShader(bounds),
                            child: Text(
                              (widget.oficial!.nombreOficial ?? 'SIN NOMBRE')
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),

                      // Status and Grade Compact Display
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: widget.oficial!.activo
                                    ? Colors.greenAccent
                                    : Colors.orangeAccent,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (widget.oficial!.activo
                                            ? Colors.greenAccent
                                            : Colors.orangeAccent)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "GRADO ${GradoAssets.displayName(widget.oficial!.grado)} • ${widget.oficial!.activo ? 'ACTIVO' : 'INACTIVO'}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.32),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                            width: 1,
                          ),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 6,
                          children: [
                            _buildTopInfoChip('REO', reoNombre),
                            _buildTopInfoChip('CTRL', controlCoords),
                            _buildTopInfoChip('ID', idOficial),
                            _buildTopInfoChip('TEL', telefono),
                            _buildTopInfoChip('JUR', jurisdiccionLabel),
                            _buildTopInfoChip('EQUIPO', equipoId),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxHeight: 500,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Performance Overview Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Section Header
                            Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00CFFF)
                                            .withValues(
                                                alpha: 0.8 +
                                                    (_pulseController.value *
                                                        0.2)),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00CFFF)
                                                .withValues(alpha: 0.5),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "PERFIL OPERATIVO",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontFamily: 'Orbitron',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Circular Performance Indicators
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildCircularMetric("ACTIVIDAD", reportesHoy,
                                    10, Colors.blueAccent),
                                _buildCircularMetric(
                                    "PARTES", partesHoy, 5, Colors.greenAccent),
                                _buildCircularMetric("ALERTAS", alertasOficial,
                                    3, Colors.redAccent),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Activity Timeline Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: Colors.purpleAccent.withValues(
                                            alpha: 0.8 +
                                                (_pulseController.value * 0.2)),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.purpleAccent
                                                .withValues(alpha: 0.5),
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "ACTIVIDAD RECIENTE",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontFamily: 'Orbitron',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _buildActivityTimeline(
                                reportesOficial, partesOficial),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Compliance & Performance Dashboard
                      Row(
                        children: [
                          // Compliance Chart
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF00CFFF)
                                                  .withValues(
                                                      alpha: 0.8 +
                                                          (_pulseController
                                                                  .value *
                                                              0.2)),
                                              shape: BoxShape.circle,
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 6),
                                      const Text(
                                        "CUMPLIMIENTO",
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 9,
                                          fontFamily: 'Orbitron',
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: TacticalSparkline(
                                      data: complianceHistory,
                                      lineColor: AppConstants.neonCyan,
                                      width: double.infinity,
                                      height: 60,
                                      showFill: true,
                                      showGrid: false,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          // Performance Rating
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    rendimiento['rating'],
                                    style: TextStyle(
                                      color: rendimiento['color'],
                                      fontSize: 12,
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "${rendimiento['score']}%",
                                    style: TextStyle(
                                      color: rendimiento['color']
                                          .withValues(alpha: 0.8),
                                      fontSize: 16,
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Text(
                                    "CALIFICACIÓN",
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 7,
                                      fontFamily: 'Rajdhani',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Spectrum Activity Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.1),
                              width: 1),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        color: AppConstants.neonCyan.withValues(
                                            alpha: 0.8 +
                                                (_pulseController.value * 0.2)),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                              color: AppConstants.neonCyan
                                                  .withValues(alpha: 0.5),
                                              blurRadius: 4)
                                        ],
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                const Text("HIST2D ACTIVIDAD",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontFamily: 'Orbitron',
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            AnimatedBuilder(
                              animation: _spectrumController,
                              builder: (context, child) {
                                return CustomPaint(
                                  size: const Size(double.infinity, 60),
                                  painter: SpectrumPainter(
                                      animation: _spectrumController.value,
                                      color: AppConstants.neonCyan),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Status Overview Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatusOverviewCard(
                              "ÚLTIMO REPORTE",
                              ultimoReporteValue,
                              ultimoReporteSubtitle,
                              ultimoReporteColor,
                              Icons.access_time,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatusOverviewCard(
                              "ESTADO ACTUAL",
                              estadoActualValue,
                              estadoActualSubtitle,
                              estadoActualColor,
                              estadoActualIcon,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularMetric(
      String label, int value, int maxValue, Color color) {
    try {
      final percentage =
          maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;

      return Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              try {
                return Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                      width: 3,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: percentage,
                        strokeWidth: 3,
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          color.withValues(
                              alpha: 0.8 + (_pulseController.value * 0.2)),
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                        child: Center(
                          child: Text(
                            value.toString(),
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              } catch (e) {
                return Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.withValues(alpha: 0.3),
                  ),
                  child: const Icon(Icons.error, color: Colors.red, size: 20),
                );
              }
            },
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 8,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    } catch (e) {
      return Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.withValues(alpha: 0.3),
            ),
            child: const Icon(Icons.error, color: Colors.red, size: 20),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 8,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildActivityTimeline(List reportes, List partes) {
    final activities = <Map<String, dynamic>>[];
    try {
      // Process reportes
      for (final r in reportes) {
        final fechaHora = r.fechaHora;
        if (fechaHora != null) {
          activities.add({
            'type': 'reporte',
            'data': r,
            'time': fechaHora,
          });
        }
      }

      // Process partes
      for (final p in partes) {
        final timestamp = p.timestamp;
        if (timestamp != null) {
          activities.add({
            'type': 'parte',
            'data': p,
            'time': timestamp,
          });
        }
      }

      // Sort activities by time (most recent first)
      activities.sort((a, b) {
        final timeA = a['time'] as DateTime?;
        final timeB = b['time'] as DateTime?;
        if (timeA == null && timeB == null) return 0;
        if (timeA == null) return 1;
        if (timeB == null) return -1;
        return timeB.compareTo(timeA);
      });

      if (activities.isEmpty) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text(
              "Sin actividad reciente",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        );
      }

      return Column(
        children: activities.take(5).map((activity) {
          final isReporte = activity['type'] == 'reporte';
          final time = activity['time'] as DateTime?;
          if (time == null) return const SizedBox.shrink();

          final timeStr =
              "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isReporte ? Colors.blueAccent : Colors.greenAccent,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isReporte ? Colors.blueAccent : Colors.greenAccent)
                                .withValues(alpha: 0.5),
                        blurRadius: 3,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isReporte ? "REPORTE ENVIADO" : "PARTE REGISTRADO",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        timeStr,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 8,
                          fontFamily: 'Rajdhani',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    } catch (e) {
      // Fallback UI if timeline fails completely
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            "Error cargando actividad",
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      );
    }
  }

  Widget _buildStatusOverviewCard(
      String title, String value, String subtitle, Color color, IconData icon) {
    try {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              color.withValues(alpha: 0.1),
              Colors.black.withValues(alpha: 0.2),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 8,
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 7,
                  fontFamily: 'Rajdhani',
                ),
              ),
            ],
          ],
        ),
      );
    } catch (e) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          "Error",
          style: TextStyle(color: Colors.red, fontSize: 10),
        ),
      );
    }
  }

  List<double> _calculateComplianceHistory(List reportes, List partes) {
    final now = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (index) {
        final day = now.subtract(Duration(days: 6 - index));
        return DateTime(day.year, day.month, day.day);
      },
    );

    final reportesByDay = <String, int>{};
    for (final r in reportes) {
      final date = r.fechaHora;
      if (date == null) continue;
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      reportesByDay[key] = (reportesByDay[key] ?? 0) + 1;
    }

    final partesByDay = <String, int>{};
    for (final p in partes) {
      final date = p.timestamp;
      if (date == null) continue;
      final key =
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      partesByDay[key] = (partesByDay[key] ?? 0) + 1;
    }

    final dailySignals = <double>[];
    for (final day in days) {
      final key =
          '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final reportesCount = reportesByDay[key] ?? 0;
      final partesCount = partesByDay[key] ?? 0;
      final signal = reportesCount.toDouble() + (partesCount * 3.0);
      dailySignals.add(signal);
    }

    final peakSignal = dailySignals.fold<double>(
      0,
      (current, value) => value > current ? value : current,
    );
    if (peakSignal <= 0) {
      return List<double>.filled(7, 0);
    }

    return dailySignals
        .map((signal) => ((signal / peakSignal) * 100).clamp(0.0, 100.0))
        .toList();
  }

  Widget _buildTopInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(6),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label: ',
              style: TextStyle(
                color: AppConstants.neonCyan.withValues(alpha: 0.85),
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                fontSize: 9,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getReoDisplayName(String? reoCode) {
    return widget.controller.getReoNombreByCodigo(reoCode);
  }

  String _getReoTelefono(String? reoCode) {
    return widget.controller.getReoTelefonoByCodigo(reoCode);
  }

  Offset _controlPointForReo(String? reoCode) {
    final reo = widget.controller.findReoByCodigo(reoCode);
    final parsed = widget.controller.parseCoords(reo?.coordenadasCasa);
    if (parsed != null) {
      return Offset(parsed.lat, parsed.lng);
    }
    return const Offset(-21.5355, -64.7296);
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }

  Widget _buildGradeIcon(String? grado, bool active, Color statusColor) {
    final gradeLevel = GradoAssets.hierarchyLevel(grado);
    final iconPath = GradoAssets.iconAsset(grado);

    final List<Color> gradeColors = [
      Colors.grey,
      Colors.white,
      Colors.blueAccent,
      Colors.greenAccent,
      Colors.yellowAccent,
      Colors.orangeAccent,
      Colors.redAccent,
    ];

    final gradeColor =
        gradeColors[(gradeLevel - 1).clamp(0, gradeColors.length - 1)];

    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gradeColor.withValues(alpha: active ? 0.2 : 0.1),
        border: Border.all(
          color: gradeColor.withValues(alpha: active ? 0.5 : 0.3),
          width: 3,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: gradeColor.withValues(alpha: 0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Image.asset(
          iconPath,
          width: 75,
          height: 75,
          color: active ? Colors.white : Colors.white54,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'G$gradeLevel',
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 16,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
    );
  }
}
