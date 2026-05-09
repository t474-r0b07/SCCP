import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/report_print_service.dart';
import '../controllers/auth_controller.dart';
import '../controllers/commander_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/admin_security_dialog.dart';
import '../widgets/pin_pad.dart';
import '../widgets/supervisor_quick_actions.dart';
import '../widgets/tron_grid.dart';
import 'dashboard_view.dart';
import 'dtex_view.dart';

class CommanderDashboardView extends StatefulWidget {
  const CommanderDashboardView({super.key});

  @override
  State<CommanderDashboardView> createState() => _CommanderDashboardViewState();
}

class _CommanderDashboardViewState extends State<CommanderDashboardView>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  late final AuthController _auth;
  bool _openingFloatingWindow = false;

  @override
  void initState() {
    super.initState();
    if (!Get.isRegistered<DashboardController>()) {
      Get.put(DashboardController());
    }
    if (!Get.isRegistered<CommanderController>()) {
      Get.put(CommanderController());
    }
    _auth = Get.find<AuthController>();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (!_auth.isDirector) {
        Future.microtask(() => Get.offAllNamed('/dashboard-supervisor'));
        return const SizedBox.shrink();
      }
      if (!_auth.hasCommanderAccess) {
        return _CommanderPinGate(auth: _auth);
      }

      return Scaffold(
        backgroundColor: AppConstants.darkBg,
        body: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Stack(
                children: [
                  const Positioned.fill(child: TronGrid()),
                  const DashboardView(
                    showHeader: false,
                    showInitializationOverlay: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _openFloatingWindow({
    required String title,
    required Widget child,
    double width = 1260,
    double height = 760,
  }) async {
    if (_openingFloatingWindow) return;
    _openingFloatingWindow = true;
    await Get.dialog<void>(
      Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: AppConstants.darkBg.withValues(alpha: 0.97),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppConstants.neonCyan.withValues(alpha: 0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: AppConstants.neonCyan.withValues(alpha: 0.25),
                blurRadius: 24,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.32),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: AppConstants.neonCyan.withValues(alpha: 0.25),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Get.back(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
      barrierColor: Colors.black.withValues(alpha: 0.55),
    );
    _openingFloatingWindow = false;
  }

  Future<void> _handleHeaderTabTap(int index) async {
    if (index == 0) return;
    if (index == 1) {
      await _openFloatingWindow(
        title: 'MAPA HISTÓRICO',
        child: const _CommanderHistoricalTab(),
      );
    } else if (index == 2) {
      await _openFloatingWindow(
        title: 'ESTADÍSTICAS COMANDANTE',
        child: const _CommanderAdvancedStatsTab(),
      );
    }
    if (mounted) {
      _tabController.animateTo(0);
    }
  }

  Widget _buildHeader() {
    final tabs = Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppConstants.neonCyan.withValues(alpha: 0.22),
        ),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: _handleHeaderTabTap,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        indicator: BoxDecoration(
          color: AppConstants.neonCyan.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(7),
        ),
        labelStyle: const TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
        tabs: const [
          Tab(text: 'OPERATIVO'),
          Tab(text: 'MAPA HIST'),
          Tab(text: 'ESTADISTICAS'),
        ],
      ),
    );
    final userLabel = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 250),
      child: Obx(() {
        final admin = _auth.currentAdmin.value;
        final text = admin == null
            ? 'DIRECTOR'
            : '${admin.nombre.toUpperCase()} · ${admin.nivelAcceso}';
        return Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppConstants.neonCyan.withValues(alpha: 0.86),
            fontFamily: 'Rajdhani',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        );
      }),
    );
    final desktopActions = _buildCommanderHeaderActions(compact: false);
    final compactActions = _buildCommanderHeaderActions(compact: true);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppConstants.neonCyan.withValues(alpha: 0.24),
            width: 1,
          ),
        ),
        color: Colors.black.withValues(alpha: 0.18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 1100;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'SCCP COMANDANTE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontFamily: 'Orbitron',
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.5,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: userLabel),
                  ],
                ),
                const SizedBox(height: 8),
                tabs,
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: compactActions,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          return Row(
            children: [
              Flexible(
                child: Text(
                  'SCCP COMANDANTE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.95),
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: tabs),
              const SizedBox(width: 12),
              userLabel,
              const SizedBox(width: 10),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: desktopActions,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildCommanderHeaderActions({required bool compact}) {
    final dashboard = Get.find<DashboardController>();
    final spacing = compact ? 4.0 : 6.0;
    final estadoPartesBadge = _commanderEstadoPartesBadgeCount(dashboard);
    final radioBadge = dashboard.unreadRadioInboxCount;
    return <Widget>[
      _buildCommanderIconAction(
        tooltip: 'Imprimir Informe',
        icon: Icons.print_rounded,
        color: Colors.orangeAccent,
        compact: compact,
        onTap: () {
          unawaited(_showCommanderPrintDialog());
        },
      ),
      SizedBox(width: spacing),
      _buildCommanderIconAction(
        tooltip: 'Parte Sorpresa',
        icon: Icons.flash_on_rounded,
        color: AppConstants.neonPink,
        compact: compact,
        onTap: () {
          unawaited(_openCommanderPartesDialog());
        },
      ),
      SizedBox(width: spacing),
      _buildCommanderIconAction(
        tooltip: 'Estado de Partes',
        icon: Icons.description,
        color: Colors.amberAccent,
        compact: compact,
        badgeCount: estadoPartesBadge,
        onTap: () {
          unawaited(_openCommanderEstadoPartesDialog());
        },
      ),
      SizedBox(width: spacing),
      _buildCommanderIconAction(
        tooltip: 'Radio Operativa',
        icon: Icons.multitrack_audio_rounded,
        color: Colors.amberAccent,
        compact: compact,
        badgeCount: radioBadge,
        onTap: () {
          unawaited(_openCommanderRadioDialog());
        },
      ),
      SizedBox(width: spacing),
      _buildCommanderIconAction(
        tooltip: 'Diligencias DTEX',
        icon: Icons.route_rounded,
        color: AppConstants.successGreen,
        compact: compact,
        onTap: () {
          unawaited(showDtexDialog());
        },
      ),
      SizedBox(width: spacing),
      _buildCommanderIconAction(
        tooltip: 'Seguridad',
        icon: Icons.security_rounded,
        color: AppConstants.neonCyan,
        compact: compact,
        onTap: () {
          Get.dialog(const AdminSecurityDialog());
        },
      ),
      SizedBox(width: spacing),
      _buildCommanderIconAction(
        tooltip: 'Cerrar Sesión',
        icon: Icons.power_settings_new,
        color: Colors.redAccent,
        compact: compact,
        onTap: () {
          unawaited(_handleCommanderLogout());
        },
      ),
    ];
  }

  Widget _buildCommanderIconAction({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    required bool compact,
    int badgeCount = 0,
  }) {
    final size = compact ? 32.0 : 34.0;
    final iconSize = compact ? 18.0 : 20.0;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.34),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withValues(alpha: 0.78),
              width: 1.0,
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: iconSize,
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    constraints:
                        const BoxConstraints(minWidth: 14, minHeight: 14),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _commanderEstadoPartesBadgeCount(DashboardController controller) {
    final grupo = controller.currentGroup.value.toUpperCase().trim();
    if (grupo.isEmpty) return 0;

    final oficialById = <String, dynamic>{
      for (final o in controller.oficiales) o.idOficial.trim(): o,
    };

    final faltasAbiertas =
        controller.inconsistenciasDelGrupoActivo.where((inc) {
      final tipo = (inc['tipo_inconsistencia'] ?? '').toString().toUpperCase();
      if (!tipo.contains('FALTA_REPORTE')) return false;
      final estado = (inc['estado'] ?? '').toString().toUpperCase();
      final resuelta = inc['resuelta'] == true;
      return !resuelta && estado != 'CERRADA';
    }).length;

    final partesGrupo = controller.partes.where((parte) {
      final of = oficialById[parte.idOficial.trim()];
      final g = (of?.grupo ?? '').toString().toUpperCase().trim();
      return g == grupo;
    }).toList();

    final partesPendientes = partesGrupo.where((p) {
      final e = p.estadoNormalized;
      return e == 'NUEVO' || e == 'PENDIENTE' || e == 'LEIDO';
    }).length;

    final partesVencidos =
        partesGrupo.where((p) => p.estadoNormalized == 'VENCIDO').length;

    return faltasAbiertas + partesPendientes + partesVencidos;
  }

  Future<void> _openCommanderPartesDialog() async {
    final controller = Get.find<DashboardController>();
    final actorName = _auth.currentAdmin.value?.nombre ?? 'DIRECTOR';
    await showSupervisorPartesDialog(
      controller: controller,
      supervisorName: actorName,
    );
  }

  Future<void> _openCommanderEstadoPartesDialog() async {
    final controller = Get.find<DashboardController>();
    final grupo = controller.currentGroup.value.toUpperCase().trim();
    final oficialById = <String, dynamic>{
      for (final o in controller.oficiales) o.idOficial.trim(): o,
    };
    final faltasGrupo = controller.inconsistenciasDelGrupoActivo.where((inc) {
      final tipo = (inc['tipo_inconsistencia'] ?? '').toString().toUpperCase();
      return tipo.contains('FALTA_REPORTE');
    }).toList()
      ..sort((a, b) {
        final da = DateTime.tryParse((a['fecha_deteccion'] ?? '').toString()) ??
            DateTime(1970);
        final db = DateTime.tryParse((b['fecha_deteccion'] ?? '').toString()) ??
            DateTime(1970);
        return db.compareTo(da);
      });

    final faltasAbiertas = faltasGrupo.where((inc) {
      final estado = (inc['estado'] ?? '').toString().toUpperCase();
      final resuelta = inc['resuelta'] == true;
      return !resuelta && estado != 'CERRADA';
    }).length;
    final faltasCerradas = faltasGrupo.length - faltasAbiertas;

    final partesGrupo = controller.partes.where((parte) {
      final of = oficialById[parte.idOficial.trim()];
      final g = (of?.grupo ?? '').toString().toUpperCase().trim();
      return g == grupo;
    }).toList();
    final partesPendientes = partesGrupo.where((p) {
      final e = p.estadoNormalized;
      return e == 'NUEVO' || e == 'PENDIENTE' || e == 'LEIDO';
    }).length;
    final partesCumplidos = partesGrupo.where((p) {
      final e = p.estadoNormalized;
      return e == 'COMPLETADO' || e == 'REGISTRADO';
    }).length;
    final partesVencidos =
        partesGrupo.where((p) => p.estadoNormalized == 'VENCIDO').length;

    await Get.dialog<void>(
      AlertDialog(
        backgroundColor: AppConstants.darkBg,
        title: const Text(
          'ESTADO DE PARTES',
          style: TextStyle(
            color: AppConstants.neonCyan,
            fontFamily: 'Orbitron',
            fontSize: 14,
            letterSpacing: 0.8,
          ),
        ),
        content: SizedBox(
          width: 540,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Grupo: $grupo',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildCommanderPartesKpiChip(
                    'FALTA ABIERTA',
                    '$faltasAbiertas',
                    faltasAbiertas > 0
                        ? AppConstants.warningRed
                        : Colors.white54,
                  ),
                  _buildCommanderPartesKpiChip(
                    'FALTA CERRADA',
                    '$faltasCerradas',
                    AppConstants.successGreen,
                  ),
                  _buildCommanderPartesKpiChip(
                    'PENDIENTES',
                    '$partesPendientes',
                    partesPendientes > 0
                        ? AppConstants.alertOrange
                        : Colors.white54,
                  ),
                  _buildCommanderPartesKpiChip(
                    'CUMPLIDOS',
                    '$partesCumplidos',
                    AppConstants.successGreen,
                  ),
                  _buildCommanderPartesKpiChip(
                    'VENCIDOS',
                    '$partesVencidos',
                    partesVencidos > 0
                        ? AppConstants.warningRed
                        : Colors.white54,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Últimas faltas de parte',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.75),
                  fontFamily: 'Orbitron',
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 6),
              if (faltasGrupo.isEmpty)
                Text(
                  'Sin faltas de parte registradas en el periodo.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontFamily: 'Rajdhani',
                    fontSize: 12,
                  ),
                )
              else
                ...faltasGrupo.take(8).map((inc) {
                  final oficialId = (inc['id_oficial'] ?? '').toString().trim();
                  final oficial = oficialById[oficialId];
                  final nombre =
                      (oficial?.nombreOficial ?? 'OFICIAL $oficialId')
                          .toString()
                          .toUpperCase();
                  final estado =
                      (inc['estado'] ?? 'ABIERTA').toString().toUpperCase();
                  final desc =
                      (inc['descripcion'] ?? 'Sin detalle').toString().trim();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $nombre [$estado] - $desc',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontFamily: 'Rajdhani',
                        fontSize: 12,
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text(
              'CERRAR',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCommanderRadioDialog() async {
    final controller = Get.find<DashboardController>();
    await showSupervisorRadioDialog(controller: controller);
  }

  Future<void> _handleCommanderLogout() async {
    await _auth.logout();
    Get.offAllNamed('/login');
  }

  String _esc(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Widget _buildCommanderPartesKpiChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontFamily: 'Orbitron',
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontFamily: 'Rajdhani',
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _commanderRecommendations({
    required Map<String, dynamic> global,
    required Map<String, dynamic> alfa,
    required Map<String, dynamic> bravo,
  }) {
    final recs = <String>[];
    final coverageGlobal = (global['cobertura_pct'] as num?)?.toDouble() ?? 0.0;
    final partesGlobal =
        (global['cumplimiento_partes_pct'] as num?)?.toDouble() ?? 0.0;
    final inconsistGlobal =
        (global['inconsistencias_abiertas'] as num?)?.toInt() ?? 0;

    final alfaCoverage = (alfa['cobertura_pct'] as num?)?.toDouble() ?? 0.0;
    final bravoCoverage = (bravo['cobertura_pct'] as num?)?.toDouble() ?? 0.0;
    final alfaIncons = (alfa['inconsistencias_abiertas'] as num?)?.toInt() ?? 0;
    final bravoIncons =
        (bravo['inconsistencias_abiertas'] as num?)?.toInt() ?? 0;

    if (coverageGlobal < 85) {
      recs.add(
        'Refuerzo inmediato de cobertura: verificar disponibilidad real de oficiales y reactivar turnos incompletos.',
      );
    }
    if (partesGlobal < 75) {
      recs.add(
        'Incrementar control sobre partes obligatorios: seguimiento por supervisor y confirmación de cierre por turno.',
      );
    }
    if (inconsistGlobal > 0) {
      recs.add(
        'Priorizar cierre formal de inconsistencias abiertas con evidencia de acción correctiva y responsable asignado.',
      );
    }
    if ((alfaCoverage - bravoCoverage).abs() >= 15) {
      final weaker = alfaCoverage < bravoCoverage ? 'ALFA' : 'BRAVO';
      recs.add(
        'Desbalance operativo detectado entre grupos. Ejecutar plan de nivelación sobre grupo $weaker.',
      );
    }
    if ((alfaIncons - bravoIncons).abs() >= 4) {
      final overloaded = alfaIncons > bravoIncons ? 'ALFA' : 'BRAVO';
      recs.add(
        'Concentración de inconsistencias en $overloaded. Recomendada auditoría puntual de procedimientos y biometría.',
      );
    }
    if (recs.isEmpty) {
      recs.add(
        'Estado estable. Mantener control preventivo y revisión comparativa diaria de cobertura, partes e inconsistencias.',
      );
    }
    return recs;
  }

  String _commanderReportHtml({
    required String scopeLabel,
    required Map<String, dynamic> data,
    required Map<String, dynamic> alfa,
    required Map<String, dynamic> bravo,
    required List<String> recommendations,
    required String logoMainSrc,
  }) {
    String pct(dynamic value) =>
        ((value as num?)?.toDouble() ?? 0).toStringAsFixed(1);
    String intv(dynamic value) => ((value as num?)?.toInt() ?? 0).toString();

    final admin = _auth.currentAdmin.value;
    final signName = admin?.nombre ?? 'DIRECTOR';
    final signRole = admin?.nivelAcceso ?? 'COMANDANTE';
    final generatedAt = DateTime.now();
    final abiertas = (data['inconsistencias_abiertas'] as num?)?.toInt() ?? 0;
    final cerradas = (data['inconsistencias_cerradas'] as num?)?.toInt() ?? 0;
    final totalIncidencias = abiertas + cerradas;
    final tasaCierre = totalIncidencias == 0
        ? 100.0
        : ((cerradas / totalIncidencias) * 100).clamp(0.0, 100.0);

    final cards = '''
<table>
  <tr><th>Indicador</th><th>Valor</th></tr>
  <tr><td>Reportes</td><td>${intv(data['total_reportes'])}</td></tr>
  <tr><td>Cobertura</td><td>${pct(data['cobertura_pct'])}%</td></tr>
  <tr><td>Cumplimiento Geocerca</td><td>${pct(data['cumplimiento_pct'])}%</td></tr>
  <tr><td>Cumplimiento Partes</td><td>${pct(data['cumplimiento_partes_pct'])}%</td></tr>
  <tr><td>Incidencias abiertas</td><td>$abiertas</td></tr>
  <tr><td>Incidencias cerradas</td><td>$cerradas</td></tr>
  <tr><td>Tasa de cierre incidencias</td><td>${tasaCierre.toStringAsFixed(1)}%</td></tr>
</table>
''';

    final compare = '''
<table>
  <tr><th>Grupo</th><th>Reportes</th><th>Cobertura</th><th>Partes</th><th>Inc. abiertas</th></tr>
  <tr><td>ALFA</td><td>${intv(alfa['total_reportes'])}</td><td>${pct(alfa['cobertura_pct'])}%</td><td>${pct(alfa['cumplimiento_partes_pct'])}%</td><td>${intv(alfa['inconsistencias_abiertas'])}</td></tr>
  <tr><td>BRAVO</td><td>${intv(bravo['total_reportes'])}</td><td>${pct(bravo['cobertura_pct'])}%</td><td>${pct(bravo['cumplimiento_partes_pct'])}%</td><td>${intv(bravo['inconsistencias_abiertas'])}</td></tr>
</table>
''';

    final recItems = recommendations.map((r) => '<li>${_esc(r)}</li>').join();

    return '''
<div style="display:flex;align-items:center;gap:14px;margin-bottom:8px;">
  <img src="${_esc(logoMainSrc)}" alt="Logo SCCP" style="width:64px;height:64px;object-fit:contain;border:1px solid #d1d5db;border-radius:8px;padding:6px;background:#fff;">
  <div>
    <h1 style="margin:0;">INFORME COMANDANTE - ${_esc(scopeLabel)}</h1>
    <p class="muted" style="margin:4px 0 0 0;">Generado: ${generatedAt.toIso8601String()}</p>
  </div>
</div>
$cards
<h2>Comparativa ALFA vs BRAVO</h2>
$compare
<p class="muted"><strong>Aclaración:</strong> "Incidencia abierta" = inconsistencia pendiente de cierre administrativo. No es equivalente a "reporte automático no enviado".</p>
<h2>Acciones recomendadas</h2>
<ol>$recItems</ol>
<p><strong>Firma:</strong> ${_esc(signName)} (${_esc(signRole)})</p>
''';
  }

  Future<String> _resolveCommanderReportLogo() async {
    return _assetImageAsDataUri(
      'assets/images/logoB.png',
      fallbackWebPath: '/assets/assets/images/logoB.png',
    );
  }

  Future<String> _assetImageAsDataUri(
    String assetPath, {
    required String fallbackWebPath,
  }) async {
    try {
      final bytes = await rootBundle.load(assetPath);
      final raw = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      return 'data:image/png;base64,${base64Encode(raw)}';
    } catch (_) {
      return fallbackWebPath;
    }
  }

  Future<void> _printCommanderScope({
    required String scope,
    required String? group,
  }) async {
    final c = Get.find<CommanderController>();
    final period = c.selectedAnalyticsPeriod.value;
    final globalData = c.buildDetailedStats(
      group: null,
      oficialId: null,
      period: period,
    );
    final alfaData = c.buildDetailedStats(
      group: 'ALFA',
      oficialId: null,
      period: period,
    );
    final bravoData = c.buildDetailedStats(
      group: 'BRAVO',
      oficialId: null,
      period: period,
    );
    final targetData = scope == 'GLOBAL'
        ? globalData
        : c.buildDetailedStats(
            group: group,
            oficialId: null,
            period: period,
          );
    final recs = _commanderRecommendations(
      global: globalData,
      alfa: alfaData,
      bravo: bravoData,
    );
    final logoMainSrc = await _resolveCommanderReportLogo();
    final label = scope == 'GLOBAL' ? 'GLOBAL' : 'GRUPO ${group ?? '--'}';
    final html = _commanderReportHtml(
      scopeLabel: label,
      data: targetData,
      alfa: alfaData,
      bravo: bravoData,
      recommendations: recs,
      logoMainSrc: logoMainSrc,
    );
    final ok = await ReportPrintService.printHtml(
      title: 'Informe Comandante $label',
      htmlBody: html,
    );
    if (!ok) {
      Get.snackbar(
        'Impresión',
        'No se pudo abrir la vista de impresión.',
        backgroundColor: AppConstants.warningRed.withValues(alpha: 0.35),
        colorText: Colors.white,
      );
    }
  }

  Future<void> _showCommanderPrintDialog() async {
    final c = Get.find<CommanderController>();
    String groupSelection = 'ALFA';
    String officialSelection =
        c.oficiales.isNotEmpty ? c.oficiales.first.idOficial : '';

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppConstants.darkBg.withValues(alpha: 0.98),
          title: const Text(
            'Impresión de Informes',
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 460;
              final width =
                  constraints.maxWidth < 560 ? constraints.maxWidth : 520.0;
              return SizedBox(
                width: width,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _MiniLabel('GLOBAL'),
                      const SizedBox(height: 6),
                      _CommandButton(
                        label: 'IMPRIMIR INFORME GLOBAL',
                        onTap: () async {
                          Get.back();
                          await _printCommanderScope(
                              scope: 'GLOBAL', group: null);
                        },
                      ),
                      const SizedBox(height: 12),
                      const _MiniLabel('POR GRUPO'),
                      const SizedBox(height: 6),
                      compact
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                DropdownButton<String>(
                                  value: groupSelection,
                                  dropdownColor: const Color(0xFF08131F),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'ALFA', child: Text('ALFA')),
                                    DropdownMenuItem(
                                        value: 'BRAVO', child: Text('BRAVO')),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setStateDialog(
                                        () => groupSelection = value);
                                  },
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: _CommandButton(
                                    label: 'IMPRIMIR INFORME GRUPO',
                                    onTap: () async {
                                      Get.back();
                                      await _printCommanderScope(
                                        scope: 'GRUPO',
                                        group: groupSelection,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                DropdownButton<String>(
                                  value: groupSelection,
                                  dropdownColor: const Color(0xFF08131F),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700,
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: 'ALFA', child: Text('ALFA')),
                                    DropdownMenuItem(
                                        value: 'BRAVO', child: Text('BRAVO')),
                                  ],
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setStateDialog(
                                        () => groupSelection = value);
                                  },
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _CommandButton(
                                    label: 'IMPRIMIR INFORME GRUPO',
                                    onTap: () async {
                                      Get.back();
                                      await _printCommanderScope(
                                        scope: 'GRUPO',
                                        group: groupSelection,
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                      const SizedBox(height: 12),
                      const _MiniLabel('INDIVIDUAL'),
                      const SizedBox(height: 6),
                      compact
                          ? Column(
                              children: [
                                DropdownButton<String>(
                                  value: officialSelection.isEmpty
                                      ? null
                                      : officialSelection,
                                  dropdownColor: const Color(0xFF08131F),
                                  isExpanded: true,
                                  hint: const Text(
                                    'SELECCIONAR OFICIAL',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700,
                                  ),
                                  items: c.oficiales
                                      .map(
                                        (o) => DropdownMenuItem(
                                          value: o.idOficial,
                                          child: Text(
                                            '${o.nombreOficial} (${o.idOficial})',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Rajdhani',
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setStateDialog(
                                        () => officialSelection = value);
                                  },
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: double.infinity,
                                  child: _CommandButton(
                                    label: 'IMPRIMIR',
                                    onTap: officialSelection.isEmpty
                                        ? null
                                        : () async {
                                            Get.back();
                                            await Get.find<
                                                    DashboardController>()
                                                .imprimirReporteIndividualSupervisor(
                                              idOficial: officialSelection,
                                            );
                                          },
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: DropdownButton<String>(
                                    value: officialSelection.isEmpty
                                        ? null
                                        : officialSelection,
                                    dropdownColor: const Color(0xFF08131F),
                                    isExpanded: true,
                                    hint: const Text(
                                      'SELECCIONAR OFICIAL',
                                      style: TextStyle(color: Colors.white70),
                                    ),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontFamily: 'Rajdhani',
                                      fontWeight: FontWeight.w700,
                                    ),
                                    items: c.oficiales
                                        .map(
                                          (o) => DropdownMenuItem(
                                            value: o.idOficial,
                                            child: Text(
                                              '${o.nombreOficial} (${o.idOficial})',
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Rajdhani',
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value == null) return;
                                      setStateDialog(
                                          () => officialSelection = value);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _CommandButton(
                                  label: 'IMPRIMIR',
                                  onTap: officialSelection.isEmpty
                                      ? null
                                      : () async {
                                          Get.back();
                                          await Get.find<DashboardController>()
                                              .imprimirReporteIndividualSupervisor(
                                            idOficial: officialSelection,
                                          );
                                        },
                                ),
                              ],
                            ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: const Text(
                'CERRAR',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommanderHistoricalTab extends StatelessWidget {
  const _CommanderHistoricalTab();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CommanderController>();
    final mapController = MapController();

    final officersPanel = _CommandGlassPanel(
      width: 270,
      height: double.infinity,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _MiniLabel('OFICIALES'),
          const SizedBox(height: 8),
          Obx(
            () => _CommandButton(
              label: 'DIA ${_fmtDate(c.historyDate.value)}',
              onTap: () async {
                final now = DateTime.now();
                final first = DateTime(now.year, now.month, 1);
                final last = DateTime(now.year, now.month + 1, 0);
                final picked = await showDatePicker(
                  context: context,
                  firstDate: first,
                  lastDate: last,
                  initialDate: c.historyDate.value,
                );
                if (picked == null) return;
                c.historyDate.value = picked;
                c.cargarHistorialRecorrido();
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Obx(() {
              c.bootstrapTargets();
              final list = c.oficiales;
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, index) {
                  final o = list[index];
                  final selected = c.selectedOficialId.value == o.idOficial;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: InkWell(
                      onTap: () {
                        c.selectedOficialId.value = o.idOficial;
                        c.cargarHistorialRecorrido();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppConstants.neonCyan.withValues(alpha: 0.16)
                              : Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? AppConstants.neonCyan
                                : Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: Text(
                          o.nombreOficial,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
    final mapPanel = _CommandGlassPanel(
      height: double.infinity,
      padding: EdgeInsets.zero,
      child: Obx(() {
        if (c.loadingHistorial.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppConstants.neonCyan),
          );
        }
        final reports = c.historial
            .where((r) => r.latitud != null && r.longitud != null)
            .toList()
          ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
        if (reports.isEmpty) {
          return const Center(
            child: _MiniLabel('SIN UBICACIONES EN EL DIA SELECCIONADO'),
          );
        }
        final clusters = c.compactHistoricalRoute(
          reports,
          thresholdMeters: 50,
        );
        final points = clusters.map((c) => c.point).toList();
        final center = c.centerForPoints(points);
        return Stack(
          children: [
            Builder(
              builder: (context) {
                final media = MediaQuery.of(context);
                final mobileViewport =
                    media.size.width < 980 || media.size.shortestSide < 700;
                final flags = mobileViewport
                    ? (InteractiveFlag.all & ~InteractiveFlag.rotate)
                    : InteractiveFlag.all;
                return FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: 12.5,
                    interactionOptions: InteractionOptions(flags: flags),
                    onMapReady: () {
                      if (points.length >= 2) {
                        mapController.fitCamera(
                          CameraFit.coordinates(
                            coordinates: points,
                            padding: const EdgeInsets.all(56),
                          ),
                        );
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      retinaMode: true,
                      userAgentPackageName: 'sccp_command_center',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: points,
                          color: AppConstants.neonCyan,
                          strokeWidth: 2.6,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        ...clusters.map((cluster) => Marker(
                              point: cluster.point,
                              width: 36,
                              height: 36,
                              child: Tooltip(
                                message:
                                    '${cluster.count > 1 ? 'RANGO' : 'HORA'}: ${_fmtHour(cluster.start)}${cluster.count > 1 ? ' - ${_fmtHour(cluster.end)}' : ''}\nREPORTES: ${cluster.count}',
                                waitDuration: const Duration(milliseconds: 100),
                                child: _HistoryPointMarker(
                                  color: AppConstants.neonCyan,
                                  count: cluster.count,
                                ),
                              ),
                            )),
                        Marker(
                          point: points.first,
                          width: 24,
                          height: 24,
                          child: const _RouteDot(color: Colors.orangeAccent),
                        ),
                        Marker(
                          point: points.last,
                          width: 34,
                          height: 34,
                          child:
                              const _RoutePulseDot(color: AppConstants.neonRed),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(6),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  '${clusters.length}/${reports.length} PUNTOS',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 900;
        if (compact) {
          return Column(
            children: [
              SizedBox(height: 200, child: officersPanel),
              const SizedBox(height: 10),
              Expanded(child: mapPanel),
            ],
          );
        }
        return Row(
          children: [
            officersPanel,
            const SizedBox(width: 10),
            Expanded(child: mapPanel),
          ],
        );
      },
    );
  }
}

class _CommanderAdvancedStatsTab extends StatelessWidget {
  const _CommanderAdvancedStatsTab();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<CommanderController>();

    return Obx(() {
      final period = c.selectedAnalyticsPeriod.value;
      final global = c.buildDetailedStats(period: period);
      final alfa = c.buildDetailedStats(group: 'ALFA', period: period);
      final bravo = c.buildDetailedStats(group: 'BRAVO', period: period);

      final globalReportes = _asInt(global['total_reportes']);
      final alfaReportes = _asInt(alfa['total_reportes']);
      final bravoReportes = _asInt(bravo['total_reportes']);

      final globalCob = _asDouble(global['cobertura_pct']);
      final alfaCob = _asDouble(alfa['cobertura_pct']);
      final bravoCob = _asDouble(bravo['cobertura_pct']);

      final globalPartes = _asDouble(global['cumplimiento_partes_pct']);
      final alfaPartes = _asDouble(alfa['cumplimiento_partes_pct']);
      final bravoPartes = _asDouble(bravo['cumplimiento_partes_pct']);

      final alfaIncons = _asInt(alfa['inconsistencias_abiertas']);
      final bravoIncons = _asInt(bravo['inconsistencias_abiertas']);
      final globalIncons = _asInt(global['inconsistencias_abiertas']);

      final inflAlfa = globalReportes == 0
          ? 0.0
          : (alfaReportes / globalReportes * 100).clamp(0.0, 100.0);
      final inflBravo = globalReportes == 0
          ? 0.0
          : (bravoReportes / globalReportes * 100).clamp(0.0, 100.0);

      final rangeLabel = c.analyticsRangeStart.value != null &&
              c.analyticsRangeEnd.value != null
          ? '${_fmtDate(c.analyticsRangeStart.value!)} - ${_fmtDate(c.analyticsRangeEnd.value!.subtract(const Duration(days: 1)))}'
          : '--';

      final recs = _buildCommanderRecommendations(
        global: global,
        alfa: alfa,
        bravo: bravo,
      );

      final alfaTrend = _listNum(alfa['tendencia_7dias']);
      final bravoTrend = _listNum(bravo['tendencia_7dias']);
      final maxTrendLen = alfaTrend.length > bravoTrend.length
          ? alfaTrend.length
          : bravoTrend.length;

      return Column(
        children: [
          _CommandGlassPanel(
            height: 112,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const _MiniLabel('PERIODO ANALITICO'),
                    ChoiceChip(
                      label: const Text('DIA'),
                      selected: period == AnalyticsPeriod.daily,
                      onSelected: (_) =>
                          c.setAnalyticsPeriod(AnalyticsPeriod.daily),
                      selectedColor:
                          AppConstants.neonCyan.withValues(alpha: 0.22),
                      side: BorderSide(
                        color: AppConstants.neonCyan.withValues(alpha: 0.35),
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      backgroundColor: Colors.black.withValues(alpha: 0.22),
                    ),
                    ChoiceChip(
                      label: const Text('MES'),
                      selected: period == AnalyticsPeriod.monthly,
                      onSelected: (_) =>
                          c.setAnalyticsPeriod(AnalyticsPeriod.monthly),
                      selectedColor:
                          AppConstants.neonCyan.withValues(alpha: 0.22),
                      side: BorderSide(
                        color: AppConstants.neonCyan.withValues(alpha: 0.35),
                      ),
                      labelStyle: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Orbitron',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      backgroundColor: Colors.black.withValues(alpha: 0.22),
                    ),
                    if (c.loadingAnalytics.value)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppConstants.neonCyan,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    rangeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Vista globalizada: comparación ALFA vs BRAVO y consolidado global con recomendaciones operativas.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontFamily: 'Rajdhani',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 760,
              child: Row(
                children: [
                  _KpiCard(
                    label: 'GLOBAL REPORTES',
                    value: '$globalReportes',
                    color: AppConstants.neonCyan,
                  ),
                  const SizedBox(width: 8),
                  _KpiCard(
                    label: 'COBERTURA GLOBAL',
                    value: '${globalCob.toStringAsFixed(1)}%',
                    color: Colors.amberAccent,
                  ),
                  const SizedBox(width: 8),
                  _KpiCard(
                    label: 'INFLUENCIA ALFA',
                    value: '${inflAlfa.toStringAsFixed(1)}%',
                    color: AppConstants.neonGreen,
                  ),
                  const SizedBox(width: 8),
                  _KpiCard(
                    label: 'INFLUENCIA BRAVO',
                    value: '${inflBravo.toStringAsFixed(1)}%',
                    color: AppConstants.neonPink,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 1080,
                child: Row(
                  children: [
                    Expanded(
                      child: _ChartCard(
                        title: 'COBERTURA COMPARATIVA',
                        metricLabel:
                            'Global ${globalCob.toStringAsFixed(1)} | ALFA ${alfaCob.toStringAsFixed(1)} | BRAVO ${bravoCob.toStringAsFixed(1)}',
                        child: BarChart(
                          BarChartData(
                            maxY: 100,
                            barGroups: [
                              _barGroup(0, globalCob, Colors.white),
                              _barGroup(1, alfaCob, AppConstants.neonGreen),
                              _barGroup(2, bravoCob, AppConstants.neonPink),
                            ],
                            gridData: _grid(),
                            borderData: FlBorderData(show: false),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false),
                              ),
                              leftTitles: const AxisTitles(
                                sideTitles: SideTitles(
                                    showTitles: true, reservedSize: 28),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  getTitlesWidget: (value, meta) {
                                    const labels = ['GLOBAL', 'ALFA', 'BRAVO'];
                                    final i = value.toInt();
                                    if (i < 0 || i >= labels.length) {
                                      return const SizedBox.shrink();
                                    }
                                    return Text(
                                      labels[i],
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 9,
                                        fontFamily: 'Rajdhani',
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChartCard(
                        title: 'CUMPLIMIENTO PARTES',
                        metricLabel:
                            'Global ${globalPartes.toStringAsFixed(1)} | ALFA ${alfaPartes.toStringAsFixed(1)} | BRAVO ${bravoPartes.toStringAsFixed(1)}',
                        child: BarChart(
                          BarChartData(
                            maxY: 100,
                            barGroups: [
                              _barGroup(0, globalPartes, Colors.white),
                              _barGroup(1, alfaPartes, AppConstants.neonGreen),
                              _barGroup(2, bravoPartes, AppConstants.neonPink),
                            ],
                            gridData: _grid(),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(show: false),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _ChartCard(
                        title: 'INCONSISTENCIAS ABIERTAS',
                        metricLabel:
                            'Global $globalIncons | ALFA $alfaIncons | BRAVO $bravoIncons',
                        child: BarChart(
                          BarChartData(
                            maxY: ([globalIncons, alfaIncons, bravoIncons]
                                        .reduce((a, b) => a > b ? a : b)
                                        .toDouble() +
                                    2)
                                .clamp(1, 100),
                            barGroups: [
                              _barGroup(
                                  0, globalIncons.toDouble(), Colors.white),
                              _barGroup(1, alfaIncons.toDouble(),
                                  AppConstants.neonGreen),
                              _barGroup(2, bravoIncons.toDouble(),
                                  AppConstants.neonPink),
                            ],
                            gridData: _grid(),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(show: false),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: 760,
                child: Row(
                  children: [
                    Expanded(
                      child: _ChartCard(
                        title: 'TENDENCIA 7 DÍAS (REPORTES)',
                        metricLabel: 'Comparativa ALFA vs BRAVO',
                        child: LineChart(
                          LineChartData(
                            gridData: _grid(),
                            borderData: FlBorderData(show: false),
                            titlesData: const FlTitlesData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: List.generate(
                                  maxTrendLen,
                                  (i) => FlSpot(
                                    i.toDouble(),
                                    i < alfaTrend.length ? alfaTrend[i] : 0,
                                  ),
                                ),
                                isCurved: true,
                                barWidth: 2,
                                color: AppConstants.neonGreen,
                                dotData: const FlDotData(show: false),
                              ),
                              LineChartBarData(
                                spots: List.generate(
                                  maxTrendLen,
                                  (i) => FlSpot(
                                    i.toDouble(),
                                    i < bravoTrend.length ? bravoTrend[i] : 0,
                                  ),
                                ),
                                isCurved: true,
                                barWidth: 2,
                                color: AppConstants.neonPink,
                                dotData: const FlDotData(show: false),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _CommandGlassPanel(
                        height: double.infinity,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _MiniLabel('RECOMENDACIONES AUTOMÁTICAS'),
                            const SizedBox(height: 8),
                            Expanded(
                              child: ListView.separated(
                                itemCount: recs.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 6),
                                itemBuilder: (context, index) {
                                  return Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${index + 1}.',
                                        style: const TextStyle(
                                          color: AppConstants.neonCyan,
                                          fontFamily: 'Orbitron',
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          recs[index],
                                          style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: 0.9),
                                            fontFamily: 'Rajdhani',
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
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
        ],
      );
    });
  }

  BarChartGroupData _barGroup(int x, double value, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: value,
          color: color,
          width: 16,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  List<String> _buildCommanderRecommendations({
    required Map<String, dynamic> global,
    required Map<String, dynamic> alfa,
    required Map<String, dynamic> bravo,
  }) {
    final recs = <String>[];

    final globalCob = _asDouble(global['cobertura_pct']);
    final globalPartes = _asDouble(global['cumplimiento_partes_pct']);
    final globalIncons = _asInt(global['inconsistencias_abiertas']);

    final alfaCob = _asDouble(alfa['cobertura_pct']);
    final bravoCob = _asDouble(bravo['cobertura_pct']);

    final alfaIncons = _asInt(alfa['inconsistencias_abiertas']);
    final bravoIncons = _asInt(bravo['inconsistencias_abiertas']);

    if (globalCob < 85) {
      recs.add(
        'Cobertura global por debajo de umbral. Reasignar recursos y validar presencia efectiva por turno.',
      );
    }
    if (globalPartes < 75) {
      recs.add(
        'Cumplimiento de partes insuficiente. Aplicar control escalonado por supervisor y cierre obligatorio por evento.',
      );
    }
    if (globalIncons > 0) {
      recs.add(
        'Existen inconsistencias abiertas en consolidado global. Priorizar cierre con trazabilidad completa.',
      );
    }
    if ((alfaCob - bravoCob).abs() >= 15) {
      final weaker = alfaCob < bravoCob ? 'ALFA' : 'BRAVO';
      recs.add(
        'Brecha de cobertura entre grupos. Ejecutar plan de nivelación operativo sobre $weaker.',
      );
    }
    if ((alfaIncons - bravoIncons).abs() >= 4) {
      final overloaded = alfaIncons > bravoIncons ? 'ALFA' : 'BRAVO';
      recs.add(
        'Concentración de inconsistencias en $overloaded. Revisión de protocolos de reporte, GPS y biometría.',
      );
    }

    if (recs.isEmpty) {
      recs.add(
        'Métricas estables en ambos grupos. Mantener control preventivo con revisión comparativa diaria.',
      );
    }

    return recs;
  }

  FlGridData _grid() {
    return FlGridData(
      show: true,
      drawHorizontalLine: true,
      drawVerticalLine: true,
      getDrawingHorizontalLine: (_) =>
          FlLine(color: Colors.white.withValues(alpha: 0.1), strokeWidth: 1),
      getDrawingVerticalLine: (_) =>
          FlLine(color: Colors.white.withValues(alpha: 0.08), strokeWidth: 1),
    );
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return 0.0;
  }

  List<double> _listNum(dynamic raw) {
    if (raw is! List) return const <double>[];
    return raw.map((e) => (e as num?)?.toDouble() ?? 0).toList();
  }
}

class _CommanderPinGate extends StatelessWidget {
  final AuthController auth;
  const _CommanderPinGate({required this.auth});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: Center(
        child: _CommandGlassPanel(
          width: 440,
          borderColor: AppConstants.neonPink.withValues(alpha: 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'ACCESO COMANDANTE',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 10),
              PinPad(
                title: 'INGRESE PIN DE DIRECTOR',
                onComplete: (pin) async {
                  final ok = await auth.verifyDirectorPin(pin);
                  if (!ok) {
                    final lockSeconds = auth.pinLockRemainingSeconds;
                    final msg = lockSeconds > 0
                        ? 'PIN BLOQUEADO TEMPORALMENTE ($lockSeconds s)'
                        : 'PIN INVALIDO';
                    Get.snackbar(
                      'SEGURIDAD',
                      msg,
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.35),
                      colorText: Colors.white,
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await auth.logout();
                  Get.offAllNamed('/login');
                },
                child: const Text(
                  'CERRAR SESION',
                  style: TextStyle(
                    color: AppConstants.neonCyan,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommandGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double? width;
  final double? height;
  final Color? borderColor;
  const _CommandGlassPanel({
    required this.child,
    this.padding,
    this.width,
    this.height,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: padding ?? const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.33),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: borderColor ??
                    AppConstants.neonCyan.withValues(alpha: 0.24),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final String metricLabel;
  final Widget child;
  const _ChartCard({
    required this.title,
    required this.metricLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _CommandGlassPanel(
      height: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniLabel(title),
          const SizedBox(height: 2),
          Text(
            metricLabel,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppConstants.neonCyan.withValues(alpha: 0.9),
              fontFamily: 'Orbitron',
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: _CommandGlassPanel(
        height: 72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommandButton extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  const _CommandButton({
    required this.label,
    required this.onTap,
  });

  @override
  State<_CommandButton> createState() => _CommandButtonState();
}

class _CommandButtonState extends State<_CommandButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 150),
        scale: _hover ? 1.03 : 1.0,
        child: InkWell(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color:
                  AppConstants.neonCyan.withValues(alpha: _hover ? 0.28 : 0.16),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppConstants.neonCyan
                    .withValues(alpha: _hover ? 0.95 : 0.6),
              ),
              boxShadow: _hover
                  ? [
                      BoxShadow(
                        color: AppConstants.neonCyan.withValues(alpha: 0.35),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
                fontSize: 11,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniLabel extends StatelessWidget {
  final String text;
  const _MiniLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.88),
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
        fontSize: 11,
        letterSpacing: 0.6,
      ),
    );
  }
}

class _RouteDot extends StatelessWidget {
  final Color color;
  const _RouteDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.25),
        border: Border.all(color: color, width: 2),
      ),
    );
  }
}

class _RoutePulseDot extends StatefulWidget {
  final Color color;
  const _RoutePulseDot({required this.color});

  @override
  State<_RoutePulseDot> createState() => _RoutePulseDotState();
}

class _RoutePulseDotState extends State<_RoutePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
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
        return Transform.scale(
          scale: 1 + (_controller.value * 0.25),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withValues(alpha: 0.24),
              border: Border.all(color: widget.color, width: 2),
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.5),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HistoryPointMarker extends StatelessWidget {
  final Color color;
  final int count;

  const _HistoryPointMarker({
    required this.color,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    final prominent = count > 1;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: prominent ? 0.35 : 0.22),
                border: Border.all(
                  color: prominent ? Colors.white : color,
                  width: prominent ? 1.8 : 1.2,
                ),
              ),
            ),
          ),
        ),
        if (prominent)
          Positioned(
            right: -7,
            top: -7,
            child: Container(
              constraints: const BoxConstraints(minWidth: 16),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                count > 99 ? '99+' : '$count',
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w800,
                  fontSize: 9,
                  height: 1,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _fmtHour(DateTime date) {
  final d = date.toLocal();
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

String _fmtDate(DateTime d) {
  return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
