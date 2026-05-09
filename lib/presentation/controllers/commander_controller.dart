import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/monitoreo_reporte_model.dart';
import '../../data/models/oficial_model.dart';
import '../../data/repositories/supabase_repository.dart';
import 'dashboard_controller.dart';

enum AnalyticsPeriod { daily, monthly }

class HistoricalRouteCluster {
  final LatLng point;
  final DateTime start;
  final DateTime end;
  final int count;

  const HistoricalRouteCluster({
    required this.point,
    required this.start,
    required this.end,
    required this.count,
  });
}

extension AnalyticsPeriodLabel on AnalyticsPeriod {
  String get label {
    switch (this) {
      case AnalyticsPeriod.daily:
        return 'DIA';
      case AnalyticsPeriod.monthly:
        return 'MES';
    }
  }
}

class CommanderController extends GetxController {
  final SupabaseRepository _repository = SupabaseRepository();

  final historial = <MonitoreoReporte>[].obs;
  final estadisticas = <String, dynamic>{}.obs;
  final informeActual = <String, dynamic>{}.obs;
  final resultadoEspia = <String, dynamic>{}.obs;

  final selectedOficialId = ''.obs;
  final selectedGrupo = 'TODOS'.obs;
  final spyReason = 'VERIFICACION_OPERATIVA'.obs;
  final spyTargetOficialId = ''.obs;
  final selectedAnalyticsPeriod = AnalyticsPeriod.daily.obs;

  final loadingHistorial = false.obs;
  final loadingStats = false.obs;
  final loadingSpyMode = false.obs;
  final loadingAnalytics = false.obs;

  final fromDate = DateTime.now().subtract(const Duration(days: 1)).obs;
  final toDate = DateTime.now().obs;
  final historyDate = DateTime.now().obs;
  final analyticsRangeStart = Rxn<DateTime>();
  final analyticsRangeEnd = Rxn<DateTime>();

  final analyticsReportes = <MonitoreoReporte>[].obs;
  final analyticsInconsistencias = <Map<String, dynamic>>[].obs;
  final analyticsPartesOficiales = <Map<String, dynamic>>[].obs;

  DashboardController get dashboard => Get.find<DashboardController>();

  List<Oficial> get oficiales => dashboard.oficiales.toList();

  List<Oficial> get oficialesFiltrados {
    if (selectedGrupo.value == 'TODOS') {
      return oficiales;
    }
    return oficiales
        .where((o) => (o.grupo ?? '').toUpperCase() == selectedGrupo.value)
        .toList();
  }

  @override
  void onInit() {
    super.onInit();
    if (oficiales.isNotEmpty) {
      selectedOficialId.value = oficiales.first.idOficial;
      spyTargetOficialId.value = oficiales.first.idOficial;
    }
    cargarEstadisticasAvanzadas();
    loadAnalyticsData(period: selectedAnalyticsPeriod.value);
  }

  void bootstrapTargets() {
    if (oficiales.isEmpty) return;
    if (selectedOficialId.value.isEmpty) {
      selectedOficialId.value = oficiales.first.idOficial;
    }
    if (spyTargetOficialId.value.isEmpty) {
      spyTargetOficialId.value = oficiales.first.idOficial;
    }
  }

  Future<void> setAnalyticsPeriod(AnalyticsPeriod period) async {
    if (selectedAnalyticsPeriod.value == period) return;
    selectedAnalyticsPeriod.value = period;
    await loadAnalyticsData(period: period);
  }

