import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';

/// Splash screen shown while Firebase initializes.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.attach_money_rounded,
                color: AppColors.dark,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(AppConstants.appName, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(
              AppConstants.appTagline,
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
