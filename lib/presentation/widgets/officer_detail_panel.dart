import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui';
import 'package:sccp_command_center/data/models/oficial_model.dart';
import 'package:sccp_command_center/data/models/monitoreo_reporte_model.dart';
import 'package:sccp_command_center/core/constants/app_constants.dart';
import 'package:sccp_command_center/presentation/controllers/dashboard_controller.dart';

class OfficerDetailPanel extends StatelessWidget {
  final String oficialId;
  final VoidCallback onClose;

  const OfficerDetailPanel({
    super.key,
    required this.oficialId,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final oficial = controller.oficiales
        .firstWhereOrNull((Oficial o) => o.idOficial == oficialId);
    final reporte = controller.reportes
        .firstWhereOrNull((MonitoreoReporte r) => r.idOficialRef == oficialId);

    if (oficial == null) {
      return const SizedBox.shrink();
    }

    return Positioned(
      left: 20,
      top: 120,
      bottom: 120,
      child: Container(
        width: 380,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppConstants.grupoColors[oficial.grupo]
                      ?.withValues(alpha: 0.3) ??
                  AppConstants.neonCyan.withValues(alpha: 0.3),
              blurRadius: 25,
              spreadRadius: 3,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppConstants.glassBg.withValues(alpha: 0.2),
                    AppConstants.glassBg.withValues(alpha: 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppConstants.grupoColors[oficial.grupo]
                          ?.withValues(alpha: 0.4) ??
                      AppConstants.neonCyan.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // HEADER
                  _buildHeader(oficial),

                  // CONTENT
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildInfoRow('ID', oficial.idOficial),
                          const SizedBox(height: 12),
                          _buildInfoRow('GRUPO', oficial.grupo ?? ''),
                          const SizedBox(height: 12),
                          _buildInfoRow('GRADO', oficial.gradoDisplay),
                          const SizedBox(height: 12),
                          _buildInfoRow('TURNO', oficial.turno ?? 'N/A'),
                          const SizedBox(height: 12),
                          _buildInfoRow('REO', oficial.reoAsignado ?? 'N/A'),
                          if (reporte != null) ...[
                            const Divider(height: 32, color: Colors.white24),
                            Text(
                              'TELEMETRÍA',
                              style: Get.textTheme.labelLarge?.copyWith(
                                color: AppConstants.neonCyan,
                                letterSpacing: 2.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildTelemetry(reporte),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // ACTIONS
                  _buildActions(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(oficial) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.grupoColors[oficial.grupo]?.withValues(alpha: 0.3) ??
                AppConstants.neonCyan.withValues(alpha: 0.3),
            Colors.transparent,
          ],
        ),
        border: Border(
          bottom: BorderSide(
            color: AppConstants.grupoColors[oficial.grupo]
                    ?.withValues(alpha: 0.5) ??
                AppConstants.neonCyan.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (oficial.grupo ?? '') == 'ALFA'
                  ? AppConstants.neonCyan
                  : AppConstants.neonPink,
              boxShadow: [
                BoxShadow(
                  color: AppConstants.grupoColors[oficial.grupo ?? '']
                          ?.withValues(alpha: 0.6) ??
                      AppConstants.neonCyan.withValues(alpha: 0.6),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                oficial.grupoDisplay,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  oficial.nombreOficial.toUpperCase(),
                  style: Get.textTheme.displaySmall?.copyWith(
                    fontSize: 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  oficial.gradoDisplay.toUpperCase(),
                  style: Get.textTheme.bodyMedium?.copyWith(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: onClose,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Get.textTheme.bodyMedium?.copyWith(
            color: Colors.white60,
            fontSize: 12,
            letterSpacing: 1.5,
          ),
        ),
        Text(
          value,
          style: Get.textTheme.bodyLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTelemetry(reporte) {
    return Column(
      children: [
        _buildInfoRow('BATERÍA', '${reporte.nivelBateria ?? 0}%'),
        const SizedBox(height: 8),
        _buildInfoRow('GPS', reporte.gpsReal ? 'REAL' : 'FALSO'),
        const SizedBox(height: 8),
        _buildInfoRow('ESTADO', reporte.estadoAlerta),
        const SizedBox(height: 8),
        _buildInfoRow('UBICACIÓN', reporte.ubicacionActual ?? 'N/A'),
      ],
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white12, width: 1),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TacticalButton(
              label: 'LLAMAR',
              icon: Icons.phone,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TacticalButton(
              label: 'PARTE',
              icon: Icons.assignment,
              onTap: () {},
              color: AppConstants.neonPink,
            ),
          ),
        ],
      ),
    );
  }
}

class _TacticalButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _TacticalButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? AppConstants.neonCyan;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            border:
                Border.all(color: btnColor.withValues(alpha: 0.5), width: 2),
            gradient: LinearGradient(
              colors: [
                btnColor.withValues(alpha: 0.2),
                btnColor.withValues(alpha: 0.1),
              ],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: btnColor, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: btnColor,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
