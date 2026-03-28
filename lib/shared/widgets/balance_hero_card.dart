import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';

/// Dark hero card showing total balance, income, and expenses.
class BalanceHeroCard extends StatelessWidget {
  final int balanceCents;
  final int incomeCents;
  final int expenseCents;

  const BalanceHeroCard({
    super.key,
    required this.balanceCents,
    required this.incomeCents,
    required this.expenseCents,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.dark,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Total Balance',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.currency(balanceCents),
            style: AppTextStyles.displayLarge.copyWith(color: AppColors.surface),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'Income',
                  amount: incomeCents,
                  color: AppColors.success,
                  arrow: Icons.arrow_downward_rounded,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatColumn(
                  label: 'Expenses',
                  amount: expenseCents,
                  color: AppColors.danger,
                  arrow: Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final IconData arrow;

  const _StatColumn({
    required this.label,
    required this.amount,
    required this.color,
    required this.arrow,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(arrow, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style:
                  AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
            ),
            Text(
              Formatters.currency(amount),
              style: AppTextStyles.labelMedium
                  .copyWith(color: AppColors.surface),
            ),
          ],
        ),
      ],
    );
  }
}
