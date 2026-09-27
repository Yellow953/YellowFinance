import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../data/models/user_model.dart';

/// Circular avatar showing the user's photo, or their initials on the yellow
/// accent when they have none.
class UserAvatar extends StatelessWidget {
  final UserModel? user;
  final double size;

  const UserAvatar({super.key, required this.user, this.size = 36});

  /// "Jane Doe" → "JD", "Jane" → "J", empty → "?".
  static String initialsOf(String name) {
    final parts = name.trim().split(' ');
    if (name.trim().isEmpty) return '?';
    if (parts.length > 1) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = user?.photoUrl ?? '';
    // Decode at the displayed size (×2 for retina-ish density), not full res.
    final cacheSize = (size * 2.2).round();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary,
        shape: BoxShape.circle,
        image: photoUrl.isNotEmpty
            ? DecorationImage(
                image: ResizeImage(
                  NetworkImage(photoUrl),
                  width: cacheSize,
                  height: cacheSize,
                ),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: photoUrl.isEmpty
          ? Center(
              child: Text(
                initialsOf(user?.displayName ?? ''),
                style: TextStyle(
                  fontSize: size * 0.36,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dark,
                ),
              ),
            )
          : null,
    );
  }
}
