class DtexAlerta {
  final String idAlerta;
  final String idMision;
  final DateTime ts;
  final String tipo;
  final String severidad;
  final double? latitud;
  final double? longitud;
  final String descripcion;
  final bool resuelta;
  final String? resueltaPor;
  final String? resolucionNota;
  final DateTime? resueltaAt;

  DtexAlerta({
    required this.idAlerta,
    required this.idMision,
    required this.ts,
    required this.tipo,
    required this.severidad,
    this.latitud,
    this.longitud,
    required this.descripcion,
    this.resuelta = false,
    this.resueltaPor,
    this.resolucionNota,
    this.resueltaAt,
  });

  factory DtexAlerta.fromJson(Map<String, dynamic> json) {
    return DtexAlerta(
      idAlerta: json['id_alerta']?.toString() ?? '',
      idMision: json['id_mision']?.toString() ?? '',
      ts: DateTime.parse(json['ts']),
      tipo: json['tipo']?.toString() ?? '',
      severidad: json['severidad']?.toString() ?? '',
      latitud:
          json['latitud'] != null ? (json['latitud'] as num).toDouble() : null,
      longitud: json['longitud'] != null
          ? (json['longitud'] as num).toDouble()
          : null,
      descripcion: json['descripcion']?.toString() ?? '',
      resuelta: json['resuelta'] ?? false,
      resueltaPor: json['resuelta_por']?.toString(),
      resolucionNota: json['resolucion_nota']?.toString(),
      resueltaAt: json['resuelta_at'] != null
          ? DateTime.parse(json['resuelta_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_mision': idMision,
      'tipo': tipo,
      'severidad': severidad,
      'latitud': latitud,
      'longitud': longitud,
      'descripcion': descripcion,
      'resuelta': resuelta,
      'resuelta_por': resueltaPor,
      'resolucion_nota': resolucionNota,
    };
  }

  bool get esEmergencia => severidad == 'EMERGENCIA';
  bool get esAviso => severidad == 'AVISO';
  bool get pendiente => !resuelta;

  String get tipoDisplay {
    switch (tipo) {
      case 'DESVIO_RUTA':
        return 'Desvío de Ruta';
      case 'DESVIO':
        return 'Desvío';
      case 'PARADA_NO_AUTORIZADA':
        return 'Parada No Autorizada';
      case 'DETENIDO':
        return 'Detenido';
      case 'TIEMPO_DESTINO_VENCIDO':
        return 'Tiempo en Destino Vencido';
      case 'GPS_PERDIDO':
        return 'GPS Perdido';
      case 'GPS_PRECISION_BAJA':
        return 'GPS Impreciso';
      case 'UBICACION_APAGADA':
        return 'Ubicación Apagada';
      case 'SIN_CONEXION':
        return 'Sin Conexión';
      case 'APP_SUSPENDIDA':
        return 'App Suspendida';
      case 'BATERIA_CRITICA':
        return 'Batería Crítica';
      case 'INICIO_FUERA_HORARIO':
        return 'Inicio Fuera de Horario';
      case 'INCONSISTENCIA':
        return 'Inconsistencia Operativa';
      case 'EXTENSION_SOLICITADA':
        return 'Extensión Solicitada';
      case 'EXTENSION_APROBADA':
        return 'Extensión Aprobada';
      case 'EXTENSION_RECHAZADA':
        return 'Extensión Rechazada';
      default:
        return tipo;
    }
  }
}
