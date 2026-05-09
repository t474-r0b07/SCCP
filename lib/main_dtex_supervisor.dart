import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/views/dtex_supervisor_android_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  Get.put(AuthController(), permanent: true);
  runApp(const DtexSupervisorAndroidApp());
}
