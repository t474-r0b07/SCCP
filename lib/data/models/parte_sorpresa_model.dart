import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class ParteSorpresa {
  final String idSorpresa;
  final String idOficial;
  final String? supervisorNombre;
  final String razon;
  final String estado;
  final DateTime timestamp;
  final String? respuestaOficial;

  ParteSorpresa({
    required this.idSorpresa,
    required this.idOficial,
    this.supervisorNombre,
    required this.razon,
    required this.estado,
    required this.timestamp,
    this.respuestaOficial,
  });

  factory ParteSorpresa.fromJson(Map<String, dynamic> json) {
    final rawTs = json['timestamp'];
    final parsedTs = rawTs != null ? DateTime.tryParse(rawTs.toString()) : null;
    return ParteSorpresa(
      idSorpresa: json['id_sorpresa']?.toString() ?? '',
      idOficial: json['id_oficial']?.toString() ?? '',
      supervisorNombre: json['supervisor_nombre']?.toString(),
      razon: json['razon']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      timestamp: parsedTs ?? DateTime.now(),
      respuestaOficial: json['respuesta_oficial']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_sorpresa': idSorpresa,
      'id_oficial': idOficial,
      'supervisor_nombre': supervisorNombre,
      'razon': razon,
      'estado': estado,
      'timestamp': timestamp.toIso8601String(),
      'respuesta_oficial': respuestaOficial,
    };
  }

  Color get estadoColor => AppConstants.estadosColor[estado] ?? Colors.grey;

  String get estadoNormalized => estado.trim().toUpperCase();

  String get estadoEtiqueta {
    switch (estadoNormalized) {
      case 'NUEVO':
      case 'PENDIENTE':
        return 'PARTE SOLICITADO';
      case 'LEIDO':
        return 'PARTE LEIDO';
      case 'COMPLETADO':
      case 'REGISTRADO':
        return 'PARTE REGISTRADO CON EXITO';
      case 'VENCIDO':
        return 'PARTE VENCIDO';
      default:
        return estadoNormalized.isEmpty ? 'SIN ESTADO' : estadoNormalized;
    }
  }

  String get estadoIcon {
    switch (estadoNormalized) {
      case 'PENDIENTE':
      case 'NUEVO':
        return '⏳';
      case 'LEIDO':
        return '👁️';
      case 'COMPLETADO':
      case 'REGISTRADO':
        return '✅';
      case 'VENCIDO':
        return '❌';
      default:
        return '❓';
    }
  }

  bool get pendiente =>
      estadoNormalized == 'PENDIENTE' || estadoNormalized == 'NUEVO';

  bool get vencido => estadoNormalized == 'VENCIDO';

  String get tiempoDisplay {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m';
    return 'Ahora';
  }
}
