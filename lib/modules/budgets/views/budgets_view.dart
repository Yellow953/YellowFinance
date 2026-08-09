import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/goal_model.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/budget_controller.dart';

/// Budgets & Goals screen — monthly category limits and savings targets.
class BudgetsView extends StatefulWidget {
  const BudgetsView({super.key});

  @override
  State<BudgetsView> createState() => _BudgetsViewState();
}

class _BudgetsViewState extends State<BudgetsView> {
  final ctrl = Get.find<BudgetController>();

  @override
  void initState() {
    super.initState();
    // Home's "Add Budget" shortcut opens the sheet straight away.
    if (Get.arguments == 'add') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showBudgetSheet(context, ctrl);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(controller: ctrl),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Obx(
                  () => ctrl.tabIndex.value == 0
                      ? _BudgetsTab(controller: ctrl)
                      : _GoalsTab(controller: ctrl),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final BudgetController controller;

  const _Header({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.dark,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        children: [
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
              const Expanded(
                child: Text(
                  'Budgets & Goals',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.surface,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => controller.tabIndex.value == 0
                    ? showBudgetSheet(context, controller)
                    : showGoalSheet(context, controller),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: AppColors.dark, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Obx(() => SegmentedToggle(
                labels: const ['Budgets', 'Goals'],
                selectedIndex: controller.tabIndex.value,
                onChanged: (i) => controller.tabIndex.value = i,
                onDark: true,
              )),
        ],
      ),
    );
  }
}

/// Segmented control matching the Income/Expense toggle in Add Transaction: one
/// track holding the options, with the selected one filled yellow.
///
/// [onDark] picks the track colour — a translucent white lift on the dark
/// header, a solid tint on a light sheet.
class SegmentedToggle extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final bool onDark;

  const SegmentedToggle({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
    required this.onDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: onDark
            ? Colors.white.withValues(alpha: 0.08)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: i == selectedIndex
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    labels[i],
                    textAlign: TextAlign.center,
                    style: AppTextStyles.labelMedium.copyWith(
                      color: i == selectedIndex
                          ? AppColors.dark
                          : AppColors.textMuted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Budgets tab ─────────────────────────────────────────────────────────────

class _BudgetsTab extends StatelessWidget {
  final BudgetController controller;

  const _BudgetsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.budgets.isEmpty) {
        return const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        );
      }

      final expenses = controller.expenseProgress;
      final incomes = controller.incomeProgress;
      // Read inside the Obx so toggling balance visibility repaints the cards —
      // reading it in their own build() would escape this observed scope.
      final hide = Get.find<AuthController>().hideBalances.value;

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          _MonthSelector(controller: controller),
          const SizedBox(height: 16),
          if (expenses.isEmpty && incomes.isEmpty)
            AppEmptyState(
              icon: Icons.pie_chart_outline_rounded,
              // Budgets are per-month, so name the month rather than implying
              // the user has none at all.
              title:
                  'Nothing budgeted for ${Formatters.dateMonthYear(controller.selectedMonth.value)}',
              message:
                  'Set a limit on a category and track what\'s left as you spend.',
              actionLabel: 'Set a budget',
              onAction: () => showBudgetSheet(context, controller),
            )
          else ...[
            if (expenses.isNotEmpty) ...[
              const _SectionLabel('Spending limits'),
              const SizedBox(height: 12),
              for (final p in expenses)
                _BudgetCard(
                  progress: p,
                  controller: controller,
                  hide: hide,
                ),
            ],
            if (incomes.isNotEmpty) ...[
              const SizedBox(height: 24),
              const _SectionLabel('Income targets'),
              const SizedBox(height: 12),
              for (final p in incomes)
                _BudgetCard(
                  progress: p,
                  controller: controller,
                  hide: hide,
                ),
            ],
          ],
        ],
      );
    });
  }
}

class _MonthSelector extends StatelessWidget {
  final BudgetController controller;

  const _MonthSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final canGoForward = controller.canGoForward;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _ArrowButton(
            icon: Icons.chevron_left_rounded,
            onTap: controller.previousMonth,
          ),
          Expanded(
            child: Center(
              child: Text(
                Formatters.dateMonthYear(controller.selectedMonth.value),
                style: AppTextStyles.titleMedium,
              ),
            ),
          ),
          _ArrowButton(
            icon: Icons.chevron_right_rounded,
            // Stops at the current month, unless a later one has a budget
            // planned — then it stays reachable.
            onTap: canGoForward ? controller.nextMonth : null,
          ),
        ],
      );
    });
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ArrowButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? AppColors.textPrimary : AppColors.border,
        ),
      ),
    );
  }
}

