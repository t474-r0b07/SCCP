import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData.dark().copyWith(
      scaffoldBackgroundColor: AppConstants.darkBg,
      primaryColor: AppConstants.neonCyan,
      colorScheme: const ColorScheme.dark(
        primary: AppConstants.neonCyan,
        secondary: AppConstants.neonPink,
        surface: AppConstants.darkBg,
        error: AppConstants.warningRed,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 48,
          fontWeight: FontWeight.w900,
          letterSpacing: 4.0,
          color: AppConstants.neonCyan,
          shadows: [
            Shadow(
              color: AppConstants.neonCyan,
              blurRadius: 20,
            ),
          ],
        ),
        displayMedium: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.5,
          color: AppConstants.neonCyan,
          shadows: [
            Shadow(
              color: AppConstants.neonCyan,
              blurRadius: 15,
            ),
          ],
        ),
        displaySmall: TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
        bodyLarge: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 15,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        bodyMedium: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 13,
          fontWeight: FontWeight.normal,
        ),
        labelLarge: TextStyle(
          fontFamily: 'Rajdhani',
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: AppConstants.neonCyan,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.zero,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          textStyle: const TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 14,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
          ),
          side: const BorderSide(
            color: AppConstants.neonCyan,
            width: 2,
          ),
        ),
      ),
    );
  }

  static BoxShadow neonGlow({
    Color color = AppConstants.neonCyan,
    double blurRadius = 25,
    double spreadRadius = 2,
  }) {
    return BoxShadow(
      color: color.withValues(alpha: 0.6),
      blurRadius: blurRadius,
      spreadRadius: spreadRadius,
    );
  }

  static BoxShadow innerGlow({
    Color color = AppConstants.neonCyan,
    double blurRadius = 15,
  }) {
    return BoxShadow(
      color: color.withValues(alpha: 0.3),
      blurRadius: blurRadius,
      spreadRadius: -5,
    );
  }
}
