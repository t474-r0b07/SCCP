import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class MonitoreoReporte {
  final String idReporte;
  final String idOficialRef;
  final String? nombreOficial;
  final String? reoAsignado;
  final String? ubicacionActual;
  final double? latitud;
  final double? longitud;
  final double? distanciaMetros;
  final String estadoAlerta;
  final int? nivelBateria;
  final bool gpsReal;
  final bool? movimiento;
  final String? parteNovedad;
  final DateTime fechaHora;
  final String? imei;
  final String? grupo;
  final String? prioridad;

  MonitoreoReporte({
    required this.idReporte,
    required this.idOficialRef,
    this.nombreOficial,
    this.reoAsignado,
    this.ubicacionActual,
    this.latitud,
    this.longitud,
    this.distanciaMetros,
    this.estadoAlerta = 'NORMAL',
    this.nivelBateria,
    this.gpsReal = true,
    this.movimiento,
    this.parteNovedad,
    required this.fechaHora,
    this.imei,
    this.grupo,
    this.prioridad,
  });

  factory MonitoreoReporte.fromJson(Map<String, dynamic> json) {
    final rawFecha = json['fecha_hora'];
    final parsedFecha = rawFecha != null
        ? DateTime.tryParse(rawFecha.toString())
        : null;
    return MonitoreoReporte(
      idReporte: json['id_reporte']?.toString() ?? '',
      idOficialRef: json['id_oficial_ref']?.toString() ?? '',
      nombreOficial: json['nombre_oficial']?.toString(),
      reoAsignado: json['reo_asignado']?.toString(),
      ubicacionActual: json['ubicacion_actual']?.toString(),
      latitud: json['latitud']?.toDouble(),
      longitud: json['longitud']?.toDouble(),
      distanciaMetros: json['distancia_metros']?.toDouble(),
      estadoAlerta: json['estado_alerta']?.toString() ?? 'NORMAL',
      nivelBateria: json['nivel_bateria']?.toInt(),
      gpsReal: json['gps_real'] ?? true,
      movimiento: json['movimiento'],
      parteNovedad: json['parte_novedad']?.toString(),
      fechaHora: (parsedFecha?.toLocal()) ?? DateTime.now(),
      imei: json['imei']?.toString(),
      grupo: json['grupo']?.toString(),
      prioridad: json['prioridad']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_reporte': idReporte,
      'id_oficial_ref': idOficialRef,
      'nombre_oficial': nombreOficial,
      'reo_asignado': reoAsignado,
      'ubicacion_actual': ubicacionActual,
      'latitud': latitud,
      'longitud': longitud,
      'distancia_metros': distanciaMetros,
      'estado_alerta': estadoAlerta,
      'nivel_bateria': nivelBateria,
      'gps_real': gpsReal,
      'movimiento': movimiento,
      'parte_novedad': parteNovedad,
      'fecha_hora': fechaHora.toIso8601String(),
      'imei': imei,
      'grupo': grupo,
      'prioridad': prioridad,
    };
  }

  Color get estadoColor =>
      AppConstants.estadosColor[estadoAlerta] ?? Colors.grey;

  String get estadoIcon {
    switch (estadoAlerta) {
      case 'NORMAL':
        return '✓';
      case 'ALERTA':
        return '⚠';
      case 'CRITICO':
        return '⚡';
      default:
        return '○';
    }
  }

  Color get bateriaColor {
    if (nivelBateria == null) return Colors.grey;
    if (nivelBateria! > 50) return AppConstants.successGreen;
    if (nivelBateria! > 20) return AppConstants.alertOrange;
    return AppConstants.warningRed;
  }

  bool get requiresAttention =>
      estadoAlerta == 'CRITICO' ||
      (nivelBateria != null && nivelBateria! < 20) ||
      !gpsReal;
}
