import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/constants/app_constants.dart';

class TacticalDock extends StatelessWidget {
  const TacticalDock({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
            color: AppConstants.neonCyan.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(35),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppConstants.glassBg.withValues(alpha: 0.2),
                  AppConstants.glassBg.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(35),
              border: Border.all(
                color: AppConstants.neonCyan.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _DockIcon(
                  icon: Icons.radar,
                  label: 'MAPA',
                  onTap: () {},
                ),
                _DockIcon(
                  icon: Icons.history,
                  label: 'HISTORIAL',
                  onTap: () {},
                ),
                _DockIcon(
                  icon: Icons.settings,
                  label: 'CONFIG',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockIcon extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DockIcon({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_DockIcon> createState() => _DockIconState();
}

class _DockIconState extends State<_DockIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isHovered ? 1.15 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isHovered
                  ? AppConstants.neonCyan.withValues(alpha: 0.2)
                  : Colors.transparent,
              border: Border.all(
                color: AppConstants.neonCyan
                    .withValues(alpha: _isHovered ? 0.6 : 0.3),
                width: 2,
              ),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: AppConstants.neonCyan.withValues(alpha: 0.5),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: Icon(
              widget.icon,
              color: AppConstants.neonCyan,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
