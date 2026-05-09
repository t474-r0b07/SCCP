import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/constants/app_constants.dart';
import 'tron_grid.dart';

class DashboardInitializationOverlay extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const DashboardInitializationOverlay({
    super.key,
    required this.onInitializationComplete,
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
      duration: const Duration(seconds: 3),
      vsync: this,
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();
    _startMessageSequence();
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                          // Stark Industries style logo
                          Container(
                            width: 100,
                            height: 100,
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
                            child: const Icon(
                              Icons.power_settings_new,
                              color: Colors.white,
                              size: 50,
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
