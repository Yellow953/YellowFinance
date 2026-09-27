import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/goal_model.dart';
import '../../../data/models/sport_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../budgets/controllers/budget_controller.dart';
import '../controllers/home_controller.dart';

/// Home screen.
class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  final _controller = Get.find<HomeController>();
  final _authCtrl = Get.find<AuthController>();

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
      // Dark, not the page background: the pinned bar's rounded bottom corners
      // are cut out of it, and at rest there is no content behind them. Against
      // a light scaffold those cut-outs would read as two pale notches under
      // the header; against dark they disappear into the hero below.
      backgroundColor: AppColors.dark,
      bottomNavigationBar: AppNavBar(
        currentIndex: 0,
        onTap: (i) {
          if (i != 0) Get.offNamed(_routes[i]);
        },
      ),
      body: CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            // ── Pinned greeting row ──────────────────────────────────────
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              backgroundColor: AppColors.dark,
              surfaceTintColor: Colors.transparent,
              toolbarHeight: 64,
              titleSpacing: 20,
              // Rounds the header itself rather than relying on the light
              // sheet's rounded top, which scrolls away — so the corners
              // survive into the pinned state instead of squaring off.
              shape: const RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.vertical(bottom: Radius.circular(28)),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Obx(() {
                      final name = (_authCtrl.user.value?.displayName ?? '')
                          .split(' ')
                          .first;
                      return Text(
                        'Hello, $name 👋',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textMuted,
                        ),
                      );
                    }),
                  ),
                  Obx(() {
                    final user = _authCtrl.user.value;
                    final photoUrl = user?.photoUrl ?? '';
                    final name = user?.displayName ?? '';
                    final initials = name.isEmpty
                        ? '?'
                        : name.trim().split(' ').length > 1
                            ? '${name.trim().split(' ').first[0]}${name.trim().split(' ').last[0]}'
                                .toUpperCase()
                            : name.trim()[0].toUpperCase();
                    return GestureDetector(
                      onTap: () => Get.toNamed(AppRoutes.PROFILE),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          image: photoUrl.isNotEmpty
                              ? DecorationImage(
                                  image: ResizeImage(
                                    NetworkImage(photoUrl),
                                    width: 80,
                                    height: 80,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: photoUrl.isEmpty
                            ? Center(
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.dark,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    );
                  }),
                  const SizedBox(width: 20),
                ],
              ),
            ),

            // ── Balance + stats (scrolls away) ──────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: AppColors.dark,
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'This Month',
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textMuted),
                        ),
                        const Spacer(),
                        Obx(() => GestureDetector(
                              onTap: _authCtrl.toggleHideBalances,
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  _authCtrl.hideBalances.value
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            )),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Obx(() {
                      // Skeletons rather than zeroes: "$0.00" is a real figure
                      // and reads as fact until it suddenly isn't.
                      if (_controller.isLoading.value) {
                        return const _HeroSkeleton();
                      }
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _HeroAmount(
                                  label: 'Income',
                                  amount: _controller.totalIncomeCents.value,
                                  color: AppColors.success,
                                  hidden: _authCtrl.hideBalances.value,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _HeroAmount(
                                  label: 'Expenses',
                                  amount: _controller.totalExpenseCents.value,
                                  color: AppColors.danger,
                                  hidden: _authCtrl.hideBalances.value,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _StatPill(
                                  label: 'Balance',
                                  amount: _controller.totalBalanceCents.value,
                                  color: AppColors.primary,
                                  icon: Icons.account_balance_wallet_outlined,
                                  hidden: _authCtrl.hideBalances.value,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _StreakPill(
                                  days: _controller.sportStreakDays.value,
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),

            // ── White card top ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _GroupLabel('Money', first: true),
                    _AddTransactionCard(),
                    const SizedBox(height: 8),
                    SizedBox(width: double.infinity, child: _ReportsCard()),
                    const _GroupLabel('Activity'),
                    _ActionGroup(
                      actions: [
                        (
                          icon: Icons.fitness_center_rounded,
                          label: 'Add Sport',
                          onTap: () => Get.toNamed(AppRoutes.SPORTS,
                              arguments: 'add'),
                          dark: false,
                        ),
                        (
                          icon: Icons.checklist_rounded,
                          label: 'Add Task',
                          onTap: () => Get.toNamed(AppRoutes.TODOS,
                              arguments: 'add'),
                          dark: false,
                        ),
                      ],
                    ),
                    const _GroupLabel('Diary'),
                    _ActionGroup(
                      actions: [
                        (
                          icon: Icons.edit_rounded,
                          label: 'Write',
                          // Straight to the editor — the paired action covers
                          // browsing.
                          onTap: () => Get.toNamed(AppRoutes.DIARY_ENTRY),
                          dark: false,
                        ),
                        (
                          icon: Icons.menu_book_rounded,
                          label: 'Browse',
                          onTap: () => Get.toNamed(AppRoutes.DIARY),
                          dark: true,
                        ),
                      ],
                    ),
                    const _GroupLabel('Budgets & Goals'),
                    _ActionGroup(
                      actions: [
                        (
                          icon: Icons.add_chart_rounded,
                          label: 'New Budget',
                          onTap: () => Get.toNamed(AppRoutes.BUDGETS,
                              arguments: 'add'),
                          dark: false,
                        ),
                        (
                          icon: Icons.pie_chart_outline_rounded,
                          label: 'Overview',
                          onTap: () => Get.toNamed(AppRoutes.BUDGETS),
                          dark: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const _BudgetSummaryCard(),
                    const SizedBox(height: 28),
                    _SectionHeader(
                      title: 'Recent Transactions',
                      onSeeAll: () => Get.toNamed(AppRoutes.TRANSACTIONS),
                    ),
                  ],
                ),
              ),
            ),

            // ── Transactions list ────────────────────────────────────────
            SliverToBoxAdapter(
              child: Obx(() {
                if (_controller.isLoading.value) {
                  // Skeleton rows rather than a spinner, so the list settles
                  // into place instead of the page jumping when data lands.
                  return const _TransactionListSkeleton();
                }
                if (_controller.recentTransactions.isEmpty) {
                  return const ColoredBox(
                    color: AppColors.background,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: _EmptyTransactions(),
                    ),
                  );
                }
                return ColoredBox(
                  color: AppColors.background,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Obx(() => Column(
                            children: [
                              for (var i = 0;
                                  i < _controller.recentTransactions.length;
                                  i++) ...[
                                TransactionTile(
                                  transaction:
                                      _controller.recentTransactions[i],
                                  hideAmount:
                                      _authCtrl.hideBalances.value,
                                ),
                                if (i <
                                    _controller.recentTransactions.length - 1)
                                  const Divider(
                                      height: 1, indent: 72, endIndent: 16),
                              ],
                            ],
                          )),
                    ),
                  ),
                );
              }),
            ),

            // ── Recent Sports ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Obx(() {
                final sports = _controller.recentSportRecords;
                if (sports.isEmpty) {
                  return const SizedBox.shrink();
                }
                return ColoredBox(
                  color: AppColors.background,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(height: 1, indent: 16, endIndent: 16),
                        Padding(
                          padding:
                              const EdgeInsets.fromLTRB(16, 20, 16, 12),
                          child: _SectionHeader(
                            title: 'Recent Sports',
                            onSeeAll: () =>
                                Get.toNamed(AppRoutes.SPORTS),
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < sports.length; i++) ...[
                                _SportRecordTile(record: sports[i]),
                                if (i < sports.length - 1)
                                  const Divider(
                                      height: 1,
                                      indent: 16,
                                      endIndent: 16),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),

            // ── Bottom padding ───────────────────────────────────────────
            const SliverToBoxAdapter(
              child: ColoredBox(
                color: AppColors.background,
                child: SizedBox(height: 100),
              ),
            ),

            // Paints the page colour over any viewport left unfilled by short
            // content — the scaffold beneath is dark for the header's corners,
            // and would otherwise show through below the list.
            const SliverFillRemaining(
              hasScrollBody: false,
              child: ColoredBox(color: AppColors.background),
            ),
          ],
        ),
    );
  }
}

