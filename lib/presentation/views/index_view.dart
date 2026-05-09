import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/tron_grid.dart';
import '../../core/constants/app_constants.dart';
import 'dart:math';

class IndexView extends StatefulWidget {
  const IndexView({super.key});

  @override
  State<IndexView> createState() => _IndexViewState();
}

class _IndexViewState extends State<IndexView> with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _backgroundController;
  late AnimationController _depthController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _backgroundRotationAnimation;
  late Animation<double> _depthAnimation;

  @override
  void initState() {
    super.initState();

    // Logo animation controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // Background perspective animation
    _backgroundController = AnimationController(
      duration: const Duration(milliseconds: 8000),
      vsync: this,
    )..repeat(reverse: true);

    // Depth animation for 3D effects
    _depthController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    )..repeat(reverse: true);

    // Scale animation - CORREGIDO: de 0.8 a 1.0 (mucho más controlado)
    _logoScaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Opacity animation
    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    // Background rotation for perspective effect
    _backgroundRotationAnimation = Tween<double>(begin: -0.1, end: 0.1).animate(
      CurvedAnimation(parent: _backgroundController, curve: Curves.slowMiddle),
    );

    // Depth animation for 3D layering
    _depthAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _depthController, curve: Curves.easeInOut),
    );

    // Start animations
    _logoController.forward();
    _backgroundController.forward();
    _depthController.forward();

    // Navigate to login after animation completes
    Future.delayed(const Duration(seconds: 4), () {
      Get.offNamed('/login');
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _backgroundController.dispose();
    _depthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;
    final compact = media.width < 980 || media.shortestSide < 760;
    final ultraCompact = media.width < 430 || media.height < 780;
    final cardOuterMargin = ultraCompact ? 12.0 : (compact ? 18.0 : 40.0);
    final cardWidth = compact
        ? (media.width * (ultraCompact ? 0.90 : 0.86)).clamp(260.0, 420.0)
        : (media.width - (cardOuterMargin * 2)).clamp(320.0, 500.0);
    final cardMaxHeight = compact
        ? (media.height * (ultraCompact ? 0.74 : 0.78)).clamp(360.0, 560.0)
        : (media.height - 40.0).clamp(420.0, 620.0);
    final cardVerticalMargin = ultraCompact ? 6.0 : (compact ? 10.0 : 12.0);
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: Stack(
        children: [
          // Animated Perspective Background
          AnimatedBuilder(
            animation: Listenable.merge([
              _backgroundController,
              _depthController,
            ]),
            builder: (context, child) {
              return Transform(
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.001) // Perspective
                  ..rotateX(_backgroundRotationAnimation.value * 0.5)
                  ..rotateY(_backgroundRotationAnimation.value)
                  ..multiply(Matrix4.diagonal3Values(_depthAnimation.value,
                      _depthAnimation.value, _depthAnimation.value)),
                alignment: Alignment.center,
                child: Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppConstants.darkBg,
                        AppConstants.darkBg.withValues(alpha: 0.8),
                        AppConstants.neonCyan.withValues(alpha: 0.05),
                        AppConstants.darkBg,
                      ],
                      stops: const [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Tron Grid with perspective
                      Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.002)
                          ..rotateZ(_backgroundRotationAnimation.value * 0.1),
                        alignment: Alignment.center,
                        child: Opacity(
                          opacity: 0.3 + (_depthAnimation.value - 0.8) * 0.5,
                          child: const TronGrid(),
                        ),
                      ),

                      // Floating geometric shapes for depth
                      ...List.generate(compact ? 5 : 8, (index) {
                        final count = compact ? 5 : 8;
                        final angle = (index / count) * 2 * 3.14159;
                        final radius = (compact ? 110.0 : 200.0) +
                            (index * (compact ? 18.0 : 30.0));
                        final x = MediaQuery.of(context).size.width / 2 +
                            radius *
                                cos(angle +
                                    _backgroundRotationAnimation.value * 2);
                        final y = MediaQuery.of(context).size.height / 2 +
                            radius *
                                sin(angle +
                                    _backgroundRotationAnimation.value * 2);

                        return Positioned(
                          left: x - 20,
                          top: y - 20,
                          child: Transform.rotate(
                            angle: angle + _backgroundRotationAnimation.value,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppConstants.neonCyan
                                      .withValues(alpha: 0.1 + (index * 0.05)),
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),

          // VENTANA FLOTANTE HUD CENTRADA - GLASSMORPHISM
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _logoController,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoOpacityAnimation.value,
                    child: Container(
                      width: cardWidth.toDouble(),
                      constraints: BoxConstraints(
                        maxHeight: cardMaxHeight.toDouble(),
                      ),
                      margin: EdgeInsets.symmetric(
                        horizontal: cardOuterMargin,
                        vertical: cardVerticalMargin,
                      ),
                      padding: EdgeInsets.all(
                          ultraCompact ? 18 : (compact ? 24 : 40)),
                      decoration: BoxDecoration(
                        // Glassmorphism effect
                        color: AppConstants.darkBg.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: AppConstants.neonCyan.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.neonCyan.withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                          BoxShadow(
                            color: AppConstants.neonPink.withValues(alpha: 0.1),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      // Backdrop blur simulado con gradientes
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.05),
                              Colors.white.withValues(alpha: 0.02),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Logo con tamaño apropiado
                            AnimatedBuilder(
                              animation: Listenable.merge([
                                _logoController,
                                _backgroundController,
                              ]),
                              builder: (context, child) {
                                return Transform(
                                  transform: Matrix4.identity()
                                    ..setEntry(3, 2, 0.001)
                                    ..rotateY(
                                        _backgroundRotationAnimation.value *
                                            0.2)
                                    ..multiply(Matrix4.diagonal3Values(
                                        _logoScaleAnimation.value,
                                        _logoScaleAnimation.value,
                                        _logoScaleAnimation.value)),
                                  alignment: Alignment.center,
                                  child: Container(
                                    width: ultraCompact
                                        ? 96
                                        : (compact ? 118 : 140),
                                    height: ultraCompact
                                        ? 96
                                        : (compact ? 118 : 140),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          AppConstants.neonCyan
                                              .withValues(alpha: 0.2),
                                          AppConstants.neonCyan
                                              .withValues(alpha: 0.1),
                                          Colors.transparent,
                                        ],
                                      ),
                                      border: Border.all(
                                        color: AppConstants.neonCyan
                                            .withValues(alpha: 0.4),
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppConstants.neonCyan
                                              .withValues(alpha: 0.3),
                                          blurRadius: 30,
                                          spreadRadius: 5,
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                        ultraCompact ? 12 : (compact ? 16 : 20),
                                      ),
                                      child: Image.asset(
                                        'assets/images/logo-alfa.png',
                                        width: ultraCompact
                                            ? 64
                                            : (compact ? 80 : 100),
                                        height: ultraCompact
                                            ? 64
                                            : (compact ? 80 : 100),
                                        fit: BoxFit.contain,
                                        errorBuilder:
                                            (context, error, stackTrace) {
                                          return ShaderMask(
                                            shaderCallback: (bounds) =>
                                                LinearGradient(
                                              colors: [
                                                AppConstants.neonCyan,
                                                AppConstants.neonPink,
                                              ],
                                            ).createShader(bounds),
                                            child: Text(
                                              'SCCP',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: ultraCompact
                                                    ? 24
                                                    : (compact ? 34 : 42),
                                                fontFamily: 'Orbitron',
                                                fontWeight: FontWeight.bold,
                                                shadows: [
                                                  Shadow(
                                                    color: AppConstants.neonCyan
                                                        .withValues(alpha: 0.8),
                                                    blurRadius: 20,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            SizedBox(
                                height:
                                    ultraCompact ? 16 : (compact ? 24 : 32)),

                            // Título con tamaño apropiado
                            Text(
                              'COMMAND CENTER',
                              style: TextStyle(
                                color: AppConstants.neonCyan,
                                fontSize:
                                    ultraCompact ? 18 : (compact ? 21 : 24),
                                fontFamily: 'Orbitron',
                                fontWeight: FontWeight.bold,
                                letterSpacing:
                                    ultraCompact ? 1.6 : (compact ? 2.2 : 3),
                                shadows: [
                                  Shadow(
                                    color: AppConstants.neonCyan
                                        .withValues(alpha: 0.8),
                                    blurRadius: 20,
                                    offset: const Offset(0, 0),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),

                            SizedBox(height: ultraCompact ? 8 : 12),

                            // Subtítulo con line break y tamaño controlado
                            Text(
                              'SISTEMA DE CONTROL Y\nMONITOREO POLICIAL',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize:
                                    ultraCompact ? 9 : (compact ? 10 : 12),
                                fontFamily: 'Rajdhani',
                                letterSpacing: ultraCompact ? 1.0 : 1.5,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                                shadows: [
                                  Shadow(
                                    color: AppConstants.neonCyan
                                        .withValues(alpha: 0.3),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),

                            SizedBox(
                                height:
                                    ultraCompact ? 18 : (compact ? 26 : 40)),

                            // Loading indicator
                            Column(
                              children: [
                                Container(
                                  width:
                                      ultraCompact ? 38 : (compact ? 44 : 50),
                                  height:
                                      ultraCompact ? 38 : (compact ? 44 : 50),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppConstants.neonCyan
                                          .withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppConstants.neonCyan
                                            .withValues(alpha: 0.3),
                                        blurRadius: 20,
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(
                                      ultraCompact ? 6 : (compact ? 7 : 8),
                                    ),
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppConstants.neonCyan,
                                      ),
                                      strokeWidth: ultraCompact ? 2.0 : 2.5,
                                    ),
                                  ),
                                ),
                                SizedBox(height: ultraCompact ? 12 : 20),
                                Text(
                                  'INICIALIZANDO SISTEMAS...',
                                  style: TextStyle(
                                    color: AppConstants.neonCyan
                                        .withValues(alpha: 0.9),
                                    fontSize:
                                        ultraCompact ? 9 : (compact ? 10 : 11),
                                    fontFamily: 'Rajdhani',
                                    letterSpacing: ultraCompact ? 1.0 : 1.5,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        color: AppConstants.neonCyan
                                            .withValues(alpha: 0.5),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // Enhanced version info with glow
          Positioned(
            bottom: ultraCompact ? 12 : (compact ? 18 : 30),
            right: ultraCompact ? 12 : (compact ? 18 : 30),
            child: AnimatedBuilder(
              animation: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacityAnimation.value * 0.6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppConstants.darkBg.withValues(alpha: 0.5),
                      border: Border.all(
                        color: AppConstants.neonCyan.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.neonCyan.withValues(alpha: 0.2),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Text(
                      'v${AppConstants.appVersion}',
                      style: TextStyle(
                        color: AppConstants.neonCyan.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
