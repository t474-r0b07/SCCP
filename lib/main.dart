import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'presentation/controllers/auth_controller.dart';
import 'presentation/middleware/auth_middleware.dart';
import 'presentation/views/app_entry_view.dart';
import 'presentation/views/login_view.dart';
import 'presentation/views/dashboard_view.dart';
import 'presentation/views/commander_dashboard_view.dart';
import 'presentation/views/dtex_custodio_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const SCCPApp());
}

class SCCPApp extends StatelessWidget {
  const SCCPApp({super.key});

  String _resolveInitialRoute() {
    final path = Uri.base.path.trim();
    if (path.isEmpty || path == '/') return '/';
    return path;
  }

  @override
  Widget build(BuildContext context) {
    Get.put(AuthController(), permanent: true);

    return GetMaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: _resolveInitialRoute(),
      getPages: [
        GetPage(name: '/', page: () => const AppEntryView()),
        GetPage(name: '/login', page: () => const LoginView()),
        GetPage(
          name: '/dashboard',
          page: () => DashboardView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/dashboard-supervisor',
          page: () => DashboardView(),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/dashboard-test',
          page: () => const DashboardView(
            showInitializationOverlay: false,
            safeMode: true,
          ),
          middlewares: [AuthMiddleware()],
        ),
        GetPage(
          name: '/dashboard-commander',
          page: () => const CommanderDashboardView(),
          middlewares: [DirectorMiddleware()],
        ),
        GetPage(
          name: '/dtex/custodio',
          page: () => const DtexCustodioView(),
        ),
      ],
    );
  }
}
