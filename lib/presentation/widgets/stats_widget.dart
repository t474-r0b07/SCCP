import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import 'tactical_charts.dart';

class StatsWidget extends StatelessWidget {
  final Map<String, dynamic> analytics;

  const StatsWidget({
    super.key,
    required this.analytics,
  });

  @override
  Widget build(BuildContext context) {
    final coverage = _num('coverage_pct');
    final cumplimientoReportes = _num('cumplimiento_reportes_pct');
    final risk = _num('risk_index');
    final reportesTotal = _int('reportes_total');
    final reportesEsperados = _int('reportes_esperados');
    final laneAlertas = _lane('alertas');
    final laneInconsistencias = _lane('inconsistencias');
    final laneTelemetria = _lane('telemetria');
    final rpt7d = _listNum('trend_reportes_7d');
    final act7d = _listNum('trend_activos_7d');

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 220;
        final tight = constraints.maxWidth < 300;
        final gap = tight ? 6.0 : 8.0;
        final gaugeSize = constraints.maxWidth < 220
            ? 42.0
            : constraints.maxWidth < 280
                ? 48.0
                : 56.0;
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                compact
                    ? Column(
                        children: [
                          _gaugeBox(
                            code: 'COV',
                            value: coverage,
                            color: AppConstants.neonCyan,
                            extra: '${coverage.toStringAsFixed(0)}%',
                            gaugeSize: gaugeSize,
                          ),
                          SizedBox(height: gap),
                          _gaugeBox(
                            code: 'CUMP',
                            value: cumplimientoReportes,
                            color: AppConstants.neonGreen,
                            extra: '$reportesTotal/$reportesEsperados',
                            gaugeSize: gaugeSize,
                          ),
                          SizedBox(height: gap),
                          _riskBox(risk, gaugeSize: gaugeSize),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _gaugeBox(
                              code: 'COV',
                              value: coverage,
                              color: AppConstants.neonCyan,
                              extra: '${coverage.toStringAsFixed(0)}%',
                              gaugeSize: gaugeSize,
                            ),
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            child: _gaugeBox(
                              code: 'CUMP',
                              value: cumplimientoReportes,
                              color: AppConstants.neonGreen,
                              extra: '$reportesTotal/$reportesEsperados',
                              gaugeSize: gaugeSize,
                            ),
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            child: _riskBox(risk, gaugeSize: gaugeSize),
                          ),
                        ],
                      ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.24),
                    border: Border.all(
                      color: AppConstants.neonCyan.withValues(alpha: 0.22),
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '1 reporte cada 6 min por oficial.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontFamily: 'Rajdhani',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                compact
                    ? Column(
                        children: [
                          _laneCard(
                            title: 'ALERTAS',
                            lane: laneAlertas,
                            accent: AppConstants.neonPink,
                          ),
                          SizedBox(height: gap),
                          _laneCard(
                            title: 'INCONS',
                            lane: laneInconsistencias,
                            accent: AppConstants.alertOrange,
                          ),
                          SizedBox(height: gap),
                          _laneCard(
                            title: 'TELEM',
                            lane: laneTelemetria,
                            accent: AppConstants.neonCyan,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _laneCard(
                              title: 'ALERTAS',
                              lane: laneAlertas,
                              accent: AppConstants.neonPink,
                            ),
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            child: _laneCard(
                              title: 'INCONS',
                              lane: laneInconsistencias,
                              accent: AppConstants.alertOrange,
                            ),
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            child: _laneCard(
                              title: 'TELEM',
                              lane: laneTelemetria,
                              accent: AppConstants.neonCyan,
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 8),
                compact
                    ? Column(
                        children: [
                          _sparkPanel(
                            title: 'RPT_7D',
                            color: Colors.blueAccent,
                            data: rpt7d,
                          ),
                          SizedBox(height: gap),
                          _sparkPanel(
                            title: 'ACT_7D',
                            color: AppConstants.neonGreen,
                            data: act7d,
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: _sparkPanel(
                              title: 'RPT_7D',
                              color: Colors.blueAccent,
                              data: rpt7d,
                            ),
                          ),
                          SizedBox(width: gap),
                          Expanded(
                            child: _sparkPanel(
                              title: 'ACT_7D',
                              color: AppConstants.neonGreen,
                              data: act7d,
                            ),
                          ),
                        ],
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _gaugeBox({
    required String code,
    required double value,
    required Color color,
    required String extra,
    required double gaugeSize,
  }) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            code,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TacticalRadialGauge(
            value: value.clamp(0, 100),
            max: 100,
            size: gaugeSize,
            color: color,
            showGlow: value < 50 || value > 85,
            critical: value < 40,
          ),
          const SizedBox(height: 2),
          Text(
            extra,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontFamily: 'Rajdhani',
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _riskBox(double risk, {required double gaugeSize}) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border:
            Border.all(color: AppConstants.neonPink.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Text(
            'RISK',
            style: TextStyle(
              color: AppConstants.neonPink,
              fontFamily: 'Orbitron',
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TacticalRiskGauge(
            riskLevel: risk.clamp(0, 100),
            size: gaugeSize,
            critical: risk > 70,
          ),
          const SizedBox(height: 2),
          Text(
            risk > 70
                ? 'HIGH'
                : risk > 40
                    ? 'MID'
                    : 'LOW',
            style: TextStyle(
              color: risk > 70
                  ? AppConstants.warningRed
                  : risk > 40
                      ? AppConstants.alertOrange
                      : AppConstants.neonGreen,
              fontFamily: 'Rajdhani',
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _laneCard({
    required String title,
    required Map<String, dynamic> lane,
    required Color accent,
  }) {
    final total = _toInt(lane['total']);
    final nivel = (lane['nivel'] ?? 'NORMAL').toString().toUpperCase();
    final levelColor = _laneLevelColor(nivel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: accent,
              fontFamily: 'Orbitron',
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'NIVEL: $nivel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: levelColor,
              fontFamily: 'Orbitron',
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'TOT $total',
            style: const TextStyle(
              color: Colors.white70,
              fontFamily: 'Rajdhani',
              fontSize: 8,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sparkPanel({
    required String title,
    required Color color,
    required List<double> data,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 7,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          TacticalSparkline(
            data: data,
            lineColor: color,
            width: double.infinity,
            height: 24,
            showFill: true,
            showGrid: false,
          ),
        ],
      ),
    );
  }

  int _int(String key) {
    final value = analytics[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  double _num(String key) {
    final value = analytics[key];
    if (value is num) return value.toDouble();
    return 0.0;
  }

  List<double> _listNum(String key) {
    final raw = analytics[key];
    if (raw is! List) return const <double>[];
    return raw.map((e) => (e as num?)?.toDouble() ?? 0).toList();
  }

  Map<String, dynamic> _lane(String key) {
    final lanes = analytics['lanes'];
    if (lanes is! Map) return const <String, dynamic>{};
    final lane = lanes[key];
    if (lane is! Map) return const <String, dynamic>{};
    return lane.cast<String, dynamic>();
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Color _laneLevelColor(String nivel) {
    switch (nivel) {
      case 'ALTA':
        return AppConstants.warningRed;
      case 'MEDIA':
        return AppConstants.alertOrange;
      case 'BAJA':
        return Colors.yellowAccent;
      default:
        return AppConstants.neonGreen;
    }
  }
}
