import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Floating curved bottom navigation bar — icons only, no labels.
class AppNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const AppNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _icons = [
    (Icons.home_rounded, Icons.home_outlined),
    (Icons.checklist_rounded, Icons.checklist_outlined),
    (Icons.fitness_center_rounded, Icons.fitness_center_rounded),
    (Icons.candlestick_chart_rounded, Icons.candlestick_chart_outlined),
    (Icons.bar_chart_rounded, Icons.bar_chart_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      color: AppColors.background,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottomPadding),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: AppColors.dark,
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_icons.length, (i) {
              final isSelected = i == currentIndex;
              return GestureDetector(
                onTap: () => onTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: isSelected ? 52 : 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Icon(
                    isSelected ? _icons[i].$1 : _icons[i].$2,
                    color: isSelected ? AppColors.dark : AppColors.textMuted,
                    size: 22,
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
