import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../data/models/dtex_destino_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/models/dtex_alerta_model.dart';
import '../../data/models/dtex_tracking_extension_model.dart';
import '../../data/models/dtex_policia_model.dart';
import '../../data/models/radio_message_model.dart';
import '../../data/repositories/dtex_repository.dart';
import '../../data/repositories/supabase_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/browser_notification.dart';
import '../../core/services/radio_rtc_signaling.dart';
import 'auth_controller.dart';

class DtexController extends GetxController {
  final repository = DtexRepository();
  final _radioRepository = SupabaseRepository();
  final AuthController _authController = Get.find<AuthController>();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ── Estado observable ────────────────────────────────────────────────────
  final destinos = <DtexDestino>[].obs;
  final misiones = <DtexMision>[].obs;
  final misionesActivas = <DtexMision>[].obs;
  final alertasPendientes = <DtexAlerta>[].obs;
  final extensiones = <DtexExtension>[].obs;
  final policiaAlfa = <DtexPolicia>[].obs;
  final policiaBravo = <DtexPolicia>[].obs;
  final allPolicia = <DtexPolicia>[].obs;

  // Tracking de la misión seleccionada en el mapa
  final trackingActivo = <DtexTrackingPunto>[].obs;
  final misionSeleccionada = Rx<DtexMision?>(null);

  // UI state
  final isLoading = false.obs;
  final loadingMessage = ''.obs;
  final isConnected = true.obs;
  final filterEstado = 'TODOS'.obs;

  // OTP recién generado para mostrar al supervisor
  final otpGenerado = Rx<String?>(null);

  // Notificaciones — ids ya vistos para no repetir
  final Set<String> _seenAlertIds = {};
  final Set<String> _seenExtensionIds = {};
  final Set<String> _seenMissionStartIds = {};
  final Set<String> _seenReportIds = {};
  bool _notificationBootstrapDone = false;
  bool _localNotificationsInitialized = false;
  bool _closingExpiredMissions = false;

