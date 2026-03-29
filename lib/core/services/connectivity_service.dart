import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get/get.dart';

/// Monitors network connectivity and exposes [isOnline] as reactive state.
class ConnectivityService extends GetxService {
  final RxBool isOnline = true.obs;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  @override
  void onInit() {
    super.onInit();
    // Check current state immediately.
    Connectivity().checkConnectivity().then(_updateStatus);
    // Listen for changes.
    _sub = Connectivity()
        .onConnectivityChanged
        .listen(_updateStatus);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }

  void _updateStatus(List<ConnectivityResult> results) {
    isOnline.value = results.any((r) => r != ConnectivityResult.none);
  }
}
