import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/detallado_perfil_oficial_dialog.dart';

class InconsistenciasView extends StatelessWidget {
  const InconsistenciasView({
    super.key,
    required this.inconsistencias,
  });

  final List<Map<String, dynamic>> inconsistencias;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final oficialNameById = <String, String>{
      for (final o in controller.oficiales)
        o.idOficial.trim(): o.nombreOficial.trim(),
    };
    final dailySeries = _buildDailySeries(inconsistencias);
    final criticalDailySeries =
        _buildDailySeriesByPriority(inconsistencias, 'CRITICA');
    final monthlySeries = _buildMonthlySeries(inconsistencias);

    return LayoutBuilder(
      builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final mobileViewport =
            media.size.width < 980 || media.size.shortestSide < 700;
        final chartBandHeight = (constraints.maxHeight *
                (mobileViewport ? 0.34 : 0.22))
            .clamp(mobileViewport ? 102.0 : 82.0, mobileViewport ? 164.0 : 104.0);
        final titleSize = mobileViewport ? 10.0 : 9.0;
        final gap = mobileViewport ? 10.0 : 8.0;

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: SizedBox(
                height: chartBandHeight,
                child: Row(
                  children: [
                    Expanded(
                      child: _MicroChartCard(
                        title: 'DIARIAS (TOTAL/CRIT)',
                        height: chartBandHeight,
                        titleSize: titleSize,
                        child: _MiniMultiLineChart(
                          primaryValues: dailySeries,
                          secondaryValues: criticalDailySeries,
                          primaryColor: Colors.orangeAccent,
                          secondaryColor: AppConstants.warningRed,
                        ),
                      ),
                    ),
                    SizedBox(width: gap),
                    Expanded(
                      child: _MicroChartCard(
                        title: 'MENSUALES',
                        height: chartBandHeight,
                        titleSize: titleSize,
                        child: _MiniBarChart(
                          values: monthlySeries,
                          color: AppConstants.neonCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                itemCount: inconsistencias.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final inc = inconsistencias[index];
                  final prioridad =
                      (inc['prioridad'] ?? 'MEDIA').toString().toUpperCase();
                  final estado =
                      (inc['estado'] ?? 'ABIERTA').toString().toUpperCase();
                  final motivo =
                      _tipoDisplay((inc['tipo_inconsistencia'] ?? '').toString());
                  final descripcion = (inc['descripcion'] ?? inc['detalle'] ?? '')
                      .toString()
                      .trim();
                  final explicacion = _tipoExplain(
                    (inc['tipo_inconsistencia'] ?? '').toString(),
                    descripcion,
                  );
                  final oficialId =
                      (inc['id_oficial'] ?? 'N/D').toString().trim();
                  final oficialLabel =
                      oficialNameById[oficialId] ?? 'OFICIAL $oficialId';
                  final fecha = _parseDateSafe(inc['fecha_deteccion']);
                  final prioridadColor = _prioridadColor(prioridad);

                  return InkWell(
                    onTap: () => _openOficialProfile(controller, oficialId),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              (AppConstants.estadosColor[estado] ?? Colors.grey)
                                  .withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: prioridadColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: prioridadColor.withValues(alpha: 0.85),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              prioridad,
                              style: TextStyle(
                                color: prioridadColor,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w700,
                                fontSize: 9,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '$oficialLabel · $estado',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.94),
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  motivo,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: prioridadColor.withValues(alpha: 0.95),
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  explicacion,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.66),
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w600,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 44,
                            child: Text(
                              _formatHourMinute(fecha),
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.6),
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openOficialProfile(DashboardController controller, String oficialId) {
    if (oficialId.isEmpty || oficialId == 'N/D') {
      Get.snackbar(
        'Oficial no disponible',
        'La inconsistencia no tiene oficial asociado.',
        backgroundColor: AppConstants.warningRed.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
      return;
    }

    final oficial = controller.oficiales.firstWhereOrNull(
      (o) => o.idOficial.trim() == oficialId,
    );

    if (oficial == null) {
      Get.snackbar(
        'Oficial no encontrado',
        'No se encontró el perfil para $oficialId.',
        backgroundColor: AppConstants.warningRed.withValues(alpha: 0.8),
        colorText: Colors.white,
      );
      return;
    }

    Get.dialog(
      DetalladoPerfilOficialDialog(
        oficial: oficial,
        controller: controller,
      ),
    );
  }

  List<double> _buildDailySeries(List<Map<String, dynamic>> data) {
    final now = DateTime.now();
    final counts = List<int>.filled(7, 0);
    for (final item in data) {
      final dt = _parseDateSafe(item['fecha_deteccion']);
      final dayDiff =
          now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (dayDiff >= 0 && dayDiff < 7) {
        counts[6 - dayDiff] += 1;
      }
    }
    return counts.map((v) => v.toDouble()).toList();
  }

  List<double> _buildDailySeriesByPriority(
    List<Map<String, dynamic>> data,
    String prioridadObjetivo,
  ) {
    final now = DateTime.now();
    final counts = List<int>.filled(7, 0);
    for (final item in data) {
      final prioridad = (item['prioridad'] ?? '').toString().toUpperCase();
      if (prioridad != prioridadObjetivo.toUpperCase()) continue;
      final dt = _parseDateSafe(item['fecha_deteccion']);
      final dayDiff =
          now.difference(DateTime(dt.year, dt.month, dt.day)).inDays;
      if (dayDiff >= 0 && dayDiff < 7) {
        counts[6 - dayDiff] += 1;
      }
    }
    return counts.map((v) => v.toDouble()).toList();
  }

  List<double> _buildMonthlySeries(List<Map<String, dynamic>> data) {
    final now = DateTime.now();
    final counts = List<int>.filled(6, 0);
    for (final item in data) {
      final dt = _parseDateSafe(item['fecha_deteccion']);
      final monthDiff = (now.year - dt.year) * 12 + (now.month - dt.month);
      if (monthDiff >= 0 && monthDiff < 6) {
        counts[5 - monthDiff] += 1;
      }
    }
    return counts.map((v) => v.toDouble()).toList();
  }

  DateTime _parseDateSafe(dynamic value) {
    if (value is DateTime) return value.toLocal();
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  String _formatHourMinute(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _tipoDisplay(String tipo) {
    switch (tipo) {
      case 'GPS_FALSO':
        return 'GPS FALSO';
      case 'VOZ_NO_COINCIDE':
        return 'VOZ NO COINCIDE';
      case 'UBICACION_FOTO_NO_COINCIDE':
      case 'FOTO_UBICACION_NO_COINCIDE':
        return 'FOTO/GPS NO COINCIDE';
      case 'MANIPULACION_GPS':
        return 'MANIPULACIÓN GPS';
      case 'COORDENADAS_IMPOSIBLES':
        return 'COORDENADAS IMPOSIBLES';
      case 'IMEI_CAMBIADO':
        return 'IMEI CAMBIADO';
      default:
        return tipo.isEmpty ? 'INCONSISTENCIA' : tipo;
    }
  }

  String _tipoExplain(String tipoRaw, String descripcionRaw) {
    final tipo = tipoRaw.toUpperCase().trim();
    final descripcion = descripcionRaw.trim();
    if (descripcion.isNotEmpty) return descripcion;

    switch (tipo) {
      case 'GPS_FALSO':
      case 'MANIPULACION_GPS':
        return 'Se detectó ubicación simulada o manipulación del proveedor GPS.';
      case 'COORDENADAS_IMPOSIBLES':
        return 'Cambio de posición con salto/velocidad no plausible en el intervalo.';
      case 'DISTANCIA_EXCEDIDA':
        return 'El oficial superó la distancia permitida respecto al punto de control.';
      case 'SIN_DATOS_GPS':
        return 'No hubo coordenadas confiables para validar el reporte.';
      case 'FALTA_REPORTE':
        return 'No se registró parte obligatorio dentro de la ventana de control.';
      case 'VOZ_NO_COINCIDE':
      case 'POSIBLE_SUPLANTACION':
        return 'La verificación de voz no coincidió con el perfil registrado.';
      case 'IMEI_CAMBIADO':
        return 'El equipo reportado no coincide con el dispositivo autorizado.';
      default:
        return 'Evento lógico-operativo que requiere revisión y cierre documentado.';
    }
  }

  Color _prioridadColor(String prioridad) {
    switch (prioridad) {
      case 'CRITICA':
        return AppConstants.warningRed;
      case 'ALTA':
        return AppConstants.alertOrange;
      case 'MEDIA':
        return AppConstants.neonOrange;
      case 'BAJA':
        return AppConstants.successGreen;
      default:
        return Colors.grey;
    }
  }
}

class _MicroChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;
  final double titleSize;

  const _MicroChartCard({
    required this.title,
    required this.child,
    this.height,
    this.titleSize = 9,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 74,
      padding: EdgeInsets.fromLTRB(8, titleSize >= 10 ? 8 : 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.16), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              fontFamily: 'Orbitron',
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: titleSize >= 10 ? 8 : 6),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MiniMultiLineChart extends StatelessWidget {
  final List<double> primaryValues;
  final List<double> secondaryValues;
  final Color primaryColor;
  final Color secondaryColor;

  const _MiniMultiLineChart({
    required this.primaryValues,
    required this.secondaryValues,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniMultiLinePainter(
        primaryValues: primaryValues,
        secondaryValues: secondaryValues,
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _MiniBarChart extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _MiniBarChart({required this.values, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniBarPainter(values: values, color: color),
      child: const SizedBox.expand(),
    );
  }
}

class _MiniMultiLinePainter extends CustomPainter {
  final List<double> primaryValues;
  final List<double> secondaryValues;
  final Color primaryColor;
  final Color secondaryColor;

  _MiniMultiLinePainter({
    required this.primaryValues,
    required this.secondaryValues,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (primaryValues.isEmpty && secondaryValues.isEmpty) return;
    final values = [...primaryValues, ...secondaryValues];
    final maxV = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    final points = primaryValues.length > secondaryValues.length
        ? primaryValues.length
        : secondaryValues.length;
    final stepX = points <= 1 ? size.width : size.width / (points - 1);

    void drawLine(List<double> series, Color color) {
      if (series.isEmpty) return;
      final path = Path();
      for (int i = 0; i < series.length; i++) {
        final x = i * stepX;
        final y = size.height - ((series[i] / safeMax) * size.height);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: 0.9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );
    }

    drawLine(primaryValues, primaryColor);
    drawLine(secondaryValues, secondaryColor);
  }

  @override
  bool shouldRepaint(covariant _MiniMultiLinePainter oldDelegate) {
    return oldDelegate.primaryValues != primaryValues ||
        oldDelegate.secondaryValues != secondaryValues ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor;
  }
}

class _MiniBarPainter extends CustomPainter {
  final List<double> values;
  final Color color;

  _MiniBarPainter({required this.values, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final maxV = values.reduce((a, b) => a > b ? a : b);
    final safeMax = maxV <= 0 ? 1.0 : maxV;
    final barW = size.width / (values.length * 1.5);

    for (int i = 0; i < values.length; i++) {
      final h = (values[i] / safeMax) * size.height;
      final x = i * (barW * 1.5);
      final rect = Rect.fromLTWH(x, size.height - h, barW, h);
      final paint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniBarPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}
