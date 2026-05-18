import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;

import '../../core/constants/app_constants.dart';
import '../../core/services/dtex_android_tracking_service.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/dtex_destino_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/models/parte_sorpresa_model.dart';
import '../../data/models/radio_message_model.dart';
import '../../data/repositories/dtex_repository.dart';
import '../../data/repositories/supabase_repository.dart';
import '../widgets/dashboard_initialization_overlay.dart';

// ─────────────────────────────────────────────
// APP ROOT
// ─────────────────────────────────────────────

class DtexCustodioAndroidApp extends StatelessWidget {
  const DtexCustodioAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DTEX Custodio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFF071014),
      ),
      home: const _DtexCustodioSplashGate(),
    );
  }
}

class _DtexCustodioSplashGate extends StatefulWidget {
  const _DtexCustodioSplashGate();

  @override
  State<_DtexCustodioSplashGate> createState() =>
      _DtexCustodioSplashGateState();
}

class _DtexCustodioSplashGateState extends State<_DtexCustodioSplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return DashboardInitializationOverlay(
        logosOnly: true,
        onInitializationComplete: () {
          if (mounted) {
            setState(() => _showSplash = false);
          }
        },
      );
    }

    return const DtexCustodioAndroidHome();
  }
}

// ─────────────────────────────────────────────
// HOME
// ─────────────────────────────────────────────

class DtexCustodioAndroidHome extends StatefulWidget {
  const DtexCustodioAndroidHome({super.key});

  @override
  State<DtexCustodioAndroidHome> createState() =>
      _DtexCustodioAndroidHomeState();
}

class _DtexCustodioAndroidHomeState extends State<DtexCustodioAndroidHome> {
  final _dtexRepository = DtexRepository();
  final _radioRepository = SupabaseRepository();
  final _tracking = DtexAndroidTrackingService();
  final _nombreController = TextEditingController();
  final _codigoController = TextEditingController();
  final _mapController = MapController();

  static const double _routeRefreshDistanceMeters = 60;
  static const Duration _routeRefreshInterval = Duration(minutes: 2);
  static const Duration _appBackgroundAlertCooldown = Duration(minutes: 5);
  static const Duration _missionStartAlarmLead = Duration(minutes: 15);
  static const Duration _missionStartAlarmGrace = Duration(minutes: 30);
  static const Duration _missionStartAlarmCooldown = Duration(minutes: 3);

