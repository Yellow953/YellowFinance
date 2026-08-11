import 'package:flutter/material.dart';

/// Screen-edge insets for laying content out clear of system UI.
///
/// Pages here deliberately use `SafeArea(bottom: false)` so the light sheet
/// bleeds to the bottom edge of the display. That keeps the background right
/// but leaves the *content* free to slide under the home indicator, so the
/// scrollable inside each page pads itself with [bottomInset] instead.
extension SafeInsets on BuildContext {
  /// Height of the system UI at the bottom of the screen — the iOS home
  /// indicator or the Android gesture bar.
  ///
  /// Zero while the keyboard is open (the keyboard covers that area) and zero
  /// inside a [Scaffold] body that has a `bottomNavigationBar`, since the
  /// scaffold hands the inset to the bar instead.
  double get bottomInset => MediaQuery.of(this).padding.bottom;

  /// Space a bottom sheet must leave below its content: the keyboard when it
  /// is open, the system bottom inset when it is not.
  ///
  /// The two are mutually exclusive — an open keyboard zeroes `padding.bottom`
  /// — so adding them never double-counts. Only valid inside a route that is
  /// not resized for the keyboard (sheets and dialogs); a [Scaffold] body sees
  /// `viewInsets.bottom` as zero because it has already been resized.
  double get sheetBottomInset =>
      MediaQuery.of(this).viewInsets.bottom +
      MediaQuery.of(this).padding.bottom;
}
