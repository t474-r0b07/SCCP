class DtexPolicia {
  final String idPolicia; // UUID como string
  final String grado;
  final String nombre;
  final String cargo;
  final bool activo;

  const DtexPolicia({
    required this.idPolicia,
    required this.grado,
    required this.nombre,
    required this.cargo,
    required this.activo,
  });

  factory DtexPolicia.fromJson(Map<String, dynamic> json) {
    return DtexPolicia(
      idPolicia: (json['id_policia'] ?? '').toString(), // UUID como string
      grado: (json['grado'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      cargo: (json['cargo'] ?? '').toString(),
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_policia': idPolicia,
      'grado': grado,
      'nombre': nombre,
      'cargo': cargo,
      'activo': activo,
    };
  }

  String get nombreCompleto => '$grado $nombre';
  
  String get displayText => '$grado $nombre - $cargo';
}
