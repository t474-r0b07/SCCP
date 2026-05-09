import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/grado_assets.dart';
import '../../../core/widgets/tactical_radial_gauge.dart';
import '../../../core/widgets/tactical_sparkline.dart';
import '../../../core/widgets/mini_donut_painter.dart';
import '../../../core/widgets/tactical_status_indicator.dart';
import '../../../data/models/oficial_model.dart';
import '../../../presentation/controllers/dashboard_controller.dart';
import '../../../presentation/widgets/detallado_perfil_oficial_dialog.dart';

class EstadoOperativoCard extends StatefulWidget {
  const EstadoOperativoCard({super.key});

  @override
  State<EstadoOperativoCard> createState() => _EstadoOperativoCardState();
}

class _EstadoOperativoCardState extends State<EstadoOperativoCard>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;
  late AnimationController _pulseController;
  late DashboardController controller;

  @override
  void initState() {
    super.initState();

    // Breathing animation for compliance gauge
    _breatheController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _breatheAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );

    // Pulse animation for alerts
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    controller = Get.find<DashboardController>();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final String grupo = controller.currentGroup.value;
      final oficialesGrupo = controller.oficiales
          .where(
            (o) =>
                o.activo &&
                (o.grupo ?? '').toUpperCase() == grupo.toUpperCase(),
          )
          .toList();

      // Fallback for when there are no officers in current shift
      final hasOfficers = oficialesGrupo.isNotEmpty;
      final expectedOfficers = hasOfficers ? oficialesGrupo.length : 0;

      // Calculate compliance metrics (sophisticated calculation)
      final complianceData = _calculateComplianceMetrics(
        oficialesGrupo,
        controller.reportes,
      );
      final compliancePercentage = complianceData['percentage'];
      final trulyActiveCount = complianceData['trulyActive'];

      // Mock trend data for sparkline - adjust for negative data
      final trendData = hasOfficers
          ? <double>[
              (trulyActiveCount - 2).clamp(0, expectedOfficers).toDouble(),
              (trulyActiveCount - 1).clamp(0, expectedOfficers).toDouble(),
              trulyActiveCount.toDouble(),
              (trulyActiveCount + 1).clamp(0, expectedOfficers).toDouble(),
              (trulyActiveCount + 2).clamp(0, expectedOfficers).toDouble(),
            ]
          : <double>[0, 0, 0, 0, 0];

      // Force rebuild when acknowledged alerts change.
      controller.alertAcknowledgementVersion.value;
      final alertasCriticas =
          controller.alertasEpisodiosActivosNoLeidosDelTurno.length;
      final metricColor =
          alertasCriticas > 0 ? AppConstants.neonPink : AppConstants.neonCyan;
      final activeGlow = alertasCriticas > 0
          ? AppConstants.neonPink.withValues(alpha: 0.3)
          : AppConstants.neonCyan.withValues(alpha: 0.22);

      return LayoutBuilder(
        builder: (context, constraints) {
          final gaugeSize = (constraints.maxHeight * 0.38).clamp(60.0, 96.0);
          final donutSize = (constraints.maxHeight * 0.33).clamp(56.0, 88.0);
          final waveformHeight =
              (constraints.maxHeight * 0.16).clamp(18.0, 36.0);

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showAlertasSelector(context, controller, grupo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                decoration: alertasCriticas > 0
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: activeGlow,
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      )
                    : BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppConstants.neonCyan.withValues(alpha: 0.22),
                          width: 1,
                        ),
                        gradient: LinearGradient(
                          colors: [
                            AppConstants.neonCyan.withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedBuilder(
                              animation: _breatheAnimation,
                              builder: (context, child) {
                                return Transform.scale(
                                  scale: compliancePercentage < 80
                                      ? _breatheAnimation.value
                                      : 1.0,
                                  child: child,
                                );
                              },
                              child: TacticalRadialGauge(
                                value: compliancePercentage,
                                max: 100,
                                size: gaugeSize,
                                label: "TURNO",
                                color: metricColor,
                                showGlow: compliancePercentage < 80,
                                critical: compliancePercentage < 70,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'CUMPLIMIENTO',
                              style: TextStyle(
                                color: metricColor.withValues(alpha: 0.8),
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: donutSize,
                              height: donutSize,
                              child: CustomPaint(
                                painter: MiniDonutPainter(
                                  segments: [
                                    DonutSegment(
                                      value: trulyActiveCount.toDouble(),
                                      color:
                                          trulyActiveCount == expectedOfficers
                                              ? Colors.greenAccent
                                              : metricColor,
                                      label: "Activos",
                                    ),
                                    DonutSegment(
                                      value:
                                          (expectedOfficers - trulyActiveCount)
                                              .clamp(0, expectedOfficers)
                                              .toDouble(),
                                      color: trulyActiveCount ==
                                              expectedOfficers
                                          ? Colors.green.withValues(alpha: 0.3)
                                          : Colors.redAccent
                                              .withValues(alpha: 0.6),
                                      label: "Inactivos",
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Text(
                                    "$trulyActiveCount/$expectedOfficers",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TacticalSparkline(
                              data: trendData,
                              lineColor: metricColor.withValues(alpha: 0.85),
                              width: double.infinity,
                              height: waveformHeight,
                              showFill: true,
                              showGrid: true,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'TENDENCIA TURNO',
                              style: TextStyle(
                                color: metricColor.withValues(alpha: 0.8),
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () =>
                              _showAlertasSelector(context, controller, grupo),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Transform.scale(
                                    scale: alertasCriticas > 0
                                        ? 1.1 + (_pulseController.value * 0.02)
                                        : 1.0,
                                    child: child,
                                  );
                                },
                                child: Container(
                                  width: donutSize,
                                  height: donutSize,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: alertasCriticas > 0
                                          ? AppConstants.neonPink
                                          : Colors.white24,
                                      width: 2,
                                    ),
                                    boxShadow: alertasCriticas > 0
                                        ? [
                                            BoxShadow(
                                              color: AppConstants.neonPink
                                                  .withValues(alpha: 0.6),
                                              blurRadius: 20 +
                                                  (_pulseController.value * 12),
                                              spreadRadius: 5 +
                                                  (_pulseController.value * 6),
                                            ),
                                          ]
                                        : null,
                                  ),
                                  child: Center(
                                    child: Text(
                                      "$alertasCriticas",
                                      style: TextStyle(
                                        color: alertasCriticas > 0
                                            ? AppConstants.neonPink
                                            : Colors.white70,
                                        fontFamily: 'Orbitron',
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'RIESGO ACTIVO',
                                style: TextStyle(
                                  color: (alertasCriticas > 0
                                          ? AppConstants.neonPink
                                          : Colors.white70)
                                      .withValues(alpha: 0.85),
                                  fontFamily: 'Rajdhani',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              TacticalStatusIndicator(
                                status:
                                    alertasCriticas > 0 ? "critical" : "normal",
                                color: alertasCriticas > 0
                                    ? AppConstants.neonPink
                                    : Colors.white24,
                                size: 8,
                                pulse: alertasCriticas > 0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  Map<String, dynamic> _calculateComplianceMetrics(
    List oficialesGrupo,
    List reportes,
  ) {
    if (oficialesGrupo.isEmpty) {
      return {'percentage': 0.0, 'trulyActive': 0};
    }

    int trulyActiveCount = 0;
    final now = DateTime.now();
    final reportesByOficial = <String, List<dynamic>>{};
    for (final reporte in reportes) {
      final key = reporte.idOficialRef.toString();
      (reportesByOficial[key] ??= <dynamic>[]).add(reporte);
    }

    for (final oficial in oficialesGrupo) {
      final oficialReportes =
          reportesByOficial[oficial.idOficial.toString()] ?? const <dynamic>[];

      if (oficialReportes.isEmpty) {
        continue;
      }

      DateTime? mostRecentTime;
      int actualReportsInLastHour = 0;
      for (final reporte in oficialReportes) {
        final reportTime = reporte.fechaHora as DateTime;
        if (mostRecentTime == null || reportTime.isAfter(mostRecentTime)) {
          mostRecentTime = reportTime;
        }
        if (now.difference(reportTime).inMinutes <= 60) {
          actualReportsInLastHour++;
        }
      }
      if (mostRecentTime == null) {
        continue;
      }

      // Check if last report is more than 30 minutes old
      final timeSinceLastReport = now.difference(mostRecentTime).inMinutes;

      if (timeSinceLastReport > 30) {
        continue;
      }

      // Cadencia operativa vigente: 1 reporte cada 6 minutos.
      const expectedReportsInLastHour = 10; // 60 / 6
      const maxMissingReportsAllowed = 5; // tolera hasta 30 min sin reporte

      final missingReports =
          (expectedReportsInLastHour - actualReportsInLastHour).clamp(
        0,
        expectedReportsInLastHour,
      );

      if (missingReports > maxMissingReportsAllowed) {
        continue;
      }

      // Passed all checks - truly active
      trulyActiveCount++;
    }

    // Calculate percentage
    final percentage = (trulyActiveCount / oficialesGrupo.length) * 100.0;

    return {
      'percentage': percentage.clamp(0.0, 100.0),
      'trulyActive': trulyActiveCount,
    };
  }

  // === SECCIÓN: SELECTOR DE ALERTAS ===
  void _showAlertasSelector(
    BuildContext context,
    DashboardController controller,
    String grupo,
  ) {
    final media = MediaQuery.of(context);
    final mobileDialog = kIsWeb
        ? media.size.width < 760
        : media.size.width < 760 || media.size.height < 760;
    final dialogWidth = mobileDialog ? media.size.width * 0.96 : 550.0;
    final dialogPadding = mobileDialog ? 12.0 : 20.0;

    final oficiales = controller.oficiales
        .where(
          (o) =>
              o.activo && (o.grupo ?? '').toUpperCase() == grupo.toUpperCase(),
        )
        .toList();

    final reportesByOficial = <String, List<dynamic>>{};
    for (final reporte in controller.reportes) {
      final key = reporte.idOficialRef.toString();
      (reportesByOficial[key] ??= <dynamic>[]).add(reporte);
    }

    final activeOficiales = <String>{};
    for (final oficial in oficiales) {
      final complianceData = _calculateComplianceMetrics(
        [oficial],
        reportesByOficial[oficial.idOficial.toString()] ?? const <dynamic>[],
      );
      if (complianceData['trulyActive'] > 0) {
        activeOficiales.add(oficial.idOficial.toString());
      }
    }

    final alertasActivasByOficial = <String, List<Map<String, dynamic>>>{};
    for (final alerta in controller.alertasEpisodiosActivosDelTurno) {
      final id =
          (alerta['id_oficial_ref'] ?? alerta['id_oficial'] ?? '').toString();
      if (id.isEmpty) continue;
      (alertasActivasByOficial[id] ??= <Map<String, dynamic>>[]).add(alerta);
    }

    DateTime alertTimestamp(Map<String, dynamic> alerta) {
      final raw = alerta['ultimo_reporte_alerta'] ??
          alerta['inicio_alerta'] ??
          alerta['fecha_hora'];
      return DateTime.tryParse(raw?.toString() ?? '') ?? DateTime(1970);
    }

    for (final alerts in alertasActivasByOficial.values) {
      alerts.sort((a, b) {
        final sevA = (a['severidad'] as num?)?.toInt() ?? 1;
        final sevB = (b['severidad'] as num?)?.toInt() ?? 1;
        if (sevA != sevB) return sevB.compareTo(sevA);
        return alertTimestamp(b).compareTo(alertTimestamp(a));
      });
    }

    final inconsistenciasAbiertasByOficial = <String, int>{};
    for (final inc in controller.inconsistencias) {
      final id = (inc['id_oficial'] ?? '').toString();
      if (id.isEmpty) continue;
      final estado = (inc['estado'] ?? '').toString().toUpperCase();
      if (estado == 'CERRADA') continue;
      inconsistenciasAbiertasByOficial[id] =
          (inconsistenciasAbiertasByOficial[id] ?? 0) + 1;
    }

    String alertActionLabel(int severidad, bool hasAlert, int inconsistencias) {
      if (hasAlert && severidad >= 3) return 'ACCION INMEDIATA';
      if (hasAlert && severidad == 2) return 'VERIFICAR AHORA';
      if (inconsistencias > 0) return 'REVISAR INCONSISTENCIA';
      return 'SIN ACCION';
    }

    final filas = oficiales.map((oficial) {
      final id = oficial.idOficial.toString();
      final oficialReportes = reportesByOficial[id] ?? const <dynamic>[];
      final reportesHoy =
          oficialReportes.where((r) => _isToday(r.fechaHora)).length;
      final trulyActive = activeOficiales.contains(id);
      final latestReport =
          _latestReporteOficial(oficialReportes.cast<dynamic>());
      final battery = latestReport?.nivelBateria;
      final gpsOk = latestReport?.gpsReal ?? false;
      final reoDisplay = controller.getReoNombreByCodigo(oficial.reoAsignado);
      final lastActivity = _getLastActivityTime(
        oficialReportes,
        controller.partes
            .where((p) => p.idOficial == oficial.idOficial)
            .toList(),
      );

      final alertasActivas =
          alertasActivasByOficial[id] ?? const <Map<String, dynamic>>[];
      final hasAlerts = alertasActivas.isNotEmpty;
      final alertaPrincipal = hasAlerts ? alertasActivas.first : null;
      final severidadPrincipal =
          ((alertaPrincipal?['severidad'] as num?)?.toInt() ?? 1).clamp(1, 3);
      final motivoPrincipal = hasAlerts
          ? ((alertaPrincipal?['motivo_alerta'] ?? 'ALERTA OPERATIVA')
              .toString()
              .trim())
          : '';
      final inconsistenciasAbiertas = inconsistenciasAbiertasByOficial[id] ?? 0;
      final accion = alertActionLabel(
        severidadPrincipal,
        hasAlerts,
        inconsistenciasAbiertas,
      );

      final riskScore = (hasAlerts ? 200 : 0) +
          (severidadPrincipal * 30) +
          (inconsistenciasAbiertas * 12) +
          (trulyActive ? 0 : 8) +
          (reportesHoy == 0 ? 4 : 0);

      return {
        'oficial': oficial,
        'id': id,
        'trulyActive': trulyActive,
        'reportesHoy': reportesHoy,
        'hasAlerts': hasAlerts,
        'alertasOficial': alertasActivas.length,
        'alertasDetalle': alertasActivas,
        'alertaPrincipal': alertaPrincipal,
        'severidadPrincipal': severidadPrincipal,
        'motivoPrincipal': motivoPrincipal,
        'inconsistenciasAbiertas': inconsistenciasAbiertas,
        'accion': accion,
        'latestReport': latestReport,
        'battery': battery,
        'gpsOk': gpsOk,
        'reoDisplay': reoDisplay,
        'lastActivity': lastActivity,
        'riskScore': riskScore,
      };
    }).toList();

    filas.sort((a, b) {
      final scoreA = (a['riskScore'] as num?)?.toInt() ?? 0;
      final scoreB = (b['riskScore'] as num?)?.toInt() ?? 0;
      if (scoreA != scoreB) return scoreB.compareTo(scoreA);
      final repA = (a['reportesHoy'] as num?)?.toInt() ?? 0;
      final repB = (b['reportesHoy'] as num?)?.toInt() ?? 0;
      return repA.compareTo(repB);
    });

    Get.dialog(
      Dialog(
        backgroundColor: AppConstants.darkBg.withValues(alpha: 0.95),
        insetPadding: EdgeInsets.symmetric(
          horizontal: mobileDialog ? 6 : 40,
          vertical: mobileDialog ? 12 : 24,
        ),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: Colors.purpleAccent.withValues(alpha: 0.5),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          width: dialogWidth,
          constraints: BoxConstraints(
            maxHeight: mobileDialog ? media.size.height * 0.9 : 650,
          ),
          padding: EdgeInsets.all(dialogPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER DEL DIÁLOGO
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      // Alert icon with glow effect
                      Container(
                        width: mobileDialog ? 36 : 50,
                        height: mobileDialog ? 36 : 50,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Colors.purpleAccent.withValues(alpha: 0.8),
                              Colors.purpleAccent.withValues(alpha: 0.4),
                              Colors.black,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(
                            color: Colors.purpleAccent,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purpleAccent.withValues(alpha: 0.6),
                              blurRadius: 20,
                              spreadRadius: 3,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.warning,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                      ),
                      SizedBox(width: mobileDialog ? 8 : 15),
                      Text(
                        "[ ALERT_SYSTEM ]",
                        style: TextStyle(
                          color: Colors.purpleAccent,
                          fontSize: mobileDialog ? 9 : 10,
                          fontFamily: 'Orbitron',
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white24,
                      size: 18,
                    ),
                    onPressed: () => Get.back(),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "ALERTAS DEL DÍA - GRUPO $grupo",
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: mobileDialog ? 12 : 16,
                  letterSpacing: mobileDialog ? 1 : 2,
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: Obx(() {
                  final noLeidas =
                      controller.alertasEpisodiosActivosNoLeidosDelTurno.length;
                  return OutlinedButton.icon(
                    onPressed: noLeidas == 0
                        ? null
                        : () {
                            controller.acknowledgeAllAlertEpisodes(
                              controller.alertasEpisodiosActivosDelTurno,
                            );
                            Get.snackbar(
                              'Alertas',
                              'Se marcaron como vistas las alertas activas.',
                              snackPosition: SnackPosition.BOTTOM,
                              backgroundColor:
                                  AppConstants.neonCyan.withValues(alpha: 0.22),
                              colorText: Colors.white,
                              duration: const Duration(seconds: 2),
                            );
                          },
                    icon: const Icon(Icons.visibility_rounded, size: 14),
                    label: Text(
                      noLeidas > 0
                          ? 'MARCAR TODAS VISTAS ($noLeidas)'
                          : 'SIN ALERTAS NUEVAS',
                      style: const TextStyle(
                        fontFamily: 'Orbitron',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: AppConstants.neonCyan.withValues(alpha: 0.8),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  );
                }),
              ),
              const Divider(
                color: Colors.purpleAccent,
                thickness: 0.5,
                height: 30,
              ),

              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: filas.length,
                  itemBuilder: (context, index) {
                    final row = filas[index];
                    final oficial = row['oficial'] as Oficial;
                    final hasAlerts = row['hasAlerts'] == true;
                    final trulyActive = row['trulyActive'] == true;
                    final alertasOficial =
                        (row['alertasOficial'] as num?)?.toInt() ?? 0;
                    final reportesHoy =
                        (row['reportesHoy'] as num?)?.toInt() ?? 0;
                    final inconsistenciasAbiertas =
                        (row['inconsistenciasAbiertas'] as num?)?.toInt() ?? 0;
                    final motivoPrincipal =
                        (row['motivoPrincipal'] ?? '').toString();
                    final accion = (row['accion'] ?? '').toString();
                    final battery = row['battery'];
                    final gpsOk = row['gpsOk'] == true;
                    final reoDisplay = (row['reoDisplay'] ?? 'N/D').toString();
                    final lastActivity =
                        (row['lastActivity'] ?? 'N/A').toString();

                    final Color statusColor = hasAlerts
                        ? Colors.purpleAccent
                        : inconsistenciasAbiertas > 0
                            ? AppConstants.alertOrange
                            : const Color(0xFF00CFFF);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: hasAlerts
                            ? Colors.purpleAccent.withValues(alpha: 0.12)
                            : inconsistenciasAbiertas > 0
                                ? AppConstants.alertOrange
                                    .withValues(alpha: 0.1)
                                : trulyActive
                                    ? statusColor.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.2),
                        border: Border.all(
                          color: hasAlerts
                              ? Colors.purpleAccent.withValues(alpha: 0.6)
                              : inconsistenciasAbiertas > 0
                                  ? AppConstants.alertOrange
                                      .withValues(alpha: 0.6)
                                  : trulyActive
                                      ? statusColor.withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.1),
                          width:
                              hasAlerts || inconsistenciasAbiertas > 0 ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ListTile(
                        dense: mobileDialog,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: mobileDialog ? 8 : 12,
                          vertical: mobileDialog ? 2 : 4,
                        ),
                        onTap: () {
                          final alertasDetalle = (row['alertasDetalle']
                                  as List<Map<String, dynamic>>?) ??
                              const <Map<String, dynamic>>[];
                          if (alertasDetalle.isNotEmpty) {
                            controller
                                .acknowledgeAllAlertEpisodes(alertasDetalle);
                          }
                          Get.dialog(
                            DetalladoPerfilOficialDialog(
                              oficial: oficial,
                              controller: controller,
                            ),
                          );
                        },
                        leading: _buildGradeIcon(
                          oficial.grado,
                          trulyActive,
                          statusColor,
                        ),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              oficial.nombreOficial.toUpperCase(),
                              style: TextStyle(
                                color: hasAlerts || inconsistenciasAbiertas > 0
                                    ? statusColor
                                    : Colors.white,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 3),
                            if (hasAlerts)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.purpleAccent
                                      .withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.purpleAccent
                                        .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      motivoPrincipal.toUpperCase(),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontFamily: 'Rajdhani',
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      accion,
                                      style: const TextStyle(
                                        color: Colors.purpleAccent,
                                        fontSize: 9,
                                        fontFamily: 'Orbitron',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (inconsistenciasAbiertas > 0)
                              Text(
                                'INCONSISTENCIAS ABIERTAS: $inconsistenciasAbiertas | $accion',
                                style: TextStyle(
                                  color: AppConstants.alertOrange
                                      .withValues(alpha: 0.95),
                                  fontSize: 10,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 2),
                            Text(
                              "REO: $reoDisplay",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppConstants.neonCyan.withValues(
                                  alpha: trulyActive ? 0.85 : 0.65,
                                ),
                                fontSize: 10,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (hasAlerts) ...[
                                  Text(
                                    "AL:$alertasOficial",
                                    style: const TextStyle(
                                      color: Colors.purpleAccent,
                                      fontSize: 10,
                                      fontFamily: 'Orbitron',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (inconsistenciasAbiertas > 0) ...[
                                  Text(
                                    "INC:$inconsistenciasAbiertas",
                                    style: const TextStyle(
                                      color: AppConstants.alertOrange,
                                      fontSize: 10,
                                      fontFamily: 'Orbitron',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  "RP:$reportesHoy",
                                  style: const TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: 10,
                                    fontFamily: 'Orbitron',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: mobileDialog
                            ? null
                            : SizedBox(
                                width: 112,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Image.asset(
                                          'assets/icons/battery_full.png',
                                          width: 20,
                                          height: 20,
                                          color: (battery ?? 100) < 20
                                              ? Colors.redAccent
                                              : AppConstants.neonCyan,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          battery != null ? "$battery%" : "N/D",
                                          style: TextStyle(
                                            color: (battery ?? 100) < 20
                                                ? Colors.redAccent
                                                : AppConstants.neonCyan,
                                            fontSize: 11,
                                            fontFamily: 'Orbitron',
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Image.asset(
                                          gpsOk
                                              ? 'assets/icons/gps_active.png'
                                              : 'assets/icons/gps_inactive.png',
                                          width: 20,
                                          height: 20,
                                          color: gpsOk
                                              ? Colors.greenAccent
                                              : Colors.orangeAccent,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          gpsOk ? "OK" : "OFF",
                                          style: TextStyle(
                                            color: gpsOk
                                                ? Colors.greenAccent
                                                : Colors.orangeAccent,
                                            fontSize: 11,
                                            fontFamily: 'Orbitron',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                        subtitle: Row(
                          children: [
                            Text(
                              "GRADO ${GradoAssets.displayName(oficial.grado)}",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 9,
                                fontFamily: 'Rajdhani',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: hasAlerts
                                    ? Colors.purpleAccent
                                    : inconsistenciasAbiertas > 0
                                        ? AppConstants.alertOrange
                                        : trulyActive
                                            ? statusColor
                                            : Colors.grey,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (hasAlerts
                                            ? Colors.purpleAccent
                                            : inconsistenciasAbiertas > 0
                                                ? AppConstants.alertOrange
                                                : trulyActive
                                                    ? statusColor
                                                    : Colors.grey)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasAlerts
                                  ? "ALERTA ACTIVA"
                                  : inconsistenciasAbiertas > 0
                                      ? "INCONSISTENCIA ABIERTA"
                                      : trulyActive
                                          ? "ACTIVO"
                                          : "INACTIVO",
                              style: TextStyle(
                                color: hasAlerts
                                    ? Colors.purpleAccent
                                    : inconsistenciasAbiertas > 0
                                        ? AppConstants.alertOrange
                                        : trulyActive
                                            ? statusColor
                                            : Colors.grey,
                                fontSize: 9,
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Última: $lastActivity",
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 10.5,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (mobileDialog) ...[
                              const SizedBox(width: 8),
                              Text(
                                'BAT ${battery ?? "N/D"}% · GPS ${gpsOk ? "OK" : "OFF"}',
                                style: TextStyle(
                                  color: (gpsOk
                                          ? Colors.greenAccent
                                          : Colors.orangeAccent)
                                      .withValues(alpha: 0.92),
                                  fontSize: 9.5,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getLastActivityTime(List oficialReportes, List partes) {
    DateTime? latestTime;
    if (oficialReportes.isNotEmpty) {
      latestTime = oficialReportes
          .map((r) => r.fechaHora)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }
    if (partes.isNotEmpty) {
      final parteTime =
          partes.map((p) => p.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
      if (latestTime == null || parteTime.isAfter(latestTime)) {
        latestTime = parteTime;
      }
    }
    if (latestTime != null) {
      final local = latestTime;
      return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }
    return 'N/A';
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: gradeColor.withValues(alpha: active ? 0.2 : 0.1),
        border: Border.all(
          color: gradeColor.withValues(alpha: active ? 0.5 : 0.3),
          width: 2,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: gradeColor.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Image.asset(
          iconPath,
          width: 30,
          height: 30,
          color: active ? Colors.white : Colors.white54,
          errorBuilder: (context, error, stackTrace) {
            return Text(
              'G$gradeLevel',
              style: TextStyle(
                color: active ? Colors.white : Colors.white54,
                fontSize: 12,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      ),
    );
  }

  dynamic _latestReporteOficial(List<dynamic> reportes) {
    if (reportes.isEmpty) return null;
    reportes.sort((a, b) => b.fechaHora.compareTo(a.fechaHora));
    return reportes.first;
  }

  bool _isToday(DateTime dateTime) {
    final now = DateTime.now();
    return dateTime.year == now.year &&
        dateTime.month == now.month &&
        dateTime.day == now.day;
  }
}
