// ─── DtexTrackingPunto ───────────────────────────────────────────────────────
// Representa un punto GPS capturado cada 5 segundos durante la misión.

class DtexTrackingPunto {
  final String idPunto;
  final String idMision;
  final DateTime ts;
  final double latitud;
  final double longitud;
  final double? precisionM;
  final double? velocidadMs;
  final double? rumbo;
  final double? altitud;
  final int? bateriaPct;
  final bool gpsActivo;

  DtexTrackingPunto({
    required this.idPunto,
    required this.idMision,
    required this.ts,
    required this.latitud,
    required this.longitud,
    this.precisionM,
    this.velocidadMs,
    this.rumbo,
    this.altitud,
    this.bateriaPct,
    this.gpsActivo = true,
  });

  factory DtexTrackingPunto.fromJson(Map<String, dynamic> json) {
    return DtexTrackingPunto(
      idPunto:     json['id_punto']?.toString() ?? '',
      idMision:    json['id_mision']?.toString() ?? '',
      ts:          DateTime.parse(json['ts']),
      latitud:     (json['latitud'] as num).toDouble(),
      longitud:    (json['longitud'] as num).toDouble(),
      precisionM:  json['precision_m'] != null ? (json['precision_m'] as num).toDouble() : null,
      velocidadMs: json['velocidad_ms'] != null ? (json['velocidad_ms'] as num).toDouble() : null,
      rumbo:       json['rumbo'] != null ? (json['rumbo'] as num).toDouble() : null,
      altitud:     json['altitud'] != null ? (json['altitud'] as num).toDouble() : null,
      bateriaPct:  json['bateria_pct'],
      gpsActivo:   json['gps_activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_mision':    idMision,
      'latitud':      latitud,
      'longitud':     longitud,
      'precision_m':  precisionM,
      'velocidad_ms': velocidadMs,
      'rumbo':        rumbo,
      'altitud':      altitud,
      'bateria_pct':  bateriaPct,
      'gps_activo':   gpsActivo,
    };
  }

  // El dispositivo está detenido si velocidad < 0.5 m/s (~1.8 km/h)
  bool get estaDetenido => velocidadMs != null ? velocidadMs! < 0.5 : false;

  bool get bateriaOk      => bateriaPct == null || bateriaPct! > 15;
  bool get bateriaCritica => bateriaPct != null && bateriaPct! <= 15;
}


// ─── DtexExtension ───────────────────────────────────────────────────────────
// Solicitud de tiempo adicional en el destino enviada por el custodio.

class DtexExtension {
  final String idExtension;
  final String idMision;
  final DateTime tsSolicitud;
  final int minutosSolicitados;
  final String motivo;
  final String estado;
  final String? respondidoPor;
  final DateTime? tsRespuesta;

  DtexExtension({
    required this.idExtension,
    required this.idMision,
    required this.tsSolicitud,
    required this.minutosSolicitados,
    required this.motivo,
    this.estado = 'PENDIENTE',
    this.respondidoPor,
    this.tsRespuesta,
  });

  factory DtexExtension.fromJson(Map<String, dynamic> json) {
    return DtexExtension(
      idExtension:         json['id_extension']?.toString() ?? '',
      idMision:            json['id_mision']?.toString() ?? '',
      tsSolicitud:         DateTime.parse(json['ts_solicitud']),
      minutosSolicitados:  json['minutos_solicitados'] ?? 0,
      motivo:              json['motivo']?.toString() ?? '',
      estado:              json['estado']?.toString() ?? 'PENDIENTE',
      respondidoPor:       json['respondido_por']?.toString(),
      tsRespuesta:         json['ts_respuesta'] != null ? DateTime.parse(json['ts_respuesta']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_mision':            idMision,
      'minutos_solicitados':  minutosSolicitados,
      'motivo':               motivo,
      'estado':               estado,
    };
  }

  bool get isPendiente  => estado == 'PENDIENTE';
  bool get isAprobada   => estado == 'APROBADA';
  bool get isRechazada  => estado == 'RECHAZADA';
}
