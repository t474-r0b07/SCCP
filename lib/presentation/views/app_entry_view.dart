import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_constants.dart';
import '../controllers/auth_controller.dart';
import 'login_view.dart';

class AppEntryView extends StatelessWidget {
  const AppEntryView({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Obx(() {
      if (!auth.isInitialized.value) {
        return const Scaffold(
          backgroundColor: AppConstants.darkBg,
          body: Center(
            child: CircularProgressIndicator(color: AppConstants.neonCyan),
          ),
        );
      }

      if (!auth.isAuthenticated) {
        return const LoginView();
      }

      if (auth.isDirector) {
        Future.microtask(() => Get.offAllNamed('/dashboard-commander'));
      } else {
        Future.microtask(() => Get.offAllNamed('/dashboard-supervisor'));
      }

      return const Scaffold(
        backgroundColor: AppConstants.darkBg,
        body: Center(
          child: CircularProgressIndicator(color: AppConstants.neonCyan),
        ),
      );
    });
  }
}