  Future<void> loadAnalyticsData({
    required AnalyticsPeriod period,
    DateTime? referenceDate,
  }) async {
    final range = _periodRange(period, referenceDate: referenceDate);
    loadingAnalytics.value = true;
    analyticsRangeStart.value = range.start;
    analyticsRangeEnd.value = range.end;

    try {
      final results = await Future.wait([
        _repository.getReportesEnRango(
          fechaInicio: range.start,
          fechaFin: range.end,
          limit: 12000,
        ),
        _repository.getInconsistenciasEnRango(
          fechaInicio: range.start,
          fechaFin: range.end,
          limit: 8000,
        ),
        _repository.getPartesOficialesEnRango(
          fechaInicio: range.start,
          fechaFin: range.end,
          limit: 12000,
        ),
      ]);

      analyticsReportes.assignAll(results[0] as List<MonitoreoReporte>);
      analyticsInconsistencias
          .assignAll(results[1] as List<Map<String, dynamic>>);
      analyticsPartesOficiales
          .assignAll(results[2] as List<Map<String, dynamic>>);

      fromDate.value = range.start;
      toDate.value = range.end;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [COMMANDER] Error loading analytics data: $e');
      }
      analyticsReportes.clear();
      analyticsInconsistencias.clear();
      analyticsPartesOficiales.clear();
    } finally {
      loadingAnalytics.value = false;
    }
  }

  Future<void> cargarHistorialRecorrido() async {
    bootstrapTargets();
    if (selectedOficialId.value.isEmpty) return;

    final start = DateTime(
      historyDate.value.year,
      historyDate.value.month,
      historyDate.value.day,
      0,
      0,
      0,
    );
    final end = DateTime(
      historyDate.value.year,
      historyDate.value.month,
      historyDate.value.day,
      23,
      59,
      59,
    );

    loadingHistorial.value = true;
    try {
      final data = await _repository.getHistorialRecorrido(
        idOficial: selectedOficialId.value,
        fechaInicio: start,
        fechaFin: end,
      );
      historial.assignAll(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [COMMANDER] Error historial: $e');
      }
      historial.clear();
    } finally {
      loadingHistorial.value = false;
    }
  }

  Future<void> cargarEstadisticasAvanzadas() async {
    loadingStats.value = true;
    try {
      final stats = await _repository.getEstadisticasAvanzadas(
        grupo: selectedGrupo.value == 'TODOS' ? null : selectedGrupo.value,
        idOficial:
            selectedOficialId.value.isEmpty ? null : selectedOficialId.value,
        fechaInicio: fromDate.value,
        fechaFin: toDate.value,
      );
      estadisticas.assignAll(stats);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [COMMANDER] Error estadísticas: $e');
      }
      estadisticas.clear();
    } finally {
      loadingStats.value = false;
    }
  }

  Future<void> generarInformeGlobal() async {
    loadingStats.value = true;
    try {
      final data = await _repository.generarInformeGlobal(
        fechaInicio: fromDate.value,
        fechaFin: toDate.value,
      );
      informeActual.assignAll(data);
    } finally {
      loadingStats.value = false;
    }
  }

  Future<void> generarInformeGrupo() async {
    if (selectedGrupo.value == 'TODOS') return;
    loadingStats.value = true;
    try {
      final data = await _repository.generarInformeGrupo(
        grupo: selectedGrupo.value,
        fechaInicio: fromDate.value,
        fechaFin: toDate.value,
      );
      informeActual.assignAll(data);
    } finally {
      loadingStats.value = false;
    }
  }

  Future<void> generarInformeOficial() async {
    if (selectedOficialId.value.isEmpty) return;
    loadingStats.value = true;
    try {
      final data = await _repository.generarInformeOficial(
        idOficial: selectedOficialId.value,
        fechaInicio: fromDate.value,
        fechaFin: toDate.value,
      );
      informeActual.assignAll(data);
    } finally {
      loadingStats.value = false;
    }
  }

  Future<void> ejecutarModoEspia() async {
    bootstrapTargets();
    if (spyTargetOficialId.value.isEmpty) return;

    loadingSpyMode.value = true;
    try {
      final data = await _repository.ejecutarModoEspia(
        idOficial: spyTargetOficialId.value,
        motivo: spyReason.value,
      );
      resultadoEspia.assignAll(data);
    } finally {
      loadingSpyMode.value = false;
    }
  }

  DateTime get effectiveShiftDate {
    final now = DateTime.now();
    if (now.hour < 8) {
      return DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));
    }
    return DateTime(now.year, now.month, now.day);
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<MonitoreoReporte> get reportesTurnoDelDia {
    final day = effectiveShiftDate;
    final group = dashboard.currentGroup.value.toUpperCase();
    final oficialById = <String, Oficial>{
      for (final o in dashboard.oficiales) o.idOficial: o,
    };
    return dashboard.reportes
        .where((r) => _isSameDay(r.fechaHora, day))
        .where((r) {
      final reportGroup = (r.grupo ?? '').trim().toUpperCase();
      final resolvedGroup = reportGroup.isEmpty
          ? (oficialById[r.idOficialRef]?.grupo ?? '').trim().toUpperCase()
          : reportGroup;

      // Si no es posible resolver el grupo, no se descarta el registro.
      if (resolvedGroup.isEmpty) return true;
      return resolvedGroup == group;
    }).toList();
  }

  Map<String, MonitoreoReporte> get latestByOfficerTurno {
    final map = <String, MonitoreoReporte>{};
    for (final report in reportesTurnoDelDia) {
      final id = report.idOficialRef;
      final current = map[id];
      if (current == null || report.fechaHora.isAfter(current.fechaHora)) {
        map[id] = report;
      }
    }
    return map;
  }

  Map<String, dynamic> buildDetailedStats({
    String? group,
    String? oficialId,
    AnalyticsPeriod? period,
    bool useCurrentShiftDay = true,
  }) {
    final selectedPeriod = period ??
        (useCurrentShiftDay
            ? selectedAnalyticsPeriod.value
            : AnalyticsPeriod.monthly);
    final normalizedGroup = (group ?? '').trim().toUpperCase();
    final normalizedOficial = (oficialId ?? '').trim();

    final range = _periodRange(selectedPeriod);
    final sourceReportes = analyticsReportes.isNotEmpty
        ? analyticsReportes.toList()
        : dashboard.reportes
            .where(
              (r) =>
                  r.fechaHora.isAfter(range.start) &&
                  r.fechaHora.isBefore(range.end),
            )
            .toList();
    final sourceInconsistencias = analyticsInconsistencias.isNotEmpty
        ? analyticsInconsistencias.toList()
        : dashboard.inconsistencias.toList();
    final sourcePartesOficiales = analyticsPartesOficiales.toList();

    final oficialById = <String, Oficial>{
      for (final o in dashboard.oficiales) o.idOficial: o,
    };

    bool matchesOficial(String id) {
      if (normalizedOficial.isEmpty) return true;
      return id == normalizedOficial;
    }

    bool matchesGroup(String id, String? reportGroup) {
      if (normalizedGroup.isEmpty || normalizedGroup == 'TODOS') return true;
      final ownGroup =
          (reportGroup ?? oficialById[id]?.grupo ?? '').toUpperCase();
      return ownGroup == normalizedGroup;
    }

    final filteredReports = sourceReportes.where((r) {
      if (!matchesOficial(r.idOficialRef)) return false;
      if (!matchesGroup(r.idOficialRef, r.grupo)) return false;
      return true;
    }).toList();

    final filteredInconsistencias = sourceInconsistencias.where((inc) {
      final id = (inc['id_oficial'] ?? '').toString();
      final fecha = _parseDate(inc['fecha_deteccion']);
      if (fecha == null) return false;
      if (fecha.isBefore(range.start) || !fecha.isBefore(range.end)) {
        return false;
      }
      if (!matchesOficial(id)) return false;
      if (!matchesGroup(id, null)) return false;
      return true;
    }).toList();

    final filteredPartesOficiales = sourcePartesOficiales.where((p) {
      final id = (p['id_oficial'] ?? '').toString();
      final fecha = _parseDate(p['timestamp']);
      if (fecha == null) return false;
      if (fecha.isBefore(range.start) || !fecha.isBefore(range.end)) {
        return false;
      }
      if (!matchesOficial(id)) return false;
      if (!matchesGroup(id, null)) return false;
      return true;
    }).toList();

    final scopedOficiales = dashboard.oficiales.where((o) {
      if (!matchesOficial(o.idOficial)) return false;
      if (!matchesGroup(o.idOficial, o.grupo)) return false;
      return o.activo;
    }).toList();

    final nominalOficiales = scopedOficiales.length;
    final latestReportByOficial = <String, MonitoreoReporte>{};
    for (final report in filteredReports) {
      final current = latestReportByOficial[report.idOficialRef];
      if (current == null || report.fechaHora.isAfter(current.fechaHora)) {
        latestReportByOficial[report.idOficialRef] = report;
      }
    }
    final latestReports = latestReportByOficial.values.toList();
    final activeOficiales = latestReports.length;
    final coveragePct = nominalOficiales == 0
        ? 0.0
        : (activeOficiales / nominalOficiales) * 100.0;

    final total = filteredReports.length;
    final distValues = latestReports
        .map((r) => (r.distanciaMetros ?? 0).toDouble())
        .where((v) => v >= 0)
        .toList();
    final batteryValues = latestReports
        .map((r) => (r.nivelBateria ?? 0).toDouble())
        .where((v) => v >= 0)
        .toList();

    int within50 = 0;
    int dist50to100 = 0;
    int dist100to200 = 0;
    int dist200Plus = 0;
    int alertAbandono = 0;
    int alertInconsistencia = 0;
    int alertFaltaReporte = 0;

    final activityBuckets = List<int>.filled(range.bucketCount, 0);
    for (final r in latestReports) {
      final d = (r.distanciaMetros ?? 0);
      if (d <= 50) {
        within50++;
      } else if (d <= 100) {
        dist50to100++;
      } else if (d <= 200) {
        dist100to200++;
      } else {
        dist200Plus++;
      }
      if (selectedPeriod == AnalyticsPeriod.daily) {
        final hour = r.fechaHora.hour.clamp(0, 23);
        activityBuckets[hour] += 1;
      } else {
        final dayIndex = (r.fechaHora.day - 1).clamp(0, range.bucketCount - 1);
        activityBuckets[dayIndex] += 1;
      }
    }

    for (final r in latestReports) {
      final estado = r.estadoAlerta.toUpperCase();
      final d = (r.distanciaMetros ?? 0);
      if (d > 50 || estado == 'CRITICO') {
        alertAbandono++;
      } else if (estado == 'ALERTA' || !r.gpsReal) {
        alertInconsistencia++;
      }
    }

    for (final inc in filteredInconsistencias) {
      final tipo = (inc['tipo_inconsistencia'] ?? '').toString().toUpperCase();
      if (tipo == 'FALTA_REPORTE') {
        alertFaltaReporte++;
      } else if (tipo == 'GPS_FALSO' ||
          tipo == 'VOZ_NO_COINCIDE' ||
          tipo == 'UBICACION_FOTO_NO_COINCIDE' ||
          tipo == 'FOTO_UBICACION_NO_COINCIDE' ||
          tipo == 'MANIPULACION_GPS') {
        alertInconsistencia++;
      } else {
        alertInconsistencia++;
      }
    }

    final batteryLow = batteryValues.where((v) => v <= 20).length;
    final batteryMedium = batteryValues.where((v) => v > 20 && v <= 60).length;
    final batteryHigh = batteryValues.where((v) => v > 60).length;
    final complianceGeo =
        activeOficiales == 0 ? 0.0 : (within50 / activeOficiales) * 100.0;

    final dayTrend = <String, int>{};
    for (final r in sourceReportes) {
      if (!matchesOficial(r.idOficialRef)) continue;
      if (!matchesGroup(r.idOficialRef, r.grupo)) continue;
      final local = r.fechaHora;
      final key =
          '${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
      dayTrend[key] = (dayTrend[key] ?? 0) + 1;
    }
    final sortedDays = dayTrend.keys.toList()..sort();
    final trendLast7 = sortedDays
        .skip(sortedDays.length > 7 ? sortedDays.length - 7 : 0)
        .map((k) => dayTrend[k] ?? 0)
        .toList();

    final partesCompletados = filteredPartesOficiales.where((p) {
      final estado = (p['estado'] ?? '').toString().toUpperCase();
      final voz = (p['resultado_voz'] ?? '').toString().toUpperCase();
      return estado != 'RECHAZADO' && voz != 'RECHAZADO';
    }).length;
    final diasPeriodo = selectedPeriod == AnalyticsPeriod.daily
        ? 1
        : range.bucketCount.clamp(1, 31);
    const slotsPorDia = 5;
    final expectedPartes = nominalOficiales * diasPeriodo * slotsPorDia;
    final compliancePartes = expectedPartes == 0
        ? 0.0
        : (partesCompletados / expectedPartes) * 100.0;

    final inconsistenciasAbiertas = filteredInconsistencias.where((inc) {
      final estado = (inc['estado'] ?? '').toString().toUpperCase();
      final resuelta = inc['resuelta'] == true;
      return !resuelta && estado != 'CERRADA';
    }).length;
    final inconsistenciasCerradas =
        filteredInconsistencias.length - inconsistenciasAbiertas;

    return {
      'periodo': selectedPeriod.label,
      'rango_inicio': range.start.toIso8601String(),
      'rango_fin': range.end.toIso8601String(),
      'total_reportes': total,
      'total_oficiales_activos': activeOficiales,
      'total_oficiales_nominales': nominalOficiales,
      'cobertura_pct': coveragePct,
      'cumplimiento_pct': complianceGeo,
      'cumplimiento_partes_pct': compliancePartes,
      'partes_completados': partesCompletados,
      'partes_esperados': expectedPartes,
      'inconsistencias_abiertas': inconsistenciasAbiertas,
      'inconsistencias_cerradas': inconsistenciasCerradas,
      'distancia_promedio': distValues.isEmpty
          ? 0.0
          : distValues.reduce((a, b) => a + b) / distValues.length,
      'distancia_buckets': [within50, dist50to100, dist100to200, dist200Plus],
      'alertas_tipo': [alertAbandono, alertInconsistencia, alertFaltaReporte],
      'bateria_buckets': [batteryLow, batteryMedium, batteryHigh],
      'actividad_horaria': activityBuckets,
      'actividad_labels': range.labels,
      'tendencia_7dias': trendLast7,
    };
  }

  ({DateTime start, DateTime end, int bucketCount, List<String> labels})
      _periodRange(
    AnalyticsPeriod period, {
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    if (period == AnalyticsPeriod.daily) {
      final adjusted =
          now.hour < 8 ? now.subtract(const Duration(days: 1)) : now;
      final day = DateTime(adjusted.year, adjusted.month, adjusted.day);
      final start = DateTime(day.year, day.month, day.day, 8, 0, 0);
      final end = start.add(const Duration(days: 1));
      final labels = List<String>.generate(
        24,
        (i) => i.toString().padLeft(2, '0'),
      );
      return (start: start, end: end, bucketCount: 24, labels: labels);
    }

    final start = DateTime(now.year, now.month, 1, 0, 0, 0);
    final end = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);
    final bucketCount = now.day;
    final labels = List<String>.generate(bucketCount, (i) => '${i + 1}');
    return (
      start: start,
      end: end,
      bucketCount: bucketCount,
      labels: labels,
    );
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  LatLng centerForPoints(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(-16.5, -68.15);
    final lat =
        points.map((e) => e.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((e) => e.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  List<HistoricalRouteCluster> compactHistoricalRoute(
    List<MonitoreoReporte> reports, {
    double thresholdMeters = 50,
  }) {
    final ordered = reports
        .where((r) => r.latitud != null && r.longitud != null)
        .toList()
      ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
    if (ordered.isEmpty) return const <HistoricalRouteCluster>[];

    const distance = Distance();
    final clusters = <HistoricalRouteCluster>[];
    var anchor = LatLng(ordered.first.latitud!, ordered.first.longitud!);
    var start = ordered.first.fechaHora;
    var end = ordered.first.fechaHora;
    var count = 1;

    for (var i = 1; i < ordered.length; i++) {
      final report = ordered[i];
      final point = LatLng(report.latitud!, report.longitud!);
      final drift = distance.as(LengthUnit.Meter, anchor, point);

      if (drift <= thresholdMeters) {
        end = report.fechaHora;
        count++;
        continue;
      }

      clusters.add(
        HistoricalRouteCluster(
          point: anchor,
          start: start,
          end: end,
          count: count,
        ),
      );
      anchor = point;
      start = report.fechaHora;
      end = report.fechaHora;
      count = 1;
    }

    clusters.add(
      HistoricalRouteCluster(
        point: anchor,
        start: start,
        end: end,
        count: count,
      ),
    );
    return clusters;
  }
}
