import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/oficial_model.dart';
import '../models/monitoreo_reporte_model.dart';
import '../models/inconsistencia_model.dart';
import '../models/parte_sorpresa_model.dart';
import '../models/radio_message_model.dart';
import '../models/allowed_admin_model.dart';
import '../models/reo_model.dart';
import '../../core/constants/app_constants.dart';

class SupabaseRepository {
  final _supabase = Supabase.instance.client;
  static const String _verifyAdminPinRpc = 'fn_verify_admin_pin';
  static const String _updateAdminPinRpc = 'fn_update_admin_pin_secure';
  static const Set<String> _allowedCommanderDeleteTables = {
    'monitoreo_reportes',
    'inconsistencias',
    'partes_sorpresa',
    'partes_oficiales',
    'radio_mensajes',
    'radio_llamadas',
    'oficiales',
    'reos',
    'login_logs',
  };
  static final RegExp _unsafeWherePattern = RegExp(
    r'(--|/\*|\*/|;|\b(drop|truncate|grant|revoke|alter|create)\b)',
    caseSensitive: false,
  );
  static final RegExp _unsafeIdentifierPattern = RegExp(r'[^a-zA-Z0-9_]');

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  String _normalizeIdentifier(String value) {
    return value.trim().toLowerCase();
  }

  bool _isSafeCommanderDeleteRequest({
    required String table,
    required String whereClause,
  }) {
    if (_unsafeIdentifierPattern.hasMatch(table)) return false;
    if (!_allowedCommanderDeleteTables.contains(table)) return false;

    final clause = whereClause.trim();
    if (clause.isEmpty) return false;
    if (clause == '1=1' || clause.toUpperCase() == 'TRUE') return false;
    if (_unsafeWherePattern.hasMatch(clause)) return false;
    return true;
  }

  bool _isLogicalInconsistencyType(String tipoRaw) {
    final tipo = tipoRaw.trim().toUpperCase();
    if (tipo.isEmpty) return false;

    final known = <String>{
      'GPS_FALSO',
      'VOZ_NO_COINCIDE',
      'UBICACION_FOTO_NO_COINCIDE',
      'FOTO_UBICACION_NO_COINCIDE',
      'MANIPULACION_GPS',
      'COORDENADAS_IMPOSIBLES',
      'IMEI_CAMBIADO',
      'DISTANCIA_EXCEDIDA',
      'SIN_DATOS_GPS',
      'FALTA_REPORTE',
      'FALLA_TECNICA_VOZ',
      'POSIBLE_SUPLANTACION',
      'OFICIAL_CERRO_VENTANA_PARTE',
      'PARTE_RECHAZADO_NO_GUARDADO',
      'ANTI_MOCKING_ALERTA',
      'EVIDENCIA_HASH_FALLA',
    };
    if (known.contains(tipo)) return true;

    if (tipo.startsWith('FALLA_') ||
        tipo.startsWith('POSIBLE_') ||
        tipo.startsWith('PARTE_') ||
        tipo.startsWith('OFICIAL_') ||
        tipo.startsWith('ANTI_') ||
        tipo.startsWith('EVIDENCIA_') ||
        tipo.startsWith('DISTANCIA_') ||
        tipo.startsWith('SIN_')) {
      return true;
    }

    // Fail-open: no ocultar eventos reales por tipado nuevo.
    return true;
  }

  String _deriveMotivoAlerta(Map<String, dynamic> row) {
    final motivoFromView = (row['motivo_alerta'] ?? '').toString().trim();
    if (motivoFromView.isNotEmpty) return motivoFromView;

    final estado = (row['estado_alerta'] ?? 'NORMAL').toString().toUpperCase();
    final gpsReal = row['gps_real'] == true;
    final battery = (row['nivel_bateria'] as num?)?.toDouble() ?? 100;
    final meters = (row['distancia_metros'] as num?)?.toDouble() ?? 0;
    final parte = (row['parte_novedad'] ?? '').toString().trim().toUpperCase();

    if (parte.isNotEmpty && parte != 'NINGUNA' && parte != 'SIN NOVEDAD') {
      return 'PARTE/NOVEDAD';
    }
    if (meters > 50) {
      return 'FUERA DE RANGO (${meters.toStringAsFixed(0)}m)';
    }
    if (!gpsReal) return 'GPS NO CONFIABLE';
    if (battery < 20) return 'BATERIA BAJA';
    if (estado == 'CRITICO') return 'ALERTA CRITICA';
    if (estado == 'ALERTA') return 'ALERTA OPERATIVA';
    return 'ALERTA OPERATIVA';
  }

  String _deriveTipoAlerta(Map<String, dynamic> row) {
    final tipoFromView = (row['tipo_alerta'] ?? '').toString().trim();
    if (tipoFromView.isNotEmpty) return tipoFromView.toUpperCase();

    final motivo = _deriveMotivoAlerta(row).toUpperCase();
    if (motivo.contains('RANGO') || motivo.contains('ABANDONO')) {
      return 'ABANDONO_CONTROL';
    }
    if (motivo.contains('GPS') || motivo.contains('BATERIA')) {
      return 'TELEMETRIA';
    }
    if (motivo.contains('PARTE')) return 'INCUMPLIMIENTO_PARTE';
    return 'OPERATIVA';
  }

  int _deriveSeveridad(Map<String, dynamic> row) {
    final sevRaw = row['severidad'];
    if (sevRaw is num) return sevRaw.toInt().clamp(1, 3);

    final estado = (row['estado_alerta'] ?? '').toString().toUpperCase();
    final meters = (row['distancia_metros'] as num?)?.toDouble() ?? 0;
    if (estado == 'CRITICO' || meters > 100) return 3;
    if (estado == 'ALERTA' || meters > 50) return 2;
    return 1;
  }

  // ── RADIO MESSAGES ─────────────────────────────────────────────

  /// Stream de mensajes de radio para comunicación en tiempo real
  Stream<List<RadioMessage>> radioMessagesStream() {
    return _supabase
        .from('radio_mensajes')
        .stream(primaryKey: ['id_mensaje'])
        .order('timestamp', ascending: false)
        .limit(50)
        .map((data) => data
            .where((json) =>
                json['tipo']?.toString().trim().toUpperCase() == 'RADIO')
            .map((json) => RadioMessage.fromJson(json))
            .toList());
  }

