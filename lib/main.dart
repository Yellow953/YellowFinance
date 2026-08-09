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
import 'core/services/home_category_filter_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/sync_service.dart';
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
  // SyncService depends on ConnectivityService — register it after.
  Get.put(SyncService(), permanent: true);
  Get.put(AuthService(), permanent: true);
  Get.put(FirestoreProvider(), permanent: true);
  // Home category settings — awaited so HomeController never reads an
  // unloaded (i.e. "nothing excluded") filter on the first frame.
  await Get.putAsync(() => HomeCategoryFilterService().init(), permanent: true);
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

/// Bottom status bar reporting connectivity and unsynced work.
///
/// Three states: offline, offline with queued changes, and online while the
/// queue drains. It stays hidden when there's nothing to report.
class _OfflineBannerOverlay extends StatelessWidget {
  final Widget child;

  const _OfflineBannerOverlay({required this.child});

  @override
  Widget build(BuildContext context) {
    final connectivity = Get.find<ConnectivityService>();
    final sync = Get.find<SyncService>();
    return Obx(() {
      final offline = !connectivity.isOnline.value;
      final pending = sync.pendingTotal;
      final changes = pending == 1 ? '1 change' : '$pending changes';

      final IconData? icon;
      final String? message;
      if (offline && pending > 0) {
        icon = Icons.cloud_off_rounded;
        message = 'No internet · $changes saved on this device';
      } else if (offline) {
        icon = Icons.wifi_off_rounded;
        message = 'No internet connection';
      } else if (pending > 0) {
        icon = Icons.cloud_upload_rounded;
        message = 'Syncing $changes…';
      } else {
        icon = null;
        message = null;
      }

      return Column(
        children: [
          Expanded(child: child),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: message == null
                ? const SizedBox.shrink()
                : SafeArea(
                    top: false,
                    child: Container(
                      width: double.infinity,
                      color: AppColors.dark,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, size: 14, color: AppColors.textMuted),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              message,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      );
    });
  }
}
