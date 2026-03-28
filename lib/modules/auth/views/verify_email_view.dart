import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../controllers/auth_controller.dart';

/// Email verification screen shown after sign-up until the user verifies.
class VerifyEmailView extends StatelessWidget {
  const VerifyEmailView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Dark header
            Container(
              color: AppColors.dark,
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 56),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.mark_email_unread_outlined,
                            color: AppColors.dark, size: 24),
                      ),
                      const SizedBox(width: 14),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verify your email',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.surface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'One last step before you dive in',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.textMuted),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // White card
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Obx(() {
                        final email = controller.user.value?.email ?? '';
                        return Text(
                          email.isNotEmpty
                              ? "We've sent a verification link to $email. Open it to activate your account."
                              : "We've sent a verification link to your email. Open it to activate your account.",
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                            height: 1.5,
                          ),
                        );
                      }),
                      const SizedBox(height: 12),
                      Text(
                        "Don't forget to check your spam folder.",
                        style: AppTextStyles.bodySmall
                            .copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 32),
                      Obx(() => AppButton(
                            label: "I've verified my email",
                            isLoading: controller.isLoading.value,
                            onPressed: controller.checkEmailVerified,
                          )),
                      const SizedBox(height: 14),
                      Obx(() => AppButton(
                            label: 'Resend verification email',
                            isLoading: controller.isLoading.value,
                            isOutlined: true,
                            onPressed: controller.resendVerificationEmail,
                          )),
                      const Spacer(),
                      Center(
                        child: TextButton(
                          onPressed: controller.signOut,
                          child: Text(
                            'Sign out',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
