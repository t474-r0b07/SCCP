import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../data/models/allowed_admin_model.dart';
import '../../data/repositories/supabase_repository.dart';

class AuthController extends GetxController {
  final SupabaseRepository _repository = SupabaseRepository();
  final Rxn<AllowedAdmin> currentAdmin = Rxn<AllowedAdmin>();
  final RxBool isLoading = false.obs;
  final RxBool isInitialized = false.obs;
  final RxBool directorPinVerified = false.obs;
  StreamSubscription<AuthState>? _authSubscription;
  static const int _maxPinAttempts = 5;
  static const Duration _pinLockDuration = Duration(minutes: 2);
  int _failedPinAttempts = 0;
  DateTime? _pinLockUntil;

  String get emailActual =>
      Supabase.instance.client.auth.currentUser?.email?.trim().toLowerCase() ??
      '';

  bool get isDirector => currentAdmin.value?.esDirector == true;
  bool get isSupervisor => currentAdmin.value?.esSupervisor == true;
  bool get hasDtexAccess => currentAdmin.value?.tieneAccesoDtex == true;
  bool get isAuthenticated =>
      Supabase.instance.client.auth.currentUser != null &&
      currentAdmin.value != null;
  bool get hasCommanderAccess => isDirector && directorPinVerified.value;
  bool get isPinVerificationLocked =>
      _pinLockUntil != null && DateTime.now().isBefore(_pinLockUntil!);
  int get pinLockRemainingSeconds {
    if (!isPinVerificationLocked) return 0;
    final remaining = _pinLockUntil!.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  @override
  void onInit() {
    super.onInit();
    _listenAuthState();
    _restoreSession().whenComplete(() {
      isInitialized.value = true;
    });
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }

  Future<void> _restoreSession() async {
    final email = emailActual;
    if (email.isEmpty) return;

    try {
      final admin = await _repository.getAdminByEmail(email);
      if (admin != null) {
        currentAdmin.value = admin;
        directorPinVerified.value = !admin.esDirector;
      } else {
        await Supabase.instance.client.auth.signOut();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AUTH] Error restaurando sesión: $e');
      }
    }
  }

  void _listenAuthState() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) async {
        final authEvent = event.event;
        if (authEvent == AuthChangeEvent.signedOut) {
          currentAdmin.value = null;
          directorPinVerified.value = false;
          _resetPinGuard();
          return;
        }

        if (authEvent == AuthChangeEvent.signedIn ||
            authEvent == AuthChangeEvent.tokenRefreshed) {
          await _restoreSession();
        }
      },
    );
  }

  Future<bool> login({
    required String email,
    required String password,
  }) async {
    isLoading.value = true;
    try {
      final auth = Supabase.instance.client.auth;
      final loginEmail = email.trim();
      final normalizedEmail = loginEmail.toLowerCase();

      await auth.signInWithPassword(
        email: loginEmail,
        password: password,
      );
      final admin = await _repository.getAdminByEmail(normalizedEmail);

      if (admin == null || !admin.activo) {
        await auth.signOut();
        return false;
      }

      _resetPinGuard();
      currentAdmin.value = admin;
      directorPinVerified.value = !admin.esDirector;
      await _repository.actualizarUltimoLogin(admin.id);
      final loginLogged = await _repository.registrarLoginLog(
        adminEmail: admin.email,
        adminNombre: admin.nombre,
        status: 'active',
      );
      if (!loginLogged && kDebugMode) {
        debugPrint('⚠️ [AUTH] login_logs no registrado para ${admin.email}');
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AUTH] Error login: $e');
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> verifyDirectorPin(String pin) async {
    final admin = currentAdmin.value;
    if (admin == null || !admin.esDirector) return false;
    final ok = await _verifyAdminPin(email: admin.email, pin: pin);
    if (ok) {
      directorPinVerified.value = true;
    }
    return ok;
  }

  Future<bool> verifyCurrentAdminPin(String pin) async {
    final admin = currentAdmin.value;
    if (admin == null) return false;
    return _verifyAdminPin(email: admin.email, pin: pin);
  }

  Future<void> logout() async {
    final admin = currentAdmin.value;
    try {
      if (admin != null) {
        final closed =
            await _repository.cerrarSesionLogActiva(adminEmail: admin.email);
        if (!closed && kDebugMode) {
          debugPrint(
              '⚠️ [AUTH] no se pudo cerrar login_log para ${admin.email}');
        }
      }
      await Supabase.instance.client.auth.signOut();
    } finally {
      currentAdmin.value = null;
      directorPinVerified.value = false;
      _resetPinGuard();
    }
  }

  Future<bool> cambiarContrasena({
    required String passwordActual,
    required String nuevaContrasena,
  }) async {
    final current = passwordActual.trim();
    final next = nuevaContrasena.trim();
    final email = emailActual;
    if (email.isEmpty || current.isEmpty || next.isEmpty) return false;
    if (next.length < 8) return false;
    if (current == next) return false;

    try {
      isLoading.value = true;
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: current,
      );
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: next),
      );
      return true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [AUTH] Error cambiando contraseña: $e');
      }
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> cambiarPinAdmin({
    required String pinActual,
    required String nuevoPin,
  }) async {
    final admin = currentAdmin.value;
    final current = pinActual.trim();
    final next = nuevoPin.trim();
    if (admin == null || current.isEmpty || next.isEmpty) return false;
    if (!RegExp(r'^\d{4,8}$').hasMatch(next)) return false;
    if (current == next) return false;

    final okCurrent = await _verifyAdminPin(email: admin.email, pin: current);
    if (!okCurrent) return false;

    final updated = await _repository.actualizarPinAdmin(
      adminId: admin.id,
      nuevoPin: next,
    );
    if (updated) {
      _resetPinGuard();
    }
    return updated;
  }

  Future<bool> _verifyAdminPin({
    required String email,
    required String pin,
  }) async {
    if (isPinVerificationLocked) return false;
    final cleanPin = pin.trim();
    if (cleanPin.isEmpty) {
      _registerPinFailure();
      return false;
    }

    final ok = await _repository.verificarPinAdmin(email, cleanPin);
    if (ok) {
      _resetPinGuard();
      return true;
    }
    _registerPinFailure();
    return false;
  }

  void _registerPinFailure() {
    _failedPinAttempts += 1;
    if (_failedPinAttempts >= _maxPinAttempts) {
      _pinLockUntil = DateTime.now().add(_pinLockDuration);
      _failedPinAttempts = 0;
    }
  }

  void _resetPinGuard() {
    _failedPinAttempts = 0;
    _pinLockUntil = null;
  }
}
