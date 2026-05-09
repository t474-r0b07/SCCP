import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class Inconsistencia {
  final String idInconsistencia;
  final String idOficial;
  final String? idReporte;
  final String tipoInconsistencia;
  final String estado;
  final String prioridad;
  final String descripcion;
  final DateTime fechaDeteccion;
  final String? justificacionOficial;
  final String? revisadoPor;
  final DateTime? fechaJustificacion;
  final DateTime? fechaRevision;
  final DateTime? fechaCierre;
  
  // Campos adicionales que usa el repository
  final bool resuelta;
  final String? resueltaPor;
  final DateTime? fechaResolucion;

  Inconsistencia({
    required this.idInconsistencia,
    required this.idOficial,
    this.idReporte,
    required this.tipoInconsistencia,
    required this.estado,
    required this.prioridad,
    required this.descripcion,
    required this.fechaDeteccion,
    this.justificacionOficial,
    this.revisadoPor,
    this.fechaJustificacion,
    this.fechaRevision,
    this.fechaCierre,
    this.resuelta = false,
    this.resueltaPor,
    this.fechaResolucion,
  });

  factory Inconsistencia.fromJson(Map<String, dynamic> json) {
    DateTime? parseLocal(dynamic value) {
      if (value == null) return null;
      final parsed = DateTime.tryParse(value.toString());
      return parsed;
    }
    return Inconsistencia(
      idInconsistencia: json['id_inconsistencia']?.toString() ?? '',
      idOficial: json['id_oficial']?.toString() ?? '',
      idReporte: json['id_reporte']?.toString(),
      tipoInconsistencia: json['tipo_inconsistencia']?.toString() ?? '',
      estado: json['estado']?.toString() ?? 'ABIERTA',
      prioridad: json['prioridad']?.toString() ?? 'MEDIA',
      descripcion: json['descripcion']?.toString() ?? '',
      fechaDeteccion: parseLocal(json['fecha_deteccion']) ?? DateTime.now(),
      justificacionOficial: json['justificacion_oficial']?.toString(),
      revisadoPor: json['revisado_por']?.toString(),
      fechaJustificacion: parseLocal(json['fecha_justificacion']),
      fechaRevision: parseLocal(json['fecha_revision']),
      fechaCierre: parseLocal(json['fecha_cierre']),
      resuelta: json['resuelta'] ?? (json['estado'] == 'CERRADA'),
      resueltaPor: json['resuelta_por']?.toString(),
      fechaResolucion: parseLocal(json['fecha_resolucion']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_inconsistencia': idInconsistencia,
      'id_oficial': idOficial,
      'id_reporte': idReporte,
      'tipo_inconsistencia': tipoInconsistencia,
      'estado': estado,
      'prioridad': prioridad,
      'descripcion': descripcion,
      'fecha_deteccion': fechaDeteccion.toIso8601String(),
      'justificacion_oficial': justificacionOficial,
      'revisado_por': revisadoPor,
      'fecha_justificacion': fechaJustificacion?.toIso8601String(),
      'fecha_revision': fechaRevision?.toIso8601String(),
      'fecha_cierre': fechaCierre?.toIso8601String(),
      'resuelta': resuelta,
      'resuelta_por': resueltaPor,
      'fecha_resolucion': fechaResolucion?.toIso8601String(),
    };
  }

  Color get estadoColor => AppConstants.estadosColor[estado] ?? Colors.grey;

  Color get prioridadColor {
    switch (prioridad) {
      case 'CRITICA':
        return AppConstants.warningRed;
      case 'ALTA':
        return AppConstants.alertOrange;
      case 'MEDIA':
        return AppConstants.neonOrange;
      case 'BAJA':
        return AppConstants.successGreen;
      default:
        return Colors.grey;
    }
  }

  String get prioridadNivel {
    switch (prioridad) {
      case 'CRITICA':
        return '4';
      case 'ALTA':
        return '3';
      case 'MEDIA':
        return '2';
      case 'BAJA':
        return '1';
      default:
        return '0';
    }
  }

  String get tipoDisplay {
    switch (tipoInconsistencia) {
      case 'GPS_FALSO':
        return 'GPS Falso';
      case 'BATERIA_BAJA':
        return 'Batería Baja';
      case 'FUERA_ZONA':
        return 'Fuera de Zona';
      case 'SIN_MOVIMIENTO':
        return 'Sin Movimiento';
      case 'DISTANCIA_EXCEDIDA':
        return 'Distancia Excedida';
      case 'FALTA_REPORTE':
        return 'Falta Reporte';
      default:
        return tipoInconsistencia;
    }
  }

  String get tipoIcon {
    switch (tipoInconsistencia) {
      case 'GPS_FALSO':
        return '📍';
      case 'BATERIA_BAJA':
        return '🔋';
      case 'FUERA_ZONA':
        return '🚫';
      case 'SIN_MOVIMIENTO':
        return '⏸️';
      case 'DISTANCIA_EXCEDIDA':
        return '📏';
      case 'FALTA_REPORTE':
        return '📡';
      default:
        return '❓';
    }
  }

  bool get requiereResolucion => 
      estado == 'ABIERTA' || estado == 'EN_REVISION';
  
  bool get estaCerrada => estado == 'CERRADA' || resuelta;
  
  bool get estaJustificada => estado == 'JUSTIFICADA';
}
