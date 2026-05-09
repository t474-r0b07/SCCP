import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/browser_notification.dart';
import '../controllers/auth_controller.dart';

class AdminSecurityDialog extends StatefulWidget {
  const AdminSecurityDialog({super.key});

  @override
  State<AdminSecurityDialog> createState() => _AdminSecurityDialogState();
}

class _AdminSecurityDialogState extends State<AdminSecurityDialog> {
  final AuthController _auth = Get.find<AuthController>();

  final TextEditingController _currentPassword = TextEditingController();
  final TextEditingController _newPassword = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  final TextEditingController _currentPin = TextEditingController();
  final TextEditingController _newPin = TextEditingController();
  final TextEditingController _confirmPin = TextEditingController();

  bool _savingPassword = false;
  bool _savingPin = false;
  bool _hidePassword = true;
  bool _hidePin = true;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    _currentPin.dispose();
    _newPin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  Future<void> _submitPassword() async {
    final current = _currentPassword.text.trim();
    final next = _newPassword.text.trim();
    final confirm = _confirmPassword.text.trim();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _toast('Seguridad', 'Completa todos los campos de contraseña');
      return;
    }
    if (next != confirm) {
      _toast('Seguridad', 'La nueva contraseña no coincide con la confirmación');
      return;
    }
    if (next.length < 8) {
      _toast('Seguridad', 'La nueva contraseña debe tener al menos 8 caracteres');
      return;
    }

    setState(() => _savingPassword = true);
    final ok = await _auth.cambiarContrasena(
      passwordActual: current,
      nuevaContrasena: next,
    );
    if (!mounted) return;
    setState(() => _savingPassword = false);

    if (ok) {
      _currentPassword.clear();
      _newPassword.clear();
      _confirmPassword.clear();
      _toast('Seguridad', 'Contraseña actualizada correctamente', success: true);
      return;
    }
    _toast('Seguridad', 'No se pudo actualizar la contraseña');
  }

  Future<void> _submitPin() async {
    final current = _currentPin.text.trim();
    final next = _newPin.text.trim();
    final confirm = _confirmPin.text.trim();

    if (current.isEmpty || next.isEmpty || confirm.isEmpty) {
      _toast('Seguridad', 'Completa todos los campos de PIN');
      return;
    }
    if (next != confirm) {
      _toast('Seguridad', 'El nuevo PIN no coincide con la confirmación');
      return;
    }
    if (!RegExp(r'^\d{4,8}$').hasMatch(next)) {
      _toast('Seguridad', 'El PIN debe ser numérico de 4 a 8 dígitos');
      return;
    }

    setState(() => _savingPin = true);
    final ok = await _auth.cambiarPinAdmin(
      pinActual: current,
      nuevoPin: next,
    );
    if (!mounted) return;
    setState(() => _savingPin = false);

    if (ok) {
      _currentPin.clear();
      _newPin.clear();
      _confirmPin.clear();
      _toast('Seguridad', 'PIN actualizado correctamente', success: true);
      return;
    }
    _toast('Seguridad', 'No se pudo actualizar el PIN');
  }

  void _toast(String title, String msg, {bool success = false}) {
    Get.snackbar(
      title,
      msg,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: (success ? AppConstants.neonGreen : AppConstants.warningRed)
          .withValues(alpha: 0.25),
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }

  Future<void> _activarCanalNotificacionesWeb() async {
    await BrowserNotification.ensurePermission();
    BrowserNotification.show(
      title: 'SCCP',
      body: 'Canal de notificaciones web habilitado',
    );
    _toast('Notificaciones', 'Permiso de notificaciones web actualizado',
        success: true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppConstants.darkBg.withValues(alpha: 0.98),
      title: const Text(
        'SEGURIDAD DE CUENTA',
        style: TextStyle(
          color: Colors.white,
          fontFamily: 'Orbitron',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sectionFrame(
                title: 'CAMBIAR CONTRASEÑA',
                child: Column(
                  children: [
                    _field(
                      controller: _currentPassword,
                      label: 'Contraseña actual',
                      obscure: _hidePassword,
                    ),
                    const SizedBox(height: 8),
                    _field(
                      controller: _newPassword,
                      label: 'Nueva contraseña',
                      obscure: _hidePassword,
                    ),
                    const SizedBox(height: 8),
                    _field(
                      controller: _confirmPassword,
                      label: 'Confirmar nueva contraseña',
                      obscure: _hidePassword,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _actionButton(
                        label: _savingPassword
                            ? 'ACTUALIZANDO...'
                            : 'ACTUALIZAR CONTRASEÑA',
                        color: AppConstants.neonCyan,
                        enabled: !_savingPassword,
                        onTap: _submitPassword,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _sectionFrame(
                title: 'CAMBIAR PIN',
                child: Column(
                  children: [
                    _field(
                      controller: _currentPin,
                      label: 'PIN actual',
                      obscure: _hidePin,
                      digitsOnly: true,
                    ),
                    const SizedBox(height: 8),
                    _field(
                      controller: _newPin,
                      label: 'Nuevo PIN (4-8 dígitos)',
                      obscure: _hidePin,
                      digitsOnly: true,
                    ),
                    const SizedBox(height: 8),
                    _field(
                      controller: _confirmPin,
                      label: 'Confirmar nuevo PIN',
                      obscure: _hidePin,
                      digitsOnly: true,
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _actionButton(
                        label: _savingPin ? 'ACTUALIZANDO...' : 'ACTUALIZAR PIN',
                        color: Colors.orangeAccent,
                        enabled: !_savingPin,
                        onTap: _submitPin,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: !_hidePassword,
                      onChanged: (v) {
                        setState(() => _hidePassword = !(v ?? false));
                      },
                      title: Text(
                        'Mostrar contraseña',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: !_hidePin,
                      onChanged: (v) {
                        setState(() => _hidePin = !(v ?? false));
                      },
                      title: Text(
                        'Mostrar PIN',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFamily: 'Rajdhani',
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: _actionButton(
                  label: 'VALIDAR NOTIFICACIONES WEB',
                  color: AppConstants.neonPink,
                  enabled: true,
                  onTap: _activarCanalNotificacionesWeb,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back(),
          child: const Text(
            'CERRAR',
            style: TextStyle(
              color: AppConstants.neonCyan,
              fontFamily: 'Orbitron',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionFrame({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppConstants.neonCyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppConstants.neonCyan,
              fontFamily: 'Orbitron',
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    bool digitsOnly = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: digitsOnly ? TextInputType.number : TextInputType.text,
      style: const TextStyle(
        color: Colors.white,
        fontFamily: 'Rajdhani',
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        isDense: true,
        filled: true,
        fillColor: Colors.black.withValues(alpha: 0.2),
        labelText: label,
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontFamily: 'Rajdhani',
          fontWeight: FontWeight.w600,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: AppConstants.neonCyan.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide:
              BorderSide(color: AppConstants.neonCyan.withValues(alpha: 0.25)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(color: AppConstants.neonCyan),
        ),
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: enabled ? 0.22 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: color.withValues(alpha: enabled ? 0.8 : 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: enabled ? 0.95 : 0.55),
            fontFamily: 'Orbitron',
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
