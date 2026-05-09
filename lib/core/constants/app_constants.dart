import 'package:flutter/material.dart';
import 'package:sccp_shared/sccp_shared.dart';

class AppConstants {
  static const String appName = 'SCCP MONITOREO';
  static const String appVersion = '1.1.3';

  // COLORES TRON LEGACY
  static const Color neonCyan = Color(0xFF00F3FF);
  static const Color neonPink = Color(0xFFFF0080);
  static const Color neonOrange = Color(0xFFFF6600);
  static const Color neonPurple = Color(0xFF9D00FF);
  static const Color neonGreen = Color(0xFF00FF99);
  static const Color neonRed = Color(0xFFFF0055);
  static const Color tronBlue = Color(0xFF00FFFF);

  // BACKGROUNDS
  static const Color darkBg = Color(0xFF000814);
  static const Color darkPanel = Color(0xFF001233);
  static const Color gridColor = Color(0xFF00F3FF);
  static const Color glassBg = Color(0x0DFFFFFF);

  static const LinearGradient gridGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [tronBlue, Color(0xFF001122)],
  );

  // ESTADOS
  static const Color successGreen = Color(0xFF00FF99);
  static const Color warningRed = Color(0xFFFF0055);
  static const Color alertOrange = Color(0xFFFF6600);

  static const Map<String, Color> estadosColor = {
    'NORMAL': successGreen,
    'ALERTA': alertOrange,
    'CRITICO': warningRed,
    'NUEVO': alertOrange,
    'PENDIENTE': alertOrange,
    'LEIDO': neonCyan,
    'COMPLETADO': successGreen,
    'REGISTRADO': successGreen,
    'VENCIDO': warningRed,
  };

  static const Map<String, Color> grupoColors = {
    'ALFA': neonCyan,
    'BRAVO': neonPink,
  };

  // DURACIONES
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration scannerDuration = Duration(seconds: 5);
  static const Duration pulseDuration = Duration(milliseconds: 2000);

  // CONFIGURACIÓN MAPA
  static const double defaultLatitude = -16.5000;
  static const double defaultLongitude = -68.1500;
  static const double defaultZoom = 13.0;
  static const double markerSize = 56.0;

  // SUPABASE
  static const String supabaseUrl = 'https://gvkkzmnlgzztlqxqqsro.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd2a2t6bW5sZ3p6dGxxeHFxc3JvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA4MjA2MjksImV4cCI6MjA4NjM5NjYyOX0.MzUCQE2e9gdK6f83PgHCO1nIfJFQfLEixmnDqN5IF5U';

  // TABLAS - CORREGIDAS SEGÚN SCHEMA
  static const String tableOficiales =
      'oficiales'; // ❌ ERA: 'oficiales_maestro'
  static const String tableMonitoreo =
      'monitoreo_reportes'; // ❌ ERA: 'monitoreoreportes'
  static const String tableInconsistencias = 'inconsistencias';
  static const String tablePartes = 'partes_sorpresa';
  static const String tableAdmins = 'allowed_admins';
  static const String tableReos = 'reos';
  static const String tablePartesOficiales = 'partes_oficiales';
  static const String tableLoginLogs = 'login_logs';
  static const String tableRadioMensajes = SharedDb.tableRadioMensajes;
  static const String tableRadioLlamadas = SharedDb.tableRadioLlamadas;
  static const String viewInconsistenciasLogicas =
      'v_webapp_inconsistencias_logicas';
  static const String viewAlertasOperativas = 'v_webapp_alertas_operativas';
  static const String viewTelemetriaActual = 'v_webapp_telemetria_actual';

  // INTERVALOS
  static const Duration refreshInterval = Duration(seconds: 10);
  static const Duration inconsistenciasInterval = Duration(seconds: 15);

  // SPACING
  static const double paddingXS = 4.0;
  static const double paddingS = 8.0;
  static const double paddingM = 16.0;
  static const double paddingL = 24.0;
  static const double paddingXL = 32.0;

  // BORDER RADIUS
  static const double radiusS = 4.0;
  static const double radiusM = 8.0;
  static const double radiusL = 12.0;
  static const double radiusXL = 16.0;
}
