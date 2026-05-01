import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/sport_record_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../auth/controllers/auth_controller.dart';
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
    AppRoutes.PORTFOLIO,
    AppRoutes.REPORTS,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
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
                    Obx(() => Text(
                          _authCtrl.hideBalances.value
                              ? '••••••'
                              : Formatters.currency(
                                  _controller.totalBalanceCents.value),
                          style: const TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w700,
                            color: AppColors.surface,
                            letterSpacing: -1.5,
                          ),
                        )),
                    const SizedBox(height: 20),
                    Obx(() => Row(
                          children: [
                            Expanded(
                              child: _StatPill(
                                label: 'Income',
                                amount: _controller.totalIncomeCents.value,
                                color: AppColors.success,
                                icon: Icons.arrow_upward_rounded,
                                hidden: _authCtrl.hideBalances.value,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _StatPill(
                                label: 'Expenses',
                                amount: _controller.totalExpenseCents.value,
                                color: AppColors.danger,
                                icon: Icons.arrow_downward_rounded,
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
                        )),
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
                    _AddTransactionCard(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _ReportsCard()),
                        const SizedBox(width: 8),
                        Expanded(child: _TasksCard()),
                        const SizedBox(width: 8),
                        Expanded(child: _AiCard()),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _AddSportPill()),
                        const SizedBox(width: 8),
                        Expanded(child: _AddTaskPill()),
                      ],
                    ),
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
                  return const ColoredBox(
                    color: AppColors.background,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 48),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary),
                      ),
                    ),
                  );
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
          ],
        ),
    );
  }
}

// ── Stat pill ──────────────────────────────────────────────────────────────

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

// ── Tasks card ────────────────────────────────────────────────────────────

class _TasksCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _QuickCard(
      label: 'Tasks',
      subtitle: 'To-do list',
      icon: Icons.checklist_rounded,
      onTap: () => Get.toNamed(AppRoutes.TODOS),
    );
  }
}

// ── Add sport pill ─────────────────────────────────────────────────────────

class _AddSportPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: GestureDetector(
        onTap: () =>
            Get.toNamed(AppRoutes.SPORTS, arguments: 'add'),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.fitness_center_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Add Sport',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Add task pill ──────────────────────────────────────────────────────────

class _AddTaskPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.TODOS, arguments: 'add'),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.checklist_rounded,
                    color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Add Task',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── AI card ───────────────────────────────────────────────────────────────

class _AiCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _QuickCard(
      label: 'AI Chat',
      subtitle: 'Ask anything',
      icon: Icons.auto_awesome_rounded,
      onTap: () => Get.toNamed(AppRoutes.AI_CHAT),
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
