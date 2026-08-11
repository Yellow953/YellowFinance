import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Shows a modal bottom sheet with the app's shape and safe-area behaviour.
///
/// `useSafeArea` keeps a tall sheet — a long form with the keyboard open, say
/// — from sliding under the status bar or a notch. The bottom edge is left to
/// the sheet's own content, which should pad itself with
/// `context.sheetBottomInset` so the background still bleeds past the home
/// indicator while the controls sit above it.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  Color backgroundColor = AppColors.surface,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: backgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: builder,
  );
}
