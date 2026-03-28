import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Primary full-width button.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Widget? leading;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.backgroundColor,
    this.foregroundColor,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return _OutlinedAppButton(
        label: label,
        isLoading: isLoading,
        onPressed: onPressed,
        leading: leading,
        foregroundColor: foregroundColor,
      );
    }
    return _PrimaryAppButton(
      label: label,
      isLoading: isLoading,
      onPressed: onPressed,
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
    );
  }
}

// ── Primary button ────────────────────────────────────────────────────────

class _PrimaryAppButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _PrimaryAppButton({
    required this.label,
    required this.isLoading,
    this.onPressed,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? AppColors.dark;
    final fg = foregroundColor ?? AppColors.surface;
    final disabled = isLoading || onPressed == null;

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: GestureDetector(
        onTap: disabled ? null : onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: disabled ? AppColors.dark.withValues(alpha: 0.5) : bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: backgroundColor != null
                  ? Colors.transparent
                  : AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(color: fg),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Outlined button ───────────────────────────────────────────────────────

class _OutlinedAppButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Widget? leading;
  final Color? foregroundColor;

  const _OutlinedAppButton({
    required this.label,
    required this.isLoading,
    this.onPressed,
    this.leading,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? AppColors.textPrimary;

    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          backgroundColor: AppColors.surface,
          side: BorderSide(
            color: foregroundColor?.withValues(alpha: 0.4) ?? AppColors.border,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
        child: isLoading
            ? SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: fg.withValues(alpha: 0.6),
                ),
              )
            : leading != null
                ? Stack(
                    alignment: Alignment.center,
                    children: [
                      Align(
                          alignment: Alignment.centerLeft, child: leading!),
                      Text(label,
                          style:
                              AppTextStyles.labelMedium.copyWith(color: fg)),
                    ],
                  )
                : Text(label,
                    style: AppTextStyles.labelMedium.copyWith(color: fg)),
      ),
    );
  }
}
