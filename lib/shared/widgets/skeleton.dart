import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';

/// Placeholder block shown while real content loads.
///
/// A gently pulsing shape rather than a spinner: it reserves the space the
/// content will occupy, so the layout doesn't jump when data lands. Hand-rolled
/// instead of pulling in a shimmer package for a handful of grey boxes.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  /// Renders light-on-dark, for skeletons sitting on the dark header.
  final bool onDark;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
    this.onDark = false,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.onDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.border;

    return FadeTransition(
      // Never fades fully out — a shape that vanishes reads as a glitch.
      opacity: Tween<double>(begin: 0.45, end: 1.0).animate(
        CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: base,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}
