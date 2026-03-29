import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/transaction_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/reports_controller.dart';

/// Reports screen — monthly bar chart + category pie chart + transaction list.
class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final controller = Get.find<ReportsController>();
  final _authCtrl = Get.find<AuthController>();

  static const _routes = [
    AppRoutes.HOME,
    AppRoutes.TRANSACTIONS,
    AppRoutes.PORTFOLIO,
    AppRoutes.REPORTS,
    AppRoutes.AI_CHAT,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      bottomNavigationBar: AppNavBar(
        currentIndex: 3,
        onTap: (i) {
          if (i != 3) Get.offNamed(_routes[i]);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Dark header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reports',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your financial overview',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 20),
                  // Month selector
                  Row(
                    children: [
                      GestureDetector(
                        onTap: controller.previousMonth,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_left_rounded,
                              color: AppColors.surface, size: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Obx(() => Text(
                            Formatters.dateMonthYear(
                                controller.selectedMonth.value),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.surface,
                            ),
                          )),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: controller.nextMonth,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.chevron_right_rounded,
                              color: AppColors.surface, size: 20),
                        ),
                      ),
                      const Spacer(),
                      Obx(() => Row(
                            children: [
                              _InlineStat(
                                label: 'In',
                                cents: controller.monthlyIncomeCents,
                                color: AppColors.success,
                                hidden: _authCtrl.hideBalances.value,
                              ),
                              const SizedBox(width: 16),
                              _InlineStat(
                                label: 'Out',
                                cents: controller.monthlyExpenseCents,
                                color: AppColors.danger,
                                hidden: _authCtrl.hideBalances.value,
                              ),
                            ],
                          )),
                    ],
                  ),
                ],
              ),
            ),

            // White card
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    children: [
                      const Text('6-Month Overview',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      Obx(() {
                        controller.selectedMonth.value;
                        return _BarChartCard(controller: controller);
                      }),
                      const SizedBox(height: 32),
                      const Text('Expenses by Category',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      Obx(() {
                        controller.selectedMonth.value;
                        controller.touchedPieIndex.value;
                        return _PieChartCard(controller: controller);
                      }),
                      const SizedBox(height: 24),
                      const Text('Transactions',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      Obx(() {
                        final groups = controller.transactionsByDay;
                        final hideAmt = _authCtrl.hideBalances.value;
                        if (groups.isEmpty) {
                          return Container(
                            height: 100,
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Center(
                              child: Text('No transactions this month.',
                                  style: AppTextStyles.bodyMedium),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: groups.map((group) {
                            return _DayGroup(
                              date: group.date,
                              transactions: group.txns,
                              hideAmount: hideAmt,
                            );
                          }).toList(),
                        );
                      }),
                    ],
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Inline stat (header) ────────────────────────────────────────────────────

class _InlineStat extends StatelessWidget {
  final String label;
  final int cents;
  final Color color;
  final bool hidden;

  const _InlineStat({
    required this.label,
    required this.cents,
    required this.color,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
        Text(
          hidden ? '••••' : Formatters.currency(cents),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Bar chart ───────────────────────────────────────────────────────────────

class _BarChartCard extends StatelessWidget {
  final ReportsController controller;
  const _BarChartCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final totals = controller.monthlyTotals;
    final selected = controller.selectedMonth.value;
    final maxVal = totals.fold<double>(0, (m, t) {
      final v =
          (t.incomeCents > t.expenseCents ? t.incomeCents : t.expenseCents) /
              100;
      return v > m ? v : m;
    });

    return Container(
      height: 210,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal == 0 ? 100 : maxVal * 1.25,
          barTouchData: BarTouchData(
            enabled: true,
            touchCallback: (event, response) {
              if (event is FlTapUpEvent &&
                  response != null &&
                  response.spot != null) {
                final idx = response.spot!.touchedBarGroupIndex;
                if (idx >= 0 && idx < totals.length) {
                  controller.setSelectedMonth(totals[idx].month);
                }
              }
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppColors.dark,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final t = totals[groupIndex];
                final label = rodIndex == 0 ? 'Income' : 'Expense';
                final cents =
                    rodIndex == 0 ? t.incomeCents : t.expenseCents;
                return BarTooltipItem(
                  '$label\n${Formatters.currency(cents)}',
                  const TextStyle(
                    color: AppColors.surface,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            leftTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= totals.length) {
                    return const SizedBox.shrink();
                  }
                  final m = totals[idx].month;
                  final isSelected =
                      m.year == selected.year && m.month == selected.month;
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      _monthAbbr(m),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxVal == 0 ? 50 : maxVal * 1.25 / 4,
            getDrawingHorizontalLine: (_) => const FlLine(
              color: AppColors.border,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(totals.length, (i) {
            final t = totals[i];
            final m = t.month;
            final isSelected =
                m.year == selected.year && m.month == selected.month;
            final opacity = isSelected ? 1.0 : 0.35;
            return BarChartGroupData(
              x: i,
              groupVertically: false,
              barRods: [
                BarChartRodData(
                  toY: t.incomeCents / 100,
                  color: AppColors.success.withValues(alpha: opacity),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
                BarChartRodData(
                  toY: t.expenseCents / 100,
                  color: AppColors.danger.withValues(alpha: opacity),
                  width: 12,
                  borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6)),
                ),
              ],
              barsSpace: 4,
            );
          }),
        ),
        duration: const Duration(milliseconds: 200),
      ),
    );
  }

  String _monthAbbr(DateTime m) {
    const abbrs = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return abbrs[m.month - 1];
  }
}

// ─── Pie / donut chart ───────────────────────────────────────────────────────

class _PieChartCard extends StatelessWidget {
  final ReportsController controller;
  const _PieChartCard({required this.controller});

  static const List<Color> _pieColors = [
    AppColors.primary,
    AppColors.success,
    AppColors.danger,
    Color(0xFF6366F1),
    Color(0xFF0EA5E9),
    Color(0xFFF97316),
    Color(0xFF8B5CF6),
    Color(0xFF14B8A6),
  ];

  @override
  Widget build(BuildContext context) {
    final map = controller.expenseCategoryMap;

    if (map.isEmpty) {
      return Container(
        height: 100,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Text('No expense data this month.',
              style: AppTextStyles.bodyMedium),
        ),
      );
    }

    final total = map.values.fold(0, (s, v) => s + v);
    final entries = map.entries.toList();
    final touched = controller.touchedPieIndex.value;

    String centerLabel;
    String centerAmount;
    if (touched >= 0 && touched < entries.length) {
      centerLabel = entries[touched].key;
      centerAmount = Formatters.currency(entries[touched].value);
    } else {
      centerLabel = 'Total';
      centerAmount = Formatters.currency(total);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 220,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sectionsSpace: 3,
                    centerSpaceRadius: 60,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (event is FlTapUpEvent) {
                          final idx = response
                              ?.touchedSection?.touchedSectionIndex ?? -1;
                          controller.touchedPieIndex.value =
                              idx == controller.touchedPieIndex.value ? -1 : idx;
                        }
                      },
                    ),
                    sections: List.generate(entries.length, (i) {
                      final isSelected = i == touched;
                      return PieChartSectionData(
                        value: entries[i].value.toDouble(),
                        color: _pieColors[i % _pieColors.length],
                        title: '',
                        radius: isSelected ? 58 : 50,
                      );
                    }),
                  ),
                  duration: const Duration(milliseconds: 200),
                ),
                // Center label
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w400,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      centerAmount,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Legend
          Column(
            children: List.generate(entries.length, (i) {
              final pct = entries[i].value / total * 100;
              final isSelected = i == touched;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _pieColors[i % _pieColors.length],
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entries[i].key,
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                    Text(
                      Formatters.currency(entries[i].value),
                      style: AppTextStyles.labelSmall.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 36,
                      child: Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: AppTextStyles.labelSmall
                            .copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─── Day group ───────────────────────────────────────────────────────────────

class _DayGroup extends StatelessWidget {
  final DateTime date;
  final List<TransactionModel> transactions;
  final bool hideAmount;

  const _DayGroup({
    required this.date,
    required this.transactions,
    required this.hideAmount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            Formatters.dateDayMonthFull(date),
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < transactions.length; i++) ...[
                TransactionTile(
                  transaction: transactions[i],
                  hideAmount: hideAmount,
                ),
                if (i < transactions.length - 1)
                  const Divider(height: 1, indent: 72, endIndent: 16),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
