class RadioMessage {
  final String idMensaje;
  final String idOficial;
  final String deUsuario;
  final String paraUsuario;
  final String mensaje;
  final String tipo;
  final String estado;
  final DateTime timestamp;

  const RadioMessage({
    required this.idMensaje,
    required this.idOficial,
    required this.deUsuario,
    required this.paraUsuario,
    required this.mensaje,
    required this.tipo,
    required this.estado,
    required this.timestamp,
  });

  factory RadioMessage.fromJson(Map<String, dynamic> json) {
    final rawTs = json['timestamp'] ?? json['created_at'];
    final parsedTs = rawTs is DateTime
        ? rawTs
        : DateTime.tryParse(rawTs?.toString() ?? '') ?? DateTime.now();

    return RadioMessage(
      idMensaje: (json['id_mensaje'] ?? '').toString(),
      idOficial: (json['id_oficial'] ?? '').toString(),
      deUsuario: (json['de_usuario'] ?? '').toString(),
      paraUsuario: (json['para_usuario'] ?? '').toString(),
      mensaje: (json['mensaje'] ?? '').toString(),
      tipo: (json['tipo'] ?? 'RADIO').toString(),
      estado: (json['estado'] ?? 'NUEVO').toString(),
      timestamp: parsedTs,
    );
  }

  bool get isIncomingForSupervisor =>
      paraUsuario.trim().toUpperCase() == 'SUPERVISOR';
}
