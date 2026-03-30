import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../routes/app_routes.dart';
import '../../../shared/widgets/asset_tile.dart';
import '../../../shared/widgets/nav_bar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/portfolio_controller.dart';

/// Watchlist screen — research symbols, get AI analysis.
class PortfolioView extends StatefulWidget {
  const PortfolioView({super.key});

  @override
  State<PortfolioView> createState() => _PortfolioViewState();
}

class _PortfolioViewState extends State<PortfolioView> {
  final controller = Get.find<PortfolioController>();
  final _authCtrl = Get.find<AuthController>();

  static const _routes = [
    AppRoutes.HOME,
    AppRoutes.TODOS,
    AppRoutes.PORTFOLIO,
    AppRoutes.REPORTS,
    AppRoutes.AI_CHAT,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dark,
      bottomNavigationBar: AppNavBar(
        currentIndex: 2,
        onTap: (i) {
          if (i != 2) Get.offNamed(_routes[i]);
        },
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Dark header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(Icons.bookmark_border_rounded,
                            color: AppColors.dark, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Watchlist',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.surface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          Obx(() {
                            final count = controller.assets.length;
                            return Text(
                              count == 0
                                  ? 'No assets tracked'
                                  : '$count asset${count == 1 ? '' : 's'} tracked',
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textMuted),
                            );
                          }),
                        ],
                      ),
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
                      child: CircularProgressIndicator(color: AppColors.primary),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.primary,
                    onRefresh: controller.refreshPrices,
                    child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Obx(() => _FilterChips(
                                    options: PortfolioController.filterOptions,
                                    selected: controller.selectedFilter.value,
                                    onSelected: (f) =>
                                        controller.selectedFilter.value = f,
                                  )),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                      Obx(() {
                        final list = controller.filteredAssets;
                        if (list.isEmpty) {
                          return const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.bookmark_border_rounded,
                                      size: 48, color: AppColors.border),
                                  SizedBox(height: 12),
                                  Text('Nothing here yet.',
                                      style: AppTextStyles.bodyMedium),
                                  SizedBox(height: 4),
                                  Text(
                                    'Tap + to add a symbol to your watchlist.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, i) {
                              final asset = list[i];
                              return Dismissible(
                                key: Key(asset.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  color: AppColors.danger,
                                  padding: const EdgeInsets.only(right: 20),
                                  child: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: AppColors.surface),
                                ),
                                onDismissed: (_) =>
                                    controller.removeAsset(asset.id),
                                child: Column(
                                  children: [
                                    Obx(() => AssetTile(
                                      asset: asset,
                                      hideAmount: _authCtrl.hideBalances.value,
                                      onTap: () => Get.toNamed(
                                        AppRoutes.ASSET_DETAIL,
                                        arguments: asset,
                                      ),
                                    )),
                                    if (i < list.length - 1)
                                      const Divider(
                                          height: 1,
                                          indent: 72,
                                          endIndent: 16),
                                  ],
                                ),
                              );
                            },
                            childCount: list.length,
                          ),
                        );
                      }),
                      const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    ],
                  ),
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

class _FilterChips extends StatelessWidget {
  final List<String> options;
  final String selected;
  final void Function(String) onSelected;

  const _FilterChips({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((opt) {
          final isSelected = opt == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.border,
                  ),
                ),
                child: Text(
                  opt,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: isSelected ? AppColors.dark : AppColors.textMuted,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
