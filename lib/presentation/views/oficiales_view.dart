import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sccp_command_center/core/constants/app_constants.dart';
import 'package:sccp_command_center/data/models/monitoreo_reporte_model.dart';
import 'package:sccp_command_center/data/models/oficial_model.dart';
import 'package:sccp_command_center/presentation/controllers/dashboard_controller.dart';
import 'package:sccp_command_center/presentation/widgets/alert_badge.dart';
import 'package:sccp_command_center/presentation/widgets/hud_card.dart';

class OficialesView extends StatelessWidget {
  const OficialesView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();

    return Obx(() {
      final oficiales = _sortedOficiales(controller);
      final alertasByOficial = controller.latestAlertaOperativaByOficial;

      return GridView.builder(
        padding: const EdgeInsets.all(AppConstants.paddingL),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: AppConstants.paddingM,
          mainAxisSpacing: AppConstants.paddingM,
          childAspectRatio: 1.2,
        ),
        itemCount: oficiales.length,
        itemBuilder: (context, index) {
          final oficial = oficiales[index];
          final reportes = controller.reportes
              .where(
                  (MonitoreoReporte r) => r.idOficialRef == oficial.idOficial)
              .toList();
          final ultimoReporte = reportes.isNotEmpty ? reportes.first : null;
          final alertaActual = alertasByOficial[oficial.idOficial];

          final severity = _alertSeverity(alertaActual);
          final alertColor = _alertColor(alertaActual);
          final groupColor = (oficial.grupo ?? '') == 'ALFA'
              ? AppConstants.neonCyan
              : AppConstants.neonPink;
          final cardGlowColor = severity > 1 ? alertColor : groupColor;

          return HudCard(
            glowColor: cardGlowColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: cardGlowColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cardGlowColor,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          oficial.grupoDisplay,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cardGlowColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.paddingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            oficial.idOficial,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          Text(
                            oficial.gradoDisplay,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white54,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingM),
                Text(
                  oficial.nombreOficial,
                  style: Theme.of(context).textTheme.bodyLarge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppConstants.paddingS),
                if (oficial.reoAsignado != null)
                  Row(
                    children: [
                      const Icon(
                        Icons.person_pin,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Reo: ${oficial.reoAsignado}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                if ((oficial.jurisdiccion ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Jurisdicción: ${oficial.jurisdiccion}',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (alertaActual != null) ...[
                  const SizedBox(height: AppConstants.paddingS),
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _alertSummary(alertaActual),
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: alertColor.withValues(alpha: 0.95),
                                    fontWeight: FontWeight.w700,
                                  ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                const Spacer(),
                const Divider(height: 16),
                if (ultimoReporte != null) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: alertaActual != null
                            ? alertColor
                            : ultimoReporte.estadoColor,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          ultimoReporte.ubicacionActual ?? 'Sin ubicación',
                          style: Theme.of(context).textTheme.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.battery_std,
                        color: ultimoReporte.bateriaColor,
                        size: 20,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${ultimoReporte.nivelBateria ?? 0}%',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: ultimoReporte.bateriaColor,
                            ),
                      ),
                      const Spacer(),
                      AlertBadge(
                        text: alertaActual != null
                            ? _alertBadgeLabel(alertaActual)
                            : ultimoReporte.estadoAlerta,
                        color: alertaActual != null
                            ? alertColor
                            : ultimoReporte.estadoColor,
                        pulse: alertaActual != null
                            ? _alertSeverity(alertaActual) >= 3
                            : ultimoReporte.estadoAlerta == 'CRITICO',
                      ),
                    ],
                  ),
                ] else
                  Text(
                    'Sin reportes',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white38,
                        ),
                  ),
              ],
            ),
          );
        },
      );
    });
  }

  List<Oficial> _sortedOficiales(DashboardController controller) {
    final alertas = controller.latestAlertaOperativaByOficial;
    final sorted = controller.oficiales.toList();
    sorted.sort((a, b) {
      final sevA = _alertSeverity(alertas[a.idOficial]);
      final sevB = _alertSeverity(alertas[b.idOficial]);
      if (sevA != sevB) return sevB.compareTo(sevA);
      return a.idOficial.compareTo(b.idOficial);
    });
    return sorted;
  }

  int _alertSeverity(Map<String, dynamic>? alerta) {
    if (alerta == null) return 0;
    final explicit = (alerta['severidad'] as num?)?.toInt();
    if (explicit != null) return explicit.clamp(1, 3);

    final estado = (alerta['estado_alerta'] ?? '').toString().toUpperCase();
    final distancia = (alerta['distancia_metros'] as num?)?.toDouble() ?? 0;
    if (estado == 'CRITICO' || distancia > 100) return 3;
    if (estado == 'ALERTA' || distancia > 50) return 2;
    return 1;
  }

  Color _alertColor(Map<String, dynamic>? alerta) {
    final sev = _alertSeverity(alerta);
    if (sev >= 3) return AppConstants.warningRed;
    if (sev == 2) return AppConstants.alertOrange;
    return const Color(0xFF8A2BE2);
  }

  String _alertSummary(Map<String, dynamic> alerta) {
    final motivo =
        (alerta['motivo_alerta'] ?? 'ALERTA').toString().toUpperCase();
    final distancia = (alerta['distancia_metros'] as num?)?.toDouble();
    if (distancia == null) return motivo;
    return '$motivo · ${distancia.toStringAsFixed(1)}m';
  }

  String _alertBadgeLabel(Map<String, dynamic> alerta) {
    final tipo = (alerta['tipo_alerta'] ?? '').toString().toUpperCase();
    if (tipo.contains('ABANDONO')) return 'ABANDONO';
    if (tipo.contains('FALTA')) return 'FALTA';
    if (tipo.contains('TELEMETRIA')) return 'TELEMETRÍA';
    return 'ALERTA';
  }
}
