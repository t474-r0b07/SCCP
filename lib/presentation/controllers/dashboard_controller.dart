import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:get/get.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import '../../data/models/parte_sorpresa_model.dart';
import '../../data/models/oficial_model.dart';
import '../../data/models/monitoreo_reporte_model.dart';
import '../../data/models/radio_message_model.dart';
import '../../data/models/reo_model.dart';
import '../../data/repositories/supabase_repository.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/browser_notification.dart';
import '../../core/services/radio_rtc_signaling.dart';
import '../../core/services/report_print_service.dart';
import 'auth_controller.dart';

class DashboardController extends GetxController {
  final repository = SupabaseRepository();
  final AuthController _authController = Get.find<AuthController>();
  static const Duration _alertNotificationWindow = Duration(hours: 8);
  static const Duration _inconsistenciaNotificationWindow = Duration(hours: 8);
  static const Duration _radioNotificationWindow = Duration(hours: 12);

  final oficiales = <Oficial>[].obs;
  final reportes = <MonitoreoReporte>[].obs;
  final RxList<Map<String, dynamic>> inconsistencias =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> alertasOperativas =
      <Map<String, dynamic>>[].obs;
  final RxList<Map<String, dynamic>> telemetriaActual =
      <Map<String, dynamic>>[].obs;
  final reos = <Reo>[].obs;
  final radioInboxSupervisor = <RadioMessage>[].obs;

  final partes = <ParteSorpresa>[].obs;
  final isConnected = true.obs;
  final isLoading = false.obs;
  final loadingMessage = ''.obs;
  final selectedOficialId = Rx<String?>(null);
  final filterEstado = 'TODOS'.obs;
  final currentGroup = 'ALFA'.obs;
  final Set<String> _seenAlertIds = <String>{};
  final Set<String> _seenInconsistenciaIds = <String>{};
  final Set<String> _seenRadioIds = <String>{};
  final Set<String> _acknowledgedAlertEpisodeIds = <String>{};
  final RxInt alertAcknowledgementVersion = 0.obs;
  bool _notificationBootstrapDone = false;

  String _calculateCurrentGroup() {
    // Start date: Feb 28, 2026 = Day 1 ALFA
    final startDate = DateTime(2026, 2, 28);

    // Get effective date: if before 8:00, use previous day
    DateTime now = DateTime.now();
    DateTime effectiveDate = now;
    if (now.hour < 8) {
      effectiveDate = now.subtract(const Duration(days: 1));
    }

    // Calculate day in 14-day cycle
    int daysSinceStart = effectiveDate.difference(startDate).inDays;
    int cycleIndex = ((daysSinceStart % 14) + 14) % 14;
    int dayOfCycle = cycleIndex + 1;

    const alfaDays = {1, 4, 6, 9, 10, 12, 14};
    return alfaDays.contains(dayOfCycle) ? 'ALFA' : 'BRAVO';
  }

  Timer? _refreshTimer;
  StreamSubscription<List<RadioMessage>>? _supervisorRadioSub;

  // Performance optimization: Track last update times
  DateTime _lastReportesUpdate = DateTime.now();
  DateTime _lastInconsistenciasUpdate = DateTime.now();
  DateTime _lastReosUpdate = DateTime.now();

  @override
  void onInit() {
    super.onInit();
    currentGroup.value = _calculateCurrentGroup();
    unawaited(BrowserNotification.ensurePermission());
    loadInitialData();
    _startRealtimeSupervisorInbox();
    startPeriodicRefresh();
  }

  @override
  void onClose() {
    _refreshTimer?.cancel();
    _supervisorRadioSub?.cancel();
    super.onClose();
  }

  void _startRealtimeSupervisorInbox() {
    _supervisorRadioSub?.cancel();
    _supervisorRadioSub =
        repository.watchSupervisorRadioInbox(limit: 80).listen((rows) {
      radioInboxSupervisor.value = rows.reversed.toList();
      _notifyNewRadioMessages(radioInboxSupervisor);
    });
  }

  Future<void> loadInitialData() async {
    try {
      isLoading.value = true;
      loadingMessage.value = 'Cargando datos del sistema...';
      isConnected.value = true;

      if (kDebugMode) {
        debugPrint('🔄 Cargando datos iniciales...');
      }

      loadingMessage.value = 'Sincronizando modulos...';
      await Future.wait([
        loadOficiales(),
        loadReos(),
        loadReportes(),
        loadAlertasOperativas(),
        loadRadioInboxSupervisor(),
        loadTelemetriaActual(),
        loadInconsistencias(),
        loadPartes(),
      ]);
      _bootstrapNotificationState();
      await loadAlertasOperativas();
      await loadRadioInboxSupervisor();

      if (kDebugMode) {
        debugPrint(
          '✅ Datos cargados: ${oficiales.length} oficiales, ${reportes.length} reportes, ${alertasOperativas.length} alertas, ${inconsistencias.length} inconsistencias lógicas',
        );
      }

      isLoading.value = false;
      loadingMessage.value = '';
    } catch (e, stackTrace) {
      isConnected.value = false;
      isLoading.value = false;
      loadingMessage.value = '';

      if (kDebugMode) {
        debugPrint('❌ Error al cargar datos iniciales: $e');
        debugPrint('Stack trace: $stackTrace');
      }

      // Show user-friendly error message
      Get.snackbar(
        'Error de Conexión',
        'No se pudo cargar los datos del sistema. Verifica tu conexión a internet.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 5),
        backgroundColor: AppConstants.warningRed.withValues(alpha: 0.9),
        colorText: Colors.white,
      );
    }
  }

