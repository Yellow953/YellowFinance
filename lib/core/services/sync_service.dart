import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../utils/app_snackbar.dart';
import 'connectivity_service.dart';

/// Owns the fire-and-forget write pattern that makes offline mode work.
///
/// Firestore only completes a write future once the server acknowledges it, so
/// awaiting one while offline hangs forever. Instead every mutation is split in
/// two: the caller commits to local state immediately (driving the UI), then
/// hands the Firestore call here. The SDK persists the mutation to a disk-backed
/// queue, so it survives an app restart and replays automatically on reconnect.
class SyncService extends GetxService {
  /// Unsynced create/update count per feature, derived from
  /// `DocumentSnapshot.metadata.hasPendingWrites`.
  ///
  /// Firestore restores that flag from disk, so this stays accurate across app
  /// restarts — a task added offline yesterday still reports as pending today.
  final RxMap<String, int> _pendingBySource = <String, int>{}.obs;

  /// Deletes issued this session that have not been acknowledged.
  ///
  /// Deletes are the one mutation with no surviving document to carry a
  /// `hasPendingWrites` flag, so they have to be counted separately. This
  /// resets on restart (the write itself still replays — only the count is
  /// lost), which is why it is kept apart from [_pendingBySource] rather than
  /// being the single source of truth.
  final RxInt _pendingDeletes = 0.obs;

  /// When the most recent write was acknowledged by the server.
  final Rx<DateTime?> lastSyncedAt = Rx<DateTime?>(null);

  /// Total unsynced changes across every feature. Reactive — read inside `Obx`.
  int get pendingTotal =>
      _pendingBySource.values.fold(0, (a, b) => a + b) + _pendingDeletes.value;

  @override
  void onInit() {
    super.onInit();
    // Firestore reconnects on its own, but an explicit nudge shortens the gap
    // between the OS reporting a network and the queue draining.
    ever<bool>(Get.find<ConnectivityService>().isOnline, (online) {
      if (online) FirebaseFirestore.instance.enableNetwork();
    });
  }

  /// Reports how many of [source]'s currently-loaded items are unsynced.
  ///
  /// Feature controllers call this whenever their list changes, counting items
  /// whose `pendingSync` flag is set.
  void reportPending(String source, int count) {
    // Mutating an RxMap always notifies, and controllers report on every
    // snapshot — bail out when nothing changed so the banner doesn't rebuild
    // on each stream tick.
    if ((_pendingBySource[source] ?? 0) == count) return;
    if (count == 0) {
      _pendingBySource.remove(source);
    } else {
      _pendingBySource[source] = count;
    }
  }

  /// Commits [write] in the background and returns immediately.
  ///
  /// [label] names the entity for the failure message ("Could not sync task.").
  /// Set [isDelete] so the change is still counted while in flight — a deleted
  /// document leaves no row behind to report itself as pending.
  /// [onSynced] fires once the server acknowledges — use it to clear a local
  /// pending flag on lists that are not backed by a snapshot stream.
  /// [onError] fires only on a genuine rejection (permission denied, invalid
  /// data); an offline write never errors, it simply stays pending. Use it to
  /// roll back the optimistic local change.
  void enqueue(
    Future<void> Function() write, {
    required String label,
    bool isDelete = false,
    VoidCallback? onSynced,
    VoidCallback? onError,
  }) {
    if (isDelete) _pendingDeletes.value++;
    write().then(
      (_) {
        if (isDelete) _pendingDeletes.value--;
        lastSyncedAt.value = DateTime.now();
        onSynced?.call();
      },
      onError: (Object e) {
        if (isDelete) _pendingDeletes.value--;
        if (kDebugMode) debugPrint('Sync failed [$label]: $e');
        AppSnackbar.error('Could not sync $label.');
        onError?.call();
      },
    );
  }
}
