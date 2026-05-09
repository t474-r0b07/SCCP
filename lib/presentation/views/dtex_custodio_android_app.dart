import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/dtex_android_tracking_service.dart';
import '../../data/models/dtex_destino_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/models/radio_message_model.dart';
import '../../data/repositories/dtex_repository.dart';
import '../../data/repositories/supabase_repository.dart';

class DtexCustodioAndroidApp extends StatelessWidget {
  const DtexCustodioAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DTEX Custodio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF071014),
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppConstants.neonCyan,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Rajdhani',
      ),
      home: const DtexCustodioAndroidHome(),
    );
  }
}

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
  late final _LifecycleObserver _lifecycleObserver;

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = _LifecycleObserver(_handleLifecycle);
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    _tracking.stop();
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

  Widget _buildLogin() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
      children: [
        const Icon(
          Icons.admin_panel_settings_rounded,
          color: AppConstants.neonCyan,
          size: 56,
        ),
        const SizedBox(height: 14),
        const Text(
          'DTEX CUSTODIO',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Orbitron',
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Acceso temporal de diligencia externa',
          textAlign: TextAlign.center,
          style: _mutedStyle(),
        ),
        const SizedBox(height: 28),
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _input(
                controller: _nombreController,
                label: 'Nombre del custodio',
                icon: Icons.badge_rounded,
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 12),
              _input(
                controller: _codigoController,
                label: 'Código de seguridad',
                icon: Icons.key_rounded,
                textCapitalization: TextCapitalization.characters,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppConstants.warningRed,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _loading ? null : _login,
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.neonCyan,
                  foregroundColor: Colors.black,
                  minimumSize: const Size.fromHeight(54),
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(_loading ? 'Validando' : 'Ingresar'),
              ),
            ],
          ),
        ),
      ],
    );
  }

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
        _telemetryCard(),
        const SizedBox(height: 10),
        _communicationsCard(mission),
      ],
    );
  }

  Widget _header(DtexMision mission) {
    return Row(
      children: [
        Icon(
          Icons.shield_rounded,
          color: _hasActiveInfraction
              ? AppConstants.warningRed
              : AppConstants.neonCyan,
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

    return SizedBox(
      height: 310,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
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
            onPressed: _trackingActive ? _reportEmergency : null,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppConstants.warningRed,
              side: const BorderSide(color: AppConstants.warningRed),
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
              telemetry?.batteryPct == null
                  ? 'N/D'
                  : '${telemetry!.batteryPct}%'),
          _row('Red', telemetry?.networkStatus ?? 'N/D'),
          _row('Último reporte',
              telemetry == null ? 'N/D' : _timeLabel(telemetry.timestamp)),
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
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
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

  Widget _input({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      textCapitalization: textCapitalization,
      decoration: _inputDecoration(label).copyWith(prefixIcon: Icon(icon)),
      onSubmitted: (_) => _login(),
    );
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

  Future<void> _login() async {
    final nombre = _nombreController.text.trim();
    final codigo = _codigoController.text.trim();
    if (nombre.length < 3 || codigo.length < 4) {
      setState(() {
        _error = 'Ingresa nombre y código de seguridad.';
      });
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

    await _primeGps();
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
      unawaited(_updateStreetRoute(force: true));
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
        _status =
            'Permisos incompletos. Activa ubicación precisa para iniciar.';
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
  }

  Future<void> _reportEmergency() async {
    final mission = _mission;
    if (mission == null) return;
    final point = _telemetry?.position;
    final ok = await _dtexRepository.cambiarEstadoMision(
      idMision: mission.idMision,
      estado: DtexMision.estadoEmergencia,
      lat: point?.latitude,
      lng: point?.longitude,
    );
    if (!mounted) return;
    setState(() {
      _status =
          ok ? 'Emergencia reportada.' : 'No se pudo reportar emergencia.';
      if (ok) {
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
    if (!_mustStayInMission) return;
    if (state != AppLifecycleState.paused &&
        state != AppLifecycleState.inactive &&
        state != AppLifecycleState.hidden) {
      return;
    }

    final now = DateTime.now();
    final last = _lastAppBackgroundAlertAt;
    if (last != null && now.difference(last) < _appBackgroundAlertCooldown) {
      return;
    }
    _lastAppBackgroundAlertAt = now;

    final mission = _mission;
    if (mission == null) return;
    final point = _telemetry?.position;
    await _dtexRepository.insertarAlerta(
      idMision: mission.idMision,
      tipo: 'APP_SUSPENDIDA',
      severidad: 'AVISO',
      descripcion:
          'La app DTEX custodio fue enviada a segundo plano durante una mision activa.',
      latitud: point?.latitude,
      longitud: point?.longitude,
    );
  }

  Future<void> _logout() async {
    if (_mustStayInMission) {
      _showMissionLockMessage();
      return;
    }
    await _tracking.stop();
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
        coordinates: [
          current,
          LatLng(destino.latitud, destino.longitud),
        ],
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
      if (mounted) {
        setState(() => _routeLoading = false);
      }
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
          title: const Text('Radio operativa'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.forum_rounded), text: 'Mensajes'),
              Tab(icon: Icon(Icons.photo_camera_rounded), text: 'Reporte'),
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
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<RadioMessage>>(
            stream: widget.repository.watchRadioMessages(
              idOficial: widget.mission.custodioCodigo,
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
        if (_photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(_photo!.path),
              height: 220,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        if (_photo != null) const SizedBox(height: 12),
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
    setState(() => _sendingMessage = true);
    final ok = await widget.repository.sendRadioMessage(
      idOficial: widget.mission.custodioCodigo,
      fromUser: 'DTEX:${widget.mission.custodioNombre}',
      toUser: 'SUPERVISOR',
      message: text,
      type: 'RADIO',
    );
    if (!mounted) return;
    setState(() {
      _sendingMessage = false;
      _status = ok ? 'Mensaje enviado.' : 'No se pudo enviar el mensaje.';
      if (ok) _messageController.clear();
    });
  }

  Future<void> _pickPhoto() async {
    final photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 72,
      maxWidth: 1600,
    );
    if (!mounted || photo == null) return;
    setState(() => _photo = photo);
  }

  Future<void> _sendSituationReport() async {
    final report = _reportController.text.trim();
    if (report.isEmpty && _photo == null) {
      setState(() => _status = 'Agrega una descripción o una foto.');
      return;
    }

    setState(() {
      _sendingReport = true;
      _status = 'Preparando reporte...';
    });

    String? photoUrl;
    final photo = _photo;
    if (photo != null) {
      final bytes = await photo.readAsBytes();
      photoUrl = await widget.repository.uploadDtexReportPhoto(
        idMision: widget.mission.idMision,
        idOficial: widget.mission.custodioCodigo,
        bytes: bytes,
      );
      if (!mounted) return;
      if (photoUrl == null) {
        setState(() {
          _sendingReport = false;
          _status = 'No se pudo subir la foto.';
        });
        return;
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

    final ok = await widget.repository.sendRadioMessage(
      idOficial: widget.mission.custodioCodigo,
      fromUser: 'DTEX:${widget.mission.custodioNombre}',
      toUser: 'SUPERVISOR',
      message: buffer.toString().trim(),
      type: 'PARTE_NOVEDAD',
    );
    if (!mounted) return;
    setState(() {
      _sendingReport = false;
      _status = ok ? 'Reporte enviado al supervisor.' : 'No se pudo enviar.';
      if (ok) {
        _reportController.clear();
        _photo = null;
      }
    });
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

class _LifecycleObserver extends WidgetsBindingObserver {
  _LifecycleObserver(this.onChange);

  final Future<void> Function(AppLifecycleState state) onChange;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    unawaited(onChange(state));
  }
}
