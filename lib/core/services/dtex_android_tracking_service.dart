import 'dart:async';
import 'dart:math' as math;

import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart' as permissions;
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/models/dtex_destino_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/repositories/dtex_repository.dart';
import 'dtex_geo_position.dart';

class DtexTelemetrySnapshot {
  final DtexGeoPosition position;
  final int? batteryPct;
  final String networkStatus;
  final bool locationServiceEnabled;
  final DateTime timestamp;

  const DtexTelemetrySnapshot({
    required this.position,
    required this.batteryPct,
    required this.networkStatus,
    required this.locationServiceEnabled,
    required this.timestamp,
  });
}

class DtexAndroidTrackingService {
  DtexAndroidTrackingService({
    DtexRepository? repository,
    Battery? battery,
    Connectivity? connectivity,
    FlutterLocalNotificationsPlugin? notifications,
  })  : _repository = repository ?? DtexRepository(),
        _battery = battery ?? Battery(),
        _connectivity = connectivity ?? Connectivity(),
        _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const Duration reportInterval = Duration(seconds: 15);
  static const double destinationAutoArrivalMeters = 80;
  static const double destinationAlertDeadZoneMeters = 50;
  static const double movementThresholdMps = 0.8;
  static const double deviationThresholdMeters = 250;
  static const Duration deviationAlertCooldown = Duration(minutes: 5);
  static const double poorGpsAccuracyMeters = 80;
  static const int lowBatteryPct = 15;
  static const int criticalBatteryPct = 8;
  static const Duration stoppedOutsideDestinationThreshold =
      Duration(minutes: 4);
  static const Duration technicalAlertCooldown = Duration(minutes: 6);

  final DtexRepository _repository;
  final Battery _battery;
  final Connectivity _connectivity;
  final FlutterLocalNotificationsPlugin _notifications;

  StreamSubscription<Position>? _positionSub;
  DateTime? _lastReportAt;
  DtexGeoPosition? _firstRoutePoint;
  bool _insideDestination = false;
  bool _arrivalReported = false;
  bool _returnReported = false;
  bool _initializedNotifications = false;
  DateTime? _lastDeviationAlertAt;
  DateTime? _stoppedOutsideDestinationSince;
  final Map<String, DateTime> _lastTechnicalAlertAt = <String, DateTime>{};

