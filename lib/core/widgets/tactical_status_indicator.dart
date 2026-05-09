import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

class TacticalStatusIndicator extends StatefulWidget {
  final String status;
  final Color color;
  final double size;
  final bool pulse;

  const TacticalStatusIndicator({
    super.key,
    required this.status,
    required this.color,
    this.size = 8.0,
    this.pulse = false,
  });

  @override
  State<TacticalStatusIndicator> createState() =>
      _TacticalStatusIndicatorState();
}

class _TacticalStatusIndicatorState extends State<TacticalStatusIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: AppConstants.pulseDuration,
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.pulse) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(TacticalStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.pulse != oldWidget.pulse) {
      if (widget.pulse) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: widget.pulse ? _pulseAnimation.value : 1.0,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color,
              boxShadow: [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.6),
                  blurRadius:
                      widget.pulse ? 8 + (_pulseAnimation.value * 4) : 4,
                  spreadRadius:
                      widget.pulse ? 2 + (_pulseAnimation.value * 2) : 1,
                ),
              ],
            ),
            child: widget.status == "critical"
                ? Icon(
                    Icons.warning,
                    color: Colors.white,
                    size: widget.size * 0.6,
                  )
                : widget.status == "warning"
                    ? Icon(
                        Icons.error_outline,
                        color: Colors.white,
                        size: widget.size * 0.6,
                      )
                    : widget.status == "success"
                        ? Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: widget.size * 0.6,
                          )
                        : null,
          ),
        );
      },
    );
  }
}
