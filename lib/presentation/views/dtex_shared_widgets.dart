import 'package:flutter/material.dart';
import 'package:sccp_command_center/core/constants/app_constants.dart';

TextStyle dtexTitleStyle({Color color = Colors.white, double fontSize = 18}) {
  return TextStyle(
    color: color,
    fontFamily: 'Orbitron',
    fontSize: fontSize,
    fontWeight: FontWeight.w800,
  );
}

TextStyle dtexMutedStyle({double fontSize = 14}) {
  return TextStyle(
    color: Colors.white.withValues(alpha: 0.68),
    fontSize: fontSize,
    fontWeight: FontWeight.w600,
  );
}

TextStyle dtexSectionStyle({double fontSize = 13}) {
  return TextStyle(
    color: AppConstants.neonCyan,
    fontSize: fontSize,
    fontWeight: FontWeight.w900,
    letterSpacing: 0,
  );
}

Widget dtexPanel({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.055),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    ),
    child: child,
  );
}

InputDecoration dtexInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.black.withValues(alpha: 0.22),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppConstants.neonCyan),
    ),
  );
}