  Future<void> initialize() async {
    if (_initializedNotifications) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings: settings);
    _initializedNotifications = true;
  }

  Future<bool> requestOperationalPermissions() async {
    await initialize();
    await permissions.Permission.notification.request();

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    var location = await Geolocator.checkPermission();
    if (location == LocationPermission.denied) {
      location = await Geolocator.requestPermission();
    }

    if (location == LocationPermission.denied ||
        location == LocationPermission.deniedForever) {
      return false;
    }

    await permissions.Permission.locationAlways.request();
    await WakelockPlus.enable();
    return true;
  }

  Future<DtexGeoPosition?> currentPosition() async {
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: Duration(seconds: 12),
      ),
    );
    return _toDtexPosition(position);
  }

  Future<bool> start({
    required DtexMision mission,
    required DtexDestino destino,
    required void Function(DtexTelemetrySnapshot snapshot) onTelemetry,
    required void Function(String message) onStatus,
    bool ensurePermissions = true,
  }) async {
    if (ensurePermissions) {
      final ok = await requestOperationalPermissions();
      if (!ok) {
        onStatus('Permisos de ubicación incompletos.');
        return false;
      }
    }

    _firstRoutePoint = null;
    _insideDestination = false;
    _arrivalReported = mission.estadoNormalizado == DtexMision.estadoEnDestino;
    _returnReported = mission.estadoNormalizado == DtexMision.estadoRetorno;
    _lastReportAt = null;
    _lastDeviationAlertAt = null;
    _stoppedOutsideDestinationSince = null;
    _lastTechnicalAlertAt.clear();

    await _showOperationalNotification(
        'DTEX activo', 'Seguimiento de diligencia en curso.');

    final settings = AndroidSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 8,
      intervalDuration: reportInterval,
      foregroundNotificationConfig: ForegroundNotificationConfig(
        notificationTitle: 'DTEX Custodio activo',
        notificationText: 'Reportando ubicación de diligencia externa.',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );

    try {
      await _positionSub?.cancel();
      _positionSub = Geolocator.getPositionStream(locationSettings: settings)
          .listen((position) async {
        final dtexPosition = _toDtexPosition(position);
        _firstRoutePoint ??= dtexPosition;
        final now = DateTime.now();
        final batteryPct = await _safeBatteryLevel();
        final network = await _networkLabel();
        final snapshot = DtexTelemetrySnapshot(
          position: dtexPosition,
          batteryPct: batteryPct,
          networkStatus: network,
          locationServiceEnabled: await Geolocator.isLocationServiceEnabled(),
          timestamp: now,
        );

        if (_lastReportAt == null ||
            now.difference(_lastReportAt!) >= reportInterval) {
          _lastReportAt = now;
          await _repository.reportarTrackingGps(
            idMision: mission.idMision,
            lat: dtexPosition.latitude,
            lng: dtexPosition.longitude,
            precisionM: dtexPosition.accuracy,
            velocidadMs: dtexPosition.speed,
            rumbo: dtexPosition.heading,
            altitud: dtexPosition.altitude,
            bateriaPct: batteryPct,
            gpsActivo: snapshot.locationServiceEnabled,
          );
        }

        await _evaluateAutomation(
          mission: mission,
          destino: destino,
          position: dtexPosition,
          batteryPct: batteryPct,
          networkStatus: network,
          locationServiceEnabled: snapshot.locationServiceEnabled,
          onStatus: onStatus,
        );

        onTelemetry(snapshot);
      }, onError: (_) {
        onStatus('GPS interrumpido. Verifica permisos y ubicación.');
      });
      return true;
    } catch (_) {
      onStatus('No se pudo iniciar el seguimiento GPS.');
      return false;
    }
  }

  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    await WakelockPlus.disable();
    await _notifications.cancel(id: 901);
  }

  Future<void> _evaluateAutomation({
    required DtexMision mission,
    required DtexDestino destino,
    required DtexGeoPosition position,
    required int? batteryPct,
    required String networkStatus,
    required bool locationServiceEnabled,
    required void Function(String message) onStatus,
  }) async {
    final destinationDistance = _distanceMeters(
      position.latitude,
      position.longitude,
      destino.latitud,
      destino.longitud,
    );
    final insideDestination =
        destinationDistance <= math.max(destino.radioMetros, 60);

    if (insideDestination && !_arrivalReported) {
      _arrivalReported = true;
      _insideDestination = true;
      await _repository.cambiarEstadoMision(
        idMision: mission.idMision,
        estado: DtexMision.estadoEnDestino,
        lat: position.latitude,
        lng: position.longitude,
      );
      await _showOperationalNotification(
        'Llegada a destino',
        'Reporte automático: llegada sin novedad.',
      );
      onStatus('Llegada a destino reportada automáticamente.');
    }

    final speed = position.speed ?? 0;
    if (_insideDestination &&
        !insideDestination &&
        speed >= movementThresholdMps &&
        !_returnReported) {
      _returnReported = true;
      _insideDestination = false;
      await _repository.cambiarEstadoMision(
        idMision: mission.idMision,
        estado: DtexMision.estadoRetorno,
        lat: position.latitude,
        lng: position.longitude,
      );
      await _showOperationalNotification(
        'En ruta',
        'Movimiento detectado fuera del destino.',
      );
      onStatus('Movimiento detectado. Retorno/en ruta reportado.');
    }

    await _maybeReportDeviation(mission, destino, position);
    await _maybeReportTechnicalAlerts(
      mission: mission,
      destino: destino,
      position: position,
      destinationDistance: destinationDistance,
      insideDestination: insideDestination,
      batteryPct: batteryPct,
      networkStatus: networkStatus,
      locationServiceEnabled: locationServiceEnabled,
      onStatus: onStatus,
    );
  }

  Future<void> _maybeReportDeviation(
    DtexMision mission,
    DtexDestino destino,
    DtexGeoPosition position,
  ) async {
    final start = _firstRoutePoint;
    if (start == null || _insideDestination) return;

    final deviation = _distanceToSegmentMeters(
      point: LatLng(position.latitude, position.longitude),
      start: LatLng(start.latitude, start.longitude),
      end: LatLng(destino.latitud, destino.longitud),
    );
    if (deviation < deviationThresholdMeters) return;

    final now = DateTime.now();
    final lastAlertAt = _lastDeviationAlertAt;
    if (lastAlertAt != null &&
        now.difference(lastAlertAt) < deviationAlertCooldown) {
      return;
    }
    _lastDeviationAlertAt = now;

    await _repository.insertarAlerta(
      idMision: mission.idMision,
      tipo: 'DESVIO_RUTA',
      severidad: 'AVISO',
      descripcion:
          'Desvio automatico detectado: ${deviation.toStringAsFixed(0)} m fuera del trayecto esperado.',
      latitud: position.latitude,
      longitud: position.longitude,
    );
  }

  Future<void> _maybeReportTechnicalAlerts({
    required DtexMision mission,
    required DtexDestino destino,
    required DtexGeoPosition position,
    required double destinationDistance,
    required bool insideDestination,
    required int? batteryPct,
    required String networkStatus,
    required bool locationServiceEnabled,
    required void Function(String message) onStatus,
  }) async {
    final inDestinationDeadZone = _insideDestination &&
        destinationDistance <= destinationAlertDeadZoneMeters;

    if (!locationServiceEnabled) {
      await _sendThrottledAlert(
        mission: mission,
        tipo: 'UBICACION_APAGADA',
        severidad: 'EMERGENCIA',
        descripcion: 'Ubicacion del dispositivo desactivada durante mision.',
        position: position,
        onStatus: onStatus,
      );
    }

    final accuracy = position.accuracy;
    if (!inDestinationDeadZone &&
        accuracy != null &&
        accuracy > poorGpsAccuracyMeters) {
      await _sendThrottledAlert(
        mission: mission,
        tipo: 'GPS_PRECISION_BAJA',
        severidad: 'AVISO',
        descripcion:
            'Precision GPS degradada: ${accuracy.toStringAsFixed(0)} m.',
        position: position,
        onStatus: onStatus,
      );
    }

    if (batteryPct != null && batteryPct <= lowBatteryPct) {
      final critical = batteryPct <= criticalBatteryPct;
      await _sendThrottledAlert(
        mission: mission,
        tipo: 'BATERIA_CRITICA',
        severidad: critical ? 'EMERGENCIA' : 'AVISO',
        descripcion: 'Bateria del dispositivo en $batteryPct%.',
        position: position,
        onStatus: onStatus,
      );
    }

    if (!inDestinationDeadZone && networkStatus == 'SIN_RED') {
      await _sendThrottledAlert(
        mission: mission,
        tipo: 'SIN_CONEXION',
        severidad: 'AVISO',
        descripcion: 'Dispositivo sin conexion de datos durante mision.',
        position: position,
        onStatus: onStatus,
      );
    }

    final speed = position.speed ?? 0;
    if (!insideDestination && speed < movementThresholdMps) {
      _stoppedOutsideDestinationSince ??= DateTime.now();
    } else {
      _stoppedOutsideDestinationSince = null;
    }

    final stoppedSince = _stoppedOutsideDestinationSince;
    if (stoppedSince != null &&
        DateTime.now().difference(stoppedSince) >=
            stoppedOutsideDestinationThreshold) {
      final distanceToDestination = _distanceMeters(
        position.latitude,
        position.longitude,
        destino.latitud,
        destino.longitud,
      );
      await _sendThrottledAlert(
        mission: mission,
        tipo: 'PARADA_NO_AUTORIZADA',
        severidad: 'AVISO',
        descripcion:
            'Parada fuera de destino por mas de ${stoppedOutsideDestinationThreshold.inMinutes} min. Distancia al destino: ${distanceToDestination.toStringAsFixed(0)} m.',
        position: position,
        onStatus: onStatus,
      );
    }
  }

  Future<void> _sendThrottledAlert({
    required DtexMision mission,
    required String tipo,
    required String severidad,
    required String descripcion,
    required DtexGeoPosition position,
    required void Function(String message) onStatus,
  }) async {
    final now = DateTime.now();
    final last = _lastTechnicalAlertAt[tipo];
    if (last != null && now.difference(last) < technicalAlertCooldown) {
      return;
    }
    _lastTechnicalAlertAt[tipo] = now;

    final ok = await _repository.insertarAlerta(
      idMision: mission.idMision,
      tipo: tipo,
      severidad: severidad,
      descripcion: descripcion,
      latitud: position.latitude,
      longitud: position.longitude,
    );
    if (ok) {
      onStatus('INFRACCION DTEX: $tipo registrada para supervisor.');
    }
  }

  Future<int?> _safeBatteryLevel() async {
    try {
      return await _battery.batteryLevel;
    } catch (_) {
      return null;
    }
  }

  Future<String> _networkLabel() async {
    try {
      final value = await _connectivity.checkConnectivity();
      if (value.contains(ConnectivityResult.mobile)) return 'DATOS';
      if (value.contains(ConnectivityResult.wifi)) return 'WIFI';
      if (value.contains(ConnectivityResult.none)) return 'SIN_RED';
      return value.map((e) => e.name.toUpperCase()).join(',');
    } catch (_) {
      return 'N/D';
    }
  }

  Future<void> _showOperationalNotification(String title, String body) async {
    const android = AndroidNotificationDetails(
      'dtex_operativo',
      'DTEX Operativo',
      channelDescription: 'Alertas operativas de diligencias externas',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: false,
    );
    const details = NotificationDetails(android: android);
    await _notifications.show(
      id: 901,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  DtexGeoPosition _toDtexPosition(Position position) {
    return DtexGeoPosition(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      speed: position.speed,
      heading: position.heading,
      altitude: position.altitude,
    );
  }

  double _distanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
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
    final sx = start.longitude;
    final sy = start.latitude;
    final ex = end.longitude;
    final ey = end.latitude;
    final px = point.longitude;
    final py = point.latitude;

    final dx = ex - sx;
    final dy = ey - sy;
    if (dx == 0 && dy == 0) {
      return _distanceMeters(py, px, sy, sx);
    }
    final t = (((px - sx) * dx) + ((py - sy) * dy)) / ((dx * dx) + (dy * dy));
    final clamped = t.clamp(0.0, 1.0);
    final projX = sx + clamped * dx;
    final projY = sy + clamped * dy;
    return _distanceMeters(py, px, projY, projX);
  }

  double _degToRad(double deg) => deg * math.pi / 180;
}
