import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../../shared/widgets/transaction_tile.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/transaction_controller.dart';

/// Full transactions list screen.
class TransactionsView extends StatefulWidget {
  const TransactionsView({super.key});

  @override
  State<TransactionsView> createState() => _TransactionsViewState();
}

class _TransactionsViewState extends State<TransactionsView> {
  final _controller = Get.find<TransactionController>();
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
        currentIndex: 1,
        onTap: (i) {
          if (i != 1) Get.offNamed(_routes[i]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.dark,
        onPressed: () => Get.toNamed(AppRoutes.ADD_TRANSACTION),
        child: const Icon(Icons.add_rounded),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dark header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Transactions',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.surface,
                          letterSpacing: -0.5,
                        ),
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
                        '${_controller.transactions.length} records',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textMuted),
                      )),
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
                  if (_controller.isLoading.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary),
                    );
                  }
                  final filtered = _controller.filteredTransactions;
                  return Column(
                    children: [
                      // ── Filter chips ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Type row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: TransactionController.filterTypes
                                    .map((t) => _FilterChip(
                                          label: t,
                                          selected:
                                              _controller.filterType.value ==
                                                  t,
                                          onTap: () =>
                                              _controller.setFilterType(t),
                                        ))
                                    .toList(),
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Category row
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _FilterChip(
                                    label: 'All',
                                    selected:
                                        _controller.filterCategory.value ==
                                            'All',
                                    onTap: () => _controller
                                        .setFilterCategory('All'),
                                    isSecondary: true,
                                  ),
                                  ..._controller.filterCategories
                                      .map((c) => _FilterChip(
                                            label: c,
                                            selected: _controller
                                                    .filterCategory.value ==
                                                c,
                                            onTap: () => _controller
                                                .setFilterCategory(c),
                                            isSecondary: true,
                                          )),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      // ── List ──────────────────────────────────────────
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  _controller.transactions.isEmpty
                                      ? 'No transactions yet'
                                      : 'No matches',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(
                                    top: 8, bottom: 100),
                                itemCount: filtered.length,
                                separatorBuilder: (_, _) => const Divider(
                                    height: 1, indent: 72, endIndent: 16),
                                itemBuilder: (_, i) {
                                  final txn = filtered[i];
                                  return Dismissible(
                        key: Key(txn.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: AppColors.danger,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: AppColors.surface),
                        ),
                        confirmDismiss: (_) async {
                          return await Get.dialog<bool>(
                            AlertDialog(
                              title: const Text('Delete transaction?'),
                              content: const Text(
                                  'This action cannot be undone.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Get.back(result: false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Get.back(result: true),
                                  child: const Text('Delete',
                                      style: TextStyle(
                                          color: AppColors.danger)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (_) =>
                            _controller.deleteTransaction(txn.id),
                        child: Obx(() => TransactionTile(
                              transaction: txn,
                              hideAmount: _authCtrl.hideBalances.value,
                            )),
                      );
                    },
                  ),
                      ),
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

// ── Filter chip ────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isSecondary;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(
          horizontal: isSecondary ? 12 : 14,
          vertical: isSecondary ? 6 : 7,
        ),
        decoration: BoxDecoration(
          color: selected
              ? (isSecondary ? AppColors.primary.withValues(alpha: 0.12) : AppColors.dark)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? (isSecondary ? AppColors.primary : AppColors.dark)
                : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: isSecondary ? 12 : 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? (isSecondary ? AppColors.dark : AppColors.surface)
                : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}
