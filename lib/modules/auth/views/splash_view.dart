import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

/// Splash screen shown while Firebase initializes.
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: Center(
        child: Container(
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
      ),
    );
  }
}
