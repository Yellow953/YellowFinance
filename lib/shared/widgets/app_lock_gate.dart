import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/app_lock_service.dart';
import '../../modules/auth/controllers/auth_controller.dart';

/// Wraps the whole app with the biometric lock screen and a privacy shield.
///
/// The locked screen is stacked *over* the app rather than replacing it, so
/// unlocking returns the user to exactly the screen and scroll position they
/// left — no navigator rebuild, no reloaded streams.
class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate>
    with WidgetsBindingObserver {
  final _lock = Get.find<AppLockService>();

  /// True while the app is not in the foreground — drives the privacy shield
  /// that keeps balances out of the OS app-switcher snapshot.
  bool _obscured = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _lock.lockIfExpired();
        if (_obscured) setState(() => _obscured = false);
      case AppLifecycleState.inactive:
        // Fires for transient interruptions too (control centre, incoming
        // call), which is exactly when the snapshot is taken.
        if (!_obscured) setState(() => _obscured = true);
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _lock.markBackgrounded();
        if (!_obscured) setState(() => _obscured = true);
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final locked = _lock.isEnabled.value && _lock.isLocked.value;
      final shielded = _lock.isEnabled.value && _obscured && !locked;

      return Stack(
        children: [
          widget.child,
          // Positioned.fill — Stack sizes non-positioned children loosely, so
          // the overlays would otherwise shrink to their content.
          if (shielded) const Positioned.fill(child: _PrivacyShield()),
          if (locked) const Positioned.fill(child: _LockScreen()),
        ],
      );
    });
  }
}

/// Opaque cover shown while the app is backgrounded so financial figures never
/// reach the task-switcher thumbnail.
class _PrivacyShield extends StatelessWidget {
  const _PrivacyShield();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: AppColors.dark,
      child: Center(
        child: Icon(Icons.lock_rounded, color: AppColors.primary, size: 32),
      ),
    );
  }
}

/// Privacy toggle offered on the lock screen itself.
///
/// Cancelling the biometric prompt leaves the user stuck on the lock screen, so
/// this stays reachable there — they can decide whether balances are on screen
/// *before* unlocking hands the app back. Writes the same per-account
/// preference the in-app toggles use, so the choice is already in effect.
class _HideBalancesPill extends StatelessWidget {
  const _HideBalancesPill();

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    return Align(
      alignment: Alignment.centerRight,
      child: Obx(() {
        final hidden = auth.hideBalances.value;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: auth.toggleHideBalances,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hidden
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 16,
                  color: AppColors.textMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  hidden ? 'Balances hidden' : 'Balances shown',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Lock screen ─────────────────────────────────────────────────────────────

class _LockScreen extends StatefulWidget {
  const _LockScreen();

  @override
  State<_LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<_LockScreen> {
  final _lock = Get.find<AppLockService>();

  bool _prompting = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    // Prompt as soon as the lock screen appears — one tap saved on the common
    // path. Deferred to post-frame so the prompt doesn't race the first build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_prompting) return;
    setState(() => _prompting = true);
    final ok = await _lock.unlock();
    if (!mounted) return;
    setState(() {
      _prompting = false;
      _failed = !ok;
    });
  }

  Future<void> _signOut() async {
    // Escape hatch: a user whose biometrics stopped working must still be able
    // to leave. Signing out reveals nothing, and clearing the lock lets the
    // next sign-in reach the app.
    await _lock.setEnabled(false);
    _lock.release();
    await Get.find<AuthController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.dark,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const _HideBalancesPill(),
              const Spacer(),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.lock_rounded,
                    color: AppColors.dark, size: 32),
              ),
              const SizedBox(height: 24),
              const Text(
                '${AppConstants.appName} is locked',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.surface,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _failed
                    ? 'Authentication failed. Try again.'
                    : 'Unlock to see your finances.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: _failed ? AppColors.danger : AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _prompting ? null : _unlock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.5),
                    foregroundColor: AppColors.dark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _prompting ? 'Waiting…' : 'Unlock',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _prompting ? null : _signOut,
                child: const Text(
                  'Sign out instead',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