// ── Loading placeholders ───────────────────────────────────────────────────

/// Stand-in for the dark header figures, matching their footprint so the
/// header doesn't resize when the real numbers arrive.
class _HeroSkeleton extends StatelessWidget {
  const _HeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 56, height: 12, onDark: true),
                  SizedBox(height: 10),
                  SkeletonBox(width: 120, height: 26, onDark: true),
                ],
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 66, height: 12, onDark: true),
                  SizedBox(height: 10),
                  SkeletonBox(width: 120, height: 26, onDark: true),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 44, radius: 12, onDark: true)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 44, radius: 12, onDark: true)),
          ],
        ),
      ],
    );
  }
}

/// Stand-in for the recent transactions list.
class _TransactionListSkeleton extends StatelessWidget {
  const _TransactionListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.background,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      SkeletonBox(width: 40, height: 40, radius: 12),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonBox(width: 110, height: 13),
                            SizedBox(height: 8),
                            SkeletonBox(width: 70, height: 11),
                          ],
                        ),
                      ),
                      SizedBox(width: 16),
                      SkeletonBox(width: 68, height: 14),
                    ],
                  ),
                ),
                if (i < 2)
                  const Divider(height: 1, indent: 72, endIndent: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Budget summary ─────────────────────────────────────────────────────────

/// Compact budget status for Home: what's left to spend this month across every
/// expense budget, or a prompt to set one when there are none.
class _BudgetSummaryCard extends StatelessWidget {
  const _BudgetSummaryCard();

  @override
  Widget build(BuildContext context) {
    final budgetCtrl = Get.find<BudgetController>();
    final authCtrl = Get.find<AuthController>();

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.BUDGETS),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Obx(() {
          // Placeholder while loading, so the card never shows "set a budget"
          // to someone who has one — that empty state was misleading, not just
          // ugly, because it read as real data.
          if (budgetCtrl.isLoading.value) return const _BudgetCardSkeleton();

          // Always the real current month — the Budgets screen may be parked on
          // an older one, but Home says "this month" and must mean it.
          final now = DateTime.now();
          final expenses = budgetCtrl.progressFor(
            type: AppConstants.txnExpense,
            month: now,
          );
          final incomes = budgetCtrl.progressFor(
            type: AppConstants.txnIncome,
            month: now,
          );
          final goals = budgetCtrl.goals;

          if (expenses.isEmpty && incomes.isEmpty && goals.isEmpty) {
            return const _BudgetEmptyRow();
          }

          final hide = authCtrl.hideBalances.value;

          // Only the first block carries the chevron, so the card reads as one
          // tap target however many blocks happen to be present.
          var chevronUsed = false;
          bool takeChevron() {
            if (chevronUsed) return false;
            chevronUsed = true;
            return true;
          }

          final blocks = <Widget>[
            if (expenses.isNotEmpty)
              _SummaryBlock(
                label: 'Budgets',
                progress: expenses,
                hide: hide,
                isExpense: true,
                showChevron: takeChevron(),
              ),
            if (incomes.isNotEmpty)
              _SummaryBlock(
                label: 'Income targets',
                progress: incomes,
                hide: hide,
                isExpense: false,
                showChevron: takeChevron(),
              ),
            if (goals.isNotEmpty)
              _GoalsBlock(
                goals: goals,
                hide: hide,
                showChevron: takeChevron(),
              ),
          ];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < blocks.length; i++) ...[
                if (i > 0) ...[
                  const SizedBox(height: 14),
                  const Divider(height: 1),
                  const SizedBox(height: 14),
                ],
                blocks[i],
              ],
            ],
          );
        }),
      ),
    );
  }
}