  Future<void> loadOficiales() async {
    try {
      final data = await repository.getOficiales();
      oficiales.value = data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading oficiales: $e');
      }
    }
  }

  Future<void> loadReportes() async {
    try {
      final data = await repository.getUltimosReportes();
      reportes.value = data;
      _lastReportesUpdate = DateTime.now();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading reportes: $e');
      }
    }
  }

  Future<void> loadReos() async {
    try {
      final data = await repository.getReos();
      reos.value = data;
      _lastReosUpdate = DateTime.now();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading reos: $e');
      }
    }
  }

  Future<void> loadInconsistencias() async {
    try {
      final data = await repository.getInconsistencias();
      inconsistencias.value = data;
      _notifyNewInconsistencias(data);
      _lastInconsistenciasUpdate = DateTime.now();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading inconsistencias: $e');
      }
    }
  }

  Future<void> loadAlertasOperativas() async {
    try {
      final base = await repository.getAlertasOperativas();
      final jumpAlerts = _buildGpsJumpSuspectAlerts();
      final merged = _mergeAlertas(base, jumpAlerts);
      alertasOperativas.value = merged;
      _notifyNewAlertas(merged);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading alertas operativas: $e');
      }
    }
  }

  Future<void> loadRadioInboxSupervisor() async {
    try {
      final data = await repository.getSupervisorRadioInbox(limit: 40);
      radioInboxSupervisor.value = data;
      _notifyNewRadioMessages(data);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading radio inbox supervisor: $e');
      }
    }
  }

  Future<void> loadTelemetriaActual() async {
    try {
      final data = await repository.getTelemetriaActual();
      telemetriaActual.value = data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading telemetría actual: $e');
      }
    }
  }

  Future<void> loadPartes() async {
    try {
      final data = await repository.getPartesSorpresa();
      partes.value = data;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading partes: $e');
      }
    }
  }

  void _bootstrapNotificationState() {
    if (_notificationBootstrapDone) return;
    for (final alerta in alertasOperativas) {
      _seenAlertIds.add(_alertKey(alerta));
    }
    for (final inc in inconsistencias) {
      _seenInconsistenciaIds.add(_inconsistenciaKey(inc));
    }
    for (final msg in radioInboxSupervisor) {
      _seenRadioIds.add(msg.idMensaje);
    }
    _notificationBootstrapDone = true;
  }

  List<Map<String, dynamic>> _mergeAlertas(
    List<Map<String, dynamic>> base,
    List<Map<String, dynamic>> extra,
  ) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in [...base, ...extra]) {
      byId[_alertKey(row)] = row;
    }
    final merged = byId.values.toList();
    merged.sort((a, b) {
      final dateA = _parseDateSafe(a['fecha_hora']) ?? DateTime(1970);
      final dateB = _parseDateSafe(b['fecha_hora']) ?? DateTime(1970);
      return dateB.compareTo(dateA);
    });
    return merged;
  }

  List<Map<String, dynamic>> _buildGpsJumpSuspectAlerts() {
    final group = currentGroup.value.toUpperCase();
    final oficialById = <String, Oficial>{
      for (final o in oficiales) o.idOficial: o,
    };
    final reportesByOficial = <String, List<MonitoreoReporte>>{};

    for (final reporte in reportes) {
      if (!_inOperationalWindow(reporte.fechaHora)) continue;
      if (reporte.latitud == null || reporte.longitud == null) continue;

      final reportGroup =
          (reporte.grupo ?? oficialById[reporte.idOficialRef]?.grupo ?? '')
              .toUpperCase();
      if (reportGroup != group) continue;
      reportesByOficial
          .putIfAbsent(reporte.idOficialRef, () => <MonitoreoReporte>[])
          .add(reporte);
    }

    final derived = <Map<String, dynamic>>[];
    for (final entry in reportesByOficial.entries) {
      final list = entry.value
        ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));

      Map<String, dynamic>? latestSuspect;
      for (int i = 1; i < list.length; i++) {
        final prev = list[i - 1];
        final curr = list[i];
        final dtSec = curr.fechaHora.difference(prev.fechaHora).inSeconds;
        if (dtSec <= 0 || dtSec > 900) continue;
        if (prev.latitud == null ||
            prev.longitud == null ||
            curr.latitud == null ||
            curr.longitud == null) {
          continue;
        }
        if (!prev.gpsReal || !curr.gpsReal) {
          // Evita "saltos" falsos cuando algún punto no es GPS confiable.
          continue;
        }

        final jumpMeters = _haversineMeters(
          prev.latitud!,
          prev.longitud!,
          curr.latitud!,
          curr.longitud!,
        );
        final speedMps = jumpMeters / dtSec;
        if (jumpMeters < 5000 || speedMps < 15) continue;

        final km = (jumpMeters / 1000).toStringAsFixed(1);
        final minutes = (dtSec / 60).toStringAsFixed(1);
        latestSuspect = {
          'id_alerta': 'GPS_JUMP_${curr.idOficialRef}_${curr.idReporte}',
          'id_oficial': curr.idOficialRef,
          'id_oficial_ref': curr.idOficialRef,
          'nombre_oficial': curr.nombreOficial ?? '',
          'grupo': curr.grupo ?? oficialById[curr.idOficialRef]?.grupo ?? '',
          'fecha_hora': curr.fechaHora.toIso8601String(),
          'estado_alerta': 'ALERTA',
          'motivo_alerta': 'SOSPECHA GPS FALSO: salto $km km en $minutes min',
          'tipo_alerta': 'GPS_SOSPECHOSO',
          'severidad': 2,
          'distancia_metros': jumpMeters,
          'velocidad_mps': speedMps,
        };
      }

      if (latestSuspect != null) {
        derived.add(latestSuspect);
      }
    }
    return derived;
  }

  double _haversineMeters(
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

  double _degToRad(double deg) => deg * (math.pi / 180.0);

  void _notifyNewAlertas(List<Map<String, dynamic>> rows) {
    if (!_notificationBootstrapDone) return;
    for (final row in rows.take(8)) {
      final id = _alertKey(row);
      if (_seenAlertIds.contains(id)) continue;
      _seenAlertIds.add(id);
      final ts = _parseDateSafe(row['fecha_hora']);
      if (!_isRecentForNotification(ts, _alertNotificationWindow)) continue;
      if (!BrowserNotification.shouldNotify(
        'alerta:$id',
        ttl: const Duration(hours: 36),
      )) {
        continue;
      }

      final motivo = (row['motivo_alerta'] ?? 'Alerta operativa').toString();
      final oficial = _resolveOficialDisplayName(
        id: (row['id_oficial_ref'] ?? row['id_oficial'] ?? '').toString(),
        fallbackName: (row['nombre_oficial'] ?? '').toString(),
      );
      BrowserNotification.show(
        title: 'ALERTA $oficial',
        body: motivo,
      );
    }
  }

  void _notifyNewInconsistencias(List<Map<String, dynamic>> rows) {
    if (!_notificationBootstrapDone) return;
    for (final row in rows.take(8)) {
      final id = _inconsistenciaKey(row);
      if (_seenInconsistenciaIds.contains(id)) continue;
      _seenInconsistenciaIds.add(id);
      final ts = _parseDateSafe(row['fecha_deteccion']);
      if (!_isRecentForNotification(ts, _inconsistenciaNotificationWindow)) {
        continue;
      }
      if (!BrowserNotification.shouldNotify(
        'inc:$id',
        ttl: const Duration(hours: 36),
      )) {
        continue;
      }

      final tipo = (row['tipo_inconsistencia'] ?? 'INCONSISTENCIA').toString();
      final oficial = _resolveOficialDisplayName(
        id: (row['id_oficial'] ?? '').toString(),
      );
      BrowserNotification.show(
        title: 'INCONSISTENCIA $oficial',
        body: tipo,
      );
    }
  }

  void _notifyNewRadioMessages(List<RadioMessage> rows) {
    if (!_notificationBootstrapDone) {
      for (final msg in rows) {
        _seenRadioIds.add(msg.idMensaje);
      }
      return;
    }
    for (final msg in rows.take(10)) {
      if (_seenRadioIds.contains(msg.idMensaje)) continue;
      _seenRadioIds.add(msg.idMensaje);
      if (RadioRtcSignal.isRtcPayload(msg.mensaje)) continue;
      final from = msg.deUsuario.trim().toUpperCase();
      if (from == 'SUPERVISOR') continue;
      if (!_isRecentForNotification(msg.timestamp, _radioNotificationWindow)) {
        continue;
      }
      if (!BrowserNotification.shouldNotify(
        'radio:${msg.idMensaje}',
        ttl: const Duration(hours: 36),
      )) {
        continue;
      }

      final type = msg.tipo.toUpperCase();
      final title = type == 'CALL_START'
          ? 'RADIO: LLAMADA ENTRANTE'
          : type == 'CALL_END'
              ? 'RADIO: LLAMADA FINALIZADA'
              : 'RADIO: MENSAJE NUEVO';
      final sender = _resolveRadioActorLabel(msg.deUsuario);
      final body = '$sender: ${msg.mensaje}';
      BrowserNotification.show(
        title: title,
        body: body,
      );
      _showInAppRadioToast(
        title: title,
        body: body,
        type: type,
      );
    }
  }

  bool _isRecentForNotification(DateTime? timestamp, Duration window) {
    if (timestamp == null) return false;
    final age = DateTime.now().difference(timestamp.toLocal());
    if (age.isNegative) return true;
    return age <= window;
  }

  void _showInAppRadioToast({
    required String title,
    required String body,
    required String type,
  }) {
    final accent = type == 'CALL_START'
        ? AppConstants.alertOrange
        : type == 'CALL_END'
            ? Colors.white70
            : AppConstants.neonCyan;
    final icon = type == 'CALL_START'
        ? Icons.phone_in_talk_rounded
        : type == 'CALL_END'
            ? Icons.phone_disabled_rounded
            : Icons.multitrack_audio_rounded;

    Get.snackbar(
      title,
      body,
      snackPosition: SnackPosition.TOP,
      margin: const EdgeInsets.only(top: 14, right: 14, left: 14),
      maxWidth: 460,
      borderRadius: 10,
      backgroundColor: Colors.black.withValues(alpha: 0.85),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
      icon: Icon(icon, color: accent),
      shouldIconPulse: type == 'CALL_START',
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    );
  }

  String _resolveOficialDisplayName({
    required String id,
    String? fallbackName,
  }) {
    final cleanId = id.trim();
    final cleanFallback = (fallbackName ?? '').trim();
    if (cleanFallback.isNotEmpty) return cleanFallback;
    if (cleanId.isEmpty) return 'N/D';
    final oficial = oficiales.firstWhereOrNull((o) => o.idOficial == cleanId);
    if (oficial != null && oficial.nombreOficial.trim().isNotEmpty) {
      return oficial.nombreOficial.trim();
    }
    return cleanId;
  }

  String _resolveRadioActorLabel(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'Usuario';
    final upper = value.toUpperCase();
    if (upper == 'SUPERVISOR') return 'Supervisor';
    return _resolveOficialDisplayName(id: value);
  }

  bool _isRtcIceSignal(RadioMessage msg) {
    final rtc = RadioRtcSignal.tryParse(msg.mensaje);
    return rtc != null && rtc.action == RadioRtcSignal.ice;
  }

  _RadioReportEvent _describeRadioEventForReport(
    RadioMessage msg, {
    required String oficialIdUpper,
  }) {
    final rtc = RadioRtcSignal.tryParse(msg.mensaje);
    if (rtc != null) {
      final from = _resolveRadioActorLabel(rtc.fromUser);
      final to = _resolveRadioActorLabel(rtc.toUser);
      final canal = '$from -> $to';
      switch (rtc.action) {
        case RadioRtcSignal.offer:
          return const _RadioReportEvent(
            tipo: 'CONTACTO RADIO',
            canal: 'Supervisor -> Oficial',
            estado: 'INTENTO',
            detalle: 'Supervisor inició contacto de radio.',
          ).copyWith(canal: canal);
        case RadioRtcSignal.answer:
          return const _RadioReportEvent(
            tipo: 'CONTACTO RADIO',
            canal: 'Oficial -> Supervisor',
            estado: 'RESPONDIDO',
            detalle: 'Oficial respondió el contacto de radio.',
          ).copyWith(canal: canal);
        case RadioRtcSignal.reject:
          return const _RadioReportEvent(
            tipo: 'CONTACTO RADIO',
            canal: 'Supervisor -> Oficial',
            estado: 'NO RESPONDIDO',
            detalle: 'Contacto rechazado o no aceptado por el oficial.',
          ).copyWith(canal: canal);
        case RadioRtcSignal.hangup:
          return const _RadioReportEvent(
            tipo: 'CONTACTO RADIO',
            canal: 'Canal de radio',
            estado: 'FINALIZADO',
            detalle: 'Comunicación de radio finalizada.',
          ).copyWith(canal: canal);
        default:
          return _RadioReportEvent(
            tipo: 'CONTACTO RADIO',
            canal: canal,
            estado: 'EVENTO',
            detalle: 'Evento de enlace de radio (${rtc.action}).',
          );
      }
    }

    final fromRaw = msg.deUsuario.trim().toUpperCase();
    final from = _resolveRadioActorLabel(msg.deUsuario);
    final to = _resolveRadioActorLabel(msg.paraUsuario);
    final canal = '$from -> $to';
    final tipo = msg.tipo.trim().toUpperCase();
    final estadoRaw = msg.estado.trim().toUpperCase();
    final messageRaw = msg.mensaje.trim();
    final messageUpper = messageRaw.toUpperCase();

    if (estadoRaw == 'ERROR' ||
        messageUpper.contains('SIN RESPUESTA') ||
        messageUpper.contains('NO RESPONDE') ||
        messageUpper.contains('NO CONTESTA')) {
      return _RadioReportEvent(
        tipo: 'CONTACTO RADIO',
        canal: canal,
        estado: 'NO RESPONDIDO',
        detalle: _sanitizeRadioDetail(
          messageRaw.isEmpty ? 'Intento de contacto sin respuesta.' : messageRaw,
        ),
      );
    }

    if (tipo == 'CALL_START' || messageUpper.contains('INICIO CONTACTO RADIO')) {
      return _RadioReportEvent(
        tipo: 'CONTACTO RADIO',
        canal: canal,
        estado: 'INTENTO',
        detalle: _sanitizeRadioDetail(
          messageRaw.isEmpty ? 'Intento de contacto de radio.' : messageRaw,
        ),
      );
    }

    final fromOfficial = fromRaw == oficialIdUpper || fromRaw.contains('OFICIAL');
    final estado = fromOfficial ? 'RESPONDIDO' : 'ENVIADO';
    return _RadioReportEvent(
      tipo: 'MENSAJE RADIO',
      canal: canal,
      estado: estado,
      detalle: _sanitizeRadioDetail(
        messageRaw.isEmpty ? 'Mensaje operativo sin detalle.' : messageRaw,
      ),
    );
  }

  String _sanitizeRadioDetail(String raw) {
    final collapsed = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (collapsed.isEmpty) return 'Sin detalle.';
    const maxLen = 180;
    if (collapsed.length <= maxLen) return collapsed;
    return '${collapsed.substring(0, maxLen)}...';
  }

  String _alertKey(Map<String, dynamic> row) {
    final id = (row['id_alerta'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    return [
      row['id_oficial_ref'] ?? row['id_oficial'] ?? '',
      row['fecha_hora'] ?? '',
      row['motivo_alerta'] ?? '',
    ].join('|');
  }

  String _inconsistenciaKey(Map<String, dynamic> row) {
    final id = (row['id_inconsistencia'] ?? '').toString().trim();
    if (id.isNotEmpty) return id;
    return [
      row['id_oficial'] ?? '',
      row['fecha_deteccion'] ?? '',
      row['tipo_inconsistencia'] ?? '',
    ].join('|');
  }

  void startPeriodicRefresh() {
    // Optimized: Single timer with intelligent refresh logic
    _refreshTimer = Timer.periodic(AppConstants.refreshInterval, (timer) {
      _intelligentRefresh();
    });
  }

  void _intelligentRefresh() {
    final now = DateTime.now();
    final resolvedGroup = _calculateCurrentGroup();
    if (resolvedGroup != currentGroup.value) {
      currentGroup.value = resolvedGroup;
    }

    // Only refresh reportes if enough time has passed
    if (now.difference(_lastReportesUpdate) >= AppConstants.refreshInterval) {
      loadReportes();
      loadAlertasOperativas();
      loadTelemetriaActual();
      loadRadioInboxSupervisor();
      loadPartes();
    }

    // Refresh control points (reo addresses/coords) to keep map pins in sync
    if (now.difference(_lastReosUpdate) >= AppConstants.refreshInterval) {
      loadReos();
    }

    // Only refresh inconsistencias if enough time has passed
    if (now.difference(_lastInconsistenciasUpdate) >=
        AppConstants.inconsistenciasInterval) {
      loadInconsistencias();
    }
  }

  void selectOficial(String oficialId) {
    selectedOficialId.value = oficialId;
  }

  Future<void> imprimirReporteIndividualSupervisor({
    required String idOficial,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final oficialId = idOficial.trim();
    if (oficialId.isEmpty) {
      Get.snackbar(
        'Reporte individual',
        'Selecciona un oficial válido.',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    final inicio = fechaInicio ?? operationalWindowStart;
    final fin = fechaFin ?? operationalWindowEnd;

    try {
      final data = await repository.generarInformeOficial(
        idOficial: oficialId,
        fechaInicio: inicio,
        fechaFin: fin,
      );
      final radioMensajes = await repository.getRadioMessagesByOficial(
        idOficial: oficialId,
        from: inicio,
        to: fin,
        limit: 150,
      );
      final inconsistenciasOficial = inconsistencias
          .where(
              (row) => (row['id_oficial'] ?? '').toString().trim() == oficialId)
          .toList();

      final oficial =
          oficiales.firstWhereOrNull((o) => o.idOficial == oficialId);
      final nombreOficial = oficial?.nombreOficial ?? oficialId;
      final grupo = (oficial?.grupo ?? 'N/D').toUpperCase();
      final supervisor = _authController.currentAdmin.value;
      final supervisorNombre =
          supervisor?.nombre ?? 'SUPERVISOR NO IDENTIFICADO';
      final supervisorGrado = _resolveSupervisorGrade(supervisor?.nivelAcceso);
      final supervisorEmail = supervisor?.email ?? '--';
      final generatedAt = DateTime.now();
      final logos = await _resolveReportLogos();
      final htmlBody = _buildOfficerExecutiveReportHtml(
        data: data,
        oficialId: oficialId,
        nombreOficial: nombreOficial,
        grupo: grupo,
        supervisorNombre: supervisorNombre,
        supervisorGrado: supervisorGrado,
        supervisorEmail: supervisorEmail,
        inicio: inicio,
        fin: fin,
        generatedAt: generatedAt,
        radioMensajes: radioMensajes,
        inconsistenciasOficial: inconsistenciasOficial,
        logoMainSrc: logos.main,
        logoInstitutional1Src: logos.institutional1,
        logoInstitutional2Src: logos.institutional2,
      );

      final printed = await ReportPrintService.printHtml(
        title: 'Reporte Individual - $oficialId',
        htmlBody: htmlBody,
        autoPrint: false,
        autoClose: false,
      );

      if (!printed) {
        Get.snackbar(
          'Impresión no disponible',
          'La impresión directa está habilitada en navegador web.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: AppConstants.alertOrange.withValues(alpha: 0.35),
          colorText: Colors.white,
        );
      } else {
        Get.snackbar(
          'Reporte individual',
          'Vista previa generada. Usa "Imprimir / Guardar PDF" en la nueva pestaña.',
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    } catch (e) {
      Get.snackbar(
        'Error de reporte',
        'No se pudo generar/imprimir reporte individual: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: AppConstants.warningRed.withValues(alpha: 0.35),
        colorText: Colors.white,
      );
    }
  }

  String _buildOfficerExecutiveReportHtml({
    required Map<String, dynamic> data,
    required String oficialId,
    required String nombreOficial,
    required String grupo,
    required String supervisorNombre,
    required String supervisorGrado,
    required String supervisorEmail,
    required DateTime inicio,
    required DateTime fin,
    required DateTime generatedAt,
    required List<RadioMessage> radioMensajes,
    required List<Map<String, dynamic>> inconsistenciasOficial,
    required String logoMainSrc,
    required String logoInstitutional1Src,
    required String logoInstitutional2Src,
  }) {
    final stats = _asMap(data['stats']);
    final kpis = _asMap(stats['kpis']);
    final detalle = _asMap(stats['detalle']);

    final cobertura =
        _toDouble(kpis['cobertura_pct'] ?? detalle['cobertura_pct']);
    final cumplimiento = _toDouble(
      kpis['cumplimiento_pct'] ?? detalle['cumplimiento_pct'],
    );
    final reportes =
        _toInt(kpis['total_reportes'] ?? detalle['total_reportes']);
    final alertas = _toInt(kpis['total_alertas'] ?? detalle['total_alertas']);
    final bateria =
        _toDouble(kpis['bateria_promedio'] ?? detalle['bateria_promedio']);
    final distancia =
        _toDouble(kpis['distancia_promedio'] ?? detalle['distancia_promedio']);
    final partesEsperados = _toInt(detalle['partes_esperados']);
    final partesCompletados = _toInt(detalle['partes_completados']);
    final cumplimientoPartes = _toDouble(detalle['cumplimiento_partes_pct']);
    final inconsistenciasAbiertas = _toInt(detalle['inconsistencias_abiertas']);
    final inconsistenciasCerradas = _toInt(detalle['inconsistencias_cerradas']);
    final incidenciasTotal = inconsistenciasAbiertas + inconsistenciasCerradas;
    final tasaCierreIncidencias = incidenciasTotal == 0
        ? 100.0
        : ((inconsistenciasCerradas / incidenciasTotal) * 100)
            .clamp(0.0, 100.0);
    final tendencia7dias = _toIntList(detalle['tendencia_7dias']);
    final bateriaBuckets = _toIntList(detalle['bateria_buckets']);

    final eval = _evaluateOfficer(
      cobertura: cobertura,
      cumplimiento: cumplimiento,
      cumplimientoPartes: cumplimientoPartes,
      inconsistenciasAbiertas: inconsistenciasAbiertas,
      bateriaPromedio: bateria,
    );

    final radioSorted = [...radioMensajes]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final radioRelevant = radioSorted.where((m) => !_isRtcIceSignal(m)).toList();
    final oficialIdUpper = oficialId.trim().toUpperCase();
    final rtcCalls = <String, _RadioCallAggregate>{};
    var manualIntentos = 0;
    var manualRespuestas = 0;
    var manualFallos = 0;

    for (final m in radioRelevant) {
      final rtc = RadioRtcSignal.tryParse(m.mensaje);
      if (rtc != null) {
        final call = rtcCalls.putIfAbsent(rtc.callId, _RadioCallAggregate.new);
        switch (rtc.action) {
          case RadioRtcSignal.offer:
            call.attempted = true;
            break;
          case RadioRtcSignal.answer:
            call.responded = true;
            break;
          case RadioRtcSignal.reject:
            call.attempted = true;
            call.failed = true;
            break;
          case RadioRtcSignal.hangup:
            call.ended = true;
            break;
        }
        continue;
      }

      final tipo = m.tipo.trim().toUpperCase();
      final msg = m.mensaje.trim().toUpperCase();
      final from = m.deUsuario.trim().toUpperCase();
      final status = m.estado.trim().toUpperCase();
      if (tipo == 'CALL_START' || msg.contains('INICIO CONTACTO RADIO')) {
        manualIntentos += 1;
      }
      if (from == oficialIdUpper || from.contains('OFICIAL')) {
        manualRespuestas += 1;
      }
      if (status == 'ERROR' ||
          msg.contains('SIN RESPUESTA') ||
          msg.contains('NO RESPONDE') ||
          msg.contains('NO CONTESTA')) {
        manualFallos += 1;
      }
    }

    final rtcIntentos = rtcCalls.values.where((c) => c.attempted).length;
    final rtcRespuestas = rtcCalls.values.where((c) => c.responded).length;
    final rtcFallos = rtcCalls.values
        .where((c) => c.failed || (c.attempted && !c.responded))
        .length;
    final radioIntentos = rtcIntentos + manualIntentos;
    final radioRespuestas = rtcRespuestas + manualRespuestas;
    final radioFallos = rtcFallos + manualFallos;

    final alertTypes = _toIntList(detalle['alertas_tipo']);
    final alertasGpsDistancia = alertTypes.isNotEmpty ? alertTypes[0] : 0;
    final alertasOtras = alertTypes.length > 1 ? alertTypes[1] : 0;
    final alertasFaltaReporte = alertTypes.length > 2 ? alertTypes[2] : 0;

    final risk = _buildRiskModel(
      cobertura: cobertura,
      cumplimientoPartes: cumplimientoPartes,
      inconsistenciasAbiertas: inconsistenciasAbiertas,
      totalAlertas: alertas,
      radioIntentos: radioIntentos,
      radioRespuestas: radioRespuestas,
      radioFallos: radioFallos,
      bateria: bateria,
    );
    final criticidad = _criticidadLabel(risk.riskScore);
    final confiabilidad = (100 - risk.riskScore).clamp(0, 100);
    final verificationPayload = jsonEncode({
      'report_type': 'OFFICER_EXECUTIVE',
      'oficial': oficialId,
      'grupo': grupo,
      'supervisor': supervisorEmail,
      'generated_at': generatedAt.toIso8601String(),
      'score': eval.score,
      'risk': risk.riskScore,
      'periodo': {
        'inicio': inicio.toIso8601String(),
        'fin': fin.toIso8601String(),
      },
    });
    final verificationCode =
        base64Url.encode(utf8.encode(verificationPayload)).replaceAll('=', '');
    final shortVerificationCode = verificationCode.substring(
      0,
      math.min(36, verificationCode.length),
    );
    final qrUrl =
        'https://api.qrserver.com/v1/create-qr-code/?size=180x180&ecc=M&data=${Uri.encodeComponent(verificationPayload)}';

    final reasons = _buildEvaluationReasons(
      cumplimientoPartes: cumplimientoPartes,
      inconsistenciasAbiertas: inconsistenciasAbiertas,
      alertas: alertas,
      bateria: bateria,
      cobertura: cobertura,
      radioFallos: radioFallos,
      radioIntentos: radioIntentos,
      radioRespuestas: radioRespuestas,
    );
    final smartNarrative = _buildCriticalNarrative(
      score: eval.score,
      riskScore: risk.riskScore,
      confiabilidad: confiabilidad.toDouble(),
      cumplimientoPartes: cumplimientoPartes,
      inconsistenciasAbiertas: inconsistenciasAbiertas,
      radioIntentos: radioIntentos,
      radioRespuestas: radioRespuestas,
      radioFallos: radioFallos,
      primaryRisk: risk.primaryRisk,
    );

    final actions = _buildRecommendedActions(
      cumplimientoPartes: cumplimientoPartes,
      inconsistenciasAbiertas: inconsistenciasAbiertas,
      bateria: bateria,
      radioFallos: radioFallos,
    );

    final timelineRows = radioRelevant.reversed.take(12).map((m) {
      final event = _describeRadioEventForReport(
        m,
        oficialIdUpper: oficialIdUpper,
      );
      return '''
<tr>
  <td>${_escapeHtml(_formatDateTime(m.timestamp))}</td>
  <td>${_escapeHtml(event.tipo)}</td>
  <td>${_escapeHtml(event.canal)}</td>
  <td>${_escapeHtml(event.estado)}</td>
  <td>${_escapeHtml(event.detalle)}</td>
</tr>
''';
    }).join();

    final inconsistRows = inconsistenciasOficial.take(10).map((row) {
      final tipo = (row['tipo_inconsistencia'] ?? '--').toString();
      final estado = (row['estado'] ?? '--').toString();
      final fecha = _parseDateSafe(row['fecha_deteccion']);
      final descripcion = (row['descripcion'] ?? '--').toString();
      return '''
<tr>
  <td>${_escapeHtml(fecha == null ? '--' : _formatDateTime(fecha))}</td>
  <td>${_escapeHtml(tipo)}</td>
  <td>${_escapeHtml(estado)}</td>
  <td>${_escapeHtml(descripcion)}</td>
</tr>
''';
    }).join();
    final trendBars = _buildTrendBars(tendencia7dias);
    final metricBars = [
      _buildMetricBar(
          'Confiabilidad Operativa', confiabilidad.toDouble(), '#0f766e'),
      _buildMetricBar('Riesgo Operativo', risk.riskScore.toDouble(), '#b91c1c'),
      _buildMetricBar('Cumplimiento de Partes', cumplimientoPartes, '#92400e'),
      _buildMetricBar('Cobertura de Reportes', cobertura, '#1d4ed8'),
    ].join();
    final alertTotal =
        math.max(1, alertasGpsDistancia + alertasOtras + alertasFaltaReporte);
    final gpsDistPct = (alertasGpsDistancia * 100 / alertTotal);
    final otrasPct = (alertasOtras * 100 / alertTotal);
    final faltaReportePct = (alertasFaltaReporte * 100 / alertTotal);
    final bateriaLow = bateriaBuckets.isNotEmpty ? bateriaBuckets[0] : 0;
    final bateriaMid = bateriaBuckets.length > 1 ? bateriaBuckets[1] : 0;
    final bateriaHigh = bateriaBuckets.length > 2 ? bateriaBuckets[2] : 0;

    return '''
<style>
  .section-card { border:1px solid #d4d4d8; border-radius:10px; padding:12px; margin:10px 0; }
  .kpi-grid { display:grid; grid-template-columns:repeat(3,minmax(0,1fr)); gap:8px; }
  .kpi { border:1px solid #e4e4e7; border-radius:8px; padding:8px; background:#fafafa; }
  .kpi .label { font-size:11px; color:#52525b; }
  .kpi .value { font-size:18px; font-weight:800; color:#111827; }
  .risk-badge { display:inline-block; padding:4px 8px; border-radius:999px; font-weight:700; font-size:12px; }
  .chart-wrap { margin:8px 0; }
  .stack { display:flex; width:100%; height:16px; border-radius:999px; overflow:hidden; background:#e5e7eb; border:1px solid #d1d5db; }
  .sig-line { margin-top:16px; border-top:1px solid #111; width:320px; padding-top:5px; font-size:12px; }
  .header-brand { display:flex; justify-content:space-between; align-items:center; gap:12px; margin-bottom:10px; }
  .header-brand img { height:56px; object-fit:contain; }
  .auth-grid { display:grid; grid-template-columns:1fr 200px; gap:12px; align-items:center; }
  @media print {
    .kpi-grid { grid-template-columns:repeat(2,minmax(0,1fr)); }
    .auth-grid { grid-template-columns:1fr 160px; }
    .header-brand img { height:46px; }
  }
</style>
<div class="header-brand">
  <img src="${_escapeHtml(logoMainSrc)}" alt="Logo SCCP">
  <img src="${_escapeHtml(logoInstitutional1Src)}" alt="Logo Institucional 1">
  <img src="${_escapeHtml(logoInstitutional2Src)}" alt="Logo Institucional 2">
</div>
<h1>INFORME INDIVIDUAL DE CONTROL OPERATIVO</h1>
<div class="muted">Generado: ${_formatDateTime(generatedAt)}</div>

<table>
  <tr><th>Oficial</th><td>${_escapeHtml(nombreOficial)}</td></tr>
  <tr><th>ID Oficial</th><td>${_escapeHtml(oficialId)}</td></tr>
  <tr><th>Grupo</th><td>${_escapeHtml(grupo)}</td></tr>
  <tr><th>Periodo evaluado</th><td>${_escapeHtml(_formatDateTime(inicio))} a ${_escapeHtml(_formatDateTime(fin))}</td></tr>
  <tr><th>Supervisor responsable</th><td>${_escapeHtml(supervisorNombre)} (${_escapeHtml(supervisorGrado)})</td></tr>
  <tr><th>Cuenta de supervisor</th><td>${_escapeHtml(supervisorEmail)}</td></tr>
</table>

<h2>Resumen Ejecutivo</h2>
<div class="section-card">
  <div class="kpi-grid">
    <div class="kpi"><div class="label">Puntaje integral</div><div class="value">${eval.score}/100</div></div>
    <div class="kpi"><div class="label">Confiabilidad</div><div class="value">${confiabilidad.toStringAsFixed(0)}%</div></div>
    <div class="kpi"><div class="label">Riesgo operativo</div><div class="value">${risk.riskScore}%</div></div>
  </div>
  <p style="margin-top:10px;"><strong>Calificación:</strong> ${_escapeHtml(eval.label)} |
  <span class="risk-badge" style="color:${_riskColor(risk.riskScore)};border:1px solid ${_riskColor(risk.riskScore)};">${_escapeHtml(criticidad)}</span></p>
  <p><strong>Riesgo dominante:</strong> ${_escapeHtml(risk.primaryRisk)}</p>
  <p><strong>Conclusión:</strong> ${_escapeHtml(eval.summary)}</p>
  <p><strong>Lectura crítica:</strong> ${_escapeHtml(smartNarrative)}</p>
</div>

<h2>Gráficos de Riesgo y Confiabilidad</h2>
<div class="chart-wrap">
  $metricBars
</div>

<h3>Distribución de Tipos de Incidencia</h3>
<div class="stack">
  <div style="width:${gpsDistPct.toStringAsFixed(2)}%;background:#b91c1c" title="GPS/Distancia ${gpsDistPct.toStringAsFixed(0)}%"></div>
  <div style="width:${otrasPct.toStringAsFixed(2)}%;background:#ea580c" title="Otras ${otrasPct.toStringAsFixed(0)}%"></div>
  <div style="width:${faltaReportePct.toStringAsFixed(2)}%;background:#ca8a04" title="Falta de reporte ${faltaReportePct.toStringAsFixed(0)}%"></div>
</div>
<p class="muted">GPS/Distancia: $alertasGpsDistancia | Otras: $alertasOtras | Falta reporte: $alertasFaltaReporte</p>

<h3>Tendencia de Reportes (7 días)</h3>
<div class="chart-wrap">$trendBars</div>

<h3>Estado energético (buckets)</h3>
<table>
  <tr><th>Batería baja</th><th>Batería media</th><th>Batería alta</th></tr>
  <tr><td>$bateriaLow</td><td>$bateriaMid</td><td>$bateriaHigh</td></tr>
</table>

<h2>Cuantificación Operativa</h2>
<table>
  <tr><th>Cobertura de reportes</th><td>${cobertura.toStringAsFixed(0)}%</td></tr>
  <tr><th>Cumplimiento general</th><td>${cumplimiento.toStringAsFixed(0)}%</td></tr>
  <tr><th>Reportes automáticos</th><td>$reportes</td></tr>
  <tr><th>Alertas totales</th><td>$alertas (GPS/Distancia: $alertasGpsDistancia | Otras: $alertasOtras | Falta reporte: $alertasFaltaReporte)</td></tr>
  <tr><th>Partes obligatorios/sorpresa</th><td>$partesCompletados / $partesEsperados (${cumplimientoPartes.toStringAsFixed(0)}%)</td></tr>
  <tr><th>Incidencias (tabla inconsistencias)</th><td>Abiertas: $inconsistenciasAbiertas | Cerradas: $inconsistenciasCerradas | Tasa de cierre: ${tasaCierreIncidencias.toStringAsFixed(0)}%</td></tr>
  <tr><th>Batería promedio</th><td>${bateria.toStringAsFixed(0)}%</td></tr>
  <tr><th>Distancia promedio al objetivo</th><td>${distancia.toStringAsFixed(2)} m</td></tr>
</table>

<h3>Aclaración de Cierre</h3>
<p class="muted"><strong>Incidencia abierta</strong> significa inconsistencia pendiente de cierre administrativo (estado distinto de CERRADA o sin marcar resuelta). <strong>No significa reporte automático no enviado.</strong></p>

<h2>Razonamiento de Evaluación Inteligente</h2>
<ul>
  ${reasons.map((r) => '<li>${_escapeHtml(r)}</li>').join()}
</ul>

<h2>Interacción con Radio Base</h2>
<table>
  <tr><th>Eventos de radio</th><td>${radioRelevant.length}</td></tr>
  <tr><th>Intentos de contacto registrados</th><td>$radioIntentos</td></tr>
  <tr><th>Respuestas del oficial</th><td>$radioRespuestas</td></tr>
  <tr><th>Incidentes/fallos de comunicación</th><td>$radioFallos</td></tr>
</table>
${radioRelevant.isEmpty ? '<p>No hay trazas de radio en el periodo analizado.</p>' : '''
<h3>Bitácora de Comunicación (últimos ${radioRelevant.length < 12 ? radioRelevant.length : 12} eventos)</h3>
<table>
  <tr><th>Fecha/Hora</th><th>Tipo</th><th>Canal</th><th>Estado</th><th>Detalle</th></tr>
  $timelineRows
</table>
'''}

<h2>Inconsistencias Registradas</h2>
${inconsistenciasOficial.isEmpty ? '<p>Sin inconsistencias del oficial en este periodo.</p>' : '''
<table>
  <tr><th>Fecha/Hora</th><th>Tipo</th><th>Estado</th><th>Descripción</th></tr>
  $inconsistRows
</table>
'''}

<h2>Acciones Recomendadas</h2>
<ol>
  ${actions.map((a) => '<li>${_escapeHtml(a)}</li>').join()}
</ol>

<h2>Autenticidad y Verificación</h2>
<div class="section-card auth-grid">
  <div>
    <p><strong>Código de verificación:</strong> ${_escapeHtml(shortVerificationCode)}</p>
    <p class="muted">Este código identifica de forma única el contenido y el contexto del informe generado.</p>
    <p class="muted">Supervisor firmante: ${_escapeHtml(supervisorNombre)} (${_escapeHtml(supervisorGrado)})</p>
  </div>
  <div style="text-align:center;">
    <img src="$qrUrl" alt="QR de autenticidad" style="width:180px;height:180px;border:1px solid #d1d5db;padding:4px;border-radius:8px;">
  </div>
</div>

<h2>Constancia de Supervisión</h2>
<p>Yo, <strong>${_escapeHtml(supervisorNombre)}</strong>, en calidad de
<strong>${_escapeHtml(supervisorGrado)}</strong>, dejo constancia de revisión de este informe y certifico que la interpretación fue emitida con base en los registros del sistema SCCP.</p>
<div class="sig-line">
  ${_escapeHtml(supervisorNombre)}<br/>
  ${_escapeHtml(supervisorGrado)}<br/>
  Fecha/Hora: ${_escapeHtml(_formatDateTime(generatedAt))}
</div>
''';
  }

  Future<({String main, String institutional1, String institutional2})>
      _resolveReportLogos() async {
    final main = await _assetImageAsDataUri(
      'assets/images/logoB.png',
      fallbackWebPath: '/assets/assets/images/logoB.png',
    );
    final institutional1 = await _assetImageAsDataUri(
      'assets/images/logo2.png',
      fallbackWebPath: '/assets/assets/images/logo2.png',
    );
    final institutional2 = await _assetImageAsDataUri(
      'assets/images/logo3.png',
      fallbackWebPath: '/assets/assets/images/logo3.png',
    );
    return (
      main: main,
      institutional1: institutional1,
      institutional2: institutional2,
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

  ({int riskScore, String primaryRisk}) _buildRiskModel({
    required double cobertura,
    required double cumplimientoPartes,
    required int inconsistenciasAbiertas,
    required int totalAlertas,
    required int radioIntentos,
    required int radioRespuestas,
    required int radioFallos,
    required double bateria,
  }) {
    final coberturaPenalty = (100 - cobertura).clamp(0, 100).toInt();
    final partesPenalty = (100 - cumplimientoPartes).clamp(0, 100).toInt();
    final inconsistPenalty =
        math.min(100, inconsistenciasAbiertas * 10).toInt();
    final alertPenalty = math.min(100, totalAlertas * 6).toInt();
    final radioSilencePenalty =
        radioIntentos > 0 && radioRespuestas == 0 ? 85 : 0;
    final radioFailPenalty = math.min(100, radioFallos * 18).toInt();
    final energyPenalty =
        bateria < 20 ? 80 : (bateria < 30 ? 50 : (bateria < 40 ? 25 : 10));

    final risk = ((partesPenalty * 0.24) +
            (inconsistPenalty * 0.22) +
            (alertPenalty * 0.16) +
            (coberturaPenalty * 0.14) +
            (math.max(radioSilencePenalty, radioFailPenalty) * 0.14) +
            (energyPenalty * 0.10))
        .round()
        .clamp(0, 100);

    final drivers = <MapEntry<String, int>>[
      MapEntry('Incumplimiento de partes', partesPenalty),
      MapEntry('Inconsistencias abiertas', inconsistPenalty),
      MapEntry('Volumen de alertas', alertPenalty),
      MapEntry('Brecha de cobertura', coberturaPenalty.toInt()),
      MapEntry(
          'Fallas de radio', math.max(radioSilencePenalty, radioFailPenalty)),
      MapEntry('Riesgo energético', energyPenalty),
    ]..sort((a, b) => b.value.compareTo(a.value));

    return (riskScore: risk, primaryRisk: drivers.first.key);
  }

  String _criticidadLabel(int riskScore) {
    if (riskScore >= 80) return 'CRITICIDAD EXTREMA';
    if (riskScore >= 65) return 'CRITICIDAD ALTA';
    if (riskScore >= 45) return 'CRITICIDAD MEDIA';
    if (riskScore >= 25) return 'CRITICIDAD CONTROLADA';
    return 'CRITICIDAD BAJA';
  }

  String _riskColor(int riskScore) {
    if (riskScore >= 80) return '#991b1b';
    if (riskScore >= 65) return '#b45309';
    if (riskScore >= 45) return '#ca8a04';
    if (riskScore >= 25) return '#0f766e';
    return '#166534';
  }

  String _buildCriticalNarrative({
    required int score,
    required int riskScore,
    required double confiabilidad,
    required double cumplimientoPartes,
    required int inconsistenciasAbiertas,
    required int radioIntentos,
    required int radioRespuestas,
    required int radioFallos,
    required String primaryRisk,
  }) {
    final gaps = <String>[];
    if (cumplimientoPartes < 80) {
      gaps.add('déficit de partes (${cumplimientoPartes.toStringAsFixed(0)}%)');
    }
    if (inconsistenciasAbiertas > 0) {
      gaps.add('$inconsistenciasAbiertas incidencias abiertas sin cierre');
    }
    if (radioIntentos > 0 && radioRespuestas == 0) {
      gaps.add('sin respuesta a radio base');
    } else if (radioFallos > 0) {
      gaps.add('fallas de comunicación interna');
    }
    if (riskScore >= 70) {
      gaps.add('criticidad acumulada alta');
    }
    if (primaryRisk.trim().isNotEmpty) {
      gaps.add('factor dominante: $primaryRisk');
    }
    if (gaps.isEmpty) {
      return 'El oficial mantiene trazabilidad operativa estable. No se detectan brechas críticas en el período analizado.';
    }
    return 'La evaluación identifica riesgo material por ${gaps.join(', ')}. El puntaje $score/100 con confiabilidad ${confiabilidad.toStringAsFixed(0)}% sugiere intervención correctiva inmediata para evitar escalamiento.';
  }

  String _buildMetricBar(String label, double value, String color) {
    final safe = value.clamp(0, 100).toDouble();
    return '''
<div style="margin:6px 0;">
  <div style="display:flex;justify-content:space-between;font-size:12px;">
    <span>${_escapeHtml(label)}</span><strong>${safe.toStringAsFixed(0)}%</strong>
  </div>
  <div style="height:14px;border:1px solid #d1d5db;background:#f3f4f6;border-radius:999px;overflow:hidden;">
    <div style="height:100%;width:${safe.toStringAsFixed(2)}%;background:$color;"></div>
  </div>
</div>
''';
  }

  String _buildTrendBars(List<int> values) {
    if (values.isEmpty) {
      return '<p class="muted">Sin datos de tendencia semanal.</p>';
    }
    final maxValue = values.reduce(math.max);
    if (maxValue <= 0) {
      return '<p class="muted">Tendencia sin actividad significativa.</p>';
    }
    final bars = values.asMap().entries.map((entry) {
      final day = entry.key + 1;
      final v = entry.value;
      final pct = (v * 100 / maxValue).clamp(4, 100).toDouble();
      return '''
<div style="display:flex;align-items:center;gap:8px;margin:4px 0;">
  <div style="width:32px;font-size:11px;">D$day</div>
  <div style="flex:1;height:12px;background:#eef2ff;border-radius:6px;overflow:hidden;">
    <div style="height:100%;width:${pct.toStringAsFixed(2)}%;background:#1d4ed8;"></div>
  </div>
  <div style="width:28px;text-align:right;font-size:11px;">$v</div>
</div>
''';
    }).join();
    return bars;
  }

  String _resolveSupervisorGrade(String? accessLevel) {
    final level = (accessLevel ?? '').trim().toUpperCase();
    if (level == 'DIRECTOR') return 'DIRECTOR OPERATIVO';
    if (level == 'SUPERVISOR') return 'SUPERVISOR DE TURNO';
    if (level.isNotEmpty) return level;
    return 'SUPERVISOR';
  }

  ({int score, String label, String summary}) _evaluateOfficer({
    required double cobertura,
    required double cumplimiento,
    required double cumplimientoPartes,
    required int inconsistenciasAbiertas,
    required double bateriaPromedio,
  }) {
    final inconsistScore = math.max(0, 100 - (inconsistenciasAbiertas * 8));
    final bateriaScore = bateriaPromedio >= 35
        ? 100
        : (bateriaPromedio >= 25 ? 75 : (bateriaPromedio >= 15 ? 45 : 20));
    final raw = (cobertura.clamp(0, 100) * 0.25) +
        (cumplimiento.clamp(0, 100) * 0.25) +
        (cumplimientoPartes.clamp(0, 100) * 0.25) +
        (inconsistScore * 0.15) +
        (bateriaScore * 0.10);
    final score = raw.round().clamp(0, 100);

    if (score >= 90) {
      return (
        score: score,
        label: 'EXCELENTE',
        summary:
            'Desempeño sólido con alta cobertura y control operativo consistente.'
      );
    }
    if (score >= 75) {
      return (
        score: score,
        label: 'BUENO',
        summary:
            'Cumplimiento aceptable, con hallazgos puntuales que requieren seguimiento.'
      );
    }
    if (score >= 60) {
      return (
        score: score,
        label: 'REGULAR',
        summary:
            'Se detectan debilidades operativas relevantes; requiere plan correctivo.'
      );
    }
    return (
      score: score,
      label: 'CRITICO',
      summary:
          'Riesgo operativo alto por incumplimientos e inconsistencias no corregidas.'
    );
  }

  List<String> _buildEvaluationReasons({
    required double cumplimientoPartes,
    required int inconsistenciasAbiertas,
    required int alertas,
    required double bateria,
    required double cobertura,
    required int radioFallos,
    required int radioIntentos,
    required int radioRespuestas,
  }) {
    final reasons = <String>[];
    if (cobertura >= 95) {
      reasons.add(
        'Cobertura de reportes estable (${cobertura.toStringAsFixed(0)}%), sin huecos relevantes en el periodo.',
      );
    } else {
      reasons.add(
        'Cobertura de reportes insuficiente (${cobertura.toStringAsFixed(0)}%), con riesgo de trazabilidad incompleta.',
      );
    }
    if (cumplimientoPartes < 70) {
      reasons.add(
        'Cumplimiento de partes bajo (${cumplimientoPartes.toStringAsFixed(0)}%): principal factor de riesgo disciplinario.',
      );
    } else {
      reasons.add(
        'Cumplimiento de partes aceptable (${cumplimientoPartes.toStringAsFixed(0)}%).',
      );
    }
    if (inconsistenciasAbiertas > 0) {
      reasons.add(
        'Existen $inconsistenciasAbiertas incidencias abiertas sin cierre formal.',
      );
    } else {
      reasons.add('No se detectan inconsistencias abiertas en el periodo.');
    }
    if (alertas >= 10) {
      reasons.add(
        'Volumen de alertas elevado ($alertas), requiere revisión de causa raíz.',
      );
    }
    if (bateria < 25) {
      reasons.add(
        'Batería promedio baja (${bateria.toStringAsFixed(0)}%), puede afectar continuidad de monitoreo.',
      );
    }
    if (radioIntentos > 0 && radioRespuestas == 0) {
      reasons.add(
        'Hubo intentos de radio sin respuesta operativa registrada.',
      );
    }
    if (radioFallos > 0) {
      reasons.add(
        'Se registraron eventos de comunicación con estado de falla ($radioFallos).',
      );
    }
    if (reasons.isEmpty) {
      reasons.add('Datos insuficientes para razonamiento detallado.');
    }
    return reasons;
  }

  List<String> _buildRecommendedActions({
    required double cumplimientoPartes,
    required int inconsistenciasAbiertas,
    required double bateria,
    required int radioFallos,
  }) {
    final actions = <String>[];
    if (cumplimientoPartes < 85) {
      actions.add(
        'Aplicar seguimiento diario de partes (obligatorio y sorpresa) con ventana y tolerancia técnica controlada.',
      );
    }
    if (inconsistenciasAbiertas > 0) {
      actions.add(
        'Cerrar inconsistencias abiertas con trazabilidad (acción, responsable, fecha y resultado).',
      );
    }
    if (radioFallos > 0) {
      actions.add(
        'Reforzar protocolo de radio: registrar intento, respuesta y cierre en bitácora por evento.',
      );
    }
    if (bateria < 30) {
      actions.add(
        'Corregir gestión energética del equipo para sostener operación continua en segundo plano.',
      );
    }
    if (actions.isEmpty) {
      actions.add(
        'Mantener el esquema actual y monitorear tendencia semanal para prevención temprana.',
      );
    }
    return actions;
  }

  Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      try {
        return raw.cast<String, dynamic>();
      } catch (_) {
        return <String, dynamic>{};
      }
    }
    return <String, dynamic>{};
  }

  double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse((v ?? '').toString()) ?? 0;
  }

  int _toInt(dynamic v) {
    if (v is num) return v.toInt();
    return int.tryParse((v ?? '').toString()) ?? 0;
  }

  List<int> _toIntList(dynamic raw) {
    if (raw is! List) return const <int>[];
    return raw.map((e) => _toInt(e)).toList();
  }

  Future<bool> resolverInconsistencia(
      String id, String nuevoEstado, String adminNombre) async {
    final ok =
        await repository.resolverInconsistencia(id, nuevoEstado, adminNombre);
    if (ok) {
      await loadInconsistencias();
    }
    return ok;
  }

  String _formatDateTime(DateTime value) {
    final d = value.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString().padLeft(4, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }

  Future<bool> registrarOficial(Oficial oficial) async {
    final ok = await repository.createOficial(oficial);
    if (ok) {
      await loadOficiales();
    }
    return ok;
  }

  Future<bool> actualizarOficial({
    required String idOficial,
    required Map<String, dynamic> data,
  }) async {
    final ok = await repository.updateOficial(idOficial: idOficial, data: data);
    if (ok) {
      await loadOficiales();
    }
    return ok;
  }

  Future<bool> desactivarOficial(String idOficial) async {
    final ok = await repository.setOficialActivo(idOficial, false);
    if (ok) {
      await loadOficiales();
    }
    return ok;
  }

  Future<bool> activarOficial(String idOficial) async {
    final ok = await repository.setOficialActivo(idOficial, true);
    if (ok) {
      await loadOficiales();
    }
    return ok;
  }

  Future<bool> actualizarOficialesMasivo({
    required List<String> ids,
    String? grupo,
    String? turno,
    bool? activo,
  }) async {
    final ok = await repository.bulkUpdateOficiales(
      ids: ids,
      grupo: grupo,
      turno: turno,
      activo: activo,
    );
    if (ok) {
      await loadOficiales();
    }
    return ok;
  }

  Future<bool> registrarReo(Map<String, dynamic> data) async {
    final ok = await repository.upsertReo(data: data);
    if (ok) {
      await loadReos();
    }
    return ok;
  }

  Future<bool> solicitarParteDirecto({
    required String idOficial,
    required String supervisorNombre,
    required String razon,
  }) async {
    final ok = await repository.crearParteSorpresa(
      idOficial: idOficial,
      supervisorNombre: supervisorNombre,
      razon: razon,
    );
    if (ok) {
      await loadPartes();
    }
    return ok;
  }

  List<Oficial> get oficialesAlfa =>
      oficiales.where((o) => (o.grupo ?? '') == 'ALFA').toList();

  List<Oficial> get oficialesBravo =>
      oficiales.where((o) => (o.grupo ?? '') == 'BRAVO').toList();

  DateTime get operationalWindowStart {
    final now = DateTime.now();
    final anchor = now.hour < 8 ? now.subtract(const Duration(days: 1)) : now;
    return DateTime(anchor.year, anchor.month, anchor.day, 8, 0, 0);
  }

  DateTime get operationalWindowEnd =>
      operationalWindowStart.add(const Duration(days: 1));

  bool _inOperationalWindow(DateTime dateTime) {
    final local = dateTime;
    return !local.isBefore(operationalWindowStart) &&
        local.isBefore(operationalWindowEnd);
  }

  List<MonitoreoReporte> get reportesOperativos {
    final group = currentGroup.value.toUpperCase();
    final oficialById = <String, Oficial>{
      for (final o in oficiales) o.idOficial: o,
    };
    return reportes.where((r) => _inOperationalWindow(r.fechaHora)).where(
      (r) {
        final reportGroup = (r.grupo ?? '').toUpperCase();
        final resolvedGroup = reportGroup.isEmpty
            ? (oficialById[r.idOficialRef]?.grupo ?? '').toUpperCase()
            : reportGroup;
        return resolvedGroup == group;
      },
    ).toList();
  }

  Map<String, MonitoreoReporte> get latestReporteByOficialOperativo {
    final latest = <String, MonitoreoReporte>{};
    for (final report in reportesOperativos) {
      final current = latest[report.idOficialRef];
      if (current == null || report.fechaHora.isAfter(current.fechaHora)) {
        latest[report.idOficialRef] = report;
      }
    }
    return latest;
  }

  DateTime? _parseDateSafe(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toLocal();
    return DateTime.tryParse(raw.toString())?.toLocal();
  }

  List<Map<String, dynamic>> get alertasOperativasDelTurno {
    final currentGroupNormalized = currentGroup.value.toUpperCase();
    final oficialById = <String, Oficial>{
      for (final o in oficiales) o.idOficial: o,
    };

    return alertasOperativas.where((alerta) {
      final fecha = _parseDateSafe(alerta['fecha_hora']);
      if (fecha == null || !_inOperationalWindow(fecha)) return false;

      final idOficial =
          (alerta['id_oficial_ref'] ?? alerta['id_oficial'] ?? '').toString();
      if (idOficial.isEmpty) return false;

      final group = (alerta['grupo'] ?? oficialById[idOficial]?.grupo ?? '')
          .toString()
          .toUpperCase();
      if (group != currentGroupNormalized) return false;

      return true;
    }).toList();
  }

  String? _resolveTipoAlertaFromReporte(MonitoreoReporte reporte) {
    final distancia = (reporte.distanciaMetros ?? 0).toDouble();
    final bateria = (reporte.nivelBateria ?? 100).toDouble();
    final estado = reporte.estadoAlerta.toUpperCase();

    if (distancia > 50) return 'FUERA_RANGO';
    if (!reporte.gpsReal) return 'GPS_NO_CONFIABLE';
    if (bateria < 20) return 'BATERIA_BAJA';
    if (estado == 'CRITICO') return 'ALERTA_CRITICA';
    if (estado == 'ALERTA') return 'ALERTA_OPERATIVA';
    return null;
  }

  String _resolveMotivoAlertaFromReporte(
    MonitoreoReporte reporte,
    String tipo,
  ) {
    final distancia = (reporte.distanciaMetros ?? 0).toDouble();
    final bateria = (reporte.nivelBateria ?? 100).toDouble();
    switch (tipo) {
      case 'FUERA_RANGO':
        return 'FUERA DE RANGO (${distancia.toStringAsFixed(0)}m)';
      case 'GPS_NO_CONFIABLE':
        return 'GPS NO CONFIABLE';
      case 'BATERIA_BAJA':
        return 'BATERIA BAJA (${bateria.toStringAsFixed(0)}%)';
      case 'ALERTA_CRITICA':
        return 'ALERTA CRITICA OPERATIVA';
      default:
        return 'ALERTA OPERATIVA';
    }
  }

  int _resolveSeveridadFromReporte(MonitoreoReporte reporte, String tipo) {
    final distancia = (reporte.distanciaMetros ?? 0).toDouble();
    final bateria = (reporte.nivelBateria ?? 100).toDouble();
    final estado = reporte.estadoAlerta.toUpperCase();

    if (tipo == 'FUERA_RANGO') {
      return distancia > 200 ? 3 : 2;
    }
    if (tipo == 'BATERIA_BAJA') {
      return bateria < 10 ? 3 : 2;
    }
    if (tipo == 'GPS_NO_CONFIABLE') {
      return estado == 'CRITICO' ? 3 : 2;
    }
    if (tipo == 'ALERTA_CRITICA') return 3;
    return 2;
  }

  Map<String, dynamic>? _buildAlertSnapshotFromReporte(
    MonitoreoReporte reporte, {
    required Oficial? oficial,
  }) {
    final tipo = _resolveTipoAlertaFromReporte(reporte);
    if (tipo == null) return null;

    return {
      'id_oficial': reporte.idOficialRef,
      'id_oficial_ref': reporte.idOficialRef,
      'nombre_oficial': reporte.nombreOficial ?? oficial?.nombreOficial ?? '',
      'grupo': reporte.grupo ?? oficial?.grupo ?? '',
      'tipo_alerta': tipo,
      'motivo_alerta': _resolveMotivoAlertaFromReporte(reporte, tipo),
      'estado_alerta': reporte.estadoAlerta.toUpperCase(),
      'severidad': _resolveSeveridadFromReporte(reporte, tipo),
      'distancia_metros': (reporte.distanciaMetros ?? 0).toDouble(),
      'distancia_metros_max': (reporte.distanciaMetros ?? 0).toDouble(),
      'nivel_bateria': (reporte.nivelBateria ?? 100).clamp(0, 100),
      'nivel_bateria_min': (reporte.nivelBateria ?? 100).clamp(0, 100),
    };
  }

  Map<String, dynamic> _closeAlertEpisode(
    Map<String, dynamic> episode,
    DateTime closedAt,
  ) {
    final start = _parseDateSafe(episode['inicio_alerta']) ?? closedAt;
    final duration = closedAt.difference(start).inMinutes.clamp(0, 24 * 60);
    return {
      ...episode,
      'activa': false,
      'fin_alerta': closedAt.toIso8601String(),
      'duracion_min': duration,
    };
  }

  List<Map<String, dynamic>> get alertasEpisodiosDelTurno {
    final oficialById = <String, Oficial>{
      for (final o in oficiales) o.idOficial: o,
    };
    final reportesByOficial = <String, List<MonitoreoReporte>>{};

    for (final reporte in reportesOperativos) {
      final id = reporte.idOficialRef;
      if (id.isEmpty) continue;
      reportesByOficial
          .putIfAbsent(id, () => <MonitoreoReporte>[])
          .add(reporte);
    }

    final now = DateTime.now();
    final episodes = <Map<String, dynamic>>[];

    for (final entry in reportesByOficial.entries) {
      final list = entry.value
        ..sort((a, b) => a.fechaHora.compareTo(b.fechaHora));
      Map<String, dynamic>? current;

      for (final reporte in list) {
        final ts = reporte.fechaHora;
        final snapshot = _buildAlertSnapshotFromReporte(
          reporte,
          oficial: oficialById[entry.key],
        );

        if (snapshot == null) {
          if (current != null) {
            episodes.add(_closeAlertEpisode(current, ts));
            current = null;
          }
          continue;
        }

        final tipo = (snapshot['tipo_alerta'] ?? '').toString();
        if (current == null) {
          current = {
            ...snapshot,
            'id_episodio':
                'EP_${entry.key}_${tipo}_${ts.millisecondsSinceEpoch}',
            'inicio_alerta': ts.toIso8601String(),
            'ultimo_reporte_alerta': ts.toIso8601String(),
            'fin_alerta': null,
            'duracion_min': 0,
            'activa': true,
            'reportes_en_alerta': 1,
          };
          continue;
        }

        final currentTipo = (current['tipo_alerta'] ?? '').toString();
        if (currentTipo != tipo) {
          episodes.add(_closeAlertEpisode(current, ts));
          current = {
            ...snapshot,
            'id_episodio':
                'EP_${entry.key}_${tipo}_${ts.millisecondsSinceEpoch}',
            'inicio_alerta': ts.toIso8601String(),
            'ultimo_reporte_alerta': ts.toIso8601String(),
            'fin_alerta': null,
            'duracion_min': 0,
            'activa': true,
            'reportes_en_alerta': 1,
          };
          continue;
        }

        current['ultimo_reporte_alerta'] = ts.toIso8601String();
        current['reportes_en_alerta'] =
            ((current['reportes_en_alerta'] as num?)?.toInt() ?? 1) + 1;
        current['severidad'] = math.max(
          (current['severidad'] as num?)?.toInt() ?? 1,
          (snapshot['severidad'] as num?)?.toInt() ?? 1,
        );
        current['distancia_metros_max'] = math.max(
          (current['distancia_metros_max'] as num?)?.toDouble() ?? 0,
          (snapshot['distancia_metros_max'] as num?)?.toDouble() ?? 0,
        );
        current['distancia_metros'] =
            (snapshot['distancia_metros'] as num?)?.toDouble() ?? 0;
        current['nivel_bateria_min'] = math.min(
          (current['nivel_bateria_min'] as num?)?.toInt() ?? 100,
          (snapshot['nivel_bateria_min'] as num?)?.toInt() ?? 100,
        );
        current['nivel_bateria'] =
            (snapshot['nivel_bateria'] as num?)?.toInt() ?? 100;
        if ((snapshot['estado_alerta'] ?? '').toString().toUpperCase() ==
            'CRITICO') {
          current['estado_alerta'] = 'CRITICO';
        }
        current['motivo_alerta'] = snapshot['motivo_alerta'];
      }

      if (current != null) {
        final start = _parseDateSafe(current['inicio_alerta']) ?? now;
        final duration = now.difference(start).inMinutes.clamp(0, 24 * 60);
        episodes.add({
          ...current,
          'activa': true,
          'fin_alerta': null,
          'duracion_min': duration,
        });
      }
    }

    episodes.sort((a, b) {
      final activeA = a['activa'] == true ? 1 : 0;
      final activeB = b['activa'] == true ? 1 : 0;
      if (activeA != activeB) return activeB.compareTo(activeA);

      final sevA = (a['severidad'] as num?)?.toInt() ?? 1;
      final sevB = (b['severidad'] as num?)?.toInt() ?? 1;
      if (sevA != sevB) return sevB.compareTo(sevA);

      final dateA =
          _parseDateSafe(a['ultimo_reporte_alerta'] ?? a['inicio_alerta']) ??
              DateTime(1970);
      final dateB =
          _parseDateSafe(b['ultimo_reporte_alerta'] ?? b['inicio_alerta']) ??
              DateTime(1970);
      return dateB.compareTo(dateA);
    });

    return episodes;
  }

  List<Map<String, dynamic>> get alertasEpisodiosActivosDelTurno {
    return alertasEpisodiosDelTurno.where((e) => e['activa'] == true).toList();
  }

  String alertEpisodeKey(Map<String, dynamic> alerta) {
    final episodio =
        (alerta['id_episodio'] ?? alerta['id_alerta'] ?? '').toString().trim();
    if (episodio.isNotEmpty) return episodio;
    final oficial =
        (alerta['id_oficial_ref'] ?? alerta['id_oficial'] ?? '').toString();
    final tipo = (alerta['tipo_alerta'] ?? '').toString();
    final inicio = (alerta['inicio_alerta'] ??
            alerta['ultimo_reporte_alerta'] ??
            alerta['fecha_hora'] ??
            '')
        .toString();
    return '$oficial|$tipo|$inicio';
  }

  Set<String> get acknowledgedAlertEpisodeIds => _acknowledgedAlertEpisodeIds;

  bool isAlertEpisodeAcknowledged(Map<String, dynamic> alerta) {
    return _acknowledgedAlertEpisodeIds.contains(alertEpisodeKey(alerta));
  }

  void acknowledgeAlertEpisode(Map<String, dynamic> alerta) {
    final changed = _acknowledgedAlertEpisodeIds.add(alertEpisodeKey(alerta));
    if (changed) {
      alertAcknowledgementVersion.value++;
    }
  }

  void acknowledgeAllAlertEpisodes(Iterable<Map<String, dynamic>> alertas) {
    var changed = false;
    for (final alerta in alertas) {
      if (alerta['activa'] != true) continue;
      if (_acknowledgedAlertEpisodeIds.add(alertEpisodeKey(alerta))) {
        changed = true;
      }
    }
    if (changed) {
      alertAcknowledgementVersion.value++;
    }
  }

  List<Map<String, dynamic>> get alertasEpisodiosActivosNoLeidosDelTurno {
    return alertasEpisodiosActivosDelTurno
        .where((e) => !isAlertEpisodeAcknowledged(e))
        .toList();
  }

  Map<String, Map<String, dynamic>> get latestAlertaOperativaByOficial {
    final latest = <String, Map<String, dynamic>>{};
    final latestAlertas = alertasOperativasDelTurno;
    for (final alerta in latestAlertas) {
      final idOficial =
          (alerta['id_oficial_ref'] ?? alerta['id_oficial'] ?? '').toString();
      if (idOficial.isEmpty) continue;
      final fecha = _parseDateSafe(alerta['fecha_hora']) ?? DateTime(1970);
      final current = latest[idOficial];
      final currentFecha = current == null
          ? DateTime(1970)
          : _parseDateSafe(current['fecha_hora']) ?? DateTime(1970);
      if (current == null || fecha.isAfter(currentFecha)) {
        latest[idOficial] = alerta;
      }
    }
    return latest;
  }

  Map<String, dynamic> buildRealtimeAnalytics() {
    final currentGroupNormalized = currentGroup.value.toUpperCase();
    final oficialesActivosNominal = oficiales.where((o) => o.activo).toList();
    final oficialById = <String, Oficial>{
      for (final o in oficiales) o.idOficial: o,
    };

    final nominalAlfa = oficialesActivosNominal
        .where((o) => (o.grupo ?? '').toUpperCase() == 'ALFA')
        .length;
    final nominalBravo = oficialesActivosNominal
        .where((o) => (o.grupo ?? '').toUpperCase() == 'BRAVO')
        .length;
    final nominalTotal =
        currentGroupNormalized == 'BRAVO' ? nominalBravo : nominalAlfa;

    String resolveReportGroup(MonitoreoReporte r) {
      final reportGroup = (r.grupo ?? '').toUpperCase();
      if (reportGroup.isNotEmpty) return reportGroup;
      return (oficialById[r.idOficialRef]?.grupo ?? '').toUpperCase();
    }

    final reportesVentana =
        reportes.where((r) => _inOperationalWindow(r.fechaHora)).toList();

    final latestByOficialWindow = <String, MonitoreoReporte>{};
    for (final report in reportesVentana) {
      final current = latestByOficialWindow[report.idOficialRef];
      if (current == null || report.fechaHora.isAfter(current.fechaHora)) {
        latestByOficialWindow[report.idOficialRef] = report;
      }
    }

    final latestReportsWindow = latestByOficialWindow.values.toList();
    final latestReports = latestReportsWindow
        .where((r) => resolveReportGroup(r) == currentGroupNormalized)
        .toList();

    final activeTotal = latestReports.length;
    final activeAlfa = latestReportsWindow
        .where((r) => resolveReportGroup(r) == 'ALFA')
        .length;
    final activeBravo = latestReportsWindow
        .where((r) => resolveReportGroup(r) == 'BRAVO')
        .length;

    final coveragePct =
        nominalTotal == 0 ? 0.0 : (activeTotal / nominalTotal) * 100.0;

    final now = DateTime.now();
    final effectiveWindowEnd =
        now.isBefore(operationalWindowEnd) ? now : operationalWindowEnd;
    final elapsedMinutes = math.max(
      1,
      effectiveWindowEnd.difference(operationalWindowStart).inMinutes,
    );
    const reportIntervalMinutes = 6;
    const fullWindowMinutes = 24 * 60;
    final expectedPerOfficerElapsed =
        (elapsedMinutes / reportIntervalMinutes).ceil();
    const expectedPerOfficerFullWindow =
        fullWindowMinutes ~/ reportIntervalMinutes;

    final reportesGrupo = reportesVentana
        .where((r) => resolveReportGroup(r) == currentGroupNormalized)
        .toList();
    final reportesTotal = reportesGrupo.length;
    final reportesEsperados = nominalTotal * expectedPerOfficerElapsed;
    final reportesEsperadosJornada =
        nominalTotal * expectedPerOfficerFullWindow;
    final cumplimientoReportesPct = reportesEsperados == 0
        ? 0.0
        : ((reportesTotal / reportesEsperados) * 100).clamp(0.0, 100.0);
    final cumplimientoBand = _metricBand(
      cumplimientoReportesPct,
      high: 90,
      medium: 75,
    );

    int distIn = 0;
    int distMid = 0;
    int distHigh = 0;
    int distExtreme = 0;

    int batLow = 0;
    int batMid = 0;
    int batHigh = 0;

    int telemetriaLow = 0;
    int telemetriaMid = 0;
    int telemetriaHigh = 0;

    for (final r in latestReports) {
      final dist = (r.distanciaMetros ?? 0).toDouble();
      final bat = (r.nivelBateria ?? 100).toDouble();

      if (dist <= 50) {
        distIn++;
      } else if (dist <= 100) {
        distMid++;
      } else if (dist <= 200) {
        distHigh++;
      } else {
        distExtreme++;
      }

      if (bat <= 20) {
        batLow++;
      } else if (bat <= 60) {
        batMid++;
      } else {
        batHigh++;
      }

      final hasHardAlert = r.estadoAlerta.toUpperCase() == 'CRITICO' ||
          r.estadoAlerta.toUpperCase() == 'ALERTA' ||
          dist > 50 ||
          bat < 20 ||
          !r.gpsReal;
      if (hasHardAlert) continue;

      if (bat <= 35 || dist > 40) {
        telemetriaHigh++;
      } else if (bat <= 55 || dist > 20) {
        telemetriaMid++;
      } else if (bat <= 70 || dist > 10) {
        telemetriaLow++;
      }
    }

    int alertAbandono = 0;
    int alertIncons = 0;
    int alertFalta = 0;
    int alertHigh = 0;
    int alertMedium = 0;
    int alertLow = 0;

    for (final alerta in alertasEpisodiosActivosDelTurno) {
      final tipo = (alerta['tipo_alerta'] ?? '').toString().toUpperCase();
      final motivo = (alerta['motivo_alerta'] ?? '').toString().toUpperCase();
      final severidad = (alerta['severidad'] as num?)?.toInt() ?? 1;

      if (severidad >= 3) {
        alertHigh++;
      } else if (severidad == 2) {
        alertMedium++;
      } else {
        alertLow++;
      }

      if (tipo.contains('FALTA') || motivo.contains('FALTA')) {
        alertFalta++;
      } else if (tipo.contains('ABANDONO') ||
          motivo.contains('RANGO') ||
          motivo.contains('ABANDONO')) {
        alertAbandono++;
      } else {
        alertIncons++;
      }
    }

    final inconsistenciasTurno = inconsistencias.where((inc) {
      final raw = inc['fecha_deteccion'];
      if (raw == null) return false;
      final date = DateTime.tryParse(raw.toString());
      if (date == null) return false;
      if (!_inOperationalWindow(date)) return false;
      final idOficial = (inc['id_oficial'] ?? '').toString();
      final group = (oficialById[idOficial]?.grupo ?? '').toUpperCase();
      return group == currentGroupNormalized;
    }).toList();

    int inconsHigh = 0;
    int inconsMedium = 0;
    int inconsLow = 0;

    for (final inc in inconsistenciasTurno) {
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

    final inconsistenciasAbiertas = inconsistenciasTurno
        .where((inc) =>
            (inc['estado'] ?? '').toString().toUpperCase() != 'CERRADA')
        .length;

    final complianceGeo = activeTotal == 0 ? 0.0 : (distIn / activeTotal) * 100;
    final reportesPorOficial =
        activeTotal == 0 ? 0.0 : reportesTotal / activeTotal.toDouble();

    final trendReportes = <double>[];
    final trendActivos = <double>[];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final keyDay = DateTime(day.year, day.month, day.day);

      final reportesDia = reportes.where((r) {
        final local = r.fechaHora;
        final sameDay = local.year == keyDay.year &&
            local.month == keyDay.month &&
            local.day == keyDay.day;
        if (!sameDay) return false;
        return resolveReportGroup(r) == currentGroupNormalized;
      }).toList();
      trendReportes.add(reportesDia.length.toDouble());

      final activeDia = reportesDia.map((r) => r.idOficialRef).toSet().length;
      trendActivos.add(activeDia.toDouble());
    }

    final laneAlertLevel = _laneLevel(
      high: alertHigh,
      medium: alertMedium,
      low: alertLow,
      total: alertHigh + alertMedium + alertLow,
    );
    final laneInconsLevel = _laneLevel(
      high: inconsHigh,
      medium: inconsMedium,
      low: inconsLow,
      total: inconsistenciasTurno.length,
    );
    final laneTelemetriaLevel = _laneLevel(
      high: telemetriaHigh,
      medium: telemetriaMid,
      low: telemetriaLow,
      total: telemetriaHigh + telemetriaMid + telemetriaLow,
    );

    final riskRaw = (alertHigh * 25.0) +
        (alertMedium * 12.0) +
        (inconsHigh * 10.0) +
        (inconsMedium * 5.0) +
        (telemetriaHigh * 6.0) +
        ((100 - cumplimientoReportesPct) * 0.5);
    var riskIndex = riskRaw.clamp(0.0, 100.0);
    if (nominalTotal > 0 && activeTotal == 0) {
      riskIndex = 100.0;
    } else if (nominalTotal > 0 && coveragePct < 40) {
      riskIndex = math.max(riskIndex, 85.0);
    }

    return {
      'window_start': operationalWindowStart.toIso8601String(),
      'window_end': operationalWindowEnd.toIso8601String(),
      'window_elapsed_min': elapsedMinutes,
      'intervalo_reporte_min': reportIntervalMinutes,
      'nominal_total': nominalTotal,
      'nominal_alfa': nominalAlfa,
      'nominal_bravo': nominalBravo,
      'active_total': activeTotal,
      'active_alfa': activeAlfa,
      'active_bravo': activeBravo,
      'coverage_pct': coveragePct,
      'reportes_total': reportesTotal,
      'reportes_esperados': reportesEsperados,
      'reportes_esperados_jornada': reportesEsperadosJornada,
      'cumplimiento_reportes_pct': cumplimientoReportesPct,
      'cumplimiento_reportes_nivel': cumplimientoBand,
      'reportes_por_oficial': reportesPorOficial,
      'geo_compliance_pct': complianceGeo,
      'risk_index': riskIndex,
      'dist_buckets': [distIn, distMid, distHigh, distExtreme],
      'battery_buckets': [batLow, batMid, batHigh],
      'alert_buckets': [alertAbandono, alertIncons, alertFalta],
      'telemetria_buckets': [telemetriaLow, telemetriaMid, telemetriaHigh],
      'alertas_total_activas': alertHigh + alertMedium + alertLow,
      'inconsistencias_total_turno': inconsistenciasTurno.length,
      'inconsistencias_abiertas_turno': inconsistenciasAbiertas,
      'telemetria_observaciones':
          telemetriaLow + telemetriaMid + telemetriaHigh,
      'lanes': {
        'alertas': {
          'total': alertHigh + alertMedium + alertLow,
          'alta': alertHigh,
          'media': alertMedium,
          'baja': alertLow,
          'nivel': laneAlertLevel,
        },
        'inconsistencias': {
          'total': inconsistenciasTurno.length,
          'alta': inconsHigh,
          'media': inconsMedium,
          'baja': inconsLow,
          'nivel': laneInconsLevel,
        },
        'telemetria': {
          'total': telemetriaLow + telemetriaMid + telemetriaHigh,
          'alta': telemetriaHigh,
          'media': telemetriaMid,
          'baja': telemetriaLow,
          'nivel': laneTelemetriaLevel,
        },
      },
      'thresholds': {
        'cumplimiento_alto_pct': 90,
        'cumplimiento_medio_pct': 75,
        'reporte_intervalo_min': reportIntervalMinutes,
      },
      'trend_reportes_7d': trendReportes,
      'trend_activos_7d': trendActivos,
    };
  }

  String _metricBand(
    double value, {
    required double high,
    required double medium,
  }) {
    if (value >= high) return 'ALTO';
    if (value >= medium) return 'MEDIO';
    return 'BAJO';
  }

  String _laneLevel({
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

  double get cobertura {
    return (buildRealtimeAnalytics()['coverage_pct'] as num?)?.toDouble() ??
        0.0;
  }

  List<ParteSorpresa> get partesSorpresa => partes;

  bool _inconsistenciaMatchesCurrentGroup(Map<String, dynamic> inc) {
    final currentGroupNormalized = currentGroup.value.toUpperCase().trim();
    if (currentGroupNormalized.isEmpty) return true;

    final idOficial =
        (inc['id_oficial'] ?? inc['id_oficial_ref'] ?? '').toString().trim();
    final groupFromRow =
        (inc['grupo'] ?? inc['grupo_oficial'] ?? inc['grupo_turno'] ?? '')
            .toString()
            .toUpperCase()
            .trim();

    if (groupFromRow.isNotEmpty) {
      return groupFromRow == currentGroupNormalized;
    }

    if (idOficial.isEmpty) return false;
    final oficial = oficiales.firstWhereOrNull(
      (o) => o.idOficial.trim() == idOficial,
    );
    final groupFromOficial =
        (oficial?.grupo ?? '').toString().toUpperCase().trim();
    if (groupFromOficial.isEmpty) return false;
    return groupFromOficial == currentGroupNormalized;
  }

  List<Map<String, dynamic>> get inconsistenciasDelGrupoActivo {
    return inconsistencias
        .where((inc) => _inconsistenciaMatchesCurrentGroup(inc))
        .toList();
  }

  List<Map<String, dynamic>> get inconsistenciasFiltered {
    final base = inconsistenciasDelGrupoActivo;
    if (filterEstado.value == 'TODOS') return base;
    return base.where((inc) => inc['estado'] == filterEstado.value).toList();
  }

  List<Map<String, dynamic>> get inconsistenciasAbiertas =>
      inconsistenciasDelGrupoActivo
          .where((inc) => inc['estado'] == 'ABIERTA')
          .toList();

  List<Map<String, dynamic>> get inconsistenciasEnRevision =>
      inconsistenciasDelGrupoActivo
          .where((inc) => inc['estado'] == 'EN_REVISION')
          .toList();

  int get unreadRadioInboxCount => radioInboxSupervisor.where((msg) {
        final estado = msg.estado.trim().toUpperCase();
        final from = msg.deUsuario.trim().toUpperCase();
        if (RadioRtcSignal.isRtcPayload(msg.mensaje)) return false;
        return from != 'SUPERVISOR' && estado != 'LEIDO';
      }).length;

  Future<void> markSupervisorRadioInboxAsRead({String? oficialId}) async {
    final target = oficialId?.trim();
    final pending = radioInboxSupervisor.where((msg) {
      final estado = msg.estado.trim().toUpperCase();
      final from = msg.deUsuario.trim().toUpperCase();
      if (from == 'SUPERVISOR' || estado == 'LEIDO') return false;
      if (target == null || target.isEmpty) return true;
      return msg.idOficial.trim() == target;
    }).toList();
    if (pending.isEmpty) return;

    for (final msg in pending) {
      await repository.markRadioMessageRead(msg.idMensaje);
    }
    await loadRadioInboxSupervisor();
  }

  Reo? findReoByCodigo(String? codigoReo) {
    if (codigoReo == null || codigoReo.isEmpty) return null;
    return reos.firstWhereOrNull(
      (reo) => reo.codigoReo.toUpperCase() == codigoReo.toUpperCase(),
    );
  }

  Reo? findReoByOficial(String? idOficial) {
    if (idOficial == null || idOficial.isEmpty) return null;
    return reos.firstWhereOrNull(
      (reo) =>
          (reo.oficialAsignado ?? '').toUpperCase() == idOficial.toUpperCase(),
    );
  }

  String getReoNombreByCodigo(String? codigoReo) {
    final reo = findReoByCodigo(codigoReo);
    if (reo != null && reo.nombreCompleto.isNotEmpty) {
      return reo.nombreCompleto;
    }
    return (codigoReo == null || codigoReo.isEmpty) ? 'N/D' : codigoReo;
  }

  String getReoTelefonoByCodigo(String? codigoReo) {
    final reo = findReoByCodigo(codigoReo);
    final phone = reo?.telefono;
    if (phone == null || phone.isEmpty) return 'N/D';
    return phone;
  }

  ({double lat, double lng})? parseCoords(String? coordsRaw) {
    if (coordsRaw == null || coordsRaw.trim().isEmpty) return null;
    final normalized = coordsRaw.trim().replaceAll(';', ',');
    final parts = normalized.split(',');
    if (parts.length < 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }
}

class _RadioCallAggregate {
  bool attempted = false;
  bool responded = false;
  bool failed = false;
  bool ended = false;
}

class _RadioReportEvent {
  final String tipo;
  final String canal;
  final String estado;
  final String detalle;

  const _RadioReportEvent({
    required this.tipo,
    required this.canal,
    required this.estado,
    required this.detalle,
  });

  _RadioReportEvent copyWith({
    String? tipo,
    String? canal,
    String? estado,
    String? detalle,
  }) {
    return _RadioReportEvent(
      tipo: tipo ?? this.tipo,
      canal: canal ?? this.canal,
      estado: estado ?? this.estado,
      detalle: detalle ?? this.detalle,
    );
  }
}
