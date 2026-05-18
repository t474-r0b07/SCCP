import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/constants/app_constants.dart';
import 'tron_grid.dart';

class DashboardInitializationOverlay extends StatefulWidget {
  final VoidCallback onInitializationComplete;
  final bool logosOnly;

  const DashboardInitializationOverlay({
    super.key,
    required this.onInitializationComplete,
    this.logosOnly = false,
  });

  @override
  State<DashboardInitializationOverlay> createState() =>
      _DashboardInitializationOverlayState();
}

class _DashboardInitializationOverlayState
    extends State<DashboardInitializationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _completionTimer;

  final List<String> _messages = [
    'INITIALIZING DASHBOARD SYSTEMS...',
    'LOADING OPERATIONAL DATA...',
    'ACTIVATING SURVEILLANCE NETWORKS...',
    'CALIBRATING TACTICAL DISPLAYS...',
    'SYNCHRONIZING REAL-TIME FEEDS...',
    'SYSTEM READY FOR COMMAND',
  ];

  int _currentMessageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: widget.logosOnly
          ? const Duration(seconds: 5)
          : const Duration(seconds: 3),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    if (widget.logosOnly) {
      _controller.repeat();
      _completionTimer = Timer(const Duration(seconds: 5), () {
        widget.onInitializationComplete();
      });
    } else {
      _controller.forward();
      _startMessageSequence();
    }
  }

  void _startMessageSequence() {
    _messageTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_currentMessageIndex < _messages.length - 1) {
        setState(() {
          _currentMessageIndex++;
        });
      } else {
        _messageTimer?.cancel();
        // Complete after showing final message
        Future.delayed(const Duration(seconds: 2), () {
          widget.onInitializationComplete();
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _messageTimer?.cancel();
    _completionTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.logosOnly) {
      return _ThreeLogoSplash(animation: _controller);
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          color: AppConstants.darkBg.withValues(alpha: 0.95),
          child: Stack(
            children: [
              // TronGrid background
              const Positioned.fill(child: TronGrid()),

              // Central content
              Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Container(
                      padding: const EdgeInsets.all(40),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppConstants.neonCyan.withValues(alpha: 0.5),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.neonCyan.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // SCCP Command Center logo
                          Container(
                            width: 100,
                            height: 100,
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  AppConstants.neonCyan.withValues(alpha: 0.8),
                                  AppConstants.neonCyan.withValues(alpha: 0.4),
                                  Colors.transparent,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConstants.neonCyan
                                      .withValues(alpha: 0.6),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // System status
                          Text(
                            'SCCP COMMAND CENTER',
                            style: TextStyle(
                              color: AppConstants.neonCyan,
                              fontSize: 24,
                              fontFamily: 'Orbitron',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Current message
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _messages[_currentMessageIndex],
                              style: TextStyle(
                                color: AppConstants.neonCyan,
                                fontSize: 16,
                                fontFamily: 'Orbitron',
                                letterSpacing: 1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                          const SizedBox(height: 30),

                          // Loading indicator
                          SizedBox(
                            width: 50,
                            height: 50,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppConstants.neonCyan,
                              ),
                              strokeWidth: 3,
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Progress text
                          Text(
                            '${((_currentMessageIndex + 1) / _messages.length * 100).round()}% COMPLETE',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'Rajdhani',
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Version info
              Positioned(
                bottom: 20,
                right: 20,
                child: Opacity(
                  opacity: _opacityAnimation.value,
                  child: Text(
                    'v${AppConstants.appVersion} - JARVIS',
                    style: TextStyle(
                      color: Colors.white30,
                      fontSize: 10,
                      fontFamily: 'Rajdhani',
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreeLogoSplash extends StatelessWidget {
  const _ThreeLogoSplash({required this.animation});

  final Animation<double> animation;

  static const _logos = [
    'assets/images/logo.png',
    'assets/images/logo2.png',
    'assets/images/logo3.png',
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFF000814)),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final size = MediaQuery.sizeOf(context);
          final compact = size.width < 430;
          final frameSize = compact ? 136.0 : 156.0;
          final logoPadding = compact ? 23.0 : 26.0;

          return Stack(
            children: [
              const Positioned.fill(child: TronGrid()),
              Positioned.fill(
                child: CustomPaint(
                  painter: _SplashScanlinePainter(animation.value),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.98 + (0.02 * _pulse(animation.value)),
                      child: SizedBox(
                        width: frameSize,
                        height: frameSize,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: Size.square(frameSize),
                              painter: _LogoRadarPainter(animation.value),
                            ),
                            Container(
                              width: frameSize,
                              height: frameSize,
                              padding: EdgeInsets.all(logoPadding),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppConstants.neonCyan
                                      .withValues(alpha: 0.9),
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppConstants.neonCyan
                                        .withValues(alpha: 0.45),
                                    blurRadius: 32,
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFFF0080)
                                        .withValues(alpha: 0.18),
                                    blurRadius: 46,
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: List.generate(_logos.length, (index) {
                                  final opacity =
                                      _cycleOpacity(animation.value, index);
                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.scale(
                                      scale: 0.94 + (opacity * 0.08),
                                      child: Image.asset(
                                        _logos[index],
                                        fit: BoxFit.contain,
                                        filterQuality: FilterQuality.high,
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'DTEX',
                      style: TextStyle(
                        color: AppConstants.neonCyan,
                        fontSize: compact ? 18 : 20,
                        fontFamily: 'Orbitron',
                        fontWeight: FontWeight.w800,
                        letterSpacing: 5,
                        shadows: [
                          Shadow(
                            color:
                                AppConstants.neonCyan.withValues(alpha: 0.85),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'SISTEMA DE DILIGENCIAS EXTERNAS',
                      style: TextStyle(
                        color: const Color(0xFFFF0080),
                        fontSize: compact ? 10 : 11,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.6,
                        shadows: [
                          Shadow(
                            color:
                                const Color(0xFFFF0080).withValues(alpha: 0.75),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppConstants.neonCyan,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _cycleOpacity(double value, int index) {
    final segment = 1 / _logos.length;
    final start = index * segment;
    final local = ((value - start) % 1.0 + 1.0) % 1.0;
    if (local > segment) return 0;
    final t = local / segment;
    if (t < 0.18) return t / 0.18;
    if (t < 0.74) return 1;
    return (1 - ((t - 0.74) / 0.26)).clamp(0.0, 1.0);
  }

  double _pulse(double value) {
    final v = (value * 2 - 1).abs();
    return 1 - v;
  }
}

class _LogoRadarPainter extends CustomPainter {
  const _LogoRadarPainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppConstants.neonCyan.withValues(alpha: 0.26);

    canvas.drawCircle(center, radius * 0.68, ringPaint);
    canvas.drawCircle(center, radius * 0.88, ringPaint);

    final sweepPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..color = AppConstants.neonCyan.withValues(alpha: 0.9);
    final rect = Rect.fromCircle(center: center, radius: radius * 0.99);
    canvas.drawArc(rect, value * 6.28318, 1.15, false, sweepPaint);
  }

  @override
  bool shouldRepaint(_LogoRadarPainter oldDelegate) =>
      oldDelegate.value != value;
}

class _SplashScanlinePainter extends CustomPainter {
  const _SplashScanlinePainter(this.value);

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * value;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          AppConstants.neonCyan.withValues(alpha: 0.72),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2));
    canvas.drawRect(Rect.fromLTWH(0, y - 1, size.width, 2), paint);
  }

  @override
  bool shouldRepaint(_SplashScanlinePainter oldDelegate) =>
      oldDelegate.value != value;
}
