import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/diary_entry_model.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/sport_record_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../budgets/controllers/budget_controller.dart';
import '../../diary/controllers/diary_controller.dart';
import '../controllers/reports_controller.dart';

const _kMonthNames = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// Reports screen — monthly bar chart + category pie chart + transaction list.
class ReportsView extends StatefulWidget {
  const ReportsView({super.key});

  @override
  State<ReportsView> createState() => _ReportsViewState();
}

class _ReportsViewState extends State<ReportsView> {
  final controller = Get.find<ReportsController>();
  final _authCtrl = Get.find<AuthController>();
  final _budgetCtrl = Get.find<BudgetController>();
  final _diaryCtrl = Get.find<DiaryController>();

  static const _routes = [
    AppRoutes.HOME,
    AppRoutes.TODOS,
    AppRoutes.SPORTS,
    AppRoutes.TRANSACTIONS,
    AppRoutes.REPORTS,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      bottomNavigationBar: AppNavBar(
        currentIndex: 4,
        onTap: (i) {
          if (i != 4) Get.offNamed(_routes[i]);
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
                      // Rebuilds only when monthlyTotals cache changes
                      Obx(() {
                        controller.monthlyTotals;
                        return _BarChartCard(
                          controller: controller,
                          hidden: _authCtrl.hideBalances.value,
                        );
                      }),
                      const SizedBox(height: 32),
                      const Text('Expenses by Category',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      // Rebuilds only when expenseCategoryMap cache changes
                      Obx(() {
                        controller.expenseCategoryMap;
                        return _PieChartCard(
                          controller: controller,
                          hidden: _authCtrl.hideBalances.value,
                        );
                      }),
                      const SizedBox(height: 24),

                      // ── Budget performance ────────────────────────────
                      const Text('Budget Performance',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      Obx(() => _BudgetPerformanceCard(
                            // The budget controller keys off an explicit month,
                            // so it reports on whichever month Reports is
                            // showing rather than its own screen's selection.
                            expenses: _budgetCtrl.progressFor(
                              type: AppConstants.txnExpense,
                              month: controller.selectedMonth.value,
                            ),
                            incomes: _budgetCtrl.progressFor(
                              type: AppConstants.txnIncome,
                              month: controller.selectedMonth.value,
                            ),
                            hidden: _authCtrl.hideBalances.value,
                          )),

                      const SizedBox(height: 32),

                      // ── Savings goals ─────────────────────────────────
                      const Text('Savings Goals',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      Obx(() => _GoalsProgressCard(
                            goals: _budgetCtrl.goals.toList(),
                            hidden: _authCtrl.hideBalances.value,
                          )),

                      const SizedBox(height: 32),

                      // ── Diary ─────────────────────────────────────────
                      const Text('Diary', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      Obx(() => _DiaryStatsCard(
                            entries: _diaryCtrl.entries.toList(),
                            month: controller.selectedMonth.value,
                          )),

                      const SizedBox(height: 32),

                      // ── Sports analytics ──────────────────────────────
                      const Text('Activity', style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      // Rebuilds only when _monthlySportRecords or _sportCategoryMap changes
                      Obx(() => _SportsSummaryCard(
                            monthly: controller.monthlySportRecords,
                            categoryMap: controller.sportCategoryMap,
                          )),

                      const SizedBox(height: 32),
                      const Text('Transactions',
                          style: AppTextStyles.titleMedium),
                      const SizedBox(height: 12),
                      // Rebuilds only when _transactionsByDay cache changes
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

// ─── Shared report card shell ────────────────────────────────────────────────

/// White panel every report section sits in.
class _ReportCard extends StatelessWidget {
  final Widget child;

  const _ReportCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Centred "nothing here" line, sized to match a populated card.
class _ReportEmpty extends StatelessWidget {
  final String message;

  const _ReportEmpty(this.message);

  @override
  Widget build(BuildContext context) {
    return _ReportCard(
      child: SizedBox(
        height: 68,
        child: Center(
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }
}

/// Thin progress bar used by the budget and goal rows.
class _MiniBar extends StatelessWidget {
  final double ratio;
  final Color color;

  const _MiniBar({required this.ratio, required this.color});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(height: 6, color: AppColors.background),
          FractionallySizedBox(
            widthFactor: ratio.clamp(0.0, 1.0),
            child: Container(height: 6, color: color),
          ),
        ],
      ),
    );
  }
}

// ─── Budget performance ──────────────────────────────────────────────────────

/// How each budget for the selected month actually turned out.
class _BudgetPerformanceCard extends StatelessWidget {
  final List<BudgetProgress> expenses;
  final List<BudgetProgress> incomes;
  final bool hidden;

  const _BudgetPerformanceCard({
    required this.expenses,
    required this.incomes,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty && incomes.isEmpty) {
      return const _ReportEmpty('No budgets set for this month.');
    }

    final kept =
        expenses.length - BudgetController.overBudgetIn(expenses);
    final metTargets = incomes
        .where((p) => p.actualCents >= p.budget.limitCents)
        .length;
    // Built once and indexed: rebuilding it per iteration to find the last
    // element would also compare budgets by value, which Equatable makes
    // ambiguous for two identically-configured rows.
    final rows = [...expenses, ...incomes];

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (expenses.isNotEmpty)
                Expanded(
                  child: _HeadlineStat(
                    value: '$kept/${expenses.length}',
                    label: expenses.length == 1
                        ? 'limit kept'
                        : 'limits kept',
                    color: kept == expenses.length
                        ? AppColors.success
                        : AppColors.danger,
                  ),
                ),
              if (incomes.isNotEmpty)
                Expanded(
                  child: _HeadlineStat(
                    value: '$metTargets/${incomes.length}',
                    label: incomes.length == 1
                        ? 'target met'
                        : 'targets met',
                    color: metTargets == incomes.length
                        ? AppColors.success
                        : AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++) ...[
            _BudgetPerformanceRow(progress: rows[i], hidden: hidden),
            if (i < rows.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _HeadlineStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _HeadlineStat({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.labelSmall),
      ],
    );
  }
}

class _BudgetPerformanceRow extends StatelessWidget {
  final BudgetProgress progress;
  final bool hidden;

  const _BudgetPerformanceRow({
    required this.progress,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final budget = progress.budget;
    final limit = budget.limitCents;
    final actual = progress.actualCents;
    final ratio = limit <= 0 ? 0.0 : actual / limit;
    final diff = limit - actual;

    // Expense: over the limit is the failure. Income: reaching it is the win.
    final Color color;
    final String status;
    if (budget.isExpense) {
      color = ratio > 1
          ? AppColors.danger
          : (ratio >= 0.8 ? AppColors.primary : AppColors.success);
      status = hidden
          ? '••••'
          : diff >= 0
              ? '${Formatters.currency(diff)} under'
              : '${Formatters.currency(-diff)} over';
    } else {
      color = ratio >= 1 ? AppColors.success : AppColors.primary;
      status = hidden
          ? '••••'
          : diff <= 0
              ? 'Target met'
              : '${Formatters.currency(diff)} short';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                budget.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              hidden
                  ? '••••'
                  : '${Formatters.currency(actual)} / ${Formatters.currency(limit)}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MiniBar(ratio: ratio, color: color),
        const SizedBox(height: 6),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Savings goals ───────────────────────────────────────────────────────────

/// Cumulative goal progress. Not month-scoped — goals accumulate over time, so
/// this reports the same figures whichever month is selected.
class _GoalsProgressCard extends StatelessWidget {
  final List<GoalModel> goals;
  final bool hidden;

  const _GoalsProgressCard({required this.goals, required this.hidden});

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) {
      return const _ReportEmpty('No savings goals yet.');
    }

    final target = goals.fold<int>(0, (a, g) => a + g.targetCents);
    final saved = goals.fold<int>(0, (a, g) => a + g.savedCents);
    final reached = goals.where((g) => g.isComplete).length;

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _HeadlineStat(
                  value: hidden ? '••••' : Formatters.currency(saved),
                  label: 'saved in total',
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: _HeadlineStat(
                  value: '$reached/${goals.length}',
                  label: goals.length == 1 ? 'goal reached' : 'goals reached',
                  color: reached == goals.length
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hidden
                ? 'of •••• targeted'
                : 'of ${Formatters.currency(target)} targeted',
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < goals.length; i++) ...[
            _GoalProgressRow(goal: goals[i], hidden: hidden),
            if (i < goals.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  final GoalModel goal;
  final bool hidden;

  const _GoalProgressRow({required this.goal, required this.hidden});

  @override
  Widget build(BuildContext context) {
    final color =
        goal.isComplete ? AppColors.success : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${(goal.progress * 100).round()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _MiniBar(ratio: goal.progress, color: color),
        const SizedBox(height: 6),
        Text(
          hidden
              ? '•••• of ••••'
              : '${Formatters.currency(goal.savedCents)} of ${Formatters.currency(goal.targetCents)}',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ─── Diary stats ─────────────────────────────────────────────────────────────

/// Writing activity and mood mix for the selected month.
class _DiaryStatsCard extends StatelessWidget {
  final List<DiaryEntryModel> entries;
  final DateTime month;

  const _DiaryStatsCard({required this.entries, required this.month});

  @override
  Widget build(BuildContext context) {
    final monthly = entries
        .where((e) => e.date.year == month.year && e.date.month == month.month)
        .toList();

    if (monthly.isEmpty) {
      return const _ReportEmpty('No diary entries this month.');
    }

    // Distinct days matter more than raw entries — two entries in one day is
    // still one day of journalling.
    final daysWritten = monthly
        .map((e) => DateTime(e.date.year, e.date.month, e.date.day))
        .toSet()
        .length;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final words = monthly.fold<int>(0, (a, e) => a + e.wordCount);

    final moods = <Mood, int>{};
    for (final e in monthly.where((e) => e.mood != Mood.none)) {
      moods[e.mood] = (moods[e.mood] ?? 0) + 1;
    }
    final ranked = moods.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _ReportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _HeadlineStat(
                  value: '${monthly.length}',
                  label: monthly.length == 1 ? 'entry' : 'entries',
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: _HeadlineStat(
                  value: '$daysWritten/$daysInMonth',
                  label: 'days written',
                  color: AppColors.primary,
                ),
              ),
              Expanded(
                child: _HeadlineStat(
                  value: Formatters.compact(words),
                  label: 'words',
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _MiniBar(
            ratio: daysWritten / daysInMonth,
            color: AppColors.primary,
          ),
          if (ranked.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('MOOD', style: AppTextStyles.labelSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in ranked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${e.key.emoji} ${e.key.label} · ${e.value}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sports summary card ─────────────────────────────────────────────────────

class _SportsSummaryCard extends StatelessWidget {
  final List<SportRecordModel> monthly;
  final Map<String, int> categoryMap;

  const _SportsSummaryCard({
    required this.monthly,
    required this.categoryMap,
  });

  @override
  Widget build(BuildContext context) {
    final maxCount =
        categoryMap.values.fold(0, (m, v) => v > m ? v : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total sessions chip
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: AppColors.dark, size: 18),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sessions this month',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                  Text(
                    '${monthly.length}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Get.toNamed(AppRoutes.SPORTS),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (categoryMap.isNotEmpty) ...[
          const SizedBox(height: 12),
          // Category breakdown
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('By category',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 12),
                ...categoryMap.entries.map((e) {
                  final frac = maxCount > 0 ? e.value / maxCount : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 88,
                          child: Text(
                            e.key,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: frac.toDouble(),
                              minHeight: 8,
                              backgroundColor: AppColors.background,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 24,
                          child: Text(
                            '${e.value}',
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        ],

        if (monthly.isNotEmpty) ...[
          const SizedBox(height: 12),
          // All records this month
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < monthly.length; i++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        // Date
                        SizedBox(
                          width: 44,
                          child: Text(
                            '${_kMonthNames[monthly[i].date.month - 1]} ${monthly[i].date.day}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Category badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            monthly[i].category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Description
                        Expanded(
                          child: Text(
                            monthly[i].description.isEmpty
                                ? '—'
                                : monthly[i].description,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i < monthly.length - 1)
                    const Divider(
                        height: 1, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 8),
      ],
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
  final bool hidden;
  const _BarChartCard({required this.controller, this.hidden = false});

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
                  '$label\n${hidden ? '••••' : Formatters.currency(cents)}',
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
  final bool hidden;
  const _PieChartCard({required this.controller, this.hidden = false});

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

    final entries = map.entries.toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Chart + center label
          SizedBox(
            height: 220,
            child: Obx(() {
              final touched = controller.touchedPieIndex.value;
              final hiddenCats = controller.hiddenPieCategories.value;

              final visibleEntries =
                  entries.where((e) => !hiddenCats.contains(e.key)).toList();
              final visibleTotal =
                  visibleEntries.fold(0, (s, e) => s + e.value);

              String centerLabel;
              String centerAmount;
              if (visibleEntries.isEmpty) {
                centerLabel = 'All hidden';
                centerAmount = '';
              } else if (touched >= 0 && touched < visibleEntries.length) {
                centerLabel = visibleEntries[touched].key;
                centerAmount = hidden
                    ? '••••'
                    : Formatters.currency(visibleEntries[touched].value);
              } else {
                centerLabel = 'Total';
                centerAmount =
                    hidden ? '••••' : Formatters.currency(visibleTotal);
              }

              return Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 60,
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          if (event is FlTapUpEvent) {
                            final idx = response?.touchedSection
                                    ?.touchedSectionIndex ??
                                -1;
                            controller.touchedPieIndex.value =
                                idx == controller.touchedPieIndex.value
                                    ? -1
                                    : idx;
                          }
                        },
                      ),
                      sections: List.generate(visibleEntries.length, (i) {
                        final origIdx = entries
                            .indexWhere((e) => e.key == visibleEntries[i].key);
                        return PieChartSectionData(
                          value: visibleEntries[i].value.toDouble(),
                          color: _pieColors[origIdx % _pieColors.length],
                          title: '',
                          radius: i == touched ? 58 : 50,
                        );
                      }),
                    ),
                    duration: const Duration(milliseconds: 200),
                  ),
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
                      if (centerAmount.isNotEmpty) ...[
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
                    ],
                  ),
                ],
              );
            }),
          ),
          const SizedBox(height: 16),
          // Legend — tap a row to hide/show it
          Obx(() {
            final touched = controller.touchedPieIndex.value;
            final hiddenCats = controller.hiddenPieCategories.value;

            final visibleEntries =
                entries.where((e) => !hiddenCats.contains(e.key)).toList();
            final visibleTotal =
                visibleEntries.fold(0, (s, e) => s + e.value);

            return Column(
              children: List.generate(entries.length, (i) {
                final entry = entries[i];
                final isHidden = hiddenCats.contains(entry.key);
                final visibleIdx =
                    visibleEntries.indexWhere((e) => e.key == entry.key);
                final isSelected = !isHidden && visibleIdx == touched;
                final pct = !isHidden && visibleTotal > 0
                    ? entry.value / visibleTotal * 100
                    : 0.0;

                return GestureDetector(
                  onTap: () => controller.togglePieCategory(entry.key),
                  child: Opacity(
                    opacity: isHidden ? 0.35 : 1.0,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isHidden
                                  ? AppColors.textMuted
                                  : _pieColors[i % _pieColors.length],
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              entry.key,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppColors.textPrimary
                                    : AppColors.textMuted,
                                decoration: isHidden
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                decorationColor: AppColors.textMuted,
                              ),
                            ),
                          ),
                          Text(
                            hidden
                                ? '••••'
                                : Formatters.currency(entry.value),
                            style: AppTextStyles.labelSmall.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 36,
                            child: Text(
                              isHidden ? '—' : '${pct.toStringAsFixed(0)}%',
                              style: AppTextStyles.labelSmall
                                  .copyWith(color: AppColors.textMuted),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            );
          }),
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
