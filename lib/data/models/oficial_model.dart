import '../../core/utils/grado_assets.dart';

class Oficial {
  final String idOficial;
  final String nombreOficial;
  final String? grupo;
  final String? grado;
  final String? reoAsignado;
  final String? turno;
  final String? imei;
  final String? jurisdiccion;
  final bool activo;

  Oficial({
    required this.idOficial,
    required this.nombreOficial,
    this.grupo,
    this.grado,
    this.reoAsignado,
    this.turno,
    this.imei,
    this.jurisdiccion,
    this.activo = true,
  });

  factory Oficial.fromJson(Map<String, dynamic> json) {
    return Oficial(
      idOficial: json['id_oficial']?.toString() ?? '',
      nombreOficial: json['nombre_oficial']?.toString() ?? '',
      grupo: json['grupo']?.toString(),
      grado: json['grado']?.toString(),
      reoAsignado: json['reo_asignado']?.toString(),
      turno: json['turno']?.toString(),
      imei: json['imei']?.toString(),
      jurisdiccion:
          (json['jurisdiccion'] ?? json['Jurisdiccion'])?.toString(),
      activo: json['activo'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_oficial': idOficial,
      'nombre_oficial': nombreOficial,
      'grupo': grupo,
      'grado': grado,
      'reo_asignado': reoAsignado,
      'turno': turno,
      'imei': imei,
      'jurisdiccion': jurisdiccion,
      'activo': activo,
    };
  }

  String get grupoDisplay => grupo ?? 'SIN GRUPO';

  String get gradoDisplay => GradoAssets.displayName(grado);
}
