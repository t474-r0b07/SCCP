import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../models/dtex_destino_model.dart';
import '../models/dtex_mision_model.dart';
import '../models/dtex_alerta_model.dart';
import '../models/dtex_tracking_extension_model.dart';

class DtexRepository {
  final _supabase = Supabase.instance.client;

  void _log(String message) {
    if (kDebugMode) {
      debugPrint(message);
    }
  }

  // ========================================
  // DESTINOS
  // ========================================

  Future<List<DtexDestino>> getDestinos() async {
    try {
      final response = await _supabase
          .from('dtex_destinos')
          .select()
          .eq('activo', true)
          .order('nombre', ascending: true);

      return (response as List)
          .map((json) => DtexDestino.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [DTEX] Error fetching destinos: $e');
      return [];
    }
  }

  Future<DtexDestino?> getDestinoById(String idDestino) async {
    try {
      final response = await _supabase
          .from('dtex_destinos')
          .select()
          .eq('id_destino', idDestino)
          .maybeSingle();

      if (response == null) return null;
      return DtexDestino.fromJson(response);
    } catch (e) {
      _log('❌ [DTEX] Error fetching destino $idDestino: $e');
      return null;
    }
  }

  // ========================================
  // MISIONES
  // ========================================

  Future<List<DtexMision>> getMisiones({
    String? estado,
    int limit = 100,
  }) async {
    try {
      var query = _supabase.from('dtex_misiones').select();

      if (estado != null && estado.isNotEmpty) {
        query = query.eq('estado', estado);
      }

      final response = await query
          .order('hora_salida_autorizada', ascending: false)
          .limit(limit);
      return (response as List)
          .map((json) => DtexMision.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [DTEX] Error fetching misiones: $e');
      return [];
    }
  }

  Future<List<DtexMision>> getMisionesActivas() async {
    try {
      final response = await _supabase
          .from('dtex_misiones')
          .select()
          .inFilter('estado', DtexMision.estadosActivos.toList())
          .order('ts_inicio_real', ascending: false);

      return (response as List)
          .map((json) => DtexMision.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [DTEX] Error fetching misiones activas: $e');
      return [];
    }
  }

  Future<DtexMision?> getMisionById(String idMision) async {
    try {
      final response = await _supabase
          .from('dtex_misiones')
          .select()
          .eq('id_mision', idMision)
          .single();

      return DtexMision.fromJson(response);
    } catch (e) {
      _log('❌ [DTEX] Error fetching misión $idMision: $e');
      return null;
    }
  }

  /// Crea una misión nueva y retorna su id.
  /// El código OTP se genera aquí: 6 dígitos aleatorios.
  Future<String?> crearMision(DtexMision mision) async {
    try {
      final otp = _generarOtp();
      final data = mision.toJson()
        ..['codigo_otp'] = otp
        ..['estado'] = DtexMision.estadoAbierta;

      final response = await _supabase
          .from('dtex_misiones')
          .insert(data)
          .select('id_mision, codigo_otp')
          .single();

      _log(
          '✅ [DTEX] Misión creada: ${response['id_mision']} OTP: ${response['codigo_otp']}');
      return response['id_mision']?.toString();
    } catch (e) {
      _log('❌ [DTEX] Error creando misión: $e');
      return null;
    }
  }

  /// Obtiene el OTP de una misión recién creada para mostrárselo al supervisor.
  Future<String?> getOtpDeMision(String idMision) async {
    try {
      final response = await _supabase
          .from('dtex_misiones')
          .select('codigo_otp')
          .eq('id_mision', idMision)
          .single();

      return response['codigo_otp']?.toString();
    } catch (e) {
      _log('❌ [DTEX] Error obteniendo OTP: $e');
      return null;
    }
  }

  Future<bool> cancelarMision(String idMision) async {
    try {
      await _supabase
          .from('dtex_misiones')
          .update({
            'estado': DtexMision.estadoCancelada,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id_mision', idMision)
          .eq(
              'estado',
              DtexMision
                  .estadoAbierta); // solo se puede cancelar si está pendiente

      return true;
    } catch (e) {
      _log('❌ [DTEX] Error cancelando misión: $e');
      return false;
    }
  }

  Future<bool> cerrarMisionConConducta({
    required String idMision,
    required String conductaFinal,
  }) async {
    try {
      final conducta = conductaFinal.trim().toUpperCase();
      if (!DtexMision.conductaFinalValida(conducta)) {
        _log('❌ [DTEX] Conducta final no permitida: $conductaFinal');
        return false;
      }

      await _supabase.from('dtex_misiones').update({
        'estado': DtexMision.estadoCompletada,
        'conducta_final': conducta,
        'ts_cierre': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id_mision', idMision);

      return true;
    } catch (e) {
      _log('❌ [DTEX] Error cerrando misión con conducta: $e');
      return false;
    }
  }

  // ========================================
  // TRACKING GPS
  // ========================================

  /// Obtiene los últimos N puntos GPS de una misión activa.
  Future<List<DtexTrackingPunto>> getTrackingMision({
    required String idMision,
    int limit = 500,
  }) async {
    try {
      final response = await _supabase
          .from('dtex_tracking_gps')
          .select()
          .eq('id_mision', idMision)
          .order('ts', ascending: true)
          .limit(limit);

      return (response as List)
          .map((json) => DtexTrackingPunto.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [DTEX] Error fetching tracking $idMision: $e');
      return [];
    }
  }

  /// Obtiene el último punto GPS conocido de una misión.
  Future<DtexTrackingPunto?> getUltimaPosicion(String idMision) async {
    try {
      final response = await _supabase
          .from('dtex_tracking_gps')
          .select()
          .eq('id_mision', idMision)
          .order('ts', ascending: false)
          .limit(1)
          .single();

      return DtexTrackingPunto.fromJson(response);
    } catch (e) {
      _log('❌ [DTEX] Error fetching última posición: $e');
      return null;
    }
  }

  // ========================================
  // ALERTAS
  // ========================================

  Future<List<DtexAlerta>> getAlertasMision(String idMision) async {
    try {
      final response = await _supabase
          .from('dtex_alertas')
          .select()
          .eq('id_mision', idMision)
          .order('ts', ascending: false);

      return (response as List)
          .map((json) => DtexAlerta.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [DTEX] Error fetching alertas $idMision: $e');
      return [];
    }
  }

  Future<List<DtexAlerta>> getAlertasPendientes() async {
    try {
      final response = await _supabase
          .from('dtex_alertas')
          .select()
          .eq('resuelta', false)
          .inFilter('severidad', ['AVISO', 'EMERGENCIA'])
          .order('ts', ascending: false)
          .limit(50);

      return (response as List)
          .map((json) => DtexAlerta.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [DTEX] Error fetching alertas pendientes: $e');
      return [];
    }
  }

  Future<bool> resolverAlerta({
    required String idAlerta,
    required String resueltaPor,
    String? nota,
  }) async {
    try {
      await _supabase.from('dtex_alertas').update({
        'resuelta': true,
        'resuelta_por': resueltaPor,
        'resolucion_nota': nota,
        'resuelta_at': DateTime.now().toIso8601String(),
      }).eq('id_alerta', idAlerta);

      return true;
    } catch (e) {
      _log('❌ [DTEX] Error resolviendo alerta: $e');
      return false;
    }
  }

  Future<bool> insertarAlerta({
    required String idMision,
    required String tipo,
    required String severidad,
    required String descripcion,
    double? latitud,
    double? longitud,
  }) async {
    try {
      await _supabase.rpc('dtex_insertar_alerta', params: {
        'p_id_mision': idMision,
        'p_tipo': tipo,
        'p_severidad': severidad,
        'p_descripcion': descripcion,
        'p_latitud': latitud,
        'p_longitud': longitud,
      });
      return true;
    } catch (e) {
      _log('❌ [DTEX] Error insertando alerta $tipo: $e');
      return false;
    }
  }

  // ========================================
  // EXTENSIONES
  // ========================================

  Future<List<DtexExtension>> getExtensionsPendientes() async {
    try {
      final response = await _supabase
          .from('dtex_extensiones')
          .select()
          .eq('estado', 'PENDIENTE')
          .order('ts_solicitud', ascending: true);

      return (response as List)
          .map((json) => DtexExtension.fromJson(json))
          .toList();
    } catch (e) {
      _log('❌ [DTEX] Error fetching extensiones pendientes: $e');
      return [];
    }
  }

  Future<bool> responderExtension({
    required String idExtension,
    required bool aprobada,
    required String respondidoPor,
  }) async {
    try {
      final nuevoEstado = aprobada ? 'APROBADA' : 'RECHAZADA';

      await _supabase.from('dtex_extensiones').update({
        'estado': nuevoEstado,
        'respondido_por': respondidoPor,
        'ts_respuesta': DateTime.now().toIso8601String(),
      }).eq('id_extension', idExtension);

      // Registrar como alerta informativa
      if (aprobada) {
        final ext = await _supabase
            .from('dtex_extensiones')
            .select('id_mision, minutos_solicitados')
            .eq('id_extension', idExtension)
            .single();

        await _supabase.rpc('dtex_insertar_alerta', params: {
          'p_id_mision': ext['id_mision'],
          'p_tipo': 'EXTENSION_APROBADA',
          'p_severidad': 'INFO',
          'p_descripcion':
              'Extensión de ${ext['minutos_solicitados']} min aprobada por $respondidoPor',
        });
      }

      return true;
    } catch (e) {
      _log('❌ [DTEX] Error respondiendo extensión: $e');
      return false;
    }
  }

  // ========================================
  // RPCs
  // ========================================

  /// Valida el OTP ingresado por el custodio y retorna los datos de la misión.
  /// Usado desde la app móvil.
  Future<Map<String, dynamic>> validarOtp(String codigo) async {
    try {
      final response = await _supabase.rpc(
        'dtex_validar_otp',
        params: {'p_codigo': codigo},
      );

      if (response is Map<String, dynamic>) return response;
      if (response is List && response.isNotEmpty) {
        final first = response.first;
        if (first is Map<String, dynamic>) {
          return {'ok': true, 'mision': first};
        }
      }
      return {'ok': false, 'error': 'Respuesta inesperada del servidor'};
    } catch (e) {
      _log('❌ [DTEX] Error validando OTP: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Valida el acceso de la app Android custodio con nombre + codigo de
  /// seguridad de la mision. No depende de QR por mision.
  Future<Map<String, dynamic>> validarAccesoCustodio({
    required String nombre,
    required String codigo,
  }) async {
    try {
      final response = await _supabase.rpc(
        'dtex_validar_acceso_custodio',
        params: {
          'p_nombre': nombre,
          'p_codigo': codigo,
        },
      );

      if (response is Map<String, dynamic>) return response;
      return {'ok': false, 'error': 'Respuesta inesperada del servidor'};
    } catch (e) {
      _log('❌ [DTEX] Error validando acceso custodio: $e');
      return {'ok': false, 'error': e.toString()};
    }
  }

  /// Cambia el estado de una misión desde la app del custodio.
  Future<bool> cambiarEstadoMision({
    required String idMision,
    required String estado,
    double? lat,
    double? lng,
  }) async {
    try {
      final response = await _supabase.rpc(
        'dtex_cambiar_estado',
        params: {
          'p_id_mision': idMision,
          'p_estado': estado,
          'p_lat': lat,
          'p_lng': lng,
        },
      );

      if (response is Map<String, dynamic>) {
        return response['ok'] == true;
      }
      return false;
    } catch (e) {
      _log('❌ [DTEX] Error cambiando estado misión: $e');
      return false;
    }
  }

  Future<bool> reportarTrackingGps({
    required String idMision,
    required double lat,
    required double lng,
    double? precisionM,
    double? velocidadMs,
    double? rumbo,
    double? altitud,
    int? bateriaPct,
    bool gpsActivo = true,
  }) async {
    try {
      final response =
          await _supabase.rpc('dtex_reportar_tracking_gps', params: {
        'p_id_mision': idMision,
        'p_lat': lat,
        'p_lng': lng,
        'p_precision_m': precisionM,
        'p_velocidad_ms': velocidadMs,
        'p_rumbo': rumbo,
        'p_altitud': altitud,
        'p_bateria_pct': bateriaPct,
        'p_gps_activo': gpsActivo,
      });

      if (response is Map<String, dynamic>) {
        return response['ok'] == true;
      }
      if (response is bool) return response;
      return false;
    } catch (e) {
      _log('❌ [DTEX] Error reportando GPS: $e');
      return false;
    }
  }

  // ========================================
  // REALTIME STREAMS
  // ========================================

  /// Stream de misiones activas — el dashboard DTEX se actualiza en tiempo real.
  Stream<List<DtexMision>> watchMisionesActivas() {
    return _supabase
        .from('dtex_misiones')
        .stream(primaryKey: ['id_mision'])
        .order('hora_salida_autorizada', ascending: false)
        .limit(50)
        .map((data) => data
            .where((json) => DtexMision.estadosActivos.contains(
                  json['estado']?.toString().trim().toUpperCase(),
                ))
            .map((json) => DtexMision.fromJson(json))
            .toList());
  }

  /// Stream de alertas sin resolver — para el panel de alertas en tiempo real.
  Stream<List<DtexAlerta>> watchAlertasPendientes() {
    return _supabase
        .from('dtex_alertas')
        .stream(primaryKey: ['id_alerta'])
        .order('ts', ascending: false)
        .limit(30)
        .map((data) => data
            .where((json) => json['resuelta'] != true)
            .map((json) => DtexAlerta.fromJson(json))
            .toList());
  }

  /// Stream del tracking GPS de una misión específica — para el mapa en vivo.
  Stream<List<DtexTrackingPunto>> watchTracking(String idMision) {
    return _supabase
        .from('dtex_tracking_gps')
        .stream(primaryKey: ['id_punto'])
        .eq('id_mision', idMision)
        .order('ts', ascending: true)
        .limit(1000)
        .map((data) =>
            data.map((json) => DtexTrackingPunto.fromJson(json)).toList());
  }

  /// Stream de extensiones pendientes de respuesta.
  Stream<List<DtexExtension>> watchExtensionsPendientes() {
    return _supabase
        .from('dtex_extensiones')
        .stream(primaryKey: ['id_extension'])
        .eq('estado', 'PENDIENTE')
        .order('ts_solicitud', ascending: true)
        .map((data) =>
            data.map((json) => DtexExtension.fromJson(json)).toList());
  }

  // ========================================
  // UTILIDADES PRIVADAS
  // ========================================

  /// Genera un OTP de 6 dígitos aleatorio.
  String _generarOtp() {
    final rng = Random.secure();
    final base = rng.nextInt(900000) + 100000; // siempre 6 digitos
    return base.toString();
  }
}
