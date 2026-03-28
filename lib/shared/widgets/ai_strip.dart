import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

/// Amber insight banner used across screens for AI suggestions.
class AiStrip extends StatelessWidget {
  final String message;
  final VoidCallback? onTap;

  const AiStrip({super.key, required this.message, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.aiStrip,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.aiBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('✦', style: TextStyle(fontSize: 14, color: AppColors.primary)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded,
                  size: 16, color: AppColors.textMuted),
            ],
          ],
        ),
      ),
    );
  }
}
