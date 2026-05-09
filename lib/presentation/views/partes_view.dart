import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/constants/app_constants.dart';
import '../controllers/dashboard_controller.dart';
import '../widgets/alert_badge.dart';
import '../widgets/hud_card.dart';

class PartesView extends StatelessWidget {
  const PartesView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<DashboardController>();
    final narrowViewport = MediaQuery.of(context).size.width < 560;
    const titleStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontFamily: 'Orbitron',
      fontWeight: FontWeight.w700,
    );
    const bodyStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      fontFamily: 'Rajdhani',
      fontWeight: FontWeight.w600,
    );
    const subtleStyle = TextStyle(
      color: Colors.white70,
      fontSize: 11,
      fontFamily: 'Rajdhani',
      fontWeight: FontWeight.w600,
    );

    return Obx(() {
      final turno = controller.currentGroup.value.toUpperCase().trim();
      final activeByOficial = <String, bool>{
        for (final o in controller.oficiales)
          o.idOficial.trim():
              o.activo && (o.grupo ?? '').toUpperCase().trim() == turno,
      };
      final errorByOficial = <String, int>{};
      for (final alerta in controller.alertasEpisodiosActivosDelTurno) {
        final id = (alerta['id_oficial_ref'] ?? alerta['id_oficial'] ?? '')
            .toString()
            .trim();
        if (id.isEmpty) continue;
        errorByOficial[id] = (errorByOficial[id] ?? 0) + 1;
      }
      for (final inc in controller.inconsistencias) {
        final estado = (inc['estado'] ?? '').toString().toUpperCase();
        if (estado == 'CERRADA') continue;
        final id = (inc['id_oficial'] ?? '').toString().trim();
        if (id.isEmpty) continue;
        errorByOficial[id] = (errorByOficial[id] ?? 0) + 1;
      }

      final partesOrdenadas = controller.partesSorpresa.toList()
        ..sort((a, b) {
          int prioridadEstado(String estado) {
            switch (estado.trim().toUpperCase()) {
              case 'NUEVO':
              case 'PENDIENTE':
                return 0;
              case 'LEIDO':
                return 1;
              case 'VENCIDO':
                return 2;
              case 'COMPLETADO':
              case 'REGISTRADO':
                return 3;
              default:
                return 4;
            }
          }

          final activeA = activeByOficial[a.idOficial.trim()] == true ? 1 : 0;
          final activeB = activeByOficial[b.idOficial.trim()] == true ? 1 : 0;
          if (activeA != activeB) return activeB.compareTo(activeA);

          final errorA = errorByOficial[a.idOficial.trim()] ?? 0;
          final errorB = errorByOficial[b.idOficial.trim()] ?? 0;
          if (errorA != errorB) return errorB.compareTo(errorA);

          final priA = prioridadEstado(a.estado);
          final priB = prioridadEstado(b.estado);
          if (priA != priB) return priA.compareTo(priB);
          final tsCmp = b.timestamp.compareTo(a.timestamp);
          if (tsCmp != 0) return tsCmp;
          return a.idOficial.compareTo(b.idOficial);
        });

      if (partesOrdenadas.isEmpty) {
        return const Center(
          child: Text(
            'Sin partes sorpresa pendientes.',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'Rajdhani',
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(10),
        itemCount: partesOrdenadas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final parte = partesOrdenadas[index];
          final id = parte.idOficial.trim();
          final hasError = (errorByOficial[id] ?? 0) > 0;
          final isActive = activeByOficial[id] == true;
          return HudCard(
            glowColor: hasError ? AppConstants.warningRed : parte.estadoColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: parte.estadoColor.withValues(alpha: 0.2),
                        borderRadius:
                            BorderRadius.circular(AppConstants.radiusM),
                      ),
                      child: Text(
                        parte.estadoIcon,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PARTE SORPRESA #${_shortId(parte.idSorpresa)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: titleStyle,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: narrowViewport ? 220 : 360,
                                ),
                                child: Text(
                                  'Oficial: ${parte.idOficial}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: false,
                                  style: bodyStyle,
                                ),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppConstants.successGreen
                                        .withValues(alpha: 0.22),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppConstants.successGreen
                                          .withValues(alpha: 0.7),
                                    ),
                                  ),
                                  child: const Text(
                                    'ACTIVO',
                                    style: TextStyle(
                                      color: AppConstants.successGreen,
                                      fontSize: 9.5,
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              if (hasError) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppConstants.warningRed
                                        .withValues(alpha: 0.24),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: AppConstants.warningRed
                                          .withValues(alpha: 0.75),
                                    ),
                                  ),
                                  child: Text(
                                    'ERROR ${(errorByOficial[id] ?? 0)}',
                                    style: const TextStyle(
                                      color: AppConstants.warningRed,
                                      fontSize: 9.5,
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    AlertBadge(
                      text: parte.estadoEtiqueta,
                      color: parte.estadoColor,
                      pulse: parte.pendiente,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppConstants.darkBg.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    border: Border.all(
                      color: AppConstants.neonCyan.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.person,
                            color: AppConstants.neonCyan,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Supervisor: ${parte.supervisorNombre}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bodyStyle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.description,
                            color: AppConstants.neonPink,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Razón: ${parte.razon}',
                              style: bodyStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          color: parte.vencido
                              ? AppConstants.warningRed
                              : AppConstants.neonCyan,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Tiempo: ${parte.tiempoDisplay}',
                          style: subtleStyle.copyWith(
                            color: parte.vencido
                                ? AppConstants.warningRed
                                : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _formatDateTime(parte.timestamp),
                      style: subtleStyle.copyWith(color: Colors.white54),
                    ),
                  ],
                ),
                if (parte.respuestaOficial != null) ...[
                  const Divider(height: 24),
                  Row(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: AppConstants.successGreen,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Registro oficial: ${parte.respuestaOficial}',
                          style: bodyStyle.copyWith(
                              color: AppConstants.successGreen),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      );
    });
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _shortId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return 'N/A';
    return value.length <= 8 ? value : value.substring(0, 8);
  }
}
