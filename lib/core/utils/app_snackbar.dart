import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';
import '../services/connectivity_service.dart';

/// Styled GetX snackbar helper. Always dark background, white text.
abstract class AppSnackbar {
  static void show(
    String title,
    String message, {
    bool isError = false,
  }) {
    Get.snackbar(
      title,
      message,
      backgroundColor: AppColors.dark,
      colorText: AppColors.surface,
      icon: Icon(
        isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
        color: isError ? AppColors.danger : AppColors.success,
        size: 22,
      ),
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      borderRadius: 14,
      duration: const Duration(seconds: 3),
      isDismissible: true,
    );
  }

  static void error(String message) => show('Error', message, isError: true);
  static void success(String message) => show('Done', message);

  /// Success message that reflects sync state.
  ///
  /// Shows [onlineMessage] when connected; offline it says the change was
  /// saved locally rather than claiming it reached the server.
  static void saved(String onlineMessage) {
    final online = Get.find<ConnectivityService>().isOnline.value;
    if (online) {
      success(onlineMessage);
    } else {
      show('Saved offline', 'Will sync when you\'re back online.');
    }
  }
}
