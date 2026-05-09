import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/dtex_geo_location.dart';
import '../../core/services/dtex_geo_position.dart';
import '../../data/models/dtex_alerta_model.dart';
import '../../data/models/dtex_destino_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/models/dtex_tracking_extension_model.dart';
import '../../data/repositories/dtex_repository.dart';

class DtexCustodioView extends StatefulWidget {
  const DtexCustodioView({super.key});

  @override
  State<DtexCustodioView> createState() => _DtexCustodioViewState();
}

class _DtexCustodioViewState extends State<DtexCustodioView> {
  static const double _movementThresholdMps = 0.7;
  static const double _deviationThresholdMeters = 250;
  static const Duration _trackingInterval = Duration(seconds: 15);
  static const Duration _stopThreshold = Duration(minutes: 5);
  static const Duration _alertCooldown = Duration(minutes: 4);

  final _repository = DtexRepository();
  final _accessCodeController = TextEditingController();
  final _mapController = MapController();

  DtexMision? _mision;
  DtexDestino? _destino;
  DtexGeoPosition? _lastPosition;
  DtexGeoPosition? _startPosition;

  List<DtexTrackingPunto> _tracking = <DtexTrackingPunto>[];
  List<DtexAlerta> _alertas = <DtexAlerta>[];

  StreamSubscription<List<DtexTrackingPunto>>? _trackingSub;
  Timer? _trackingTimer;

  bool _loading = false;
  bool _sending = false;
  bool _trackingEnabled = false;
  bool _insideDestination = false;

  String? _error;
  String? _gpsStatus;
  DateTime? _stoppedSince;
  DateTime? _lastDeviationAlertAt;
  DateTime? _lastStopAlertAt;

