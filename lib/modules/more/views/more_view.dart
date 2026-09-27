import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/user_model.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/link_row.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/controllers/auth_controller.dart';

/// More tab — the profile plus every page that isn't a tab of its own.
class MoreView extends StatelessWidget {
  const MoreView({super.key});

  static const _index = 4;

  @override
  Widget build(BuildContext context) {
    final authCtrl = Get.find<AuthController>();

    return Scaffold(
      backgroundColor: AppColors.dark,
      extendBody: true,
      bottomNavigationBar: AppNavBar(
        currentIndex: _index,
        onTap: (i) {
          if (i != _index) Get.offNamed(AppNavBar.routes[i]);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dark header
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Your account and everything else',
                    style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                  ),
                ],
              ),
            ),

            // Light sheet
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                      20, 24, 20, 32 + AppNavBar.overlap(context)),
                  children: [
                    Obx(() => _ProfileCard(user: authCtrl.user.value)),
                    const SizedBox(height: 24),
                    // Tabs switch like the nav bar does; the rest open on top.
                    const Text('Money', style: AppTextStyles.labelSmall),
                    const SizedBox(height: 10),
                    _Group(children: [
                      LinkRow(
                        icon: Icons.receipt_long_rounded,
                        title: 'Transactions',
                        subtitle: 'Income and expenses',
                        onTap: () => Get.offNamed(AppRoutes.TRANSACTIONS),
                      ),
                      LinkRow(
                        icon: Icons.bar_chart_rounded,
                        title: 'Analytics',
                        subtitle: 'Monthly reports and categories',
                        onTap: () => Get.offNamed(AppRoutes.REPORTS),
                      ),
                      LinkRow(
                        icon: Icons.pie_chart_outline_rounded,
                        title: 'Budgets & Goals',
                        subtitle: 'Monthly limits and savings goals',
                        onTap: () => Get.toNamed(AppRoutes.BUDGETS),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    const Text('Life', style: AppTextStyles.labelSmall),
                    const SizedBox(height: 10),
                    _Group(children: [
                      LinkRow(
                        icon: Icons.checklist_rounded,
                        title: 'Tasks',
                        subtitle: 'To-dos and calendar',
                        onTap: () => Get.offNamed(AppRoutes.TODOS),
                      ),
                      LinkRow(
                        icon: Icons.menu_book_rounded,
                        title: 'Diary',
                        subtitle: 'Write or look back',
                        onTap: () => Get.toNamed(AppRoutes.DIARY),
                      ),
                      LinkRow(
                        icon: Icons.fitness_center_rounded,
                        title: 'Sports',
                        subtitle: 'Workouts and streaks',
                        onTap: () => Get.toNamed(AppRoutes.SPORTS),
                      ),
                    ]),
                    const SizedBox(height: 24),
                    const Text('Account', style: AppTextStyles.labelSmall),
                    const SizedBox(height: 10),
                    _Group(children: [
                      LinkRow(
                        icon: Icons.person_outline_rounded,
                        title: 'Edit profile',
                        subtitle: 'Name and account details',
                        onTap: () => Get.toNamed(AppRoutes.PROFILE),
                      ),
                      LinkRow(
                        icon: Icons.settings_outlined,
                        title: 'Settings',
                        subtitle: 'Security, home screen, reminders',
                        onTap: () => Get.toNamed(AppRoutes.SETTINGS),
                      ),
                      _SignOutRow(onTap: authCtrl.signOut),
                    ]),
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

/// Avatar, name and email — opens the profile page.
class _ProfileCard extends StatelessWidget {
  final UserModel? user;

  const _ProfileCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final name = user?.displayName ?? '';
    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.PROFILE),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            UserAvatar(user: user, size: 52),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name.isEmpty ? 'Your profile' : name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    user?.email ?? '',
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

/// White card holding [children] separated by inset dividers.
class _Group extends StatelessWidget {
  final List<Widget> children;

  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, indent: 72, endIndent: 16),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _SignOutRow extends StatelessWidget {
  final VoidCallback onTap;

  const _SignOutRow({required this.onTap});

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
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.logout_rounded,
                  size: 20, color: AppColors.danger),
            ),
            const SizedBox(width: 12),
            const Text(
              'Sign out',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.danger,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
