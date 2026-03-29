import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/services/market_data_service.dart';
import '../../../data/models/asset_model.dart';
import '../../../routes/app_routes.dart';
import '../controllers/asset_detail_controller.dart';

/// Full-screen price chart for a single watchlist asset.
class AssetDetailView extends StatefulWidget {
  const AssetDetailView({super.key});

  @override
  State<AssetDetailView> createState() => _AssetDetailViewState();
}

class _AssetDetailViewState extends State<AssetDetailView> {
  late final AssetDetailController _ctrl;

  @override
  void initState() {
    super.initState();
    final asset = Get.arguments as AssetModel;
    _ctrl = Get.put(
      AssetDetailController(
        marketData: MarketDataService(),
        asset: asset,
      ),
      tag: asset.id,
    );
  }

  @override
  void dispose() {
    Get.delete<AssetDetailController>(tag: _ctrl.asset.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asset = _ctrl.asset;
    final change = asset.priceChange24h;
    final isPositive = (change ?? 0) >= 0;
    final changeColor = change == null
        ? AppColors.textMuted
        : isPositive
            ? AppColors.success
            : AppColors.danger;

    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Dark header ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back + symbol row
                  Row(
                    children: [
                      GestureDetector(
                        onTap: Get.back,
                        child: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: const Icon(Icons.arrow_back_rounded,
                              color: AppColors.surface, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            asset.symbol,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: AppColors.surface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              asset.type.toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Ask AI shortcut
                      GestureDetector(
                        onTap: () {
                          final range = _ctrl.selectedRange.value;
                          final spots = _ctrl.spots;
                          final high = _ctrl.chartHigh.value;
                          final low = _ctrl.chartLow.value;
                          final current = asset.currentPrice;
                          final change24h = asset.priceChange24h;

                          final hasChart = spots.length >= 2;
                          final startPrice = hasChart ? spots.first.y : null;
                          final endPrice = hasChart ? spots.last.y : null;
                          final periodChangePct = (startPrice != null &&
                                  startPrice > 0 &&
                                  endPrice != null)
                              ? ((endPrice - startPrice) / startPrice * 100)
                                  .toStringAsFixed(2)
                              : null;

                          final buf = StringBuffer();
                          buf.writeln('Asset: ${asset.symbol} (${asset.type})');
                          buf.writeln('Selected period: $range chart');
                          if (current != null) {
                            buf.writeln(
                                'Current price: \$${current.toStringAsFixed(2)}');
                          }
                          if (change24h != null) {
                            buf.writeln(
                                '24h change: ${change24h >= 0 ? '+' : ''}${change24h.toStringAsFixed(2)}%');
                          }
                          if (hasChart) {
                            buf.writeln(
                                'Period high: \$${high.toStringAsFixed(2)}');
                            buf.writeln(
                                'Period low: \$${low.toStringAsFixed(2)}');
                            if (periodChangePct != null) {
                              buf.writeln(
                                  'Period performance: ${double.parse(periodChangePct) >= 0 ? '+' : ''}$periodChangePct% over $range');
                            }
                          }

                          final displayPrompt =
                              'Analyze ${asset.symbol} — $range chart';

                          Get.toNamed(
                            AppRoutes.AI_CHAT,
                            arguments: {
                              'prompt': displayPrompt,
                              'assetContext': buf.toString().trim(),
                            },
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.aiStrip,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.aiBorder),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  size: 13, color: Color(0xFF92400E)),
                              SizedBox(width: 5),
                              Text(
                                'Ask AI',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF92400E),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Price display
                  Obx(() {
                    final displayPrice =
                        _ctrl.touchedPrice.value ?? asset.currentPrice;
                    return Text(
                      displayPrice != null
                          ? Formatters.currencyFromDouble(displayPrice)
                          : '—',
                      style: const TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.w700,
                        color: AppColors.surface,
                        letterSpacing: -1.5,
                      ),
                    );
                  }),
                  const SizedBox(height: 6),

                  // 24h change pill
                  if (change != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: changeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isPositive
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 12,
                            color: changeColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${change.abs().toStringAsFixed(2)}% today',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: changeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // ── White card ──────────────────────────────────────────────
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),

                    // Range chips
                    Obx(() => _RangeChips(
                          selected: _ctrl.selectedRange.value,
                          onSelected: (r) => _ctrl.selectedRange.value = r,
                        )),

                    const SizedBox(height: 8),

                    // Chart area
                    Expanded(
                      child: Obx(() {
                        if (_ctrl.isLoadingChart.value) {
                          return const Center(
                            child: CircularProgressIndicator(
                                color: AppColors.primary),
                          );
                        }
                        if (_ctrl.spots.length < 2) {
                          return _EmptyChart(symbol: asset.symbol);
                        }
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                          child: _PriceChart(ctrl: _ctrl),
                        );
                      }),
                    ),

                    // High / Low stats
                    Obx(() {
                      if (_ctrl.spots.length < 2) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        child: Row(
                          children: [
                            _StatChip(
                                label: 'High',
                                value: Formatters.currencyFromDouble(
                                    _ctrl.chartHigh.value),
                                color: AppColors.success),
                            const SizedBox(width: 12),
                            _StatChip(
                                label: 'Low',
                                value: Formatters.currencyFromDouble(
                                    _ctrl.chartLow.value),
                                color: AppColors.danger),
                            const SizedBox(width: 12),
                            if (asset.currentPrice != null)
                              _StatChip(
                                  label: 'Current',
                                  value: Formatters.currencyFromDouble(
                                      asset.currentPrice!),
                                  color: AppColors.primary),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Range chips ────────────────────────────────────────────────────────────

class _RangeChips extends StatelessWidget {
  final String selected;
  final void Function(String) onSelected;

  const _RangeChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: AssetDetailController.ranges.map((r) {
        final isSelected = r == selected;
        return GestureDetector(
          onTap: () => onSelected(r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            padding:
                const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.dark : Colors.transparent,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              r,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.surface
                    : AppColors.textMuted,
              ),
            ),
          ),
        );
      }).toList(),
      ),
    );
  }
}

// ── Price chart ────────────────────────────────────────────────────────────

class _PriceChart extends StatelessWidget {
  final AssetDetailController ctrl;

  const _PriceChart({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final spots = ctrl.spots;
    final isPositive = ctrl.chartIsPositive;
    final lineColor = isPositive ? AppColors.success : AppColors.danger;

    final prices = spots.map((s) => s.y).toList();
    final minY = prices.reduce((a, b) => a < b ? a : b);
    final maxY = prices.reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: minY - padding,
        maxY: maxY + padding,
        clipData: const FlClipData.all(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(show: false),
        lineTouchData: LineTouchData(
          touchCallback: (event, response) {
            if (response?.lineBarSpots?.isNotEmpty == true) {
              ctrl.touchedPrice.value =
                  response!.lineBarSpots!.first.y;
            } else {
              ctrl.touchedPrice.value = null;
            }
          },
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((_) {
              return TouchedSpotIndicatorData(
                FlLine(
                    color: AppColors.textMuted.withValues(alpha: 0.4),
                    strokeWidth: 1,
                    dashArray: [4, 4]),
                FlDotData(
                  show: true,
                  getDotPainter: (_, _, _, _) =>
                      FlDotCirclePainter(
                    radius: 5,
                    color: lineColor,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.dark,
            tooltipBorderRadius: BorderRadius.circular(8),
            tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 6),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  Formatters.currencyFromDouble(spot.y),
                  const TextStyle(
                    color: AppColors.surface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: List.unmodifiable(spots),
            isCurved: true,
            curveSmoothness: 0.25,
            color: lineColor,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  lineColor.withValues(alpha: 0.2),
                  lineColor.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

// ── Empty state ────────────────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final String symbol;
  const _EmptyChart({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.show_chart_rounded,
              size: 52, color: AppColors.border),
          const SizedBox(height: 12),
          Text(
            'No price history for $symbol yet.',
            style: AppTextStyles.bodyMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Data will appear once the price feed is active.',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Stat chip ─────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.textMuted)),
            const SizedBox(height: 3),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}
