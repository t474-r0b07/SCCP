import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:math';
import '../controllers/dashboard_controller.dart';
import '../../core/constants/app_constants.dart';
import 'tactical_charts.dart';
import '../../data/models/oficial_model.dart';
import 'detallado_perfil_oficial_dialog.dart';

class AlertasCard extends StatefulWidget {
  const AlertasCard({super.key});

  @override
  State<AlertasCard> createState() => _AlertasCardState();
}

class _AlertasCardState extends State<AlertasCard>
    with TickerProviderStateMixin {
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

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

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    return Obx(() {
      // Force rebuild when acknowledged alerts change.
      controller.alertAcknowledgementVersion.value;
      final alertasDelDia = controller.alertasEpisodiosDelTurno;
      final alertasActivasBase =
          alertasDelDia.where((a) => a['activa'] == true).toList();
      final analytics = controller.buildRealtimeAnalytics();
      final nominalTotal = (analytics['nominal_total'] as num?)?.toInt() ?? 0;
      final activosTotal = (analytics['active_total'] as num?)?.toInt() ?? 0;
      final coveragePct =
          (analytics['coverage_pct'] as num?)?.toDouble() ?? 0.0;
      final riesgoAnalitico =
          (analytics['risk_index'] as num?)?.toDouble() ?? 0.0;

      final faltantesCobertura = max(0, nominalTotal - activosTotal);
      final coberturaCritica = nominalTotal > 0 && activosTotal == 0;
      final coberturaIncompleta =
          nominalTotal > 0 && activosTotal < nominalTotal;
      final requiereAlertaCobertura = coberturaIncompleta;

      final sistemaCoberturaAlerta = <String, dynamic>{
        'id_episodio': 'SYS_COBERTURA_${nominalTotal}_$activosTotal',
        'id_alerta': 'SYS_COBERTURA',
        'id_oficial_ref': 'SISTEMA',
        'id_oficial': 'SISTEMA',
        'nombre_oficial': 'SISTEMA',
        'tipo_alerta': 'SIN_COBERTURA',
        'motivo_alerta':
            'INCUMPLIMIENTO DE COBERTURA: $activosTotal/$nominalTotal activos (${coveragePct.toStringAsFixed(1)}%)',
        'estado_alerta': coberturaCritica ? 'CRITICO' : 'ALERTA',
        'severidad': coberturaCritica ? 3 : 2,
        'activa': true,
        'inicio_alerta': DateTime.now().toIso8601String(),
        'ultimo_reporte_alerta': DateTime.now().toIso8601String(),
        'reportes_en_alerta': faltantesCobertura,
        'duracion_min': 0,
        'nivel_bateria': 100,
        'distancia_metros': 0.0,
        'distancia_metros_max': 0.0,
      };

      final alertasActivas = <Map<String, dynamic>>[
        ...alertasActivasBase,
        if (requiereAlertaCobertura) sistemaCoberturaAlerta,
      ];
      final alertasDelDiaConSistema = <Map<String, dynamic>>[
        ...alertasDelDia,
        if (requiereAlertaCobertura) sistemaCoberturaAlerta,
      ];

      final alertasCriticas = alertasActivas.where((r) {
        final severidad = (r['severidad'] as num?)?.toInt() ?? 1;
        final estado = (r['estado_alerta'] ?? '').toString().toUpperCase();
        return severidad >= 3 || estado == 'CRITICO';
      }).length;
      final gpsInestables = alertasActivasBase.where((r) {
        final tipo = (r['tipo_alerta'] ?? '').toString().toUpperCase();
        final motivo = (r['motivo_alerta'] ?? '').toString().toUpperCase();
        return tipo.contains('GPS') || motivo.contains('GPS');
      }).length;
      final bateriaCritica = alertasActivasBase.where((r) {
        final battery = (r['nivel_bateria'] as num?)?.toDouble() ?? 100;
        final tipo = (r['tipo_alerta'] ?? '').toString().toUpperCase();
        final motivo = (r['motivo_alerta'] ?? '').toString().toUpperCase();
        return battery < 20 ||
            tipo.contains('BATERIA') ||
            motivo.contains('BATERIA');
      }).length;
      final problemasTecnicos = gpsInestables + bateriaCritica;
      final totalProblems = alertasActivas.length;
      final unackedProblems = alertasActivas
          .where((a) => !controller.isAlertEpisodeAcknowledged(a))
          .length;

      var riskScore = riesgoAnalitico;
      if (coberturaCritica) {
        riskScore = 100.0;
      } else if (coberturaIncompleta && coveragePct < 60) {
        riskScore = max(riskScore, 78.0);
      }

      // Real trend for last 5 hours (no synthetic animation when no events)
      final now = DateTime.now();
      final trendBuckets = List<int>.filled(5, 0);
      for (final alerta in alertasActivas) {
        final raw = alerta['ultimo_reporte_alerta'] ??
            alerta['inicio_alerta'] ??
            alerta['fecha_hora'];
        final ts = DateTime.tryParse(raw?.toString() ?? '');
        if (ts == null) continue;
        final ageHours = now.difference(ts).inHours;
        if (ageHours >= 0 && ageHours < trendBuckets.length) {
          trendBuckets[trendBuckets.length - 1 - ageHours]++;
        }
      }
      final trendData = trendBuckets.map((v) => v.toDouble()).toList();

      return LayoutBuilder(builder: (context, constraints) {
        final media = MediaQuery.of(context);
        final mobileViewport =
            media.size.width < 980 || media.size.shortestSide < 700;
        final compact =
            constraints.maxWidth < 420 || constraints.maxHeight < 230;
        final gaugeSize = (constraints.maxHeight * 0.42).clamp(
          mobileViewport ? 74.0 : 68.0,
          mobileViewport ? 118.0 : 96.0,
        );
        final donutSize = (constraints.maxHeight * 0.38).clamp(
          mobileViewport ? 70.0 : 62.0,
          mobileViewport ? 112.0 : 90.0,
        );
        final sparkHeight = compact ? 24.0 : 30.0;
        final cardSpacing = compact ? 6.0 : 10.0;
        final captionSize = compact ? 8.0 : 9.0;
        final sectionTitleSize = compact ? 9.0 : 10.0;
        final counterSize = compact ? 16.0 : 18.0;
        final topBandHeight = (constraints.maxHeight * 0.70).clamp(120.0, 200.0);

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openAlertasDialog(
              context,
              alertasDelDiaConSistema,
              controller,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              decoration: unackedProblems > 0
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.neonPink.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    )
                  : null,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 6.0 : 8.0,
                    horizontal: compact ? 6.0 : 4.0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      SizedBox(
                        height: topBandHeight,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AnimatedBuilder(
                                    animation: _breatheAnimation,
                                    builder: (context, child) {
                                      return Transform.scale(
                                        scale: riskScore > 70
                                            ? _breatheAnimation.value
                                            : 1.0,
                                        child: child,
                                      );
                                    },
                                    child: TacticalRadialGauge(
                                      value: riskScore,
                                      max: 100,
                                      size: gaugeSize,
                                      label: "RIESGO",
                                      color: AppConstants.neonCyan,
                                      showGlow: riskScore > 70,
                                      critical: riskScore > 70,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 2 : 4),
                                  Text(
                                    "RIESGO",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontFamily: 'Orbitron',
                                      fontSize: captionSize,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: cardSpacing),
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: donutSize,
                                    height: donutSize,
                                    child: CustomPaint(
                                      painter: MiniDonutPainter(segments: [
                                        DonutSegment(
                                          value: alertasCriticas.toDouble(),
                                          color: AppConstants.warningRed,
                                          label: "Críticas",
                                        ),
                                        DonutSegment(
                                          value: faltantesCobertura.toDouble(),
                                          color: AppConstants.alertOrange,
                                          label: "Cobertura",
                                        ),
                                        DonutSegment(
                                          value: problemasTecnicos.toDouble(),
                                          color: AppConstants.neonCyan,
                                          label: "Técnicas",
                                        ),
                                      ]),
                                      child: Center(
                                        child: Text(
                                          "$totalProblems",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: sectionTitleSize,
                                            fontFamily: 'Orbitron',
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: compact ? 2 : 4),
                                  Text(
                                    "PROBLEMAS",
                                    style: TextStyle(
                                      color: Colors.white30,
                                      fontFamily: 'Rajdhani',
                                      fontSize: sectionTitleSize,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 2 : 4),
                                  TacticalSparkline(
                                    data: trendData,
                                    lineColor: AppConstants.neonCyan
                                        .withValues(alpha: 0.8),
                                    width: double.infinity,
                                    height: sparkHeight,
                                    showFill: false,
                                    showGrid: false,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: cardSpacing),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _openAlertasDialog(
                                  context,
                                  alertasDelDiaConSistema,
                                  controller,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) {
                                        return Transform.scale(
                                          scale: unackedProblems > 0
                                              ? 1.0 +
                                                  (_pulseAnimation.value * 0.1)
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
                                            color: unackedProblems > 0
                                                ? AppConstants.neonPink
                                                : Colors.white24,
                                            width: 2,
                                          ),
                                          boxShadow: unackedProblems > 0
                                              ? [
                                                  BoxShadow(
                                                    color: AppConstants.neonPink
                                                        .withValues(
                                                            alpha: 0.6),
                                                    blurRadius: 20 +
                                                        (_pulseAnimation.value *
                                                            10),
                                                    spreadRadius: 5 +
                                                        (_pulseAnimation.value *
                                                            5),
                                                  ),
                                                ]
                                              : null,
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "$totalProblems",
                                                style: TextStyle(
                                                  color: unackedProblems > 0
                                                      ? AppConstants.neonPink
                                                      : Colors.white70,
                                                  fontFamily: 'Orbitron',
                                                  fontSize: counterSize,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              Text(
                                                "ALERTAS",
                                                style: TextStyle(
                                                  color: Colors.white30,
                                                  fontSize: captionSize,
                                                  fontFamily: 'Rajdhani',
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    TacticalStatusIndicator(
                                      status: unackedProblems > 0
                                          ? "critical"
                                          : "normal",
                                      color: unackedProblems > 0
                                          ? AppConstants.neonPink
                                          : Colors.white24,
                                      size: compact ? 7 : 8,
                                      pulse: unackedProblems > 0,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: compact ? 5 : 7),
                      _buildAlertTypeBars(
                        criticas: alertasCriticas,
                        cobertura: faltantesCobertura,
                        tecnico: problemasTecnicos,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      });
    });
  }

  void _openAlertasDialog(
    BuildContext context,
    List<Map<String, dynamic>> alertas,
    DashboardController controller,
  ) {
    _showAlertasDialog(
      context,
      alertas,
      controller,
      acknowledgedEpisodeIds: controller.acknowledgedAlertEpisodeIds,
      onAcknowledge: controller.acknowledgeAlertEpisode,
    );
  }

  Widget _buildAlertTypeBars({
    required int criticas,
    required int cobertura,
    required int tecnico,
  }) {
    final maxValue =
        [criticas, cobertura, tecnico].fold<int>(1, (p, e) => e > p ? e : p);
    return Row(
      children: [
        Expanded(
          child: _tinyBar('CRÍT', criticas, maxValue, AppConstants.warningRed),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _tinyBar('COV', cobertura, maxValue, AppConstants.alertOrange),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _tinyBar('TEC', tecnico, maxValue, AppConstants.neonCyan),
        ),
      ],
    );
  }

  Widget _tinyBar(String label, int value, int maxValue, Color color) {
    final ratio = maxValue == 0 ? 0.0 : (value / maxValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label $value',
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontFamily: 'Orbitron',
            fontSize: 9,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 5,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

void _showAlertasDialog(
  BuildContext context,
  List<Map<String, dynamic>> alertas,
  DashboardController controller, {
  required Set<String> acknowledgedEpisodeIds,
  required void Function(Map<String, dynamic>) onAcknowledge,
}) {
  final sortedAlertas = alertas.toList()
    ..sort((a, b) {
      final unreadA = (a['activa'] == true) &&
          !acknowledgedEpisodeIds.contains(_alertEpisodeKey(a));
      final unreadB = (b['activa'] == true) &&
          !acknowledgedEpisodeIds.contains(_alertEpisodeKey(b));
      if (unreadA != unreadB) return unreadB ? 1 : -1;
      final activeA = a['activa'] == true ? 1 : 0;
      final activeB = b['activa'] == true ? 1 : 0;
      if (activeA != activeB) return activeB.compareTo(activeA);
      final sevA = (a['severidad'] as num?)?.toInt() ?? 1;
      final sevB = (b['severidad'] as num?)?.toInt() ?? 1;
      if (sevA != sevB) return sevB.compareTo(sevA);
      final fechaA = _parseAlertTime(
            a['ultimo_reporte_alerta'] ?? a['fecha_hora'],
          ) ??
          DateTime(1970);
      final fechaB = _parseAlertTime(
            b['ultimo_reporte_alerta'] ?? b['fecha_hora'],
          ) ??
          DateTime(1970);
      return fechaB.compareTo(fechaA);
    });

  final total = sortedAlertas.where((a) => a['activa'] == true).length;
  final noLeidas = sortedAlertas.where((a) {
    final active = a['activa'] == true;
    final unread = !acknowledgedEpisodeIds.contains(_alertEpisodeKey(a));
    return active && unread;
  }).length;
  final resueltas = sortedAlertas.where((a) => a['activa'] != true).length;
  final criticas = sortedAlertas.where((a) {
    if (a['activa'] != true) return false;
    final severidad = (a['severidad'] as num?)?.toInt() ?? 1;
    final estado = (a['estado_alerta'] ?? '').toString().toUpperCase();
    return severidad >= 3 || estado == 'CRITICO';
  }).length;
  final faltasReporte = sortedAlertas.where((a) {
    if (a['activa'] != true) return false;
    final tipo = (a['tipo_alerta'] ?? '').toString().toUpperCase();
    final motivo = (a['motivo_alerta'] ?? '').toString().toUpperCase();
    return tipo.contains('FALTA') ||
        motivo.contains('FALTA') ||
        tipo.contains('SIN_COBERTURA') ||
        motivo.contains('INCUMPLIMIENTO DE COBERTURA');
  }).length;
  final tecnicas = sortedAlertas.where((a) {
    if (a['activa'] != true) return false;
    final battery = (a['nivel_bateria'] as num?)?.toDouble() ?? 100;
    final tipo = (a['tipo_alerta'] ?? '').toString().toUpperCase();
    final motivo = (a['motivo_alerta'] ?? '').toString().toUpperCase();
    return battery < 20 ||
        tipo.contains('GPS') ||
        motivo.contains('GPS') ||
        tipo.contains('BATERIA') ||
        motivo.contains('BATERIA');
  }).length;

  Get.dialog(
    Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 550,
        constraints: const BoxConstraints(maxHeight: 650),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppConstants.darkBg.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppConstants.neonPink, width: 1),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ALERTAS AGRUPADAS DEL TURNO",
                style: TextStyle(
                    color: AppConstants.neonPink,
                    fontFamily: 'Orbitron',
                    fontSize: 14,
                    letterSpacing: 2)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: 96,
                  child: _AlertStatChip(
                    label: "ACTIVAS",
                    value: total.toString(),
                    color: Colors.white,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: _AlertStatChip(
                    label: "NUEVAS",
                    value: noLeidas.toString(),
                    color: AppConstants.warningRed,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: _AlertStatChip(
                    label: "RESUELTAS",
                    value: resueltas.toString(),
                    color: Colors.white70,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: _AlertStatChip(
                    label: "CRÍTICAS",
                    value: criticas.toString(),
                    color: AppConstants.warningRed,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: _AlertStatChip(
                    label: "FALTA RPT",
                    value: faltasReporte.toString(),
                    color: AppConstants.warningRed,
                  ),
                ),
                SizedBox(
                  width: 96,
                  child: _AlertStatChip(
                    label: "TÉCNICAS",
                    value: tecnicas.toString(),
                    color: AppConstants.neonCyan,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FALTA RPT = parte obligatorio no registrado en ventana de control.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.86),
                      fontFamily: 'Rajdhani',
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'NUEVAS: $noLeidas  |  ACTIVAS: $total  |  FALTAS PARTE: $faltasReporte',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontFamily: 'Rajdhani',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: noLeidas <= 0
                    ? null
                    : () {
                        for (final alerta in sortedAlertas) {
                          if (alerta['activa'] == true) {
                            onAcknowledge(alerta);
                          }
                        }
                        Get.snackbar(
                          'Alertas',
                          'Alertas activas marcadas como vistas.',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor:
                              AppConstants.neonCyan.withValues(alpha: 0.22),
                          colorText: Colors.white,
                          duration: const Duration(seconds: 2),
                        );
                      },
                icon: const Icon(Icons.visibility_rounded, size: 14),
                label: const Text(
                  'MARCAR TODAS VISTAS',
                  style: TextStyle(
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
              ),
            ),
            const Divider(color: Colors.white12, height: 30),
            Flexible(
              child: sortedAlertas.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Sin alertas registradas hoy",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: sortedAlertas.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white12, height: 16),
                      itemBuilder: (context, index) {
                        final alerta = sortedAlertas[index];
                        final oficialId = (alerta['id_oficial_ref'] ??
                                alerta['id_oficial'] ??
                                '')
                            .toString()
                            .trim();
                        final oficial = controller.oficiales.firstWhereOrNull(
                          (o) => o.idOficial.trim() == oficialId,
                        );

                        return _AlertItem(
                          alerta: alerta,
                          unread: (alerta['activa'] == true) &&
                              !acknowledgedEpisodeIds
                                  .contains(_alertEpisodeKey(alerta)),
                          oficial: oficial,
                          onTap: () {
                            onAcknowledge(alerta);
                            if (oficialId.isNotEmpty) {
                              for (final a in sortedAlertas) {
                                final aId =
                                    (a['id_oficial_ref'] ?? a['id_oficial'] ??
                                            '')
                                        .toString()
                                        .trim();
                                if (a['activa'] == true && aId == oficialId) {
                                  onAcknowledge(a);
                                }
                              }
                            }
                            if (oficial == null) {
                              if (oficialId.toUpperCase() == 'SISTEMA') {
                                _showSystemAlertDetail(alerta);
                                return;
                              }
                              Get.snackbar(
                                "OFICIAL NO DISPONIBLE",
                                "No se encontró el perfil para $oficialId",
                                backgroundColor: AppConstants.warningRed
                                    .withValues(alpha: 0.8),
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
                          },
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

void _showSystemAlertDetail(Map<String, dynamic> alerta) {
  final motivo =
      (alerta['motivo_alerta'] ?? 'ALERTA DE SISTEMA').toString().toUpperCase();
  final estado = (alerta['estado_alerta'] ?? 'ALERTA').toString().toUpperCase();
  final severidad = (alerta['severidad'] as num?)?.toInt() ?? 2;
  final reportesEnAlerta = (alerta['reportes_en_alerta'] as num?)?.toInt() ?? 0;
  final ts =
      _parseAlertTime(alerta['ultimo_reporte_alerta'] ?? alerta['inicio_alerta']);
  final hora = ts == null
      ? '--:--'
      : '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';

  Get.dialog(
    AlertDialog(
      backgroundColor: AppConstants.darkBg.withValues(alpha: 0.95),
      title: const Text(
        'ALERTA DE SISTEMA',
        style: TextStyle(
          color: AppConstants.warningRed,
          fontFamily: 'Orbitron',
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            motivo,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Estado: $estado | Severidad: $severidad',
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Rajdhani',
            ),
          ),
          Text(
            'Faltantes detectados: $reportesEnAlerta | Hora: $hora',
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Rajdhani',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text(
            'ENTENDIDO',
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ],
    ),
  );
}

class _AlertStatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _AlertStatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.9),
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.bold,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }
}

String _alertEpisodeKey(Map<String, dynamic> alerta) {
  final episodio =
      (alerta['id_episodio'] ?? alerta['id_alerta'] ?? '').toString().trim();
  if (episodio.isNotEmpty) return episodio;
  final oficial =
      (alerta['id_oficial_ref'] ?? alerta['id_oficial'] ?? '').toString();
  final tipo = (alerta['tipo_alerta'] ?? '').toString();
  final inicio = (alerta['inicio_alerta'] ??
          alerta['ultimo_reporte_alerta'] ??
          alerta['fecha_hora'] ??
          '')
      .toString();
  return '$oficial|$tipo|$inicio';
}

String _operationalCauseLabel(Map<String, dynamic> alerta) {
  final tipo = (alerta['tipo_alerta'] ?? '').toString().toUpperCase();
  final motivo = (alerta['motivo_alerta'] ?? '').toString().toUpperCase();

  if (tipo.contains('GPS_SOSPECHOSO') ||
      motivo.contains('SALTO') ||
      motivo.contains('IMPOSIBLE')) {
    return 'Se detectó salto improbable de ubicación entre reportes consecutivos.';
  }
  if (tipo.contains('GPS') || motivo.contains('GPS')) {
    return 'GPS no confiable/simulado o sin señal suficiente para validar posición.';
  }
  if (tipo.contains('FALTA') ||
      motivo.contains('FALTA') ||
      tipo.contains('INCUMPLIMIENTO_PARTE')) {
    return 'No se registró parte obligatorio en la ventana y tolerancia definidas.';
  }
  if (tipo.contains('SIN_COBERTURA') || motivo.contains('COBERTURA')) {
    return 'Personal activo por debajo del nominal esperado para el turno.';
  }
  if (tipo.contains('BATERIA') || motivo.contains('BATERIA')) {
    return 'Batería crítica, riesgo de pérdida de telemetría o reportes.';
  }
  if (tipo.contains('RANGO') || motivo.contains('RANGO')) {
    return 'Desplazamiento fuera del rango de control geográfico definido.';
  }
  return 'Evento operativo con impacto de control; revisar detalle y trazabilidad.';
}

class _AlertItem extends StatelessWidget {
  final Map<String, dynamic> alerta;
  final bool unread;
  final Oficial? oficial;
  final VoidCallback onTap;
  const _AlertItem({
    required this.alerta,
    required this.unread,
    required this.oficial,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final estado =
        (alerta['estado_alerta'] ?? 'ALERTA').toString().toUpperCase();
    final isActiva = alerta['activa'] == true;
    final color = !isActiva
        ? Colors.white54
        : estado == 'CRITICO'
            ? AppConstants.warningRed
            : AppConstants.alertOrange;
    final battery =
        ((alerta['nivel_bateria'] as num?)?.toInt() ?? 100).clamp(0, 100);
    final distance = (alerta['distancia_metros_max'] as num?)?.toDouble() ??
        (alerta['distancia_metros'] as num?)?.toDouble() ??
        0;
    final motivo = (alerta['motivo_alerta'] ?? 'ALERTA OPERATIVA')
        .toString()
        .toUpperCase();
    final inicio = _parseAlertTime(
          alerta['inicio_alerta'] ?? alerta['fecha_hora'],
        ) ??
        DateTime.now();
    final ultimo = _parseAlertTime(
          alerta['ultimo_reporte_alerta'] ?? alerta['fecha_hora'],
        ) ??
        inicio;
    final fin = _parseAlertTime(alerta['fin_alerta']);
    final duracionMin = (alerta['duracion_min'] as num?)?.toInt() ??
        (isActiva ? DateTime.now().difference(inicio).inMinutes : 0);
    final idOficial =
        (alerta['id_oficial_ref'] ?? alerta['id_oficial'] ?? '').toString();
    final reportes = (alerta['reportes_en_alerta'] as num?)?.toInt() ?? 1;
    final warnText = [
      if (!isActiva) 'RESUELTA',
      if (estado == 'CRITICO') 'CRÍTICO',
      if (motivo.contains('GPS')) 'GPS OFF',
      if (battery < 20) 'BATERÍA BAJA',
      if (distance > 50) 'FUERA DE RANGO',
    ].join(' • ');
    final explicacion = _operationalCauseLabel(alerta);

    return ListTile(
      onTap: onTap,
      leading: SizedBox(
          width: 36,
          height: 36,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: MiniRadarPainter(color: color)),
              ),
              if (unread)
                const Positioned(
                  right: -1,
                  top: -1,
                  child: Icon(Icons.circle, size: 9, color: Colors.redAccent),
                ),
            ],
          )),
      title: Text(
          oficial != null ? oficial!.nombreOficial : 'OFICIAL $idOficial',
          style: TextStyle(
              color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${inicio.hour.toString().padLeft(2, '0')}:${inicio.minute.toString().padLeft(2, '0')} • ${isActiva ? "ACTIVA" : "RESUELTA"} • $estado',
            style: const TextStyle(color: Colors.white54, fontSize: 10),
          ),
          Text(
            'MOTIVO: $motivo',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Text(
            explicacion,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 10,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            'DISTANCIA: ${distance.toStringAsFixed(1)} m',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Text(
            isActiva
                ? 'DURACIÓN ACTUAL: $duracionMin min • ÚLTIMO ${ultimo.hour.toString().padLeft(2, '0')}:${ultimo.minute.toString().padLeft(2, '0')}'
                : 'DURACIÓN TOTAL: $duracionMin min • FIN ${fin == null ? "--:--" : "${fin.hour.toString().padLeft(2, '0')}:${fin.minute.toString().padLeft(2, '0')}"}',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          Text(
            'REPORTES EN ALERTA: $reportes',
            style: const TextStyle(color: Colors.white70, fontSize: 10),
          ),
          if (warnText.isNotEmpty)
            Text(
              warnText,
              style: const TextStyle(color: Colors.white70, fontSize: 10),
            ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: battery / 100,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(
                battery < 20 ? AppConstants.warningRed : AppConstants.neonCyan,
              ),
            ),
          ),
        ],
      ),
      trailing: Icon(Icons.chevron_right,
          color: unread ? Colors.redAccent : Colors.white24, size: 16),
    );
  }
}

DateTime? _parseAlertTime(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw.toLocal();
  return DateTime.tryParse(raw.toString())?.toLocal();
}

class MiniRadarPainter extends CustomPainter {
  final Color color;
  MiniRadarPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 2, paint);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width / 4, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ThreatGaugePainter extends CustomPainter {
  final int threatLevel;
  ThreatGaugePainter({required this.threatLevel});
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: center, radius: 55), -pi,
        pi * (threatLevel / 100), false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.5;
    for (double i = 0; i < size.width; i += 20) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 0; i < size.height; i += 20) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
