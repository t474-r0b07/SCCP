import 'package:flutter/material.dart';
import 'dart:ui';
import '../../core/constants/app_constants.dart';

class HudCard extends StatelessWidget {
  final Widget child;
  final double? width;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;

  const HudCard({
    super.key,
    required this.child,
    this.width,
    this.height,
    this.padding,
    this.glowColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = glowColor ?? AppConstants.neonCyan;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(
          color: effectiveColor,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.5),
            blurRadius: 25,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: effectiveColor.withValues(alpha: 0.3),
            blurRadius: 50,
          ),
        ],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Container(
            padding: padding ?? const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.darkPanel.withValues(alpha: 0.8),
                  AppConstants.darkBg.withValues(alpha: 0.6),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
