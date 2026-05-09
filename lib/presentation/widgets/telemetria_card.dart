import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import '../controllers/dashboard_controller.dart';
import '../../core/constants/app_constants.dart';
import 'tactical_charts.dart';

class TelemetriaCard extends GetView<DashboardController> {
  const TelemetriaCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final telemetria = controller.telemetriaActual;
      final analytics = controller.buildRealtimeAnalytics();
      final nominalTotal = (analytics['nominal_total'] as num?)?.toInt() ?? 0;
      final activosTotal = (analytics['active_total'] as num?)?.toInt() ?? 0;
      final lanes = ((analytics['lanes'] as Map?) ?? const <String, dynamic>{})
          .cast<String, dynamic>();
      final laneTelemetria =
          ((lanes['telemetria'] as Map?) ?? const <String, dynamic>{})
              .cast<String, dynamic>();
      final nivelTelemetria =
          (laneTelemetria['nivel'] ?? 'NORMAL').toString().toUpperCase();

      final telemetriaRef = telemetria.isEmpty
          ? controller.reportesOperativos
              .map((r) => {
                    'id_oficial_ref': r.idOficialRef,
                    'estado_alerta': r.estadoAlerta,
                    'nivel_bateria': r.nivelBateria,
                    'gps_real': r.gpsReal,
                    'parte_novedad': r.parteNovedad,
                  })
              .toList()
          : telemetria.toList();
      final dispositivosOnline = activosTotal;
      final totalDispositivos = nominalTotal;
      final gpsOfflineCount =
          telemetriaRef.where((t) => t['gps_real'] != true).length;
      final bateriaBajaCount = telemetriaRef
          .where((t) => ((t['nivel_bateria'] as num?)?.toDouble() ?? 100) < 20)
          .length;
      final criticosSensores = telemetriaRef.where((t) {
        final estado = (t['estado_alerta'] ?? '').toString().toUpperCase();
        final battery = ((t['nivel_bateria'] as num?)?.toDouble() ?? 100);
        final gpsReal = t['gps_real'] == true;
        return estado == 'CRITICO' ||
            estado == 'ALERTA' ||
            battery < 20 ||
            !gpsReal;
      }).length;
      final criticosCount = criticosSensores +
          ((totalDispositivos > 0 && dispositivosOnline == 0) ? 1 : 0);

      // Get battery data for strip chart
      final batteryLevels = telemetriaRef
          .where((t) => t['nivel_bateria'] != null)
          .take(8)
          .map((t) => BatteryLevel(
                id: (t['id_oficial_ref'] ?? t['id_oficial'] ?? 'DEV')
                    .toString(),
                level: (((t['nivel_bateria'] as num?)?.toDouble() ?? 0) / 100)
                    .clamp(0.0, 1.0),
                charging: _isChargingFromRow(t),
              ))
          .toList();
      final fallbackBatteryCount =
          totalDispositivos <= 0 ? 1 : totalDispositivos.clamp(1, 8);
      final batteryLevelsRender = batteryLevels.isNotEmpty
          ? batteryLevels
          : List.generate(
              fallbackBatteryCount,
              (i) => BatteryLevel(
                id: "ND${i + 1}",
                level: 0.0,
                charging: false,
              ),
            );

      // Signal data derived from latest telemetry in Supabase
      final source = telemetriaRef.take(20).toList();
      final signalData = source.isEmpty
          ? List<double>.filled(20, 0.0)
          : source.map((t) {
              final battery = ((t['nivel_bateria'] as num?)?.toDouble() ?? 50);
              final gpsBoost = t['gps_real'] == true ? 8.0 : -12.0;
              final estado =
                  (t['estado_alerta'] ?? '').toString().toUpperCase();
              final alertPenalty =
                  (estado == 'CRITICO' || estado == 'ALERTA') ? -10.0 : 0.0;
              return (battery + gpsBoost + alertPenalty).clamp(0.0, 100.0);
            }).toList();

