import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/app_colors.dart';
import 'core/services/auth_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/theme/app_theme.dart';
import 'data/providers/firestore_provider.dart';
import 'data/repositories/auth_repository.dart';
import 'modules/auth/controllers/auth_controller.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore offline persistence so reads work without internet.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Register global services
  Get.put(ConnectivityService(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(FirestoreProvider(), permanent: true);
  Get.put(
    Dio(BaseOptions(connectTimeout: const Duration(seconds: 15))),
    permanent: true,
  );

  // AuthController is permanent — it manages app-wide auth state
  // and must remain alive for all modules to call Get.find<AuthController>().
  Get.put(
    AuthController(
      authRepo: AuthRepository(
        authService: Get.find<AuthService>(),
        firestore: Get.find<FirestoreProvider>(),
      ),
    ),
    permanent: true,
  );

  runApp(const YellowFinanceApp());
}

class YellowFinanceApp extends StatelessWidget {
  const YellowFinanceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.LOGIN,
      getPages: AppPages.routes,
      defaultTransition: Transition.fadeIn,
      builder: (context, child) => _OfflineBannerOverlay(child: child!),
    );
  }
}

class _OfflineBannerOverlay extends StatelessWidget {
  final Widget child;

  const _OfflineBannerOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    return Obx(() {
      final offline = !connectivity.isOnline.value;
      return Column(
        children: [
          Expanded(child: child),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: offline
                ? SafeArea(
                    top: false,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.dark,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 14, color: AppColors.textMuted),
                          SizedBox(width: 6),
                          Text(
                            'No internet connection',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );
    });
  }
}
