class DtexDestino {
  final String idDestino;
  final String nombre;
  final String tipo;
  final String direccion;
  final double latitud;
  final double longitud;
  final int radioMetros;
  final bool activo;

  DtexDestino({
    required this.idDestino,
    required this.nombre,
    required this.tipo,
    required this.direccion,
    required this.latitud,
    required this.longitud,
    this.radioMetros = 80,
    this.activo = true,
  });

  factory DtexDestino.fromJson(Map<String, dynamic> json) {
    return DtexDestino(
      idDestino:   json['id_destino']?.toString() ?? '',
      nombre:      json['nombre']?.toString() ?? '',
      tipo:        json['tipo']?.toString() ?? '',
      direccion:   json['direccion']?.toString() ?? '',
      latitud:     (json['latitud'] as num).toDouble(),
      longitud:    (json['longitud'] as num).toDouble(),
      radioMetros: json['radio_metros'] ?? 80,
      activo:      json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_destino':   idDestino,
      'nombre':       nombre,
      'tipo':         tipo,
      'direccion':    direccion,
      'latitud':      latitud,
      'longitud':     longitud,
      'radio_metros': radioMetros,
      'activo':       activo,
    };
  }

  String get tipoDisplay {
    switch (tipo) {
      case 'JUDICIAL':       return 'Judicial';
      case 'HOSPITALARIO':   return 'Hospitalario';
      case 'ADMINISTRATIVO': return 'Administrativo';
      default:               return 'Otro';
    }
  }
}
