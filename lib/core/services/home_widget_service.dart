import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';

import '../../routes/app_routes.dart';
import '../constants/app_constants.dart';
import 'pending_launch.dart';

/// Routes taps on the home-screen Quick Add widget into the app's add flows.
///
/// The widget is static — it shows no user data — so nothing is ever written to
/// shared widget storage. Each button is just a deep link of the form
/// `yellowfinance://add/<action>?homeWidget`; the `homeWidget` query item is
/// what the plugin uses to recognise the URL as a widget tap on iOS. These URLs
/// are mirrored in `ios/QuickAddWidget/QuickAddWidget.swift` and
/// `android/.../QuickAddWidgetProvider.kt` — keep all three in sync.
abstract class HomeWidgetService {
  static const _host = 'add';

  static StreamSubscription<Uri?>? _clicks;

  /// Picks up a widget tap that cold-started the app and starts listening for
  /// taps while it runs. Call once in `main()`, before `runApp`.
  static Future<void> init() async {
    try {
      final target = _targetFor(
        await HomeWidget.initiallyLaunchedFromHomeWidget(),
      );
      if (target != null) {
        // GetX has no navigator yet — HomeController opens it on first load.
        PendingLaunch.set(target.route, arguments: target.arguments);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Widget launch check failed: $e');
    }
    _clicks ??= HomeWidget.widgetClicked.listen(_onClick);
  }

  static void _onClick(Uri? uri) {
    final target = _targetFor(uri);
    if (target == null) return;

    if (!_hasSession) {
      // The auth flow ends on Home, whose controller consumes this.
      PendingLaunch.set(target.route, arguments: target.arguments);
      return;
    }
    // Same shape as a notification tap: a fresh stack with Home underneath,
    // so back from the add flow always lands somewhere sensible and a route
    // already open (e.g. a half-filled add form) can't collide with the new one.
    Future.delayed(Duration.zero, () {
      Get.offAllNamed(AppRoutes.HOME);
      Get.toNamed(target.route, arguments: target.arguments);
    });
  }

  /// Mirrors [AuthMiddleware]: signed in, and verified unless via Google.
  static bool get _hasSession {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    return user.emailVerified ||
        user.providerData.any((p) => p.providerId == 'google.com');
  }

  static ({String route, Object? arguments})? _targetFor(Uri? uri) {
    if (uri == null || uri.host != _host || uri.pathSegments.isEmpty) {
      return null;
    }
    switch (uri.pathSegments.first) {
      case 'expense':
        return (
          route: AppRoutes.ADD_TRANSACTION,
          arguments: AppConstants.txnExpense,
        );
      case 'income':
        return (
          route: AppRoutes.ADD_TRANSACTION,
          arguments: AppConstants.txnIncome,
        );
      case 'task':
        return (route: AppRoutes.TODOS, arguments: 'add');
      case 'sport':
        return (route: AppRoutes.SPORTS, arguments: 'add');
      case 'diary':
        return (route: AppRoutes.DIARY, arguments: 'add');
      default:
        return null;
    }
  }
}
