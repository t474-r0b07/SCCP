// ═══════════════════════════════════════════════════════════════════════════
//  DTEX SUPERVISOR — Restyled con lenguaje visual SCCP HUD
//  Toda la lógica y funciones originales se preservan intactas.
//  Solo se modifica la capa de presentación (UI/UX).
// ═══════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/services/radio_rtc_signaling.dart';
import '../../core/utils/grado_assets.dart';
import '../../data/models/dtex_alerta_model.dart';
import '../../data/models/dtex_destino_model.dart';
import '../../data/models/dtex_mision_model.dart';
import '../../data/models/parte_sorpresa_model.dart';
import '../../data/models/dtex_policia_model.dart';
import '../../data/models/radio_message_model.dart';
import '../../data/models/dtex_tracking_extension_model.dart';
import '../../data/repositories/supabase_repository.dart';
import '../controllers/auth_controller.dart';
import '../controllers/dtex_controller.dart';
import '../widgets/dashboard_initialization_overlay.dart';

// ─── PALETA HUD DTEX ────────────────────────────────────────────────────────
// Se mantienen las constantes originales de AppConstants pero se añaden
// alias semánticos HUD para legibilidad interna.
const _kCyan = AppConstants.neonCyan; // Color primario
const _kRed = AppConstants.warningRed; // Emergencia
const _kGreen = AppConstants.successGreen; // OK / en destino
const _kOrange = AppConstants.alertOrange; // Advertencia
const _kDark = AppConstants.darkBg; // Fondo base
const _kTarijaCenter = LatLng(-21.5355, -64.7296); // Tarija, Bolivia

// ─── TIPOGRAFÍA HUD ─────────────────────────────────────────────────────────
TextStyle _hudTitle({double fontSize = 18, Color color = _kCyan}) => TextStyle(
      fontFamily: 'Orbitron',
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
      color: color,
    );

TextStyle _hudSubtitle({double fontSize = 13}) => TextStyle(
      fontFamily: 'Rajdhani',
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: Colors.white.withValues(alpha: 0.75),
    );

TextStyle _hudMuted({double fontSize = 12}) => TextStyle(
      fontFamily: 'Rajdhani',
      fontSize: fontSize,
      letterSpacing: 0.5,
      color: Colors.white.withValues(alpha: 0.5),
    );

String _gradeAbbreviation(String grado) => GradoAssets.abbreviation(grado);

Widget _gradeIcon(String grado, {double size = 28}) {
  return Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.22),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _kCyan.withValues(alpha: 0.34)),
    ),
    child: Image.asset(
      GradoAssets.iconAsset(grado),
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const Icon(
        Icons.military_tech_rounded,
        color: _kCyan,
        size: 18,
      ),
    ),
  );
}

// ─── GLASS PANEL HUD ────────────────────────────────────────────────────────
Widget _hudPanel({
  required Widget child,
  EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  Color borderColor = _kCyan,
  double borderOpacity = 0.22,
  BorderRadius? borderRadius,
}) {
  return Container(
    padding: padding,
    decoration: BoxDecoration(
      color: const Color(0xFF07101B).withValues(alpha: 0.82),
      borderRadius: borderRadius ?? BorderRadius.circular(14),
      border: Border.all(
        color: borderColor.withValues(alpha: borderOpacity),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: borderColor.withValues(alpha: 0.07),
          blurRadius: 18,
          spreadRadius: 0,
        ),
      ],
    ),
    child: child,
  );
}

// ─── CORNER BRACKET DECORATION ──────────────────────────────────────────────
// Marcos de esquinas estilo HUD táctico.
class _HudCornerBracket extends StatelessWidget {
  final Widget child;
  final Color color;
  final double size;

  const _HudCornerBracket({
    required this.child,
    this.color = _kCyan,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CornerPainter(color: color, size: size, stroke: 1.4),
      child: child,
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double size;
  final double stroke;

  const _CornerPainter({
    required this.color,
    required this.size,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size s) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    // Top-left
    canvas.drawLine(Offset(0, size), const Offset(0, 0), paint);
    canvas.drawLine(const Offset(0, 0), Offset(size, 0), paint);

    // Top-right
    canvas.drawLine(Offset(s.width - size, 0), Offset(s.width, 0), paint);
    canvas.drawLine(Offset(s.width, 0), Offset(s.width, size), paint);

    // Bottom-left
    canvas.drawLine(Offset(0, s.height - size), Offset(0, s.height), paint);
    canvas.drawLine(Offset(0, s.height), Offset(size, s.height), paint);

    // Bottom-right
    canvas.drawLine(
        Offset(s.width - size, s.height), Offset(s.width, s.height), paint);
    canvas.drawLine(
        Offset(s.width, s.height - size), Offset(s.width, s.height), paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) =>
      old.color != color || old.size != size || old.stroke != stroke;
}

// ─── SCAN LINE OVERLAY ──────────────────────────────────────────────────────
class _ScanLineOverlay extends StatelessWidget {
  final Widget child;
  const _ScanLineOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        IgnorePointer(
          child: CustomPaint(
            painter: _ScanLinePainter(),
            child: const SizedBox.expand(),
          ),
        ),
      ],
    );
  }
}

class _ScanLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.015)
      ..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanLinePainter _) => false;
}

// ─── INPUT DECORATION HUD ───────────────────────────────────────────────────
InputDecoration _hudInputDecoration(String label, {IconData? prefixIcon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: TextStyle(
      fontFamily: 'Rajdhani',
      color: _kCyan.withValues(alpha: 0.7),
      fontSize: 13,
      letterSpacing: 0.8,
    ),
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: _kCyan.withValues(alpha: 0.6), size: 18)
        : null,
    filled: true,
    fillColor: const Color(0x7A07101B),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kCyan),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: _kCyan.withValues(alpha: 0.28)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _kCyan, width: 1.4),
    ),
  );
}

// ─── PULSING BADGE ──────────────────────────────────────────────────────────
class _PulsingDot extends StatefulWidget {
  final Color color;
  final double size;
  const _PulsingDot({this.color = _kGreen, this.size = 8});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.6 * _ctrl.value),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── ANIMATED METRIC CARD ───────────────────────────────────────────────────
class _HudMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _HudMetric({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return _hudPanel(
      borderColor: color,
      borderOpacity: 0.3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color.withValues(alpha: 0.8), size: 14),
              const SizedBox(width: 5),
              Text(label.toUpperCase(), style: _hudMuted(fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: _hudTitle(fontSize: 28, color: color)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// APP ROOT (sin cambios de lógica)
// ─────────────────────────────────────────────

class DtexSupervisorAndroidApp extends StatelessWidget {
  const DtexSupervisorAndroidApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'DTEX Supervisor',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const _DtexSupervisorSplashGate(),
    );
  }
}

class _DtexSupervisorSplashGate extends StatefulWidget {
  const _DtexSupervisorSplashGate();

  @override
  State<_DtexSupervisorSplashGate> createState() =>
      _DtexSupervisorSplashGateState();
}

class _DtexSupervisorSplashGateState extends State<_DtexSupervisorSplashGate> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return DashboardInitializationOverlay(
        logosOnly: true,
        onInitializationComplete: () {
          if (mounted) {
            setState(() => _showSplash = false);
          }
        },
      );
    }

    return const DtexSupervisorRoot();
  }
}

class DtexSupervisorRoot extends StatelessWidget {
  const DtexSupervisorRoot({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (!auth.isInitialized.value) {
        return DashboardInitializationOverlay(
          logosOnly: true,
          onInitializationComplete: () {},
        );
      }
      final admin = auth.currentAdmin.value;
      if (admin == null) return DtexSupervisorLogin(auth: auth);
      if (!admin.tieneAccesoDtex) {
        return _HudAccessDeniedScreen();
      }
      if (!Get.isRegistered<DtexController>()) {
        Get.put(DtexController(), permanent: true);
      }
      return DtexSupervisorHome(auth: auth, controller: Get.find());
    });
  }
}