  // ========================================
  // OFICIALES
  // ========================================

  Future<List<Oficial>> getOficiales() async {
    try {
      _log(
          '🔍 [DEBUG] Fetching oficiales from: ${AppConstants.tableOficiales}');

      final response = await _supabase
          .from(AppConstants.tableOficiales)
          .select()
          .eq('activo', true)
          .order('nombre_oficial', ascending: true);

      _log('📊 [DEBUG] Oficiales query response: ${response.length} records');

      final oficiales =
          (response as List).map((json) => Oficial.fromJson(json)).toList();

      _log('✅ [DEBUG] Parsed ${oficiales.length} oficiales successfully');
      return oficiales;
    } catch (e, stackTrace) {
      _log('❌ [ERROR] Error fetching oficiales: $e');
      _log('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<Oficial?> getOficialById(String idOficial) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableOficiales)
          .select()
          .eq('id_oficial', idOficial)
          .single();

      return Oficial.fromJson(response);
    } catch (e) {
      _log('❌ [ERROR] Error fetching oficial $idOficial: $e');
      return null;
    }
  }

  Future<bool> createOficial(Oficial oficial) async {
    try {
      await _supabase
          .from(AppConstants.tableOficiales)
          .insert(oficial.toJson());
      return true;
    } catch (e) {
      _log('❌ [ERROR] Error creating oficial ${oficial.idOficial}: $e');
      return false;
    }
  }

  Future<bool> updateOficial({
    required String idOficial,
    required Map<String, dynamic> data,
  }) async {
    try {
      await _supabase
          .from(AppConstants.tableOficiales)
          .update(data)
          .eq('id_oficial', idOficial);
      return true;
    } catch (e) {
      _log('❌ [ERROR] Error updating oficial $idOficial: $e');
      return false;
    }
  }

  Future<bool> setOficialActivo(String idOficial, bool activo) async {
    return updateOficial(
      idOficial: idOficial,
      data: {'activo': activo},
    );
  }

  Future<bool> bulkUpdateOficiales({
    required List<String> ids,
    String? grupo,
    String? turno,
    bool? activo,
  }) async {
    if (ids.isEmpty) return false;
    final update = <String, dynamic>{};
    if (grupo != null && grupo.isNotEmpty) update['grupo'] = grupo;
    if (turno != null && turno.isNotEmpty) update['turno'] = turno;
    if (activo != null) update['activo'] = activo;
    if (update.isEmpty) return false;

    try {
      await _supabase
          .from(AppConstants.tableOficiales)
          .update(update)
          .inFilter('id_oficial', ids);
      return true;
    } catch (e) {
      _log('❌ [ERROR] Error bulk updating oficiales: $e');
      return false;
    }
  }

  // ========================================
  // MONITOREO REPORTES
  // ========================================

  Future<List<MonitoreoReporte>> getUltimosReportes({int limit = 500}) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMonitoreo)
          .select()
          .order('fecha_hora', ascending: false)
          .limit(limit);

