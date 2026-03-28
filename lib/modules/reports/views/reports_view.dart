import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/reports_controller.dart';

/// Reports screen — monthly bar chart + category pie chart.
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
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textMuted),
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
                      // Summary inline
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
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Obx(() {
                  if (controller.isLoading.value) {
                    return const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary));
                  }
                  return ListView(
                    padding:
                        const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    children: [
                      const Text('6-Month Overview',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 16),
                      Obx(() {
                        controller.selectedMonth.value;
                        return _BarChartCard(controller: controller);
                      }),
                      const SizedBox(height: 24),
                      const Text('Expenses by Category',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 16),
                      Obx(() {
                        controller.selectedMonth.value;
                        return _PieChartCard(controller: controller);
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

class _InlineStat extends StatelessWidget {
  final String label;
  final int cents;
  final Color color;
  final bool hidden;

  const _InlineStat(
      {required this.label,
      required this.cents,
      required this.color,
      this.hidden = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, color: AppColors.textMuted)),
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

class _BarChartCard extends StatelessWidget {
  final ReportsController controller;
  const _BarChartCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final totals = controller.monthlyTotals;
    final maxVal = totals.fold<double>(0, (m, t) {
      final v = (t.incomeCents > t.expenseCents
              ? t.incomeCents
              : t.expenseCents) /
          100;
      return v > m ? v : m;
    });

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: BarChart(
        BarChartData(
          maxY: maxVal == 0 ? 100 : maxVal * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= totals.length) {
                    return const SizedBox.shrink();
                  }
                  return Text(
                    Formatters.dateDayMonth(totals[idx].month)
                        .split(' ')
                        .last
                        .substring(0, 3),
                    style: AppTextStyles.labelSmall,
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(totals.length, (i) {
            final t = totals[i];
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: t.incomeCents / 100,
                  color: AppColors.success,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
                BarChartRodData(
                  toY: t.expenseCents / 100,
                  color: AppColors.danger,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }
}

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
        height: 160,
        padding: const EdgeInsets.all(16),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 180,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 50,
                sections: List.generate(entries.length, (i) {
                  final pct = entries[i].value / total * 100;
                  return PieChartSectionData(
                    value: entries[i].value.toDouble(),
                    color: _pieColors[i % _pieColors.length],
                    title: '${pct.toStringAsFixed(0)}%',
                    titleStyle: AppTextStyles.labelSmall
                        .copyWith(color: AppColors.surface),
                    radius: 55,
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: List.generate(entries.length, (i) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _pieColors[i % _pieColors.length],
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(entries[i].key,
                      style: AppTextStyles.bodySmall),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
