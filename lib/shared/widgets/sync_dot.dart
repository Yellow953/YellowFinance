import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';

/// Small muted dot marking a row whose change hasn't reached the server yet.
///
/// Driven by each model's `pendingSync` flag, which comes from Firestore's
/// `DocumentSnapshot.metadata.hasPendingWrites` — restored from disk, so the
/// dot is still correct on a row created offline several restarts ago.
/// Renders nothing when [pending] is false so callers can drop it into a Row
/// unconditionally.
class SyncDot extends StatelessWidget {
  final bool pending;

  const SyncDot({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    if (!pending) return const SizedBox.shrink();
    return const Padding(
      padding: EdgeInsets.only(left: 6),
      child: Tooltip(
        message: 'Not synced yet',
        child: SizedBox(
          width: 6,
          height: 6,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.textMuted,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