// ─── PANTALLA SIN ACCESO ────────────────────────────────────────────────────
class _HudAccessDeniedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _ScanLineOverlay(
      child: Scaffold(
        backgroundColor: _kDark,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: _HudCornerBracket(
              color: _kRed,
              size: 20,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_rounded, color: _kRed, size: 52),
                    const SizedBox(height: 16),
                    Text('ACCESO DENEGADO',
                        style: _hudTitle(color: _kRed, fontSize: 20)),
                    const SizedBox(height: 8),
                    Text(
                      'Usuario sin autorización DTEX.\nContacte al administrador del sistema.',
                      textAlign: TextAlign.center,
                      style: _hudSubtitle(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGIN — Restyled con HUD SCCP
// ─────────────────────────────────────────────

class DtexSupervisorLogin extends StatefulWidget {
  const DtexSupervisorLogin({super.key, required this.auth});
  final AuthController auth;

  @override
  State<DtexSupervisorLogin> createState() => _DtexSupervisorLoginState();
}

class _DtexSupervisorLoginState extends State<DtexSupervisorLogin>
    with TickerProviderStateMixin {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _error;

  late final AnimationController _entryCtrl;
  late final AnimationController _glitchCtrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..forward();
    _glitchCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _glitchCtrl.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _staggeredIn({
    required int index,
    required Widget child,
    double drop = 24,
  }) {
    final start = (0.08 + index * 0.09).clamp(0.0, 0.85);
    final end = (start + 0.30).clamp(0.0, 1.0);
    final anim = CurvedAnimation(
      parent: _entryCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: anim,
      child: child,
      builder: (_, c) => Opacity(
        opacity: anim.value,
        child: Transform.translate(
          offset: Offset(0, (1 - anim.value) * drop),
          child: c,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ScanLineOverlay(
      child: Scaffold(
        backgroundColor: _kDark,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final contentWidth = isWide ? 520.0 : constraints.maxWidth;

              return Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  child: SizedBox(
                    width: contentWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── BRAND ──
                        _staggeredIn(
                          index: 0,
                          drop: 32,
                          child: Column(
                            children: [
                              _DtexGlitchIcon(
                                animation: _glitchCtrl,
                                size: isWide ? 196.0 : 164.0,
                              ),
                              const SizedBox(height: 16),
                              Text('DTEX SUPERVISOR',
                                  textAlign: TextAlign.center,
                                  style: _hudTitle(fontSize: 26)),
                              const SizedBox(height: 4),
                              Text(
                                'COMMAND CENTER OPERATIVO',
                                textAlign: TextAlign.center,
                                style: _hudMuted(fontSize: 11).copyWith(
                                  letterSpacing: 2.0,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 28),

                        // ── CARD ──
                        _staggeredIn(
                          index: 1,
                          drop: 28,
                          child: _HudCornerBracket(
                            child: _hudPanel(
                              borderRadius: BorderRadius.circular(16),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 22, 20, 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _staggeredIn(
                                    index: 2,
                                    child: Row(
                                      children: [
                                        const Icon(
                                            Icons.admin_panel_settings_rounded,
                                            color: _kCyan,
                                            size: 20),
                                        const SizedBox(width: 8),
                                        Text('AUTENTICACIÓN',
                                            style: _hudTitle(fontSize: 14)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _staggeredIn(
                                    index: 3,
                                    child: TextField(
                                      controller: _email,
                                      keyboardType: TextInputType.emailAddress,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: _hudInputDecoration(
                                        'Correo supervisor',
                                        prefixIcon:
                                            Icons.alternate_email_rounded,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _staggeredIn(
                                    index: 4,
                                    child: TextField(
                                      controller: _password,
                                      obscureText: _obscure,
                                      style:
                                          const TextStyle(color: Colors.white),
                                      onSubmitted: (_) => _login(),
                                      decoration: _hudInputDecoration(
                                        'Contraseña',
                                        prefixIcon: Icons.lock_outline_rounded,
                                      ).copyWith(
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscure
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            color:
                                                _kCyan.withValues(alpha: 0.55),
                                            size: 18,
                                          ),
                                          onPressed: () => setState(
                                              () => _obscure = !_obscure),
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (_error != null) ...[
                                    const SizedBox(height: 12),
                                    _staggeredIn(
                                      index: 5,
                                      drop: 8,
                                      child: Row(
                                        children: [
                                          const Icon(
                                              Icons.error_outline_rounded,
                                              color: _kRed,
                                              size: 15),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _error!,
                                              style: TextStyle(
                                                color: _kRed,
                                                fontFamily: 'Rajdhani',
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 20),
                                  _staggeredIn(
                                    index: 6,
                                    child: Obx(() => SizedBox(
                                          width: double.infinity,
                                          child: widget.auth.isLoading.value
                                              ? const Center(
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                            vertical: 10),
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: _kCyan),
                                                  ),
                                                )
                                              : ElevatedButton.icon(
                                                  onPressed: _login,
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor: _kCyan,
                                                    foregroundColor:
                                                        Colors.black,
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                        vertical: 15),
                                                    shape:
                                                        RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              10),
                                                    ),
                                                    textStyle: const TextStyle(
                                                      fontFamily: 'Orbitron',
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      letterSpacing: 0.8,
                                                    ),
                                                  ),
                                                  icon: const Icon(
                                                      Icons.login_rounded,
                                                      size: 18),
                                                  label: const Text('INGRESAR'),
                                                ),
                                        )),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // ── FOOTER ──
                        _staggeredIn(
                          index: 7,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.grid_4x4_rounded,
                                  size: 12,
                                  color: Colors.white.withValues(alpha: 0.38)),
                              const SizedBox(width: 6),
                              Text(
                                'DTEX · ENCRIPTADO AES-L7',
                                style: _hudMuted(fontSize: 11)
                                    .copyWith(letterSpacing: 1.4),
                              ),
                            ],
                          ),
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
    );
  }

  // Lógica original preservada
  Future<void> _login() async {
    final ok = await widget.auth.login(
      email: _email.text.trim(),
      password: _password.text.trim(),
    );
    if (!mounted) return;
    final admin = widget.auth.currentAdmin.value;
    setState(() {
      _error = ok && admin?.tieneAccesoDtex == true
          ? null
          : 'Credenciales inválidas o sin acceso DTEX.';
    });
  }
}

// ─── GLITCH ICON DTEX ───────────────────────────────────────────────────────
class _DtexGlitchIcon extends StatelessWidget {
  final Animation<double> animation;
  final double size;

  const _DtexGlitchIcon({
    required this.animation,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (_, __) {
        final phase = animation.value;
        final fastWave = math.sin(phase * math.pi * 14);
        final glitch = math.max(0.0, fastWave.abs() - 0.45) * 5.0;
        final scanY = -1 + (((phase * 1.6) % 1.0) * 2);

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Glow base
              IgnorePointer(
                child: Container(
                  width: size * 0.8,
                  height: size * 0.8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _kCyan.withValues(alpha: 0.35),
                        blurRadius: 32,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: const Color(0xFFFF33EE).withValues(alpha: 0.12),
                        blurRadius: 40,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),

              // Logo principal con glow, sin circulo pintado.
              SizedBox(
                width: size * 0.78,
                height: size * 0.78,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),

              // Glitch layer izquierdo
              Transform.translate(
                offset: Offset(glitch, 0),
                child: Opacity(
                  opacity: 0.18,
                  child: Container(
                    width: size * 0.78,
                    height: size * 0.78,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _kCyan.withValues(alpha: 0.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xFF00FFD1),
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Glitch layer derecho
              Transform.translate(
                offset: Offset(-glitch, 0),
                child: Opacity(
                  opacity: 0.14,
                  child: SizedBox(
                    width: size * 0.78,
                    height: size * 0.78,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Color(0xFFFF33EE),
                          BlendMode.srcATop,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Scan line animada
              Align(
                alignment: Alignment(0, scanY),
                child: Container(
                  width: size * 0.8,
                  height: 1.5,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        _kCyan.withValues(alpha: 0.8),
                        Colors.transparent,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kCyan.withValues(alpha: 0.5),
                        blurRadius: 8,
                      ),
                    ],
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

// ─────────────────────────────────────────────
// HOME + NAV — Restyled
// ─────────────────────────────────────────────

class DtexSupervisorHome extends StatefulWidget {
  const DtexSupervisorHome({
    super.key,
    required this.auth,
    required this.controller,
  });
  final AuthController auth;
  final DtexController controller;

  @override
  State<DtexSupervisorHome> createState() => _DtexSupervisorHomeState();
}

class _DtexSupervisorHomeState extends State<DtexSupervisorHome> {
  final _repo = SupabaseRepository();
  int _index = 0;

  DtexController get c => widget.controller;

  void _goToTab(int index) => setState(() => _index = index);

  static const _navItems = [
    (icon: Icons.dashboard_rounded, label: 'INICIO'),
    (icon: Icons.add_task_rounded, label: 'ASIGNAR'),
    (icon: Icons.map_rounded, label: 'MAPA'),
    (icon: Icons.warning_amber_rounded, label: 'ALERTAS'),
    (icon: Icons.assignment_late_rounded, label: 'PARTES'),
    (icon: Icons.radio_rounded, label: 'RADIO'),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      _DashboardTab(controller: c, onGoToMap: () => _goToTab(2)),
      _AssignTaskTab(controller: c),
      _MapTab(controller: c),
      _AlertsTab(controller: c),
      _PartesSorpresaTab(
        controller: c,
        repository: _repo,
        supervisorNombre:
            widget.auth.currentAdmin.value?.nombre ?? 'DTEX SUPERVISOR',
      ),
      _RadioTab(controller: c, repository: _repo),
    ];

    return _ScanLineOverlay(
      child: Scaffold(
        backgroundColor: _kDark,

        // ── APP BAR HUD ──
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF07101B).withValues(alpha: 0.95),
              border: Border(
                bottom: BorderSide(
                  color: _kCyan.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: _kCyan.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              titleSpacing: 16,
              title: Row(
                children: [
                  const _PulsingDot(color: _kCyan, size: 8),
                  const SizedBox(width: 8),
                  Text('DTEX SUPERVISOR', style: _hudTitle(fontSize: 15)),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'Actualizar',
                  onPressed: c.loadInitialData,
                  icon: const Icon(Icons.refresh_rounded, color: _kCyan),
                ),
                IconButton(
                  tooltip: 'Salir',
                  onPressed: widget.auth.logout,
                  icon: Icon(Icons.logout_rounded,
                      color: _kRed.withValues(alpha: 0.8)),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),

        body: SafeArea(child: pages[_index]),

        // ── BOTTOM NAV HUD ──
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF07101B).withValues(alpha: 0.96),
            border: Border(
              top: BorderSide(
                color: _kCyan.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: List.generate(_navItems.length, (i) {
                  final item = _navItems[i];
                  final selected = _index == i;
                  return Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _index = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        decoration: BoxDecoration(
                          border: Border(
                            top: BorderSide(
                              color: selected ? _kCyan : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              item.icon,
                              color: selected
                                  ? _kCyan
                                  : Colors.white.withValues(alpha: 0.4),
                              size: 22,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: selected
                                    ? _kCyan
                                    : Colors.white.withValues(alpha: 0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// DASHBOARD TAB — Restyled
// ─────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  const _DashboardTab({required this.controller, required this.onGoToMap});
  final DtexController controller;
  final VoidCallback onGoToMap;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final admin = Get.find<AuthController>().currentAdmin.value;
      final misiones = controller.misionesActivas;
      final tracking = controller.trackingActivo;
      final ultimaPosicion = tracking.isNotEmpty ? tracking.last : null;

      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
        children: [
          // ── TARJETA SUPERVISOR ──
          _HudCornerBracket(
            child: _hudPanel(
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _kCyan.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kCyan.withValues(alpha: 0.4)),
                    ),
                    child: Image.asset('assets/images/logo.png',
                        width: 48, height: 48),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(admin?.nombre ?? '—',
                            style: _hudTitle(fontSize: 15)),
                        Text(admin?.nivelDisplay ?? '—', style: _hudSubtitle()),
                        Text(admin?.email ?? '—',
                            style: _hudMuted(),
                            overflow: TextOverflow.ellipsis),
                        if (admin?.ultimoLogin != null) ...[
                          const SizedBox(height: 2),
                          Row(children: [
                            Icon(Icons.access_time_rounded,
                                size: 10,
                                color: Colors.white.withValues(alpha: 0.4)),
                            const SizedBox(width: 4),
                            Text(
                              'Último acceso: ${_formatDateTime(admin!.ultimoLogin!)}',
                              style: _hudMuted(fontSize: 10),
                            ),
                          ]),
                        ],
                      ],
                    ),
                  ),
                  const _PulsingDot(color: _kGreen),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── MÉTRICAS ──
          Row(
            children: [
              Expanded(
                child: _HudMetric(
                  label: 'Activas',
                  value: misiones.length.toString(),
                  color: _kCyan,
                  icon: Icons.shield_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HudMetric(
                  label: 'Alertas',
                  value: controller.alertasPendientes.length.toString(),
                  color: _kRed,
                  icon: Icons.warning_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _HudMetric(
                  label: 'Destinos',
                  value: controller.destinos.length.toString(),
                  color: _kGreen,
                  icon: Icons.location_on_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _HudMetric(
                  label: 'Extensiones',
                  value: controller.extensiones.length.toString(),
                  color: _kOrange,
                  icon: Icons.extension_rounded,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── MINI MAPA ──
          GestureDetector(
            onTap: onGoToMap,
            child: _HudCornerBracket(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    SizedBox(
                      height: 188,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: ultimaPosicion != null
                              ? LatLng(ultimaPosicion.latitud,
                                  ultimaPosicion.longitud)
                              : _kTarijaCenter,
                          initialZoom: 13,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.none,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName:
                                'sccp_command_center.dtex_supervisor',
                          ),
                          MarkerLayer(
                            markers: tracking
                                .fold<Map<String, dynamic>>(
                                  {},
                                  (acc, t) {
                                    acc[t.idMision] = t;
                                    return acc;
                                  },
                                )
                                .values
                                .map((t) => Marker(
                                      point: LatLng(t.latitud, t.longitud),
                                      width: 16,
                                      height: 16,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: _kCyan,
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                              color: Colors.white, width: 2),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  _kCyan.withValues(alpha: 0.7),
                                              blurRadius: 8,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ))
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    // Overlay HUD sobre mapa
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                _kDark.withValues(alpha: 0.05),
                                _kDark.withValues(alpha: 0.25),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Badge "Ver mapa"
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _kDark.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(6),
                          border:
                              Border.all(color: _kCyan.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.open_in_full_rounded,
                                size: 13, color: _kCyan),
                            const SizedBox(width: 5),
                            Text('Ver mapa completo',
                                style: _hudMuted(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                    // Label arriba izquierda
                    Positioned(
                      top: 8,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kDark.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(5),
                          border:
                              Border.all(color: _kCyan.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.radar_rounded,
                                size: 11, color: _kCyan),
                            const SizedBox(width: 4),
                            Text(
                              '${tracking.fold<Set<String>>({}, (s, t) => s..add(t.idMision)).length} UNIDAD(ES)',
                              style: _hudMuted(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // ── MISIONES ACTIVAS ──
          if (misiones.isNotEmpty) ...[
            Row(
              children: [
                Image.asset('assets/images/logo.png', width: 14, height: 14),
                const SizedBox(width: 6),
                Text('MISIONES ACTIVAS', style: _hudSubtitle(fontSize: 12)),
                const Spacer(),
                Text('${misiones.length}', style: _hudTitle(fontSize: 13)),
              ],
            ),
            const SizedBox(height: 8),
            for (final m in misiones) ...[
              _missionTile(controller, m),
              const SizedBox(height: 6),
            ],
          ],
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────
// ASIGNAR TAB — Restyled
// ─────────────────────────────────────────────

class _AssignTaskTab extends StatefulWidget {
  const _AssignTaskTab({required this.controller});
  final DtexController controller;

  @override
  State<_AssignTaskTab> createState() => _AssignTaskTabState();
}

class _AssignTaskTabState extends State<_AssignTaskTab> {
  final _reo = TextEditingController();
  String _tipo = 'JUDICIAL';
  String _grado = 'SARGENTO';
  String? _destinoId;
  String? _custodioSeleccionadoId;
  String? _custodioSeleccionadoNombre;
  String? _otp;
  TimeOfDay? _horaAudiencia;

  static const _tipos = [
    {'value': 'JUDICIAL', 'label': 'Judicial', 'icon': Icons.gavel_rounded},
    {
      'value': 'HOSPITALARIO',
      'label': 'Hospital',
      'icon': Icons.local_hospital_rounded
    },
    {'value': 'PERSONAL', 'label': 'Personal', 'icon': Icons.person_rounded},
  ];

  @override
  void dispose() {
    _reo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final allDestinos = widget.controller.destinos;
      final destinos = _tipo == 'PERSONAL'
          ? allDestinos
              .where((d) => d.tipo != 'JUDICIAL' && d.tipo != 'HOSPITALARIO')
              .toList()
          : allDestinos.where((d) => d.tipo == _tipo).toList();

      if (_destinoId != null &&
          !destinos.any((d) => d.idDestino == _destinoId)) {
        _destinoId = destinos.isNotEmpty ? destinos.first.idDestino : null;
      } else if (_destinoId == null && destinos.isNotEmpty) {
        _destinoId = destinos.first.idDestino;
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
        children: [
          // Encabezado
          Row(
            children: [
              const Icon(Icons.add_task_rounded, size: 16, color: _kCyan),
              const SizedBox(width: 8),
              Text('ASIGNAR DILIGENCIA', style: _hudTitle(fontSize: 15)),
            ],
          ),
          const SizedBox(height: 14),

          // ── TIPO ──
          Text('TIPO DE DILIGENCIA', style: _hudMuted(fontSize: 10)),
          const SizedBox(height: 8),
          Row(
            children: _tipos.map((t) {
              final selected = _tipo == t['value'];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _tipo = t['value'] as String;
                      _destinoId = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: selected
                            ? _kCyan.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? _kCyan
                              : Colors.white.withValues(alpha: 0.12),
                          width: selected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(t['icon'] as IconData,
                              color: selected ? _kCyan : Colors.white38,
                              size: 24),
                          const SizedBox(height: 5),
                          Text(
                            t['label'] as String,
                            style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: selected ? _kCyan : Colors.white38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),

          // ── INTERNO ──
          TextField(
            controller: _reo,
            textCapitalization: TextCapitalization.words,
            style: const TextStyle(color: Colors.white),
            decoration: _hudInputDecoration(
              'Nombre del interno',
              prefixIcon: Icons.person_outline_rounded,
            ),
          ),
          const SizedBox(height: 14),

          // ── CUSTODIO ──
          Text('CUSTODIO', style: _hudMuted(fontSize: 10)),
          const SizedBox(height: 8),
          Obx(() {
            final allPolicia = widget.controller.allPolicia;
            // Filtrar por grupo según supervisor y turno
            final filteredPolicia = _filterPoliciaByGrupo(allPolicia);

            if (filteredPolicia.isEmpty) {
              return _hudPanel(
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        color: _kOrange.withValues(alpha: 0.7), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sin custodios disponibles para este turno',
                        style: _hudSubtitle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              );
            }

            final validValue = filteredPolicia
                    .any((p) => p.idPolicia == _custodioSeleccionadoId)
                ? _custodioSeleccionadoId
                : null;

            return DropdownButtonFormField<String>(
              initialValue: validValue,
              decoration: _hudInputDecoration(
                'Seleccionar custodio',
                prefixIcon: Icons.badge_rounded,
              ),
              isExpanded: true,
              menuMaxHeight: 360,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
              ),
              dropdownColor: _kDark,
              selectedItemBuilder: (context) {
                return filteredPolicia.map((policia) {
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        _gradeIcon(policia.grado, size: 26),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_gradeAbbreviation(policia.grado)} ${policia.nombre}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();
              },
              items: filteredPolicia.map((policia) {
                return DropdownMenuItem<String>(
                  value: policia.idPolicia,
                  child: ListTile(
                    dense: true,
                    minLeadingWidth: 0,
                    contentPadding: EdgeInsets.zero,
                    title: Row(
                      children: [
                        _gradeIcon(policia.grado, size: 30),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_gradeAbbreviation(policia.grado)} ${policia.nombre}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Rajdhani',
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      policia.cargo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _hudMuted(fontSize: 10),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _custodioSeleccionadoId = value;
                  final selected = filteredPolicia
                      .firstWhereOrNull((p) => p.idPolicia == value);
                  if (selected != null) {
                    _grado = selected.grado;
                    _custodioSeleccionadoNombre = selected.nombre;
                  }
                });
              },
            );
          }),
          const SizedBox(height: 14),

          // ── DESTINO ──
          Text('DESTINO', style: _hudMuted(fontSize: 10)),
          const SizedBox(height: 8),
          destinos.isEmpty
              ? _hudPanel(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        'Sin destinos para este tipo de diligencia',
                        style: _hudSubtitle(fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                )
              : GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 2.8,
                  children: destinos.map((d) {
                    final selected = _destinoId == d.idDestino;
                    return GestureDetector(
                      onTap: () => setState(() => _destinoId = d.idDestino),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? _kCyan.withValues(alpha: 0.16)
                              : Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: selected
                                ? _kCyan
                                : Colors.white.withValues(alpha: 0.12),
                            width: selected ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.location_on_rounded,
                                size: 15,
                                color: selected ? _kCyan : Colors.white24),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                d.nombre,
                                style: TextStyle(
                                  fontFamily: 'Rajdhani',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: selected ? _kCyan : Colors.white54,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 14),

          // ── HORA ──
          Text('HORA DE AUDIENCIA', style: _hudMuted(fontSize: 10)),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: _horaAudiencia ?? TimeOfDay.now(),
              );
              if (picked != null) setState(() => _horaAudiencia = picked);
            },
            child: _hudPanel(
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: _kCyan, size: 20),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('HORA', style: _hudMuted(fontSize: 10)),
                      Text(
                        _horaAudiencia != null
                            ? _horaAudiencia!.format(context)
                            : 'Seleccionar',
                        style: _hudTitle(fontSize: 14),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),

          // ── BOTÓN CREAR ──
          Obx(() => SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.controller.isLoading.value ? null : _create,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kCyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  icon: const Icon(Icons.key_rounded, size: 18),
                  label: const Text('CREAR MISIÓN Y GENERAR OTP'),
                ),
              )),

          // ── OTP ──
          if (_otp != null) ...[
            const SizedBox(height: 16),
            _HudCornerBracket(
              color: _kGreen,
              child: _hudPanel(
                borderColor: _kGreen,
                borderOpacity: 0.4,
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_rounded,
                            color: _kGreen, size: 16),
                        const SizedBox(width: 6),
                        Text('OTP GENERADO', style: _hudMuted(fontSize: 11)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _otp!,
                      style: _hudTitle(color: _kGreen, fontSize: 36).copyWith(
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: _otp!)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kGreen,
                            side: BorderSide(
                                color: _kGreen.withValues(alpha: 0.5)),
                          ),
                          icon: const Icon(Icons.copy_rounded, size: 15),
                          label: const Text('COPIAR'),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _compartirWhatsApp(_otp!),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kCyan,
                            side: BorderSide(
                                color: _kCyan.withValues(alpha: 0.5)),
                          ),
                          icon: const Icon(Icons.share_rounded, size: 15),
                          label: const Text('WHATSAPP'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),
        ],
      );
    });
  }

  // ── Métodos de lógica originales intactos ──

  // Calcular el grupo actual según el calendario de rotación 14 días
  String _calculateCurrentGroup() {
    // Fecha de inicio: 28 de febrero 2026 = Día 1 ALFA
    final startDate = DateTime(2026, 2, 28);

    // Hora de corte: antes de las 8:00 AM, usar día anterior
    DateTime now = DateTime.now();
    DateTime effectiveDate = now;
    if (now.hour < 8) {
      effectiveDate = now.subtract(const Duration(days: 1));
    }

    // Calcular día en el ciclo de 14 días
    int daysSinceStart = effectiveDate.difference(startDate).inDays;
    int cycleIndex = ((daysSinceStart % 14) + 14) % 14;
    int dayOfCycle = cycleIndex + 1;

    // Días del ciclo que pertenecen a ALFA
    const Set<int> alfaDays = {1, 4, 6, 9, 10, 12, 14};

    return alfaDays.contains(dayOfCycle) ? 'ALFA' : 'BRAVO';
  }

  // Filtrar custodios por grupo según supervisor y turno
  List<DtexPolicia> _filterPoliciaByGrupo(List<DtexPolicia> allPolicia) {
    final currentGroup = _calculateCurrentGroup();

    // Obtener la lista de custodios del grupo actual
    if (currentGroup == 'ALFA') {
      return widget.controller.policiaAlfa.where((p) => p.activo).toList();
    } else {
      return widget.controller.policiaBravo.where((p) => p.activo).toList();
    }
  }

  Future<void> _compartirWhatsApp(String otp) async {
    // Deep link para abrir directamente en DTEX Custodio
    const deepLink = 'dtex-custodio://mision/otp';
    final message = 'Código OTP DTEX: $otp\n\n'
        'Ingresa este código en la aplicación DTEX Custodio para iniciar la diligencia.\n\n'
        'O toca aquí para abrir directo: $deepLink/$otp';
    final encoded = Uri.encodeComponent(message);
    final appUri = Uri.parse('whatsapp://send?text=$encoded');
    final webUri = Uri.parse('https://api.whatsapp.com/send?text=$encoded');

    try {
      final openedApp = await launchUrl(
        appUri,
        mode: LaunchMode.externalApplication,
      );
      if (openedApp) return;

      final openedWeb = await launchUrl(
        webUri,
        mode: LaunchMode.externalApplication,
      );
      if (openedWeb) return;

      Clipboard.setData(ClipboardData(text: message));
      Get.snackbar(
        'WhatsApp',
        'WhatsApp no disponible. OTP copiado al portapapeles.',
        duration: const Duration(seconds: 3),
      );
    } catch (_) {
      Clipboard.setData(ClipboardData(text: message));
      Get.snackbar(
        'WhatsApp',
        'Error al abrir WhatsApp. OTP copiado al portapapeles.',
        duration: const Duration(seconds: 3),
      );
    }
  }

  Future<void> _create() async {
    final destino = widget.controller.destinos
        .firstWhereOrNull((d) => d.idDestino == _destinoId);
    if (destino == null ||
        _reo.text.trim().isEmpty ||
        _custodioSeleccionadoId == null) {
      Get.snackbar('DTEX', 'Completa interno, custodio y destino.');
      return;
    }
    final now = DateTime.now();
    final horaSalida = _horaAudiencia != null
        ? DateTime(now.year, now.month, now.day, _horaAudiencia!.hour,
            _horaAudiencia!.minute)
        : now;
    final otp = await widget.controller.crearMision(
      tipoDiligencia: _tipo,
      reoNombre: _reo.text.trim(),
      reoCi: '',
      custodioNombre: _custodioSeleccionadoNombre ?? '',
      custodioCodigo: _custodioSeleccionadoId ?? '',
      custodioGrado: _grado,
      destino: destino,
      horaSalida: horaSalida,
      tiempoMaxMin: 120,
      referenciaLegal: null,
    );
    setState(() => _otp = otp);
  }
}

// ─────────────────────────────────────────────
// MAPA TAB — Restyled markers
// ─────────────────────────────────────────────

class _MapTab extends StatefulWidget {
  const _MapTab({required this.controller});
  final DtexController controller;

  @override
  State<_MapTab> createState() => _MapTabState();
}

class _MapTabState extends State<_MapTab> {
  final _mapController = MapController();
  LatLng? _lastCameraPoint;
  List<LatLng> _streetRoute = const <LatLng>[];
  String? _streetRouteKey;
  bool _streetRouteLoading = false;

  DtexController get controller => widget.controller;

  void _selectMission(DtexMision mission) {
    controller.seleccionarMision(mission);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final misiones = controller.misionesActivas;
      final selected = controller.misionSeleccionada.value;
      final effectiveSelected =
          misiones.any((m) => m.idMision == selected?.idMision)
              ? selected
              : null;
      final tracking = effectiveSelected == null
          ? const <DtexTrackingPunto>[]
          : controller.trackingActivo;

      if (misiones.isEmpty && selected != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && controller.misionesActivas.isEmpty) {
            controller.deseleccionarMision();
          }
        });
      } else if (misiones.isNotEmpty &&
          (selected == null ||
              !misiones.any((m) => m.idMision == selected.idMision))) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && controller.misionSeleccionada.value == selected) {
            _selectMission(misiones.first);
          }
        });
      }

      final diagnostics = _buildRouteDiagnostics(tracking);
      final routePoints = diagnostics.trustedPoints;
      final lastPoint = routePoints.isEmpty ? null : routePoints.last;
      final lastTrustedPoint = diagnostics.lastTrustedPoint;
      final markerColor =
          _stateColor(effectiveSelected?.estadoNormalizado ?? '');
      _focusLatestTrustedPoint(lastPoint);
      _updateStreetRoute(effectiveSelected, routePoints);
      final destino = _destinoForMission(effectiveSelected);
      final visibleSegments = _streetRoute.length >= 2
          ? <List<LatLng>>[_streetRoute]
          : diagnostics.segments;

      return Column(
        children: [
          Container(
            height: 122,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF07101B).withValues(alpha: 0.95),
              border: Border(
                bottom: BorderSide(color: _kCyan.withValues(alpha: 0.18)),
              ),
            ),
            child: misiones.isEmpty
                ? _emptyActiveMissionStrip()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: misiones.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final mission = misiones[index];
                      final isSelected = selected?.idMision == mission.idMision;
                      final color = _stateColor(mission.estadoNormalizado);
                      return InkWell(
                        onTap: () => _selectMission(mission),
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 220,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.16)
                                : Colors.white.withValues(alpha: 0.055),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? color
                                  : Colors.white.withValues(alpha: 0.16),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _gradeIcon(mission.custodioGrado, size: 20),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      '${_gradeAbbreviation(mission.custodioGrado)} ${mission.custodioNombre}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: _hudTitle(
                                        fontSize: 12,
                                        color: isSelected ? color : _kCyan,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                mission.estadoDisplay,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: _hudMuted(fontSize: 11),
                              ),
                              const Spacer(),
                              Text(
                                isSelected
                                    ? 'GPS: ${diagnostics.trustedCount} confiables / ${diagnostics.rejectedCount} dudosos'
                                    : 'Historial GPS: 0 punto(s)',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : Colors.white.withValues(alpha: 0.45),
                                  fontFamily: 'Rajdhani',
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: _kTarijaCenter,
                    initialZoom: 13,
                    minZoom: 10,
                    maxZoom: 18,
                    interactionOptions: const InteractionOptions(
                      flags: ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName:
                          'sccp_command_center.dtex_supervisor',
                    ),
                    if (visibleSegments.isNotEmpty)
                      PolylineLayer(
                        polylines: visibleSegments
                            .map(
                              (segment) => Polyline(
                                points: segment,
                                strokeWidth: _streetRoute.length >= 2 ? 5 : 4,
                                color: _kCyan.withValues(alpha: 0.9),
                              ),
                            )
                            .toList(),
                      ),
                    if (destino != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(destino.latitud, destino.longitud),
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _kGreen.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.flag_rounded,
                                color: Colors.black,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (lastTrustedPoint != null)
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: LatLng(
                              lastTrustedPoint.latitud,
                              lastTrustedPoint.longitud,
                            ),
                            radius: math.max(
                              lastTrustedPoint.precisionM ?? 8,
                              8,
                            ),
                            useRadiusInMeter: true,
                            color: _kCyan.withValues(alpha: 0.08),
                            borderColor: _kCyan.withValues(alpha: 0.45),
                            borderStrokeWidth: 1.4,
                          ),
                        ],
                      ),
                    if (lastPoint != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: lastPoint,
                            width: 62,
                            height: 62,
                            child: GestureDetector(
                              onTap: () {
                                if (effectiveSelected != null) {
                                  _selectMission(effectiveSelected);
                                }
                              },
                              child: Column(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color:
                                          markerColor.withValues(alpha: 0.88),
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 2),
                                      boxShadow: [
                                        BoxShadow(
                                          color: markerColor.withValues(
                                              alpha: 0.6),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      width: 16,
                                      height: 16,
                                    ),
                                  ),
                                  if (effectiveSelected != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _kDark.withValues(alpha: 0.82),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: markerColor.withValues(
                                              alpha: 0.5),
                                        ),
                                      ),
                                      child: Text(
                                        effectiveSelected.custodioNombre
                                            .split(' ')
                                            .first,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _kDark.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _kCyan.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _PulsingDot(color: _kCyan, size: 7),
                        const SizedBox(width: 7),
                        Text(
                          'TARIJA · ${misiones.length} ACT · ${diagnostics.trustedCount} GPS OK · ${diagnostics.rejectedCount} FILTRADOS',
                          style: _hudMuted(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ),
                if (routePoints.isEmpty && effectiveSelected != null)
                  Center(
                    child: _hudPanel(
                      borderColor: _kOrange,
                      borderOpacity: 0.3,
                      child: Text(
                        diagnostics.rejectedCount > 0
                            ? 'Sin puntos GPS confiables para ${effectiveSelected.custodioNombre}'
                            : 'Sin puntos GPS para ${effectiveSelected.custodioNombre}',
                        style: _hudMuted(fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Widget _emptyActiveMissionStrip() {
    return _hudPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      borderColor: _kOrange,
      borderOpacity: 0.25,
      child: Row(
        children: [
          const Icon(Icons.person_off_rounded, color: _kOrange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sin custodios activos en misión',
              style: _hudMuted(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  bool _isZeroPoint(LatLng point) =>
      point.latitude == 0 && point.longitude == 0;

  DtexMapRouteDiagnostics _buildRouteDiagnostics(
    List<DtexTrackingPunto> tracking,
  ) {
    final trustedPoints = <LatLng>[];
    final rejectedPoints = <DtexTrackingPunto>[];
    final segments = <List<LatLng>>[];
    final currentSegment = <LatLng>[];
    DtexTrackingPunto? previousTrusted;
    DtexTrackingPunto? lastTrusted;
    var jumpCount = 0;

    void closeSegment() {
      if (currentSegment.length >= 2) {
        segments.add(List<LatLng>.unmodifiable(currentSegment));
      }
      currentSegment.clear();
    }

    for (final point in tracking) {
      final latLng = LatLng(point.latitud, point.longitud);
      if (!_isTrustedTrackingPoint(point) || _isZeroPoint(latLng)) {
        rejectedPoints.add(point);
        continue;
      }

      final previous = previousTrusted;
      if (previous != null) {
        final gap = point.ts.difference(previous.ts).abs();
        if (gap > DtexMapRouteDiagnostics.maxTelemetryGap) {
          closeSegment();
          previousTrusted = null;
        } else if (_isImpossibleGpsJump(previous, point)) {
          jumpCount++;
          rejectedPoints.add(point);
          closeSegment();
          continue;
        }
      }

      trustedPoints.add(latLng);
      currentSegment.add(latLng);
      previousTrusted = point;
      lastTrusted = point;
    }
    closeSegment();

    return DtexMapRouteDiagnostics(
      trustedPoints: List<LatLng>.unmodifiable(trustedPoints),
      rejectedPoints: List<DtexTrackingPunto>.unmodifiable(rejectedPoints),
      segments: List<List<LatLng>>.unmodifiable(segments),
      jumpCount: jumpCount,
      lastTrustedPoint: lastTrusted,
    );
  }

  bool _isTrustedTrackingPoint(DtexTrackingPunto point) {
    if (!point.gpsActivo) return false;
    if (point.latitud < -90 ||
        point.latitud > 90 ||
        point.longitud < -180 ||
        point.longitud > 180) {
      return false;
    }
    final accuracy = point.precisionM;
    if (accuracy == null) return false;
    return accuracy <= DtexMapRouteDiagnostics.maxOfficialAccuracyMeters;
  }

  bool _isImpossibleGpsJump(
    DtexTrackingPunto previous,
    DtexTrackingPunto current,
  ) {
    final seconds = current.ts.difference(previous.ts).inMilliseconds / 1000;
    if (seconds <= 0) return true;

    final distanceMeters = const Distance().as(
      LengthUnit.Meter,
      LatLng(previous.latitud, previous.longitud),
      LatLng(current.latitud, current.longitud),
    );
    if (distanceMeters < 60) return false;

    final toleratedNoise =
        (previous.precisionM ?? 0) + (current.precisionM ?? 0) + 35;
    if (distanceMeters <= toleratedNoise) return false;

    final speedMps = distanceMeters / seconds;
    return speedMps > DtexMapRouteDiagnostics.maxUrbanSpeedMps ||
        distanceMeters > DtexMapRouteDiagnostics.maxSingleJumpMeters;
  }

  void _focusLatestTrustedPoint(LatLng? point) {
    if (point == null) return;
    final last = _lastCameraPoint;
    if (last != null &&
        const Distance().as(LengthUnit.Meter, last, point) < 12) {
      return;
    }
    _lastCameraPoint = point;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _mapController.move(point, 15.5);
    });
  }

  DtexDestino? _destinoForMission(DtexMision? mission) {
    if (mission == null) return null;
    return controller.destinos.firstWhereOrNull(
      (d) => d.idDestino == mission.idDestino,
    );
  }

  void _updateStreetRoute(DtexMision? mission, List<LatLng> routePoints) {
    if (mission == null || routePoints.isEmpty) {
      if (_streetRoute.isNotEmpty || _streetRouteKey != null) {
        _streetRouteKey = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _streetRoute = const <LatLng>[]);
        });
      }
      return;
    }
    if (_streetRouteLoading) return;
    final destino = _destinoForMission(mission);
    if (destino == null) return;
    final origin = routePoints.first;
    final destination = LatLng(destino.latitud, destino.longitud);
    final key =
        '${mission.idMision}:${origin.latitude.toStringAsFixed(5)},${origin.longitude.toStringAsFixed(5)}:${destination.latitude.toStringAsFixed(5)},${destination.longitude.toStringAsFixed(5)}';
    if (_streetRouteKey == key) return;
    _streetRouteKey = key;
    _streetRouteLoading = true;

    unawaited(() async {
      try {
        final uri = Uri.https(
          'router.project-osrm.org',
          '/route/v1/driving/'
              '${origin.longitude},${origin.latitude};'
              '${destination.longitude},${destination.latitude}',
          const <String, String>{
            'overview': 'full',
            'geometries': 'geojson',
            'steps': 'false',
          },
        );
        final client = HttpClient()
          ..connectionTimeout = const Duration(seconds: 8);
        final request = await client.getUrl(uri);
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'sccp-dtex-supervisor',
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        client.close(force: true);
        if (response.statusCode != HttpStatus.ok) return;

        final payload = jsonDecode(body);
        if (payload is! Map<String, dynamic>) return;
        final routes = payload['routes'];
        if (routes is! List || routes.isEmpty) return;
        final firstRoute = routes.first;
        if (firstRoute is! Map<String, dynamic>) return;
        final geometry = firstRoute['geometry'];
        if (geometry is! Map<String, dynamic>) return;
        final coordinates = geometry['coordinates'];
        if (coordinates is! List) return;
        final points = coordinates
            .whereType<List>()
            .where((pair) => pair.length >= 2)
            .map((pair) => LatLng(
                  (pair[1] as num).toDouble(),
                  (pair[0] as num).toDouble(),
                ))
            .toList();
        if (points.length < 2 || !mounted) return;
        setState(() => _streetRoute = points);
      } catch (_) {
        if (mounted) setState(() => _streetRoute = const <LatLng>[]);
      } finally {
        _streetRouteLoading = false;
      }
    }());
  }
}

class DtexMapRouteDiagnostics {
  static const double maxOfficialAccuracyMeters = 25;
  static const double maxUrbanSpeedMps = 24;
  static const double maxSingleJumpMeters = 240;
  static const Duration maxTelemetryGap = Duration(minutes: 3);

  final List<LatLng> trustedPoints;
  final List<DtexTrackingPunto> rejectedPoints;
  final List<List<LatLng>> segments;
  final int jumpCount;
  final DtexTrackingPunto? lastTrustedPoint;

  const DtexMapRouteDiagnostics({
    required this.trustedPoints,
    required this.rejectedPoints,
    required this.segments,
    required this.jumpCount,
    required this.lastTrustedPoint,
  });

  int get trustedCount => trustedPoints.length;
  int get rejectedCount => rejectedPoints.length;
}

// ─────────────────────────────────────────────
// CUSTODIOS TAB — Active Custodians List
// ─────────────────────────────────────────────

class _CustodiansTab extends StatefulWidget {
  const _CustodiansTab({required this.controller});
  final DtexController controller;

  @override
  State<_CustodiansTab> createState() => _CustodiansTabState();
}

class _CustodiansTabState extends State<_CustodiansTab> {
  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final misiones = widget.controller.misionesActivas;

      if (misiones.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kOrange.withValues(alpha: 0.1),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.people_outline_rounded,
                    color: _kOrange, size: 36),
              ),
              const SizedBox(height: 16),
              Text('SIN CUSTODIOS EN MISION HOY',
                  style: _hudTitle(color: _kOrange, fontSize: 15)),
              const SizedBox(height: 6),
              Text('Las listas operativas se activan con misiones del día',
                  style: _hudMuted(fontSize: 12)),
            ],
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _hudPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppConstants.grupoColors['ALFA'] ?? _kCyan,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CUSTODIOS EN MISION',
                          style: _hudTitle(fontSize: 13),
                        ),
                        Text(
                          '${misiones.length} custodios activos hoy',
                          style: _hudMuted(fontSize: 11),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border:
                            Border.all(color: _kGreen.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        '● ACTIVOS',
                        style: TextStyle(
                          color: _kGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'Rajdhani',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(misiones.length, (i) {
            final m = misiones[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _hudPanel(
                borderColor: _stateColor(m.estadoNormalizado),
                borderOpacity: 0.4,
                child: Row(
                  children: [
                    _gradeIcon(m.custodioGrado, size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_gradeAbbreviation(m.custodioGrado)} ${m.custodioNombre}',
                            style: _hudTitle(fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${m.estadoDisplay} · ${m.destinoNombre}',
                            style: _hudMuted(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _kGreen.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: _kGreen,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      );
    });
  }
}

// ─────────────────────────────────────────────
// ALERTAS TAB — Restyled
// ─────────────────────────────────────────────

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.controller});
  final DtexController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final alertas = controller.alertasPendientes;
      if (alertas.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kGreen.withValues(alpha: 0.1),
                  border: Border.all(color: _kGreen.withValues(alpha: 0.4)),
                ),
                child:
                    const Icon(Icons.check_rounded, color: _kGreen, size: 36),
              ),
              const SizedBox(height: 16),
              Text('SIN ALERTAS PENDIENTES',
                  style: _hudTitle(color: _kGreen, fontSize: 15)),
              const SizedBox(height: 6),
              Text('Sistema operativo nominal', style: _hudMuted(fontSize: 12)),
            ],
          ),
        );
      }
      return ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: alertas.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _alertTile(controller, alertas[i]),
      );
    });
  }
}

// ─────────────────────────────────────────────
// RADIO TAB — Restyled
// ─────────────────────────────────────────────

class _RadioTab extends StatefulWidget {
  const _RadioTab({required this.controller, required this.repository});
  final DtexController controller;
  final SupabaseRepository repository;

  @override
  State<_RadioTab> createState() => _RadioTabState();
}

class _RadioTabState extends State<_RadioTab> {
  final _message = TextEditingController();

  // _targetId almacena el custodioCodigo (no idMision) de la misión seleccionada
  String? _targetId;
  // _targetMisionId almacena el idMision para mostrar en el dropdown
  String? _targetMisionId;

  bool _sending = false;
  List<RadioMessage> _messages = [];
  StreamSubscription<List<RadioMessage>>? _sub;

  @override
  void initState() {
    super.initState();
    // Auto-seleccionar la primera misión activa si existe
    final misiones = widget.controller.misionesActivas;
    if (misiones.isNotEmpty) {
      _targetMisionId = misiones.first.idMision;
      _targetId = misiones.first.custodioCodigo;
    }
    _subscribeMessages();
  }

  /// Re-suscribe el stream filtrando por el custodioCodigo seleccionado.
  /// Se llama al iniciar y cada vez que el supervisor cambia de custodio.
  void _subscribeMessages() {
    _sub?.cancel();
    final codigoFiltro = _targetId;
    if (codigoFiltro == null) {
      setState(() => _messages = const <RadioMessage>[]);
    } else {
      // Con custodio seleccionado: filtrar por su código
      _sub = widget.repository
          .watchRadioMessages(idOficial: codigoFiltro)
          .listen((msgs) {
        if (mounted) {
          setState(
            () => _messages =
                msgs.where((msg) => _isToday(msg.timestamp)).toList(),
          );
        }
      });
    }
  }

  bool _isToday(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  void _selectMision(String? idMision) {
    if (idMision == null) return;
    final misiones = widget.controller.misionesActivas;
    final mision = misiones.firstWhereOrNull((m) => m.idMision == idMision);
    if (mision == null) return;
    setState(() {
      _targetMisionId = mision.idMision;
      _targetId = mision.custodioCodigo;
      _messages = [];
    });
    _subscribeMessages();
  }

  void _ensureActiveTarget(List<DtexMision> misiones) {
    if (misiones.isEmpty) {
      if (_targetId == null && _targetMisionId == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _targetMisionId = null;
          _targetId = null;
          _messages = [];
        });
        _subscribeMessages();
      });
      return;
    }
    final currentStillActive =
        misiones.any((m) => m.idMision == _targetMisionId);
    if (_targetId != null && currentStillActive) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final latest = widget.controller.misionesActivas;
      if (latest.isEmpty) return;
      final first = latest.first;
      if (_targetMisionId == first.idMision &&
          _targetId == first.custodioCodigo) {
        return;
      }
      setState(() {
        _targetMisionId = first.idMision;
        _targetId = first.custodioCodigo;
        _messages = [];
      });
      _subscribeMessages();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final misiones = widget.controller.misionesActivas;
      _ensureActiveTarget(misiones);

      return Column(
        children: [
          // ── HEADER RADIO ──
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            decoration: BoxDecoration(
              color: const Color(0xFF07101B).withValues(alpha: 0.9),
              border: Border(
                bottom: BorderSide(color: _kCyan.withValues(alpha: 0.15)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radio_rounded, color: _kCyan, size: 16),
                    const SizedBox(width: 6),
                    Text('CANAL DE RADIO', style: _hudTitle(fontSize: 13)),
                    const Spacer(),
                    const _PulsingDot(color: _kCyan),
                  ],
                ),
                const SizedBox(height: 10),
                // Mostrar misiones activas si existen
                if (misiones.isNotEmpty) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _targetMisionId,
                    decoration: _hudInputDecoration(
                      'Misión activa',
                      prefixIcon: Icons.person_search_rounded,
                    ),
                    dropdownColor: _kDark,
                    style: const TextStyle(color: Colors.white),
                    items: misiones
                        .map((m) => DropdownMenuItem(
                              value: m.idMision,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(m.custodioNombre,
                                      style:
                                          const TextStyle(color: Colors.white)),
                                  Text(m.custodioCodigo,
                                      style: _hudMuted(fontSize: 10)),
                                ],
                              ),
                            ))
                        .toList(),
                    onChanged: _selectMision,
                  ),
                  const SizedBox(height: 8),
                ] else
                  _hudPanel(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    borderColor: _kOrange,
                    borderOpacity: 0.28,
                    child: Row(
                      children: [
                        const Icon(Icons.radio_rounded,
                            color: _kOrange, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Radio habilitada solo para custodios en misión activa hoy.',
                            style: _hudMuted(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ── MENSAJES ──
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_bubble_outline_rounded,
                            color: _kCyan.withValues(alpha: 0.3), size: 42),
                        const SizedBox(height: 10),
                        Text('Sin mensajes en canal',
                            style: _hudMuted(fontSize: 13)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      if (RadioRtcSignal.isRtcPayload(msg.mensaje)) {
                        return const SizedBox.shrink();
                      }
                      final esMio = msg.deUsuario == 'SUPERVISOR';
                      return Align(
                        alignment: esMio
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.75),
                          decoration: BoxDecoration(
                            color: esMio
                                ? _kCyan.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: esMio
                                  ? _kCyan.withValues(alpha: 0.4)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: esMio
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(msg.mensaje,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 14)),
                              const SizedBox(height: 4),
                              Text(msg.deUsuario,
                                  style: _hudMuted(fontSize: 10)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // ── INPUT ENVÍO ──
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: const Color(0xFF07101B).withValues(alpha: 0.9),
              border: Border(
                top: BorderSide(color: _kCyan.withValues(alpha: 0.15)),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _message,
                    minLines: 1,
                    maxLines: 3,
                    style: const TextStyle(color: Colors.white),
                    decoration: _hudInputDecoration('Mensaje al custodio',
                        prefixIcon: Icons.message_rounded),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _kCyan,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: _kCyan.withValues(alpha: 0.4),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: (_sending || _targetId == null) ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.send_rounded, color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  Future<void> _send() async {
    // _targetId contiene el custodioCodigo de la misión seleccionada
    final codigoCustodio = _targetId;
    final text = _message.text.trim();
    if (codigoCustodio == null || text.isEmpty) return;
    setState(() => _sending = true);
    final ok = await widget.repository.sendRadioMessage(
      idOficial:
          codigoCustodio, // debe coincidir con watchRadioMessages(idOficial) del custodio
      fromUser: 'SUPERVISOR',
      toUser: 'DTEX:$codigoCustodio',
      message: text,
      type: 'RADIO',
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) _message.clear();
    });
    if (!ok) {
      Get.snackbar(
        'Radio operativa',
        'No se pudo enviar el mensaje.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _kRed.withValues(alpha: 0.86),
        colorText: Colors.white,
      );
    }
  }
}

// ─────────────────────────────────────────────
// PARTES SORPRESA TAB
// ─────────────────────────────────────────────

class _PartesSorpresaTab extends StatefulWidget {
  const _PartesSorpresaTab({
    required this.controller,
    required this.repository,
    required this.supervisorNombre,
  });

  final DtexController controller;
  final SupabaseRepository repository;
  final String supervisorNombre;

  @override
  State<_PartesSorpresaTab> createState() => _PartesSorpresaTabState();
}

class _PartesSorpresaTabState extends State<_PartesSorpresaTab> {
  final _razon = TextEditingController();
  List<ParteSorpresa> _partes = const <ParteSorpresa>[];
  String? _targetId;
  bool _loading = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _razon.text =
        'Control sorpresa DTEX: confirmar novedad, ubicación y estado operativo.';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureDefaultTarget();
      unawaited(_loadPartes());
    });
  }

  @override
  void dispose() {
    _razon.dispose();
    super.dispose();
  }

  void _ensureDefaultTarget() {
    final candidates = _targets();
    if (candidates.isEmpty || _targetId != null) return;
    setState(() => _targetId = candidates.first.$1);
  }

  List<(String, String)> _targets() {
    final byId = <String, String>{};
    for (final m in widget.controller.misionesActivas) {
      final id = m.custodioCodigo.trim();
      if (id.isEmpty) continue;
      byId[id] =
          '${_gradeAbbreviation(m.custodioGrado)} ${m.custodioNombre} · ${m.destinoNombre}';
    }
    final entries = byId.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return entries.map((e) => (e.key, e.value)).toList();
  }

  Future<void> _loadPartes() async {
    setState(() => _loading = true);
    final data = await widget.repository.getPartesSorpresa(limit: 80);
    final activeIds = _targets().map((t) => t.$1).toSet();
    if (!mounted) return;
    setState(() {
      _partes = data
          .where((p) =>
              activeIds.contains(p.idOficial.trim()) && _isToday(p.timestamp))
          .toList();
      _loading = false;
    });
  }

  bool _isToday(DateTime value) {
    final local = value.toLocal();
    final now = DateTime.now();
    return local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
  }

  Future<void> _sendParte() async {
    final target = _targetId?.trim() ?? '';
    final razon = _razon.text.trim();
    if (target.isEmpty || razon.isEmpty || _sending) return;
    final activeIds = _targets().map((t) => t.$1).toSet();
    if (!activeIds.contains(target)) {
      Get.snackbar(
        'Partes sorpresa',
        'Solo se puede enviar a custodios en misión activa hoy.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _kOrange.withValues(alpha: 0.86),
        colorText: Colors.black,
      );
      return;
    }

    setState(() => _sending = true);
    final ok = await widget.repository.crearParteSorpresa(
      idOficial: target,
      supervisorNombre: widget.supervisorNombre,
      razon: razon,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (ok) {
      await _loadPartes();
      Get.snackbar(
        'Parte sorpresa enviado',
        'El custodio debe responder el requerimiento.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.black.withValues(alpha: 0.86),
        colorText: Colors.white,
        icon: const Icon(Icons.assignment_turned_in_rounded, color: _kCyan),
      );
    } else {
      Get.snackbar(
        'Partes sorpresa',
        'No se pudo crear el parte.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: _kRed.withValues(alpha: 0.86),
        colorText: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final targets = _targets();
      if (targets.isNotEmpty && !targets.any((t) => t.$1 == _targetId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !targets.any((t) => t.$1 == _targetId)) {
            setState(() => _targetId = targets.first.$1);
          }
        });
      }
      final visible = _targetId == null
          ? _partes
          : _partes.where((p) => p.idOficial.trim() == _targetId).toList();

      return RefreshIndicator(
        onRefresh: _loadPartes,
        color: _kCyan,
        backgroundColor: _kDark,
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            _hudPanel(
              borderColor: _kOrange,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment_late_rounded,
                          color: _kOrange, size: 18),
                      const SizedBox(width: 8),
                      Text('PARTES SORPRESA', style: _hudTitle(fontSize: 13)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Actualizar',
                        onPressed: _loading ? null : _loadPartes,
                        icon: _loading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh_rounded, color: _kCyan),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (targets.isEmpty)
                    _hudPanel(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 9),
                      borderColor: _kOrange,
                      borderOpacity: 0.28,
                      child: Text(
                        'Sin custodios en misión activa hoy.',
                        style: _hudMuted(fontSize: 12),
                      ),
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: targets.any((t) => t.$1 == _targetId)
                          ? _targetId
                          : null,
                      decoration: _hudInputDecoration(
                        'Custodio en misión activa',
                        prefixIcon: Icons.badge_rounded,
                      ),
                      dropdownColor: _kDark,
                      style: const TextStyle(color: Colors.white),
                      items: targets
                          .map(
                            (t) => DropdownMenuItem(
                              value: t.$1,
                              child: Text(
                                t.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setState(() => _targetId = value),
                    ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _razon,
                    minLines: 2,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: _hudInputDecoration(
                      'Orden / motivo',
                      prefixIcon: Icons.edit_note_rounded,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed:
                        (_sending || targets.isEmpty) ? null : _sendParte,
                    style: FilledButton.styleFrom(
                      backgroundColor: _kOrange,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label:
                        Text(_sending ? 'Enviando' : 'Enviar parte sorpresa'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (visible.isEmpty)
              _hudPanel(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 26),
                    child: Text(
                      'Sin partes sorpresa para el custodio seleccionado',
                      style: _hudMuted(fontSize: 13),
                    ),
                  ),
                ),
              )
            else
              ...visible.map(_parteTile),
          ],
        ),
      );
    });
  }

  Widget _parteTile(ParteSorpresa parte) {
    final color = parte.estadoColor;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _hudPanel(
        borderColor: color,
        borderOpacity: 0.34,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment_rounded, color: color, size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    parte.estadoEtiqueta,
                    style: _hudSubtitle(fontSize: 13).copyWith(color: color),
                  ),
                ),
                Text(parte.tiempoDisplay, style: _hudMuted(fontSize: 11)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              parte.razon,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Rajdhani',
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((parte.respuestaOficial ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                parte.respuestaOficial!,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontFamily: 'Rajdhani',
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text('Custodio: ${parte.idOficial}',
                style: _hudMuted(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// HELPERS — Restyled (lógica intacta)
// ─────────────────────────────────────────────

Widget _missionTile(DtexController controller, DtexMision mission) {
  final color = _stateColor(mission.estadoNormalizado);
  final puedeCerrar = [
    DtexMision.estadoEnDestino,
    DtexMision.estadoRetorno,
    DtexMision.estadoEmergencia,
  ].contains(mission.estadoNormalizado);

  return GestureDetector(
    onTap: () => controller.seleccionarMision(mission),
    child: _hudPanel(
      borderColor: color,
      borderOpacity: 0.28,
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          // Estado indicador
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.shield_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mission.custodioNombre,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        mission.estadoDisplay,
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        mission.destinoNombre,
                        style: _hudMuted(fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (puedeCerrar)
                IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded,
                      color: _kGreen, size: 22),
                  onPressed: () =>
                      _showCierreDialog(Get.context!, controller, mission),
                ),
              Icon(Icons.chevron_right_rounded,
                  color: color.withValues(alpha: 0.7)),
            ],
          ),
        ],
      ),
    ),
  );
}

void _showCierreDialog(
    BuildContext context, DtexController controller, DtexMision mission) {
  String conducta = 'SIN_INCIDENCIAS';
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: _kDark,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: _kCyan.withValues(alpha: 0.25)),
      ),
      title: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: _kGreen, size: 20),
          const SizedBox(width: 8),
          Text('FINALIZAR DILIGENCIA',
              style: _hudTitle(fontSize: 14, color: _kGreen)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: conducta,
            decoration: _hudInputDecoration('Conducta final'),
            dropdownColor: _kDark,
            style: const TextStyle(color: Colors.white),
            items: const [
              DropdownMenuItem(
                  value: 'SIN_INCIDENCIAS', child: Text('Sin incidencias')),
              DropdownMenuItem(
                  value: 'CON_OBSERVACIONES', child: Text('Con observaciones')),
              DropdownMenuItem(
                  value: 'CON_INCIDENCIAS_GRAVES',
                  child: Text('Incidencias graves')),
            ],
            onChanged: (v) => conducta = v ?? conducta,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: Text('CANCELAR',
              style: TextStyle(
                  fontFamily: 'Rajdhani',
                  color: Colors.white.withValues(alpha: 0.6))),
        ),
        ElevatedButton(
          onPressed: () async {
            await controller.cerrarMisionManual(
              idMision: mission.idMision,
              conductaFinal: conducta,
            );
            Get.back();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _kGreen,
            foregroundColor: Colors.black,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('CERRAR MISIÓN',
              style: TextStyle(
                  fontFamily: 'Orbitron',
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}

Widget _alertTile(DtexController controller, DtexAlerta alerta) {
  final mission = _missionForAlert(controller, alerta);
  final color = _alertSeverityColor(alerta);
  final custodio = mission == null
      ? 'Mision ${_shortId(alerta.idMision)}'
      : '${_gradeAbbreviation(mission.custodioGrado)} ${mission.custodioNombre}'
          .trim();
  return _hudPanel(
    borderColor: color,
    borderOpacity: _isCriticalAlert(alerta) ? 0.5 : 0.3,
    padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
    child: Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _isCriticalAlert(alerta)
                ? Icons.emergency_rounded
                : Icons.warning_rounded,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (mission != null) ...[
                    _gradeIcon(mission.custodioGrado, size: 20),
                  ] else ...[
                    Icon(Icons.person_outline_rounded,
                        color: _kCyan.withValues(alpha: 0.82), size: 14),
                  ],
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      custodio.isEmpty ? 'Custodio no identificado' : custodio,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Rajdhani',
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.schedule_rounded,
                      color: Colors.white.withValues(alpha: 0.5), size: 13),
                  const SizedBox(width: 4),
                  Text(
                    _formatAlertTime(alerta.ts),
                    style: _hudMuted(fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                alerta.tipoDisplay,
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: color,
                ),
              ),
              Text(alerta.descripcion,
                  style: _hudMuted(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              if ((mission?.destinoNombre ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  mission!.destinoNombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _hudMuted(fontSize: 11),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.done_rounded, color: _kGreen, size: 22),
          onPressed: () => controller.resolverAlerta(idAlerta: alerta.idAlerta),
        ),
      ],
    ),
  );
}

DtexMision? _missionForAlert(
  DtexController controller,
  DtexAlerta alerta,
) {
  DtexMision? findIn(Iterable<DtexMision> rows) {
    for (final mission in rows) {
      if (mission.idMision == alerta.idMision) return mission;
    }
    return null;
  }

  return findIn(controller.misionesActivas) ?? findIn(controller.misiones);
}

bool _isCriticalAlert(DtexAlerta alerta) {
  final severity = alerta.severidad.trim().toUpperCase();
  return severity == 'EMERGENCIA' ||
      severity == 'CRITICA' ||
      severity == 'CRITICO';
}

Color _alertSeverityColor(DtexAlerta alerta) {
  if (_isCriticalAlert(alerta)) return _kRed;
  final severity = alerta.severidad.trim().toUpperCase();
  if (severity == 'INFO' || severity == 'INFORMATIVA') return _kCyan;
  return _kOrange;
}

String _formatAlertTime(DateTime ts) {
  final local = ts.toLocal();
  final now = DateTime.now();
  final sameDay = local.year == now.year &&
      local.month == now.month &&
      local.day == now.day;
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  if (sameDay) return '$hh:$mm';
  final dd = local.day.toString().padLeft(2, '0');
  final mo = local.month.toString().padLeft(2, '0');
  return '$dd/$mo $hh:$mm';
}

String _shortId(String value) {
  final clean = value.trim();
  if (clean.isEmpty) return 'N/D';
  return clean.length <= 8 ? clean : clean.substring(0, 8);
}

Color _stateColor(String state) {
  switch (state.trim().toUpperCase()) {
    case 'EMERGENCIA':
      return _kRed;
    case 'EN_DESTINO':
      return _kGreen;
    case 'EN_RUTA':
    case 'RETORNO':
      return _kCyan;
    default:
      return _kOrange;
  }
}

String _formatDateTime(DateTime dt) {
  final local = dt.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')} '
      '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
