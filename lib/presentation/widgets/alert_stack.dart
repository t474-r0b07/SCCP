import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'hud_card.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/inconsistencia_model.dart';

class AlertStack extends StatelessWidget {
  final List<Inconsistencia> inconsistencias;

  const AlertStack({
    super.key,
    required this.inconsistencias,
  });

  @override
  Widget build(BuildContext context) {
    if (inconsistencias.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      width: 320,
      child: ListView.separated(
        itemCount: inconsistencias.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final inc = inconsistencias[index];
          return _AlertCard(inconsistencia: inc);
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final Inconsistencia inconsistencia;

  const _AlertCard({required this.inconsistencia});

  @override
  Widget build(BuildContext context) {
    final createdAt = inconsistencia.fechaDeteccion;
    final elapsed = DateTime.now().difference(createdAt);

    return HudCard(
      glowColor: AppConstants.warningRed,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Shimmer.fromColors(
                baseColor: AppConstants.warningRed,
                highlightColor: AppConstants.neonOrange,
                period: const Duration(milliseconds: 1500),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppConstants.warningRed,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  inconsistencia.tipoInconsistencia,
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.warningRed,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              Text(
                _formatDuration(elapsed),
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            inconsistencia.idOficial,
            style: const TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            inconsistencia.descripcion,
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.7),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideX(begin: 1.0, end: 0.0);
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}
