import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:ui';
import '../controllers/auth_controller.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/tactical_map.dart';
import '../views/inconsistencias_view.dart';
import '../widgets/stats_widget.dart';
import '../widgets/tron_grid.dart';
import '../widgets/alertas_card.dart';
import '../widgets/telemetria_card.dart';
import '../widgets/estado_operativo_card.dart';
import '../widgets/gestion_oficiales_dialog.dart';
import '../widgets/dashboard_initialization_overlay.dart';
import '../widgets/supervisor_quick_actions.dart';
import '../widgets/admin_security_dialog.dart';
import '../views/dtex_view.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/oficial_model.dart';
import 'package:fl_chart/fl_chart.dart';

class DashboardView extends StatefulWidget {
  final bool showHeader;
  final bool showInitializationOverlay;
  final bool safeMode;
  const DashboardView({
    super.key,
    this.showHeader = true,
    this.showInitializationOverlay = true,
    this.safeMode = false,
  });

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView>
    with TickerProviderStateMixin {
  static const double _desktopMinViewportWidth = 1360;

  late final DashboardController _controller;
  late final AuthController _authController;
  late bool _showInitializationOverlay;

  // Entrance animation controllers
  late AnimationController _entranceController;
  late List<Animation<double>> _slideAnimations;
  late List<Animation<double>> _opacityAnimations;

  @override
  void initState() {
    super.initState();
    _controller = Get.isRegistered<DashboardController>()
        ? Get.find<DashboardController>()
        : Get.put(DashboardController());
    _authController = Get.find<AuthController>();
    _showInitializationOverlay = widget.showInitializationOverlay && !kIsWeb;

    // Entrance animation setup
    _entranceController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // Create staggered animations for 7 elements (header + 6 cards)
    _slideAnimations = [];
    _opacityAnimations = [];

    for (int i = 0; i < 7; i++) {
      final startTime = i * 0.1; // Stagger by 100ms
      final endTime = startTime + 0.4; // Each animation lasts 400ms

      _slideAnimations.add(
        Tween<double>(begin: 100.0, end: 0.0).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Interval(startTime, endTime, curve: Curves.easeOutCubic),
          ),
        ),
      );

      _opacityAnimations.add(
        Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _entranceController,
            curve: Interval(startTime, endTime, curve: Curves.easeIn),
          ),
        ),
      );
    }

    // When the initialization overlay is disabled (commander tab),
    // make content visible immediately.
    if (!_showInitializationOverlay) {
      _entranceController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _entranceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main dashboard content
        _buildDashboardContent(_controller),

        // Iron Man-style initialization overlay
        if (_showInitializationOverlay)
          DashboardInitializationOverlay(
            onInitializationComplete: () {
              setState(() {
                _showInitializationOverlay = false;
              });
              // Start entrance animations after overlay completes
              Future.delayed(const Duration(milliseconds: 500), () {
                _entranceController.forward();
              });
            },
          ),
      ],
    );
  }

  Widget _animatedEntranceWidget({
    required Widget child,
    required int index,
    required Offset slideDirection,
  }) {
    return AnimatedBuilder(
      animation: _entranceController,
      builder: (context, childWidget) {
        final slideOffset = slideDirection * _slideAnimations[index].value;
        return Transform.translate(
          offset: slideOffset,
          child: Opacity(
            opacity: _opacityAnimations[index].value,
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildDashboardContent(DashboardController controller) {
    return Obx(() {
      final showLightweightBody = _shouldShowLightweightBody(controller);
      return Scaffold(
        backgroundColor: AppConstants.darkBg,
        body: Stack(
          children: [
            const Positioned.fill(child: TronGrid()),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile =
                      _useStackedMobileLayout(context, constraints);
                  final desktopContent =
                      _buildDesktopDashboardLayout(controller);
                  final heavyContent = isMobile
                      ? _buildMobileDashboardLayout(controller)
                      : constraints.maxWidth < _desktopMinViewportWidth
                          ? SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minWidth: _desktopMinViewportWidth,
                                  minHeight: constraints.maxHeight,
                                ),
                                child: desktopContent,
                              ),
                            )
                          : desktopContent;
                  return Column(
                    children: [
                      if (widget.showHeader)
                        _animatedEntranceWidget(
                          index: 0,
                          slideDirection: const Offset(0, -1),
                          child: _buildTopHeader(controller),
                        ),
                      Expanded(
                        child: showLightweightBody
                            ? _buildDashboardLoadingBody(controller)
                            : heavyContent,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      );
    });
  }

  bool _shouldShowLightweightBody(DashboardController controller) {
    if (!controller.isLoading.value) return false;
    return controller.oficiales.isEmpty &&
        controller.reportes.isEmpty &&
        controller.alertasOperativas.isEmpty &&
        controller.telemetriaActual.isEmpty &&
        controller.inconsistencias.isEmpty;
  }

  Widget _buildDashboardLoadingBody(DashboardController controller) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppConstants.neonCyan.withValues(alpha: 0.45),
            ),
            boxShadow: [
              BoxShadow(
                color: AppConstants.neonCyan.withValues(alpha: 0.08),
                blurRadius: 24,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppConstants.neonCyan),
              const SizedBox(height: 14),
              Text(
                controller.loadingMessage.value.isEmpty
                    ? 'Cargando dashboard operativo...'
                    : controller.loadingMessage.value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El encabezado y los accesos siguen disponibles mientras terminan de sincronizarse los modulos.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontFamily: 'Rajdhani',
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppConstants.neonCyan,
                  side: BorderSide(
                    color: AppConstants.neonCyan.withValues(alpha: 0.7),
                  ),
                ),
                onPressed: controller.loadInitialData,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Reintentar carga'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _useStackedMobileLayout(
    BuildContext context,
    BoxConstraints constraints,
  ) {
    final media = MediaQuery.of(context);
    final shortestSide = media.size.shortestSide;
    final maxWidth = constraints.maxWidth;

    // On web, preserve desktop composition unless viewport is truly narrow.
    if (kIsWeb) return maxWidth < 980;

    return shortestSide < 700 && maxWidth < 1180;
  }

  Widget _buildDesktopDashboardLayout(DashboardController controller) {
    const leftFlex = 2;
    const centerFlex = 5;
    const rightFlex = 2;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: leftFlex,
            child: Column(
              children: [
                Expanded(
                  child: _animatedEntranceWidget(
                    index: 1,
                    slideDirection: const Offset(-1, 0),
                    child: _buildGlassCard(
                      title: 'ESTADO OPERATIVO',
                      color: AppConstants.neonCyan,
                      child: EstadoOperativoCard(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _animatedEntranceWidget(
                    index: 2,
                    slideDirection: const Offset(-1, 0),
                    child: _buildGlassCard(
                      title: 'ALERTAS CRÍTICAS',
                      color: AppConstants.neonPink,
                      child: AlertasCard(),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: _animatedEntranceWidget(
                    index: 3,
                    slideDirection: const Offset(-1, 0),
                    child: _buildGlassCard(
                      title: 'TELEMETRÍA',
                      color: Colors.blueAccent,
                      child: TelemetriaCard(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: centerFlex,
            child: _animatedEntranceWidget(
              index: 4,
              slideDirection: const Offset(0, 1),
              child: _buildMainCentralHub(),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: rightFlex,
            child: Column(
              children: [
                Expanded(
                  flex: 1,
                  child: _animatedEntranceWidget(
                    index: 5,
                    slideDirection: const Offset(1, 0),
                    child: _buildGlassCard(
                      title: 'INCONSISTENCIAS',
                      color: Colors.orangeAccent,
                      onTap: () => _showInconsistenciasDialog(controller),
                      child: Obx(
                        () => InconsistenciasView(
                          inconsistencias: controller.inconsistenciasFiltered,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  flex: 1,
                  child: _animatedEntranceWidget(
                    index: 6,
                    slideDirection: const Offset(1, 0),
                    child: _buildGlassCard(
                      title: 'ESTADÍSTICAS',
                      color: Colors.tealAccent,
                      onTap: () => _showEstadisticasDialog(controller),
                      child: Obx(
                        () => StatsWidget(
                          analytics: controller.buildRealtimeAnalytics(),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileDashboardLayout(DashboardController controller) {
    final width = MediaQuery.of(context).size.width;
    final compactPhone = width < 380;
    final standardCardHeight = compactPhone ? 250.0 : 270.0;
    final denseCardHeight = compactPhone ? 268.0 : 292.0;
    final mapHeight = compactPhone ? 320.0 : 350.0;
    final gap = compactPhone ? 8.0 : 10.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        children: [
          _mobileCard(
            title: 'ESTADO OPERATIVO',
            color: AppConstants.neonCyan,
            index: 1,
            height: standardCardHeight,
            compactHeader: compactPhone,
            child: EstadoOperativoCard(),
          ),
          SizedBox(height: gap),
          _mobileCard(
            title: 'ALERTAS CRÍTICAS',
            color: AppConstants.neonPink,
            index: 2,
            height: standardCardHeight,
            compactHeader: compactPhone,
            child: AlertasCard(),
          ),
          SizedBox(height: gap),
          _mobileCard(
            title: 'TELEMETRÍA',
            color: Colors.blueAccent,
            index: 3,
            height: standardCardHeight,
            compactHeader: compactPhone,
            child: TelemetriaCard(),
          ),
          SizedBox(height: gap),
          SizedBox(
            width: double.infinity,
            height: mapHeight,
            child: _animatedEntranceWidget(
              index: 4,
              slideDirection: const Offset(0, 1),
              child: _buildMainCentralHub(),
            ),
          ),
          SizedBox(height: gap),
          _mobileCard(
            title: 'INCONSISTENCIAS',
            color: Colors.orangeAccent,
            index: 5,
            height: denseCardHeight,
            compactHeader: compactPhone,
            onTap: () => _showInconsistenciasDialog(controller),
            child: Obx(
              () => InconsistenciasView(
                inconsistencias: controller.inconsistenciasFiltered,
              ),
            ),
          ),
          SizedBox(height: gap),
          _mobileCard(
            title: 'ESTADÍSTICAS',
            color: Colors.tealAccent,
            index: 6,
            height: denseCardHeight,
            compactHeader: compactPhone,
            onTap: () => _showEstadisticasDialog(controller),
            child: Obx(
              () => StatsWidget(
                analytics: controller.buildRealtimeAnalytics(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileCard({
    required String title,
    required Widget child,
    required Color color,
    required int index,
    required double height,
    bool compactHeader = false,
    VoidCallback? onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: _animatedEntranceWidget(
        index: index,
        slideDirection: const Offset(0, 0.8),
        child: _buildGlassCard(
          title: title,
          color: color,
          onTap: onTap,
          compactHeader: compactHeader,
          child: child,
        ),
      ),
    );
  }

  Widget _buildTopHeader(DashboardController controller) {
    return Obx(() {
      final currentGroup = controller.currentGroup.value;
      final adminName = _resolveHeaderAdminName();
      final roleName =
          _authController.currentAdmin.value?.nivelAcceso ?? 'SUPERVISOR';
      final isSupervisorRole = roleName.toUpperCase() == 'SUPERVISOR';
      final media = MediaQuery.of(context);
      final isMobile = kIsWeb
          ? media.size.width < 980
          : media.size.width < 980 || media.size.shortestSide < 700;
      final supervisorActions =
          _buildSupervisorHeaderActions(controller, compact: isMobile);
      return Container(
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 10 : 24,
          vertical: isMobile ? 10 : 15,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppConstants.neonCyan.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          gradient: LinearGradient(
            colors: [
              AppConstants.neonCyan.withValues(alpha: 0.1),
              Colors.transparent,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SCCP COMMAND CENTER',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      color: Colors.white,
                      fontSize: 10,
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildCompactGroupChip(currentGroup)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              roleName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.amber.withValues(alpha: 0.95),
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.4,
                              ),
                            ),
                            Text(
                              adminName.toUpperCase(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (supervisorActions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: SizedBox(
                        height: 36,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: supervisorActions,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (isSupervisorRole) const SizedBox(height: 2),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'SCCP COMMAND CENTER',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Orbitron',
                              color: Colors.white,
                              fontSize: 17,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(child: _buildGroupLogo(currentGroup)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: _buildHeaderStat(
                      roleName.toUpperCase(),
                      adminName.toUpperCase(),
                      Colors.amber,
                    ),
                  ),
                  if (supervisorActions.isNotEmpty) const SizedBox(width: 10),
                  if (supervisorActions.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: supervisorActions,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      );
    });
  }

  String _resolveHeaderAdminName() {
    final admin = _authController.currentAdmin.value;
    if (admin == null) return 'OPERADOR';
    final rawName = admin.nombre.trim();
    if (rawName.isNotEmpty) return rawName;

    final email = admin.email.trim();
    if (email.isEmpty) return 'OPERADOR';
    final localPart = email.split('@').first;
    final normalized = localPart.replaceAll(RegExp(r'[._-]+'), ' ').trim();
    if (normalized.isEmpty) return 'OPERADOR';
    return normalized.toUpperCase();
  }

  List<Widget> _buildSupervisorHeaderActions(
    DashboardController controller, {
    bool compact = false,
  }) {
    final admin = _authController.currentAdmin.value;
    if (admin == null) {
      return const <Widget>[];
    }

    final spacing = compact ? 4.0 : 6.0;
    if (admin.esSupervisorDtex && !admin.esSupervisor) {
      return <Widget>[
        _buildSupervisorActionButton(
          tooltip: 'Diligencias DTEX',
          icon: Icons.route_rounded,
          color: AppConstants.successGreen,
          compact: compact,
          onPressed: _showDtexDialog,
        ),
        SizedBox(width: spacing),
        _buildSupervisorActionButton(
          tooltip: 'Seguridad de Cuenta',
          icon: Icons.security_rounded,
          color: Colors.lightBlueAccent,
          compact: compact,
          onPressed: () => Get.dialog(const AdminSecurityDialog()),
        ),
        SizedBox(width: spacing),
        _buildSupervisorActionButton(
          tooltip: 'Cerrar Sesión',
          icon: Icons.power_settings_new,
          color: Colors.redAccent,
          compact: compact,
          onPressed: _handleSupervisorLogout,
        ),
      ];
    }

    if (!admin.esSupervisor) {
      return const <Widget>[];
    }

    final estadoPartesBadge = _estadoPartesBadgeCount(controller);
    final radioBadge = controller.unreadRadioInboxCount;
    return <Widget>[
      _buildSupervisorActionButton(
        tooltip: 'Imprimir Reporte Individual',
        icon: Icons.print_rounded,
        color: Colors.orangeAccent,
        compact: compact,
        onPressed: () => _showImprimirReporteIndividualDialog(controller),
      ),
      SizedBox(width: spacing),
      _buildSupervisorActionButton(
        tooltip: 'Partes Sorpresa',
        icon: Icons.flash_on_rounded,
        color: AppConstants.neonPink,
        compact: compact,
        onPressed: () => _showPartesSorpresaDialog(controller),
      ),
      SizedBox(width: spacing),
      _buildSupervisorActionButton(
        tooltip: 'Estado de Partes',
        icon: Icons.description,
        color: Colors.amberAccent,
        compact: compact,
        badgeCount: estadoPartesBadge,
        onPressed: () => _showEstadoPartesDialog(controller),
      ),
      SizedBox(width: spacing),
      _buildSupervisorActionButton(
        tooltip: 'Radio Operativa',
        icon: Icons.multitrack_audio_rounded,
        color: Colors.orangeAccent,
        compact: compact,
        badgeCount: radioBadge,
        onPressed: () => _showRadioDialog(controller),
      ),
      SizedBox(width: spacing),
      _buildSupervisorActionButton(
        tooltip: 'Diligencias DTEX',
        icon: Icons.route_rounded,
        color: AppConstants.successGreen,
        compact: compact,
        onPressed: _showDtexDialog,
      ),
      SizedBox(width: spacing),
      _buildSupervisorActionButton(
        tooltip: 'Gestionar Oficiales',
        icon: Icons.manage_accounts_rounded,
        color: AppConstants.neonCyan,
        compact: compact,
        onPressed: () => Get.dialog(const GestionOficialesDialog()),
      ),
      SizedBox(width: spacing),
      _buildSupervisorActionButton(
        tooltip: 'Seguridad de Cuenta',
        icon: Icons.security_rounded,
        color: Colors.lightBlueAccent,
        compact: compact,
        onPressed: () => Get.dialog(const AdminSecurityDialog()),
      ),
      SizedBox(width: spacing),
      _buildSupervisorActionButton(
        tooltip: 'Cerrar Sesión',
        icon: Icons.power_settings_new,
        color: Colors.redAccent,
        compact: compact,
        onPressed: _handleSupervisorLogout,
      ),
    ];
  }

  Future<void> _handleSupervisorLogout() async {
    await _authController.logout();
    Get.offAllNamed('/login');
  }

  Widget _buildSupervisorActionButton({
    required String tooltip,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    bool compact = false,
    int badgeCount = 0,
  }) {
    final size = compact ? 32.0 : 34.0;
    final iconSize = compact ? 18.0 : 20.0;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onPressed,
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

  int _estadoPartesBadgeCount(DashboardController controller) {
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

  Widget _buildKpiChip(String label, String value, Color color) {
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

  Widget _buildGroupLogo(String group) {
    final normalizedGroup = group.trim().toUpperCase();
    final logoPath = switch (normalizedGroup) {
      'ALFA' => 'assets/images/logo-alfa.png',
      'BRAVO' => 'assets/images/logo-bravo.png',
      _ => 'assets/images/logo-sccp.png',
    };
    final groupColor = normalizedGroup == 'ALFA'
        ? AppConstants.neonCyan
        : normalizedGroup == 'BRAVO'
            ? const Color(0xFFFF8C00)
            : Colors.white70;

    return Row(
      children: [
        // Large logo taking full height
        Container(
          width: 48,
          height: 48, // Full height of header
          decoration: BoxDecoration(
            color: groupColor.withValues(alpha: 0.1),
            border: Border.all(
              color: groupColor.withValues(alpha: 0.3),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Image.asset(
              logoPath,
              width: 36,
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                return Text(
                  group.toUpperCase(),
                  style: TextStyle(
                    color: groupColor,
                    fontSize: 14,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.bold,
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Text info
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'GRUPO ${group.toUpperCase()}',
              style: TextStyle(
                color: groupColor,
                fontSize: 14,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
            Text(
              'ACTIVO',
              style: TextStyle(
                color: groupColor.withValues(alpha: 0.8),
                fontSize: 10,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactGroupChip(String group) {
    final label = group.toUpperCase().trim().isEmpty
        ? 'GRUPO --'
        : 'GRUPO ${group.toUpperCase()}';
    final groupColor = group.toUpperCase() == 'ALFA'
        ? AppConstants.neonCyan
        : const Color(0xFFFF8C00);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: groupColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: groupColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: groupColor,
          fontFamily: 'Orbitron',
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.6),
            fontSize: 10,
            letterSpacing: 2,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildGlassCard({
    required String title,
    required Widget child,
    required Color color,
    bool compactHeader = false,
    VoidCallback? onTap,
  }) {
    return CustomPaint(
      painter: _TronFramePainter(color: color),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 2.0, sigmaY: 2.0),
          child: InkWell(
            onTap: onTap,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: compactHeader ? 10 : 12,
                      vertical: compactHeader ? 5 : 6,
                    ),
                    color: color.withValues(alpha: 0.2),
                    child: Text(
                      title,
                      style: TextStyle(
                        color: color,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.bold,
                        fontSize: compactHeader ? 11 : 16,
                      ),
                    ),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMainCentralHub() {
    if (widget.safeMode) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: AppConstants.neonCyan.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: AppConstants.neonCyan.withValues(alpha: 0.05),
              blurRadius: 30,
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.health_and_safety_rounded,
                  color: AppConstants.neonCyan,
                  size: 46,
                ),
                const SizedBox(height: 12),
                const Text(
                  'MODO DE PRUEBA DEL DASHBOARD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'El mapa táctico está desactivado temporalmente para verificar que el header, botones y tarjetas sigan funcionando.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontFamily: 'Rajdhani',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppConstants.neonCyan.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppConstants.neonCyan.withValues(alpha: 0.05),
            blurRadius: 30,
          ),
        ],
      ),
      child: const TacticalMap(),
    );
  }

  Future<void> _showPartesSorpresaDialog(DashboardController controller) {
    final supervisorName =
        _authController.currentAdmin.value?.nombre ?? 'SUPERVISOR';
    return showSupervisorPartesDialog(
      controller: controller,
      supervisorName: supervisorName,
    );
  }

  Future<void> _showRadioDialog(DashboardController controller) {
    return showSupervisorRadioDialog(
      controller: controller,
    );
  }

  Future<void> _showDtexDialog() {
    return showDtexDialog();
  }

  Future<void> _showEstadoPartesDialog(DashboardController controller) async {
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
          width: 520,
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
                  _buildKpiChip(
                    'FALTA ABIERTA',
                    '$faltasAbiertas',
                    faltasAbiertas > 0
                        ? AppConstants.warningRed
                        : Colors.white54,
                  ),
                  _buildKpiChip(
                    'FALTA CERRADA',
                    '$faltasCerradas',
                    AppConstants.successGreen,
                  ),
                  _buildKpiChip(
                    'PENDIENTES',
                    '$partesPendientes',
                    partesPendientes > 0
                        ? AppConstants.alertOrange
                        : Colors.white54,
                  ),
                  _buildKpiChip(
                    'CUMPLIDOS',
                    '$partesCumplidos',
                    AppConstants.successGreen,
                  ),
                  _buildKpiChip(
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
                ...faltasGrupo.take(6).map((inc) {
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

  Future<void> _showImprimirReporteIndividualDialog(
    DashboardController controller,
  ) async {
    final activeGroup = controller.currentGroup.value.toUpperCase();
    final oficialesGrupo = controller.oficiales
        .where((o) =>
            (o.grupo ?? '').toUpperCase() == activeGroup && (o.activo == true))
        .toList()
      ..sort((a, b) => a.nombreOficial.compareTo(b.nombreOficial));

    if (oficialesGrupo.isEmpty) {
      Get.snackbar(
        'Reporte individual',
        'No hay oficiales activos en el grupo $activeGroup.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppConstants.alertOrange.withValues(alpha: 0.35),
        colorText: Colors.white,
      );
      return;
    }

    String selectedId = controller.selectedOficialId.value?.trim() ?? '';
    if (selectedId.isEmpty ||
        !oficialesGrupo.any((o) => o.idOficial == selectedId)) {
      selectedId = oficialesGrupo.first.idOficial;
    }

    await Get.dialog<void>(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            backgroundColor: AppConstants.darkBg,
            title: const Text(
              'IMPRIMIR REPORTE INDIVIDUAL',
              style: TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                fontSize: 14,
              ),
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grupo activo: $activeGroup',
                    style: TextStyle(
                      color: AppConstants.neonCyan.withValues(alpha: 0.9),
                      fontFamily: 'Rajdhani',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedId,
                    dropdownColor: const Color(0xFF08131F),
                    decoration: InputDecoration(
                      labelText: 'Oficial',
                      labelStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppConstants.neonCyan),
                      ),
                    ),
                    items: oficialesGrupo
                        .map(
                          (o) => DropdownMenuItem<String>(
                            value: o.idOficial,
                            child: Text(
                              '${o.nombreOficial} (${o.idOficial})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'Rajdhani',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setStateDialog(() => selectedId = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Periodo: turno operativo actual (08:00 a 08:00).',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontFamily: 'Rajdhani',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Permiso: Supervisor solo puede imprimir reportes individuales.',
                    style: TextStyle(
                      color: Colors.amber.withValues(alpha: 0.9),
                      fontFamily: 'Rajdhani',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Get.back(),
                child: const Text(
                  'CANCELAR',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Get.back();
                  await controller.imprimirReporteIndividualSupervisor(
                    idOficial: selectedId,
                  );
                },
                icon: const Icon(Icons.print_rounded),
                label: const Text('IMPRIMIR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      Colors.lightGreenAccent.withValues(alpha: 0.2),
                  foregroundColor: Colors.white,
                  side: BorderSide(
                    color: Colors.lightGreenAccent.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ============================================================================
  // DIALOGS DETALLADOS - VISUALES Y COMPREHENSIVOS
  // ============================================================================

  void _showInconsistenciasDialog(DashboardController controller) {
    final inconsistencias = controller.inconsistenciasDelGrupoActivo;
    final totalInconsistencias = inconsistencias.length;
    final criticas = inconsistencias
        .where(
          (i) => (i['prioridad'] ?? '').toString().toUpperCase() == 'CRITICA',
        )
        .length;
    final abiertas = inconsistencias
        .where(
          (i) => (i['estado'] ?? '').toString().toUpperCase() == 'ABIERTA',
        )
        .length;

    final media = MediaQuery.of(context).size;
    final mobileDialog = media.width < 980 || media.shortestSide < 760;
    final dialogWidth =
        (mobileDialog ? media.width * 0.96 : 860).clamp(260.0, 860.0);
    final dialogHeight =
        (mobileDialog ? media.height * 0.94 : 620).clamp(520.0, 760.0);
    final metricWidth = (mobileDialog
            ? ((dialogWidth.toDouble() - 40) / 2)
            : ((dialogWidth.toDouble() - 84) / 4))
        .clamp(120.0, 220.0);

    Get.dialog(
      Padding(
        padding: EdgeInsets.symmetric(
          horizontal: mobileDialog ? 6 : 24,
          vertical: mobileDialog ? 10 : 24,
        ),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: dialogWidth.toDouble(),
            height: dialogHeight.toDouble(),
            child: Container(
              decoration: BoxDecoration(
                color: AppConstants.darkBg.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orangeAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orangeAccent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: mobileDialog ? 12 : 16,
                      vertical: mobileDialog ? 9 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orangeAccent.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning,
                          color: Colors.orangeAccent,
                          size: mobileDialog ? 20 : 26,
                        ),
                        SizedBox(width: mobileDialog ? 8 : 10),
                        Expanded(
                          child: Text(
                            'ANÁLISIS DE INCONSISTENCIAS LÓGICAS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: mobileDialog ? 12 : 15,
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white54,
                            size: 24,
                          ),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      mobileDialog ? 10 : 14,
                      mobileDialog ? 10 : 12,
                      mobileDialog ? 10 : 14,
                      8,
                    ),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: metricWidth.toDouble(),
                          child: _buildMetricCard(
                            'TOTAL',
                            totalInconsistencias.toString(),
                            Colors.white,
                            Icons.list,
                            compact: true,
                          ),
                        ),
                        SizedBox(
                          width: metricWidth.toDouble(),
                          child: _buildMetricCard(
                            'CRÍTICAS',
                            criticas.toString(),
                            AppConstants.warningRed,
                            Icons.priority_high,
                            compact: true,
                          ),
                        ),
                        SizedBox(
                          width: metricWidth.toDouble(),
                          child: _buildMetricCard(
                            'ABIERTAS',
                            abiertas.toString(),
                            AppConstants.alertOrange,
                            Icons.pending,
                            compact: true,
                          ),
                        ),
                        SizedBox(
                          width: metricWidth.toDouble(),
                          child: _buildMetricCard(
                            'RESUELTAS',
                            (totalInconsistencias - abiertas).toString(),
                            AppConstants.successGreen,
                            Icons.check_circle,
                            compact: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        mobileDialog ? 10 : 14,
                        0,
                        mobileDialog ? 10 : 14,
                        10,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: InconsistenciasView(
                          inconsistencias: inconsistencias,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEstadisticasDialog(DashboardController controller) {
    final analytics = controller.buildRealtimeAnalytics();
    final currentGroup = controller.currentGroup.value.toUpperCase();
    final now = DateTime.now();

    final nominalGrupo = (analytics['nominal_total'] as num?)?.toInt() ?? 0;
    final alfaNom = (analytics['nominal_alfa'] as num?)?.toInt() ?? 0;
    final bravoNom = (analytics['nominal_bravo'] as num?)?.toInt() ?? 0;
    final nominalGlobal = alfaNom + bravoNom;
    final intervaloReporteMin = (((analytics['thresholds'] as Map?) ??
                const <String, dynamic>{})['reporte_intervalo_min'] as num?)
            ?.toInt() ??
        6;

    final officialById = <String, Oficial>{
      for (final o in controller.oficiales) o.idOficial: o,
    };

    String resolveReportGroup(dynamic r) {
      final reportGroup = (r.grupo ?? '').toString().toUpperCase();
      if (reportGroup.isNotEmpty) return reportGroup;
      return (officialById[r.idOficialRef]?.grupo ?? '')
          .toString()
          .toUpperCase();
    }

    DateTime periodStart(String period) {
      if (period == 'HOY') {
        return controller.operationalWindowStart;
      }
      final dayStart = DateTime(now.year, now.month, now.day);
      if (period == '7D') {
        return dayStart.subtract(const Duration(days: 6));
      }
      return dayStart.subtract(const Duration(days: 29));
    }

    DateTime periodEnd(String period, DateTime start) {
      if (period == 'HOY') {
        final windowEnd = controller.operationalWindowEnd;
        return now.isBefore(windowEnd) ? now : windowEnd;
      }
      return now;
    }

    String metricBand(double value) {
      if (value >= 90) return 'ALTO';
      if (value >= 75) return 'MEDIO';
      return 'BAJO';
    }

    String laneLevel({
      required int high,
      required int medium,
      required int low,
      required int total,
    }) {
      if (high > 0 || total >= 6) return 'ALTA';
      if (medium > 0 || total >= 3) return 'MEDIA';
      if (low > 0) return 'BAJA';
      return 'NORMAL';
    }

    DateTime? parseInconsistencyDate(dynamic raw) {
      if (raw == null) return null;
      if (raw is DateTime) return raw;
      return DateTime.tryParse(raw.toString());
    }

    Map<String, dynamic> computePeriodModel(String period) {
      final start = periodStart(period);
      final end = periodEnd(period, start);

      final reportesGlobalPeriodo = controller.reportes.where((r) {
        final ts = r.fechaHora;
        if (ts.isBefore(start) || !ts.isBefore(end)) return false;
        return resolveReportGroup(r).isNotEmpty;
      }).toList();

      final reportesGrupoPeriodo = reportesGlobalPeriodo
          .where((r) => resolveReportGroup(r) == currentGroup)
          .toList();

      final reportesGrupo = reportesGrupoPeriodo.length;
      final reportesGlobal = reportesGlobalPeriodo.length;

      final activeGroupIds = reportesGrupoPeriodo
          .map((r) => r.idOficialRef.toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final activeGlobalIds = reportesGlobalPeriodo
          .map((r) => r.idOficialRef.toString().trim())
          .where((id) => id.isNotEmpty)
          .toSet();

      final activosGrupo = activeGroupIds.length;
      final activosGlobal = activeGlobalIds.length;
      final coberturaGrupo = nominalGrupo == 0
          ? 0.0
          : ((activosGrupo / nominalGrupo) * 100).clamp(0.0, 100.0);

      final elapsedMinutes =
          end.difference(start).inMinutes.clamp(1, 60 * 24 * 365);
      final expectedPerOfficer = (elapsedMinutes / intervaloReporteMin).ceil();
      final reportesEsperadosGrupo = nominalGrupo * expectedPerOfficer;
      final reportesEsperadosGlobal = nominalGlobal * expectedPerOfficer;

      final cumplimientoGrupo = reportesEsperadosGrupo == 0
          ? 0.0
          : ((reportesGrupo / reportesEsperadosGrupo) * 100).clamp(0.0, 100.0);
      final cumplimientoGlobal = reportesEsperadosGlobal == 0
          ? 0.0
          : ((reportesGlobal / reportesEsperadosGlobal) * 100)
              .clamp(0.0, 100.0);

      final influenciaGrupoReportes = reportesGlobal == 0
          ? 0.0
          : ((reportesGrupo / reportesGlobal) * 100).clamp(0.0, 100.0);
      final influenciaGrupoActivos = activosGlobal == 0
          ? 0.0
          : ((activosGrupo / activosGlobal) * 100).clamp(0.0, 100.0);

      int alertHigh = 0;
      int alertMedium = 0;
      int alertLow = 0;
      int telemHigh = 0;
      int telemMedium = 0;
      int telemLow = 0;

      for (final r in reportesGrupoPeriodo) {
        final dist = (r.distanciaMetros ?? 0).toDouble();
        final bat = (r.nivelBateria ?? 100).toDouble();
        final estado = (r.estadoAlerta).toString().toUpperCase();
        final hardAlert =
            estado != 'NORMAL' || dist > 50 || bat < 20 || (r.gpsReal == false);

        if (hardAlert) {
          final sev = (estado == 'CRITICO' || dist > 100 || bat < 10) ? 3 : 2;
          if (sev >= 3) {
            alertHigh++;
          } else if (sev == 2) {
            alertMedium++;
          } else {
            alertLow++;
          }
          continue;
        }

        if (bat <= 35 || dist > 40) {
          telemHigh++;
        } else if (bat <= 55 || dist > 20) {
          telemMedium++;
        } else if (bat <= 70 || dist > 10) {
          telemLow++;
        }
      }

      final inconsistenciasPeriodo =
          controller.inconsistenciasDelGrupoActivo.where((inc) {
        final ts = parseInconsistencyDate(inc['fecha_deteccion']);
        if (ts == null) return false;
        return !ts.isBefore(start) && ts.isBefore(end);
      }).toList();

      int inconsHigh = 0;
      int inconsMedium = 0;
      int inconsLow = 0;

      for (final inc in inconsistenciasPeriodo) {
        final prio = (inc['prioridad'] ?? '').toString().toUpperCase();
        final estado = (inc['estado'] ?? '').toString().toUpperCase();
        final isOpen = estado != 'CERRADA';
        if (prio == 'CRITICA' || (prio == 'ALTA' && isOpen)) {
          inconsHigh++;
        } else if (prio == 'ALTA' || prio == 'MEDIA') {
          inconsMedium++;
        } else {
          inconsLow++;
        }
      }

      final laneAlertas = {
        'total': alertHigh + alertMedium + alertLow,
        'alta': alertHigh,
        'media': alertMedium,
        'baja': alertLow,
        'nivel': laneLevel(
          high: alertHigh,
          medium: alertMedium,
          low: alertLow,
          total: alertHigh + alertMedium + alertLow,
        ),
      };

      final laneInconsistencias = {
        'total': inconsistenciasPeriodo.length,
        'alta': inconsHigh,
        'media': inconsMedium,
        'baja': inconsLow,
        'nivel': laneLevel(
          high: inconsHigh,
          medium: inconsMedium,
          low: inconsLow,
          total: inconsistenciasPeriodo.length,
        ),
      };

      final telemTotal = telemHigh + telemMedium + telemLow;
      final laneTelemetria = {
        'total': telemTotal,
        'alta': telemHigh,
        'media': telemMedium,
        'baja': telemLow,
        'nivel': laneLevel(
          high: telemHigh,
          medium: telemMedium,
          low: telemLow,
          total: telemTotal,
        ),
      };

      final riskRaw = (alertHigh * 25.0) +
          (alertMedium * 12.0) +
          (inconsHigh * 10.0) +
          (inconsMedium * 5.0) +
          (telemHigh * 6.0) +
          ((100 - cumplimientoGrupo) * 0.5);
      double riesgoGrupo = riskRaw.clamp(0.0, 100.0);
      if (nominalGrupo > 0 && activosGrupo == 0) {
        riesgoGrupo = 100.0;
      }

      final periodLabels = <String>[];
      final periodValues = <double>[];
      if (period == 'HOY') {
        for (int i = 0; i < 8; i++) {
          final hour = (start.hour + (i * 3)) % 24;
          periodLabels.add(hour.toString().padLeft(2, '0'));
          periodValues.add(0);
        }
        for (final report in reportesGrupoPeriodo) {
          final diffHours = report.fechaHora.difference(start).inHours;
          if (diffHours < 0 || diffHours >= 24) continue;
          final idx = (diffHours ~/ 3).clamp(0, 7);
          periodValues[idx] = periodValues[idx] + 1;
        }
      } else if (period == '7D') {
        final dayStart = DateTime(now.year, now.month, now.day);
        for (int i = 6; i >= 0; i--) {
          final d0 = dayStart.subtract(Duration(days: i));
          final d1 = d0.add(const Duration(days: 1));
          final c = controller.reportes.where((r) {
            final ts = r.fechaHora;
            if (ts.isBefore(d0) || !ts.isBefore(d1)) return false;
            return resolveReportGroup(r) == currentGroup;
          }).length;
          periodLabels.add(_weekdayShort(d0.weekday));
          periodValues.add(c.toDouble());
        }
      } else {
        for (int b = 0; b < 6; b++) {
          final bStart = start.add(Duration(days: b * 5));
          final bEnd = b == 5 ? end : bStart.add(const Duration(days: 5));
          final c = controller.reportes.where((r) {
            final ts = r.fechaHora;
            if (ts.isBefore(bStart) || !ts.isBefore(bEnd)) return false;
            return resolveReportGroup(r) == currentGroup;
          }).length;
          final d0 = (b * 5) + 1;
          final d1 = ((b + 1) * 5).clamp(1, 30);
          periodLabels.add('D$d0-$d1');
          periodValues.add(c.toDouble());
        }
      }

      final weeklyLabels = <String>[];
      final weeklyValues = <double>[];
      final influenceWeekly = <double>[];
      final todayStart = DateTime(now.year, now.month, now.day);
      for (int i = 6; i >= 0; i--) {
        final d0 = todayStart.subtract(Duration(days: i));
        final d1 = d0.add(const Duration(days: 1));
        final gCount = controller.reportes.where((r) {
          final ts = r.fechaHora;
          if (ts.isBefore(d0) || !ts.isBefore(d1)) return false;
          return resolveReportGroup(r) == currentGroup;
        }).length;
        final allCount = controller.reportes.where((r) {
          final ts = r.fechaHora;
          if (ts.isBefore(d0) || !ts.isBefore(d1)) return false;
          return resolveReportGroup(r).isNotEmpty;
        }).length;
        weeklyLabels.add(_weekdayShort(d0.weekday));
        weeklyValues.add(gCount.toDouble());
        influenceWeekly.add(
          allCount == 0 ? 0.0 : ((gCount / allCount) * 100).clamp(0.0, 100.0),
        );
      }

      final periodLabel = period == 'HOY'
          ? '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - ${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}'
          : '${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} - ${end.day.toString().padLeft(2, '0')}/${end.month.toString().padLeft(2, '0')}';

      return {
        'periodLabel': periodLabel,
        'reportesGrupo': reportesGrupo,
        'reportesEsperadosGrupo': reportesEsperadosGrupo,
        'cumplimientoGrupo': cumplimientoGrupo,
        'cumplimientoNivelGrupo': metricBand(cumplimientoGrupo),
        'activosGrupo': activosGrupo,
        'nominalGrupo': nominalGrupo,
        'coberturaGrupo': coberturaGrupo,
        'riesgoGrupo': riesgoGrupo,
        'reportesGlobal': reportesGlobal,
        'cumplimientoGlobal': cumplimientoGlobal,
        'influenciaGrupoReportes': influenciaGrupoReportes,
        'influenciaGrupoActivos': influenciaGrupoActivos,
        'activosGlobal': activosGlobal,
        'laneAlertas': laneAlertas,
        'laneInconsistencias': laneInconsistencias,
        'laneTelemetria': laneTelemetria,
        'periodLabels': periodLabels,
        'periodValues': periodValues,
        'weeklyLabels': weeklyLabels,
        'weeklyValues': weeklyValues,
        'influenceWeekly': influenceWeekly,
      };
    }

    String selectedPeriod = 'HOY';

    Get.dialog(
      StatefulBuilder(
        builder: (context, setStateDialog) {
          final model = computePeriodModel(selectedPeriod);
          final reportesGrupo = (model['reportesGrupo'] as int?) ?? 0;
          final reportesEsperadosGrupo =
              (model['reportesEsperadosGrupo'] as int?) ?? 0;
          final cumplimientoGrupo =
              (model['cumplimientoGrupo'] as num?)?.toDouble() ?? 0;
          final cumplimientoNivelGrupo =
              (model['cumplimientoNivelGrupo'] ?? 'BAJO').toString();
          final activosGrupo = (model['activosGrupo'] as int?) ?? 0;
          final coberturaGrupo =
              (model['coberturaGrupo'] as num?)?.toDouble() ?? 0;
          final riesgoGrupo = (model['riesgoGrupo'] as num?)?.toDouble() ?? 0;
          final reportesGlobal = (model['reportesGlobal'] as int?) ?? 0;
          final cumplimientoGlobal =
              (model['cumplimientoGlobal'] as num?)?.toDouble() ?? 0;
          final influenciaGrupoReportes =
              (model['influenciaGrupoReportes'] as num?)?.toDouble() ?? 0;
          final influenciaGrupoActivos =
              (model['influenciaGrupoActivos'] as num?)?.toDouble() ?? 0;
          final activosGlobal = (model['activosGlobal'] as int?) ?? 0;
          final periodLabel = (model['periodLabel'] ?? '--').toString();

          final laneAlertas =
              ((model['laneAlertas'] as Map?) ?? const <String, dynamic>{})
                  .cast<String, dynamic>();
          final laneInconsistencias = ((model['laneInconsistencias'] as Map?) ??
                  const <String, dynamic>{})
              .cast<String, dynamic>();
          final laneTelemetria =
              ((model['laneTelemetria'] as Map?) ?? const <String, dynamic>{})
                  .cast<String, dynamic>();

          final periodLabels = ((model['periodLabels'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList();
          final periodValues = ((model['periodValues'] as List?) ?? const [])
              .map((e) => (e as num).toDouble())
              .toList();
          final weeklyLabels = ((model['weeklyLabels'] as List?) ?? const [])
              .map((e) => e.toString())
              .toList();
          final weeklyValues = ((model['weeklyValues'] as List?) ?? const [])
              .map((e) => (e as num).toDouble())
              .toList();
          final influenceWeekly =
              ((model['influenceWeekly'] as List?) ?? const [])
                  .map((e) => (e as num).toDouble())
                  .toList();
          final screenSize = MediaQuery.of(context).size;
          final dialogWidth =
              screenSize.width < 1040 ? screenSize.width * 0.96 : 980.0;
          final dialogHeight =
              screenSize.height < 760 ? screenSize.height * 0.92 : 700.0;
          final compact = dialogWidth < 860;

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: dialogWidth,
              height: dialogHeight,
              decoration: BoxDecoration(
                color: AppConstants.darkBg.withValues(alpha: 0.98),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.tealAccent, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.tealAccent.withValues(alpha: 0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.tealAccent.withValues(alpha: 0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              const Icon(
                                Icons.analytics,
                                color: Colors.tealAccent,
                                size: 24,
                              ),
                              Text(
                                'ESTADÍSTICAS GRUPO $currentGroup',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: AppConstants.neonCyan
                                        .withValues(alpha: 0.35),
                                  ),
                                ),
                                child: Text(
                                  'PERIODO $selectedPeriod · $periodLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontFamily: 'Rajdhani',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white54,
                            size: 24,
                          ),
                          onPressed: () => Get.back(),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _buildPeriodChip(
                                label: 'HOY',
                                selected: selectedPeriod == 'HOY',
                                onTap: () => setStateDialog(() {
                                  selectedPeriod = 'HOY';
                                }),
                              ),
                              _buildPeriodChip(
                                label: '7D',
                                selected: selectedPeriod == '7D',
                                onTap: () => setStateDialog(() {
                                  selectedPeriod = '7D';
                                }),
                              ),
                              _buildPeriodChip(
                                label: '30D',
                                selected: selectedPeriod == '30D',
                                onTap: () => setStateDialog(() {
                                  selectedPeriod = '30D';
                                }),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          compact
                              ? Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    SizedBox(
                                      width: (dialogWidth - 56) / 2,
                                      child: _buildTechMetricTile(
                                        code: 'RPT GRUPO',
                                        value: '$reportesGrupo',
                                        unit: 'EVENT',
                                        color: AppConstants.neonCyan,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (dialogWidth - 56) / 2,
                                      child: _buildTechMetricTile(
                                        code: 'CUMP G',
                                        value: cumplimientoGrupo
                                            .toStringAsFixed(1),
                                        unit: '%',
                                        color: AppConstants.neonGreen,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (dialogWidth - 56) / 2,
                                      child: _buildTechMetricTile(
                                        code: 'COV G',
                                        value:
                                            coberturaGrupo.toStringAsFixed(1),
                                        unit: '%',
                                        color: Colors.amberAccent,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (dialogWidth - 56) / 2,
                                      child: _buildTechMetricTile(
                                        code: 'RISK G',
                                        value: riesgoGrupo.toStringAsFixed(1),
                                        unit: 'IDX',
                                        color: riesgoGrupo > 70
                                            ? AppConstants.warningRed
                                            : riesgoGrupo > 40
                                                ? AppConstants.alertOrange
                                                : AppConstants.neonGreen,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _buildTechMetricTile(
                                        code: 'RPT GRUPO',
                                        value: '$reportesGrupo',
                                        unit: 'EVENT',
                                        color: AppConstants.neonCyan,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTechMetricTile(
                                        code: 'CUMP G',
                                        value: cumplimientoGrupo
                                            .toStringAsFixed(1),
                                        unit: '%',
                                        color: AppConstants.neonGreen,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTechMetricTile(
                                        code: 'COV G',
                                        value:
                                            coberturaGrupo.toStringAsFixed(1),
                                        unit: '%',
                                        color: Colors.amberAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTechMetricTile(
                                        code: 'RISK G',
                                        value: riesgoGrupo.toStringAsFixed(1),
                                        unit: 'IDX',
                                        color: riesgoGrupo > 70
                                            ? AppConstants.warningRed
                                            : riesgoGrupo > 40
                                                ? AppConstants.alertOrange
                                                : AppConstants.neonGreen,
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 8),
                          compact
                              ? Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    SizedBox(
                                      width: (dialogWidth - 56) / 2,
                                      child: _buildTechMetricTile(
                                        code: 'RPT GLOBAL',
                                        value: '$reportesGlobal',
                                        unit: 'EVENT',
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (dialogWidth - 56) / 2,
                                      child: _buildTechMetricTile(
                                        code: 'CUMP GLB',
                                        value: cumplimientoGlobal
                                            .toStringAsFixed(1),
                                        unit: '%',
                                        color: Colors.lightBlueAccent,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (dialogWidth - 56) / 2,
                                      child: _buildTechMetricTile(
                                        code: 'INFL RPT',
                                        value: influenciaGrupoReportes
                                            .toStringAsFixed(1),
                                        unit: '%',
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                    SizedBox(
                                      width: (dialogWidth - 56) / 2,
                                      child: _buildTechMetricTile(
                                        code: 'INFL ACT',
                                        value: influenciaGrupoActivos
                                            .toStringAsFixed(1),
                                        unit: '%',
                                        color: Colors.purpleAccent,
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _buildTechMetricTile(
                                        code: 'RPT GLOBAL',
                                        value: '$reportesGlobal',
                                        unit: 'EVENT',
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTechMetricTile(
                                        code: 'CUMP GLB',
                                        value: cumplimientoGlobal
                                            .toStringAsFixed(1),
                                        unit: '%',
                                        color: Colors.lightBlueAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTechMetricTile(
                                        code: 'INFL RPT',
                                        value: influenciaGrupoReportes
                                            .toStringAsFixed(1),
                                        unit: '%',
                                        color: Colors.orangeAccent,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildTechMetricTile(
                                        code: 'INFL ACT',
                                        value: influenciaGrupoActivos
                                            .toStringAsFixed(1),
                                        unit: '%',
                                        color: Colors.purpleAccent,
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.22),
                              border: Border.all(
                                color: AppConstants.neonCyan
                                    .withValues(alpha: 0.28),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Lectura inmediata grupo: $reportesGrupo / $reportesEsperadosGrupo reportes (${cumplimientoGrupo.toStringAsFixed(1)}%) | Nivel $cumplimientoNivelGrupo | Activos $activosGrupo/$nominalGrupo',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.86),
                                    fontFamily: 'Rajdhani',
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Influencia del grupo en global: Reportes ${influenciaGrupoReportes.toStringAsFixed(1)}% | Activos ${influenciaGrupoActivos.toStringAsFixed(1)}% ($activosGrupo/$activosGlobal).',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.62),
                                    fontFamily: 'Rajdhani',
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                compact
                                    ? Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          SizedBox(
                                            width: (dialogWidth - 56) / 2,
                                            child: _buildLaneSummaryTile(
                                              title: 'ALERTAS',
                                              lane: laneAlertas,
                                              accent: AppConstants.neonPink,
                                            ),
                                          ),
                                          SizedBox(
                                            width: (dialogWidth - 56) / 2,
                                            child: _buildLaneSummaryTile(
                                              title: 'INCONSISTENCIAS',
                                              lane: laneInconsistencias,
                                              accent: AppConstants.alertOrange,
                                            ),
                                          ),
                                          SizedBox(
                                            width: (dialogWidth - 56) / 2,
                                            child: _buildLaneSummaryTile(
                                              title: 'TELEMETRÍA',
                                              lane: laneTelemetria,
                                              accent: AppConstants.neonCyan,
                                            ),
                                          ),
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(
                                            child: _buildLaneSummaryTile(
                                              title: 'ALERTAS',
                                              lane: laneAlertas,
                                              accent: AppConstants.neonPink,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildLaneSummaryTile(
                                              title: 'INCONSISTENCIAS',
                                              lane: laneInconsistencias,
                                              accent: AppConstants.alertOrange,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: _buildLaneSummaryTile(
                                              title: 'TELEMETRÍA',
                                              lane: laneTelemetria,
                                              accent: AppConstants.neonCyan,
                                            ),
                                          ),
                                        ],
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          compact
                              ? Column(
                                  children: [
                                    SizedBox(
                                      height: 220,
                                      child: _buildChartPanel(
                                        title: selectedPeriod == 'HOY'
                                            ? 'ACTIVIDAD DIARIA (3H) · GRUPO'
                                            : 'ACTIVIDAD PERÍODO · GRUPO',
                                        child: _buildBarChart(
                                          labels: periodLabels,
                                          data: periodValues,
                                          colors: List<Color>.filled(
                                            periodLabels.length,
                                            AppConstants.neonCyan,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 220,
                                      child: _buildChartPanel(
                                        title: 'ACTIVIDAD SEMANAL · GRUPO',
                                        child: _buildBarChart(
                                          labels: weeklyLabels,
                                          data: weeklyValues,
                                          colors: List<Color>.filled(
                                            weeklyLabels.length,
                                            AppConstants.neonGreen,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      height: 220,
                                      child: _buildChartPanel(
                                        title:
                                            'INFLUENCIA SEMANAL EN GLOBAL (%)',
                                        child: _buildLineChart(
                                          data: influenceWeekly,
                                          color: Colors.orangeAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Row(
                                  children: [
                                    Expanded(
                                      child: _buildChartPanel(
                                        title: selectedPeriod == 'HOY'
                                            ? 'ACTIVIDAD DIARIA (3H) · GRUPO'
                                            : 'ACTIVIDAD PERÍODO · GRUPO',
                                        child: _buildBarChart(
                                          labels: periodLabels,
                                          data: periodValues,
                                          colors: List<Color>.filled(
                                            periodLabels.length,
                                            AppConstants.neonCyan,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildChartPanel(
                                        title: 'ACTIVIDAD SEMANAL · GRUPO',
                                        child: _buildBarChart(
                                          labels: weeklyLabels,
                                          data: weeklyValues,
                                          colors: List<Color>.filled(
                                            weeklyLabels.length,
                                            AppConstants.neonGreen,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildChartPanel(
                                        title:
                                            'INFLUENCIA SEMANAL EN GLOBAL (%)',
                                        child: _buildLineChart(
                                          data: influenceWeekly,
                                          color: Colors.orangeAccent,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final color = selected ? AppConstants.neonCyan : Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppConstants.neonCyan.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? AppConstants.neonCyan.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.25),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontFamily: 'Orbitron',
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildTechMetricTile({
    required String code,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            code,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            unit,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 9,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLaneSummaryTile({
    required String title,
    required Map<String, dynamic> lane,
    required Color accent,
  }) {
    int asInt(dynamic value) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      return 0;
    }

    final total = asInt(lane['total']);
    final alta = asInt(lane['alta']);
    final media = asInt(lane['media']);
    final baja = asInt(lane['baja']);
    final nivel = (lane['nivel'] ?? 'NORMAL').toString().toUpperCase();
    final levelColor = _laneLevelColor(nivel);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: accent,
              fontSize: 9,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                'NIVEL: $nivel',
                style: TextStyle(
                  color: levelColor,
                  fontSize: 9,
                  fontFamily: 'Orbitron',
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                'TOT $total',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'A:$alta  M:$media  B:$baja',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 10,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Color _laneLevelColor(String level) {
    switch (level) {
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

  String _weekdayShort(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'L';
      case DateTime.tuesday:
        return 'M';
      case DateTime.wednesday:
        return 'X';
      case DateTime.thursday:
        return 'J';
      case DateTime.friday:
        return 'V';
      case DateTime.saturday:
        return 'S';
      case DateTime.sunday:
        return 'D';
      default:
        return '--';
    }
  }

  Widget _buildChartPanel({
    required String title,
    required Widget child,
    double height = 190,
  }) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 10,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Expanded(child: child),
        ],
      ),
    );
  }

  Widget _buildLineChart({
    required List<double> data,
    required Color color,
  }) {
    final safeData = data.isEmpty ? const [0.0] : data;
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(
              safeData.length,
              (i) => FlSpot(i.toDouble(), safeData[i]),
            ),
            isCurved: true,
            barWidth: 2.2,
            color: color,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart({
    required List<String> labels,
    required List<double> data,
    required List<Color> colors,
  }) {
    final maxValue = data.isEmpty
        ? 1.0
        : data.reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return BarChart(
      BarChartData(
        maxY: maxValue * 1.2,
        barGroups: List.generate(
          labels.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: i < data.length ? data[i] : 0,
                color: i < colors.length ? colors[i] : Colors.white70,
                width: 16,
                borderRadius: BorderRadius.circular(3),
              ),
            ],
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.white.withValues(alpha: 0.08),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(
                  labels[index],
                  style: const TextStyle(
                    color: Colors.white60,
                    fontFamily: 'Rajdhani',
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    Color color,
    IconData icon, {
    bool compact = false,
  }) {
    final iconSize = compact ? 20.0 : 32.0;
    final valueSize = compact ? 17.0 : 24.0;
    final titleSize = compact ? 9.0 : 10.0;
    final padding = compact ? 8.0 : 16.0;
    final vSpace = compact ? 4.0 : 8.0;

    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: iconSize),
          SizedBox(height: vSpace),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: valueSize,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: compact ? 2 : 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: titleSize,
              fontFamily: 'Rajdhani',
            ),
          ),
        ],
      ),
    );
  }
}

// --- PINTORES TÁCTICOS (Tron Legacy Glow) ---

class _TronFramePainter extends CustomPainter {
  final Color color;
  _TronFramePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    double l = 20.0;

    // Esquinas tácticas
    // Superior Izquierda
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, 0)
        ..lineTo(l, 0),
      glowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, l)
        ..lineTo(0, 0)
        ..lineTo(l, 0),
      paint,
    );

    // Superior Derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - l, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, l),
      glowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - l, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, l),
      paint,
    );

    // Inferior Izquierda
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - l)
        ..lineTo(0, size.height)
        ..lineTo(l, size.height),
      glowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - l)
        ..lineTo(0, size.height)
        ..lineTo(l, size.height),
      paint,
    );

    // Inferior Derecha
    canvas.drawPath(
      Path()
        ..moveTo(size.width - l, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - l),
      glowPaint,
    );
    canvas.drawPath(
      Path()
        ..moveTo(size.width - l, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - l),
      paint,
    );

    // Bordes sutiles
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
