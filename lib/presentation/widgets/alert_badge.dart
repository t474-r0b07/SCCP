import 'package:flutter/material.dart';

class AlertBadge extends StatelessWidget {
  final String text;
  final Color color;
  final bool pulse;

  const AlertBadge(
      {super.key, required this.text, required this.color, this.pulse = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          if (pulse)
            BoxShadow(
              color: color.withValues(alpha: 0.4),
              blurRadius: 8,
              spreadRadius: 1,
            ),
        ],
      ),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'Orbitron', // Estética militar
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