      final reportes = (response as List)
          .map((json) => MonitoreoReporte.fromJson(json))
          .toList();
      return reportes;
    } catch (e, stackTrace) {
      _log('❌ [ERROR] Error fetching reportes: $e');
      _log('Stack trace: $stackTrace');
      return [];
    }
  }

  Future<MonitoreoReporte?> getUltimoReporteByOficial(String oficialId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMonitoreo)
          .select()
          .eq('id_oficial_ref', oficialId)
          .order('fecha_hora', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return MonitoreoReporte.fromJson(response);
    } catch (e) {
      _log('❌ [ERROR] Error fetching último reporte for $oficialId: $e');
      return null;
    }
  }

  Future<List<MonitoreoReporte>> getReportesByOficial(
    String oficialId, {
    int limit = 50,
  }) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMonitoreo)
          .select()
          .eq('id_oficial_ref', oficialId)
          .order('fecha_hora', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => MonitoreoReporte.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching reportes for oficial $oficialId: $e');
      return [];
    }
  }

  Future<List<MonitoreoReporte>> getReportesByGrupo(
    String grupo, {
    int limit = 100,
  }) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMonitoreo)
          .select()
          .eq('grupo', grupo)
          .order('fecha_hora', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => MonitoreoReporte.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching reportes for grupo $grupo: $e');
      return [];
    }
  }

  Future<List<MonitoreoReporte>> getReportesEnRango({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? grupo,
    String? idOficial,
    int limit = 10000,
  }) async {
    try {
      var query = _supabase.from(AppConstants.tableMonitoreo).select();

      if (grupo != null && grupo.isNotEmpty) {
        query = query.eq('grupo', grupo);
      }
      if (idOficial != null && idOficial.isNotEmpty) {
        query = query.eq('id_oficial_ref', idOficial);
      }

      final response = await query
          .gte('fecha_hora', fechaInicio.toIso8601String())
          .lt('fecha_hora', fechaFin.toIso8601String())
          .order('fecha_hora', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => MonitoreoReporte.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching reportes en rango: $e');
      return [];
    }
  }

  Future<List<MonitoreoReporte>> getReportesEnAlerta() async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMonitoreo)
          .select()
          .or('estado_alerta.eq.ALERTA,estado_alerta.eq.CRITICO')
          .order('fecha_hora', ascending: false)
          .limit(50);

      return (response as List)
          .map((json) => MonitoreoReporte.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching reportes en alerta: $e');
      return [];
    }
  }

  // ========================================
  // REOS
  // ========================================

  Future<List<Reo>> getReos() async {
    try {
      final response = await _supabase
          .from(AppConstants.tableReos)
          .select()
          .order('codigo_reo', ascending: true);

      return (response as List).map((json) => Reo.fromJson(json)).toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching reos: $e');
      return [];
    }
  }

  Future<Reo?> getReoByCodigo(String codigoReo) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableReos)
          .select()
          .eq('codigo_reo', codigoReo)
          .maybeSingle();

      if (response == null) return null;
      return Reo.fromJson(response);
    } catch (e) {
      _log('❌ [ERROR] Error fetching reo $codigoReo: $e');
      return null;
    }
  }

  Future<bool> upsertReo({
    required Map<String, dynamic> data,
  }) async {
    try {
      await _supabase.from(AppConstants.tableReos).upsert(
            data,
            onConflict: 'codigo_reo',
          );
      return true;
    } catch (e) {
      _log('❌ [ERROR] Error upserting reo: $e');
      return false;
    }
  }

  // ========================================
  // INCONSISTENCIAS
  // ========================================

  Future<List<Map<String, dynamic>>> getInconsistencias({
    bool soloAbiertas = true,
    int limit = 50,
  }) async {
    try {
      var query =
          _supabase.from(AppConstants.viewInconsistenciasLogicas).select();

      if (soloAbiertas) {
        query = query.or('resuelta.is.null,resuelta.eq.false');
      }

      final response =
          await query.order('fecha_deteccion', ascending: false).limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (_) {
      try {
        var fallback =
            _supabase.from(AppConstants.tableInconsistencias).select();
        if (soloAbiertas) {
          fallback = fallback.or('resuelta.is.null,resuelta.eq.false');
        }
        final response = await fallback
            .order('fecha_deteccion', ascending: false)
            .limit(limit);
        return (response as List)
            .cast<Map<String, dynamic>>()
            .where((row) => _isLogicalInconsistencyType(
                (row['tipo_inconsistencia'] ?? '').toString()))
            .toList();
      } catch (e) {
        _log('❌ [ERROR] Error fetching inconsistencias: $e');
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> getAlertasOperativas(
      {int limit = 120}) async {
    try {
      final response = await _supabase
          .from(AppConstants.viewAlertasOperativas)
          .select()
          .order('fecha_hora', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>().map((row) {
        return {
          ...row,
          'motivo_alerta': _deriveMotivoAlerta(row),
          'tipo_alerta': _deriveTipoAlerta(row),
          'severidad': _deriveSeveridad(row),
        };
      }).toList();
    } catch (_) {
      try {
        final response = await _supabase
            .from(AppConstants.tableMonitoreo)
            .select(
                'id_reporte, id_oficial_ref, nombre_oficial, grupo, estado_alerta, distancia_metros, nivel_bateria, gps_real, parte_novedad, fecha_hora')
            .or('estado_alerta.eq.ALERTA,estado_alerta.eq.CRITICO,gps_real.eq.false,nivel_bateria.lt.20,distancia_metros.gt.50')
            .order('fecha_hora', ascending: false)
            .limit(limit);

        final rows = (response as List).cast<Map<String, dynamic>>();
        return rows.map((row) {
          final idOficial = (row['id_oficial_ref'] ?? '').toString();
          final fecha = (row['fecha_hora'] ?? DateTime.now().toIso8601String())
              .toString();
          final motivo = _deriveMotivoAlerta(row);
          final tipo = _deriveTipoAlerta(row);
          return {
            ...row,
            'id_alerta': '${idOficial}_$fecha',
            'id_oficial': idOficial,
            'motivo_alerta': motivo,
            'tipo_alerta': tipo,
            'severidad': _deriveSeveridad(row),
          };
        }).toList();
      } catch (e) {
        _log('❌ [ERROR] Error fetching alertas operativas: $e');
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> getTelemetriaActual(
      {int limit = 120}) async {
    try {
      final response = await _supabase
          .from(AppConstants.viewTelemetriaActual)
          .select()
          .order('fecha_hora', ascending: false)
          .limit(limit);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (_) {
      try {
        final response = await _supabase
            .from(AppConstants.tableMonitoreo)
            .select(
                'id_oficial_ref, grupo, nivel_bateria, gps_real, estado_alerta, fecha_hora, parte_novedad')
            .order('fecha_hora', ascending: false)
            .limit(limit * 4);

        final latest = <String, Map<String, dynamic>>{};
        for (final row in (response as List).cast<Map<String, dynamic>>()) {
          final id = (row['id_oficial_ref'] ?? '').toString();
          if (id.isEmpty || latest.containsKey(id)) continue;
          latest[id] = row;
        }
        return latest.values.toList();
      } catch (e) {
        _log('❌ [ERROR] Error fetching telemetría actual: $e');
        return [];
      }
    }
  }

  Future<List<Map<String, dynamic>>> getInconsistenciasEnRango({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? idOficial,
    bool? resuelta,
    int limit = 5000,
  }) async {
    try {
      var query =
          _supabase.from(AppConstants.viewInconsistenciasLogicas).select();

      if (idOficial != null && idOficial.isNotEmpty) {
        query = query.eq('id_oficial', idOficial);
      }
      if (resuelta != null) {
        query = resuelta
            ? query.eq('resuelta', true)
            : query.or('resuelta.is.null,resuelta.eq.false');
      }

      final response = await query
          .gte('fecha_deteccion', fechaInicio.toIso8601String())
          .lt('fecha_deteccion', fechaFin.toIso8601String())
          .order('fecha_deteccion', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (_) {
      try {
        var query = _supabase.from(AppConstants.tableInconsistencias).select();
        if (idOficial != null && idOficial.isNotEmpty) {
          query = query.eq('id_oficial', idOficial);
        }
        if (resuelta != null) {
          query = resuelta
              ? query.eq('resuelta', true)
              : query.or('resuelta.is.null,resuelta.eq.false');
        }
        final response = await query
            .gte('fecha_deteccion', fechaInicio.toIso8601String())
            .lt('fecha_deteccion', fechaFin.toIso8601String())
            .order('fecha_deteccion', ascending: false)
            .limit(limit);
        return (response as List)
            .cast<Map<String, dynamic>>()
            .where((row) => _isLogicalInconsistencyType(
                (row['tipo_inconsistencia'] ?? '').toString()))
            .toList();
      } catch (e) {
        _log('❌ [ERROR] Error fetching inconsistencias en rango: $e');
        return [];
      }
    }
  }

  Future<List<Inconsistencia>> getInconsistenciasByOficial(
    String oficialId, {
    bool soloAbiertas = false,
  }) async {
    final rows = await getInconsistenciasEnRango(
      fechaInicio: DateTime.now().subtract(const Duration(days: 90)),
      fechaFin: DateTime.now().add(const Duration(minutes: 1)),
      idOficial: oficialId,
      resuelta: soloAbiertas ? false : null,
      limit: 200,
    );
    return rows.map((json) => Inconsistencia.fromJson(json)).toList();
  }

  Future<bool> resolverInconsistencia(
    String id,
    String nuevoEstado,
    String adminNombre,
  ) async {
    try {
      await _supabase.from(AppConstants.tableInconsistencias).update({
        'estado': nuevoEstado,
        'resuelta': nuevoEstado == 'CERRADA',
        'resuelta_por': adminNombre,
        'fecha_resolucion': DateTime.now().toIso8601String(),
        'revisado_por': adminNombre,
        'fecha_revision': DateTime.now().toIso8601String(),
        if (nuevoEstado == 'CERRADA')
          'fecha_cierre': DateTime.now().toIso8601String(),
      }).eq('id_inconsistencia', id);

      _log('✅ Inconsistencia $id resuelta por $adminNombre');
      return true;
    } catch (e) {
      _log('❌ [ERROR] Error resolving inconsistencia $id: $e');
      return false;
    }
  }

  Future<bool> justificarInconsistencia(
    String id,
    String justificacion,
    String oficialNombre,
  ) async {
    try {
      await _supabase.from(AppConstants.tableInconsistencias).update({
        'justificacion_oficial': justificacion,
        'estado': 'JUSTIFICADA',
        'fecha_justificacion': DateTime.now().toIso8601String(),
      }).eq('id_inconsistencia', id);

      return true;
    } catch (e) {
      _log('❌ [ERROR] Error justificando inconsistencia $id: $e');
      return false;
    }
  }

  // ========================================
  // PARTES SORPRESA
  // ========================================

  Future<List<ParteSorpresa>> getPartesSorpresa({
    String? estado,
    int limit = 50,
  }) async {
    try {
      var query = _supabase.from(AppConstants.tablePartes).select();

      if (estado != null) {
        query = query.eq('estado', estado);
      }

      final response =
          await query.order('timestamp', ascending: false).limit(limit);

      return (response as List)
          .map((json) => ParteSorpresa.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching partes sorpresa: $e');
      return [];
    }
  }

  Future<List<ParteSorpresa>> getPartesByOficial(String oficialId) async {
    try {
      final response = await _supabase
          .from(AppConstants.tablePartes)
          .select()
          .eq('id_oficial', oficialId)
          .order('timestamp', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => ParteSorpresa.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching partes for oficial $oficialId: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getPartesOficialesEnRango({
    required DateTime fechaInicio,
    required DateTime fechaFin,
    String? idOficial,
    int limit = 10000,
  }) async {
    try {
      var query = _supabase.from(AppConstants.tablePartesOficiales).select();

      if (idOficial != null && idOficial.isNotEmpty) {
        query = query.eq('id_oficial', idOficial);
      }

      final response = await query
          .gte('timestamp', fechaInicio.toIso8601String())
          .lt('timestamp', fechaFin.toIso8601String())
          .order('timestamp', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      _log('❌ [ERROR] Error fetching partes oficiales en rango: $e');
      return [];
    }
  }

  Future<bool> crearParteSorpresa({
    required String idOficial,
    required String supervisorNombre,
    required String razon,
  }) async {
    try {
      final idSorpresa = 'PS_${DateTime.now().millisecondsSinceEpoch}';

      await _supabase.from(AppConstants.tablePartes).insert({
        'id_sorpresa': idSorpresa,
        'id_oficial': idOficial,
        'supervisor_nombre': supervisorNombre,
        'razon': razon,
        'estado': 'PENDIENTE',
        'timestamp': DateTime.now().toIso8601String(),
      });

      return true;
    } catch (e) {
      _log('❌ [ERROR] Error creando parte sorpresa: $e');
      return false;
    }
  }

  Future<bool> actualizarEstadoParte(
    String idSorpresa,
    String nuevoEstado, {
    String? respuestaOficial,
    double? latitud,
    double? longitud,
  }) async {
    try {
      final updates = <String, dynamic>{
        'estado': nuevoEstado,
      };

      if (nuevoEstado == 'LEIDO') {
        updates['fecha_lectura'] = DateTime.now().toIso8601String();
      } else if (nuevoEstado == 'COMPLETADO') {
        updates['fecha_completado'] = DateTime.now().toIso8601String();
        if (respuestaOficial != null) {
          updates['respuesta_oficial'] = respuestaOficial;
        }
        if (latitud != null) updates['latitud_respuesta'] = latitud;
        if (longitud != null) updates['longitud_respuesta'] = longitud;
      }

      await _supabase
          .from(AppConstants.tablePartes)
          .update(updates)
          .eq('id_sorpresa', idSorpresa);

      return true;
    } catch (e) {
      _log('❌ [ERROR] Error actualizando parte $idSorpresa: $e');
      return false;
    }
  }

  // ========================================
  // RADIO MENSAJES
  // ========================================

  Stream<List<RadioMessage>> watchRadioMessages({String? idOficial}) {
    final oficial = idOficial?.trim() ?? '';
    // NOTA: No usar .eq() encadenado sobre .stream() — en algunas versiones de
    // supabase_flutter el filtro se ignora silenciosamente. Se filtra en .map().
    return _supabase
        .from(AppConstants.tableRadioMensajes)
        .stream(primaryKey: ['id_mensaje'])
        .order('timestamp')
        .limit(200)
        .map((rows) {
          // Filtrar por id_oficial sobre el JSON crudo antes de parsear,
          // evitando el bug de .eq() encadenado en stream de supabase_flutter.
          final filtered = oficial.isEmpty
              ? rows
              : rows.where((json) {
                  final rowOficial =
                      (json['id_oficial'] ?? '').toString().trim();
                  final deUsuario = (json['de_usuario'] ?? '').toString();
                  final paraUsuario = (json['para_usuario'] ?? '').toString();
                  return rowOficial == oficial ||
                      deUsuario.contains(oficial) ||
                      paraUsuario.contains(oficial);
                }).toList();
          final items =
              filtered.map((json) => RadioMessage.fromJson(json)).toList();
          items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return items;
        });
  }

  Stream<List<RadioMessage>> watchSupervisorRadioInbox({int limit = 80}) {
    return _supabase
        .from(AppConstants.tableRadioMensajes)
        .stream(primaryKey: ['id_mensaje'])
        .order('timestamp')
        .limit(limit)
        .map((rows) {
          final items = rows
              .where((json) =>
                  (json['para_usuario'] ?? '')
                      .toString()
                      .trim()
                      .toUpperCase() ==
                  'SUPERVISOR')
              .map((json) => RadioMessage.fromJson(json))
              .toList();
          items.sort((a, b) => a.timestamp.compareTo(b.timestamp));
          return items;
        });
  }

  Future<bool> sendRadioMessage({
    required String idOficial,
    required String fromUser,
    required String toUser,
    required String message,
    String type = 'RADIO',
  }) async {
    final cleanIdOficial = idOficial.trim();
    final cleanFromUser = fromUser.trim();
    final cleanToUser = toUser.trim();
    final rawType = type.trim().toUpperCase();
    final cleanMessage = message.trim();
    if (cleanIdOficial.isEmpty ||
        cleanFromUser.isEmpty ||
        cleanToUser.isEmpty ||
        cleanMessage.isEmpty) {
      _log('⚠️ [WARN] sendRadioMessage rechazado por payload incompleto');
      return false;
    }

    try {
      final id =
          'RADIO_${cleanIdOficial}_${DateTime.now().millisecondsSinceEpoch}';
      await _supabase.from(AppConstants.tableRadioMensajes).insert({
        'id_mensaje': id,
        'id_oficial': cleanIdOficial,
        'de_usuario': cleanFromUser,
        'para_usuario': cleanToUser,
        'mensaje': cleanMessage,
        'tipo': rawType,
        'estado': 'NUEVO',
        'timestamp': DateTime.now().toIso8601String(),
      });
      return true;
    } catch (e) {
      final isTipoConstraintError = e is PostgrestException &&
          (e.code == '23514' || e.message.contains('radio_mensajes_tipo_chk'));
      if (isTipoConstraintError && rawType != 'RADIO') {
        try {
          final fallbackId =
              'RADIO_${cleanIdOficial}_${DateTime.now().millisecondsSinceEpoch}_FB';
          await _supabase.from(AppConstants.tableRadioMensajes).insert({
            'id_mensaje': fallbackId,
            'id_oficial': cleanIdOficial,
            'de_usuario': cleanFromUser,
            'para_usuario': cleanToUser,
            'mensaje': '[$rawType] $cleanMessage',
            'tipo': 'RADIO',
            'estado': 'NUEVO',
            'timestamp': DateTime.now().toIso8601String(),
          });
          _log(
            '⚠️ [WARN] Fallback aplicado por constraint tipo radio_mensajes: $rawType -> RADIO',
          );
          return true;
        } catch (fallbackError) {
          _log(
            '❌ [ERROR] Fallback RADIO también falló para tipo $rawType: $fallbackError',
          );
        }
      }
      _log('❌ [ERROR] Error sending radio message: $e');
      return false;
    }
  }

  Future<String?> uploadDtexReportPhoto({
    required String idMision,
    required String idOficial,
    required Uint8List bytes,
  }) async {
    final cleanMision = idMision.trim();
    final cleanOficial = idOficial.trim();
    if (cleanMision.isEmpty || cleanOficial.isEmpty || bytes.isEmpty) {
      _log('⚠️ [WARN] uploadDtexReportPhoto rechazado por payload incompleto');
      return null;
    }

    final path =
        '$cleanMision/$cleanOficial/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      await _supabase.storage.from('dtex-reportes').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'image/jpeg',
              upsert: true,
            ),
          );
      return _supabase.storage.from('dtex-reportes').getPublicUrl(path);
    } catch (e) {
      _log('❌ [ERROR] Error uploading DTEX report photo: $e');
      return null;
    }
  }

  Future<List<RadioMessage>> getSupervisorRadioInbox({int limit = 30}) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableRadioMensajes)
          .select()
          .eq('para_usuario', 'SUPERVISOR')
          .order('timestamp', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => RadioMessage.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching supervisor radio inbox: $e');
      return [];
    }
  }

  Future<List<RadioMessage>> getRadioMessagesByOficial({
    required String idOficial,
    DateTime? from,
    DateTime? to,
    int limit = 120,
  }) async {
    final cleanId = idOficial.trim();
    if (cleanId.isEmpty) return const <RadioMessage>[];
    try {
      var query = _supabase
          .from(AppConstants.tableRadioMensajes)
          .select()
          .eq('id_oficial', cleanId);

      if (from != null) {
        query = query.gte('timestamp', from.toIso8601String());
      }
      if (to != null) {
        query = query.lte('timestamp', to.toIso8601String());
      }

      final response =
          await query.order('timestamp', ascending: false).limit(limit);
      return (response as List)
          .map((json) => RadioMessage.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching radio messages by oficial: $e');
      return const <RadioMessage>[];
    }
  }

  Future<Map<String, dynamic>?> getActiveRadioCall({
    required String idOficial,
  }) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableRadioLlamadas)
          .select(
              'id_llamada, id_oficial, de_usuario, para_usuario, inicio_llamada')
          .eq('id_oficial', idOficial)
          .eq('estado', 'ACTIVA')
          .order('inicio_llamada', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;
      return Map<String, dynamic>.from(response);
    } catch (e) {
      _log('❌ [ERROR] Error fetching active radio call: $e');
      return null;
    }
  }

  Future<String?> startRadioCall({
    required String idOficial,
    required String fromUser,
    required String toUser,
  }) async {
    final existing = await getActiveRadioCall(idOficial: idOficial);
    if (existing != null) {
      final existingId = (existing['id_llamada'] ?? '').toString();
      if (existingId.isNotEmpty) return existingId;
    }

    final callId = 'CALL_${idOficial}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      var callLogged = false;
      try {
        await _supabase.from(AppConstants.tableRadioLlamadas).insert({
          'id_llamada': callId,
          'id_oficial': idOficial,
          'de_usuario': fromUser,
          'para_usuario': toUser,
          'estado': 'ACTIVA',
        });
        callLogged = true;
      } catch (e) {
        _log(
          '⚠️ [WARN] Bitácora radio_llamadas no disponible para start call ($callId): $e',
        );
      }

      var startEventSent = await sendRadioMessage(
        idOficial: idOficial,
        fromUser: fromUser,
        toUser: toUser,
        message: 'INICIO CONTACTO RADIO (SIN AUDIO EN VIVO)',
        type: 'CALL_START',
      );
      if (!startEventSent) {
        // Fallback defensivo para esquemas antiguos con CHECK en tipo.
        startEventSent = await sendRadioMessage(
          idOficial: idOficial,
          fromUser: fromUser,
          toUser: toUser,
          message: 'INICIO CONTACTO RADIO (SIN AUDIO EN VIVO)',
          type: 'RADIO',
        );
      }

      if (!startEventSent) {
        if (callLogged) {
          await _supabase.from(AppConstants.tableRadioLlamadas).update({
            'estado': 'CANCELADA',
            'resumen': 'FALLO_EVENTO_CALL_START',
          }).eq('id_llamada', callId);
        }
        _log(
          '❌ [ERROR] startRadioCall cancelada: no se publicó CALL_START en radio_mensajes',
        );
        return null;
      }
      return callId;
    } catch (e) {
      _log('❌ [ERROR] Error starting radio call (log obligatorio): $e');
      return null;
    }
  }

  Future<bool> endRadioCall({
    required String callId,
    required String idOficial,
    required String fromUser,
    required String toUser,
    String? resumen,
  }) async {
    final cleanResumen = resumen?.trim();
    final endMessage = cleanResumen == null || cleanResumen.isEmpty
        ? 'FIN CONTACTO RADIO'
        : 'FIN CONTACTO RADIO | $cleanResumen';

    try {
      try {
        final row = await _supabase
            .from(AppConstants.tableRadioLlamadas)
            .select('inicio_llamada, estado')
            .eq('id_llamada', callId)
            .maybeSingle();

        if (row != null) {
          final status = (row['estado'] ?? '').toString().toUpperCase();
          if (status == 'ACTIVA') {
            final now = DateTime.now();
            final startedAt =
                DateTime.tryParse((row['inicio_llamada'] ?? '').toString()) ??
                    now;
            final duration =
                now.difference(startedAt).inSeconds.clamp(0, 86400);

            await _supabase.from(AppConstants.tableRadioLlamadas).update({
              'fin_llamada': now.toIso8601String(),
              'duracion_segundos': duration,
              'estado': 'FINALIZADA',
              if (cleanResumen != null && cleanResumen.isNotEmpty)
                'resumen': cleanResumen,
            }).eq('id_llamada', callId);
          }
        } else {
          _log('⚠️ [WARN] endRadioCall sin bitácora local: $callId');
        }
      } catch (e) {
        _log('⚠️ [WARN] endRadioCall bitácora no disponible: $e');
      }

      var endEventSent = await sendRadioMessage(
        idOficial: idOficial,
        fromUser: fromUser,
        toUser: toUser,
        message: endMessage,
        type: 'CALL_END',
      );
      if (!endEventSent) {
        endEventSent = await sendRadioMessage(
          idOficial: idOficial,
          fromUser: fromUser,
          toUser: toUser,
          message: endMessage,
          type: 'RADIO',
        );
      }
      if (!endEventSent) {
        _log(
          '❌ [ERROR] endRadioCall cerrada en bitácora pero sin evento CALL_END',
        );
        return false;
      }
      return true;
    } catch (e) {
      _log('❌ [ERROR] Error ending radio call (log obligatorio): $e');
      return false;
    }
  }

  Future<void> markRadioMessageRead(String idMensaje) async {
    try {
      await _supabase.from(AppConstants.tableRadioMensajes).update({
        'estado': 'LEIDO',
      }).eq('id_mensaje', idMensaje);
    } catch (e) {
      _log('❌ [ERROR] Error marking radio message as read: $e');
    }
  }

  // ========================================
  // ADMINISTRADORES
  // ========================================

  Future<AllowedAdmin?> getAdminByEmail(String email) async {
    try {
      final normalized = email.trim().toLowerCase();
      if (normalized.isEmpty) return null;
      final response = await _supabase
          .from(AppConstants.tableAdmins)
          .select('id, email, nombre, nivel_acceso, activo, created_at, '
              'updated_at, ultimo_login')
          .ilike('email', normalized)
          .eq('activo', true)
          .maybeSingle();

      if (response == null) return null;
      return AllowedAdmin.fromJson(response);
    } catch (e) {
      _log('❌ [ERROR] Error fetching admin $email: $e');
      return null;
    }
  }

  Future<bool> verificarPinAdmin(String email, String pin) async {
    final normalizedEmail = email.trim().toLowerCase();
    final cleanPin = pin.trim();
    if (normalizedEmail.isEmpty || cleanPin.isEmpty) {
      return false;
    }

    try {
      final rpcResponse = await _supabase.rpc(
        _verifyAdminPinRpc,
        params: {
          'p_email': normalizedEmail,
          'p_pin': cleanPin,
        },
      );
      if (rpcResponse is bool) {
        return rpcResponse;
      }
      if (rpcResponse is Map<String, dynamic>) {
        if (rpcResponse['ok'] is bool) {
          return rpcResponse['ok'] as bool;
        }
        if (rpcResponse['valid'] is bool) {
          return rpcResponse['valid'] as bool;
        }
      }
    } catch (e) {
      _log('❌ [SECURITY] RPC $_verifyAdminPinRpc no disponible: $e');
      _log('⛔ [SECURITY] Verificación PIN bloqueada (sin fallback inseguro)');
      return false;
    }

    _log('❌ [SECURITY] Respuesta inválida de $_verifyAdminPinRpc');
    return false;
  }

  Future<bool> actualizarPinAdmin({
    required String adminId,
    required String nuevoPin,
  }) async {
    final id = adminId.trim();
    final pin = nuevoPin.trim();
    if (id.isEmpty || pin.isEmpty) return false;

    try {
      final rpcResponse = await _supabase.rpc(
        _updateAdminPinRpc,
        params: {
          'p_admin_id': id,
          'p_new_pin': pin,
        },
      );

      if (rpcResponse is bool) {
        return rpcResponse;
      }
      if (rpcResponse is Map<String, dynamic>) {
        if (rpcResponse['ok'] is bool) {
          return rpcResponse['ok'] as bool;
        }
        if (rpcResponse['updated'] is bool) {
          return rpcResponse['updated'] as bool;
        }
      }

      _log('❌ [SECURITY] Respuesta inválida de $_updateAdminPinRpc');
      return false;
    } catch (e) {
      _log('❌ [SECURITY] RPC $_updateAdminPinRpc no disponible: $e');
      _log('⛔ [SECURITY] Cambio de PIN bloqueado (sin update directo)');
      return false;
    }
  }

  Future<bool> actualizarUltimoLogin(String adminId) async {
    try {
      await _supabase.from(AppConstants.tableAdmins).update({
        'ultimo_login': DateTime.now().toIso8601String(),
      }).eq('id', adminId);

      return true;
    } catch (e) {
      _log('❌ [ERROR] Error actualizando último login: $e');
      return false;
    }
  }

  Future<bool> registrarLoginLog({
    required String adminEmail,
    String? adminNombre,
    required String status,
  }) async {
    final normalizedEmail = adminEmail.trim().toLowerCase();
    final normalizedStatus = status.trim().toLowerCase();
    if (normalizedEmail.isEmpty || normalizedStatus.isEmpty) {
      return false;
    }

    try {
      await _supabase.from(AppConstants.tableLoginLogs).insert({
        'admin_email': normalizedEmail,
        'admin_nombre':
            adminNombre?.trim().isEmpty == true ? null : adminNombre?.trim(),
        'status': normalizedStatus,
        'timestamp': DateTime.now().toIso8601String(),
        'actor_tipo': 'ADMIN',
        'metadata': {'source': 'webapp_auth'},
      });
      return true;
    } catch (e) {
      _log('❌ [ERROR] Error registrando login_log ($status): $e');
      try {
        // Compatibilidad con esquemas legacy sin columnas extendidas.
        await _supabase.from(AppConstants.tableLoginLogs).insert({
          'admin_email': normalizedEmail,
          'admin_nombre':
              adminNombre?.trim().isEmpty == true ? null : adminNombre?.trim(),
          'status': normalizedStatus,
          'timestamp': DateTime.now().toIso8601String(),
        });
        return true;
      } catch (inner) {
        _log('❌ [ERROR] Fallback login_log también falló ($status): $inner');
        return false;
      }
    }
  }

  Future<bool> cerrarSesionLogActiva({
    required String adminEmail,
  }) async {
    final normalizedEmail = adminEmail.trim().toLowerCase();
    if (normalizedEmail.isEmpty) return false;

    try {
      final now = DateTime.now();
      final recentRows = await _supabase
          .from(AppConstants.tableLoginLogs)
          .select('id_log, timestamp, status')
          .eq('admin_email', normalizedEmail)
          .order('timestamp', ascending: false)
          .limit(20);

      Map<String, dynamic>? active;
      for (final row in (recentRows as List).cast<Map<String, dynamic>>()) {
        final st = (row['status'] ?? '').toString().trim().toLowerCase();
        if (st == 'active') {
          active = row;
          break;
        }
      }

      if (active == null) {
        return registrarLoginLog(
          adminEmail: normalizedEmail,
          status: 'logout',
        );
      }

      final openedAtRaw = active['timestamp']?.toString();
      final openedAt =
          openedAtRaw == null ? now : DateTime.tryParse(openedAtRaw) ?? now;
      final duration = now.difference(openedAt).inMinutes.clamp(0, 1000000);

      await _supabase.from(AppConstants.tableLoginLogs).update({
        'status': 'logout',
        'duracion_minutos': duration,
      }).eq('id_log', active['id_log']);
      return true;
    } catch (e) {
      _log('❌ [ERROR] Error cerrando login_log activo: $e');
      return false;
    }
  }

  // ========================================
  // REALTIME SUBSCRIPTIONS
  // ========================================

  Stream<List<MonitoreoReporte>> watchReportes() {
    return _supabase
        .from(AppConstants.tableMonitoreo)
        .stream(primaryKey: ['id_reporte'])
        .order('fecha_hora', ascending: false)
        .limit(100)
        .map((data) =>
            data.map((json) => MonitoreoReporte.fromJson(json)).toList());
  }

  Stream<List<Inconsistencia>> watchInconsistencias() {
    return _supabase
        .from(AppConstants.tableInconsistencias)
        .stream(primaryKey: ['id_inconsistencia'])
        .order('fecha_deteccion', ascending: false)
        .limit(120)
        .map((data) => data
            .where((json) => json['resuelta'] != true)
            .where((json) => _isLogicalInconsistencyType(
                (json['tipo_inconsistencia'] ?? '').toString()))
            .map((json) => Inconsistencia.fromJson(json))
            .toList());
  }

  Stream<List<ParteSorpresa>> watchPartesPendientes() {
    return _supabase
        .from(AppConstants.tablePartes)
        .stream(primaryKey: ['id_sorpresa'])
        .order('timestamp', ascending: false)
        .map((data) => data
            .map((json) => ParteSorpresa.fromJson(json))
            .where((parte) =>
                parte.estadoNormalized == 'NUEVO' ||
                parte.estadoNormalized == 'PENDIENTE' ||
                parte.estadoNormalized == 'LEIDO')
            .toList());
  }

  // ========================================
  // COMANDANTE - HISTORIAL / ESTADISTICAS / MODO ESPIA
  // ========================================

  Future<List<MonitoreoReporte>> getHistorialRecorrido({
    required String idOficial,
    required DateTime fechaInicio,
    required DateTime fechaFin,
    int limit = 2000,
  }) async {
    try {
      final response = await _supabase
          .from(AppConstants.tableMonitoreo)
          .select()
          .eq('id_oficial_ref', idOficial)
          .gte('fecha_hora', fechaInicio.toIso8601String())
          .lte('fecha_hora', fechaFin.toIso8601String())
          .order('fecha_hora', ascending: true)
          .limit(limit);

      return (response as List)
          .map((json) => MonitoreoReporte.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [ERROR] Error fetching historial recorrido: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getEstadisticasAvanzadas({
    String? grupo,
    String? idOficial,
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    final start =
        fechaInicio ?? DateTime.now().subtract(const Duration(days: 7));
    final end = fechaFin ?? DateTime.now();

    try {
      final rpcResponse = await _supabase.rpc(
        'fn_commander_stats_advanced',
        params: {
          'p_grupo': grupo,
          'p_oficial': idOficial,
          'p_fecha_inicio': start.toIso8601String(),
          'p_fecha_fin': end.toIso8601String(),
        },
      );

      if (rpcResponse is Map<String, dynamic>) {
        return rpcResponse;
      }
    } catch (e) {
      _log('⚠️ [WARN] RPC fn_commander_stats_advanced no disponible: $e');
    }

    try {
      var query = _supabase.from(AppConstants.tableMonitoreo).select(
          'id_oficial_ref, estado_alerta, distancia_metros, nivel_bateria, fecha_hora, grupo');

      if (grupo != null && grupo.isNotEmpty) {
        query = query.eq('grupo', grupo);
      }
      if (idOficial != null && idOficial.isNotEmpty) {
        query = query.eq('id_oficial_ref', idOficial);
      }

      final rows = await query
          .gte('fecha_hora', start.toIso8601String())
          .lte('fecha_hora', end.toIso8601String())
          .limit(5000);

      final data = (rows as List).cast<Map<String, dynamic>>();
      final total = data.length;
      final alertas = data
          .where((r) => (r['estado_alerta'] ?? 'NORMAL') != 'NORMAL')
          .length;
      final distanciaPromedio = total == 0
          ? 0.0
          : data
                  .map(
                      (r) => (r['distancia_metros'] as num?)?.toDouble() ?? 0.0)
                  .reduce((a, b) => a + b) /
              total;
      final bateriaPromedio = total == 0
          ? 0.0
          : data
                  .map((r) => (r['nivel_bateria'] as num?)?.toDouble() ?? 0.0)
                  .reduce((a, b) => a + b) /
              total;

      return {
        'source': 'fallback_query',
        'periodo': {
          'inicio': start.toIso8601String(),
          'fin': end.toIso8601String(),
        },
        'kpis': {
          'total_reportes': total,
          'total_alertas': alertas,
          'distancia_promedio': distanciaPromedio,
          'bateria_promedio': bateriaPromedio,
        },
      };
    } catch (e) {
      _log('❌ [ERROR] Error calculating estadísticas avanzadas fallback: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> generarInformeGlobal({
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      final response = await _supabase.rpc(
        'fn_commander_generate_report_global',
        params: {
          'p_fecha_inicio': fechaInicio.toIso8601String(),
          'p_fecha_fin': fechaFin.toIso8601String(),
        },
      );
      if (response is Map<String, dynamic>) return response;
      return {'data': response};
    } catch (e) {
      _log('❌ [ERROR] Error generating global report: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> generarInformeGrupo({
    required String grupo,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      final response = await _supabase.rpc(
        'fn_commander_generate_report_group',
        params: {
          'p_grupo': grupo,
          'p_fecha_inicio': fechaInicio.toIso8601String(),
          'p_fecha_fin': fechaFin.toIso8601String(),
        },
      );
      if (response is Map<String, dynamic>) return response;
      return {'data': response};
    } catch (e) {
      _log('❌ [ERROR] Error generating group report: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> generarInformeOficial({
    required String idOficial,
    required DateTime fechaInicio,
    required DateTime fechaFin,
  }) async {
    try {
      final response = await _supabase.rpc(
        'fn_commander_generate_report_officer',
        params: {
          'p_oficial': idOficial,
          'p_fecha_inicio': fechaInicio.toIso8601String(),
          'p_fecha_fin': fechaFin.toIso8601String(),
        },
      );
      if (response is Map<String, dynamic>) return response;
      return {'data': response};
    } catch (e) {
      _log('❌ [ERROR] Error generating officer report: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> ejecutarModoEspia({
    required String idOficial,
    required String motivo,
  }) async {
    try {
      final response = await _supabase.rpc(
        'fn_commander_spy_mode',
        params: {
          'p_id_oficial': idOficial,
          'p_motivo': motivo,
        },
      );
      if (response is Map<String, dynamic>) return response;
      return {'data': response};
    } catch (e) {
      _log('❌ [ERROR] Error ejecutando modo espía: $e');
      return {};
    }
  }

  Future<Map<String, dynamic>> eliminarDatosTabla({
    required String tabla,
    required String condicionSql,
  }) async {
    final normalizedTable = _normalizeIdentifier(tabla);
    final safeWhereClause = condicionSql.trim();
    if (!_isSafeCommanderDeleteRequest(
      table: normalizedTable,
      whereClause: safeWhereClause,
    )) {
      _log(
        '⚠️ [WARN] eliminarDatosTabla bloqueado por validación local '
        '(table=$normalizedTable)',
      );
      return {
        'ok': false,
        'error': 'Solicitud de borrado no permitida por validación local',
      };
    }

    try {
      final response = await _supabase.rpc(
        'fn_commander_delete_data',
        params: {
          'p_table': normalizedTable,
          'p_where_clause': safeWhereClause,
        },
      );
      if (response is Map<String, dynamic>) return response;
      return {'data': response};
    } catch (e) {
      _log('❌ [ERROR] Error en borrado controlado: $e');
      return {};
    }
  }
}
