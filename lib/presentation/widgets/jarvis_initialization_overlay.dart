// ============================================================================
// IRON MAN-STYLE ENTRANCE ANIMATION SYSTEM
// ============================================================================

import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/constants/app_constants.dart';
import 'tron_grid.dart';

class JarvisInitializationOverlay extends StatefulWidget {
  const JarvisInitializationOverlay({super.key});

  @override
  State<JarvisInitializationOverlay> createState() =>
      _JarvisInitializationOverlayState();
}

class _JarvisInitializationOverlayState
    extends State<JarvisInitializationOverlay> with TickerProviderStateMixin {
  late AnimationController _jarvisController;
  late AnimationController _particlesController;
  late AnimationController _energyPulseController;
  late Animation<double> _jarvisOpacity;
  late Animation<double> _particlesScale;
  late Animation<double> _energyPulse;

  final List<String> _jarvisLines = [
    'INITIALIZING SCCP COMMAND CENTER SYSTEMS...',
    'ACCESSING SCCP COMMAND CENTER SYSTEMS',
    'AUTHORIZATION PROTOCOLS: ACTIVE',
    'NEURAL LINK: ESTABLISHED',
    'SYSTEM INTEGRITY: 100%',
    'READY FOR OPERATOR INPUT',
  ];

  int _currentLineIndex = 0;
  String _displayText = '';
  int _charIndex = 0;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();

    // Jarvis text animation
    _jarvisController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _jarvisOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _jarvisController, curve: Curves.easeInOut),
    );

    // Particles animation
    _particlesController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _particlesScale = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _particlesController, curve: Curves.easeInOut),
    );

    // Energy pulse animation
    _energyPulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _energyPulse = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _energyPulseController, curve: Curves.easeInOut),
    );

    // Start Jarvis sequence
    _startJarvisSequence();

    // Auto-complete after full sequence
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        // Fade out overlay
        _jarvisController.reverse();
        Future.delayed(const Duration(milliseconds: 500), () {
          // This will be handled by parent widget
        });
      }
    });
  }

  void _startJarvisSequence() {
    _jarvisController.forward();

    // Start typing animation
    _typingTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_charIndex < _jarvisLines[_currentLineIndex].length) {
        setState(() {
          _displayText =
              _jarvisLines[_currentLineIndex].substring(0, _charIndex + 1);
          _charIndex++;
        });
      } else {
        // Line complete, wait then start next line
        Future.delayed(const Duration(milliseconds: 800), () {
          if (_currentLineIndex < _jarvisLines.length - 1) {
            _currentLineIndex++;
            _charIndex = 0;
            setState(() {
              _displayText = '';
            });
          } else {
            _typingTimer?.cancel();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _jarvisController.dispose();
    _particlesController.dispose();
    _energyPulseController.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final compact = size.width < 760 || size.shortestSide < 700;
    final ultraCompact = size.width < 430;
    final horizontalInset = ultraCompact ? 12.0 : (compact ? 20.0 : 50.0);
    final textBottom = ultraCompact ? 116.0 : (compact ? 132.0 : 150.0);
    final progressBottom = ultraCompact ? 22.0 : (compact ? 34.0 : 50.0);
    final panelPadding = ultraCompact ? 12.0 : (compact ? 16.0 : 20.0);
    final avatarSize = ultraCompact ? 38.0 : (compact ? 44.0 : 50.0);
    final avatarIconSize = ultraCompact ? 20.0 : (compact ? 24.0 : 28.0);
    final textSize = ultraCompact ? 12.0 : (compact ? 14.0 : 16.0);

    return AnimatedBuilder(
      animation: Listenable.merge(
          [_jarvisController, _particlesController, _energyPulseController]),
      builder: (context, child) {
        return Container(
          color: AppConstants.darkBg.withValues(alpha: 0.95),
          child: Stack(
            children: [
              // TronGrid background
              Positioned.fill(child: TronGrid()),

              // Holographic particles
              ..._buildHolographicParticles(
                screenSize: size,
                compact: compact,
                ultraCompact: ultraCompact,
              ),

              // Arc reactor energy core
              Center(
                child: _buildArcReactor(
                  compact: compact,
                  ultraCompact: ultraCompact,
                ),
              ),

              // Jarvis text overlay
              Positioned(
                bottom: textBottom,
                left: horizontalInset,
                right: horizontalInset,
                child: Opacity(
                  opacity: _jarvisOpacity.value,
                  child: Container(
                    padding: EdgeInsets.all(panelPadding),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.8),
                      border: Border.all(
                        color: AppConstants.neonCyan.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(compact ? 8 : 10),
                    ),
                    child: Column(
                      children: [
                        // Ultron-style AI avatar
                        Container(
                          width: avatarSize,
                          height: avatarSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                AppConstants.warningRed.withValues(alpha: 0.8),
                                AppConstants.warningRed.withValues(alpha: 0.4),
                                Colors.black,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(
                              color: AppConstants.warningRed,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppConstants.warningRed
                                    .withValues(alpha: 0.6),
                                blurRadius: 15,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Icon(
                              Icons
                                  .visibility, // Eye-like icon for AI surveillance
                              color: Colors.white,
                              size: avatarIconSize,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 10 : 15),
                        // Typing text
                        Text(
                          _displayText,
                          style: TextStyle(
                            color: AppConstants.neonCyan,
                            fontSize: textSize,
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.w500,
                            letterSpacing: compact ? 0.8 : 1,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        // Cursor
                        if (_typingTimer?.isActive ?? false)
                          Container(
                            margin: const EdgeInsets.only(top: 5),
                            width: 10,
                            height: 2,
                            color: AppConstants.neonCyan,
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Loading progress
              Positioned(
                bottom: progressBottom,
                left: horizontalInset,
                right: horizontalInset,
                child: Opacity(
                  opacity: _jarvisOpacity.value,
                  child: LinearProgressIndicator(
                    value: (_currentLineIndex +
                            (_charIndex /
                                _jarvisLines[_currentLineIndex].length)) /
                        _jarvisLines.length,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppConstants.neonCyan),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildHolographicParticles({
    required Size screenSize,
    required bool compact,
    required bool ultraCompact,
  }) {
    final particles = <Widget>[];
    final random = math.Random(42); // Fixed seed for consistent pattern
    final particleCount = ultraCompact ? 20 : (compact ? 30 : 50);

    for (int i = 0; i < particleCount; i++) {
      final size = random.nextDouble() * 4 + 2;
      final opacity = random.nextDouble() * 0.6 + 0.2;

      particles.add(
        Positioned(
          left: random.nextDouble() * screenSize.width,
          top: random.nextDouble() * screenSize.height,
          child: AnimatedBuilder(
            animation: _particlesController,
            builder: (context, child) {
              return Opacity(
                opacity: opacity * _particlesScale.value * _jarvisOpacity.value,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: AppConstants.neonCyan,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppConstants.neonCyan.withValues(alpha: 0.8),
                        blurRadius: 8 * _energyPulse.value,
                        spreadRadius: 2 * _energyPulse.value,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    return particles;
  }

  Widget _buildArcReactor({
    required bool compact,
    required bool ultraCompact,
  }) {
    final outerSize = ultraCompact ? 136.0 : (compact ? 168.0 : 200.0);
    final innerSize = ultraCompact ? 54.0 : (compact ? 66.0 : 80.0);
    final iconSize = ultraCompact ? 28.0 : (compact ? 34.0 : 40.0);

    return AnimatedBuilder(
      animation: _energyPulseController,
      builder: (context, child) {
        return Container(
          width: outerSize,
          height: outerSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppConstants.neonCyan
                    .withValues(alpha: 0.8 * _energyPulse.value),
                AppConstants.neonCyan
                    .withValues(alpha: 0.4 * _energyPulse.value),
                Colors.transparent,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppConstants.neonCyan
                    .withValues(alpha: 0.6 * _energyPulse.value),
                blurRadius: 50,
                spreadRadius: 20,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: innerSize,
              height: innerSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white
                        .withValues(alpha: 0.8 * _energyPulse.value),
                    blurRadius: 30,
                    spreadRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Icons.power,
                color: AppConstants.darkBg,
                size: iconSize,
              ),
            ),
          ),
        );
      },
    );
  }
}
