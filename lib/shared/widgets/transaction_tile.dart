import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/transaction_model.dart';

/// List tile for a single transaction.
class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final bool hideAmount;

  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.hideAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final amountColor = isIncome ? AppColors.success : AppColors.danger;
    final amountPrefix = isIncome ? '+' : '-';
    final icon =
        isIncome ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final displayTitle =
        transaction.title.isNotEmpty ? transaction.title : transaction.category;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: amountColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: amountColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Title + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayTitle,
                    style: AppTextStyles.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${transaction.category} · ${Formatters.dateDayMonth(transaction.date)}',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textMuted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Amount
            Text(
              hideAmount
                  ? '••••'
                  : '$amountPrefix${Formatters.currency(transaction.amount)}',
              style: AppTextStyles.labelMedium.copyWith(color: amountColor),
            ),
          ],
        ),
      ),
    );
  }
}
