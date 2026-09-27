import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/todo_model.dart';
import '../../../core/utils/formatters.dart';
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
      extendBody: true,
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
                                child: _StatPill(
                                  label: 'Spent today',
                                  amount: _controller.todaySpentCents.value,
                                  color: AppColors.danger,
                                  icon: Icons.today_rounded,
                                  hidden: _authCtrl.hideBalances.value,
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

            // ── Quick entry ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _AddButtons(),
                    const _BudgetAlert(),
                    const SizedBox(height: 20),
                    Obx(
                      () =>
                          _TasksSection(todos: _controller.openTodos.toList()),
                    ),
                    const SizedBox(height: 20),
                    _SectionHeader(
                      title: 'Recent',
                      onSeeAll: () => Get.toNamed(AppRoutes.TRANSACTIONS),
                    ),
                  ],
                ),
              ),
            ),

            // ── Transactions, grouped by day ─────────────────────────────
            SliverToBoxAdapter(
              child: Obx(() {
                if (_controller.isLoading.value) {
                  // Skeleton rows rather than a spinner, so the list settles
                  // into place instead of the page jumping when data lands.
                  return const _TransactionListSkeleton();
                }
                final groups = _controller.recentByDay;
                if (groups.isEmpty) {
                  return const ColoredBox(
                    color: AppColors.background,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: _EmptyTransactions(),
                    ),
                  );
                }
                final hide = _authCtrl.hideBalances.value;
                return ColoredBox(
                  color: AppColors.background,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final g in groups) ...[
                          _DayHeader(
                            day: g.day,
                            spentCents: g.spentCents,
                            hidden: hide,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              children: [
                                for (var i = 0; i < g.txns.length; i++) ...[
                                  TransactionTile(
                                    transaction: g.txns[i],
                                    hideAmount: hide,
                                  ),
                                  if (i < g.txns.length - 1)
                                    const Divider(
                                      height: 1,
                                      indent: 72,
                                      endIndent: 16,
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),

            // ── Less-frequent destinations ───────────────────────────────
            // Budgets and the diary have no tab of their own, so this is
            // their way in; Sports sits with them as it's rarely used now.
            // Kept at the bottom because these are visited a few times a
            // month, not a few times a day.
            const SliverToBoxAdapter(
              child: ColoredBox(
                color: AppColors.background,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                  child: _MoreLinks(),
                ),
              ),
            ),

            // ── Bottom padding ───────────────────────────────────────────
            SliverToBoxAdapter(
              child: ColoredBox(
                color: AppColors.background,
                child: SizedBox(height: 100 + AppNavBar.overlap(context)),
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

// ── Add buttons ───────────────────────────────────────────────────────────

/// The two entry points, equal in size. Expense — logged several times a day —
/// is the dark one, so the eye lands on it first.
class _AddButtons extends StatelessWidget {
  const _AddButtons();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AddButton(
            label: 'Add Expense',
            icon: Icons.remove_rounded,
            iconColor: AppColors.danger,
            dark: true,
            onTap: () => Get.toNamed(
              AppRoutes.ADD_TRANSACTION,
              arguments: AppConstants.txnExpense,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _AddButton(
            label: 'Add Income',
            icon: Icons.add_rounded,
            iconColor: AppColors.success,
            dark: false,
            onTap: () => Get.toNamed(
              AppRoutes.ADD_TRANSACTION,
              arguments: AppConstants.txnIncome,
            ),
          ),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color iconColor;
  final bool dark;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.icon,
    required this.iconColor,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: dark ? AppColors.dark : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dark ? AppColors.dark : AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: dark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
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

// ── Budget alert ──────────────────────────────────────────────────────────

/// Warns about the expense budget closest to (or past) its limit this month.
///
/// Silent below 80%: budgets are reviewed a few times a month, so Home only
/// speaks up when one actually needs attention.
class _BudgetAlert extends StatelessWidget {
  const _BudgetAlert();

  static const _threshold = 0.8;

  @override
  Widget build(BuildContext context) {
    final budgetCtrl = Get.find<BudgetController>();
    final authCtrl = Get.find<AuthController>();

    return Obx(() {
      if (budgetCtrl.isLoading.value) return const SizedBox.shrink();

      final progress = budgetCtrl.progressFor(
        type: AppConstants.txnExpense,
        month: DateTime.now(),
      );
      BudgetProgress? worst;
      var worstRatio = 0.0;
      var flagged = 0;
      for (final p in progress) {
        final limit = p.budget.limitCents;
        if (limit <= 0) continue;
        final ratio = p.actualCents / limit;
        if (ratio < _threshold) continue;
        flagged++;
        if (ratio > worstRatio) {
          worstRatio = ratio;
          worst = p;
        }
      }
      if (worst == null) return const SizedBox.shrink();

      final over = worst.actualCents > worst.budget.limitCents;
      final hide = authCtrl.hideBalances.value;
      final remaining = worst.budget.limitCents - worst.actualCents;
      final detail = hide
          ? '${(worstRatio * 100).round()}%'
          : over
          ? '${Formatters.currency(-remaining)} over'
          : '${(worstRatio * 100).round()}% · '
                '${Formatters.currency(remaining)} left';
      final more = flagged > 1 ? '  +${flagged - 1} more' : '';

      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: GestureDetector(
          onTap: () => Get.toNamed(AppRoutes.BUDGETS),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: over
                  ? AppColors.danger.withValues(alpha: 0.08)
                  : AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: over
                    ? AppColors.danger.withValues(alpha: 0.3)
                    : AppColors.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  over
                      ? Icons.error_outline_rounded
                      : Icons.warning_amber_rounded,
                  size: 18,
                  color: over ? AppColors.danger : AppColors.textPrimary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${worst.budget.label} ',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        TextSpan(text: detail),
                        TextSpan(
                          text: more,
                          style: const TextStyle(color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

// ── Tasks section ─────────────────────────────────────────────────────────

/// The next few open tasks, soonest due first, with shortcuts to add one or
/// open the full list.
///
/// Read-only on purpose: completing a task also reschedules its reminders and
/// rolls recurring tasks forward, which lives in the Todos screen. A tap opens
/// that screen instead of duplicating the logic here.
class _TasksSection extends StatelessWidget {
  final List<TodoModel> todos;

  const _TasksSection({required this.todos});

  static const _shown = 3;

  @override
  Widget build(BuildContext context) {
    final visible = todos.take(_shown).toList();
    final more = todos.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Tasks', style: AppTextStyles.titleMedium),
            if (todos.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '${todos.length} open',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textMuted,
                ),
              ),
            ],
            const Spacer(),
            _HeaderPill(
              label: 'New task',
              icon: Icons.add_rounded,
              filled: true,
              onTap: () => Get.toNamed(AppRoutes.TODOS, arguments: 'add'),
            ),
            const SizedBox(width: 8),
            _HeaderPill(
              label: 'See all',
              onTap: () => Get.offNamed(AppRoutes.TODOS),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: visible.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.task_alt_rounded,
                          size: 20,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'All clear — no open tasks',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < visible.length; i++) ...[
                      _TaskRow(todo: visible[i]),
                      if (i < visible.length - 1)
                        const Divider(height: 1, indent: 72, endIndent: 16),
                    ],
                    if (more > 0) ...[
                      const Divider(height: 1),
                      GestureDetector(
                        onTap: () => Get.offNamed(AppRoutes.TODOS),
                        behavior: HitTestBehavior.opaque,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: Text(
                              '+$more more',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

/// One open task: title, optional note, and when it's due.
class _TaskRow extends StatelessWidget {
  final TodoModel todo;

  const _TaskRow({required this.todo});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String? due;
    var overdue = false;
    var dueToday = false;
    if (todo.dueDate != null) {
      final d = todo.dueDate!;
      final day = DateTime(d.year, d.month, d.day);
      overdue = day.isBefore(today);
      dueToday = day == today;
      due = overdue
          ? 'Overdue'
          : dueToday
          ? 'Today'
          : day == today.add(const Duration(days: 1))
          ? 'Tomorrow'
          : Formatters.dateDayMonth(d);
    }

    return GestureDetector(
      onTap: () => Get.offNamed(AppRoutes.TODOS),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: overdue
                    ? AppColors.danger.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.radio_button_unchecked_rounded,
                size: 20,
                color: overdue ? AppColors.danger : AppColors.dark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    todo.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (todo.note.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      todo.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (due != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: overdue
                      ? AppColors.danger.withValues(alpha: 0.1)
                      : dueToday
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.background,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  due,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: overdue ? AppColors.danger : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Day header ────────────────────────────────────────────────────────────

/// Label above one day's transactions, with that day's spending on the right.
class _DayHeader extends StatelessWidget {
  final DateTime day;
  final int spentCents;
  final bool hidden;

  const _DayHeader({
    required this.day,
    required this.spentCents,
    required this.hidden,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final label = day == today
        ? 'Today'
        : day == today.subtract(const Duration(days: 1))
        ? 'Yesterday'
        : Formatters.dateDayMonth(day);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Row(
        children: [
          Text(label.toUpperCase(), style: AppTextStyles.labelSmall),
          const Spacer(),
          if (spentCents > 0)
            Text(
              hidden ? '••••' : '-${Formatters.currency(spentCents)}',
              style: AppTextStyles.labelSmall,
            ),
        ],
      ),
    );
  }
}

// ── More links ────────────────────────────────────────────────────────────

/// Quiet entry points for Budgets & Goals, the Diary and Sports.
class _MoreLinks extends StatelessWidget {
  const _MoreLinks();

  @override
  Widget build(BuildContext context) {
    final budgetCtrl = Get.find<BudgetController>();
    final authCtrl = Get.find<AuthController>();

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Obx(() {
            var subtitle = 'Monthly limits and savings goals';
            if (!budgetCtrl.isLoading.value) {
              final now = DateTime.now();
              final expenses = budgetCtrl.progressFor(
                type: AppConstants.txnExpense,
                month: now,
              );
              if (expenses.isNotEmpty) {
                // Not a sum of the rows: budgets may share a category.
                final target = expenses.fold<int>(
                  0,
                  (a, p) => a + p.budget.limitCents,
                );
                final left =
                    target - budgetCtrl.combinedActualCents(expenses, now);
                subtitle = authCtrl.hideBalances.value
                    ? '•••• left this month'
                    : left >= 0
                    ? '${Formatters.currency(left)} left this month'
                    : '${Formatters.currency(-left)} over this month';
              } else if (budgetCtrl.goals.isNotEmpty) {
                final n = budgetCtrl.goals.length;
                subtitle = n == 1 ? '1 savings goal' : '$n savings goals';
              } else {
                subtitle = 'Set a monthly limit or savings goal';
              }
            }
            return _LinkRow(
              icon: Icons.pie_chart_outline_rounded,
              title: 'Budgets & Goals',
              subtitle: subtitle,
              onTap: () => Get.toNamed(AppRoutes.BUDGETS),
            );
          }),
          const Divider(height: 1, indent: 72, endIndent: 16),
          _LinkRow(
            icon: Icons.menu_book_rounded,
            title: 'Diary',
            subtitle: 'Write or look back',
            onTap: () => Get.toNamed(AppRoutes.DIARY),
          ),
          const Divider(height: 1, indent: 72, endIndent: 16),
          _LinkRow(
            icon: Icons.fitness_center_rounded,
            title: 'Sports',
            subtitle: 'Workouts and streaks',
            // A tab, so it replaces Home the way the nav bar does.
            onTap: () => Get.offNamed(AppRoutes.SPORTS),
          ),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: AppColors.dark),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textMuted,
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
        if (onSeeAll != null) _HeaderPill(label: 'See all', onTap: onSeeAll!),
      ],
    );
  }
}

/// Small pill button for section headers.
///
/// Outlined white by default; [filled] makes it solid yellow for the one
/// action in a header that creates something. Dark text either way — yellow
/// text on the grey sheet is too faint to read.
class _HeaderPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool filled;

  const _HeaderPill({
    required this.label,
    required this.onTap,
    this.icon,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 32,
        padding: EdgeInsets.only(
          left: icon != null ? 10 : 14,
          right: icon != null ? 14 : 10,
        ),
        decoration: BoxDecoration(
          color: filled ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: filled ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: AppColors.dark),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.dark,
              ),
            ),
            if (icon == null) ...[
              const SizedBox(width: 2),
              const Icon(
                Icons.chevron_right_rounded,
                size: 16,
                color: AppColors.dark,
              ),
            ],
          ],
        ),
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
          const Text('Tap Add Expense to record your first one',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