/// One budget row with its progress bar.
class _BudgetCard extends StatelessWidget {
  final BudgetProgress progress;
  final BudgetController controller;
  final bool hide;

  const _BudgetCard({
    required this.progress,
    required this.controller,
    required this.hide,
  });

  @override
  Widget build(BuildContext context) {
    final budget = progress.budget;
    final ratio = controller.ratioOf(progress);
    final remaining = budget.limitCents - progress.actualCents;

    // Expense: over the limit is a failure, and 80% is the warning point.
    // Income: hitting the target is the success state, so the scale inverts.
    final Color color;
    if (budget.isExpense) {
      color = ratio > 1
          ? AppColors.danger
          : (ratio >= 0.8 ? AppColors.primary : AppColors.success);
    } else {
      color = ratio >= 1 ? AppColors.success : AppColors.primary;
    }

    return Dismissible(
      key: ValueKey(budget.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.surface),
      ),
      confirmDismiss: (_) => Get.dialog<bool>(
        AlertDialog(
          title: const Text('Delete budget?'),
          content: Text('The limit on ${budget.label} will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => controller.deleteBudget(budget.id),
      child: GestureDetector(
        onTap: () =>
            showBudgetSheet(context, controller, existing: budget),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          budget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.surface,
                          ),
                        ),
                        // Spells out what a grouped budget covers, so
                        // "Essentials" isn't opaque.
                        if (budget.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            budget.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.textMuted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${(ratio * 100).round()}%',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ProgressBar(
                ratio: ratio.clamp(0.0, 1.0),
                color: color,
                // A lifted white rather than the page colour — the track has to
                // read as unfilled space inside a dark card.
                background: Colors.white.withValues(alpha: 0.12),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Text(
                    hide
                        ? '••••'
                        : '${Formatters.currency(progress.actualCents)} of ${Formatters.currency(budget.limitCents)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    _statusLabel(budget, remaining, hide),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(BudgetModel budget, int remaining, bool hide) {
    if (hide) return '••••';
    if (budget.isExpense) {
      return remaining >= 0
          ? '${Formatters.currency(remaining)} left'
          : '${Formatters.currency(-remaining)} over';
    }
    return remaining <= 0
        ? 'Target met'
        : '${Formatters.currency(remaining)} to go';
  }
}

// ── Goals tab ───────────────────────────────────────────────────────────────

class _GoalsTab extends StatelessWidget {
  final BudgetController controller;

  const _GoalsTab({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final goals = controller.goals;
      // Read inside the Obx so a balance-visibility toggle repaints the cards.
      final hide = Get.find<AuthController>().hideBalances.value;
      if (goals.isEmpty) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            AppEmptyState(
              icon: Icons.savings_outlined,
              title: 'No goals yet',
              message:
                  'Set a target — an emergency fund, a trip — and track what you\'ve put aside.',
              actionLabel: 'Create a goal',
              onAction: () => showGoalSheet(context, controller),
            ),
          ],
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          for (final g in goals)
            _GoalCard(goal: g, controller: controller, hide: hide),
        ],
      );
    });
  }
}

class _GoalCard extends StatelessWidget {
  final GoalModel goal;
  final BudgetController controller;
  final bool hide;

  const _GoalCard({
    required this.goal,
    required this.controller,
    required this.hide,
  });

