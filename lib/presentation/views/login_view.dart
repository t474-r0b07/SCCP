import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'dart:ui';
import '../../core/constants/app_constants.dart';
import '../controllers/auth_controller.dart';
import '../widgets/pin_pad.dart';
import '../widgets/tron_grid.dart';
import '../widgets/scanner_overlay.dart';
import '../widgets/jarvis_initialization_overlay.dart';

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView>
    with SingleTickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _showJarvisOverlay = true;
  late AnimationController _energyController;
  late final AuthController _authController;

  @override
  void initState() {
    super.initState();
    _authController = Get.find<AuthController>();
    _energyController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    // Hide Jarvis overlay after initialization
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _showJarvisOverlay = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _energyController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    setState(() => _isLoading = true);
    try {
      final username = _usernameController.text.trim();
      final password = _passwordController.text.trim();

      if (username.isEmpty || password.isEmpty) {
        setState(() => _isLoading = false);
        Get.snackbar('SISTEMA', 'CREDENTIAL_FAILURE: Datos requeridos',
            backgroundColor: Colors.redAccent.withValues(alpha: 0.4),
            colorText: Colors.white,
            margin: const EdgeInsets.all(20));
        return;
      }

      if (!GetUtils.isEmail(username)) {
        setState(() => _isLoading = false);
        Get.snackbar(
          'SISTEMA',
          'INGRESE CORREO DE ADMINISTRADOR (NO ID DE OFICIAL)',
          backgroundColor: Colors.orangeAccent.withValues(alpha: 0.35),
          colorText: Colors.white,
          margin: const EdgeInsets.all(20),
        );
        return;
      }

      final ok = await _authController.login(
        email: username,
        password: password,
      );

      if (ok) {
        await _waitForJarvisOverlayToFinish();
        if (_authController.isDirector) {
          final pinOk = await _showDirectorPinDialog();
          if (!pinOk) {
            await _authController.logout();
            return;
          }
          Get.offAllNamed('/dashboard-commander');
        } else {
          Get.offAllNamed('/dashboard-supervisor');
        }
      } else {
        Get.snackbar('SISTEMA', 'ACCESO DENEGADO O PERFIL NO AUTORIZADO',
            backgroundColor: Colors.redAccent.withValues(alpha: 0.4),
            colorText: Colors.white,
            margin: const EdgeInsets.all(20));
      }
    } catch (e) {
      Get.snackbar('ERROR DE TERMINAL', e.toString(),
          backgroundColor: Colors.redAccent.withValues(alpha: 0.4),
          colorText: Colors.white);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _waitForJarvisOverlayToFinish() async {
    if (!_showJarvisOverlay) return;
    while (mounted && _showJarvisOverlay) {
      await Future.delayed(const Duration(milliseconds: 150));
    }
  }

  Future<bool> _showDirectorPinDialog() async {
    bool success = false;
    await Get.dialog(
      Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppConstants.neonCyan.withValues(alpha: 0.45),
            ),
          ),
          child: PinPad(
            title: 'VALIDACION DIRECTOR',
            onComplete: (pin) async {
              final ok = await _authController.verifyDirectorPin(pin);
              if (ok) {
                success = true;
                Get.back();
              } else {
                final lockSeconds = _authController.pinLockRemainingSeconds;
                final msg = lockSeconds > 0
                    ? 'PIN BLOQUEADO TEMPORALMENTE ($lockSeconds s)'
                    : 'PIN INCORRECTO';
                Get.snackbar(
                  'SEGURIDAD',
                  msg,
                  backgroundColor: Colors.redAccent.withValues(alpha: 0.35),
                  colorText: Colors.white,
                );
              }
            },
          ),
        ),
      ),
      barrierDismissible: false,
    );
    return success;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Main login interface
        _buildMainLoginInterface(),

        // Jarvis initialization overlay (shows first)
        if (_showJarvisOverlay) JarvisInitializationOverlay(),
      ],
    );
  }

  Widget _buildMainLoginInterface() {
    return Scaffold(
      backgroundColor: AppConstants.darkBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 760;
          final ultraCompact = constraints.maxWidth < 430;
          final containerWidth = ultraCompact
              ? (constraints.maxWidth - 16).clamp(230.0, 360.0)
              : compact
                  ? (constraints.maxWidth - 24).clamp(260.0, 430.0)
                  : 460.0;
          final horizontalPadding = ultraCompact ? 16.0 : (compact ? 22.0 : 45.0);
          final verticalPadding = ultraCompact ? 20.0 : (compact ? 28.0 : 60.0);
          final mainSpacing = ultraCompact ? 18.0 : (compact ? 26.0 : 50.0);
          final sectionSpacing = ultraCompact ? 12.0 : (compact ? 18.0 : 25.0);
          final helperTextSize = ultraCompact ? 9.0 : (compact ? 10.0 : 12.0);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Same TronGrid background as dashboard
              const Positioned.fill(child: TronGrid()),
              _buildCoreGlow(compact: compact || ultraCompact),
              Center(
                child: SingleChildScrollView(
                  padding:
                      EdgeInsets.symmetric(horizontal: compact ? 10 : 0, vertical: 10),
                  child: _buildCyberContainer(
                    width: containerWidth,
                    horizontalPadding: horizontalPadding,
                    verticalPadding: verticalPadding,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildBrandSection(
                          compact: compact,
                          ultraCompact: ultraCompact,
                        ),
                        SizedBox(height: mainSpacing),
                        _buildTacticalInput(
                          controller: _usernameController,
                          label: 'ADMIN_EMAIL',
                          icon: Icons.account_circle_outlined,
                          keyboardType: TextInputType.emailAddress,
                          compact: compact,
                          ultraCompact: ultraCompact,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Use el correo habilitado en allowed_admins',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: helperTextSize,
                            color: AppConstants.neonCyan.withValues(alpha: 0.75),
                            letterSpacing: compact ? 0.8 : 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: sectionSpacing),
                        _buildTacticalInput(
                          controller: _passwordController,
                          label: 'ACCESS_KEY',
                          icon: Icons.vpn_key_outlined,
                          isPass: true,
                          compact: compact,
                          ultraCompact: ultraCompact,
                        ),
                        SizedBox(height: mainSpacing),
                        _buildAuthButton(
                          compact: compact,
                          ultraCompact: ultraCompact,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Efecto scanner sobre toda la pantalla
              const ScannerOverlay(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoreGlow({bool compact = false}) {
    return AnimatedBuilder(
      animation: _energyController,
      builder: (context, child) {
        return Container(
          width: compact ? 340 : 500,
          height: compact ? 340 : 500,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                AppConstants.neonCyan
                    .withValues(alpha: 0.15 * _energyController.value),
                Colors.transparent,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCyberContainer({
    required Widget child,
    required double width,
    required double horizontalPadding,
    required double verticalPadding,
  }) {
    return CustomPaint(
      painter: _TronFramePainter(pulse: _energyController.value),
      child: ClipPath(
        clipper: _OctagonalClipper(),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: width,
            padding: EdgeInsets.symmetric(
              horizontal: horizontalPadding,
              vertical: verticalPadding,
            ),
            color: Colors.black.withValues(alpha: 0.4),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _buildBrandSection({
    bool compact = false,
    bool ultraCompact = false,
  }) {
    final logoSize = ultraCompact ? 58.0 : (compact ? 72.0 : 90.0);
    final titleSize = ultraCompact ? 24.0 : (compact ? 34.0 : 50.0);
    final titleSpacing = ultraCompact ? 4.0 : (compact ? 7.0 : 15.0);
    final subtitleSize = ultraCompact ? 9.0 : (compact ? 10.0 : 12.0);
    final subtitleSpacing = ultraCompact ? 1.4 : (compact ? 2.2 : 4.0);
    return Column(
      children: [
        AnimatedBuilder(
          animation: _energyController,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.neonCyan
                        .withValues(alpha: 0.6 * _energyController.value),
                    blurRadius: 40, // Más brillo neón
                    spreadRadius: 8,
                  ),
                ],
              ),
              child: Image.asset(
                'assets/images/logo.png',
                height: logoSize,
                width: logoSize,
                fit: BoxFit.contain,
              ),
            );
          },
        ),
        SizedBox(height: ultraCompact ? 6 : (compact ? 8 : 10)),
        Text('SCCP',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: titleSize,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: titleSpacing,
              shadows: [
                Shadow(
                    color: AppConstants.neonCyan.withValues(alpha: 0.8),
                    blurRadius: 15),
              ],
            )),
        Text('CENTRAL COMMAND ACCESS',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: subtitleSize,
              color: AppConstants.neonCyan.withValues(alpha: 0.8),
              letterSpacing: subtitleSpacing,
            )),
      ],
    );
  }

  Widget _buildTacticalInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPass = false,
    TextInputType? keyboardType,
    bool compact = false,
    bool ultraCompact = false,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: ultraCompact ? 10 : (compact ? 12 : 15)),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(
            color: AppConstants.neonCyan.withValues(alpha: 0.8),
            width: ultraCompact ? 1.4 : (compact ? 1.6 : 2.0)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        keyboardType: keyboardType,
        autocorrect: false,
        enableSuggestions: !isPass,
        textCapitalization: TextCapitalization.none,
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Rajdhani',
          fontSize: ultraCompact ? 14 : (compact ? 16 : 18),
        ),
        decoration: InputDecoration(
          icon: Icon(
            icon,
            color: AppConstants.neonCyan,
            size: ultraCompact ? 16 : (compact ? 18 : 20),
          ),
          labelText: label,
          labelStyle: TextStyle(
              color: AppConstants.neonCyan.withValues(alpha: 0.7),
              fontSize: ultraCompact ? 9 : (compact ? 10 : 11),
              letterSpacing: 2),
          border: InputBorder.none,
          contentPadding:
              EdgeInsets.symmetric(vertical: ultraCompact ? 8 : (compact ? 10 : 12)),
        ),
      ),
    );
  }

  Widget _buildAuthButton({
    bool compact = false,
    bool ultraCompact = false,
  }) {
    return InkWell(
      onTap: _isLoading ? null : _login,
      child: AnimatedBuilder(
        animation: _energyController,
        builder: (context, child) {
          return Container(
            height: ultraCompact ? 46 : (compact ? 52 : 60),
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppConstants.neonCyan.withValues(alpha: 0.05),
              border: Border.all(
                color: AppConstants.neonCyan
                    .withValues(alpha: 0.8 + (0.2 * _energyController.value)),
                width: ultraCompact ? 1.8 : (compact ? 2.2 : 3),
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                // Glow exterior reducido
                BoxShadow(
                  color: AppConstants.neonCyan
                      .withValues(alpha: 0.4 * _energyController.value),
                  blurRadius: 15,
                  spreadRadius: 2,
                ),
                // Glow medio reducido
                BoxShadow(
                  color: AppConstants.neonCyan
                      .withValues(alpha: 0.3 * _energyController.value),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
                // Núcleo blanco reducido
                BoxShadow(
                  color: Colors.white
                      .withValues(alpha: 0.2 * _energyController.value),
                  blurRadius: 6,
                  spreadRadius: 0.5,
                ),
              ],
            ),
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(
                      color: AppConstants.neonCyan)
                  : Text('AUTHORIZE SYSTEM',
                      style: TextStyle(
                        fontFamily: 'Orbitron',
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: ultraCompact ? 1.4 : (compact ? 2.2 : 4),
                        fontSize: ultraCompact ? 10.5 : (compact ? 12 : 14),
                        shadows: [
                          Shadow(
                              color: AppConstants.neonCyan,
                              blurRadius: 10 * _energyController.value),
                        ],
                      )),
            ),
          );
        },
      ),
    );
  }
}

class _OctagonalClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    double n = 30.0;
    return Path()
      ..moveTo(n, 0)
      ..lineTo(size.width - n, 0)
      ..lineTo(size.width, n)
      ..lineTo(size.width, size.height - n)
      ..lineTo(size.width - n, size.height)
      ..lineTo(n, size.height)
      ..lineTo(0, size.height - n)
      ..lineTo(0, n)
      ..close();
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _TronFramePainter extends CustomPainter {
  final double pulse;
  _TronFramePainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    const n = 30.0;
    final path = Path()
      ..moveTo(n, 0)
      ..lineTo(size.width - n, 0)
      ..lineTo(size.width, n)
      ..lineTo(size.width, size.height - n)
      ..lineTo(size.width - n, size.height)
      ..lineTo(n, size.height)
      ..lineTo(0, size.height - n)
      ..lineTo(0, n)
      ..close();

    // Capa 1: Resplandor exterior (Glow reducido)
    final glowPaint = Paint()
      ..color = AppConstants.neonCyan.withValues(alpha: 0.4 * pulse)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..maskFilter =
          const MaskFilter.blur(BlurStyle.normal, 10); // Glow más suave

    canvas.drawPath(path, glowPaint);

    // Capa 2: Resplandor medio (Capa intermedia reducida)
    final midGlowPaint = Paint()
      ..color = AppConstants.neonCyan.withValues(alpha: 0.3 * pulse)
      ..strokeWidth = 5.0
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawPath(path, midGlowPaint);

    // Capa 3: Línea base brillante
    final basePaint = Paint()
      ..color = AppConstants.neonCyan.withValues(alpha: 0.7 + (pulse * 0.2))
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, basePaint);

    // Capa 4: Núcleo de luz blanca (Brillo moderado)
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6 * pulse)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, corePaint);

    // Muescas decorativas con glow moderado
    final detailPaint = Paint()
      ..color = AppConstants.neonCyan.withValues(alpha: 0.8)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    canvas.drawLine(Offset(n, 0), Offset(n, -15), detailPaint);
    canvas.drawLine(Offset(size.width - n, size.height),
        Offset(size.width - n, size.height + 15), detailPaint);

    // Líneas de energía cruzadas
    final energyPaint = Paint()
      ..color = AppConstants.neonCyan.withValues(alpha: 0.7 * pulse)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, n), Offset(-10, n), energyPaint);
    canvas.drawLine(Offset(size.width, size.height - n),
        Offset(size.width + 10, size.height - n), energyPaint);
  }

  @override
  bool shouldRepaint(covariant _TronFramePainter oldDelegate) => true;
}