  DtexMision? _mission;
  DtexDestino? _destino;
  DtexTelemetrySnapshot? _telemetry;
  List<LatLng> _streetRoute = <LatLng>[];
  LatLng? _lastRouteOrigin;
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  DateTime? _lastRouteFetchAt;
  String? _error;
  String _status = 'Esperando acceso de custodio.';
  bool _loading = false;
  bool _trackingActive = false;
  bool _startingTracking = false;
  bool _routeLoading = false;
  bool _mapReady = false;
  DateTime? _lastAppBackgroundAlertAt;
  DateTime? _lastMissionStartAlarmAt;
  bool _missionStartDialogOpen = false;
  Timer? _missionStartAlarmTimer;
  StreamSubscription<List<ParteSorpresa>>? _partesSub;
  List<ParteSorpresa> _partesPendientes = <ParteSorpresa>[];
  final _partesReadMarkedIds = <String>{};
  final _notifications = FlutterLocalNotificationsPlugin();
  late final _LifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _LifecycleObserver(_handleLifecycle);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
    unawaited(_initializeMissionAlarmNotifications());
    _requestCriticalPermissions();
    // Intentar restaurar sesión si el proceso fue reiniciado en medio de una misión
    WidgetsBinding.instance.addPostFrameCallback((_) => _restaurarSesion());
  }

  Future<void> _requestCriticalPermissions() async {
    try {
      await _tracking.requestOperationalPermissions();
    } catch (e) {
      debugPrint('Error solicitando permisos: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    // IMPORTANTE: NO detener el tracking aquí si la misión está activa.
    // El foreground service debe seguir corriendo aunque el widget se destruya.
    // Solo se detiene explícitamente desde _closeMission() o _logout().
    _missionStartAlarmTimer?.cancel();
    _partesSub?.cancel();
    if (!_mustStayInMission) {
      _tracking.stop();
    }
    _nombreController.dispose();
    _codigoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_mustStayInMission,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mustStayInMission) {
          _showMissionLockMessage();
        }
      },
      child: Scaffold(
        backgroundColor: _hasActiveInfraction ? const Color(0xFF22070B) : null,
        body: SafeArea(
          child: _mission == null ? _buildLogin() : _buildDashboard(),
        ),
      ),
    );
  }

  // ── LOGIN con UI estilo SCCP ──────────────────

  Widget _buildLogin() {
    return _DtexLoginScreen(
      nombreController: _nombreController,
      codigoController: _codigoController,
      loading: _loading,
      error: _error,
      onLogin: _login,
    );
  }

  // ── DASHBOARD ────────────────────────────────

  Widget _buildDashboard() {
    final mission = _mission!;
    final destino = _destino;
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
      children: [
        _header(mission),
        if (_hasActiveInfraction) ...[
          const SizedBox(height: 10),
          _infractionBanner(),
        ],
        const SizedBox(height: 10),
        _missionCard(mission),
        const SizedBox(height: 10),
        _destinationCard(destino),
        const SizedBox(height: 10),
        _mapCard(destino),
        const SizedBox(height: 10),
        _actionsCard(mission),
        const SizedBox(height: 10),
        if (_partesPendientes.isNotEmpty) ...[
          _partesSorpresaCard(),
          const SizedBox(height: 10),
        ],
        _telemetryCard(),
        const SizedBox(height: 10),
        _communicationsCard(mission),
      ],
    );
  }

  Widget _header(DtexMision mission) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (_hasActiveInfraction
                  ? AppConstants.warningRed
                  : AppConstants.neonCyan)
              .withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: (_hasActiveInfraction
                    ? AppConstants.warningRed
                    : AppConstants.neonCyan)
                .withValues(alpha: 0.08),
            blurRadius: 14,
          ),
        ],
      ),
      child: Row(
        children: [
          Image.asset(
            'assets/images/logo.png',
            width: 48,
            height: 48,
            color: _hasActiveInfraction ? Colors.red : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.custodioNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'Orbitron',
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                Text(
                  mission.estadoDisplay,
                  style: TextStyle(
                    color: _stateColor(mission.estado),
                    fontWeight: FontWeight.w800,
                    fontFamily: 'Rajdhani',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _canDisconnect ? _logout : _showMissionLockMessage,
            icon: const Icon(Icons.power_settings_new_rounded),
            color: _canDisconnect ? Colors.white70 : Colors.white24,
          ),
        ],
      ),
    );
  }

  Widget _missionCard(DtexMision mission) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.assignment_ind_rounded, 'Custodio e interno'),
          const SizedBox(height: 10),
          _row('Grado', mission.custodioGrado),
          _row('Custodio', mission.custodioNombre),
          _row('Interno', mission.reoNombre),
          _row('CI interno', mission.reoCi),
        ],
      ),
    );
  }

  Widget _destinationCard(DtexDestino? destino) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.location_on_rounded, 'Destino'),
          const SizedBox(height: 10),
          _row('Nombre', destino?.nombre ?? _mission?.destinoNombre ?? 'N/D'),
          _row('Dirección', destino?.direccion ?? 'N/D'),
          _row('Tiempo autorizado', '${_mission?.tiempoMaxEstadiMin ?? 0} min'),
          _row('Distancia', _distanceLabel),
          _row('ETA', _etaLabel),
        ],
      ),
    );
  }

  Widget _mapCard(DtexDestino? destino) {
    final current = _currentLatLng;
    final destination =
        destino == null ? null : LatLng(destino.latitud, destino.longitud);
    final center = current ??
        destination ??
        const LatLng(
            AppConstants.defaultLatitude, AppConstants.defaultLongitude);
    final fallbackLine = <LatLng>[
      if (current != null) current,
      if (destination != null) destination,
    ];
    final route = _streetRoute.length >= 2 ? _streetRoute : <LatLng>[];

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.neonCyan.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppConstants.neonCyan.withValues(alpha: 0.06),
            blurRadius: 12,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 310,
          child: FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: current != null && destination != null ? 13 : 15,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onMapReady: () {
                _mapReady = true;
                _focusMapOnOperationalPoints();
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'sccp_command_center.dtex_custodio',
              ),
              if (route.isEmpty && fallbackLine.length == 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: fallbackLine,
                      color: Colors.white24,
                      strokeWidth: 2,
                    ),
                  ],
                ),
              if (route.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: route,
                      color: AppConstants.neonCyan,
                      strokeWidth: 4,
                    ),
                  ],
                ),
              if (destino != null)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: LatLng(destino.latitud, destino.longitud),
                      radius: math.max(destino.radioMetros.toDouble(), 60),
                      useRadiusInMeter: true,
                      color: AppConstants.successGreen.withValues(alpha: 0.12),
                      borderColor: AppConstants.successGreen,
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  if (destination != null)
                    Marker(
                      point: destination,
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppConstants.successGreen,
                        size: 34,
                      ),
                    ),
                  if (current != null)
                    Marker(
                      point: current,
                      width: 42,
                      height: 42,
                      child: const Icon(
                        Icons.navigation_rounded,
                        color: AppConstants.neonCyan,
                        size: 34,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionsCard(DtexMision mission) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(Icons.touch_app_rounded, 'Acciones'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                _trackingActive || _startingTracking ? null : _startMission,
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.successGreen,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(54),
            ),
            icon: _startingTracking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.play_arrow_rounded),
            label: Text(_startingTracking ? 'Activando' : 'Empezar diligencia'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _mission != null ? _confirmEmergency : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppConstants.warningRed,
              side: BorderSide(
                color: _mission != null
                    ? AppConstants.warningRed
                    : AppConstants.warningRed.withValues(alpha: 0.35),
              ),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('Emergencia'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _canCloseMission ? _closeMission : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.done_all_rounded),
            label: const Text('Concluir diligencia'),
          ),
          const SizedBox(height: 10),
          Text(_status, style: _mutedStyle()),
        ],
      ),
    );
  }

  Widget _infractionBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.warningRed.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppConstants.warningRed),
        boxShadow: [
          BoxShadow(
            color: AppConstants.warningRed.withValues(alpha: 0.15),
            blurRadius: 16,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: AppConstants.warningRed),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _telemetryCard() {
    final telemetry = _telemetry;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(Icons.sensors_rounded, 'Telemetría'),
          const SizedBox(height: 10),
          _row(
            'GPS',
            telemetry == null
                ? 'Pendiente'
                : '${telemetry.position.latitude.toStringAsFixed(6)}, ${telemetry.position.longitude.toStringAsFixed(6)}',
          ),
          _row(
            'Batería',
            telemetry?.batteryPct == null ? 'N/D' : '${telemetry!.batteryPct}%',
          ),
          _row('Red', telemetry?.networkStatus ?? 'N/D'),
          _row(
            'Último reporte',
            telemetry == null ? 'N/D' : _timeLabel(telemetry.timestamp),
          ),
        ],
      ),
    );
  }

  Widget _communicationsCard(DtexMision mission) {
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(Icons.radio_rounded, 'Comunicaciones'),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: () => _openRadioPage(mission),
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.neonCyan,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.forum_rounded),
            label: const Text('Abrir radio operativa'),
          ),
        ],
      ),
    );
  }

  Widget _partesSorpresaCard() {
    final parte = _partesPendientes.first;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _sectionTitle(Icons.assignment_late_rounded, 'Parte sorpresa'),
          const SizedBox(height: 10),
          Text(
            parte.razon,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Solicitado por ${parte.supervisorNombre ?? 'Supervisor'} · ${parte.tiempoDisplay}',
            style: _mutedStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => _responderParteSorpresa(parte),
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.alertOrange,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(50),
            ),
            icon: const Icon(Icons.assignment_turned_in_rounded),
            label: const Text('Responder ahora'),
          ),
        ],
      ),
    );
  }

  // ── SHARED WIDGETS ────────────────────────────

  Widget _panel({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: AppConstants.neonCyan, size: 20),
        const SizedBox(width: 8),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: AppConstants.neonCyan,
            fontFamily: 'Rajdhani',
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(label, style: _mutedStyle(fontSize: 13)),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/D' : value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _mutedStyle({double fontSize = 14}) {
    return TextStyle(
      color: Colors.white.withValues(alpha: 0.68),
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
  }

  // ── LÓGICA ────────────────────────────────────

  Future<void> _login() async {
    final nombre = _nombreController.text.trim();
    final codigo = _codigoController.text.trim();
    final nombreTokens =
        nombre.split(RegExp(r'\s+')).where((t) => t.length >= 2).length;
    if (nombreTokens < 2 || codigo.length < 4) {
      setState(() => _error =
          'Ingresa al menos dos palabras del nombre y el código de seguridad.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final response = await _dtexRepository.validarAccesoCustodio(
      nombre: nombre,
      codigo: codigo,
    );

    final mission = _missionFromResponse(response);
    final destino = _destinoFromResponse(response);

    if (!mounted) return;
    if (mission == null) {
      setState(() {
        _loading = false;
        _error = response['error']?.toString() ??
            'Acceso rechazado. Verifica nombre y código.';
      });
      return;
    }

    final resolvedDestino =
        destino ?? await _dtexRepository.getDestinoById(mission.idDestino);
    if (!mounted) return;
    setState(() {
      _mission = mission;
      _destino = resolvedDestino;
      _loading = false;
      _status = 'Misión cargada. Solicita permisos antes de salir.';
    });
    _armMissionStartAlarm();
    _subscribePartesSorpresa(mission.custodioCodigo);

    await _primeGps();
  }

  void _subscribePartesSorpresa(String codigoCustodio) {
    final codigo = codigoCustodio.trim();
    _partesSub?.cancel();
    _partesPendientes = <ParteSorpresa>[];
    _partesReadMarkedIds.clear();
    if (codigo.isEmpty) return;

    _partesSub = _radioRepository.watchPartesPendientes().listen((rows) {
      final pendientes = rows
          .where((p) =>
              p.idOficial.trim() == codigo &&
              (p.estadoNormalized == 'NUEVO' ||
                  p.estadoNormalized == 'PENDIENTE' ||
                  p.estadoNormalized == 'LEIDO'))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
      for (final parte in pendientes) {
        if (_partesReadMarkedIds.add(parte.idSorpresa)) {
          unawaited(
            _radioRepository.actualizarEstadoParte(parte.idSorpresa, 'LEIDO'),
          );
        }
      }
      if (!mounted) return;
      setState(() => _partesPendientes = pendientes);
    });
  }

  Future<void> _responderParteSorpresa(ParteSorpresa parte) async {
    final controller = TextEditingController();
    final response = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppConstants.alertOrange),
        ),
        title: const Text(
          'PARTE SORPRESA',
          style: TextStyle(
            color: AppConstants.alertOrange,
            fontFamily: 'Orbitron',
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              parte.razon,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              minLines: 3,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Respuesta / novedad',
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    controller.dispose();
    final text = response?.trim() ?? '';
    if (text.isEmpty) return;

    final point = _telemetry?.position;
    final ok = await _radioRepository.actualizarEstadoParte(
      parte.idSorpresa,
      'COMPLETADO',
      respuestaOficial: text,
      latitud: point?.latitude,
      longitud: point?.longitude,
    );
    if (!mounted) return;
    setState(() {
      if (ok) {
        _partesPendientes.removeWhere((p) => p.idSorpresa == parte.idSorpresa);
        _status = 'Parte sorpresa enviado al supervisor.';
      } else {
        _status = 'No se pudo enviar el parte sorpresa.';
      }
    });
  }

  Future<void> _primeGps() async {
    try {
      final position = await _tracking.currentPosition();
      if (!mounted || position == null) return;
      setState(() {
        _telemetry = DtexTelemetrySnapshot(
          position: position,
          batteryPct: null,
          networkStatus: 'N/D',
          locationServiceEnabled: true,
          timestamp: DateTime.now(),
        );
      });
      // Forzar actualización de ruta inmediatamente
      _updateStreetRoute(force: true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'GPS pendiente. Se solicitarán permisos al iniciar.';
      });
    }
  }

  Future<void> _startMission() async {
    final mission = _mission;
    final destino = _destino;
    if (mission == null || destino == null || _startingTracking) return;

    setState(() {
      _startingTracking = true;
      _status = 'Solicitando permisos operativos...';
    });
    final permissionsOk = await _tracking.requestOperationalPermissions();
    if (!mounted) return;
    if (!permissionsOk) {
      setState(() {
        _startingTracking = false;
        _trackingActive = false;
        _status = 'Permisos incompletos. Activa ubicación precisa.';
      });
      return;
    }

    setState(() => _status = 'Activando seguimiento GPS...');
    final missionEnRuta = mission.copyWith(
      estado: DtexMision.estadoEnRuta,
      tsInicioReal: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final trackingStarted = await _tracking.start(
      mission: missionEnRuta,
      destino: destino,
      ensurePermissions: false,
      onTelemetry: (snapshot) {
        if (!mounted) return;
        setState(() => _telemetry = snapshot);
        _focusMapOnOperationalPoints();
        unawaited(_updateStreetRoute());
      },
      onStatus: (message) {
        if (!mounted) return;
        setState(() {
          _status = message;
          if (message.toLowerCase().contains('destino')) {
            _mission = _mission?.copyWith(
              estado: DtexMision.estadoEnDestino,
              tsLlegadaDestino: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          } else if (message.toLowerCase().contains('retorno') ||
              message.toLowerCase().contains('ruta')) {
            _mission = _mission?.copyWith(
              estado: DtexMision.estadoRetorno,
              tsSalidaDestino: DateTime.now(),
              updatedAt: DateTime.now(),
            );
          }
        });
      },
    );
    if (!mounted) return;
    if (!trackingStarted) {
      setState(() {
        _startingTracking = false;
        _trackingActive = false;
        _status = 'No se pudo iniciar el seguimiento GPS.';
      });
      return;
    }

    setState(() => _status = 'Sincronizando inicio con DTEX...');
    final current = _telemetry?.position;
    final ok = await _dtexRepository.cambiarEstadoMision(
      idMision: mission.idMision,
      estado: DtexMision.estadoEnRuta,
      lat: current?.latitude,
      lng: current?.longitude,
    );
    if (!mounted) return;
    if (!ok) {
      await _tracking.stop();
      if (!mounted) return;
      setState(() {
        _startingTracking = false;
        _trackingActive = false;
        _status = 'No se pudo iniciar la diligencia en DTEX.';
      });
      return;
    }

    setState(() {
      _startingTracking = false;
      _trackingActive = true;
      _mission = missionEnRuta;
      _status = 'Diligencia en ruta. Tracking activo.';
    });
    _cancelMissionStartAlarm();
    // Persistir sesión inmediatamente al activar tracking
    unawaited(_persistirSesion());
  }

  Future<void> _confirmEmergency() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppConstants.warningRed),
        ),
        title: const Row(
          children: [
            Icon(Icons.emergency_rounded, color: AppConstants.warningRed),
            SizedBox(width: 8),
            Text(
              'EMERGENCIA',
              style: TextStyle(
                color: AppConstants.warningRed,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
        content: const Text(
          'Esto notifica al supervisor con tu ubicación actual como EMERGENCIA. ¿Confirmar?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child:
                const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.warningRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('CONFIRMAR EMERGENCIA',
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 12)),
          ),
        ],
      ),
    );
    if (confirmed == true) await _reportEmergency();
  }

  Future<void> _reportEmergency() async {
    final mission = _mission;
    if (mission == null) return;
    var point = _telemetry?.position;
    try {
      point ??= await _tracking.currentPosition();
    } catch (_) {
      point = null;
    }
    if (point != null && mounted) {
      setState(() {
        _telemetry = DtexTelemetrySnapshot(
          position: point!,
          batteryPct: _telemetry?.batteryPct,
          networkStatus: _telemetry?.networkStatus ?? 'N/D',
          locationServiceEnabled: true,
          timestamp: DateTime.now(),
        );
      });
    }
    final ok = await _dtexRepository.cambiarEstadoMision(
      idMision: mission.idMision,
      estado: DtexMision.estadoEmergencia,
      lat: point?.latitude,
      lng: point?.longitude,
    );
    final alertOk = await _dtexRepository.insertarAlerta(
      idMision: mission.idMision,
      tipo: 'EMERGENCIA_CUSTODIO',
      severidad: 'CRITICA',
      descripcion:
          'Botón de emergencia activado por ${mission.custodioNombre}.',
      latitud: point?.latitude,
      longitud: point?.longitude,
    );
    final radioOk = await _radioRepository.sendRadioMessage(
      idOficial: mission.custodioCodigo,
      fromUser: 'DTEX:${mission.custodioNombre}',
      toUser: 'SUPERVISOR',
      message: point == null
          ? 'EMERGENCIA DTEX ACTIVADA. Ubicación pendiente.'
          : 'EMERGENCIA DTEX ACTIVADA. Ubicación: '
              '${point.latitude.toStringAsFixed(6)}, '
              '${point.longitude.toStringAsFixed(6)}',
      type: 'RADIO',
    );
    if (!mounted) return;
    setState(() {
      final reported = ok || alertOk || radioOk;
      _status = reported
          ? 'Emergencia enviada al supervisor.'
          : 'No se pudo reportar emergencia.';
      if (reported) {
        _mission = mission.copyWith(
          estado: DtexMision.estadoEmergencia,
          updatedAt: DateTime.now(),
        );
      }
    });
  }

  Future<void> _closeMission() async {
    final mission = _mission;
    if (mission == null) return;
    final point = _telemetry?.position;
    final ok = await _dtexRepository.cambiarEstadoMision(
      idMision: mission.idMision,
      estado: DtexMision.estadoCompletada,
      lat: point?.latitude,
      lng: point?.longitude,
    );
    if (!mounted) return;
    if (ok) {
      await _tracking.stop();
      await _partesSub?.cancel();
      _cancelMissionStartAlarm();
      await _limpiarSesionPersistida(); // borrar sesión guardada al cerrar correctamente
    }
    setState(() {
      _trackingActive = false;
      _status = ok
          ? 'Misión cerrada. La app se cerrará automáticamente.'
          : 'Cierre fallido.';
      if (ok) {
        _mission = mission.copyWith(
          estado: DtexMision.estadoCompletada,
          tsCierre: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
    });
    if (ok) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      await SystemNavigator.pop();
    }
  }

  Future<void> _handleLifecycle(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // App va a segundo plano durante misión activa
        if (!_mustStayInMission) return;
        // Persistir sesión para poder restaurarla si el proceso muere
        await _persistirSesion();
        // Registrar alerta (con cooldown para no saturar)
        final now = DateTime.now();
        final last = _lastAppBackgroundAlertAt;
        if (last == null ||
            now.difference(last) >= _appBackgroundAlertCooldown) {
          _lastAppBackgroundAlertAt = now;
          final mission = _mission;
          final point = _telemetry?.position;
          if (mission != null) {
            await _dtexRepository.insertarAlerta(
              idMision: mission.idMision,
              tipo: 'APP_SUSPENDIDA',
              severidad: 'AVISO',
              descripcion:
                  'La app DTEX custodio fue enviada a segundo plano durante una misión activa.',
              latitud: point?.latitude,
              longitud: point?.longitude,
            );
          }
        }
      case AppLifecycleState.resumed:
        // App vuelve al frente: restaurar sesión si el state se perdió
        if (_mission == null) {
          await _restaurarSesion();
        }
      case AppLifecycleState.detached:
        // Proceso a punto de terminar: persistir por si acaso
        if (_mustStayInMission) await _persistirSesion();
    }
  }

  /// Guarda misión y código en almacenamiento local para sobrevivir reinicios de proceso.
  Future<void> _persistirSesion() async {
    try {
      final mission = _mission;
      if (mission == null) return;
      final prefs = await _getSharedPreferences();
      await prefs.setString('dtex_mission_id', mission.idMision);
      await prefs.setString('dtex_custodio_codigo', mission.custodioCodigo);
      await prefs.setString('dtex_custodio_nombre', mission.custodioNombre);
      await prefs.setBool('dtex_tracking_active', _trackingActive);
    } catch (e) {
      debugPrint('Error persistiendo sesión DTEX: $e');
    }
  }

  /// Intenta restaurar la sesión desde almacenamiento local tras reinicio de proceso.
  Future<void> _restaurarSesion() async {
    try {
      final prefs = await _getSharedPreferences();
      final misionId = await prefs.getString('dtex_mission_id');
      final wasTracking = await prefs.getBool('dtex_tracking_active') ?? false;
      if (misionId == null || !wasTracking) return;
      // getMisionById devuelve DtexMision? directamente (no Map)
      final mission = await _dtexRepository.getMisionById(misionId);
      if (!mounted) return;
      if (mission == null || !mission.estaActiva) {
        await _limpiarSesionPersistida();
        return;
      }
      final destino = await _dtexRepository.getDestinoById(mission.idDestino);
      if (!mounted) return;
      setState(() {
        _mission = mission;
        _destino = destino;
        _trackingActive = false; // se reactivará al tocar "Empezar diligencia"
        _status = 'Sesión restaurada. Reactiva el seguimiento GPS.';
      });
      _armMissionStartAlarm();
      _subscribePartesSorpresa(mission.custodioCodigo);
    } catch (e) {
      debugPrint('Error restaurando sesión DTEX: $e');
    }
  }

  Future<void> _limpiarSesionPersistida() async {
    try {
      final prefs = await _getSharedPreferences();
      await prefs.remove('dtex_mission_id');
      await prefs.remove('dtex_custodio_codigo');
      await prefs.remove('dtex_custodio_nombre');
      await prefs.remove('dtex_tracking_active');
    } catch (_) {}
  }

  // Lazy getter para SharedPreferences sin añadir dependencia nueva:
  // usa el método de platform channel ya disponible en flutter/services.dart
  Future<_SimplePrefs> _getSharedPreferences() async {
    return _SimplePrefs._instance;
  }

  Future<void> _logout() async {
    if (_mustStayInMission) {
      _showMissionLockMessage();
      return;
    }
    await _tracking.stop();
    await _partesSub?.cancel();
    _cancelMissionStartAlarm();
    await _limpiarSesionPersistida();
    if (!mounted) return;
    setState(() {
      _mission = null;
      _destino = null;
      _telemetry = null;
      _streetRoute = <LatLng>[];
      _lastRouteOrigin = null;
      _routeDistanceMeters = null;
      _routeDurationSeconds = null;
      _lastRouteFetchAt = null;
      _routeLoading = false;
      _partesPendientes = <ParteSorpresa>[];
      _partesReadMarkedIds.clear();
      _trackingActive = false;
      _startingTracking = false;
      _status = 'Esperando acceso de custodio.';
      _error = null;
    });
  }

  Future<void> _openRadioPage(DtexMision mission) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DtexCustodioRadioPage(
          mission: mission,
          repository: _radioRepository,
          currentPoint: _currentLatLng,
        ),
      ),
    );
  }

  Future<void> _initializeMissionAlarmNotifications() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings: settings);
  }

  void _armMissionStartAlarm() {
    _missionStartAlarmTimer?.cancel();
    _lastMissionStartAlarmAt = null;
    _checkMissionStartAlarm();
    _missionStartAlarmTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkMissionStartAlarm(),
    );
  }

  void _cancelMissionStartAlarm() {
    _missionStartAlarmTimer?.cancel();
    _missionStartAlarmTimer = null;
    _lastMissionStartAlarmAt = null;
    _missionStartDialogOpen = false;
  }

  void _checkMissionStartAlarm() {
    final mission = _mission;
    if (mission == null || _trackingActive || _startingTracking) return;
    if (mission.estadoNormalizado != DtexMision.estadoAbierta &&
        mission.estadoNormalizado != DtexMision.estadoRegistroRealizado) {
      return;
    }

    final now = DateTime.now();
    final startsAt = mission.horaSalidaAutorizada;
    final untilStart = startsAt.difference(now);
    final isNearStart = untilStart <= _missionStartAlarmLead &&
        untilStart >= -_missionStartAlarmGrace;
    if (!isNearStart) return;

    final last = _lastMissionStartAlarmAt;
    if (last != null && now.difference(last) < _missionStartAlarmCooldown) {
      return;
    }
    _lastMissionStartAlarmAt = now;
    unawaited(_showMissionStartAlarm(mission, untilStart));
  }

  Future<void> _showMissionStartAlarm(
    DtexMision mission,
    Duration untilStart,
  ) async {
    final minutes = untilStart.inMinutes;
    final body = minutes >= 1
        ? 'La misión inicia en $minutes min. Activa la diligencia.'
        : 'La hora autorizada ya llegó. Activa la diligencia ahora.';

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'dtex_mission_start',
        'Alarmas de inicio DTEX',
        channelDescription: 'Avisos para activar misiones DTEX a tiempo.',
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
      ),
    );
    await _notifications.show(
      id: 911,
      title: 'Inicio de misión DTEX',
      body: body,
      notificationDetails: details,
    );

    if (!mounted || _missionStartDialogOpen) return;
    _missionStartDialogOpen = true;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppConstants.alertOrange),
        ),
        title: const Row(
          children: [
            Icon(Icons.alarm_rounded, color: AppConstants.alertOrange),
            SizedBox(width: 8),
            Text(
              'INICIO DE MISIÓN',
              style: TextStyle(
                color: AppConstants.alertOrange,
                fontFamily: 'Orbitron',
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
          ],
        ),
        content: Text(body, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('ENTENDIDO'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              unawaited(_startMission());
            },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('ACTIVAR'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.successGreen,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
    _missionStartDialogOpen = false;
  }

  void _showMissionLockMessage() {
    if (!mounted) return;
    setState(() {
      _status =
          'Diligencia activa. Solo se habilita salida al concluir la misión.';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Diligencia activa: concluye la misión para cerrar la app.',
        ),
        duration: Duration(seconds: 2),
      ),
    );
  }

  DtexMision? _missionFromResponse(Map<String, dynamic> response) {
    final direct = _mapValue(response, 'mision') ??
        _mapValue(response, 'mission') ??
        _mapValue(response, 'data');
    if (direct == null) return null;
    try {
      return DtexMision.fromJson(direct);
    } catch (_) {
      return null;
    }
  }

  DtexDestino? _destinoFromResponse(Map<String, dynamic> response) {
    final direct =
        _mapValue(response, 'destino') ?? _mapValue(response, 'destination');
    if (direct == null) return null;
    try {
      return DtexDestino.fromJson(direct);
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic>? _mapValue(Map<String, dynamic> source, String key) {
    final value = source[key];
    return value is Map<String, dynamic> ? value : null;
  }

  LatLng? get _currentLatLng {
    final point = _telemetry?.position;
    if (point == null) return null;
    return LatLng(point.latitude, point.longitude);
  }

  void _focusMapOnOperationalPoints() {
    if (!_mapReady) return;
    final current = _currentLatLng;
    final destino = _destino;
    if (current == null) return;
    if (destino == null) {
      _mapController.move(current, 16);
      return;
    }
    _mapController.fitCamera(
      CameraFit.coordinates(
        coordinates: [current, LatLng(destino.latitud, destino.longitud)],
        padding: const EdgeInsets.all(44),
      ),
    );
  }

  Future<void> _updateStreetRoute({bool force = false}) async {
    if (_routeLoading) return;
    final origin = _currentLatLng;
    final destino = _destino;
    if (origin == null || destino == null) return;

    final lastOrigin = _lastRouteOrigin;
    final movedMeters = lastOrigin == null
        ? double.infinity
        : const Distance().as(LengthUnit.Meter, lastOrigin, origin);
    final elapsed = _lastRouteFetchAt == null
        ? _routeRefreshInterval
        : DateTime.now().difference(_lastRouteFetchAt!);

    if (!force &&
        movedMeters < _routeRefreshDistanceMeters &&
        elapsed < _routeRefreshInterval) {
      return;
    }

    setState(() => _routeLoading = true);
    final destination = LatLng(destino.latitud, destino.longitud);
    try {
      final uri = Uri.https(
        'router.project-osrm.org',
        '/route/v1/driving/'
            '${origin.longitude},${origin.latitude};'
            '${destination.longitude},${destination.latitude}',
        <String, String>{
          'overview': 'full',
          'geometries': 'geojson',
          'steps': 'false',
        },
      );
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.userAgentHeader, 'sccp-dtex-custodio');
      final response = await request.close();
      final body = await response.transform(utf8.decoder).join();
      client.close(force: true);
      if (response.statusCode != HttpStatus.ok) return;

      final payload = jsonDecode(body);
      if (payload is! Map<String, dynamic>) return;
      final routes = payload['routes'];
      if (routes is! List || routes.isEmpty) return;
      final firstRoute = routes.first;
      if (firstRoute is! Map<String, dynamic>) return;
      final geometry = firstRoute['geometry'];
      if (geometry is! Map<String, dynamic>) return;
      final coordinates = geometry['coordinates'];
      if (coordinates is! List) return;

      final points = coordinates
          .whereType<List>()
          .where((pair) => pair.length >= 2)
          .map((pair) => LatLng(
                (pair[1] as num).toDouble(),
                (pair[0] as num).toDouble(),
              ))
          .toList();
      if (points.length < 2) return;
      if (!mounted) return;
      setState(() {
        _streetRoute = points;
        _lastRouteOrigin = origin;
        _routeDistanceMeters = (firstRoute['distance'] as num?)?.toDouble();
        _routeDurationSeconds = (firstRoute['duration'] as num?)?.toDouble();
        _lastRouteFetchAt = DateTime.now();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _streetRoute = <LatLng>[];
        _routeDistanceMeters = null;
        _routeDurationSeconds = null;
      });
    } finally {
      if (mounted) setState(() => _routeLoading = false);
    }
  }

  bool get _canCloseMission {
    final state = _mission?.estadoNormalizado;
    return _trackingActive &&
        (state == DtexMision.estadoRetorno ||
            state == DtexMision.estadoEnDestino ||
            state == DtexMision.estadoEmergencia);
  }

  bool get _canDisconnect {
    final mission = _mission;
    return mission == null || !mission.estaActiva;
  }

  bool get _mustStayInMission {
    final mission = _mission;
    return mission != null && mission.estaActiva;
  }

  bool get _hasActiveInfraction =>
      _status.toUpperCase().contains('INFRACCION DTEX') ||
      _mission?.estadoNormalizado == DtexMision.estadoEmergencia;

  String get _etaLabel {
    final current = _telemetry?.position;
    final destino = _destino;
    if (current == null || destino == null) return 'Calculando';
    final routeDuration = _routeDurationSeconds;
    if (routeDuration != null && routeDuration > 0) {
      final etaMin = routeDuration / 60;
      if (etaMin < 1) return '< 1 min por calles';
      return '${etaMin.round()} min por calles';
    }
    final distance = const Distance().as(
      LengthUnit.Meter,
      LatLng(current.latitude, current.longitude),
      LatLng(destino.latitud, destino.longitud),
    );
    final speed =
        current.speed != null && current.speed! > 1.5 ? current.speed! : 8.33;
    final etaMin = distance / speed / 60;
    if (etaMin < 1) return '< 1 min';
    return '${etaMin.round()} min';
  }

  String get _distanceLabel {
    final routeDistance = _routeDistanceMeters;
    if (routeDistance != null && routeDistance > 0) {
      return _formatDistance(routeDistance);
    }
    final current = _telemetry?.position;
    final destino = _destino;
    if (current == null || destino == null) {
      return _routeLoading ? 'Calculando ruta' : 'N/D';
    }
    final distance = const Distance().as(
      LengthUnit.Meter,
      LatLng(current.latitude, current.longitude),
      LatLng(destino.latitud, destino.longitud),
    );
    return '${_formatDistance(distance)} lineal';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(2)} km';
  }

  String _timeLabel(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    final s = value.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color _stateColor(String estado) {
    switch (estado.trim().toUpperCase()) {
      case DtexMision.estadoEnRuta:
      case DtexMision.estadoRetorno:
        return AppConstants.neonCyan;
      case DtexMision.estadoEnDestino:
      case DtexMision.estadoCompletada:
        return AppConstants.successGreen;
      case DtexMision.estadoEmergencia:
        return AppConstants.warningRed;
      default:
        return AppConstants.alertOrange;
    }
  }
}

// ─────────────────────────────────────────────
// LOGIN SCREEN — estilo SCCP
// ─────────────────────────────────────────────

class _DtexLoginScreen extends StatefulWidget {
  const _DtexLoginScreen({
    required this.nombreController,
    required this.codigoController,
    required this.loading,
    required this.error,
    required this.onLogin,
  });

  final TextEditingController nombreController;
  final TextEditingController codigoController;
  final bool loading;
  final String? error;
  final VoidCallback onLogin;

  @override
  State<_DtexLoginScreen> createState() => _DtexLoginScreenState();
}

class _DtexLoginScreenState extends State<_DtexLoginScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryController;
  late final AnimationController _glitchController;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _entryController.dispose();
    _glitchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 720;
        final contentWidth = isWide ? 560.0 : constraints.maxWidth;

        return Stack(
          children: [
            // Fondo — scan line animado
            const _DtexScanBackground(),

            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _staggered(
                        index: 0,
                        child: _buildBrand(),
                      ),
                      const SizedBox(height: 22),
                      _staggered(
                        index: 1,
                        child: _buildCard(context),
                      ),
                      const SizedBox(height: 14),
                      _staggered(
                        index: 2,
                        child: _buildFooter(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrand() {
    return Column(
      children: [
        _DtexGlitchIcon(animation: _glitchController, size: 172),
        const SizedBox(height: 16),
        const Text(
          'DTEX CUSTODIO',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Orbitron',
            fontSize: 28,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
            color: AppConstants.neonCyan,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ACCESO TEMPORAL DE DILIGENCIA EXTERNA',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 10.5,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    return _GlassPanel(
      borderRadius: BorderRadius.circular(22),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _staggered(
            index: 3,
            child: const Text(
              'INICIAR DILIGENCIA',
              style: TextStyle(
                fontFamily: 'Orbitron',
                letterSpacing: 1.0,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppConstants.neonCyan,
              ),
            ),
          ),
          const SizedBox(height: 6),
          _staggered(
            index: 4,
            child: Text(
              'Ingresa al menos dos palabras de tu nombre y el código de seguridad asignado.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
                fontFamily: 'Rajdhani',
              ),
            ),
          ),
          const SizedBox(height: 18),
          _staggered(
            index: 5,
            child: TextField(
              controller: widget.nombreController,
              textCapitalization: TextCapitalization.words,
              style: const TextStyle(color: Colors.white),
              decoration: _inputDec('NOMBRE DEL CUSTODIO',
                  prefixIcon: Icons.badge_rounded),
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
          ),
          const SizedBox(height: 12),
          _staggered(
            index: 6,
            child: TextField(
              controller: widget.codigoController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Orbitron',
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
              decoration: _inputDec('CÓDIGO DE SEGURIDAD',
                  prefixIcon: Icons.key_rounded),
              onSubmitted: (_) => widget.onLogin(),
            ),
          ),
          const SizedBox(height: 16),
          if (widget.error != null)
            _staggered(
              index: 7,
              drop: 8,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  widget.error!,
                  style: const TextStyle(
                    color: AppConstants.warningRed,
                    fontFamily: 'Rajdhani',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          _staggered(
            index: 8,
            child: SizedBox(
              width: double.infinity,
              child: widget.loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: CircularProgressIndicator(
                          color: AppConstants.neonCyan,
                        ),
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: widget.onLogin,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppConstants.neonCyan,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.login_rounded),
                      label: const Text(
                        'INGRESAR',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      children: [
        Icon(Icons.grid_4x4,
            color: Colors.white.withValues(alpha: 0.45), size: 14),
        const SizedBox(width: 8),
        Text(
          'SCCP · SISTEMA DE CONTROL Y CUSTODIA POLICIAL',
          style: TextStyle(
            fontFamily: 'Rajdhani',
            color: Colors.white.withValues(alpha: 0.45),
            fontSize: 11,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDec(String label, {required IconData prefixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: AppConstants.neonCyan.withValues(alpha: 0.7),
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
      ),
      prefixIcon:
          Icon(prefixIcon, color: AppConstants.neonCyan.withValues(alpha: 0.7)),
      filled: true,
      fillColor: const Color(0x7A07101B),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppConstants.neonCyan),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: AppConstants.neonCyan.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppConstants.neonCyan, width: 1.4),
      ),
    );
  }

  Widget _staggered({
    required int index,
    required Widget child,
    double drop = 24,
  }) {
    final start = (0.08 + (index * 0.07)).clamp(0.0, 0.88);
    final end = (start + 0.32).clamp(0.0, 1.0);
    final animation = CurvedAnimation(
      parent: _entryController,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (_, item) {
        final t = animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * drop),
            child: item,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// ─── GLITCH ICON DTEX ───────────────────────────────────────────────────────
class _DtexGlitchIcon extends StatelessWidget {
  final Animation<double> animation;
  final double size;

  const _DtexGlitchIcon({
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final phase = animation.value;
        final fastWave = math.sin(phase * math.pi * 14);
        final glitch = math.max(0.0, fastWave.abs() - 0.45) * 5.0;
        final scanY = -1 + (((phase * 1.6) % 1.0) * 2);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // ── GLOW BASE ─────────────────────────────
              IgnorePointer(
                child: Container(
                  width: size * 0.8,
                  height: size * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.neonCyan.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF33EE).withValues(alpha: 0.12),
                        blurRadius: 40,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // ── LOGO PRINCIPAL CON GLOW ─────────────────
              SizedBox(
                width: size * 0.78,
                height: size * 0.78,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // ── GLITCH CYAN ───────────────────────────
              Transform.translate(
                offset: Offset(glitch, 0),
                child: Opacity(
                  opacity: 0.18,
                  child: SizedBox(
                    width: size * 0.78,
                    height: size * 0.78,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF00FFD1),
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── GLITCH MAGENTA ────────────────────────
              Transform.translate(
                offset: Offset(-glitch, 0),
                child: Opacity(
                  opacity: 0.14,
                  child: SizedBox(
                    width: size * 0.78,
                    height: size * 0.78,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFFF33EE),
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── SCAN LINE ─────────────────────────────
              Align(
                alignment: Alignment(0, scanY),
                child: Container(
                  width: size * 0.8,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        AppConstants.neonCyan.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.neonCyan.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// GLASS PANEL — glassmorphism card
// ─────────────────────────────────────────────

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    required this.padding,
    required this.borderRadius,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        color: Colors.white.withValues(alpha: 0.045),
        border: Border.all(
          color: AppConstants.neonCyan.withValues(alpha: 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.neonCyan.withValues(alpha: 0.08),
            blurRadius: 24,
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────
// SCAN BACKGROUND — scanlines animadas de fondo
// ─────────────────────────────────────────────

class _DtexScanBackground extends StatefulWidget {
  const _DtexScanBackground();

  @override
  State<_DtexScanBackground> createState() => _DtexScanBackgroundState();
}

class _DtexScanBackgroundState extends State<_DtexScanBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return CustomPaint(
          painter: _ScanPainter(_ctrl.value),
          child: const SizedBox.expand(),
        );
      },
    );
  }
}

class _ScanPainter extends CustomPainter {
  _ScanPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    // Líneas de scan horizontales sutiles
    final paint = Paint()
      ..color = const Color(0x0800FFD1)
      ..strokeWidth = 1;
    const spacing = 18.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    // Barra de scan que recorre verticalmente
    final scanY = t * size.height;
    final barPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          const Color(0x1800FFD1),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, scanY - 40, size.width, 80));
    canvas.drawRect(Rect.fromLTWH(0, scanY - 40, size.width, 80), barPaint);
  }

  @override
  bool shouldRepaint(_ScanPainter old) => old.t != t;
}

// ─────────────────────────────────────────────
// RADIO PAGE
// ─────────────────────────────────────────────

class DtexCustodioRadioPage extends StatefulWidget {
  const DtexCustodioRadioPage({
    super.key,
    required this.mission,
    required this.repository,
    required this.currentPoint,
  });

  final DtexMision mission;
  final SupabaseRepository repository;
  final LatLng? currentPoint;

  @override
  State<DtexCustodioRadioPage> createState() => _DtexCustodioRadioPageState();
}

class _DtexCustodioRadioPageState extends State<DtexCustodioRadioPage> {
  final _messageController = TextEditingController();
  final _reportController = TextEditingController();
  final _picker = ImagePicker();
  final _readMarkedIds = <String>{};

  XFile? _photo;
  bool _sendingMessage = false;
  bool _sendingReport = false;
  String? _status;

  @override
  void dispose() {
    _messageController.dispose();
    _reportController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'RADIO OPERATIVA',
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 14),
          ),
          bottom: const TabBar(
            indicatorColor: AppConstants.neonCyan,
            labelColor: AppConstants.neonCyan,
            tabs: [
              Tab(icon: Icon(Icons.forum_rounded), text: 'Mensajes'),
              Tab(
                  icon: Icon(Icons.photo_camera_rounded),
                  text: 'Parte novedad'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _messagesTab(),
              _reportTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _messagesTab() {
    final codigoCustodio = widget.mission.custodioCodigo.trim();
    if (codigoCustodio.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_rounded,
                  color: AppConstants.alertOrange, size: 36),
              const SizedBox(height: 12),
              const Text(
                'Radio no disponible',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'El código de custodio no está asignado en esta misión.\nContactar al supervisor.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<RadioMessage>>(
            stream: widget.repository.watchRadioMessages(
              idOficial: widget.mission.custodioCodigo.trim(),
            ),
            builder: (context, snapshot) {
              final rows = snapshot.data ?? const <RadioMessage>[];
              _markIncomingMessagesRead(rows);
              if (rows.isEmpty) {
                return Center(
                  child: Text(
                    'Sin mensajes registrados.',
                    style: _mutedStyle(),
                  ),
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: rows.length,
                itemBuilder: (_, index) => _messageTile(rows[index]),
              );
            },
          ),
        ),
        _messageComposer(),
      ],
    );
  }

  Widget _messageTile(RadioMessage message) {
    final fromCustodio = message.deUsuario.startsWith('DTEX:');
    final color = fromCustodio ? AppConstants.neonCyan : Colors.white70;
    return Align(
      alignment: fromCustodio ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        width: MediaQuery.sizeOf(context).width * 0.82,
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: fromCustodio ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${message.deUsuario} • ${message.tipo}',
              style: TextStyle(
                color: color,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              message.mensaje,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(_timeLabel(message.timestamp),
                style: _mutedStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _markIncomingMessagesRead(List<RadioMessage> rows) {
    for (final message in rows) {
      final fromCustodio = message.deUsuario.startsWith('DTEX:');
      final unread = message.estado.trim().toUpperCase() != 'LEIDO';
      if (fromCustodio || !unread || !_readMarkedIds.add(message.idMensaje)) {
        continue;
      }
      unawaited(widget.repository.markRadioMessageRead(message.idMensaje));
    }
  }

  Widget _messageComposer() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.22),
        border:
            Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 3,
              decoration: _inputDecoration('Mensaje al supervisor'),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _sendingMessage ? null : _sendMessage,
            icon: _sendingMessage
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }

  Widget _reportTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        TextField(
          controller: _reportController,
          minLines: 5,
          maxLines: 8,
          decoration: _inputDecoration('Reporte de situación'),
        ),
        const SizedBox(height: 12),
        if (_photo != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_photo!.path),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 12),
        ],
        OutlinedButton.icon(
          onPressed: _pickPhoto,
          icon: const Icon(Icons.photo_camera_rounded),
          label: Text(_photo == null ? 'Tomar foto' : 'Reemplazar foto'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _sendingReport ? null : _sendSituationReport,
          style: FilledButton.styleFrom(
            backgroundColor: AppConstants.neonCyan,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(52),
          ),
          icon: _sendingReport
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.assignment_turned_in_rounded),
          label: Text(_sendingReport ? 'Enviando' : 'Enviar reporte'),
        ),
        if (_status != null) ...[
          const SizedBox(height: 12),
          Text(_status!, style: _mutedStyle()),
        ],
      ],
    );
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    final codigoCustodio = widget.mission.custodioCodigo.trim();
    if (codigoCustodio.isEmpty) {
      setState(() => _status = 'Error: código de custodio no disponible.');
      return;
    }
    setState(() => _sendingMessage = true);
    try {
      final ok = await widget.repository.sendRadioMessage(
        idOficial: codigoCustodio,
        fromUser: 'DTEX:${widget.mission.custodioNombre}',
        toUser: 'SUPERVISOR',
        message: text,
        type: 'RADIO',
      );
      if (!mounted) return;
      setState(() {
        _sendingMessage = false;
        _status = ok ? 'Mensaje enviado.' : 'No se pudo enviar. Reintenta.';
        if (ok) _messageController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingMessage = false;
        _status = 'Error al enviar: ${e.toString()}';
      });
    }
  }

  Future<void> _pickPhoto() async {
    try {
      var permission = await permissions.Permission.camera.status;
      if (!permission.isGranted) {
        permission = await permissions.Permission.camera.request();
      }
      if (!permission.isGranted) {
        if (permission.isPermanentlyDenied) {
          await permissions.openAppSettings();
        }
        if (!mounted) return;
        setState(() => _status =
            'Cámara sin permiso. Autoriza cámara para adjuntar foto.');
        return;
      }

      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 72,
        maxWidth: 1600,
      );
      if (!mounted) return;
      if (photo == null) {
        setState(() => _status = 'No se tomó ninguna foto.');
        return;
      }
      setState(() {
        _photo = photo;
        _status = 'Foto lista para enviar.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _status =
          'No se pudo acceder a la cámara. Verifica los permisos en Ajustes.');
    }
  }

  Future<void> _sendSituationReport() async {
    final report = _reportController.text.trim();
    if (report.isEmpty && _photo == null) {
      setState(() => _status = 'Agrega una descripción o una foto.');
      return;
    }
    final codigoCustodio = widget.mission.custodioCodigo.trim();
    if (codigoCustodio.isEmpty) {
      setState(() => _status = 'Error: código de custodio no disponible.');
      return;
    }

    setState(() {
      _sendingReport = true;
      _status = 'Preparando reporte...';
    });

    try {
      String? photoUrl;
      bool photoUploadFailed = false;
      final photo = _photo;
      if (photo != null) {
        setState(() => _status = 'Subiendo foto...');
        final bytes = await photo.readAsBytes();
        photoUrl = await widget.repository.uploadDtexReportPhoto(
          idMision: widget.mission.idMision,
          idOficial: codigoCustodio,
          bytes: bytes,
        );
        if (!mounted) return;
        if (photoUrl == null) {
          photoUploadFailed = true;
        }
      }

      final point = widget.currentPoint;
      final buffer = StringBuffer()
        ..writeln(report.isEmpty ? 'Reporte de situación DTEX.' : report)
        ..writeln('Misión: ${widget.mission.idMision}')
        ..writeln('Destino: ${widget.mission.destinoNombre}');
      if (point != null) {
        buffer.writeln(
          'Ubicación: ${point.latitude.toStringAsFixed(6)}, ${point.longitude.toStringAsFixed(6)}',
        );
      }
      if (photoUrl != null) buffer.writeln('Foto: $photoUrl');
      if (photoUploadFailed) {
        buffer.writeln('Foto: captura tomada, pero no se pudo subir.');
      }

      setState(() => _status = 'Enviando reporte...');
      final ok = await widget.repository.sendRadioMessage(
        idOficial: codigoCustodio,
        fromUser: 'DTEX:${widget.mission.custodioNombre}',
        toUser: 'SUPERVISOR',
        message: buffer.toString().trim(),
        type: 'PARTE_NOVEDAD',
      );
      if (!mounted) return;
      setState(() {
        _sendingReport = false;
        _status =
            ok ? '✓ Reporte enviado al supervisor.' : 'No se pudo enviar.';
        if (ok) {
          _reportController.clear();
          _photo = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingReport = false;
        _status = 'Error al enviar reporte: ${e.toString()}';
      });
    }
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.22),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppConstants.neonCyan),
      ),
    );
  }

  TextStyle _mutedStyle({double fontSize = 14}) {
    return TextStyle(
      color: Colors.white.withValues(alpha: 0.68),
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
  }

  String _timeLabel(DateTime value) {
    final h = value.hour.toString().padLeft(2, '0');
    final m = value.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

// ─────────────────────────────────────────────
// ─────────────────────────────────────────────
// SIMPLE PREFS — Persistencia liviana sin dependencia extra
// Usa MethodChannel de flutter/services (ya importado) para
// leer/escribir SharedPreferences de Android directamente.
// ─────────────────────────────────────────────

class _SimplePrefs {
  _SimplePrefs._();
  static final _SimplePrefs _instance = _SimplePrefs._();

  static const _ch = MethodChannel('dtex_custodio/prefs');

  Future<void> setString(String key, String value) async {
    try {
      await _ch.invokeMethod<void>('setString', {'key': key, 'value': value});
    } catch (_) {
      // Canal no implementado aún: no bloquear flujo principal
    }
  }

  Future<void> setBool(String key, bool value) async {
    try {
      await _ch.invokeMethod<void>('setBool', {'key': key, 'value': value});
    } catch (_) {}
  }

  Future<String?> getString(String key) async {
    try {
      return await _ch.invokeMethod<String>('getString', {'key': key});
    } catch (_) {
      return null;
    }
  }

  Future<bool?> getBool(String key) async {
    try {
      return await _ch.invokeMethod<bool>('getBool', {'key': key});
    } catch (_) {
      return null;
    }
  }

  Future<void> remove(String key) async {
    try {
      await _ch.invokeMethod<void>('remove', {'key': key});
    } catch (_) {}
  }
}

// ─────────────────────────────────────────────
// LIFECYCLE OBSERVER
// ─────────────────────────────────────────────

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this.onChange);
  final Future<void> Function(AppLifecycleState state) onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(onChange(state));
  }
}