  @override
  Widget build(BuildContext context) {
    final color = goal.isComplete ? AppColors.success : AppColors.primary;

    return Dismissible(
      key: ValueKey(goal.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.surface),
      ),
      confirmDismiss: (_) => Get.dialog<bool>(
        AlertDialog(
          title: const Text('Delete goal?'),
          content: Text('${goal.title} and its saved total will be removed.'),
          actions: [
            TextButton(
              onPressed: () => Get.back(result: false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Get.back(result: true),
              child: const Text('Delete',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      ),
      onDismissed: (_) => controller.deleteGoal(goal.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: goal.isComplete
                        ? AppColors.success.withValues(alpha: 0.14)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    goal.isComplete
                        ? Icons.check_circle_rounded
                        : Icons.savings_outlined,
                    size: 19,
                    color:
                        goal.isComplete ? AppColors.success : AppColors.dark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        goal.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (goal.deadline != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _deadlineLabel(goal.deadline!),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      showGoalSheet(context, controller, existing: goal),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.edit_outlined,
                        size: 17, color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  hide ? '••••••' : Formatters.currency(goal.savedCents),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hide
                      ? 'of ••••'
                      : 'of ${Formatters.currency(goal.targetCents)}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ProgressBar(
              ratio: goal.progress,
              color: color,
              background: AppColors.background,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${(goal.progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  goal.isComplete
                      ? 'Goal reached 🎉'
                      : hide
                          ? '•••• to go'
                          : '${Formatters.currency(goal.remainingCents)} to go',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _GoalActionButton(
                    label: 'Add money',
                    filled: true,
                    onTap: () => showContributeSheet(
                      context,
                      controller,
                      goal,
                      withdraw: false,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _GoalActionButton(
                    label: 'Withdraw',
                    filled: false,
                    onTap: goal.savedCents == 0
                        ? null
                        : () => showContributeSheet(
                              context,
                              controller,
                              goal,
                              withdraw: true,
                            ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _deadlineLabel(DateTime deadline) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(deadline.year, deadline.month, deadline.day);
    final days = d.difference(today).inDays;
    if (days < 0) return 'Past due · ${Formatters.dateShort(deadline)}';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    if (days < 30) return 'Due in $days days';
    return 'By ${Formatters.dateShort(deadline)}';
  }
}

class _GoalActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _GoalActionButton({
    required this.label,
    required this.filled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          color: filled && enabled ? AppColors.dark : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: filled && enabled ? AppColors.dark : AppColors.border,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: !enabled
                  ? AppColors.textMuted
                  : (filled ? AppColors.surface : AppColors.textPrimary),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared pieces ───────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double ratio;
  final Color color;
  final Color background;

  const _ProgressBar({
    required this.ratio,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          Container(height: 8, color: background),
          FractionallySizedBox(
            widthFactor: ratio.clamp(0.0, 1.0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              height: 8,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: AppTextStyles.labelSmall);
  }
}

// ── Sheets ──────────────────────────────────────────────────────────────────

/// Opens the add/edit budget sheet. Pass [existing] to edit its limit.
void showBudgetSheet(
  BuildContext context,
  BudgetController controller, {
  BudgetModel? existing,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _BudgetSheet(controller: controller, existing: existing),
  );
}

/// Opens the add/edit goal sheet. Pass [existing] to edit it.
void showGoalSheet(
  BuildContext context,
  BudgetController controller, {
  GoalModel? existing,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _GoalSheet(controller: controller, existing: existing),
  );
}

/// Opens the contribute / withdraw sheet for [goal].
void showContributeSheet(
  BuildContext context,
  BudgetController controller,
  GoalModel goal, {
  required bool withdraw,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _ContributeSheet(
      controller: controller,
      goal: goal,
      withdraw: withdraw,
    ),
  );
}

class _BudgetSheet extends StatefulWidget {
  final BudgetController controller;
  final BudgetModel? existing;

  const _BudgetSheet({required this.controller, this.existing});

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _name;
  late String _type;

  /// Categories this budget will measure. Holds the all-categories sentinel
  /// when "All" is picked, which is mutually exclusive with everything else.
  late Set<String> _selected;

  /// Month the budget applies to. Defaults to whatever month the screen is
  /// showing, so "add" from a month you're browsing lands where you expect.
  late DateTime _month;

  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  bool get _allSelected =>
      _selected.contains(AppConstants.budgetAllCategories);

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _amount = TextEditingController(
      text: existing == null
          ? ''
          : (existing.limitCents / 100).toStringAsFixed(2),
    );
    _name = TextEditingController(text: existing?.name ?? '');
    _type = existing?.type ?? AppConstants.txnExpense;
    _month = existing?.month ?? widget.controller.selectedMonth.value;
    // Nothing preselected on a new budget — picking categories is the whole
    // decision, so it should be deliberate.
    _selected = existing != null ? {...existing.categories} : <String>{};
  }

  /// Every category of this type. Budgets may deliberately overlap — the same
  /// category can sit in several — so nothing is withheld here.
  List<String> get _options => BudgetController.categoriesOf(_type);

  void _toggleCategory(String category) {
    setState(() {
      _error = null;
      // "All" and specific categories are mutually exclusive — holding both
      // would count the same transactions twice within one budget.
      if (category == AppConstants.budgetAllCategories) {
        _selected = _allSelected ? {} : {AppConstants.budgetAllCategories};
        return;
      }
      _selected.remove(AppConstants.budgetAllCategories);
      if (!_selected.remove(category)) _selected.add(category);
    });
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  void _setType(String type) {
    setState(() {
      _type = type;
      // Category lists differ per type, so nothing carries over.
      _selected = {};
      _error = null;
    });
  }

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (BudgetController.parseCents(_amount.text) == null) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'Pick at least one category');
      return;
    }
    setState(() => _saving = true);
    if (_isEdit) {
      await widget.controller.updateBudget(
        id: widget.existing!.id,
        categories: _selected.toList(),
        name: _name.text,
        limitText: _amount.text,
      );
    } else {
      await widget.controller.addBudget(
        type: _type,
        categories: _selected.toList(),
        name: _name.text,
        limitText: _amount.text,
        month: _month,
      );
      // Jump the screen to the month just budgeted, so the new row is visible
      // rather than filed away under a month the user isn't looking at.
      widget.controller.selectedMonth.value = BudgetModel.monthOf(_month);
    }
    // Navigator.pop, not Get.back: the controller shows a snackbar on success,
    // and Get.back() would pop that instead of this sheet — leaving the sheet
    // open and every further tap writing another budget.
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final options = _options;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetGrabber(),
            Text(
              _isEdit ? 'Edit budget' : 'New budget',
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 20),

            // Type and month are fixed on edit: changing either would make the
            // budget measure a different set of transactions than it was
            // created for, which reads as data loss rather than an edit.
            if (!_isEdit) ...[
              SegmentedToggle(
                labels: const ['Spending limit', 'Income target'],
                selectedIndex: _type == AppConstants.txnExpense ? 0 : 1,
                onDark: false,
                onChanged: (i) => _setType(
                  i == 0 ? AppConstants.txnExpense : AppConstants.txnIncome,
                ),
              ),
              const SizedBox(height: 20),
              const Text('Month', style: AppTextStyles.labelMedium),
              const SizedBox(height: 10),
              _MonthStepper(
                month: _month,
                onPrevious: () => _shiftMonth(-1),
                onNext: () => _shiftMonth(1),
              ),
              const SizedBox(height: 20),
            ] else ...[
              Text(
                Formatters.dateMonthYear(_month),
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textMuted),
              ),
              const SizedBox(height: 20),
            ],

            Row(
              children: [
                const Text('Categories', style: AppTextStyles.labelMedium),
                const SizedBox(width: 8),
                if (_selected.isNotEmpty && !_allSelected)
                  Text(
                    '${_selected.length} selected',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick several to budget them together.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 10),
            Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CategoryChip(
                    label: _type == AppConstants.txnIncome
                        ? 'All income'
                        : 'All expenses',
                    selected: _allSelected,
                    onTap: () =>
                        _toggleCategory(AppConstants.budgetAllCategories),
                  ),
                  for (final c in options)
                    _CategoryChip(
                      label: c,
                      selected: _selected.contains(c),
                      // Picking a specific category clears "All", so the two
                      // never both apply.
                      onTap: () => _toggleCategory(c),
                    ),
                ],
              ),
            const SizedBox(height: 20),

            // A group of categories needs a name to be recognisable in the
            // list; a single category already names itself.
            const Text('Name (optional)', style: AppTextStyles.labelMedium),
            const SizedBox(height: 10),
            _SheetField(
              controller: _name,
              hint: _selected.length > 1 ? 'Essentials' : 'Optional label',
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 20),

            Text(
              _type == AppConstants.txnIncome
                  ? 'Monthly target'
                  : 'Monthly limit',
              style: AppTextStyles.labelMedium,
            ),
            const SizedBox(height: 10),
            _SheetField(
              controller: _amount,
              hint: '0.00',
              prefixText: '\$ ',
              errorText: _error,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            const SizedBox(height: 24),
            _SheetSaveButton(
              label: _isEdit ? 'Save changes' : 'Create budget',
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalSheet extends StatefulWidget {
  final BudgetController controller;
  final GoalModel? existing;

  const _GoalSheet({required this.controller, this.existing});

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _title;
  late final TextEditingController _target;
  late final TextEditingController _starting;
  DateTime? _deadline;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _title = TextEditingController(text: existing?.title ?? '');
    _target = TextEditingController(
      text: existing == null
          ? ''
          : (existing.targetCents / 100).toStringAsFixed(2),
    );
    _starting = TextEditingController();
    _deadline = existing?.deadline;
  }

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    _starting.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(
                primary: AppColors.primary,
                onPrimary: AppColors.dark,
                surface: AppColors.surface,
                onSurface: AppColors.textPrimary,
              ),
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Give your goal a name');
      return;
    }
    if (BudgetController.parseCents(_target.text) == null) {
      setState(() => _error = 'Enter a target greater than 0');
      return;
    }
    setState(() => _saving = true);
    if (_isEdit) {
      await widget.controller.updateGoal(
        id: widget.existing!.id,
        title: _title.text,
        targetText: _target.text,
        deadline: _deadline,
        clearDeadline: _deadline == null,
      );
    } else {
      await widget.controller.addGoal(
        title: _title.text,
        targetText: _target.text,
        startingText:
            _starting.text.trim().isEmpty ? null : _starting.text,
        deadline: _deadline,
      );
    }
    // Navigator.pop, not Get.back — see _BudgetSheetState._save.
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetGrabber(),
            Text(
              _isEdit ? 'Edit goal' : 'New goal',
              style: AppTextStyles.titleLarge,
            ),
            const SizedBox(height: 20),
            const Text('Name', style: AppTextStyles.labelMedium),
            const SizedBox(height: 10),
            _SheetField(
              controller: _title,
              hint: 'Emergency fund',
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 18),
            const Text('Target amount', style: AppTextStyles.labelMedium),
            const SizedBox(height: 10),
            _SheetField(
              controller: _target,
              hint: '0.00',
              prefixText: '\$ ',
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
            ),
            if (!_isEdit) ...[
              const SizedBox(height: 18),
              const Text('Already saved (optional)',
                  style: AppTextStyles.labelMedium),
              const SizedBox(height: 10),
              _SheetField(
                controller: _starting,
                hint: '0.00',
                prefixText: '\$ ',
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
              ),
            ],
            const SizedBox(height: 18),
            const Text('Target date (optional)',
                style: AppTextStyles.labelMedium),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _pickDeadline,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 10),
                    Text(
                      _deadline == null
                          ? 'No date set'
                          : Formatters.dateShort(_deadline!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _deadline == null
                            ? AppColors.textMuted
                            : AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (_deadline != null)
                      GestureDetector(
                        onTap: () => setState(() => _deadline = null),
                        child: const Icon(Icons.close_rounded,
                            size: 16, color: AppColors.textMuted),
                      ),
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(
                _error!,
                style: const TextStyle(fontSize: 13, color: AppColors.danger),
              ),
            ],
            const SizedBox(height: 24),
            _SheetSaveButton(
              label: _isEdit ? 'Save changes' : 'Create goal',
              onTap: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContributeSheet extends StatefulWidget {
  final BudgetController controller;
  final GoalModel goal;
  final bool withdraw;

  const _ContributeSheet({
    required this.controller,
    required this.goal,
    required this.withdraw,
  });

  @override
  State<_ContributeSheet> createState() => _ContributeSheetState();
}

class _ContributeSheetState extends State<_ContributeSheet> {
  final _amount = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (BudgetController.parseCents(_amount.text) == null) {
      setState(() => _error = 'Enter an amount greater than 0');
      return;
    }
    setState(() => _saving = true);
    await widget.controller.contribute(
      id: widget.goal.id,
      amountText: _amount.text,
      withdraw: widget.withdraw,
    );
    // Navigator.pop, not Get.back — see _BudgetSheetState._save.
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetGrabber(),
          Text(
            widget.withdraw ? 'Withdraw from goal' : 'Add to goal',
            style: AppTextStyles.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            widget.goal.title,
            style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _SheetField(
            controller: _amount,
            hint: '0.00',
            prefixText: '\$ ',
            autofocus: true,
            errorText: _error,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          const SizedBox(height: 24),
          _SheetSaveButton(
            label: widget.withdraw ? 'Withdraw' : 'Add money',
            onTap: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

// ── Sheet primitives ────────────────────────────────────────────────────────

/// Month picker for the budget sheet. A stepper rather than a date dialog —
/// a budget belongs to a month, not a day, and neighbouring months are the
/// only realistic choices.
class _MonthStepper extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _MonthStepper({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _StepperArrow(icon: Icons.chevron_left_rounded, onTap: onPrevious),
          Expanded(
            child: Center(
              child: Text(
                Formatters.dateMonthYear(month),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          _StepperArrow(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _StepperArrow extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepperArrow({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 19, color: AppColors.textPrimary),
      ),
    );
  }
}

class _SheetGrabber extends StatelessWidget {
  const _SheetGrabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? prefixText;
  final String? errorText;
  final bool autofocus;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final void Function(String)? onChanged;

  const _SheetField({
    required this.controller,
    required this.hint,
    this.prefixText,
    this.errorText,
    this.autofocus = false,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      onChanged: onChanged,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixText: prefixText,
        errorText: errorText,
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}

class _SheetSaveButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SheetSaveButton({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: enabled ? AppColors.dark : AppColors.border,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: enabled ? AppColors.surface : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.dark : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
