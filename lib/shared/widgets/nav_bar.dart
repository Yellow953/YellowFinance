import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../routes/app_routes.dart';

/// Floating frosted-glass bottom navigation bar — icons only, no labels.
///
/// Pages content scrolls underneath it (hosts set `extendBody: true`), so the
/// blur picks up whatever is behind. A translucent lens marks the current tab
/// and slides over from the previously selected one after each page switch.
class AppNavBar extends StatelessWidget {
  final int currentIndex;
  final void Function(int) onTap;

  const AppNavBar({super.key, required this.currentIndex, required this.onTap});

  static const double _barHeight = 64;
  static const double _bottomGap = 12;
  static const double _sideInset = 20;
  static const double _innerPadding = 6;

  /// Colour matrix boosting saturation by 1.6× (Rec. 709 luma weights).
  static const List<double> _saturate = [
    1.4724, -0.4291, -0.0433, 0, 0, //
    -0.1276, 1.1709, -0.0433, 0, 0, //
    -0.1276, -0.4291, 1.5567, 0, 0, //
    0, 0, 0, 1, 0,
  ];

  static const _icons = [
    (Icons.home_rounded, Icons.home_outlined),
    (Icons.checklist_rounded, Icons.checklist_outlined),
    (Icons.receipt_long_rounded, Icons.receipt_long_outlined),
    (Icons.bar_chart_rounded, Icons.bar_chart_outlined),
    (Icons.menu_rounded, Icons.menu_rounded),
  ];

  /// Route of each tab, in bar order.
  static const routes = [
    AppRoutes.HOME,
    AppRoutes.TODOS,
    AppRoutes.TRANSACTIONS,
    AppRoutes.REPORTS,
    AppRoutes.MORE,
  ];

  /// Tab shown before the latest switch. Each page builds its own bar, so the
  /// lens animates from here to [currentIndex] when the new page appears.
  static int _lastIndex = 0;

  /// Vertical space the bar covers at the bottom of the screen. Scroll views
  /// running under it add this to their bottom padding so their last item can
  /// scroll clear. Call with a context above the hosting [Scaffold].
  static double overlap(BuildContext context) =>
      _barHeight + _bottomGap + MediaQuery.paddingOf(context).bottom;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final from = _lastIndex.toDouble();
    _lastIndex = currentIndex;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _sideInset,
        0,
        _sideInset,
        _bottomGap + bottomPadding,
      ),
      child: CustomPaint(
        // Shadow is painted only outside the pill: a regular BoxShadow also
        // sits under the translucent fill and greys the glass out.
        painter: const _OuterShadowPainter(radius: _barHeight / 2),
        foregroundPainter: const _RimPainter(radius: _barHeight / 2),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_barHeight / 2),
          child: BackdropFilter(
            // Light blur + saturation boost: content behind stays readable
            // and colourful, like iOS glass, instead of frosting to grey.
            filter: ImageFilter.compose(
              outer: const ColorFilter.matrix(_saturate),
              inner: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            ),
            child: Container(
              height: _barHeight,
              padding: const EdgeInsets.all(_innerPadding),
              color: AppColors.surface.withValues(alpha: 0.3),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final slotWidth = constraints.maxWidth / _icons.length;
                  return Stack(
                    children: [
                      // ── Sliding selection lens ─────────────────────────
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: from, end: currentIndex.toDouble()),
                        duration: const Duration(milliseconds: 380),
                        curve: Curves.easeOutBack,
                        builder: (context, pos, child) => Positioned(
                          left: pos * slotWidth,
                          top: 0,
                          bottom: 0,
                          width: slotWidth,
                          child: child!,
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.dark.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              (_barHeight - _innerPadding * 2) / 2,
                            ),
                            border: Border.all(
                              color: AppColors.surface.withValues(alpha: 0.6),
                              width: 1,
                            ),
                          ),
                        ),
                      ),

                      // ── Icons ──────────────────────────────────────────
                      Row(
                        children: List.generate(_icons.length, (i) {
                          final isSelected = i == currentIndex;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => onTap(i),
                              behavior: HitTestBehavior.opaque,
                              child: Center(
                                child: AnimatedScale(
                                  scale: isSelected ? 1.1 : 1.0,
                                  duration: const Duration(milliseconds: 200),
                                  child: Icon(
                                    isSelected ? _icons[i].$1 : _icons[i].$2,
                                    color: isSelected
                                        ? AppColors.textPrimary
                                        : AppColors.textPrimary.withValues(
                                            alpha: 0.5,
                                          ),
                                    size: 24,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Soft drop shadow clipped to the area outside the pill, so the glass itself
/// stays clear.
class _OuterShadowPainter extends CustomPainter {
  final double radius;

  const _OuterShadowPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    canvas.save();
    canvas.clipPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rrect.outerRect.inflate(60)),
        Path()..addRRect(rrect),
      ),
    );
    canvas.drawRRect(
      rrect.shift(const Offset(0, 8)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.2)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_OuterShadowPainter old) => old.radius != radius;
}

/// Glass edge: a bright specular rim that fades around the pill, plus a faint
/// dark hairline so the bar still reads against white content.
class _RimPainter extends CustomPainter {
  final double radius;

  const _RimPainter({required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));

    // Inner shading gives the glass thickness: a soft shadow hugging the
    // bottom inside edge and a bright glow along the top one.
    canvas.save();
    canvas.clipRRect(rrect);
    final frame = Path()..addRect(rect.inflate(20));
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        frame,
        Path()..addRRect(rrect.shift(const Offset(0, -4))),
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        frame,
        Path()..addRRect(rrect.shift(const Offset(0, 3))),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.restore();

    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.black.withValues(alpha: 0.1),
    );

    canvas.drawRRect(
      rrect.deflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.95),
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.7),
          ],
          stops: const [0, 0.35, 0.65, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.radius != radius;
}
