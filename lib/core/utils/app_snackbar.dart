import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../constants/app_colors.dart';

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
}