  @override
  void initState() {
    super.initState();
    final code = Get.parameters['codigo'] ??
        Get.parameters['otp'] ??
        Uri.base.queryParameters['codigo'] ??
        Uri.base.queryParameters['otp'];
    if (code != null && code.trim().isNotEmpty) {
      _accessCodeController.text = code.trim();
      WidgetsBinding.instance.addPostFrameCallback((_) => _validarOtp());
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _primeGps());
    }
  }

  @override
  void dispose() {
    _trackingTimer?.cancel();
    _trackingSub?.cancel();
    _accessCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final mobile = media.width < 980;

    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1320),
            child: Padding(
              padding: EdgeInsets.all(mobile ? 10 : 16),
              child:
                  _mision == null ? _buildOtpAccess() : _buildMission(mobile),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpAccess() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: _shellDecoration(AppConstants.neonCyan),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.verified_user_rounded,
                color: AppConstants.neonCyan,
                size: 48,
              ),
              const SizedBox(height: 14),
              const Text(
                'DTEX CUSTODIO',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Ingresa tu carnet o el código de misión',
                textAlign: TextAlign.center,
                style: _mutedStyle(),
              ),
              const SizedBox(height: 18),
              _statusStrip(
                title: 'GPS PREPARADO',
                value: _lastPosition == null
                    ? 'Pendiente de permisos o lectura inicial.'
                    : '${_lastPosition!.latitude.toStringAsFixed(6)}, ${_lastPosition!.longitude.toStringAsFixed(6)}',
                color: AppConstants.successGreen,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _accessCodeController,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.text,
                maxLength: 20,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9-]')),
                ],
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'Orbitron',
                  fontSize: 21,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
                decoration: _inputDecoration('Código de acceso'),
                onSubmitted: (_) => _validarOtp(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppConstants.warningRed,
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppConstants.neonCyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _loading ? null : _validarOtp,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.lock_open_rounded),
                label: Text(_loading ? 'Validando' : 'Validar acceso'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMission(bool mobile) {
    final topCards = Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _infoCard(
          title: 'CUSTODIO',
          color: AppConstants.neonCyan,
          rows: [
            _dataRow('Nombre', _mision!.custodioNombre),
            _dataRow('Código', _mision!.custodioCodigo),
            _dataRow('Grado', _mision!.custodioGrado),
          ],
        ),
        _infoCard(
          title: 'REO',
          color: AppConstants.alertOrange,
          rows: [
            _dataRow('Nombre', _mision!.reoNombre),
            _dataRow('CI', _mision!.reoCi),
            _dataRow('Expediente', _mision!.reoExpediente ?? 'N/D'),
          ],
        ),
        _infoCard(
          title: 'MISION',
          color: _statusColor(_mision!.estado),
          rows: [
            _dataRow('Estado', _mision!.estadoDisplay),
            _dataRow('Destino', _destino?.nombre ?? _mision!.destinoNombre),
            _dataRow('ETA', _etaLabel),
            _dataRow('Tiempo', '${_mision!.tiempoMaxEstadiMin} min'),
          ],
        ),
      ],
    );

    final leftColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _statusStrip(
          title: 'GPS ACTUAL',
          value: _lastPosition == null
              ? 'Esperando lectura de ubicación.'
              : '${_lastPosition!.latitude.toStringAsFixed(6)}, ${_lastPosition!.longitude.toStringAsFixed(6)}',
          color: AppConstants.successGreen,
        ),
        const SizedBox(height: 10),
        _statusStrip(
          title: 'AUTOMATIZACIÓN',
          value: _gpsStatus == null
              ? _automationLabel
              : '$_automationLabel\n$_gpsStatus',
          color: _trackingEnabled
              ? AppConstants.successGreen
              : AppConstants.alertOrange,
        ),
        const SizedBox(height: 10),
        _statusStrip(
          title: 'DESTINO',
          value: _destinoStatusLabel,
          color: _insideDestination
              ? AppConstants.successGreen
              : AppConstants.neonCyan,
        ),
        const SizedBox(height: 12),
        _actionPanel(),
        const SizedBox(height: 12),
        Expanded(child: _alertsPanel()),
      ],
    );

    final mapPanel = _mapPanel();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _missionHeader(),
        const SizedBox(height: 10),
        topCards,
        const SizedBox(height: 12),
        Expanded(
          child: mobile
              ? ListView(
                  children: [
                    SizedBox(height: 360, child: mapPanel),
                    const SizedBox(height: 12),
                    SizedBox(height: 560, child: leftColumn),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 7, child: mapPanel),
                    const SizedBox(width: 12),
                    Expanded(flex: 4, child: leftColumn),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _missionHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _statusColor(_mision!.estado).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, color: _statusColor(_mision!.estado)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _mision!.estadoDisplay.toUpperCase(),
                  style: TextStyle(
                    color: _statusColor(_mision!.estado),
                    fontFamily: 'Orbitron',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _destino?.direccion ?? _mision!.destinoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _mutedStyle(fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _refreshMissionContext,
            color: Colors.white70,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Salir',
            onPressed: _salir,
            color: Colors.white70,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget _actionPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _shellDecoration(AppConstants.neonCyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'OPERACIÓN',
            style: TextStyle(
              color: AppConstants.neonCyan,
              fontFamily: 'Rajdhani',
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppConstants.successGreen,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _canRegister ? _marcarRegistroRealizado : null,
            icon: const Icon(Icons.fact_check_rounded),
            label: const Text('Registro realizado'),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _operationButton(
                icon: Icons.route_rounded,
                label: 'En ruta',
                enabled: _canStartRoute,
                onPressed: _iniciarMision,
              ),
              _operationButton(
                icon: Icons.location_on_rounded,
                label: 'En destino',
                enabled: _canMarkDestination,
                onPressed: _marcarEnDestino,
              ),
              _operationButton(
                icon: Icons.keyboard_return_rounded,
                label: 'Retorno',
                enabled: _canMarkReturn,
                onPressed: _marcarRetorno,
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppConstants.warningRed,
              side: BorderSide(
                color: AppConstants.warningRed.withValues(alpha: 0.68),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _canReportEmergency ? _marcarEmergencia : null,
            icon: const Icon(Icons.emergency_rounded),
            label: const Text('Emergencia'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: _canFinish ? _terminarMision : null,
            icon: const Icon(Icons.flag_rounded),
            label: const Text('Misión terminada'),
          ),
          const SizedBox(height: 10),
          Text(
            'Después de marcar en ruta, el seguimiento y las alertas se controlan automáticamente.',
            style: _mutedStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _operationButton({
    required IconData icon,
    required String label,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: 132,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: BorderSide(color: Colors.white.withValues(alpha: 0.28)),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        ),
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Widget _alertsPanel() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _shellDecoration(AppConstants.alertOrange),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ALERTAS Y EVENTOS',
            style: TextStyle(
              color: AppConstants.alertOrange,
              fontFamily: 'Rajdhani',
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: _alertas.isEmpty
                ? Center(
                    child: Text(
                      'Sin alertas registradas.',
                      style: _mutedStyle(),
                    ),
                  )
                : ListView.separated(
                    itemCount: _alertas.length,
                    separatorBuilder: (_, __) => Divider(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                    itemBuilder: (_, index) {
                      final alerta = _alertas[index];
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          alerta.esEmergencia
                              ? Icons.warning_rounded
                              : Icons.info_outline_rounded,
                          color: alerta.esEmergencia
                              ? AppConstants.warningRed
                              : AppConstants.alertOrange,
                        ),
                        title: Text(
                          alerta.tipoDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: Text(
                          alerta.descripcion,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: _mutedStyle(fontSize: 12),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _mapPanel() {
    final destinationPoint =
        _destino == null ? null : LatLng(_destino!.latitud, _destino!.longitud);
    final currentPoint = _currentLatLng;
    final routePoints = <LatLng>[
      ..._tracking
          .map((p) => LatLng(p.latitud, p.longitud))
          .where((p) => !_isZeroPoint(p)),
    ];
    if (routePoints.isEmpty && currentPoint != null) {
      routePoints.add(currentPoint);
    }

    final suggestedLine = <LatLng>[
      if (currentPoint != null) currentPoint,
      if (destinationPoint != null) destinationPoint,
    ];

    final focusPoints = <LatLng>[
      if (currentPoint != null) currentPoint,
      if (destinationPoint != null) destinationPoint,
      ...routePoints,
    ];

    final center = focusPoints.isEmpty
        ? const LatLng(
            AppConstants.defaultLatitude, AppConstants.defaultLongitude)
        : _center(focusPoints);

    return Container(
      decoration: _shellDecoration(AppConstants.neonCyan),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Text(
                  'GPS / RUTA / DESTINO',
                  style: TextStyle(
                    color: AppConstants.neonCyan,
                    fontFamily: 'Rajdhani',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Centrar',
                  onPressed: () => _mapController.move(center, 14.6),
                  icon: const Icon(
                    Icons.center_focus_strong_rounded,
                    color: AppConstants.neonCyan,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: center,
                  initialZoom: 14.2,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onMapReady: () {
                    if (focusPoints.length >= 2) {
                      _mapController.fitCamera(
                        CameraFit.coordinates(
                          coordinates: focusPoints,
                          padding: const EdgeInsets.all(42),
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
                  if (destinationPoint != null)
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: destinationPoint,
                          radius: _destino!.radioMetros.toDouble(),
                          useRadiusInMeter: true,
                          color:
                              AppConstants.successGreen.withValues(alpha: 0.08),
                          borderColor:
                              AppConstants.successGreen.withValues(alpha: 0.7),
                          borderStrokeWidth: 1.2,
                        ),
                      ],
                    ),
                  if (suggestedLine.length == 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: suggestedLine,
                          color: Colors.white24,
                          strokeWidth: 2,
                        ),
                      ],
                    ),
                  if (routePoints.length >= 2)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: routePoints,
                          color: AppConstants.neonCyan,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                  MarkerLayer(
                    markers: [
                      if (destinationPoint != null)
                        Marker(
                          point: destinationPoint,
                          width: 170,
                          height: 36,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppConstants.successGreen,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  _destino!.nombre,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppConstants.successGreen,
                                    fontFamily: 'Rajdhani',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (currentPoint != null)
                        Marker(
                          point: currentPoint,
                          width: 42,
                          height: 42,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  AppConstants.neonCyan.withValues(alpha: 0.2),
                              border: Border.all(
                                color: AppConstants.neonCyan,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.shield_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _mapChip('Distancia', _distanceLabel),
                _mapChip('Ruta', _routeStatusLabel),
                _mapChip('Tiempo', _etaLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required String title,
    required Color color,
    required List<Widget> rows,
  }) {
    return Container(
      width: 310,
      padding: const EdgeInsets.all(12),
      decoration: _shellDecoration(color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontFamily: 'Rajdhani',
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...rows,
        ],
      ),
    );
  }

  Widget _statusStrip({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _shellDecoration(color),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontFamily: 'Rajdhani',
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'Rajdhani',
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              label,
              style: _mutedStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Rajdhani',
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: Colors.white,
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _validarOtp() async {
    final code = _accessCodeController.text.trim().toUpperCase();
    if (code.length < 4) {
      setState(() => _error = 'Ingresa tu carnet o código de misión.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    await _primeGps();
    final response = await _repository.validarOtp(code);
    final mission = await _missionFromOtpResponse(response);

    if (!mounted) return;
    if (mission == null) {
      setState(() {
        _loading = false;
        _error = response['error']?.toString() ??
            'Código inválido, expirado o sin misión activa.';
      });
      return;
    }

    final destino = _destinoFromOtpResponse(response) ??
        await _repository.getDestinoById(mission.idDestino);
    final tracking =
        await _repository.getTrackingMision(idMision: mission.idMision);
    final alertas = await _repository.getAlertasMision(mission.idMision);
    _trackingSub?.cancel();
    _trackingSub = _repository.watchTracking(mission.idMision).listen((rows) {
      if (!mounted) return;
      setState(() {
        _tracking = rows;
      });
    });

    setState(() {
      _mision = mission;
      _destino = destino;
      _tracking = tracking;
      _alertas = alertas;
      _loading = false;
      _trackingEnabled = _isMissionAlreadyStarted(mission);
      _insideDestination = _computeInsideDestination();
      _startPosition ??= _lastPosition;
    });

    if (_trackingEnabled) {
      _startAutomationLoop();
    }
  }

  Future<void> _refreshMissionContext() async {
    final mission = _mision;
    if (mission == null) return;
    final updated = await _repository.getMisionById(mission.idMision);
    final alertas = await _repository.getAlertasMision(mission.idMision);
    if (!mounted) return;
    setState(() {
      if (updated != null) _mision = updated;
      _alertas = alertas;
      _insideDestination = _computeInsideDestination();
    });
  }

  Future<void> _primeGps() async {
    final position = await getCurrentDtexPosition();
    if (!mounted) return;
    setState(() {
      _lastPosition = position;
      _gpsStatus = position == null
          ? 'No se pudo obtener ubicación inicial.'
          : 'Ubicación lista para iniciar misión.';
    });
  }

  Future<void> _marcarRegistroRealizado() async {
    await _cambiarEstadoOperativo(
      DtexMision.estadoRegistroRealizado,
      successMessage: 'Registro realizado. Listo para iniciar ruta.',
      errorMessage: 'No se pudo registrar la diligencia.',
    );
  }

  Future<void> _iniciarMision() async {
    await _cambiarEstadoOperativo(
      DtexMision.estadoEnRuta,
      successMessage: 'Misión en ruta. Seguimiento automático activo.',
      errorMessage: 'No se pudo iniciar la ruta.',
      enableTracking: true,
      captureAfterChange: true,
    );
  }

  Future<void> _marcarEnDestino() async {
    await _cambiarEstadoOperativo(
      DtexMision.estadoEnDestino,
      successMessage: 'Llegada a destino registrada.',
      errorMessage: 'No se pudo registrar llegada a destino.',
    );
  }

  Future<void> _marcarRetorno() async {
    await _cambiarEstadoOperativo(
      DtexMision.estadoRetorno,
      successMessage: 'Retorno registrado. Seguimiento activo.',
      errorMessage: 'No se pudo registrar retorno.',
      enableTracking: true,
    );
  }

  Future<void> _marcarEmergencia() async {
    await _cambiarEstadoOperativo(
      DtexMision.estadoEmergencia,
      successMessage: 'Emergencia reportada al sistema.',
      errorMessage: 'No se pudo reportar emergencia.',
      enableTracking: true,
      captureAfterChange: true,
    );
  }

  Future<void> _cambiarEstadoOperativo(
    String estado, {
    required String successMessage,
    required String errorMessage,
    bool enableTracking = false,
    bool captureAfterChange = false,
  }) async {
    final mission = _mision;
    if (mission == null) return;

    setState(() => _sending = true);
    await _primeGps();
    final current = _lastPosition;
    final ok = await _repository.cambiarEstadoMision(
      idMision: mission.idMision,
      estado: estado,
      lat: current?.latitude,
      lng: current?.longitude,
    );

    final updated =
        ok ? await _repository.getMisionById(mission.idMision) : null;
    if (!mounted) return;

    setState(() {
      _sending = false;
      if (ok && enableTracking) _trackingEnabled = true;
      if (ok && enableTracking) _startPosition ??= current;
      if (updated != null) {
        _mision = updated;
      } else if (ok) {
        _mision = mission.copyWith(
          estado: estado,
          updatedAt: DateTime.now(),
          tsInicioReal: estado == DtexMision.estadoEnRuta
              ? DateTime.now()
              : mission.tsInicioReal,
          tsLlegadaDestino: estado == DtexMision.estadoEnDestino
              ? DateTime.now()
              : mission.tsLlegadaDestino,
          tsSalidaDestino: estado == DtexMision.estadoRetorno
              ? DateTime.now()
              : mission.tsSalidaDestino,
        );
      }
      _insideDestination = _computeInsideDestination();
      _gpsStatus = ok ? successMessage : errorMessage;
    });

    if (ok && enableTracking) {
      _startAutomationLoop();
    }
    if (ok && captureAfterChange) {
      await _captureAndEvaluate();
    }
  }

  Future<void> _terminarMision() async {
    final mission = _mision;
    if (mission == null) return;

    setState(() => _sending = true);
    _trackingTimer?.cancel();
    final ok = await _repository.cambiarEstadoMision(
      idMision: mission.idMision,
      estado: DtexMision.estadoCompletada,
      lat: _lastPosition?.latitude,
      lng: _lastPosition?.longitude,
    );
    final updated =
        ok ? await _repository.getMisionById(mission.idMision) : null;
    if (!mounted) return;

    setState(() {
      _sending = false;
      _trackingEnabled = false;
      if (updated != null) {
        _mision = updated;
      } else if (ok) {
        _mision = mission.copyWith(
          estado: DtexMision.estadoCompletada,
          tsCierre: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      _gpsStatus = ok
          ? 'Misión cerrada. El custodio ya puede salir.'
          : 'No se pudo cerrar la misión.';
    });
    await _refreshMissionContext();
  }

  void _startAutomationLoop() {
    _trackingTimer?.cancel();
    _trackingTimer = Timer.periodic(_trackingInterval, (_) {
      _captureAndEvaluate();
    });
  }

  Future<void> _captureAndEvaluate() async {
    final mission = _mision;
    if (mission == null || !_trackingEnabled || _sending) return;

    final position = await getCurrentDtexPosition();
    if (position == null) {
      if (!mounted) return;
      setState(() {
        _gpsStatus = 'No se pudo leer GPS en este ciclo.';
      });
      return;
    }

    _startPosition ??= position;
    final ok = await _repository.reportarTrackingGps(
      idMision: mission.idMision,
      lat: position.latitude,
      lng: position.longitude,
      precisionM: position.accuracy,
      velocidadMs: position.speed,
      rumbo: position.heading,
      altitud: position.altitude,
    );

    if (!mounted) return;
    setState(() {
      _lastPosition = position;
      _gpsStatus = ok ? 'GPS enviado automáticamente.' : 'GPS no enviado.';
    });

    await _runAutomationRules(position);
  }

  Future<void> _runAutomationRules(DtexGeoPosition position) async {
    final mission = _mision;
    final destino = _destino;
    if (mission == null || destino == null) return;

    final nowInside = _distanceMeters(
          position.latitude,
          position.longitude,
          destino.latitud,
          destino.longitud,
        ) <=
        destino.radioMetros;

    if (nowInside && !_insideDestination) {
      _insideDestination = true;
      await _repository.cambiarEstadoMision(
        idMision: mission.idMision,
        estado: DtexMision.estadoEnDestino,
        lat: position.latitude,
        lng: position.longitude,
      );
      if (mounted) {
        setState(() {
          _mision = mission.copyWith(
            estado: DtexMision.estadoEnDestino,
            tsLlegadaDestino: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        });
      }
      await _refreshMissionContext();
    } else if (!nowInside &&
        _insideDestination &&
        _mision?.estadoNormalizado == DtexMision.estadoEnDestino) {
      _insideDestination = false;
      await _repository.cambiarEstadoMision(
        idMision: mission.idMision,
        estado: DtexMision.estadoRetorno,
        lat: position.latitude,
        lng: position.longitude,
      );
      if (mounted) {
        setState(() {
          _mision = mission.copyWith(
            estado: DtexMision.estadoRetorno,
            tsSalidaDestino: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        });
      }
      await _refreshMissionContext();
    } else {
      _insideDestination = nowInside;
    }

    await _maybeAlertDeviation(position);
    await _maybeAlertUnauthorizedStop(position);
  }

  Future<void> _maybeAlertDeviation(DtexGeoPosition position) async {
    final mission = _mision;
    final destino = _destino;
    final start = _startPosition;
    if (mission == null || destino == null || start == null) return;
    if (_insideDestination) return;

    final deviation = _distanceToSegmentMeters(
      point: LatLng(position.latitude, position.longitude),
      start: LatLng(start.latitude, start.longitude),
      end: LatLng(destino.latitud, destino.longitud),
    );
    if (deviation < _deviationThresholdMeters) return;

    final now = DateTime.now();
    if (_lastDeviationAlertAt != null &&
        now.difference(_lastDeviationAlertAt!) < _alertCooldown) {
      return;
    }

    _lastDeviationAlertAt = now;
    await _repository.insertarAlerta(
      idMision: mission.idMision,
      tipo: 'DESVIO',
      severidad: 'AVISO',
      descripcion:
          'Desvío detectado: ${deviation.toStringAsFixed(0)} m fuera del trayecto esperado.',
      latitud: position.latitude,
      longitud: position.longitude,
    );
    await _refreshMissionContext();
  }

  Future<void> _maybeAlertUnauthorizedStop(DtexGeoPosition position) async {
    final mission = _mision;
    if (mission == null) return;

    final speed = position.speed ?? 0;
    if (_insideDestination || speed > _movementThresholdMps) {
      _stoppedSince = null;
      return;
    }

    final now = DateTime.now();
    _stoppedSince ??= now;
    if (now.difference(_stoppedSince!) < _stopThreshold) return;

    if (_lastStopAlertAt != null &&
        now.difference(_lastStopAlertAt!) < _alertCooldown) {
      return;
    }

    _lastStopAlertAt = now;
    await _repository.insertarAlerta(
      idMision: mission.idMision,
      tipo: 'DETENIDO',
      severidad: 'AVISO',
      descripcion:
          'Parada no autorizada detectada fuera del destino por más de 5 minutos.',
      latitud: position.latitude,
      longitud: position.longitude,
    );
    await _refreshMissionContext();
  }

  bool _isMissionAlreadyStarted(DtexMision mission) {
    final state = mission.estadoNormalizado;
    return state == DtexMision.estadoEnRuta ||
        state == DtexMision.estadoEnDestino ||
        state == DtexMision.estadoRetorno ||
        state == DtexMision.estadoEmergencia;
  }

  bool _computeInsideDestination() {
    final destino = _destino;
    final point = _currentLatLng;
    if (destino == null || point == null) return false;
    return _distanceMeters(
          point.latitude,
          point.longitude,
          destino.latitud,
          destino.longitud,
        ) <=
        destino.radioMetros;
  }

  Future<DtexMision?> _missionFromOtpResponse(
    Map<String, dynamic> response,
  ) async {
    final direct = _mapValue(response, 'mision') ??
        _mapValue(response, 'mission') ??
        _mapValue(response, 'data');
    if (direct != null && direct.containsKey('id_mision')) {
      try {
        return DtexMision.fromJson(direct);
      } catch (_) {
        final id = direct['id_mision']?.toString();
        if (id != null && id.isNotEmpty) return _repository.getMisionById(id);
      }
    }

    final id = response['id_mision']?.toString() ??
        response['mision_id']?.toString() ??
        response['mission_id']?.toString();
    if (id != null && id.isNotEmpty) {
      return _repository.getMisionById(id);
    }

    return null;
  }

  DtexDestino? _destinoFromOtpResponse(Map<String, dynamic> response) {
    final direct =
        _mapValue(response, 'destino') ?? _mapValue(response, 'destination');
    if (direct == null || !direct.containsKey('id_destino')) return null;
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

  void _salir() {
    _trackingTimer?.cancel();
    _trackingSub?.cancel();
    setState(() {
      _mision = null;
      _destino = null;
      _tracking = <DtexTrackingPunto>[];
      _alertas = <DtexAlerta>[];
      _trackingEnabled = false;
      _insideDestination = false;
      _startPosition = null;
      _error = null;
      _gpsStatus = null;
    });
    _primeGps();
  }

  LatLng? get _currentLatLng {
    final p = _lastPosition;
    if (p == null) return null;
    return LatLng(p.latitude, p.longitude);
  }

  String get _distanceLabel {
    final destino = _destino;
    final point = _currentLatLng;
    if (destino == null || point == null) return 'N/D';
    final distance = _distanceMeters(
      point.latitude,
      point.longitude,
      destino.latitud,
      destino.longitud,
    );
    if (distance < 1000) return '${distance.toStringAsFixed(0)} m';
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  String get _etaLabel {
    final destino = _destino;
    final point = _currentLatLng;
    if (destino == null || point == null) return 'Calculando';
    final distance = _distanceMeters(
      point.latitude,
      point.longitude,
      destino.latitud,
      destino.longitud,
    );
    final speed = _lastPosition?.speed;
    final effectiveSpeed = (speed != null && speed > 1.5) ? speed : 8.33;
    final etaMin = distance / effectiveSpeed / 60;
    if (etaMin < 1) return '< 1 min';
    return '${etaMin.round()} min';
  }

  String get _routeStatusLabel {
    if (_tracking.isEmpty) return 'Sin traza aún';
    return '${_tracking.length} puntos';
  }

  String get _automationLabel {
    if (!_trackingEnabled) return 'Pendiente. Solo GPS preparado.';
    if (_insideDestination) {
      return 'Dentro del destino. Monitoreo de estancia activo.';
    }
    return 'Seguimiento automático, desvíos y paradas activas.';
  }

  String get _destinoStatusLabel {
    final destino = _destino;
    if (destino == null) return 'Destino sin coordenadas';
    final inside =
        _insideDestination ? 'Dentro del radio autorizado' : 'En trayecto';
    return '$inside (${destino.radioMetros} m)';
  }

  String get _estadoActual => _mision?.estadoNormalizado ?? '';

  bool get _canRegister {
    return !_sending && _estadoActual == DtexMision.estadoAbierta;
  }

  bool get _canStartRoute {
    return !_sending &&
        !_trackingEnabled &&
        (_estadoActual == DtexMision.estadoAbierta ||
            _estadoActual == DtexMision.estadoRegistroRealizado);
  }

  bool get _canMarkDestination {
    return !_sending &&
        _trackingEnabled &&
        (_estadoActual == DtexMision.estadoEnRuta ||
            _estadoActual == DtexMision.estadoRetorno ||
            _estadoActual == DtexMision.estadoEmergencia);
  }

  bool get _canMarkReturn {
    return !_sending &&
        _trackingEnabled &&
        _estadoActual == DtexMision.estadoEnDestino;
  }

  bool get _canReportEmergency {
    return !_sending &&
        _mision != null &&
        _estadoActual != DtexMision.estadoCompletada &&
        _estadoActual != DtexMision.estadoCancelada;
  }

  bool get _canFinish {
    return !_sending &&
        _trackingEnabled &&
        (_estadoActual == DtexMision.estadoRetorno ||
            _estadoActual == DtexMision.estadoEnDestino ||
            _estadoActual == DtexMision.estadoEmergencia);
  }

  BoxDecoration _shellDecoration(Color color) {
    return BoxDecoration(
      color: Colors.black.withValues(alpha: 0.34),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      counterText: '',
      labelStyle: TextStyle(color: Colors.white.withValues(alpha: 0.65)),
      filled: true,
      fillColor: Colors.black.withValues(alpha: 0.3),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppConstants.neonCyan),
      ),
    );
  }

  TextStyle _mutedStyle({double fontSize = 13}) {
    return TextStyle(
      color: Colors.white.withValues(alpha: 0.68),
      fontFamily: 'Rajdhani',
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
    );
  }

  Color _statusColor(String estado) {
    switch (estado.trim().toUpperCase()) {
      case DtexMision.estadoAbierta:
      case DtexMision.estadoRegistroRealizado:
        return AppConstants.alertOrange;
      case DtexMision.estadoEnRuta:
      case DtexMision.estadoRetorno:
        return AppConstants.neonCyan;
      case DtexMision.estadoEnDestino:
        return AppConstants.successGreen;
      case DtexMision.estadoEmergencia:
        return AppConstants.warningRed;
      case DtexMision.estadoCompletada:
        return Colors.white70;
      default:
        return Colors.white70;
    }
  }

  LatLng _center(List<LatLng> points) {
    final lat =
        points.map((p) => p.latitude).reduce((a, b) => a + b) / points.length;
    final lng =
        points.map((p) => p.longitude).reduce((a, b) => a + b) / points.length;
    return LatLng(lat, lng);
  }

  bool _isZeroPoint(LatLng p) => p.latitude == 0 && p.longitude == 0;

  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  double _distanceToSegmentMeters({
    required LatLng point,
    required LatLng start,
    required LatLng end,
  }) {
    final meanLat = (start.latitude + end.latitude + point.latitude) / 3;
    final startX = _lngToMeters(start.longitude, meanLat);
    final startY = _latToMeters(start.latitude);
    final endX = _lngToMeters(end.longitude, meanLat);
    final endY = _latToMeters(end.latitude);
    final pointX = _lngToMeters(point.longitude, meanLat);
    final pointY = _latToMeters(point.latitude);

    final dx = endX - startX;
    final dy = endY - startY;
    if (dx == 0 && dy == 0) {
      return math
          .sqrt(math.pow(pointX - startX, 2) + math.pow(pointY - startY, 2));
    }

    final t = (((pointX - startX) * dx) + ((pointY - startY) * dy)) /
        ((dx * dx) + (dy * dy));
    final clampedT = t.clamp(0.0, 1.0);
    final projX = startX + (dx * clampedT);
    final projY = startY + (dy * clampedT);
    return math.sqrt(math.pow(pointX - projX, 2) + math.pow(pointY - projY, 2));
  }

  double _latToMeters(double lat) => lat * 111111.0;

  double _lngToMeters(double lng, double atLat) {
    final cosLat = math.cos(_degToRad(atLat)).abs().clamp(0.2, 1.0);
    return lng * 111111.0 * cosLat;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}
