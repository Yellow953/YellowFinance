import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/validators.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/google_logo.dart';
import '../controllers/auth_controller.dart';

/// Login screen.
class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _controller = Get.find<AuthController>();
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top brand area (dark)
            Container(
              color: AppColors.dark,
              padding: const EdgeInsets.fromLTRB(28, 48, 28, 56),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.attach_money_rounded,
                        color: AppColors.dark, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome back',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Sign in to ${AppConstants.appName}',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // White card for form
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppTextField(
                          label: 'Email',
                          controller: _emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          validator: Validators.email,
                          prefixIcon: const Icon(Icons.mail_outline_rounded,
                              color: AppColors.textMuted, size: 20),
                        ),
                        const SizedBox(height: 14),
                        StatefulBuilder(
                          builder: (_, setSuffix) => AppTextField(
                            label: 'Password',
                            controller: _passCtrl,
                            obscureText: _obscure,
                            validator: Validators.password,
                            prefixIcon: const Icon(Icons.lock_outline_rounded,
                                color: AppColors.textMuted, size: 20),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscure
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              onPressed: () => setSuffix(
                                  () => _obscure = !_obscure),
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () =>
                                Get.toNamed(AppRoutes.FORGOT_PASSWORD),
                            child: Text(
                              'Forgot password?',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Obx(() => AppButton(
                              label: 'Sign In',
                              isLoading: _controller.isLoading.value,
                              onPressed: () {
                                if (_formKey.currentState!.validate()) {
                                  _controller.signIn(
                                    email: _emailCtrl.text.trim(),
                                    password: _passCtrl.text,
                                  );
                                }
                              },
                            )),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            const Expanded(child: Divider()),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 14),
                              child: Text('or',
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: AppColors.textMuted)),
                            ),
                            const Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Obx(() => _GoogleButton(
                              isLoading: _controller.isLoading.value,
                              onPressed: _controller.signInWithGoogle,
                            )),
                        const SizedBox(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: AppColors.textMuted),
                            ),
                            GestureDetector(
                              onTap: () => Get.toNamed(AppRoutes.REGISTER),
                              child: Text(
                                'Sign Up',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
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

class _GoogleButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GoogleButton({required this.isLoading, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surface,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.textMuted),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GoogleLogo(size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
