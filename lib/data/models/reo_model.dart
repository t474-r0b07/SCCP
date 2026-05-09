class Reo {
  final String codigoReo;
  final String nombreCompleto;
  final String? documentoIdentidad;
  final String? coordenadasCasa;
  final String? direccionCasa;
  final String? telefono;
  final String? oficialAsignado;
  final String? estado;
  final String? observaciones;

  Reo({
    required this.codigoReo,
    required this.nombreCompleto,
    this.documentoIdentidad,
    this.coordenadasCasa,
    this.direccionCasa,
    this.telefono,
    this.oficialAsignado,
    this.estado,
    this.observaciones,
  });

  factory Reo.fromJson(Map<String, dynamic> json) {
    return Reo(
      codigoReo: json['codigo_reo']?.toString() ?? '',
      nombreCompleto: json['nombre_completo']?.toString() ?? '',
      documentoIdentidad: json['documento_identidad']?.toString(),
      coordenadasCasa: json['coordenadas_casa']?.toString(),
      direccionCasa: json['direccion_casa']?.toString(),
      telefono: json['telefono']?.toString(),
      oficialAsignado: json['oficial_asignado']?.toString(),
      estado: json['estado']?.toString(),
      observaciones: json['observaciones']?.toString(),
    );
  }
}
