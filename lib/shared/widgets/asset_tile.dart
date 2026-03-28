import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/asset_model.dart';

/// List tile for a single watchlist asset.
class AssetTile extends StatelessWidget {
  final AssetModel asset;
  final VoidCallback? onTap;
  final VoidCallback? onAskAi;
  final bool hideAmount;

  const AssetTile({
    super.key,
    required this.asset,
    this.onTap,
    this.onAskAi,
    this.hideAmount = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrice = asset.currentPrice != null;
    final change = asset.priceChange24h;
    final isPositive = (change ?? 0) >= 0;
    final changeColor = change == null
        ? AppColors.textMuted
        : isPositive
            ? AppColors.success
            : AppColors.danger;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Symbol icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                asset.symbol.length > 3
                    ? asset.symbol.substring(0, 3)
                    : asset.symbol,
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.dark,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Symbol + type badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  asset.symbol,
                  style: AppTextStyles.bodyMedium
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    asset.type.toUpperCase(),
                    style: AppTextStyles.labelSmall.copyWith(
                      fontSize: 10,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Price + 24h change
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hideAmount
                    ? '••••'
                    : hasPrice
                        ? Formatters.currencyFromDouble(asset.currentPrice!)
                        : '—',
                style: AppTextStyles.labelMedium,
              ),
              if (!hideAmount && change != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPositive
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 11,
                      color: changeColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${change.abs().toStringAsFixed(2)}%',
                      style:
                          AppTextStyles.bodySmall.copyWith(color: changeColor),
                    ),
                  ],
                ),
              ] else if (!hideAmount)
                Text('—',
                    style:
                        AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(width: 10),

          // Ask AI button
          GestureDetector(
            onTap: onAskAi,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.aiStrip,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.aiBorder),
              ),
              child: const Text(
                'Ask AI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF92400E),
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
