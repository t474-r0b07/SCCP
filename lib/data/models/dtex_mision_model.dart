class DtexMision {
  static const estadoAbierta = 'PENDIENTE';
  static const estadoRegistroRealizado = 'REGISTRO_REALIZADO';
  static const estadoEnRuta = 'EN_RUTA';
  static const estadoEnDestino = 'EN_DESTINO';
  static const estadoRetorno = 'RETORNANDO';
  static const estadoCompletada = 'CERRADA';
  static const estadoEmergencia = 'EMERGENCIA';
  static const estadoCancelada = 'CANCELADA';

  static const estadosActivos = <String>{
    estadoAbierta,
    estadoRegistroRealizado,
    estadoEnRuta,
    estadoEnDestino,
    estadoRetorno,
    estadoEmergencia,
  };

  static const estadosFiltrables = <String>[
    'TODOS',
    estadoAbierta,
    estadoRegistroRealizado,
    estadoEnRuta,
    estadoEnDestino,
    estadoRetorno,
    estadoEmergencia,
    estadoCompletada,
    estadoCancelada,
  ];

  static const conductaSinIncidencias = 'SIN_INCIDENCIAS';
  static const conductaConObservaciones = 'CON_OBSERVACIONES';
  static const conductaConIncidenciasGraves = 'CON_INCIDENCIAS_GRAVES';

  static const conductasFinales = <String>[
    conductaSinIncidencias,
    conductaConObservaciones,
    conductaConIncidenciasGraves,
  ];

  final String idMision;
  final String tipoDiligencia;

  // Interno
  final String reoNombre;
  final String reoCi;
  final String? reoExpediente;

  // Custodio
  final String custodioNombre;
  final String custodioCodigo;
  final String custodioGrado;

  // Destino
  final String idDestino;
  final String destinoNombre;

  // Autorización
  final DateTime horaSalidaAutorizada;
  final int tiempoMaxEstadiMin;
  final String? referenciaLegal;

  // OTP
  final String codigoOtp;
  final bool otpUsado;
  final DateTime? otpUsadoAt;

  // Estado
  final String estado;
  final String? conductaFinal;

  // Timestamps operativos
  final DateTime? tsInicioReal;
  final DateTime? tsLlegadaDestino;
  final DateTime? tsSalidaDestino;
  final DateTime? tsCierre;

  // Supervisor
  final String supervisorEmail;
  final String supervisorNombre;

  // Extra
  final String? notas;
  final String? informeUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  DtexMision({
    required this.idMision,
    required this.tipoDiligencia,
    required this.reoNombre,
    required this.reoCi,
    this.reoExpediente,
    required this.custodioNombre,
    required this.custodioCodigo,
    required this.custodioGrado,
    required this.idDestino,
    required this.destinoNombre,
    required this.horaSalidaAutorizada,
    this.tiempoMaxEstadiMin = 60,
    this.referenciaLegal,
    required this.codigoOtp,
    this.otpUsado = false,
    this.otpUsadoAt,
    this.estado = 'PENDIENTE',
    this.conductaFinal,
    this.tsInicioReal,
    this.tsLlegadaDestino,
    this.tsSalidaDestino,
    this.tsCierre,
    required this.supervisorEmail,
    required this.supervisorNombre,
    this.notas,
    this.informeUrl,
    this.createdAt,
    this.updatedAt,
  });

  factory DtexMision.fromJson(Map<String, dynamic> json) {
    return DtexMision(
      idMision: json['id_mision']?.toString() ?? '',
      tipoDiligencia: json['tipo_diligencia']?.toString() ?? '',
      reoNombre: json['reo_nombre']?.toString() ?? '',
      reoCi: json['reo_ci']?.toString() ?? '',
      reoExpediente: json['reo_expediente']?.toString(),
      custodioNombre: json['custodio_nombre']?.toString() ?? '',
      custodioCodigo: json['custodio_codigo']?.toString() ?? '',
      custodioGrado: json['custodio_grado']?.toString() ?? '',
      idDestino: json['id_destino']?.toString() ?? '',
      destinoNombre: json['destino_nombre']?.toString() ?? '',
      horaSalidaAutorizada: DateTime.parse(json['hora_salida_autorizada']),
      tiempoMaxEstadiMin: json['tiempo_max_estadia_min'] ?? 60,
      referenciaLegal: json['referencia_legal']?.toString(),
      codigoOtp: json['codigo_otp']?.toString() ?? '',
      otpUsado: json['otp_usado'] ?? false,
      otpUsadoAt: json['otp_usado_at'] != null
          ? DateTime.parse(json['otp_usado_at'])
          : null,
      estado: json['estado']?.toString() ?? 'PENDIENTE',
      conductaFinal: json['conducta_final']?.toString(),
      tsInicioReal: json['ts_inicio_real'] != null
          ? DateTime.parse(json['ts_inicio_real'])
          : null,
      tsLlegadaDestino: json['ts_llegada_destino'] != null
          ? DateTime.parse(json['ts_llegada_destino'])
          : null,
      tsSalidaDestino: json['ts_salida_destino'] != null
          ? DateTime.parse(json['ts_salida_destino'])
          : null,
      tsCierre:
          json['ts_cierre'] != null ? DateTime.parse(json['ts_cierre']) : null,
      supervisorEmail: json['supervisor_email']?.toString() ?? '',
      supervisorNombre: json['supervisor_nombre']?.toString() ?? '',
      notas: json['notas']?.toString(),
      informeUrl: json['informe_url']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tipo_diligencia': tipoDiligencia,
      'reo_nombre': reoNombre,
      'reo_ci': reoCi,
      'reo_expediente': reoExpediente,
      'custodio_nombre': custodioNombre,
      'custodio_codigo': custodioCodigo,
      'custodio_grado': custodioGrado,
      'id_destino': idDestino,
      'destino_nombre': destinoNombre,
      'hora_salida_autorizada': horaSalidaAutorizada.toIso8601String(),
      'tiempo_max_estadia_min': tiempoMaxEstadiMin,
      'referencia_legal': referenciaLegal,
      'codigo_otp': codigoOtp,
      'supervisor_email': supervisorEmail,
      'supervisor_nombre': supervisorNombre,
      'notas': notas,
    };
  }

  DtexMision copyWith({
    String? estado,
    bool? otpUsado,
    DateTime? otpUsadoAt,
    DateTime? tsInicioReal,
    DateTime? tsLlegadaDestino,
    DateTime? tsSalidaDestino,
    DateTime? tsCierre,
    DateTime? updatedAt,
  }) {
    return DtexMision(
      idMision: idMision,
      tipoDiligencia: tipoDiligencia,
      reoNombre: reoNombre,
      reoCi: reoCi,
      reoExpediente: reoExpediente,
      custodioNombre: custodioNombre,
      custodioCodigo: custodioCodigo,
      custodioGrado: custodioGrado,
      idDestino: idDestino,
      destinoNombre: destinoNombre,
      horaSalidaAutorizada: horaSalidaAutorizada,
      tiempoMaxEstadiMin: tiempoMaxEstadiMin,
      referenciaLegal: referenciaLegal,
      codigoOtp: codigoOtp,
      otpUsado: otpUsado ?? this.otpUsado,
      otpUsadoAt: otpUsadoAt ?? this.otpUsadoAt,
      estado: estado ?? this.estado,
      conductaFinal: conductaFinal,
      tsInicioReal: tsInicioReal ?? this.tsInicioReal,
      tsLlegadaDestino: tsLlegadaDestino ?? this.tsLlegadaDestino,
      tsSalidaDestino: tsSalidaDestino ?? this.tsSalidaDestino,
      tsCierre: tsCierre ?? this.tsCierre,
      supervisorEmail: supervisorEmail,
      supervisorNombre: supervisorNombre,
      notas: notas,
      informeUrl: informeUrl,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Getters de estado
  String get estadoNormalizado => estado.trim().toUpperCase();

  bool get estaActiva => estadosActivos.contains(estadoNormalizado);
  bool get esCerrada => estadoNormalizado == estadoCompletada;
  bool get esEmergencia => estadoNormalizado == estadoEmergencia;
  bool get isPendiente => estadoNormalizado == estadoAbierta;

  String get estadoDisplay {
    switch (estadoNormalizado) {
      case estadoAbierta:
        return 'Misión abierta';
      case estadoRegistroRealizado:
        return 'Registro realizado';
      case estadoEnRuta:
        return 'En ruta';
      case estadoEnDestino:
        return 'En destino';
      case estadoRetorno:
        return 'Retorno';
      case estadoCompletada:
        return 'Completada';
      case estadoEmergencia:
        return 'EMERGENCIA';
      case estadoCancelada:
        return 'Cancelada';
      default:
        return estado;
    }
  }

  static String estadoLabel(String value) {
    switch (value.trim().toUpperCase()) {
      case 'TODOS':
        return 'Todas';
      case estadoAbierta:
        return 'Misión abierta';
      case estadoRegistroRealizado:
        return 'Registro realizado';
      case estadoEnRuta:
        return 'En ruta';
      case estadoEnDestino:
        return 'En destino';
      case estadoRetorno:
        return 'Retorno';
      case estadoCompletada:
        return 'Completada';
      case estadoEmergencia:
        return 'Emergencia';
      case estadoCancelada:
        return 'Cancelada';
      default:
        return value;
    }
  }

  static bool conductaFinalValida(String value) {
    return conductasFinales.contains(value.trim().toUpperCase());
  }

  static String conductaDisplay(String value) {
    switch (value.trim().toUpperCase()) {
      case conductaSinIncidencias:
        return 'Sin incidencias';
      case conductaConObservaciones:
        return 'Con observaciones';
      case conductaConIncidenciasGraves:
        return 'Con incidencias graves';
      default:
        return value;
    }
  }

  String get tipoDiligenciaDisplay {
    switch (tipoDiligencia) {
      case 'JUDICIAL':
        return 'Judicial';
      case 'HOSPITALARIA':
        return 'Hospitalaria';
      case 'PERSONAL':
        return 'Personal';
      case 'PERMISO_ESPECIAL':
        return 'Permiso Especial';
      default:
        return tipoDiligencia;
    }
  }

  // Duración total de la misión (si ya cerró)
  Duration? get duracionTotal {
    if (tsInicioReal == null || tsCierre == null) return null;
    return tsCierre!.difference(tsInicioReal!);
  }

  // Tiempo transcurrido en destino
  Duration? get tiempoEnDestino {
    if (tsLlegadaDestino == null) return null;
    final fin = tsSalidaDestino ?? DateTime.now();
    return fin.difference(tsLlegadaDestino!);
  }

  // Si superó el tiempo máximo autorizado en destino
  bool get tiempoDestinoVencido {
    final t = tiempoEnDestino;
    if (t == null) return false;
    return t.inMinutes > tiempoMaxEstadiMin;
  }
}