      return LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 340 || constraints.maxHeight < 190;
          final moduleGap = compact ? 8.0 : 12.0;
          final moduleWidth =
              ((constraints.maxWidth - (moduleGap * 2) - 16) / 3)
                  .clamp(70.0, 120.0);
          final vizHeight = (constraints.maxHeight * 0.34).clamp(48.0, 72.0);
          final statusHeight = (constraints.maxHeight * 0.42).clamp(60.0, 90.0);
          final labelSize = compact ? 8.0 : 9.0;
          final valueSize = compact ? 12.0 : 14.0;
          final metaSize = compact ? 7.0 : 8.0;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showTelemetriaDialog(context),
              highlightColor: AppConstants.neonCyan.withValues(alpha: 0.1),
              splashColor: AppConstants.neonCyan.withValues(alpha: 0.2),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  compact ? 6 : 8,
                  compact ? 6 : 8,
                  compact ? 6 : 8,
                  compact ? 4 : 6,
                ),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: moduleWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TacticalBatteryStrip(
                              batteries: batteryLevelsRender,
                              width: moduleWidth - 4,
                              height: vizHeight,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "BATERÍAS",
                              style: TextStyle(
                                color: Colors.white30,
                                fontFamily: 'Rajdhani',
                                fontSize: labelSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: moduleGap),
                      SizedBox(
                        width: moduleWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TacticalWaveform(
                              data: signalData,
                              color: AppConstants.neonCyan,
                              width: moduleWidth - 4,
                              height: vizHeight,
                              showGrid: true,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "SEÑAL",
                              style: TextStyle(
                                color: Colors.white30,
                                fontFamily: 'Rajdhani',
                                fontSize: labelSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: moduleGap),
                      SizedBox(
                        width: moduleWidth,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: moduleWidth,
                              height: statusHeight,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: criticosCount > 0
                                      ? AppConstants.warningRed
                                      : dispositivosOnline > 0
                                          ? AppConstants.neonCyan
                                          : AppConstants.warningRed,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      "$dispositivosOnline/$totalDispositivos",
                                      style: TextStyle(
                                        color: criticosCount > 0
                                            ? AppConstants.warningRed
                                            : dispositivosOnline > 0
                                                ? AppConstants.neonCyan
                                                : AppConstants.warningRed,
                                        fontFamily: 'Orbitron',
                                        fontSize: valueSize,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      "CONECTADOS",
                                      style: TextStyle(
                                        color: criticosCount > 0
                                            ? AppConstants.warningRed
                                            : dispositivosOnline > 0
                                                ? AppConstants.neonCyan
                                                : AppConstants.warningRed,
                                        fontSize: metaSize,
                                        fontFamily: 'Rajdhani',
                                      ),
                                    ),
                                    Text(
                                      "GPS:$gpsOfflineCount BAT:$bateriaBajaCount $nivelTelemetria",
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.72),
                                        fontSize: metaSize,
                                        fontFamily: 'Rajdhani',
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            TacticalStatusIndicator(
                              status:
                                  dispositivosOnline > 0 ? "online" : "offline",
                              color: dispositivosOnline > 0
                                  ? AppConstants.neonCyan
                                  : AppConstants.warningRed,
                              size: compact ? 7 : 8,
                              pulse: dispositivosOnline == 0,
                            ),
                          ],
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

  void _showTelemetriaDialog(BuildContext context) {
    final analytics = controller.buildRealtimeAnalytics();
    final currentGroupNormalized = controller.currentGroup.value.toUpperCase();
    final nominalTotal = (analytics['nominal_total'] as num?)?.toInt() ?? 0;
    final activosTotal = (analytics['active_total'] as num?)?.toInt() ?? 0;
    final lanes = ((analytics['lanes'] as Map?) ?? const <String, dynamic>{})
        .cast<String, dynamic>();
    final laneTelemetria =
        ((lanes['telemetria'] as Map?) ?? const <String, dynamic>{})
            .cast<String, dynamic>();
    final nivelTelemetria =
        (laneTelemetria['nivel'] ?? 'NORMAL').toString().toUpperCase();

    final groupByOficial = <String, String>{
      for (final o in controller.oficiales)
        o.idOficial.trim(): (o.grupo ?? '').toUpperCase(),
    };
    final teleRows = controller.telemetriaActual.where((r) {
      final id =
          (r['id_oficial_ref'] ?? r['id_oficial'] ?? '').toString().trim();
      final group = (r['grupo'] ?? groupByOficial[id] ?? '')
          .toString()
          .toUpperCase()
          .trim();
      return group == currentGroupNormalized;
    }).toList();
    final gpsOffline = teleRows.where((r) => r['gps_real'] != true).length;
    final bateriaBaja = teleRows
        .where((r) => ((r['nivel_bateria'] as num?)?.toDouble() ?? 100) < 20)
        .length;
    final criticos = teleRows.where((r) {
      final estado = (r['estado_alerta'] ?? '').toString().toUpperCase();
      final battery = ((r['nivel_bateria'] as num?)?.toDouble() ?? 100);
      final gpsReal = r['gps_real'] == true;
      return estado == 'CRITICO' ||
          estado == 'ALERTA' ||
          battery < 20 ||
          !gpsReal;
    }).length;
    final signalRows = teleRows
        .where((r) => r['nivel_bateria'] != null || r['estado_alerta'] != null)
        .toList();
    final signalSource = signalRows.isEmpty
        ? controller.reportesOperativos
            .take(24)
            .map(
              (r) => {
                'nivel_bateria': r.nivelBateria,
                'gps_real': r.gpsReal,
                'estado_alerta': r.estadoAlerta,
              },
            )
            .toList()
        : signalRows.take(24).toList();
    final signalOrdered = signalSource.reversed.toList();

    List<FlSpot> toSpots(List<double> values) {
      final safe = values.isEmpty ? const [0.0] : values;
      return List.generate(
        safe.length,
        (i) => FlSpot(i.toDouble(), safe[i]),
      );
    }

    final batterySignal = toSpots(
      signalOrdered
          .map(
            (r) => ((r['nivel_bateria'] as num?)?.toDouble() ?? 0.0)
                .clamp(0.0, 100.0),
          )
          .toList(),
    );
    final gpsSignal = toSpots(
      signalOrdered.map((r) => r['gps_real'] == true ? 100.0 : 0.0).toList(),
    );
    final estadoSignal = toSpots(
      signalOrdered.map((r) {
        final estado = (r['estado_alerta'] ?? '').toString().toUpperCase();
        if (estado == 'CRITICO') return 100.0;
        if (estado == 'ALERTA') return 60.0;
        return 15.0;
      }).toList(),
    );

    final sampleSize = teleRows.length;
    final gpsOkCount = teleRows.where((r) => r['gps_real'] == true).length;
    final batteryOkCount = teleRows
        .where((r) => ((r['nivel_bateria'] as num?)?.toDouble() ?? 0) >= 40)
        .length;
    final estadoNormalCount = teleRows.where((r) {
      final estado = (r['estado_alerta'] ?? '').toString().toUpperCase();
      return estado == 'NORMAL' || estado == 'OK';
    }).length;
    final gpsOkPct = sampleSize == 0 ? 0.0 : (gpsOkCount / sampleSize) * 100.0;
    final batteryOkPct =
        sampleSize == 0 ? 0.0 : (batteryOkCount / sampleSize) * 100.0;
    final estadoNormalPct =
        sampleSize == 0 ? 0.0 : (estadoNormalCount / sampleSize) * 100.0;
    final enlaceCoberturaPct = nominalTotal == 0
        ? 0.0
        : ((activosTotal / nominalTotal) * 100).clamp(0.0, 100.0);
    final teleRowsSorted = [
      ...teleRows
    ]..sort((a, b) => _telemetryTimestamp(b).compareTo(_telemetryTimestamp(a)));
    final latestByOficial = <String, Map<String, dynamic>>{};
    for (final row in teleRowsSorted) {
      final id =
          (row['id_oficial_ref'] ?? row['id_oficial'] ?? '').toString().trim();
      if (id.isEmpty || latestByOficial.containsKey(id)) continue;
      latestByOficial[id] = row;
    }
    final oficialesTurno = controller.oficiales
        .where((o) => (o.grupo ?? '').toUpperCase() == currentGroupNormalized)
        .toList();
    final selectorItems = oficialesTurno.map((o) {
      final id = o.idOficial.trim();
      final row = latestByOficial[id];
      final priority = _telemetryPriority(row);
      return <String, dynamic>{
        'id': id,
        'nombre': o.nombreOficial,
        'row': row,
        'priority': priority,
        'color': _telemetryPriorityColor(priority),
      };
    }).toList();
    if (selectorItems.isEmpty && latestByOficial.isNotEmpty) {
      for (final entry in latestByOficial.entries) {
        final priority = _telemetryPriority(entry.value);
        selectorItems.add({
          'id': entry.key,
          'nombre': entry.value['nombre_oficial']?.toString() ?? entry.key,
          'row': entry.value,
          'priority': priority,
          'color': _telemetryPriorityColor(priority),
        });
      }
    }
    selectorItems.sort((a, b) {
      final pA = (a['priority'] as int?) ?? 0;
      final pB = (b['priority'] as int?) ?? 0;
      final byPriority = pB.compareTo(pA);
      if (byPriority != 0) return byPriority;
      final tA = _telemetryTimestamp(a['row'] as Map<String, dynamic>?);
      final tB = _telemetryTimestamp(b['row'] as Map<String, dynamic>?);
      final byTime = tB.compareTo(tA);
      if (byTime != 0) return byTime;
      return (a['id'] as String).compareTo(b['id'] as String);
    });
    final selectorById = <String, Map<String, dynamic>>{
      for (final item in selectorItems) (item['id'] as String): item,
    };
    final selectedOficialId =
        (selectorItems.isNotEmpty ? selectorItems.first['id'] as String : '')
            .obs;

    Map<String, dynamic>? selectedTelemetryRow() {
      final id = selectedOficialId.value;
      final selected = selectorById[id];
      if (selected == null) return null;
      return selected['row'] as Map<String, dynamic>?;
    }

    final screenSize = MediaQuery.of(context).size;
    final mobileDialog =
        screenSize.width < 980 || screenSize.shortestSide < 700;
    final dialogWidth =
        (mobileDialog ? screenSize.width * 0.97 : 800.0).clamp(280.0, 980.0);
    final dialogHeight = (mobileDialog ? screenSize.height * 0.94 : 500.0)
        .clamp(460.0, screenSize.height * 0.98);
    final compactDialog = mobileDialog || dialogWidth < 760;
    Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: dialogWidth,
          height: dialogHeight,
          decoration: BoxDecoration(
            color: AppConstants.darkBg.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppConstants.neonCyan, width: 1),
          ),
          child: Stack(
            children: [
              // Liquid Crystal Effect Background
              Positioned.fill(
                  child: CustomPaint(painter: LiquidCrystalPainter())),
              // Subtle Scanlines
              Positioned.fill(child: CustomPaint(painter: ScanlinesPainter())),

              Padding(
                padding: EdgeInsets.all(compactDialog ? 12 : 20),
                child: Column(
                  children: [
                    // Header row with fixed summary panel (left) and title (right)
                    compactDialog
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _telemetrySummaryPanel(
                                activosTotal: activosTotal,
                                nominalTotal: nominalTotal,
                                gpsOffline: gpsOffline,
                                bateriaBaja: bateriaBaja,
                                criticos: criticos,
                                nivelTelemetria: nivelTelemetria,
                                fullWidth: true,
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          "[ HARDWARE_CORE ]",
                                          style: TextStyle(
                                            color: AppConstants.neonCyan,
                                            fontSize: 10,
                                            fontFamily: 'Orbitron',
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          "TELEMETRÍA DE DISPOSITIVOS",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Orbitron',
                                            fontSize: 14,
                                            letterSpacing: 1.2,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.white24, size: 18),
                                    onPressed: () => Get.back(),
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _telemetrySummaryPanel(
                                activosTotal: activosTotal,
                                nominalTotal: nominalTotal,
                                gpsOffline: gpsOffline,
                                bateriaBaja: bateriaBaja,
                                criticos: criticos,
                                nivelTelemetria: nivelTelemetria,
                                fullWidth: false,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: const [
                                      Text(
                                        "[ HARDWARE_CORE ]",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: AppConstants.neonCyan,
                                          fontSize: 10,
                                          fontFamily: 'Orbitron',
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "TELEMETRÍA",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Orbitron',
                                          fontSize: 14,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        "DE DISPOSITIVOS",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Orbitron',
                                          fontSize: 14,
                                          letterSpacing: 1.2,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close,
                                    color: Colors.white24, size: 18),
                                onPressed: () => Get.back(),
                              ),
                            ],
                          ),
                    const Divider(
                        color: AppConstants.neonCyan,
                        thickness: 0.5,
                        height: 30),
                    const SizedBox(height: 4),

                    // Hardware Panels
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: compactDialog ? 980 : (dialogWidth - 40),
                          child: Row(
                            children: [
                              // Battery Cell Panel
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text("OFICIAL TELEMETRÍA",
                                        style: TextStyle(
                                            color: AppConstants.neonCyan,
                                            fontSize: 10,
                                            fontFamily: 'Orbitron')),
                                    const SizedBox(height: 4),
                                    if (selectorItems.isNotEmpty)
                                      Obx(() {
                                        final selectedId =
                                            selectedOficialId.value;
                                        final selected =
                                            selectorById[selectedId] ??
                                                selectorItems.first;
                                        final selectedColor =
                                            (selected['color'] as Color?) ??
                                                Colors.white70;
                                        return Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black
                                                .withValues(alpha: 0.22),
                                            border: Border.all(
                                              color: selectedColor.withValues(
                                                  alpha: 0.55),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<String>(
                                              isExpanded: true,
                                              value: selectedId,
                                              dropdownColor:
                                                  const Color(0xFF041729),
                                              iconEnabledColor: selectedColor,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Rajdhani',
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              items: selectorItems.map((item) {
                                                final id = item['id'] as String;
                                                final priority =
                                                    (item['priority']
                                                            as int?) ??
                                                        0;
                                                final color =
                                                    (item['color'] as Color?) ??
                                                        Colors.white70;
                                                return DropdownMenuItem<String>(
                                                  value: id,
                                                  child: Text(
                                                    '$id [${_telemetryPriorityLabel(priority)}]',
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      color: color,
                                                      fontFamily: 'Rajdhani',
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                );
                                              }).toList(),
                                              onChanged: (value) {
                                                if (value == null ||
                                                    value.isEmpty) {
                                                  return;
                                                }
                                                selectedOficialId.value = value;
                                              },
                                            ),
                                          ),
                                        );
                                      })
                                    else
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.black
                                              .withValues(alpha: 0.22),
                                          border: Border.all(
                                            color: Colors.white
                                                .withValues(alpha: 0.2),
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Sin telemetría del grupo',
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.78),
                                            fontFamily: 'Rajdhani',
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    const SizedBox(height: 10),
                                    const Text("ENERGY CELL",
                                        style: TextStyle(
                                            color: Colors.greenAccent,
                                            fontSize: 10,
                                            fontFamily: 'Orbitron')),
                                    const SizedBox(height: 2),
                                    Text(
                                      "Batería del último reporte",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 9,
                                        fontFamily: 'Rajdhani',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Obx(() {
                                      final row = selectedTelemetryRow();
                                      final selectedId =
                                          selectedOficialId.value.trim();
                                      final level =
                                          (((row?['nivel_bateria'] as num?)
                                                          ?.toDouble() ??
                                                      0) /
                                                  100)
                                              .clamp(0.0, 1.0);
                                      final pct =
                                          row == null ? -1.0 : (level * 100);
                                      final label =
                                          pct < 0 ? 'N/D' : '${pct.round()}%';
                                      final bandLabel = _energyBandLabel(pct);
                                      final bandColor = _energyBandColor(pct);
                                      final trend = _batteryTrendForOficial(
                                        selectedId,
                                      );
                                      return Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Flexible(
                                              fit: FlexFit.tight,
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    flex: 2,
                                                    child: CustomPaint(
                                                      painter:
                                                          BatteryCellPainter(
                                                        level: level,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(
                                                      width: compactDialog
                                                          ? 6
                                                          : 10),
                                                  Expanded(
                                                    flex: 3,
                                                    child: Column(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          label,
                                                          style: TextStyle(
                                                            color: bandColor,
                                                            fontFamily:
                                                                'Orbitron',
                                                            fontSize:
                                                                compactDialog
                                                                    ? 20
                                                                    : 24,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: compactDialog
                                                              ? 4
                                                              : 6,
                                                        ),
                                                        ClipRRect(
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                            6,
                                                          ),
                                                          child:
                                                              LinearProgressIndicator(
                                                            minHeight:
                                                                compactDialog
                                                                    ? 8
                                                                    : 10,
                                                            value: pct < 0
                                                                ? 0
                                                                : (pct / 100)
                                                                    .clamp(
                                                                    0.0,
                                                                    1.0,
                                                                  ),
                                                            backgroundColor:
                                                                Colors.white
                                                                    .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                            valueColor:
                                                                AlwaysStoppedAnimation<
                                                                        Color>(
                                                                    bandColor),
                                                          ),
                                                        ),
                                                        SizedBox(
                                                          height: compactDialog
                                                              ? 6
                                                              : 8,
                                                        ),
                                                        Container(
                                                          padding: EdgeInsets
                                                              .symmetric(
                                                            horizontal:
                                                                compactDialog
                                                                    ? 6
                                                                    : 8,
                                                            vertical:
                                                                compactDialog
                                                                    ? 3
                                                                    : 4,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: bandColor
                                                                .withValues(
                                                              alpha: 0.2,
                                                            ),
                                                            border: Border.all(
                                                              color: bandColor,
                                                            ),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        6),
                                                          ),
                                                          child: Text(
                                                            'ESTADO: $bandLabel',
                                                            style: TextStyle(
                                                              color: bandColor,
                                                              fontFamily:
                                                                  'Orbitron',
                                                              fontSize:
                                                                  compactDialog
                                                                      ? 8
                                                                      : 9,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (trend.isNotEmpty) ...[
                                              SizedBox(
                                                  height:
                                                      compactDialog ? 6 : 8),
                                              TacticalSparkline(
                                                data: trend,
                                                lineColor: bandColor,
                                                width: double.infinity,
                                                height: compactDialog ? 34 : 38,
                                                showFill: true,
                                                showGrid: false,
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'TENDENCIA BATERÍA (últimos reportes)',
                                                style: TextStyle(
                                                  color:
                                                      Colors.white.withValues(
                                                    alpha: 0.72,
                                                  ),
                                                  fontFamily: 'Rajdhani',
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),

                              SizedBox(width: compactDialog ? 12 : 20),

                              // Spectrum Radar Panel
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text("SPECTRUM RADAR",
                                        style: TextStyle(
                                            color: AppConstants.neonCyan,
                                            fontSize: 10,
                                            fontFamily: 'Orbitron')),
                                    const SizedBox(height: 4),
                                    Text(
                                      "GPS/Batería/Estado/Cobertura",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 9,
                                        fontFamily: 'Rajdhani',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: _buildSpectrumBars(
                                        gpsOkPct: gpsOkPct,
                                        batteryOkPct: batteryOkPct,
                                        estadoNormalPct: estadoNormalPct,
                                        coberturaPct: enlaceCoberturaPct,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              SizedBox(width: compactDialog ? 12 : 20),

                              // Technical Data Panel
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("CORE DIAGNOSTICS",
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontFamily: 'Orbitron')),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Estado técnico del equipo reportante",
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 9,
                                        fontFamily: 'Rajdhani',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 15),
                                    Obx(() {
                                      final selectedId =
                                          selectedOficialId.value;
                                      final selected =
                                          selectorById[selectedId] ?? const {};
                                      final row = selectedTelemetryRow();
                                      final priority = _telemetryPriority(row);
                                      final priorityColor =
                                          _telemetryPriorityColor(priority);
                                      final pingTs = _telemetryTimestamp(row);
                                      final pingLabel = pingTs
                                                  .millisecondsSinceEpoch <=
                                              0
                                          ? 'SIN REPORTE'
                                          : "${pingTs.hour.toString().padLeft(2, '0')}:${pingTs.minute.toString().padLeft(2, '0')}:${pingTs.second.toString().padLeft(2, '0')}";
                                      final nombre = (selected['nombre'] ?? '')
                                          .toString()
                                          .trim();
                                      final oficialLabel = selectedId.isEmpty
                                          ? 'N/D'
                                          : nombre.isEmpty
                                              ? selectedId
                                              : '$selectedId - $nombre';
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: priorityColor.withValues(
                                                alpha: 0.2,
                                              ),
                                              border: Border.all(
                                                color: priorityColor,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'PRIORIDAD: ${_telemetryPriorityLabel(priority)}',
                                              style: TextStyle(
                                                color: priorityColor,
                                                fontFamily: 'Orbitron',
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          _buildTechData(
                                              "Oficial", oficialLabel),
                                          _buildTechData(
                                            "Dispositivo",
                                            (row?['imei'] ?? 'SIN REPORTE')
                                                .toString(),
                                          ),
                                          _buildTechData(
                                              "Último ping", pingLabel),
                                          _buildTechData(
                                            "Batería",
                                            row == null
                                                ? "SIN REPORTE"
                                                : "${((row['nivel_bateria'] as num?)?.toInt() ?? 0)}%",
                                          ),
                                          _buildTechData(
                                            "Carga",
                                            row == null
                                                ? "SIN REPORTE"
                                                : (_isChargingFromRow(row)
                                                    ? "CARGANDO"
                                                    : "DESCARGANDO"),
                                          ),
                                          _buildTechData(
                                            "GPS",
                                            row == null
                                                ? "SIN REPORTE"
                                                : ((row['gps_real'] == true)
                                                    ? "CONFIABLE"
                                                    : "OFFLINE"),
                                          ),
                                          _buildTechData(
                                            "Estado",
                                            (row?['estado_alerta'] ??
                                                    'SIN REPORTE')
                                                .toString(),
                                          ),
                                        ],
                                      );
                                    }),
                                  ],
                                ),
                              ),

                              const SizedBox(width: 20),

                              // Multi-Line Signals Panel
                              Expanded(
                                child: Column(
                                  children: [
                                    const Text("MULTI-LINE SIGNALS",
                                        style: TextStyle(
                                            color: AppConstants.neonCyan,
                                            fontSize: 10,
                                            fontFamily: 'Orbitron')),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Tendencia reciente por señal",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color:
                                            Colors.white.withValues(alpha: 0.7),
                                        fontSize: 9,
                                        fontFamily: 'Rajdhani',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Expanded(
                                      child: LineChart(
                                        LineChartData(
                                          gridData: FlGridData(
                                            show: true,
                                            drawVerticalLine: false,
                                            getDrawingHorizontalLine: (value) =>
                                                FlLine(
                                              color: Colors.white
                                                  .withValues(alpha: 0.1),
                                              strokeWidth: 1,
                                            ),
                                          ),
                                          titlesData: FlTitlesData(show: false),
                                          borderData: FlBorderData(show: false),
                                          lineBarsData: [
                                            LineChartBarData(
                                              spots: batterySignal,
                                              isCurved: true,
                                              color: const Color(0xFFFF4DD2),
                                              barWidth: 3,
                                              dotData: FlDotData(show: true),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                color: const Color(0xFFFF4DD2)
                                                    .withValues(alpha: 0.2),
                                              ),
                                            ),
                                            LineChartBarData(
                                              spots: gpsSignal,
                                              isCurved: false,
                                              color: const Color(0xFF00E5FF),
                                              barWidth: 3,
                                              dotData: FlDotData(show: true),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                color: const Color(0xFF00E5FF)
                                                    .withValues(alpha: 0.2),
                                              ),
                                            ),
                                            LineChartBarData(
                                              spots: estadoSignal,
                                              isCurved: true,
                                              color: const Color(0xFFFFA000),
                                              barWidth: 2,
                                              dotData: FlDotData(show: false),
                                              belowBarData: BarAreaData(
                                                show: true,
                                                color: const Color(0xFFFFA000)
                                                    .withValues(alpha: 0.2),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 4,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        _buildSignalLegend(
                                          label: "BATERÍA",
                                          color: const Color(0xFFFF4DD2),
                                        ),
                                        _buildSignalLegend(
                                          label: "GPS",
                                          color: const Color(0xFF00E5FF),
                                        ),
                                        _buildSignalLegend(
                                          label: "ALERTA",
                                          color: const Color(0xFFFFA000),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DateTime _telemetryTimestamp(Map<String, dynamic>? row) {
    if (row == null) return DateTime.fromMillisecondsSinceEpoch(0);
    final raw = row['fecha_hora'];
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse(raw.toString())?.toLocal() ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  int _telemetryPriority(Map<String, dynamic>? row) {
    if (row == null) return 0;
    final estado = (row['estado_alerta'] ?? '').toString().toUpperCase();
    final battery = ((row['nivel_bateria'] as num?)?.toDouble() ?? 100);
    final gpsReal = row['gps_real'] == true;
    if (estado == 'CRITICO' || battery < 20 || !gpsReal) return 3;
    if (estado == 'ALERTA' || battery < 35) return 2;
    if (battery < 50) return 1;
    return 0;
  }

  Color _telemetryPriorityColor(int priority) {
    if (priority >= 3) return AppConstants.warningRed;
    if (priority == 2) return AppConstants.alertOrange;
    if (priority == 1) return Colors.yellowAccent;
    return AppConstants.neonGreen;
  }

  String _telemetryPriorityLabel(int priority) {
    if (priority >= 3) return 'CRÍTICA';
    if (priority == 2) return 'ALTA';
    if (priority == 1) return 'MEDIA';
    return 'NORMAL';
  }

  String _energyBandLabel(double pct) {
    if (pct < 0) return 'SIN REPORTE';
    if (pct < 20) return 'CRÍTICA';
    if (pct < 35) return 'BAJA';
    if (pct < 60) return 'MEDIA';
    return 'ÓPTIMA';
  }

  Color _energyBandColor(double pct) {
    if (pct < 0) return Colors.white54;
    if (pct < 20) return AppConstants.warningRed;
    if (pct < 35) return AppConstants.alertOrange;
    if (pct < 60) return Colors.yellowAccent;
    return AppConstants.neonGreen;
  }

  bool _isChargingFromRow(Map<String, dynamic> row) {
    final explicit = row['cargando_bateria'] ?? row['is_charging'];
    if (explicit is bool) return explicit;
    final explicitText = (explicit ?? '').toString().trim().toLowerCase();
    if (explicitText == 'true' ||
        explicitText == '1' ||
        explicitText == 'si' ||
        explicitText == 'yes' ||
        explicitText == 'charging') {
      return true;
    }

    final telemetryNote =
        (row['parte_novedad'] ?? '').toString().trim().toUpperCase();
    if (telemetryNote.contains('POWER_CHARGING')) return true;
    if (telemetryNote.contains('POWER_DISCHARGING')) return false;
    return false;
  }

  List<double> _batteryTrendForOficial(String oficialId) {
    if (oficialId.isEmpty) return const <double>[];
    final trend = controller.reportesOperativos
        .where((r) => r.idOficialRef.trim() == oficialId)
        .where((r) => r.nivelBateria != null)
        .take(12)
        .map((r) => (r.nivelBateria ?? 0).toDouble().clamp(0.0, 100.0))
        .toList()
        .reversed
        .toList();
    return trend;
  }

  Widget _telemetrySummaryPanel({
    required int activosTotal,
    required int nominalTotal,
    required int gpsOffline,
    required int bateriaBaja,
    required int criticos,
    required String nivelTelemetria,
    required bool fullWidth,
  }) {
    return Container(
      width: fullWidth ? double.infinity : 230,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF031D2D),
        border: Border.all(
          color: AppConstants.neonCyan.withValues(alpha: 0.45),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "RESUMEN TELEMETRÍA",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          _buildStatusLine(
            "Dispositivos vigilados",
            "$activosTotal / $nominalTotal",
            AppConstants.neonCyan,
          ),
          _buildStatusLine(
            "GPS offline",
            "$gpsOffline",
            gpsOffline > 0 ? Colors.redAccent : Colors.white54,
          ),
          _buildStatusLine(
            "Batería <20%",
            "$bateriaBaja",
            bateriaBaja > 0 ? Colors.orangeAccent : Colors.white54,
          ),
          _buildStatusLine(
            "Críticos telemetría",
            "$criticos",
            criticos > 0 ? AppConstants.warningRed : Colors.white54,
          ),
          _buildStatusLine(
            "Nivel consolidado",
            nivelTelemetria,
            nivelTelemetria == 'ALTA'
                ? AppConstants.warningRed
                : nivelTelemetria == 'MEDIA'
                    ? AppConstants.alertOrange
                    : AppConstants.neonGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildTechData(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text("$label: $value",
          style: const TextStyle(
            color: Colors.greenAccent,
            fontFamily: 'Rajdhani',
            fontSize: 11,
            fontWeight: FontWeight.w600,
          )),
    );
  }

  Widget _buildStatusLine(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label:',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.82),
                fontFamily: 'Rajdhani',
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: color,
                fontFamily: 'Orbitron',
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpectrumBars({
    required double gpsOkPct,
    required double batteryOkPct,
    required double estadoNormalPct,
    required double coberturaPct,
  }) {
    final metrics = <({
      String label,
      double pct,
      Color color,
    })>[
      (
        label: 'GPS OK',
        pct: gpsOkPct.clamp(0.0, 100.0),
        color: const Color(0xFF00E5FF),
      ),
      (
        label: 'BAT OK',
        pct: batteryOkPct.clamp(0.0, 100.0),
        color: const Color(0xFFFF4DD2),
      ),
      (
        label: 'EST NORMAL',
        pct: estadoNormalPct.clamp(0.0, 100.0),
        color: const Color(0xFFFFA000),
      ),
      (
        label: 'COBERTURA',
        pct: coberturaPct.clamp(0.0, 100.0),
        color: const Color(0xFF00FF88),
      ),
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: metrics.map((m) {
        final ratio = (m.pct / 100).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      m.label,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontFamily: 'Rajdhani',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${m.pct.round()}%',
                    style: TextStyle(
                      color: m.color,
                      fontFamily: 'Orbitron',
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 11,
                  value: ratio,
                  backgroundColor: Colors.white.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(m.color),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSignalLegend({
    required String label,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontFamily: 'Rajdhani',
            fontSize: 9,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DeviceModule extends StatefulWidget {
  final String status;
  final Color color;

  const _DeviceModule({required this.status, required this.color});

  @override
  State<_DeviceModule> createState() => _DeviceModuleState();
}

class _DeviceModuleState extends State<_DeviceModule>
    with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scanController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _scanController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 40,
      decoration: BoxDecoration(
        border:
            Border.all(color: widget.color.withValues(alpha: 0.5), width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          // Grid background
          Positioned.fill(
            child: CustomPaint(
              painter: ModuleGridPainter(widget.color),
            ),
          ),

          // Horizontal scanner bars
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _scanController,
              builder: (context, child) {
                return CustomPaint(
                  painter: HorizontalScannerPainter(
                    progress: _scanController.value,
                    color: widget.color,
                  ),
                );
              },
            ),
          ),

          // Status LED
          Positioned(
            top: 2,
            right: 2,
            child: AnimatedBuilder(
              animation: _blinkController,
              builder: (context, child) {
                return Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: widget.color
                        .withValues(alpha: _blinkController.value * 0.8 + 0.2),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: widget.color
                            .withValues(alpha: _blinkController.value * 0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Status text
          Positioned(
            bottom: 2,
            left: 2,
            child: Text(
              widget.status,
              style: TextStyle(
                color: widget.color,
                fontSize: 6,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painters

class ModuleGridPainter extends CustomPainter {
  final Color color;

  ModuleGridPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 0.5;

    const spacing = 8.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class HorizontalScannerPainter extends CustomPainter {
  final double progress;
  final Color color;

  HorizontalScannerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        Paint()
          ..color = color.withValues(alpha: 0.3)
          ..strokeWidth = 2);

    // Fill effect
    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final rect = Rect.fromLTWH(0, y, size.width, size.height - y);
    canvas.drawRect(rect, fillPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LiquidCrystalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Subtle liquid crystal pattern
    for (double y = 0; y < size.height; y += 15) {
      final opacity = sin(y / size.height * pi * 4) * 0.05 + 0.02;
      final linePaint = Paint()
        ..color =
            AppConstants.neonCyan.withValues(alpha: opacity.clamp(0.0, 0.08))
        ..strokeWidth = 1;

      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanlinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.02)
      ..strokeWidth = 0.5;

    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BatteryCellPainter extends CustomPainter {
  final double level;

  BatteryCellPainter({required this.level});

  @override
  void paint(Canvas canvas, Size size) {
    const segments = 8;
    final segmentHeight = size.height / segments;
    final segmentWidth = size.width * 0.8;

    for (int i = 0; i < segments; i++) {
      final y = size.height - (i + 1) * segmentHeight;
      final isActive = (segments - i) / segments <= level;

      final color = isActive
          ? AppConstants.neonCyan.withValues(alpha: 0.8)
          : Colors.white.withValues(alpha: 0.1);

      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(
        (size.width - segmentWidth) / 2,
        y,
        segmentWidth,
        segmentHeight - 2,
      );

      canvas.drawRect(rect, paint);

      // Glow effect for active segments
      if (isActive) {
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

        canvas.drawRect(rect, glowPaint);
      }
    }

    // Battery terminals
    final terminalPaint = Paint()
      ..color = AppConstants.neonCyan.withValues(alpha: 0.6)
      ..strokeWidth = 2;

    canvas.drawLine(
      Offset(size.width / 2 - 5, 0),
      Offset(size.width / 2 - 5, 8),
      terminalPaint,
    );
    canvas.drawLine(
      Offset(size.width / 2 + 5, 0),
      Offset(size.width / 2 + 5, 8),
      terminalPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class SpectrumRadarPainter extends CustomPainter {
  final List<double> levels;

  SpectrumRadarPainter({required this.levels});

  @override
  void paint(Canvas canvas, Size size) {
    final source = levels.isEmpty ? const <double>[0.0] : levels;
    final bars = max(12, source.length);
    final barWidth = size.width / bars - 2;

    for (int i = 0; i < bars; i++) {
      final raw = source[i % source.length].clamp(0.0, 1.0);
      final height = size.height * raw;
      final x = i * (barWidth + 2);
      final color = raw >= 0.7
          ? AppConstants.neonGreen
          : raw >= 0.4
              ? AppConstants.alertOrange
              : AppConstants.warningRed;

      final paint = Paint()
        ..color = color.withValues(alpha: 0.75)
        ..style = PaintingStyle.fill;

      final rect = Rect.fromLTWH(x, size.height - height, barWidth, height);
      canvas.drawRect(rect, paint);

      // Glow effect
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

      canvas.drawRect(rect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumRadarPainter oldDelegate) =>
      oldDelegate.levels != levels;
}
