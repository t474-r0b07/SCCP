import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../data/models/dtex_destino_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/models/dtex_alerta_model.dart';
import '../../data/models/dtex_tracking_extension_model.dart';
import '../../data/repositories/dtex_repository.dart';
import '../../core/constants/app_constants.dart';
import 'auth_controller.dart';

class DtexController extends GetxController {
  final repository = DtexRepository();
  final AuthController _authController = Get.find<AuthController>();

  // ── Estado observable ────────────────────────────────────────────────────
  final destinos = <DtexDestino>[].obs;
  final misiones = <DtexMision>[].obs;
  final misionesActivas = <DtexMision>[].obs;
  final alertasPendientes = <DtexAlerta>[].obs;
  final extensiones = <DtexExtension>[].obs;

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

  // Streams realtime
  StreamSubscription<List<DtexMision>>? _misionesSub;
  StreamSubscription<List<DtexAlerta>>? _alertasSub;
  StreamSubscription<List<DtexExtension>>? _extensionesSub;
  StreamSubscription<List<DtexTrackingPunto>>? _trackingSub;

  // ── Lifecycle ────────────────────────────────────────────────────────────

  @override
  void onInit() {
    super.onInit();
    loadInitialData();
    _startRealtimeStreams();
  }

  @override
  void onClose() {
    _misionesSub?.cancel();
    _alertasSub?.cancel();
    _extensionesSub?.cancel();
    _trackingSub?.cancel();
    super.onClose();
  }

  // ── Carga inicial ────────────────────────────────────────────────────────

  Future<void> loadInitialData() async {
    try {
      isLoading.value = true;
      loadingMessage.value = 'Cargando módulo DTEX...';
      isConnected.value = true;

      await Future.wait([
        loadDestinos(),
        loadMisiones(),
        loadAlertasPendientes(),
        loadExtensiones(),
      ]);

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

  Future<void> loadMisiones() async {
    try {
      final data = await repository.getMisiones(limit: 100);
      misiones.value = data;
      misionesActivas.value = data
          .where((m) => DtexMision.estadosActivos.contains(m.estadoNormalizado))
          .toList();
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
      misionesActivas.value = data;
      // Sincronizar también en la lista general
      for (final m in data) {
        final idx = misiones.indexWhere((x) => x.idMision == m.idMision);
        if (idx >= 0) {
          misiones[idx] = m;
        } else {
          misiones.insert(0, m);
        }
      }
    });

    // Alertas pendientes
    _alertasSub?.cancel();
    _alertasSub = repository.watchAlertasPendientes().listen((data) {
      alertasPendientes.value = data;
      _notifyNuevasAlertas(data);
    });

    // Extensiones pendientes
    _extensionesSub?.cancel();
    _extensionesSub = repository.watchExtensionsPendientes().listen((data) {
      extensiones.value = data;
      _notifyNuevasExtensiones(data);
    });
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
    if (filterEstado.value == 'TODOS') return misiones;
    return misiones
        .where((m) => m.estadoNormalizado == filterEstado.value)
        .toList();
  }

  List<DtexAlerta> get alertasEmergencia =>
      alertasPendientes.where((a) => a.esEmergencia).toList();

  int get totalMisionesHoy {
    final hoy = DateTime.now();
    return misiones
        .where((m) =>
            m.createdAt != null &&
            m.createdAt!.day == hoy.day &&
            m.createdAt!.month == hoy.month &&
            m.createdAt!.year == hoy.year)
        .length;
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

  void _notifyNuevasAlertas(List<DtexAlerta> alertas) {
    for (final alerta in alertas) {
      if (_seenAlertIds.contains(alerta.idAlerta)) continue;
      _seenAlertIds.add(alerta.idAlerta);

      if (alerta.esEmergencia) {
        if (kDebugMode) {
          debugPrint(
              '🚨 [DTEX] EMERGENCIA: ${alerta.tipoDisplay} — ${alerta.descripcion}');
        }
        // TODO: integrar con BrowserNotification cuando esté disponible
      }
    }
  }

  void _notifyNuevasExtensiones(List<DtexExtension> exts) {
    for (final ext in exts) {
      if (_seenExtensionIds.contains(ext.idExtension)) continue;
      _seenExtensionIds.add(ext.idExtension);

      if (kDebugMode) {
        debugPrint(
            '📋 [DTEX] Nueva extensión solicitada: ${ext.minutosSolicitados} min — ${ext.motivo}');
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