  // Streams realtime
  StreamSubscription<List<DtexMision>>? _misionesSub;
  StreamSubscription<List<DtexAlerta>>? _alertasSub;
  StreamSubscription<List<DtexExtension>>? _extensionesSub;
  StreamSubscription<List<DtexTrackingPunto>>? _trackingSub;
  StreamSubscription<List<RadioMessage>>? _reportesSub;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    unawaited(_initializeNotifications());
    loadInitialData();
    _startRealtimeStreams();
  }

  @override
  void onClose() {
    _misionesSub?.cancel();
    _alertasSub?.cancel();
    _extensionesSub?.cancel();
    _trackingSub?.cancel();
    _reportesSub?.cancel();
    super.onClose();
  }

  // ── Carga inicial ────────────────────────────────────────────────────────

  Future<void> loadInitialData() async {
    try {
      if (kDebugMode) debugPrint('🚀 [DTEX] Iniciando loadInitialData...');

      isLoading.value = true;
      loadingMessage.value = 'Cargando módulo DTEX...';
      isConnected.value = true;

      if (kDebugMode) debugPrint('📋 [DTEX] Cargando datos en paralelo...');

      await Future.wait([
        loadDestinos(),
        loadMisiones(),
        loadAlertasPendientes(),
        loadExtensiones(),
        loadPolicia(),
      ]);
      _bootstrapNotificationState();

      if (kDebugMode) debugPrint('✅ [DTEX] Todos los datos cargados');

      if (kDebugMode) {
        debugPrint(
          '✅ [DTEX] Datos cargados: '
          '${destinos.length} destinos, '
          '${misiones.length} misiones, '
          '${alertasPendientes.length} alertas pendientes',
        );
      }

      isLoading.value = false;
      loadingMessage.value = '';
    } catch (e, stackTrace) {
      isConnected.value = false;
      isLoading.value = false;
      loadingMessage.value = '';

      if (kDebugMode) {
        debugPrint('❌ [DTEX] Error al cargar datos: $e');
        debugPrint('Stack: $stackTrace');
      }

      Get.snackbar(
        'Error de Conexión',
        'No se pudo cargar el módulo DTEX. Verifica tu conexión.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
        backgroundColor: AppConstants.warningRed.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    }
  }

  Future<void> loadDestinos() async {
    try {
      final data = await repository.getDestinos();
      destinos.value = data;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error loading destinos: $e');
    }
  }

  Future<void> loadPolicia() async {
    try {
      if (kDebugMode) debugPrint('🔄 [DTEX] Iniciando carga de policías...');

      // VERIFICAR ESTADO ANTES DE CARGAR
      if (kDebugMode) {
        debugPrint(
            '📊 [DTEX] Estado inicial allPolicia: ${allPolicia.length} elementos');
        debugPrint(
            '📊 [DTEX] Estado inicial policiaAlfa: ${policiaAlfa.length} elementos');
        debugPrint(
            '📊 [DTEX] Estado inicial policiaBravo: ${policiaBravo.length} elementos');
      }

      final alfaData = await repository.getPoliciaAlfa();
      final bravoData = await repository.getPoliciaBravo();
      final allData = [...alfaData, ...bravoData];

      policiaAlfa.value = alfaData;
      policiaBravo.value = bravoData;
      allPolicia.value = allData;

      if (kDebugMode) {
        debugPrint('✅ [DTEX] Cargados ${alfaData.length} policías ALFA');
        debugPrint('✅ [DTEX] Cargados ${bravoData.length} policías BRAVO');
        debugPrint('📊 [DTEX] Total policías: ${allData.length}');
        debugPrint(
            '📊 [DTEX] Estado final allPolicia: ${allPolicia.length} elementos');

        debugPrint('📋 [DTEX] Lista ALFA:');
        for (final p in alfaData) {
          debugPrint('  - ${p.grado} ${p.nombre} - ${p.cargo}');
        }
        debugPrint('📋 [DTEX] Lista BRAVO:');
        for (final p in bravoData) {
          debugPrint('  - ${p.grado} ${p.nombre} - ${p.cargo}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [DTEX] Error loading policia: $e');
        debugPrint('📍 [DTEX] Stack trace: ${StackTrace.current}');
      }
    }
  }

  Future<void> loadMisiones() async {
    try {
      var data = await repository.getMisiones(limit: 100);
      final closedAny = await _autoCloseExpiredMissions(data);
      if (closedAny) {
        data = await repository.getMisiones(limit: 100);
      }
      misiones.value = data;
      misionesActivas.value = _activeToday(data);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error loading misiones: $e');
    }
  }

  Future<void> loadAlertasPendientes() async {
    try {
      final data = await repository.getAlertasPendientes();
      alertasPendientes.value = data;
      _notifyNuevasAlertas(data);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error loading alertas: $e');
    }
  }

  Future<void> loadExtensiones() async {
    try {
      final data = await repository.getExtensionsPendientes();
      extensiones.value = data;
      _notifyNuevasExtensiones(data);
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error loading extensiones: $e');
    }
  }

  // ── Realtime streams ─────────────────────────────────────────────────────
  void _startRealtimeStreams() {
    // Misiones activas
    _misionesSub?.cancel();
    _misionesSub = repository.watchMisionesActivas().listen((data) {
      unawaited(_handleActiveMissionStream(data));
    });

    // Alertas pendientes
    _alertasSub?.cancel();
    _alertasSub = repository.watchAlertasPendientes().listen((data) {
      alertasPendientes.value = data;
      _notifyNuevasAlertas(data);
    });

    // Extensiones pendientes — stream en tiempo real
    _extensionesSub?.cancel();
    _extensionesSub = repository.watchExtensionesPendientes().listen((data) {
      extensiones.value = data;
      _notifyNuevasExtensiones(data);
    });

    _reportesSub?.cancel();
    _reportesSub =
        _radioRepository.watchSupervisorRadioInbox(limit: 80).listen((data) {
      _notifyNuevosReportes(data);
    });
  }

  Future<void> _handleActiveMissionStream(List<DtexMision> data) async {
    final closedAny = await _autoCloseExpiredMissions(data);
    if (closedAny) {
      await loadMisiones();
      return;
    }

    final activeToday = _activeToday(data);
    misionesActivas.value = activeToday;
    // Sincronizar también en la lista general
    for (final m in activeToday) {
      final idx = misiones.indexWhere((x) => x.idMision == m.idMision);
      if (idx >= 0) {
        misiones[idx] = m;
      } else {
        misiones.insert(0, m);
      }
    }
    _notifyMissionStarts(activeToday);
  }

  bool _isToday(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  bool _isMissionToday(DtexMision mission) {
    return _isToday(mission.horaSalidaAutorizada) ||
        (mission.createdAt != null && _isToday(mission.createdAt!));
  }

  List<DtexMision> _activeToday(Iterable<DtexMision> rows) {
    return rows
        .where((m) =>
            DtexMision.estadosActivos.contains(m.estadoNormalizado) &&
            _isMissionToday(m))
        .toList();
  }

  Future<bool> _autoCloseExpiredMissions(Iterable<DtexMision> rows) async {
    if (_closingExpiredMissions) return false;
    _closingExpiredMissions = true;
    var closedAny = false;
    try {
      final now = DateTime.now();
      for (final mission in rows) {
        if (!DtexMision.estadosActivos.contains(mission.estadoNormalizado)) {
          continue;
        }
        final startedAt =
            (mission.tsInicioReal ?? mission.horaSalidaAutorizada).toLocal();
        final maxMinutes = mission.tiempoMaxEstadiMin.clamp(30, 180).toInt();
        final deadline = startedAt.add(Duration(minutes: maxMinutes));
        if (now.isBefore(deadline)) continue;

        final ok = await repository.cerrarMisionVencida(
          mision: mission,
          motivo:
              'Misión cerrada automáticamente por vencimiento de tiempo operativo ($maxMinutes min).',
        );
        closedAny = closedAny || ok;
      }
    } finally {
      _closingExpiredMissions = false;
    }
    return closedAny;
  }

  /// Suscribir tracking GPS de la misión seleccionada.
  void seleccionarMision(DtexMision mision) {
    misionSeleccionada.value = mision;
    _trackingSub?.cancel();
    trackingActivo.clear();

    if (mision.estaActiva) {
      _trackingSub = repository.watchTracking(mision.idMision).listen((puntos) {
        trackingActivo.value = puntos;
      });
    } else {
      // Misión cerrada: cargar historial completo una sola vez
      repository.getTrackingMision(idMision: mision.idMision).then((puntos) {
        trackingActivo.value = puntos;
      });
    }
  }

  void deseleccionarMision() {
    _trackingSub?.cancel();
    misionSeleccionada.value = null;
    trackingActivo.clear();
  }

  // ── Acciones del supervisor ───────────────────────────────────────────────

  /// Crea una misión nueva y retorna el OTP generado para mostrárselo al supervisor.
  Future<String?> crearMision({
    required String tipoDiligencia,
    required String reoNombre,
    required String reoCi,
    String? reoExpediente,
    required String custodioNombre,
    required String custodioCodigo,
    required String custodioGrado,
    required DtexDestino destino,
    required DateTime horaSalida,
    required int tiempoMaxMin,
    String? referenciaLegal,
    String? notas,
  }) async {
    try {
      isLoading.value = true;
      loadingMessage.value = 'Creando misión...';

      final supervisor = _authController.currentAdmin.value;
      if (supervisor == null) {
        _snackError('Sin sesión', 'No se encontró sesión del supervisor.');
        return null;
      }

      final mision = DtexMision(
        idMision: '',
        tipoDiligencia: tipoDiligencia,
        reoNombre: reoNombre,
        reoCi: reoCi,
        reoExpediente: reoExpediente,
        custodioNombre: custodioNombre,
        custodioCodigo: custodioCodigo,
        custodioGrado: custodioGrado,
        idDestino: destino.idDestino,
        destinoNombre: destino.nombre,
        horaSalidaAutorizada: horaSalida,
        tiempoMaxEstadiMin: tiempoMaxMin,
        referenciaLegal: referenciaLegal,
        codigoOtp: '',
        supervisorEmail: supervisor.email,
        supervisorNombre: supervisor.nombre,
        notas: notas,
      );

      final idMision = await repository.crearMision(mision);
      if (idMision == null) {
        _snackError('Error', 'No se pudo crear la misión. Intenta de nuevo.');
        return null;
      }

      final otp = await repository.getOtpDeMision(idMision);
      otpGenerado.value = otp;

      await loadMisiones();
      final nuevaMision =
          misiones.firstWhereOrNull((m) => m.idMision == idMision);
      if (nuevaMision != null) {
        seleccionarMision(nuevaMision);
      }

      if (kDebugMode) debugPrint('✅ [DTEX] Misión creada. OTP: $otp');

      Get.snackbar(
        '✅ Misión Creada',
        'Código OTP para el custodio: $otp',
        snackPosition: SnackPosition.TOP,
        duration: const Duration(seconds: 8),
        backgroundColor: const Color(0xFF00FFD1).withValues(alpha: 0.15),
        colorText: const Color(0xFF00FFD1),
      );

      return otp;
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error creando misión: $e');
      _snackError('Error', 'Error inesperado al crear la misión.');
      return null;
    } finally {
      isLoading.value = false;
      loadingMessage.value = '';
    }
  }

  Future<void> cancelarMision(String idMision) async {
    try {
      final ok = await repository.cancelarMision(idMision);
      if (ok) {
        await loadMisiones();
        Get.snackbar(
          'Misión Cancelada',
          'La misión fue cancelada correctamente.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppConstants.warningRed.withValues(alpha: 0.9),
          colorText: Colors.white,
        );
      } else {
        _snackError('Error', 'No se pudo cancelar la misión.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error cancelando misión: $e');
    }
  }

  Future<void> resolverAlerta({
    required String idAlerta,
    String? nota,
  }) async {
    try {
      final supervisor = _authController.currentAdmin.value;
      if (supervisor == null) return;

      final ok = await repository.resolverAlerta(
        idAlerta: idAlerta,
        resueltaPor: supervisor.email,
        nota: nota,
      );

      if (ok) {
        alertasPendientes.removeWhere((a) => a.idAlerta == idAlerta);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error resolviendo alerta: $e');
    }
  }

  Future<void> responderExtension({
    required String idExtension,
    required bool aprobada,
  }) async {
    try {
      final supervisor = _authController.currentAdmin.value;
      if (supervisor == null) return;

      final ok = await repository.responderExtension(
        idExtension: idExtension,
        aprobada: aprobada,
        respondidoPor: supervisor.email,
      );

      if (ok) {
        extensiones.removeWhere((e) => e.idExtension == idExtension);
        Get.snackbar(
          aprobada ? '✅ Extensión Aprobada' : 'Extensión Rechazada',
          aprobada
              ? 'El custodio fue notificado.'
              : 'La solicitud fue rechazada.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: aprobada
              ? const Color(0xFF00FFD1).withValues(alpha: 0.15)
              : AppConstants.warningRed.withValues(alpha: 0.9),
          colorText: aprobada ? const Color(0xFF00FFD1) : Colors.white,
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error respondiendo extensión: $e');
    }
  }

  Future<void> cerrarMisionManual({
    required String idMision,
    required String conductaFinal,
  }) async {
    try {
      final conducta = conductaFinal.trim().toUpperCase();
      if (!DtexMision.conductaFinalValida(conducta)) {
        _snackError('DTEX', 'Selecciona una conducta final valida.');
        return;
      }

      final ok = await repository.cerrarMisionConConducta(
        idMision: idMision,
        conductaFinal: conducta,
      );

      if (ok) {
        await loadMisiones();
        if (misionSeleccionada.value?.idMision == idMision) {
          deseleccionarMision();
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('❌ [DTEX] Error cerrando misión: $e');
    }
  }

  // ── Getters computados ───────────────────────────────────────────────────

  List<DtexMision> get misionesFiltradas {
    final today = misiones.where(_isMissionToday).toList();
    if (filterEstado.value == 'TODOS') return today;
    return today
        .where((m) => m.estadoNormalizado == filterEstado.value)
        .toList();
  }

  List<DtexAlerta> get alertasEmergencia =>
      alertasPendientes.where((a) => a.esEmergencia).toList();

  int get totalMisionesHoy {
    return misiones.where(_isMissionToday).length;
  }

  int get totalMisionesActivas => misionesActivas.length;

  int get totalAlertasPendientes => alertasPendientes.length;

  int get totalExtensiones => extensiones.length;

  /// Última posición conocida de la misión seleccionada.
  DtexTrackingPunto? get ultimaPosicion =>
      trackingActivo.isNotEmpty ? trackingActivo.last : null;

  /// Tiempo transcurrido desde el inicio de la misión seleccionada.
  Duration? get tiempoMisionActiva {
    final m = misionSeleccionada.value;
    if (m == null || m.tsInicioReal == null) return null;
    return DateTime.now().difference(m.tsInicioReal!);
  }

  // ── Lógica de detección de parada anómala ────────────────────────────────
  // No usamos API de tráfico externa. Detectamos paradas por velocidad GPS
  // y tiempo detenido. Si velocidad < 0.5 m/s por más de 5 minutos
  // fuera del geofence del destino → parada sospechosa.

  bool detectarParadaSospechosa({
    required List<DtexTrackingPunto> puntos,
    required double destinoLat,
    required double destinoLng,
    required int radioMetros,
    int umbralMinutos = 5,
  }) {
    if (puntos.length < 2) return false;

    // Tomar los últimos puntos del período umbral
    final ahora = DateTime.now();
    final limite = ahora.subtract(Duration(minutes: umbralMinutos));
    final recientes = puntos.where((p) => p.ts.isAfter(limite)).toList();

    if (recientes.isEmpty) return false;

    // Verificar si todos los puntos recientes están detenidos
    final todosDetenidos = recientes.every((p) => p.estaDetenido);
    if (!todosDetenidos) return false;

    // Verificar si están fuera del geofence del destino
    final ultimo = recientes.last;
    final distancia = _calcularDistanciaMetros(
      ultimo.latitud,
      ultimo.longitud,
      destinoLat,
      destinoLng,
    );

    // Si está dentro del geofence del destino, es normal
    if (distancia <= radioMetros) return false;

    // También verificar geofence del penal (coordenadas fijas Morros Blancos)
    // TODO: mover a app_constants cuando estén confirmadas
    const penalLat = -21.5850;
    const penalLng = -64.7220;
    final distanciaAlPenal = _calcularDistanciaMetros(
      ultimo.latitud,
      ultimo.longitud,
      penalLat,
      penalLng,
    );
    if (distanciaAlPenal <= 150) return false;

    return true;
  }

  /// Fórmula Haversine para calcular distancia en metros entre dos coordenadas.
  double _calcularDistanciaMetros(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const R = 6371000.0; // Radio de la Tierra en metros
    final dLat = _deg2rad(lat2 - lat1);
    final dLng = _deg2rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_deg2rad(lat1)) *
            math.cos(_deg2rad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (math.pi / 180);

  // ── Notificaciones internas ───────────────────────────────────────────────

  Future<void> _initializeNotifications() async {
    await BrowserNotification.ensurePermission();
    if (kIsWeb || _localNotificationsInitialized) return;

    try {
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android);
      await _localNotifications.initialize(settings: settings);
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      _localNotificationsInitialized = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [DTEX] Notificaciones locales no disponibles: $e');
      }
    }
  }

  void _bootstrapNotificationState() {
    if (_notificationBootstrapDone) return;
    for (final alerta in alertasPendientes) {
      _seenAlertIds.add(alerta.idAlerta);
    }
    for (final ext in extensiones) {
      _seenExtensionIds.add(ext.idExtension);
    }
    for (final mision in misionesActivas) {
      if (_isMissionStarted(mision)) {
        _seenMissionStartIds.add(mision.idMision);
      }
    }
    _notificationBootstrapDone = true;
  }

  void _notifyNuevasAlertas(List<DtexAlerta> alertas) {
    for (final alerta in alertas) {
      if (_seenAlertIds.contains(alerta.idAlerta)) continue;
      _seenAlertIds.add(alerta.idAlerta);

      if (!_notificationBootstrapDone) continue;
      if (!_isRecentForNotification(alerta.ts, const Duration(hours: 12))) {
        continue;
      }

      final title = alerta.esEmergencia
          ? 'DTEX EMERGENCIA'
          : 'DTEX ALERTA ${alerta.severidad.toUpperCase()}';
      final body = '${alerta.tipoDisplay}: ${alerta.descripcion}';
      _showSupervisorNotification(
        key: 'dtex_alert:${alerta.idAlerta}',
        title: title,
        body: body,
        critical: alerta.esEmergencia,
      );
    }
  }

  void _notifyNuevasExtensiones(List<DtexExtension> exts) {
    for (final ext in exts) {
      if (_seenExtensionIds.contains(ext.idExtension)) continue;
      _seenExtensionIds.add(ext.idExtension);
      if (!_notificationBootstrapDone) continue;

      if (kDebugMode) {
        debugPrint(
            '📋 [DTEX] Nueva extensión solicitada: ${ext.minutosSolicitados} min — ${ext.motivo}');
      }
      _showSupervisorNotification(
        key: 'dtex_extension:${ext.idExtension}',
        title: 'DTEX EXTENSION SOLICITADA',
        body: '${ext.minutosSolicitados} min: ${ext.motivo}',
      );
    }
  }

  void _notifyMissionStarts(List<DtexMision> misiones) {
    for (final mision in misiones) {
      if (!_isMissionStarted(mision)) continue;
      if (_seenMissionStartIds.contains(mision.idMision)) continue;
      _seenMissionStartIds.add(mision.idMision);
      if (!_notificationBootstrapDone) continue;

      final startedAt = mision.tsInicioReal ?? DateTime.now();
      if (!_isRecentForNotification(startedAt, const Duration(hours: 12))) {
        continue;
      }

      _showSupervisorNotification(
        key: 'dtex_start:${mision.idMision}',
        title: 'DTEX MISION INICIADA',
        body:
            '${mision.custodioGrado} ${mision.custodioNombre} en ruta a ${mision.destinoNombre}',
      );
    }
  }

  void _notifyNuevosReportes(List<RadioMessage> rows) {
    for (final msg in rows.take(20)) {
      if (_seenReportIds.contains(msg.idMensaje)) continue;
      _seenReportIds.add(msg.idMensaje);
      if (!_notificationBootstrapDone) continue;
      if (RadioRtcSignal.isRtcPayload(msg.mensaje)) continue;
      if (!_isDtexSupervisorReport(msg)) continue;
      if (!_isRecentForNotification(msg.timestamp, const Duration(hours: 12))) {
        continue;
      }

      _showSupervisorNotification(
        key: 'dtex_report:${msg.idMensaje}',
        title: 'DTEX REPORTE RECIBIDO',
        body: _compactNotificationBody(msg.mensaje),
      );
    }
  }

  bool _isMissionStarted(DtexMision mision) {
    return mision.estadoNormalizado == DtexMision.estadoEnRuta ||
        mision.estadoNormalizado == DtexMision.estadoEnDestino ||
        mision.estadoNormalizado == DtexMision.estadoRetorno ||
        mision.estadoNormalizado == DtexMision.estadoEmergencia ||
        mision.tsInicioReal != null;
  }

  bool _isDtexSupervisorReport(RadioMessage msg) {
    final type = msg.tipo.trim().toUpperCase();
    final text = msg.mensaje.trim().toUpperCase();
    final from = msg.deUsuario.trim().toUpperCase();
    return msg.isIncomingForSupervisor &&
        from.startsWith('DTEX:') &&
        (type == 'PARTE_NOVEDAD' ||
            text.startsWith('[PARTE_NOVEDAD]') ||
            text.contains('REPORTE DE SITUACION DTEX') ||
            text.contains('REPORTE DE SITUACIÓN DTEX') ||
            text.contains('MISION:') ||
            text.contains('MISIÓN:'));
  }

  bool _isRecentForNotification(DateTime timestamp, Duration window) {
    final age = DateTime.now().difference(timestamp.toLocal());
    if (age.isNegative) return true;
    return age <= window;
  }

  String _compactNotificationBody(String raw) {
    final clean = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 140) return clean;
    return '${clean.substring(0, 140)}...';
  }

  void _showSupervisorNotification({
    required String key,
    required String title,
    required String body,
    bool critical = false,
  }) {
    if (!BrowserNotification.shouldNotify(
      key,
      ttl: const Duration(hours: 36),
    )) {
      return;
    }

    BrowserNotification.show(title: title, body: body);
    unawaited(_showLocalSupervisorNotification(
      key: key,
      title: title,
      body: body,
      critical: critical,
    ));

    Get.snackbar(
      title,
      body,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.only(top: 14, right: 14, left: 14),
      maxWidth: 460,
      borderRadius: 10,
      backgroundColor: Colors.black.withValues(alpha: 0.86),
      colorText: Colors.white,
      duration: Duration(seconds: critical ? 6 : 4),
      icon: Icon(
        critical
            ? Icons.warning_amber_rounded
            : Icons.notifications_active_rounded,
        color: critical ? AppConstants.warningRed : AppConstants.neonCyan,
      ),
      shouldIconPulse: critical,
    );
  }

  Future<void> _showLocalSupervisorNotification({
    required String key,
    required String title,
    required String body,
    required bool critical,
  }) async {
    if (kIsWeb) return;
    try {
      await _initializeNotifications();
      final android = AndroidNotificationDetails(
        'dtex_supervisor_operativo',
        'DTEX Supervisor',
        channelDescription: 'Alertas, comienzos y reportes de misiones DTEX',
        importance: critical ? Importance.max : Importance.high,
        priority: critical ? Priority.max : Priority.high,
        playSound: true,
        enableVibration: true,
      );
      await _localNotifications.show(
        id: key.hashCode.abs() % 100000,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: android),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('⚠️ [DTEX] No se pudo mostrar notificación local: $e');
      }
    }
  }

  // ── Utilidades privadas ───────────────────────────────────────────────────

  void _snackError(String title, String message) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 4),
      backgroundColor: AppConstants.warningRed.withValues(alpha: 0.9),
      colorText: Colors.white,
    );
  }
}
