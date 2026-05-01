import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/app_colors.dart';
import 'core/services/auth_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/notification_service.dart';
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

  // Initialize local notification scheduler.
  await NotificationService.init();

  // Enable Firestore offline persistence so reads work without internet.
  // Cap cache at 50 MB to avoid unbounded disk/memory growth.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: 50 * 1024 * 1024,
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

  // Determine starting screen from Firebase Auth's cached local state so
  // Flutter draws the correct screen on its very first frame — no flash.
  final cachedUser = FirebaseAuth.instance.currentUser;
  final String initialRoute;
  if (cachedUser == null) {
    initialRoute = AppRoutes.LOGIN;
  } else {
    final isVerified = cachedUser.emailVerified ||
        cachedUser.providerData.any((p) => p.providerId == 'google.com');
    initialRoute = isVerified ? AppRoutes.HOME : AppRoutes.VERIFY_EMAIL;
  }

  runApp(YellowFinanceApp(initialRoute: initialRoute));
}

class YellowFinanceApp extends StatelessWidget {
  final String initialRoute;

  const YellowFinanceApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.light,
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
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