/// Loading placeholder shaped like a populated budget block.
class _BudgetCardSkeleton extends StatelessWidget {
  const _BudgetCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SkeletonBox(width: 70, height: 14),
            Spacer(),
            SkeletonBox(width: 90, height: 14),
          ],
        ),
        SizedBox(height: 12),
        SkeletonBox(height: 6, radius: 20),
        SizedBox(height: 8),
        SkeletonBox(width: 180, height: 12),
      ],
    );
  }
}

/// Prompt shown when there is nothing budgeted and no goals at all.
class _BudgetEmptyRow extends StatelessWidget {
  const _BudgetEmptyRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.pie_chart_outline_rounded,
              size: 18, color: AppColors.dark),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Budgets & Goals',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Set a monthly limit or savings goal',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded,
            size: 18, color: AppColors.textMuted),
      ],
    );
  }
}

/// Savings goals on the Home card.
///
/// Goals are cumulative rather than monthly, so they are totalled across all of
/// them rather than being scoped to the current month like the budget blocks.
class _GoalsBlock extends StatelessWidget {
  final List<GoalModel> goals;
  final bool hide;
  final bool showChevron;

  const _GoalsBlock({
    required this.goals,
    required this.hide,
    required this.showChevron,
  });

  @override
  Widget build(BuildContext context) {
    final target = goals.fold<int>(0, (a, g) => a + g.targetCents);
    final saved = goals.fold<int>(0, (a, g) => a + g.savedCents);
    final ratio = target <= 0 ? 0.0 : (saved / target).clamp(0.0, 1.0);
    final done = goals.where((g) => g.isComplete).length;
    final allDone = done == goals.length;
    final color = allDone ? AppColors.success : AppColors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              goals.length == 1 ? 'Savings goal' : 'Savings goals',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              hide ? '••••' : '${Formatters.currency(saved)} saved',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: allDone ? color : AppColors.textPrimary,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(height: 6, color: AppColors.background),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(height: 6, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          done > 0
              ? '$done of ${goals.length} reached'
              : hide
                  ? '•••• of •••• saved'
                  : '${Formatters.currency(saved)} of ${Formatters.currency(target)} saved',
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

/// One totalled row of the Home budget card — a headline figure, a bar and a
/// caption — for either spending limits or income targets.
///
/// The two directions read inversely: on a spending limit being under is good
/// and going over is a failure; on an income target reaching the figure is the
/// win. [isExpense] switches the wording and the colour accordingly.
class _SummaryBlock extends StatelessWidget {
  final String label;
  final List<BudgetProgress> progress;
  final bool hide;
  final bool isExpense;
  final bool showChevron;

  const _SummaryBlock({
    required this.label,
    required this.progress,
    required this.hide,
    required this.isExpense,
    required this.showChevron,
  });

  @override
  Widget build(BuildContext context) {
    final target = progress.fold<int>(0, (a, p) => a + p.budget.limitCents);
    // Not a sum of the rows: budgets may share a category, and adding their
    // actuals would count the same spending twice in this combined figure.
    final actual = Get.find<BudgetController>()
        .combinedActualCents(progress, DateTime.now());
    final remaining = target - actual;
    final ratio = target <= 0 ? 0.0 : (actual / target).clamp(0.0, 1.0);

    final Color color;
    final String headline;
    final String caption;

    if (isExpense) {
      final over = BudgetController.overBudgetIn(progress);
      color = remaining >= 0 ? AppColors.primary : AppColors.danger;
      headline = hide
          ? '••••'
          : remaining >= 0
              ? '${Formatters.currency(remaining)} left'
              : '${Formatters.currency(-remaining)} over';
      caption = over > 0
          ? '$over of ${progress.length} over limit'
          : hide
              ? '•••• of •••• spent this month'
              : '${Formatters.currency(actual)} of ${Formatters.currency(target)} spent this month';
    } else {
      final met = remaining <= 0;
      color = met ? AppColors.success : AppColors.primary;
      headline = met
          ? 'Target met'
          : hide
              ? '••••'
              : '${Formatters.currency(remaining)} to go';
      caption = hide
          ? '•••• of •••• earned this month'
          : '${Formatters.currency(actual)} of ${Formatters.currency(target)} earned this month';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              headline,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: color == AppColors.primary
                    ? AppColors.textPrimary
                    : color,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textMuted),
            ],
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Container(height: 6, color: AppColors.background),
              FractionallySizedBox(
                widthFactor: ratio,
                child: Container(height: 6, color: color),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          caption,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

// ── Stat pill ──────────────────────────────────────────────────────────────

/// Large hero figure in the dark header (income / expenses).
class _HeroAmount extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final bool hidden;

  const _HeroAmount({
    required this.label,
    required this.amount,
    required this.color,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            hidden ? '••••••' : Formatters.currency(amount),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.surface,
              letterSpacing: -1,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final IconData icon;
  final bool hidden;

  const _StatPill({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.hidden = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, color: color, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                Text(
                  hidden ? '••••' : Formatters.currency(amount),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Streak pill ────────────────────────────────────────────────────────────

class _StreakPill extends StatelessWidget {
  final int days;

  const _StreakPill({required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.local_fire_department_rounded,
                color: AppColors.primary, size: 13),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Streak',
                    style: TextStyle(
                        fontSize: 10, color: AppColors.textMuted)),
                Text(
                  days == 0 ? '—' : '$days d',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.surface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Add transaction card ───────────────────────────────────────────────────

class _AddTransactionCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ActionHalf(
              label: 'Add Expense',
              icon: Icons.remove_rounded,
              color: AppColors.danger,
              onTap: () => Get.toNamed(AppRoutes.ADD_TRANSACTION,
                  arguments: 'expense'),
              isLeft: true,
            ),
          ),
          Container(
            width: 1,
            height: 64,
            color: AppColors.border,
          ),
          Expanded(
            child: _ActionHalf(
              label: 'Add Income',
              icon: Icons.add_rounded,
              color: AppColors.success,
              onTap: () => Get.toNamed(AppRoutes.ADD_TRANSACTION,
                  arguments: 'income'),
              isLeft: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionHalf extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLeft;

  const _ActionHalf({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.isLeft,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isLeft ? 20 : 16, 18, isLeft ? 16 : 20, 18),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reports card ──────────────────────────────────────────────────────────

class _ReportsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _QuickCard(
      label: 'Reports',
      subtitle: 'Monthly',
      icon: Icons.bar_chart_rounded,
      onTap: () => Get.toNamed(AppRoutes.REPORTS),
    );
  }
}

// ── Group label ───────────────────────────────────────────────────────────

/// Small caps heading that separates the Home action grid into sections.
///
/// Owns the vertical rhythm around itself so the sections stay evenly spaced
/// without callers hand-tuning a `SizedBox` before each one.
class _GroupLabel extends StatelessWidget {
  final String text;

  /// Drops the leading gap for the first label, which already sits below the
  /// card's own top padding.
  final bool first;

  const _GroupLabel(this.text, {this.first = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: first ? 0 : 18, bottom: 8),
      child: Text(text.toUpperCase(), style: AppTextStyles.labelSmall),
    );
  }
}

// ── Action group ──────────────────────────────────────────────────────────

/// One shortcut within an [_ActionGroup].
typedef HomeAction = ({
  IconData icon,
  String label,
  VoidCallback onTap,
  bool dark,
});

/// A section's shortcuts, as separate cards sharing one row.
///
/// Cards can be individually darkened. That is used to separate "go look at
/// something" from "create something" — it carries meaning rather than just
/// breaking up an all-white grid.
class _ActionGroup extends StatelessWidget {
  final List<HomeAction> actions;

  const _ActionGroup({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < actions.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _ActionGroupCard(action: actions[i])),
        ],
      ],
    );
  }
}

class _ActionGroupCard extends StatelessWidget {
  final HomeAction action;

  const _ActionGroupCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final dark = action.dark;

    return GestureDetector(
      onTap: action.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
        decoration: BoxDecoration(
          color: dark ? AppColors.dark : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          // The dark card borders itself in its own colour: a grey outline on
          // near-black reads as a stray seam rather than an edge.
          border: Border.all(
            color: dark ? AppColors.dark : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: dark
                    ? Colors.white.withValues(alpha: 0.10)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: AppColors.primary, size: 17),
            ),
            const SizedBox(width: 10),
            // Flexible so a long label ellipsizes on a narrow screen instead of
            // overflowing the row.
            Flexible(
              child: Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: dark ? AppColors.surface : AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared quick-action card ──────────────────────────────────────────────

class _QuickCard extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickCard({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.dark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(height: 20),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.surface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onSeeAll;
  const _SectionHeader({required this.title, this.onSeeAll});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleMedium),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: Text(
              'See all',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.primary),
            ),
          ),
      ],
    );
  }
}

// ── Sport record tile ─────────────────────────────────────────────────────

class _SportRecordTile extends StatelessWidget {
  final SportRecordModel record;
  const _SportRecordTile({required this.record});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Date
          SizedBox(
            width: 44,
            child: Text(
              '${_months[record.date.month - 1]} ${record.date.day}',
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              record.category,
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
              record.description.isEmpty ? '—' : record.description,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────

class _EmptyTransactions extends StatelessWidget {
  const _EmptyTransactions();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined,
              size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('No transactions yet',
              style: AppTextStyles.bodyMedium
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 4),
          const Text('Use the cards above to add one',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
